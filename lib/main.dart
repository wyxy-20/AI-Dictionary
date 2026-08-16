import 'dart:io';

import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'database/app_database.dart';
import 'database/history_dao.dart';
import 'database/ai_settings_dao.dart';
import 'database/settings_dao.dart';
import 'database/term_dao.dart';
import 'providers/ai_config_provider.dart';
import 'providers/ai_explanation_provider.dart';
import 'providers/dictionary_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/ai/secure_key_store.dart';
import 'services/backup_service.dart';
import 'services/search_service.dart';
import 'services/seed_service.dart';
import 'services/tray_service.dart';
import 'services/update_service.dart';
import 'services/quick_search/quick_search_controller.dart';
import 'services/quick_search/quick_search_channels.dart';
import 'screens/quick_search_window.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // desktop_multi_window：同一进程可包含多个窗口，子窗口（悬浮快捷搜索）
  // 通过启动参数区分，运行各自的 UI，避免重复初始化主应用。
  try {
    final windowController = await WindowController.fromCurrentEngine();
    if (windowController.arguments == quickSearchWindowArgument) {
      await runQuickSearchWindow(windowController);
      return;
    }
  } catch (_) {
    // 非 desktop_multi_window 环境（例如测试）继续按主窗口启动。
  }

  // ---- Desktop window configuration (resizable, centered) ----
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 620),
    center: true,
    title: AppConfig.appTitle,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  // 点击关闭按钮时由 Dart 层决定隐藏到托盘，而不是退出进程。
  await windowManager.setPreventClose(true);

  // 数据库在启动页中初始化（展示同步状态）。
  final database = AppDatabase();

  runApp(AIDictionaryApp(database: database));
}

/// 应用根组件：先显示启动加载页并自动同步词库，完成后进入主界面。
class AIDictionaryApp extends StatefulWidget {
  const AIDictionaryApp({super.key, required this.database, this.updateService});

  final AppDatabase database;

  /// 允许测试注入自定义同步服务（默认使用 GitHub 远程词库）。
  final UpdateService? updateService;

  @override
  State<AIDictionaryApp> createState() => _AIDictionaryAppState();
}

class _AIDictionaryAppState extends State<AIDictionaryApp> {
  bool _ready = false;
  String _statusKey = 'init';
  String _detailKey = '';

  // Provider 在 State 创建时即存在，始终处于 MaterialApp 之上，
  // 因此弹窗 / 对话框也能访问（修复"设置打开无内容"）。
  late final SettingsProvider _settingsProvider =
      SettingsProvider(SettingsDao(widget.database));
  late final AiConfigProvider _aiConfigProvider = AiConfigProvider(
    AiSettingsDao(
      widget.database,
      keyStore: Platform.isWindows
          ? WindowsDpapiKeyStore()
          : const NoopSecureKeyStore(),
    ),
  );
  late final DictionaryProvider _dictionaryProvider = DictionaryProvider(
    database: widget.database,
    termDao: TermDao(widget.database),
    historyDao: HistoryDao(widget.database),
    searchService: const SearchService(),
    aiConfigProvider: _aiConfigProvider,
  );
  late final AiExplanationProvider _aiExplanationProvider =
      AiExplanationProvider(_dictionaryProvider);
  late final QuickSearchController _quickSearchController =
      QuickSearchController(_settingsProvider, _dictionaryProvider);
  late final TrayService _trayService = TrayService(
    onShowQuickSearch: () => _quickSearchController.showQuickSearch(),
    onHideQuickSearch: () => _quickSearchController.hideQuickSearch(),
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _settingsProvider.dispose();
    _aiConfigProvider.dispose();
    _dictionaryProvider.dispose();
    _aiExplanationProvider.dispose();
    _quickSearchController.dispose();
    _trayService.dispose();
    super.dispose();
  }

  /// 启动流程：打开数据库 -> 导入内置词库 -> 自动同步远程词库 -> 加载主界面。
  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();
    await AppLogger.instance.init();

    // 1. 数据库初始化 + 内置词库导入（失败不阻断启动）。
    try {
      await widget.database.open();
      await SeedService(widget.database).seedIfNeeded();
    } catch (e) {
      await AppLogger.instance.error('bootstrap', '数据库初始化失败：$e');
    }

    // 2. 自动检查并同步远程词库（网络异常静默降级）。
    try {
      setState(() => _statusKey = 'sync');
      final updateService = widget.updateService ??
          UpdateService(widget.database, onProgress: (stage) {
            if (mounted) {
              setState(() => _detailKey = stage.name);
            }
          });
      await updateService.syncIfNeeded();
      if (mounted) setState(() => _detailKey = SyncStage.done.name);
    } catch (e) {
      await AppLogger.instance.error('bootstrap', '远程词库同步失败：$e');
    }

    // 3. 加载 Provider 数据（主界面数据源）。
    try {
      await _settingsProvider.load();
      await _aiConfigProvider.load();
      await _dictionaryProvider.load();
      await _quickSearchController.start();
      await _trayService.init();
    } catch (e) {
      await AppLogger.instance.error('bootstrap', '状态加载失败：$e');
    }

    // 3.5 自动备份数据库（到期才备份，失败不影响启动）。
    await BackupService(widget.database, directory: widget.database.directory)
        .maybeBackup();

    // 4. 保证加载页至少展示片刻，避免闪烁。
    final remaining = 700 - stopwatch.elapsedMilliseconds;
    if (remaining > 0) {
      await Future<void>.delayed(Duration(milliseconds: remaining));
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    // Provider 包裹整个 MaterialApp：主题切换实时生效，对话框可正常访问状态。
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settingsProvider),
        ChangeNotifierProvider.value(value: _aiConfigProvider),
        ChangeNotifierProvider.value(value: _dictionaryProvider),
        ChangeNotifierProvider.value(value: _aiExplanationProvider),
        ChangeNotifierProvider.value(value: _quickSearchController),
      ],
      child: ListenableBuilder(
        listenable: _settingsProvider,
        builder: (context, _) {
          return MaterialApp(
            title: AppConfig.appTitle,
            debugShowCheckedModeBanner: false,
            navigatorKey: _quickSearchController.navigatorKey,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _settingsProvider.themeMode,
            home: _ready
                ? const HomeScreen()
                : SplashScreen(statusKey: _statusKey, detailKey: _detailKey),
          );
        },
      ),
    );
  }
}
