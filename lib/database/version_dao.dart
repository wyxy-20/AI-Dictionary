import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/dictionary_version.dart';
import 'app_database.dart';

/// dictionary_version 表的数据访问层（单行）。
class VersionDao {
  VersionDao(this.database);

  final AppDatabase database;

  Database get _db => database.database;

  Future<DictionaryVersion?> get() async {
    final rows = await _db.query('dictionary_version', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : DictionaryVersion.fromMap(rows.first);
  }

  Future<void> save(DictionaryVersion version) async {
    await _db.insert(
      'dictionary_version',
      version.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 记录一次成功检查（无论是否真正更新）。
  Future<void> updateLastCheckTime(int time) async {
    final rows = await _db.query('dictionary_version', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      await save(DictionaryVersion(
        version: '1.0.0',
        lastCheckTime: time,
      ));
    } else {
      await _db.update(
        'dictionary_version',
        {'last_check_time': time},
        where: 'id = 1',
      );
    }
  }
}
