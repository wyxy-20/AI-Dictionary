import 'package:ai_dictionary/core/config/app_config.dart';
import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/database/version_dao.dart';
import 'package:ai_dictionary/models/dictionary_version.dart';
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

  test('旧版本升级：已有部分词条时增量补齐，保留收藏与历史', () async {
    // 模拟旧版本用户：db 中只有内置词库的子集 + 收藏 + 旧版本号
    final all = await SeedService(db).loadTerms();
    final subset = all.take(20).toList();
    final dao = TermDao(db);
    await dao.insertAll(subset);
    // 从 db 取回带 id 的词条
    final inserted = await dao.getAll();
    final favorite = inserted.first;
    await dao.setFavorite(favorite.id!, true);
    // 版本表降为旧版本（模拟 v1.8.x 的 1.0.0）
    await VersionDao(db).save(DictionaryVersion(
      version: '1.0.0',
      updateTime: '',
      termsCount: subset.length,
      lastCheckTime: 0,
    ));

    // 执行补齐（模拟升级后启动）
    final service = SeedService(db);
    expect(await service.seedIfNeeded(), isTrue, reason: '应执行增量补齐');

    final after = await dao.getAll();
    expect(after.length, all.length, reason: '应补齐到完整词库');
    final favoriteAfter =
        after.firstWhere((t) => t.englishName == favorite.englishName);
    expect(favoriteAfter.favorite, isTrue, reason: '收藏不能被覆盖');

    // 版本表对齐到内置版本
    final version = await VersionDao(db).get();
    expect(version!.version, AppConfig.seedDictionaryVersion);

    // 再次执行不重复插入
    expect(await service.seedIfNeeded(), isFalse);
  });
}
