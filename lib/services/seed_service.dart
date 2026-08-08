import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/config/app_config.dart';
import '../database/app_database.dart';
import '../database/term_dao.dart';
import '../models/term.dart';

/// 种子数据服务：首次启动时将 assets/data/terms 下的 JSON 词库导入 SQLite。
class SeedService {
  SeedService(this.database);

  final AppDatabase database;

  /// 已存在数据则跳过，返回是否执行了导入。
  Future<bool> seedIfNeeded() async {
    final dao = TermDao(database);
    if (await dao.count() > 0) return false;
    final terms = await loadTerms();
    if (terms.isEmpty) return false;
    await dao.insertAll(terms);
    return true;
  }

  /// 读取全部字母 JSON 词库文件并合并为词条列表。
  Future<List<Term>> loadTerms() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <Term>[];
    for (final letter in AppConfig.seedLetters) {
      final path = '${AppConfig.seedAssetFolder}/$letter.json';
      final raw = await rootBundle.loadString(path);
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final term = Term.fromJson(item as Map<String, dynamic>)
            .copyWith(firstCreated: now);
        if (term.englishName.isNotEmpty) result.add(term);
      }
    }
    return result;
  }

  /// 清空词库与历史，并从 JSON 重新导入（设置页“重置数据”使用）。
  Future<void> resetDatabase() async {
    final db = database.database;
    await db.transaction((txn) async {
      await txn.delete('history');
      await txn.delete('terms');
    });
    await seedIfNeeded();
  }
}
