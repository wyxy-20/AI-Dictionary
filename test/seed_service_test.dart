import 'package:ai_dictionary/core/config/app_config.dart';
import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/services/seed_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    ensureSqliteAvailable();
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
  });

  tearDown(() async {
    await db.close();
  });

  test('JSON 词库包含不少于 300 个词条且无重复', () async {
    final service = SeedService(db);
    final terms = await service.loadTerms();

    expect(terms.length, greaterThanOrEqualTo(AppConfig.minSeedTerms));
    final names = terms.map((t) => t.englishName.toLowerCase()).toSet();
    expect(names.length, terms.length, reason: '存在重复英文词条');

    // 每个词条关键字段非空
    for (final term in terms) {
      expect(term.englishName, isNotEmpty);
      expect(term.chineseName, isNotEmpty);
      expect(term.category, isNotEmpty);
      expect(term.shortDescription, isNotEmpty);
      expect(term.detailDescription, isNotEmpty);
      expect(term.application, isNotEmpty);
      expect(term.relatedTerms, isNotEmpty);
      expect(term.difficulty, inInclusiveRange(1, 3));
    }
  });

  test('核心必备词条均存在', () async {
    final terms = await SeedService(db).loadTerms();
    final names = terms.map((t) => t.englishName.toLowerCase()).toSet();
    const required = [
      'ai', 'agi', 'agent', 'alignment', 'algorithm', 'api', 'attention',
      'backpropagation', 'benchmark', 'bias', 'cuda', 'cnn', 'context window',
      'chain of thought', 'deep learning', 'diffusion', 'dataset', 'embedding',
      'fine-tuning', 'function calling', 'gan', 'gpu', 'llm', 'machine learning',
      'mcp', 'memory', 'multi-agent', 'prompt', 'prompt engineering', 'python',
      'planning', 'rag', 'rlhf', 'token', 'transformer', 'tool calling',
      'vector database', 'chatgpt', 'claude', 'gemini', 'cursor', 'comfyui',
      'langchain', 'langgraph', 'dify', 'coze', 'autogpt',
    ];
    for (final name in required) {
      expect(names, contains(name), reason: '缺少必备词条 $name');
    }
  });

  test('首次导入后重复执行不会重复插入', () async {
    final service = SeedService(db);
    expect(await service.seedIfNeeded(), isTrue);
    expect(await service.seedIfNeeded(), isFalse);
    final dao = TermDao(db);
    expect(await dao.count(), greaterThanOrEqualTo(AppConfig.minSeedTerms));
  });

  test('重置数据库后重新导入', () async {
    final service = SeedService(db);
    await service.seedIfNeeded();
    final dao = TermDao(db);
    final before = await dao.count();
    await service.resetDatabase();
    expect(await dao.count(), before);
  });
}
