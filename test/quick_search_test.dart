import 'package:ai_dictionary/database/ai_settings_dao.dart';
import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/history_dao.dart';
import 'package:ai_dictionary/database/settings_dao.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/providers/ai_config_provider.dart';
import 'package:ai_dictionary/providers/ai_explanation_provider.dart';
import 'package:ai_dictionary/providers/dictionary_provider.dart';
import 'package:ai_dictionary/providers/settings_provider.dart';
import 'package:ai_dictionary/screens/home_screen.dart';
import 'package:ai_dictionary/screens/quick_search_window.dart';
import 'package:ai_dictionary/services/quick_search/quick_search_controller.dart';
import 'package:ai_dictionary/widgets/quick_search_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Term makeTerm(String en, String zh) {
  return Term(
    englishName: en,
    chineseName: zh,
    category: '测试',
    difficulty: 1,
    shortDescription: '$en 简介',
    detailDescription: '$en 详细',
    application: const ['场景'],
    relatedTerms: const ['AI'],
    firstCreated: 0,
  );
}

void main() {
  late AppDatabase db;
  late DictionaryProvider dictionary;
  late QuickSearchController controller;

  setUp(() async {
    ensureSqliteAvailable();
    QuickSearchController.debugDisablePlatform = true;
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    await TermDao(db).insertAll([
      makeTerm('Agent', '智能体'),
      makeTerm('RAG', '检索增强生成'),
      makeTerm('Transformer', 'Transformer'),
    ]);
    dictionary = DictionaryProvider(
      database: db,
      termDao: TermDao(db),
      historyDao: HistoryDao(db),
    );
    await dictionary.load();
    controller = QuickSearchController(
      SettingsProvider(SettingsDao(db)),
      dictionary,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('快捷键预设解析', () {
    final ctrlK = QuickSearchController.parseHotKey('Ctrl+K');
    expect(ctrlK, isNotNull);
    expect(ctrlK!.logicalKey, LogicalKeyboardKey.keyK);
    expect(ctrlK.modifiers, contains(HotKeyModifier.control));

    final f8 = QuickSearchController.parseHotKey('F8');
    expect(f8!.logicalKey, LogicalKeyboardKey.f8);
    expect(f8.modifiers, isNull);

    expect(QuickSearchController.parseHotKey('Unknown'), isNull);
  });

  testWidgets('快捷键触发的弹窗支持实时搜索与选中词条', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider(SettingsDao(db))),
          ChangeNotifierProvider.value(value: AiConfigProvider(AiSettingsDao(db))),
          ChangeNotifierProvider.value(value: dictionary),
          ChangeNotifierProvider.value(
            value: AiExplanationProvider(dictionary),
          ),
          ChangeNotifierProvider.value(value: controller),
        ],
        child: MaterialApp(
          navigatorKey: controller.navigatorKey,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 模拟全局快捷键回调
    controller.showQuickSearch();
    await tester.pumpAndSettle();
    expect(find.byType(QuickSearchDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'rag');
    await tester.pumpAndSettle();
    final dialog = find.byType(QuickSearchDialog);
    expect(find.descendant(of: dialog, matching: find.text('RAG')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('Agent')), findsNothing);

    await tester.tap(find.descendant(of: dialog, matching: find.text('RAG')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickSearchDialog), findsNothing);
    expect(find.text('检索增强生成'), findsWidgets);
  });

  testWidgets('设置中可配置快捷键并保存', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final settings = SettingsProvider(SettingsDao(db));
    await settings.load();
    controller = QuickSearchController(settings, dictionary);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: AiConfigProvider(AiSettingsDao(db))),
          ChangeNotifierProvider.value(value: dictionary),
          ChangeNotifierProvider.value(
            value: AiExplanationProvider(dictionary),
          ),
          ChangeNotifierProvider.value(value: controller),
        ],
        child: MaterialApp(
          navigatorKey: controller.navigatorKey,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    // 启用快捷键
    await tester.ensureVisible(find.text('启用全局快捷键'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('启用全局快捷键'));
    await tester.pumpAndSettle();
    expect(settings.settings.quickSearchEnabled, isTrue);

    // 自定义快捷键录制：点击当前组合进入录制，再按 Alt+K
    await tester.ensureVisible(find.text('Ctrl+K'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ctrl+K'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('请按下新的快捷键组合…（Esc 取消）'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    expect(settings.settings.quickSearchHotkey, 'Alt+K');
    expect(find.text('Alt+K'), findsOneWidget);
  });

  testWidgets('悬浮搜索窗口可渲染并支持输入', (tester) async {
    tester.view.physicalSize = const Size(560, 460);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const QuickSearchWindowApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('输入关键词开始搜索…'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rag');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('悬浮窗 Esc 隐藏、Enter 选中词条', (tester) async {
    tester.view.physicalSize = const Size(560, 460);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final windowCalls = <String>[];
    final channelCalls = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        windowCalls.add(call.method);
        if (call.method == 'ensureInitialized') return true;
        if (call.method == 'isMinimized') return false;
        if (call.method == 'show' ||
            call.method == 'hide' ||
            call.method == 'focus' ||
            call.method == 'restore') {
          return true;
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('mixin.one/desktop_multi_window'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('mixin.one/desktop_multi_window/channels'),
      (call) async {
        if (call.method == 'invokeMethod') {
          final args = (call.arguments as Map).cast<String, dynamic>();
          channelCalls.add(args['method'] as String);
          switch (args['method']) {
            case 'search':
              return {
                'results': [
                  {
                    'englishName': 'RAG',
                    'chineseName': '检索增强生成',
                    'category': '技术',
                    'difficulty': 2,
                    'letter': 'R',
                  },
                ],
              };
            case 'selectTerm':
              return true;
            case 'getState':
              return {'theme': 'light', 'language': 'zh'};
          }
        }
        if (call.method == 'registerMethodHandler') return true;
        return null;
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(const MethodChannel('window_manager'), null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('mixin.one/desktop_multi_window'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('mixin.one/desktop_multi_window/channels'),
        null,
      );
    });

    await tester.pumpWidget(const QuickSearchWindowApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField), 'rag');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RAG'), findsOneWidget);
    expect(channelCalls, contains('search'));

    // Esc 隐藏浮窗
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(windowCalls, contains('hide'));

    // 再次显示，Enter 选中词条
    windowCalls.clear();
    channelCalls.clear();
    await quickSearchOverlayKey.currentState?.showFromMain();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(windowCalls, contains('show'));
    await tester.enterText(find.byType(TextField), 'rag');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(channelCalls, contains('selectTerm'));
    expect(windowCalls, contains('hide'));
  });
}
