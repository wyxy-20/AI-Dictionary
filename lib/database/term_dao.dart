import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/term.dart';
import 'app_database.dart';

/// terms 表的数据访问层。
class TermDao {
  TermDao(this.database);

  final AppDatabase database;

  Database get _db => database.database;

  Future<List<Term>> getAll() async {
    final rows = await _db.query(
      'terms',
      orderBy: 'english_name COLLATE NOCASE ASC',
    );
    return rows.map(Term.fromMap).toList();
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM terms');
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> insertAll(List<Term> terms) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final term in terms) {
        batch.insert('terms', term.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Term?> byId(int id) async {
    final rows = await _db.query('terms', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Term.fromMap(rows.first);
  }

  Future<Term?> byEnglishName(String englishName) async {
    final rows = await _db.query(
      'terms',
      where: 'english_name = ? COLLATE NOCASE',
      whereArgs: [englishName],
      limit: 1,
    );
    return rows.isEmpty ? null : Term.fromMap(rows.first);
  }

  Future<void> setFavorite(int id, bool favorite) async {
    await _db.update(
      'terms',
      {'favorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Term>> getFavorites() async {
    final rows = await _db.query(
      'terms',
      where: 'favorite = 1',
      orderBy: 'english_name COLLATE NOCASE ASC',
    );
    return rows.map(Term.fromMap).toList();
  }
}
