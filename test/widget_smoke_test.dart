import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/ai_settings_dao.dart';
import 'package:ai_dictionary/database/history_dao.dart';
import 'package:ai_dictionary/database/settings_dao.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/providers/ai_config_provider.dart';
import 'package:ai_dictionary/providers/dictionary_provider.dart';
import 'package:ai_dictionary/providers/settings_provider.dart';
import 'package:ai_dictionary/screens/home_screen.dart';
import 'package:ai_dictionary/widgets/left_nav_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

Term makeTerm(String en, String zh, {String category = '测试分类'}) {
  return Term(
    englishName: en,
    chineseName: zh,
    category: category,
    difficulty: 2,
    shortDescription: '$en 的一句话解释',
    detailDescription: '$en 的详细解释。这里描述了概念、原理与用途。',
    application: const ['应用场景一', '应用场景二'],
    relatedTerms: const ['AI', 'LLM'],
    firstCreated: 0,
  );
}

Widget buildApp(AppDatabase db) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(SettingsDao(db))..load(),
      ),
      ChangeNotifierProvider(
        create: (_) => AiConfigProvider(AiSettingsDao(db))..load(),
      ),
      ChangeNotifierProvider(
        create: (_) => DictionaryProvider(
          database: db,
          termDao: TermDao(db),
          historyDao: HistoryDao(db),
        )..load(),
      ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    ensureSqliteAvailable();
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    await TermDao(db).insertAll([
      makeTerm('Agent', '智能体'),
      makeTerm('RAG', '检索增强生成'),
      makeTerm('LLM', '大语言模型'),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('三栏布局渲染：搜索框、字母导航、列表与详情', (tester) async {
    await tester.pumpWidget(buildApp(db));
    await tester.pumpAndSettle();

    expect(find.text('Search AI terms...'), findsOneWidget);
    expect(find.text('全部词条'), findsWidgets);
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('最近浏览'), findsOneWidget);
    expect(find.text('字母导航'), findsOneWidget);
    expect(find.text('选择一个词条查看详情'), findsOneWidget);

    // 列表包含三个词条
    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('RAG'), findsOneWidget);
    expect(find.text('LLM'), findsOneWidget);
  });

  testWidgets('点击词条显示详情并记录历史', (tester) async {
    await tester.pumpWidget(buildApp(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('RAG'));
    await tester.pumpAndSettle();

    expect(find.text('检索增强生成'), findsWidgets);
    expect(find.text('RAG 的详细解释。这里描述了概念、原理与用途。'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('相关词条'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('相关词条'), findsOneWidget);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('LLM'), findsWidgets);

    // 切换到最近浏览应包含 RAG
    await tester.tap(find.text('最近浏览'));
    await tester.pumpAndSettle();
    expect(find.text('RAG'), findsWidgets);
  });

  testWidgets('实时搜索过滤词条', (tester) async {
    await tester.pumpWidget(buildApp(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'rag');
    await tester.pumpAndSettle();

    expect(find.text('RAG'), findsOneWidget);
    expect(find.text('Agent'), findsNothing);
    expect(find.text('LLM'), findsNothing);
  });

  testWidgets('字母导航过滤 + 收藏功能', (tester) async {
    await tester.pumpWidget(buildApp(db));
    await tester.pumpAndSettle();

    // 点击字母 R
    await tester.tap(
      find.descendant(
        of: find.byType(LeftNavPanel),
        matching: find.text('R'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('字母 R'), findsOneWidget);
    expect(find.text('RAG'), findsOneWidget);
    expect(find.text('Agent'), findsNothing);

    // 清除筛选回到全部
    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();

    // 打开 RAG 详情并收藏
    await tester.tap(find.text('RAG'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.star_border_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsWidgets);

    // 收藏列表可见
    await tester.tap(find.text('我的收藏'));
    await tester.pumpAndSettle();
    expect(find.text('RAG'), findsWidgets);
  });

  testWidgets('主题切换按钮存在且可点击', (tester) async {
    await tester.pumpWidget(buildApp(db));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
  });
}
