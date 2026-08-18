import 'package:ai_dictionary/core/constants/ai_presets.dart';
import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/main.dart';
import 'package:ai_dictionary/services/quick_search/quick_search_controller.dart';
import 'package:ai_dictionary/services/seed_service.dart';
import 'package:ai_dictionary/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiServicePresets 数据', () {
    test('match 能识别官方配置并容忍尾部斜杠', () {
      expect(
        AiServicePresets.match('https://api.deepseek.com', 'deepseek-v4-flash'),
        'DeepSeek',
      );
      expect(
        AiServicePresets.match(
          'https://api.deepseek.com/',
          'deepseek-v4-flash',
        ),
        'DeepSeek',
      );
      expect(
        AiServicePresets.match('https://api.openai.com/v1', 'gpt-4o-mini'),
        'OpenAI',
      );
      expect(AiServicePresets.match('https://x.com', 'unknown'), isNull);
    });

    test('byName 能按名称取回预设', () {
      expect(AiServicePresets.byName('DeepSeek')?.modelName,
          'deepseek-v4-flash');
      expect(AiServicePresets.byName('不存在'), isNull);
    });
  });

  group('设置页 AI 服务预设', () {
    late AppDatabase db;

    setUp(() async {
      ensureSqliteAvailable();
      QuickSearchController.debugDisablePlatform = true;
      db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
      await db.openInMemory();
      final terms = await SeedService(db).loadTerms();
      await TermDao(db).insertAll(terms);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('选择 DeepSeek 预设自动填充地址与模型名', (tester) async {
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

      // 默认配置匹配 OpenAI 预设，先滚动到预设下拉
      final dialogScrollable = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      );
      final presetField = find.text('OpenAI');
      await tester.scrollUntilVisible(
        presetField,
        200,
        scrollable: dialogScrollable.first,
      );
      await tester.tap(presetField);
      await tester.pumpAndSettle();

      await tester.tap(find.text('DeepSeek').last);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'https://api.deepseek.com'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'deepseek-v4-flash'),
        findsOneWidget,
      );
    });
  });
}
