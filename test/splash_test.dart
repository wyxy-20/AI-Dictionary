import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/main.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/services/seed_service.dart';
import 'package:ai_dictionary/services/update_service.dart';
import 'package:ai_dictionary/screens/home_screen.dart';
import 'package:ai_dictionary/services/quick_search/quick_search_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_utils.dart';

Term makeTerm(String en, String zh) {
  return Term(
    englishName: en,
    chineseName: zh,
    category: '测试分类',
    difficulty: 1,
    shortDescription: '$en 简介',
    detailDescription: '$en 详细解释',
    application: const ['场景'],
    relatedTerms: const ['AI'],
    firstCreated: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    ensureSqliteAvailable();
    QuickSearchController.debugDisablePlatform = true;
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    // 预置完整内置词库：避免启动时在 testWidgets 的 FakeAsync 环境中
    // 执行种子导入（sqflite 异步操作在 FakeAsync 中无法完成）。
    final terms = await SeedService(db).loadTerms();
    await TermDao(db).insertAll(terms);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('启动页显示同步状态，完成后自动进入主界面', (tester) async {
    final updateService = UpdateService(
      db,
      client: MockClient((request) async => http.Response('not found', 404)),
      baseUrl: 'http://dictionary.test',
    );

    await tester.pumpWidget(
      AIDictionaryApp(database: db, updateService: updateService),
    );

    // 启动页：图标 + 标题 + 同步状态
    expect(find.text('AI Dictionary'), findsOneWidget);
    await tester.pump();
    expect(find.text('正在同步最新 AI 知识库...'), findsOneWidget);

    // 同步完成后自动进入主界面
    await tester.pumpAndSettle();
    expect(find.text('Search AI terms...'), findsOneWidget);
    expect(find.text('全部词条'), findsWidgets);
    // 词条列表是虚拟化的（1125 条），目标词条需滚动到视口内
    await tester.scrollUntilVisible(
      find.text('Agent'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Agent'), findsOneWidget);
  });

  testWidgets('网络异常也不阻断启动，正常进入主界面', (tester) async {
    final updateService = UpdateService(
      db,
      client: MockClient((request) async {
        throw http.ClientException('offline');
      }),
      baseUrl: 'http://dictionary.test',
    );

    await tester.pumpWidget(
      AIDictionaryApp(database: db, updateService: updateService),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search AI terms...'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Agent'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Agent'), findsOneWidget);
  });

  testWidgets('主题切换实时生效，无需重启', (tester) async {
    final updateService = UpdateService(
      db,
      client: MockClient((request) async => http.Response('not found', 404)),
      baseUrl: 'http://dictionary.test',
    );

    await tester.pumpWidget(
      AIDictionaryApp(database: db, updateService: updateService),
    );
    await tester.pumpAndSettle();

    Brightness brightness() =>
        Theme.of(tester.element(find.byType(HomeScreen))).brightness;

    expect(brightness(), Brightness.light);

    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark, reason: '切深色应即时生效');

    await tester.tap(find.byIcon(Icons.light_mode_rounded));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light, reason: '切回浅色应即时生效');
  });

  testWidgets('设置对话框内容完整显示（回归：对话框可访问 Provider）', (tester) async {
    final updateService = UpdateService(
      db,
      client: MockClient((request) async => http.Response('not found', 404)),
      baseUrl: 'http://dictionary.test',
    );

    await tester.pumpWidget(
      AIDictionaryApp(database: db, updateService: updateService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('AI 服务设置'), findsOneWidget);
    expect(find.text('保存配置'), findsOneWidget);
    expect(find.text('测试连接'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('语言切到 English 后界面即时变为英文，无需重启', (tester) async {
    final updateService = UpdateService(
      db,
      client: MockClient((request) async => http.Response('not found', 404)),
      baseUrl: 'http://dictionary.test',
    );

    await tester.pumpWidget(
      AIDictionaryApp(database: db, updateService: updateService),
    );
    await tester.pumpAndSettle();

    // 默认中文
    expect(find.text('全部词条'), findsWidgets);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // 设置对话框立即变为英文
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('AI Service Settings'), findsOneWidget);

    // 关闭后主界面立即变为英文
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('All Terms'), findsWidgets);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('全部词条'), findsNothing);

    // 切回中文，界面立即恢复
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('全部词条'), findsWidgets);
  });
}
