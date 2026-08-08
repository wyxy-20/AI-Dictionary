import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/history_dao.dart';
import 'package:ai_dictionary/database/settings_dao.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

Term makeTerm(String en, {String zh = '', String category = '测试'}) {
  return Term(
    englishName: en,
    chineseName: zh.isEmpty ? en : zh,
    category: category,
    difficulty: 1,
    shortDescription: '简介 $en',
    detailDescription: '详细介绍 $en',
    application: const ['场景一'],
    relatedTerms: const ['AI'],
    firstCreated: 0,
  );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    ensureSqliteAvailable();
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
  });

  tearDown(() async {
    await db.close();
  });

  test('建表并插入词条', () async {
    final dao = TermDao(db);
    expect(await dao.count(), 0);
    await dao.insertAll([makeTerm('Agent'), makeTerm('RAG'), makeTerm('LLM')]);
    expect(await dao.count(), 3);
    final all = await dao.getAll();
    expect(all.map((t) => t.englishName), containsAll(['Agent', 'RAG', 'LLM']));
  });

  test('词条按英文名排序（忽略大小写）', () async {
    final dao = TermDao(db);
    await dao.insertAll([
      makeTerm('llm'),
      makeTerm('Agent'),
      makeTerm('RAG'),
      makeTerm('api'),
    ]);
    final all = await dao.getAll();
    expect(all.map((t) => t.englishName).toList(), ['Agent', 'api', 'llm', 'RAG']);
  });

  test('收藏切换', () async {
    final dao = TermDao(db);
    await dao.insertAll([makeTerm('Agent')]);
    final term = (await dao.getAll()).first;
    await dao.setFavorite(term.id!, true);
    expect((await dao.getFavorites()).length, 1);
    await dao.setFavorite(term.id!, false);
    expect(await dao.getFavorites(), isEmpty);
  });

  test('历史记录去重且按时间倒序', () async {
    final termDao = TermDao(db);
    final historyDao = HistoryDao(db);
    await termDao.insertAll([makeTerm('A'), makeTerm('B'), makeTerm('C')]);
    final all = await termDao.getAll();

    await historyDao.recordView(all[0].id!);
    await historyDao.recordView(all[1].id!);
    await historyDao.recordView(all[2].id!);
    await historyDao.recordView(all[0].id!); // 重复查看 A，应更新顺序

    final recent = await historyDao.getRecentTerms();
    expect(recent.map((t) => t.englishName).toList(), ['A', 'C', 'B']);
  });

  test('历史记录限制条数', () async {
    final termDao = TermDao(db);
    final historyDao = HistoryDao(db);
    final terms = [for (var i = 0; i < 15; i++) makeTerm('Term$i')];
    await termDao.insertAll(terms);
    final all = await termDao.getAll();
    for (final t in all) {
      await historyDao.recordView(t.id!);
    }
    final recent = await historyDao.getRecentTerms(limit: 10);
    expect(recent.length, 10);
  });

  test('设置读写', () async {
    final dao = SettingsDao(db);
    final initial = await dao.getSettings();
    expect(initial.theme, 'system');
    expect(initial.language, 'zh');

    await dao.updateTheme('dark');
    await dao.updateLanguage('en');
    final updated = await dao.getSettings();
    expect(updated.theme, 'dark');
    expect(updated.language, 'en');
  });

  test('清空历史', () async {
    final termDao = TermDao(db);
    final historyDao = HistoryDao(db);
    await termDao.insertAll([makeTerm('A')]);
    final term = (await termDao.getAll()).first;
    await historyDao.recordView(term.id!);
    expect((await historyDao.getRecentTerms()).length, 1);
    await historyDao.clear();
    expect(await historyDao.getRecentTerms(), isEmpty);
  });
}
