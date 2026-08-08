import 'package:ai_dictionary/database/ai_explanation_cache_dao.dart';
import 'package:ai_dictionary/database/ai_settings_dao.dart';
import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/history_dao.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/models/ai_config.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/providers/ai_config_provider.dart';
import 'package:ai_dictionary/providers/dictionary_provider.dart';
import 'package:ai_dictionary/services/ai/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

class CountingAiService implements AiService {
  int calls = 0;

  @override
  Future<String> explainTerm(Term term) async {
    calls++;
    return '【一句话理解】\n${term.englishName} 的简单解释。\n'
        '【详细解释】\n- 它是什么：测试内容。\n'
        '【实际应用】\n- 应用案例。\n'
        '【为什么重要】\n学习价值。\n'
        '【相关概念】\n- 相关一';
  }

  @override
  Future<String> askQuestion(String question) async => 'qa';

  @override
  Future<List<String>> learningPath(String goal) async => const [];
}

Term makeTerm(String en, {String zh = '', int version = 1}) {
  return Term(
    englishName: en,
    chineseName: zh.isEmpty ? en : zh,
    category: '测试',
    difficulty: 1,
    shortDescription: '简介 $en',
    detailDescription: '详细 $en',
    application: const ['场景'],
    relatedTerms: const ['AI'],
    firstCreated: 0,
    version: version,
  );
}

void main() {
  late AppDatabase db;
  late CountingAiService service;
  late AiConfigProvider aiConfig;
  late DictionaryProvider provider;

  setUp(() async {
    ensureSqliteAvailable();
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    await TermDao(db).insertAll([makeTerm('Agent'), makeTerm('Transformer')]);
    service = CountingAiService();
    aiConfig = AiConfigProvider(
      AiSettingsDao(db),
      serviceFactory: (_) => service,
    );
    await aiConfig.load();
    provider = DictionaryProvider(
      database: db,
      termDao: TermDao(db),
      historyDao: HistoryDao(db),
      aiConfigProvider: aiConfig,
    );
    await provider.load();
  });

  tearDown(() async {
    await db.close();
  });

  test('首次生成并写缓存，重复点击命中缓存不重复调用 API', () async {
    final term = (await TermDao(db).getAll()).firstWhere((t) => t.englishName == 'Agent');

    final first = await provider.explainTerm(term);
    expect(service.calls, 1);
    expect(first, contains('一句话理解'));

    final second = await provider.explainTerm(term);
    expect(service.calls, 1, reason: '第二次应命中缓存');
    expect(second, first);

    expect(await AiExplanationCacheDao(db).count(), 1);
  });

  test('词条版本变化后旧缓存失效，重新调用 AI', () async {
    final dao = TermDao(db);
    final term = (await dao.getAll()).firstWhere((t) => t.englishName == 'Agent');
    await provider.explainTerm(term);
    expect(service.calls, 1);

    // 模拟远程同步后词条内容变化：version 1 -> 2
    await db.database.update('terms', {'version': 2}, where: 'id = ?', whereArgs: [term.id]);
    final updatedTerm = (await dao.getAll()).firstWhere((t) => t.englishName == 'Agent');
    expect(updatedTerm.version, 2);

    await provider.explainTerm(updatedTerm);
    expect(service.calls, 2, reason: '版本变化后应重新生成');
    expect(await AiExplanationCacheDao(db).count(), 1);
  });

  test('切换模型后旧缓存失效', () async {
    final term = (await TermDao(db).getAll()).firstWhere((t) => t.englishName == 'Agent');
    await provider.explainTerm(term);
    expect(service.calls, 1);

    await aiConfig.save(const AiConfig(modelName: 'other-model'));
    await provider.explainTerm(term);
    expect(service.calls, 2);
  });

  test('新增词条可以正常解释', () async {
    final dao = TermDao(db);
    await dao.insertAll([makeTerm('MCP')]);
    final term = (await dao.getAll()).firstWhere((t) => t.englishName == 'MCP');

    final content = await provider.explainTerm(term);
    expect(content, contains('MCP'));
    expect(service.calls, 1);
    expect(await AiExplanationCacheDao(db).count(), 1);
  });

  test('未配置 API Key 时抛出配置异常', () async {
    final noKeyConfig = AiConfigProvider(AiSettingsDao(db));
    await noKeyConfig.load();
    final noKeyProvider = DictionaryProvider(
      database: db,
      termDao: TermDao(db),
      historyDao: HistoryDao(db),
      aiConfigProvider: noKeyConfig,
    );
    await noKeyProvider.load();

    final term = (await TermDao(db).getAll()).first;
    expect(
      () => noKeyProvider.explainTerm(term),
      throwsA(isA<AiConfigException>()),
    );
  });
}
