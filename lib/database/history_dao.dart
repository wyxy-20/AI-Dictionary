import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/config/app_config.dart';
import '../models/term.dart';
import 'app_database.dart';

/// history 表的数据访问层：保存最近查看的词条。
class HistoryDao {
  HistoryDao(this.database);

  final AppDatabase database;

  Database get _db => database.database;

  /// 记录一次查看：同一词条只保留最新一条记录。
  Future<void> recordView(int termId) async {
    await _db.transaction((txn) async {
      // 保证 view_time 严格递增，避免同一毫秒内排序不稳定。
      final maxRow = await txn.rawQuery(
        'SELECT MAX(view_time) AS mt FROM history',
      );
      var now = DateTime.now().millisecondsSinceEpoch;
      final maxTime = maxRow.first['mt'] as int?;
      if (maxTime != null && now <= maxTime) now = maxTime + 1;

      await txn.delete('history', where: 'term_id = ?', whereArgs: [termId]);
      await txn.insert('history', {
        'term_id': termId,
        'view_time': now,
      });
      final overflow = await txn.rawQuery(
        'SELECT id FROM history ORDER BY view_time DESC LIMIT -1 OFFSET ?',
        [AppConfig.maxHistoryEntries],
      );
      if (overflow.isNotEmpty) {
        final ids = overflow.map((r) => r['id']).toList();
        final placeholders = List.filled(ids.length, '?').join(',');
        await txn.delete(
          'history',
          where: 'id IN ($placeholders)',
          whereArgs: ids,
        );
      }
    });
  }

  /// 按查看时间倒序返回最近查看的词条（去重）。
  Future<List<Term>> getRecentTerms({int? limit}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT t.* FROM history h
      JOIN terms t ON t.id = h.term_id
      ORDER BY h.view_time DESC
      LIMIT ?
      ''',
      [limit ?? AppConfig.recentLimit],
    );
    return rows.map(Term.fromMap).toList();
  }

  Future<void> clear() async {
    await _db.delete('history');
  }
}
