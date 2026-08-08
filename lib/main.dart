import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'database/app_database.dart';
import 'database/history_dao.dart';
import 'database/settings_dao.dart';
import 'database/term_dao.dart';
import 'providers/dictionary_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'services/search_service.dart';
import 'services/seed_service.dart';

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

  // ---- Local database + initial seed data ----
  final database = AppDatabase();
  await database.open();
  await SeedService(database).seedIfNeeded();

  runApp(AIDictionaryApp(database: database));
}

/// 应用根组件：负责装配所有 Provider 与主题。
class AIDictionaryApp extends StatelessWidget {
  const AIDictionaryApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(SettingsDao(database))..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => DictionaryProvider(
            database: database,
            termDao: TermDao(database),
            historyDao: HistoryDao(database),
            searchService: SearchService(),
          )..load(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConfig.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
