import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/config/app_config.dart';

/// SQLite 数据库封装。
///
/// 桌面端使用 sqflite_common_ffi 驱动；测试时可传入内存数据库。
class AppDatabase {
  AppDatabase({this.factory, this.directory});

  final DatabaseFactory? factory;
  String? directory;
  Database? _db;

  DatabaseFactory get _effectiveFactory => factory ?? databaseFactoryFfi;

  Database get database {
    final db = _db;
    if (db == null) {
      throw StateError('数据库尚未打开，请先调用 open()。');
    }
    return db;
  }

  /// 打开（或创建）应用数据目录下的数据库文件。
  Future<void> open() async {
    if (_db != null) return;
    sqfliteFfiInit();
    final dir = directory ?? (await getApplicationSupportDirectory()).path;
    directory = dir;
    await Directory(dir).create(recursive: true);
    final path = p.join(dir, AppConfig.databaseFileName);
    _db = await _effectiveFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppConfig.databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// 使用内存数据库（测试用）。
  Future<void> openInMemory() async {
    if (_db != null) return;
    sqfliteFfiInit();
    _db = await _effectiveFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppConfig.databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
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
        view_time INTEGER NOT NULL,
        FOREIGN KEY (term_id) REFERENCES terms(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_history_term ON history(term_id)');
    await db.execute('CREATE INDEX idx_history_time ON history(view_time DESC)');
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        theme TEXT NOT NULL DEFAULT 'system',
        language TEXT NOT NULL DEFAULT 'zh'
      )
    ''');
    await _createVersionTable(db);
    await _initVersionRow(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createVersionTable(db);
      await _initVersionRow(db);
    }
  }

  Future<void> _createVersionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dictionary_version (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        version TEXT NOT NULL DEFAULT '1.0.0',
        update_time TEXT NOT NULL DEFAULT '',
        terms_count INTEGER NOT NULL DEFAULT 0,
        last_check_time INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _initVersionRow(Database db) async {
    await db.insert('dictionary_version', {
      'id': 1,
      'version': AppConfig.seedDictionaryVersion,
      'update_time': '',
      'terms_count': 0,
      'last_check_time': 0,
    });
  }
}
