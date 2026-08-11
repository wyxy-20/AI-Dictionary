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
import 'package:ai_dictionary/services/ai/ai_service.dart';
import 'package:ai_dictionary/widgets/ai_explanation_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

class StubExplainService implements AiService {
  int calls = 0;

  @override
  Future<String> explainTerm(Term term) async {
    calls++;
    return '【一句话理解】\n${term.englishName} 的简单解释。\n'
        '【详细解释】\n- 它是什么：测试。\n- 它解决什么问题：测试。\n- 基本原理：测试。\n'
        '【实际应用】\n- 应用案例一。\n'
        '【为什么重要】\n值得学习。\n'
        '【相关概念】\n- 相关一（Related）';
  }

  @override
  Future<String> askQuestion(String question) async => 'qa';

  @override
  Future<List<String>> learningPath(String goal) async => const [];

  @override
  Future<String> testConnection() async => 'ok';
}

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

Widget buildApp(AppDatabase db, AiConfigProvider aiConfig) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider(SettingsDao(db))..load()),
      ChangeNotifierProvider.value(value: aiConfig),
      ChangeNotifierProvider(
        create: (_) => DictionaryProvider(
          database: db,
          termDao: TermDao(db),
          historyDao: HistoryDao(db),
          aiConfigProvider: aiConfig,
        )..load(),
      ),
      ChangeNotifierProvider(
        create: (ctx) => AiExplanationProvider(ctx.read<DictionaryProvider>()),
      ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void setDesktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    ensureSqliteAvailable();
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    await TermDao(db).insertAll([makeTerm('Agent', '智能体')]);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('点击 AI 解释：右侧边栏加载 -> 分模块内容 + 复制/重新生成', (tester) async {
    setDesktopView(tester);
    final service = StubExplainService();
    final aiConfig = AiConfigProvider(
      AiSettingsDao(db),
      serviceFactory: (_) => service,
    );
    await aiConfig.load();

    await tester.pumpWidget(buildApp(db, aiConfig));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 解释'));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    expect(find.byType(AiExplanationPanel), findsOneWidget);
    expect(find.text('一句话理解'), findsOneWidget);
    expect(find.text('详细解释'), findsWidgets);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);

    // 关闭面板后再次点击：命中缓存，不重复调用 API
    await tester.tap(
      find.descendant(
        of: find.byType(AiExplanationPanel),
        matching: find.byTooltip('关闭 AI 解释面板'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AiExplanationPanel), findsNothing);
    await tester.tap(find.byTooltip('AI 解释'));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.byType(AiExplanationPanel), findsOneWidget);
  });

  testWidgets('未配置 API Key 时侧边栏显示配置提示，不崩溃', (tester) async {
    setDesktopView(tester);
    final aiConfig = AiConfigProvider(AiSettingsDao(db));
    await aiConfig.load();

    await tester.pumpWidget(buildApp(db, aiConfig));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 解释'));
    await tester.pumpAndSettle();

    expect(find.text('请先配置AI服务。'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);
    expect(find.byType(AiExplanationPanel), findsOneWidget);
  });

  testWidgets('顶部按钮可显示 / 隐藏 AI 解释面板', (tester) async {
    setDesktopView(tester);
    final aiConfig = AiConfigProvider(AiSettingsDao(db));
    await aiConfig.load();

    await tester.pumpWidget(buildApp(db, aiConfig));
    await tester.pumpAndSettle();

    expect(find.byType(AiExplanationPanel), findsNothing);

    await tester.tap(find.byTooltip('显示 AI 解释面板'));
    await tester.pumpAndSettle();
    expect(find.byType(AiExplanationPanel), findsOneWidget);
    expect(find.textContaining('AI 解释'), findsWidgets);

    await tester.tap(find.byTooltip('隐藏 AI 解释面板'));
    await tester.pumpAndSettle();
    expect(find.byType(AiExplanationPanel), findsNothing);
  });

  testWidgets('侧边栏打开时切换词条会自动跟随更新（缓存优先）', (tester) async {
    setDesktopView(tester);
    await TermDao(db).insertAll([makeTerm('RAG', '检索增强生成')]);

    final service = StubExplainService();
    final aiConfig = AiConfigProvider(
      AiSettingsDao(db),
      serviceFactory: (_) => service,
    );
    await aiConfig.load();

    await tester.pumpWidget(buildApp(db, aiConfig));
    await tester.pumpAndSettle();

    // 打开 Agent 的 AI 解释
    await tester.tap(find.text('Agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AI 解释'));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.textContaining('Agent 的简单解释'), findsOneWidget);

    // 切换到 RAG：侧边栏应自动跟随
    await tester.tap(find.text('RAG'));
    await tester.pumpAndSettle();
    expect(service.calls, 2, reason: '切换词条后应为新词条生成');
    expect(find.textContaining('RAG 的简单解释'), findsOneWidget);

    // 切回 Agent：命中缓存，不重复调用 API
    await tester.tap(find.text('Agent'));
    await tester.pumpAndSettle();
    expect(service.calls, 2, reason: '切回已解释词条应命中缓存');
    expect(find.textContaining('Agent 的简单解释'), findsOneWidget);
  });
}
