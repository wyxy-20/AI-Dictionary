import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/main.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/services/update_service.dart';
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
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    await TermDao(db).insertAll([makeTerm('Agent', '智能体')]);
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
    expect(find.text('Agent'), findsOneWidget);
  });
}
