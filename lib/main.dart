import 'package:flutter/material.dart';
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
import 'providers/dictionary_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/search_service.dart';
import 'services/seed_service.dart';
import 'services/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  String _status = '正在初始化本地词库...';
  String _detail = '';

  // Provider 在 State 创建时即存在，始终处于 MaterialApp 之上，
  // 因此弹窗 / 对话框也能访问（修复"设置打开无内容"）。
  late final SettingsProvider _settingsProvider =
      SettingsProvider(SettingsDao(widget.database));
  late final AiConfigProvider _aiConfigProvider =
      AiConfigProvider(AiSettingsDao(widget.database));
  late final DictionaryProvider _dictionaryProvider = DictionaryProvider(
    database: widget.database,
    termDao: TermDao(widget.database),
    historyDao: HistoryDao(widget.database),
    searchService: const SearchService(),
    aiConfigProvider: _aiConfigProvider,
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
    super.dispose();
  }

  /// 启动流程：打开数据库 -> 导入内置词库 -> 自动同步远程词库 -> 加载主界面。
  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();

    // 1. 数据库初始化 + 内置词库导入（失败不阻断启动）。
    try {
      await widget.database.open();
      await SeedService(widget.database).seedIfNeeded();
    } catch (_) {
      // 数据库异常：继续尝试进入界面。
    }

    // 2. 自动检查并同步远程词库（网络异常静默降级）。
    try {
      setState(() => _status = '正在同步最新 AI 知识库...');
      final updateService = widget.updateService ??
          UpdateService(widget.database, onProgress: (message) {
            if (mounted) setState(() => _detail = message);
          });
      await updateService.syncIfNeeded();
      if (mounted) setState(() => _detail = '完成。');
    } catch (_) {
      // 静默降级，不阻断启动。
    }

    // 3. 加载 Provider 数据（主界面数据源）。
    try {
      await _settingsProvider.load();
      await _aiConfigProvider.load();
      await _dictionaryProvider.load();
    } catch (_) {
      // 保持空状态进入主界面。
    }

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
      ],
      child: ListenableBuilder(
        listenable: _settingsProvider,
        builder: (context, _) {
          return MaterialApp(
            title: AppConfig.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _settingsProvider.themeMode,
            home: _ready
                ? const HomeScreen()
                : SplashScreen(status: _status, detail: _detail),
          );
        },
      ),
    );
  }
}
