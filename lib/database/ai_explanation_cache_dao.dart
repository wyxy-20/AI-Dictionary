import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/ai_explanation.dart';
import 'app_database.dart';

/// ai_explanation_cache 表的数据访问层。
class AiExplanationCacheDao {
  AiExplanationCacheDao(this.database);

  final AppDatabase database;

  Database get _db => database.database;

  /// 查找指定词条 + 版本 + 模型的有效缓存。
  Future<AiExplanation?> findValid(
    int termId,
    int termVersion,
    String modelName,
  ) async {
    final rows = await _db.query(
      'ai_explanation_cache',
      where: 'term_id = ? AND term_version = ? AND model_name = ?',
      whereArgs: [termId, termVersion, modelName],
      orderBy: 'updated_time DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : AiExplanation.fromMap(rows.first);
  }

  /// 写入缓存：同一词条保留最新一条（删除旧记录后插入）。
  Future<void> upsert(AiExplanation explanation) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'ai_explanation_cache',
        where: 'term_id = ?',
        whereArgs: [explanation.termId],
      );
      await txn.insert('ai_explanation_cache', explanation.toMap());
    });
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM ai_explanation_cache');
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> clear() async {
    await _db.delete('ai_explanation_cache');
  }
}
