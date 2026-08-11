import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../database/app_database.dart';
import '../database/settings_dao.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../services/quick_search/quick_search_channels.dart';

typedef _SetFocusNative = ffi.IntPtr Function(ffi.IntPtr);
typedef _SetFocusDart = int Function(int);

/// 悬浮搜索窗口的 State 全局句柄，供窗口引导（channel handler）触发 UI。
final GlobalKey<QuickSearchOverlayState> quickSearchOverlayKey =
    GlobalKey<QuickSearchOverlayState>();

/// 悬浮快捷搜索子窗口入口（由 main.dart 按窗口参数路由）。
///
/// 该窗口是独立 Flutter engine：只渲染搜索 UI，数据统一通过
/// [quickSearchMainChannel] 向主窗口请求，避免多进程访问同一个 SQLite。
Future<void> runQuickSearchWindow(WindowController controller) async {
  await windowManager.ensureInitialized();

  // 处理来自主窗口的指令（show / hide）。
  await controller.setWindowMethodHandler((call) async {
    switch (call.method) {
      case 'show':
        unawaited(quickSearchOverlayKey.currentState?.showFromMain());
        return true;
      case 'hide':
        unawaited(quickSearchOverlayKey.currentState?.hideFromMain());
        return true;
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  });

  const windowOptions = WindowOptions(
    size: Size(560, 460),
    minimumSize: Size(420, 320),
    center: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    title: 'AI Dictionary · 快捷搜索',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const QuickSearchWindowApp());
}

/// 子窗口使用的内存版 SettingsDao：主题/语言从主窗口同步，不落库。
class _MemorySettingsDao implements SettingsDao {
  _MemorySettingsDao(this._settings);

  AppSettings _settings;

  @override
  AppDatabase get database =>
      throw UnsupportedError('In-memory settings DAO has no database');

  @override
  Future<AppSettings> getSettings() async => _settings;

  @override
  Future<void> updateTheme(String theme) async {
    _settings = _settings.copyWith(theme: theme);
  }

  @override
  Future<void> updateLanguage(String language) async {
    _settings = _settings.copyWith(language: language);
  }

  @override
  Future<void> updateQuickSearchHotkey(String hotkey) async {}

  @override
  Future<void> updateQuickSearchEnabled(bool enabled) async {}
}

class QuickSearchWindowApp extends StatefulWidget {
  const QuickSearchWindowApp({super.key});

  @override
  State<QuickSearchWindowApp> createState() => _QuickSearchWindowAppState();
}

class _QuickSearchWindowAppState extends State<QuickSearchWindowApp> {
  final SettingsProvider _settingsProvider = SettingsProvider(
    _MemorySettingsDao(const AppSettings()),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _settingsProvider,
      child: ListenableBuilder(
        listenable: _settingsProvider,
        builder: (context, _) {
          return MaterialApp(
            title: 'AI Dictionary',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _settingsProvider.themeMode,
            home: QuickSearchOverlay(
              key: quickSearchOverlayKey,
              settingsProvider: _settingsProvider,
            ),
          );
        },
      ),
    );
  }
}

class QuickSearchOverlay extends StatefulWidget {
  const QuickSearchOverlay({super.key, required this.settingsProvider});

  final SettingsProvider settingsProvider;

  @override
  State<QuickSearchOverlay> createState() => QuickSearchOverlayState();
}

class QuickSearchOverlayState extends State<QuickSearchOverlay>
    with WindowListener {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final List<Map<String, dynamic>> _results = [];

  String _query = '';
  bool _searching = false;
  bool _visible = true;
  bool _stateOk = true;
  String _error = '';
  int _selectedIndex = 0;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    HardwareKeyboard.instance.addHandler(_onRawKeyEvent);
    unawaited(_watchMainWindow());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(showFromMain());
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    HardwareKeyboard.instance.removeHandler(_onRawKeyEvent);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// 在 Focus/Shortcuts 链之前处理快捷键（子窗口引擎的键盘事件更可靠地
  /// 到达这里；字母键已证明能到达本引擎）。
  bool _onRawKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        unawaited(_hide());
        return true;
      case LogicalKeyboardKey.enter:
        if (_results.isNotEmpty) {
          unawaited(_select(_results[_selectedIndex]));
        }
        return true;
      case LogicalKeyboardKey.arrowDown:
        if (_results.isNotEmpty) _moveSelection(1);
        return true;
      case LogicalKeyboardKey.arrowUp:
        if (_results.isNotEmpty) _moveSelection(-1);
        return true;
    }
    return false;
  }

  /// 主窗口关闭时，悬浮窗也关闭（整个进程随之退出）。
  Future<void> _watchMainWindow() async {
    onWindowsChanged.listen((_) async {
      try {
        final windows = await WindowController.getAll();
        final hasOther = windows
            .any((w) => w.arguments != quickSearchWindowArgument);
        if (windows.isNotEmpty && !hasOther) {
          try {
            await windowManager.close();
          } catch (_) {}
        }
      } catch (_) {
        // 忽略枚举失败。
      }
    });
  }

  /// 从主窗口拉取主题/语言并显示/聚焦窗口。
  Future<void> showFromMain() async {
    await _applyStateFromMain();
    try {
      await windowManager.show();
      await windowManager.focus();
      // window_manager 的 Show/Focus 可能把窗口移出置顶层，每次显示都重申。
      await windowManager.setAlwaysOnTop(true);
      await _forceKeyboardFocus();
    } catch (_) {
      // 窗口控制失败不阻塞 UI。
    }
    if (!mounted) return;
    setState(() {
      _visible = true;
      _query = '';
      _searchController.clear();
      _results.clear();
      _selectedIndex = 0;
      _requestSeq++;
      if (_stateOk) _error = '';
    });
    _searchFocus.requestFocus();
    // 重新显示时，输入法/焦点可能尚未就绪，稍后再补一次焦点与输入连接。
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || !_visible) return;
      unawaited(_forceKeyboardFocus());
      unawaited(windowManager.setAlwaysOnTop(true).catchError((_) {}));
      _searchFocus.requestFocus();
    });
  }

  /// 子窗口是独立引擎创建的 Win32 窗口，仅置前台（foreground）并不会自动
  /// 获得键盘焦点；这里用 SetFocus 强制把焦点给到子窗口，保证按键能送达。
  Future<void> _forceKeyboardFocus() async {
    try {
      final hwnd = await windowManager.getId();
      if (hwnd == 0) return;
      final user32 = ffi.DynamicLibrary.open('user32.dll');
      final setFocus = user32.lookupFunction<_SetFocusNative, _SetFocusDart>(
        'SetFocus',
      );
      setFocus(hwnd);
    } catch (_) {
      // 非 Windows 或无权限时忽略。
    }
  }

  Future<void> hideFromMain() => _hide();

  Future<void> _hide() async {
    if (!_visible) return;
    setState(() => _visible = false);
    try {
      await windowManager.hide();
    } catch (_) {
      // 忽略。
    }
  }

  Future<void> _applyStateFromMain() async {
    try {
      final state = await quickSearchMainChannel
          .invokeMethod<Map<dynamic, dynamic>>('getState');
      final theme = state?['theme'] as String? ?? 'system';
      final language = state?['language'] as String? ?? 'zh';
      if (!mounted) return;
      await widget.settingsProvider.setTheme(theme);
      await widget.settingsProvider.setLanguage(language);
      setState(() {
        _stateOk = true;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stateOk = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String value) {
    final seq = ++_requestSeq;
    final query = value.trim();
    setState(() {
      _query = query;
      _selectedIndex = 0;
      if (query.isEmpty) {
        _results.clear();
        _searching = false;
      } else {
        _searching = true;
      }
    });
    if (query.isNotEmpty) {
      unawaited(_search(query, seq));
    }
  }

  Future<void> _search(String query, int seq) async {
    try {
      final result = await quickSearchMainChannel.invokeMethod<Map>(
        'search',
        {'query': query},
      );
      if (!mounted || seq != _requestSeq) return;
      final raw = (result?['results'] as List<dynamic>?) ?? const [];
      setState(() {
        _results
          ..clear()
          ..addAll(raw
              .cast<Map<dynamic, dynamic>>()
              .map((m) => Map<String, dynamic>.from(m)));
        _searching = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results.clear();
        _searching = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _select(Map<String, dynamic> term) async {
    // 先让主窗口完成选中并聚焦（此时浮窗仍在前台，同进程激活不受限制），
    // 再隐藏浮窗；即使通道异常/超时也会照常关闭。
    try {
      await quickSearchMainChannel
          .invokeMethod(
            'selectTerm',
            {'englishName': term['englishName']},
          )
          .timeout(const Duration(seconds: 1));
    } catch (_) {
      // 主窗口不可用或超时：仅关闭浮窗。
    }
    unawaited(_hide());
  }

  @override
  void onWindowBlur() {
    if (_visible) {
      unawaited(_hide());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.search_rounded, size: 22, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) {
                        if (_results.isNotEmpty) {
                          unawaited(_select(_results[_selectedIndex]));
                        }
                      },
                      decoration: InputDecoration(
                        hintText: s.quickSearchSearchHint,
                        isDense: true,
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                tooltip: s.clearSearch,
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: s.close,
                    onPressed: () => unawaited(_hide()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(scheme, s)),
              const SizedBox(height: 4),
              Text(
                s.quickSearchShortcutHint,
                style: TextStyle(fontSize: 10.5, color: scheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveSelection(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _results.length - 1);
    });
  }

  Widget _buildBody(ColorScheme scheme, AppStrings s) {
    if (!_stateOk) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 32, color: scheme.error),
            const SizedBox(height: 8),
            Text(
              s.quickSearchMainUnavailable,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (_query.isEmpty) {
      return Center(
        child: Text(
          s.quickSearchTypeToStart,
          style: TextStyle(fontSize: 13, color: scheme.outline),
        ),
      );
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Text(
          s.quickSearchNoResults,
          style: TextStyle(fontSize: 13, color: scheme.outline),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          s.quickSearchNoResults,
          style: TextStyle(fontSize: 13, color: scheme.outline),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final term = _results[index];
        final letter = term['letter'] as String? ??
            _letterFromName(term['englishName'] as String? ?? '');
        return ListTile(
          dense: true,
          selected: index == _selectedIndex,
          selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.35),
          leading: CircleAvatar(
            radius: 15,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          title: Text(term['englishName'] as String? ?? ''),
          subtitle: Text(
            term['chineseName'] as String? ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => unawaited(_select(term)),
        );
      },
    );
  }

  String _letterFromName(String name) {
    final t = name.trim();
    if (t.isEmpty) return '#';
    final c = t[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
  }
}
