import 'dart:io';

import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_utils.dart';

void main() {
  test('v2 -> v3 迁移：新增 version 列与 AI 表，旧数据完好', () async {
    ensureSqliteAvailable();

    final dir = Directory.systemTemp.createTempSync('ai_dict_migrate_');
    final path = p.join(dir.path, 'ai_dictionary.db');

    // 构造一个 v2 版本的旧数据库（与旧版 schema 一致，并写入旧数据）
    final raw = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE terms (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              english_name TEXT NOT NULL UNIQUE,
              chinese_name TEXT NOT NULL,
              category TEXT NOT NULL DEFAULT '未分类',
              difficulty INTEGER NOT NULL DEFAULT 1,
              short_description TEXT NOT NULL DEFAULT '',
              detail_description TEXT NOT NULL DEFAULT '',
              application TEXT NOT NULL DEFAULT '[]',
              related_terms TEXT NOT NULL DEFAULT '[]',
              first_created INTEGER NOT NULL,
              favorite INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              term_id INTEGER NOT NULL,
              view_time INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE settings (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              theme TEXT NOT NULL DEFAULT 'system',
              language TEXT NOT NULL DEFAULT 'zh'
            )
          ''');
          await db.execute('''
            CREATE TABLE dictionary_version (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              version TEXT NOT NULL DEFAULT '1.0.0',
              update_time TEXT NOT NULL DEFAULT '',
              terms_count INTEGER NOT NULL DEFAULT 0,
              last_check_time INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.insert('terms', {
            'english_name': 'Transformer',
            'chinese_name': 'Transformer',
            'category': '深度学习',
            'difficulty': 2,
            'short_description': '旧简介',
            'detail_description': '旧详细',
            'application': '["a"]',
            'related_terms': '["AI"]',
            'first_created': 1,
            'favorite': 1,
          });
          await db.insert('history', {'term_id': 1, 'view_time': 123});
          await db.insert('settings', {'id': 1, 'theme': 'dark', 'language': 'zh'});
          await db.insert('dictionary_version', {
            'id': 1,
            'version': '1.0.0',
            'update_time': '',
            'terms_count': 1,
            'last_check_time': 0,
          });
        },
      ),
    );
    await raw.close();

    // 用新版本 AppDatabase 打开，触发 2 -> 3 迁移
    final db = AppDatabase(factory: databaseFactoryFfiNoIsolate, directory: dir.path);
    await db.open();

    final userVersion =
        (await db.database.rawQuery('PRAGMA user_version')).first.values.first;
    expect(userVersion, 4);

    final columns = await db.database.rawQuery('PRAGMA table_info(terms)');
    expect(columns.map((c) => c['name']), contains('version'));

    final tables = await db.database
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final tableNames = tables.map((t) => t['name']).toSet();
    expect(tableNames, contains('ai_explanation_cache'));
    expect(tableNames, contains('ai_settings'));

    // 旧数据完好
    final terms = await TermDao(db).getAll();
    expect(terms.length, 1);
    final term = terms.first;
    expect(term.englishName, 'Transformer');
    expect(term.version, 1, reason: '旧词条 version 默认 1');
    expect(term.favorite, isTrue);

    final history = await db.database.query('history');
    expect(history.length, 1);
    final settings = await db.database.query('settings');
    expect(settings.first['theme'], 'dark');
    final settingsColumns =
        await db.database.rawQuery('PRAGMA table_info(settings)');
    final settingsNames = settingsColumns.map((c) => c['name']).toSet();
    expect(settingsNames, contains('quick_search_hotkey'));
    expect(settingsNames, contains('quick_search_enabled'));
    expect(settings.first['quick_search_hotkey'], 'Ctrl+K');
    expect(settings.first['quick_search_enabled'], 0);

    await db.close();
    dir.deleteSync(recursive: true);
  });
}
