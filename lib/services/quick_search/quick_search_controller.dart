import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/term.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/search_service.dart';
import '../../widgets/quick_search_dialog.dart';
import 'hotkey_codec.dart';
import 'quick_search_channels.dart';

/// 全局快捷搜索控制器：
///
/// - 注册系统级全局热键（任意自定义组合），在任何应用（如看视频时）按
///   下都会触发；
/// - 触发后打开一个置顶的悬浮搜索子窗口（desktop_multi_window），不再受
///   主窗口束缚；
/// - 子窗口通过 `ai_dict/quick_search/main` 通道请求搜索/选中词条；
/// - 平台不可用（如测试环境）时回退为应用内弹窗。
class QuickSearchController extends ChangeNotifier {
  QuickSearchController(this._settingsProvider, this._dictionaryProvider);

  final SettingsProvider _settingsProvider;
  final DictionaryProvider _dictionaryProvider;

  /// 用于在应用内弹窗回退时显示 [QuickSearchDialog]。
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 测试环境置为 true 可跳过插件调用（避免挂起计时器）。
  static bool debugDisablePlatform = false;

  bool _registered = false;
  bool get registered => _registered;

  String? _lastError;
  String? get lastError => _lastError;

  bool _started = false;
  bool _busy = false;

  /// 解析存储的快捷键字符串（兼容旧预设，如 `Ctrl+K`）。
  static HotKey? parseHotKey(String text) => QuickSearchHotkeyCodec.decode(text);

  /// 启动：注册主窗口侧的跨窗口通道并同步全局热键。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _lastError = null;
    if (!debugDisablePlatform) {
      try {
        await quickSearchMainChannel.setMethodCallHandler(_handleMainCall);
      } catch (e) {
        _lastError = 'Quick search bridge unavailable: $e';
      }
    }
    await syncRegistration();
  }

  /// 主窗口侧通道处理：供悬浮子窗口调用。
  Future<dynamic> _handleMainCall(MethodCall call) async {
    switch (call.method) {
      case 'search':
        final query = (call.arguments as Map?)?['query'] as String? ?? '';
        final results = SearchService()
            .search(_dictionaryProvider.allTerms, query)
            .take(8)
            .toList();
        return {
          'results': [for (final term in results) _termToMap(term)],
        };
      case 'selectTerm':
        final englishName =
            (call.arguments as Map?)?['englishName'] as String? ?? '';
        Term? matched;
        for (final term in _dictionaryProvider.allTerms) {
          if (term.englishName == englishName) {
            matched = term;
            break;
          }
        }
        if (matched != null) {
          await _dictionaryProvider.selectTerm(matched);
          // 在主窗口仍是前台进程时完成聚焦，随后子窗口隐藏，焦点不会丢失。
          await _focusMainWindow();
        }
        return true;
      case 'getState':
        final settings = _settingsProvider.settings;
        return {'theme': settings.theme, 'language': settings.language};
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  }

  Map<String, dynamic> _termToMap(Term term) => {
        'englishName': term.englishName,
        'chineseName': term.chineseName,
        'category': term.category,
        'difficulty': term.difficulty,
        'letter': term.firstLetter,
      };

  Future<void> _focusMainWindow() async {
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // 聚焦失败不阻塞词条选择。
    }
  }

  /// 根据当前设置注册 / 注销全局热键。
  Future<void> syncRegistration() async {
    _lastError = null;
    if (debugDisablePlatform) {
      _registered = false;
      notifyListeners();
      return;
    }
    try {
      await hotKeyManager
          .unregisterAll()
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      if (!_settingsProvider.settings.quickSearchEnabled) {
        _registered = false;
        notifyListeners();
        return;
      }
      final hotKey =
          QuickSearchHotkeyCodec.decode(_settingsProvider.settings.quickSearchHotkey);
      if (hotKey == null) {
        _lastError = '快捷键配置无效';
        _registered = false;
        notifyListeners();
        return;
      }
      await hotKeyManager
          .register(
            hotKey,
            keyDownHandler: (_) {
              // 全局热键回调：显示悬浮搜索窗口。
              showQuickSearch();
            },
          )
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      _registered = true;
    } catch (e) {
      _registered = false;
      _lastError = e.toString();
    }
    notifyListeners();
  }

  /// 显示快捷搜索：
  /// 已存在子窗口则通知其显示；否则创建一个置顶悬浮窗口。
  Future<void> showQuickSearch() async {
    if (debugDisablePlatform) {
      _showInAppDialog();
      return;
    }
    if (_busy) return;
    _busy = true;
    try {
      final existing = await _findQuickSearchWindow();
      if (existing != null) {
        await _invokeShowWithRetry(existing);
      } else {
        try {
          await WindowController.create(
            WindowConfiguration(
              hiddenAtLaunch: true,
              arguments: quickSearchWindowArgument,
            ),
          );
          // 子窗口启动完成后会自行显示并置顶。
        } catch (e) {
          _lastError = e.toString();
          _showInAppDialog();
        }
      }
    } finally {
      _busy = false;
    }
  }

  Future<WindowController?> _findQuickSearchWindow() async {
    try {
      final windows = await WindowController.getAll();
      for (final window in windows) {
        if (window.arguments == quickSearchWindowArgument) return window;
      }
    } catch (_) {
      // 插件不可用时返回 null，走弹窗回退。
    }
    return null;
  }

  /// 子窗口刚创建时其 Dart 层尚未就绪，重试几次通知显示；
  /// 全部失败则退化为原生 show（至少让窗口可见）。
  Future<void> _invokeShowWithRetry(WindowController window) async {
    Object? lastError;
    for (var attempt = 0; attempt < 15; attempt++) {
      try {
        await window.invokeMethod('show');
        return;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    _lastError = lastError?.toString();
    try {
      await window.show();
    } catch (_) {
      // 忽略：下次热键会重新尝试。
    }
  }

  void _showInAppDialog() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    showDialog<void>(
      context: navigator.context,
      builder: (_) => QuickSearchDialog(dictionaryProvider: _dictionaryProvider),
    );
  }

  @override
  void dispose() {
    try {
      hotKeyManager.unregisterAll().catchError((_) {});
    } catch (_) {
      // 插件不可用时忽略（例如测试环境）。
    }
    super.dispose();
  }
}
