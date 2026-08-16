import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/config/app_config.dart';
import '../database/app_database.dart';
import '../database/term_dao.dart';
import '../database/version_dao.dart';
import '../models/dictionary_version.dart';
import '../models/term.dart';
import '../utils/version_utils.dart';

/// 种子数据服务：首次启动时将 assets/data/terms 下的 JSON 词库导入 SQLite。
///
/// 三种场景：
/// 1. 空库 -> 全量导入内置词库；
/// 2. 已有部分词条但少于内置词库（旧版本升级，如内置 319 条的 v1.8.x）：
///    增量补齐缺失词条，保留收藏与历史，并把本地词库版本对齐到内置版本；
/// 3. 词条数已满足 -> 跳过。
class SeedService {
  SeedService(this.database);

  final AppDatabase database;

  /// 已存在数据则跳过，返回是否执行了导入。
  Future<bool> seedIfNeeded() async {
    final dao = TermDao(database);
    final count = await dao.count();

    if (count == 0) {
      // 空库：全量导入内置词库
      final terms = await loadTerms();
      if (terms.isEmpty) return false;
      await dao.insertAll(terms);
      await _alignVersionTable(terms.length);
      return true;
    }

    // 本地词库版本已对齐内置版本：数据已是最新（含用户数据），跳过。
    // 注意：不加载词库文件，避免无谓开销（测试环境也依赖此短路）。
    final versionDao = VersionDao(database);
    final local = await versionDao.get();
    if (local != null &&
        VersionUtils.compare(
              local.version,
              AppConfig.seedDictionaryVersion,
            ) >=
            0) {
      return false;
    }

    // 旧版本升级：内置词库版本高于本地，补齐缺失词条（保留收藏/历史）。
    final terms = await loadTerms();
    if (terms.isEmpty) return false;
    if (count < terms.length) {
      final existing = await dao.getAll();
      final existingNames = {
        for (final t in existing) t.englishName.trim().toLowerCase(),
      };
      final missing = terms
          .where(
            (t) => !existingNames.contains(t.englishName.trim().toLowerCase()),
          )
          .toList();
      if (missing.isNotEmpty) {
        await dao.insertAll(missing);
        await _alignVersionTable(terms.length);
        return true;
      }
    }
    return false;
  }

  /// 本地词库版本低于内置种子版本时对齐（避免后续重复下载 / 节流混乱）。
  Future<void> _alignVersionTable(int termsCount) async {
    try {
      final versionDao = VersionDao(database);
      final local = await versionDao.get();
      if (local == null ||
          VersionUtils.compare(
                local.version,
                AppConfig.seedDictionaryVersion,
              ) <
              0) {
        await versionDao.save(DictionaryVersion(
          version: AppConfig.seedDictionaryVersion,
          updateTime: '',
          termsCount: termsCount,
          lastCheckTime: local?.lastCheckTime ?? 0,
        ));
      }
    } catch (_) {
      // 版本表对齐失败不影响词条导入。
    }
  }

  /// 读取内置完整词库 JSON 并解析为词条列表。
  Future<List<Term>> loadTerms() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final raw = await rootBundle.loadString(AppConfig.seedTermsFile);
    final list = jsonDecode(raw) as List<dynamic>;
    final result = <Term>[];
    for (final item in list) {
      final term = Term.fromJson(item as Map<String, dynamic>)
          .copyWith(firstCreated: now);
      if (term.englishName.isNotEmpty) result.add(term);
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
