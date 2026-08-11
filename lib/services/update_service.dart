import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../database/app_database.dart';
import '../database/term_dao.dart';
import '../database/version_dao.dart';
import '../models/dictionary_version.dart';
import '../models/term.dart';
import '../utils/version_utils.dart';

/// 同步过程中的阶段（用于启动页本地化状态展示）。
enum SyncStage { checking, downloading, updating, done }

/// 一次同步的结果。
class SyncResult {
  const SyncResult._(
    this.status,
    this.message, {
    this.version,
    this.addedCount,
    this.updatedCount = 0,
  });

  /// skipped：24 小时内已检查；upToDate：已是最新；updated：完成增量更新；
  /// failed：网络异常，已降级到本地词库。
  final String status;
  final String message;
  final String? version;
  final int? addedCount;
  final int updatedCount;

  bool get isUpdated => status == 'updated';

  factory SyncResult.skipped(String version) =>
      SyncResult._('skipped', '24 小时内已检查过更新', version: version);

  factory SyncResult.upToDate(String version) =>
      SyncResult._('upToDate', '本地词库已是最新版本', version: version);

  factory SyncResult.updated(String version, int added, {int updated = 0}) {
    final updateText =
        updated > 0 ? '，更新 $updated 个词条内容' : '';
    return SyncResult._(
      'updated',
      '词库已更新到 $version，新增 $added 个词条$updateText',
      version: version,
      addedCount: added,
      updatedCount: updated,
    );
  }

  factory SyncResult.failed() => const SyncResult._(
        'failed',
        '网络不可用或远程词库无法访问，使用本地词库',
      );
}

/// 启动自动同步词库服务：
/// 检查远程 version.json -> 比较本地版本 -> 增量下载新词条 -> 更新 SQLite。
///
/// 任何网络异常都不会抛错，统一降级为使用本地词库。
class UpdateService {
  UpdateService(
    this.database, {
    this.client,
    String? baseUrl,
    this.onProgress,
  }) : _baseUrl = baseUrl ?? AppConfig.remoteDictionaryBaseUrl;

  final AppDatabase database;

  /// 注入的自定义 HTTP 客户端（测试用）；为空时内部自动创建。
  final http.Client? client;
  final String _baseUrl;
  final void Function(SyncStage stage)? onProgress;

  /// 执行一次同步。
  ///
  /// [force] 为 true 时忽略 24 小时检查间隔（用于测试 / 手动触发）。
  Future<SyncResult> syncIfNeeded({bool force = false}) async {
    final httpClient = client ?? http.Client();
    try {
      final versionDao = VersionDao(database);
      final local = await versionDao.get();
      final now = DateTime.now().millisecondsSinceEpoch;

      // 24 小时内已成功检查过：跳过，避免重复下载。
      if (!force &&
          local != null &&
          now - local.lastCheckTime <
              AppConfig.remoteCheckInterval.inMilliseconds) {
        return SyncResult.skipped(local.version);
      }

      onProgress?.call(SyncStage.checking);
      final remote = await _fetchVersion(httpClient);
      await versionDao.updateLastCheckTime(now);

      if (local != null &&
          VersionUtils.compare(local.version, remote.version) >= 0) {
        return SyncResult.upToDate(local.version);
      }

      onProgress?.call(SyncStage.downloading);
      final terms = await _fetchTerms(httpClient);

      onProgress?.call(SyncStage.updating);
      final incremental = await _applyIncremental(terms);
      final added = incremental.$1;
      final updated = incremental.$2;

      await versionDao.save(DictionaryVersion(
        version: remote.version,
        updateTime: remote.updateTime,
        termsCount: terms.length,
        lastCheckTime: now,
      ));
      onProgress?.call(SyncStage.done);
      return SyncResult.updated(remote.version, added, updated: updated);
    } on Exception {
      // 网络异常 / 远程不可达 / 数据解析失败：静默降级到本地词库。
      return SyncResult.failed();
    } finally {
      if (client == null) httpClient.close();
    }
  }

  Future<DictionaryVersion> _fetchVersion(http.Client client) async {
    final uri = Uri.parse('$_baseUrl/version.json');
    final response = await client.get(uri).timeout(AppConfig.remoteTimeout);
    if (response.statusCode != 200) {
      throw UpdateServiceException('version.json HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateServiceException('version.json 格式错误');
    }
    final remote = DictionaryVersion.fromJson(decoded);
    if (remote.version.isEmpty) {
      throw const UpdateServiceException('version.json 缺少版本号');
    }
    return remote;
  }

  Future<List<Term>> _fetchTerms(http.Client client) async {
    final uri = Uri.parse('$_baseUrl/terms.json');
    final response = await client.get(uri).timeout(AppConfig.remoteTimeout);
    if (response.statusCode != 200) {
      throw UpdateServiceException('terms.json HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> ? decoded['terms'] : null);
    if (list is! List) {
      throw const UpdateServiceException('terms.json 格式错误');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final seen = <String>{};
    final terms = <Term>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final term = Term.fromJson(item).copyWith(firstCreated: now);
      final key = term.englishName.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      terms.add(term);
    }
    return terms;
  }

  /// 增量更新：
  /// - 本地不存在的词条 -> 插入；
  /// - 已存在但内容变化的词条 -> 更新内容并 version +1（旧 AI 缓存失效）；
  /// - 不删除任何词条，不影响收藏、浏览历史等用户数据。
  ///
  /// 返回 (新增数, 内容更新数)。
  Future<(int, int)> _applyIncremental(List<Term> remoteTerms) async {
    if (remoteTerms.isEmpty) return (0, 0);
    final termDao = TermDao(database);
    final existing = await termDao.getAll();
    final existingByLower = {
      for (final t in existing) t.englishName.trim().toLowerCase(): t,
    };
    final newTerms = <Term>[];
    var updated = 0;
    for (final term in remoteTerms) {
      final key = term.englishName.trim().toLowerCase();
      final current = existingByLower[key];
      if (current == null) {
        newTerms.add(term);
      } else if (await termDao.updateContentIfChanged(current, term)) {
        updated++;
      }
    }
    var added = 0;
    if (newTerms.isNotEmpty) {
      await termDao.insertAll(newTerms);
      added = newTerms.length;
    }
    return (added, updated);
  }
}

class UpdateServiceException implements Exception {
  const UpdateServiceException(this.message);

  final String message;

  @override
  String toString() => 'UpdateServiceException: $message';
}
