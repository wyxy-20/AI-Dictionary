import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../utils/app_logger.dart';

/// 自动备份：定期（默认 7 天）把数据库文件复制到
/// `应用支持目录/backups/` 下，保留最近 [maxBackups] 份。
///
/// 上次备份时间记录在同目录的 [stateFileName] 中（避免改动数据库结构）。
/// 所有失败静默并记日志——备份绝不影响启动。
class BackupService {
  BackupService(this.database, {this._directory});

  final AppDatabase database;
  final String? _directory;

  /// 自动备份最多保留的份数。
  static const int maxBackups = 5;

  /// 自动备份间隔。
  static const Duration interval = Duration(days: 7);

  static const String stateFileName = 'backup_state.json';
  static const String backupFolderName = 'backups';

  /// 执行一次"到期才备份"检查：
  /// 距上次备份不足 [interval] 则跳过，否则备份并清理旧文件。
  ///
  /// 未指定备份目录（如内存数据库测试环境）时直接跳过——
  /// 正常应用流程由 main.dart 传入 `database.directory`。
  Future<void> maybeBackup() async {
    try {
      final dir = _directory;
      if (dir == null) return;

      final stateFile = File(p.join(dir, stateFileName));
      final last = await _readLastBackupTime(stateFile);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (last != null && now - last < interval.inMilliseconds) return;

      final backupDir = Directory(p.join(dir, backupFolderName));
      await backupDir.create(recursive: true);

      final dbPath = database.database.path;
      final stamp = _stamp(DateTime.now());
      final backupName = 'auto_backup_$stamp.db';
      await File(dbPath).copy(p.join(backupDir.path, backupName));

      await _prune(backupDir);
      await stateFile.writeAsString(jsonEncode({'last_backup_time': now}));
      await AppLogger.instance
          .info('backup', '自动备份完成：$backupName（保留 $maxBackups 份）');
    } catch (e) {
      await AppLogger.instance.warn('backup', '自动备份失败：$e');
    }
  }

  Future<int?> _readLastBackupTime(File stateFile) async {
    try {
      if (!await stateFile.exists()) return null;
      final decoded = jsonDecode(await stateFile.readAsString());
      if (decoded is Map<String, dynamic>) {
        return (decoded['last_backup_time'] as num?)?.toInt();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 清理旧备份，只保留最新的 [maxBackups] 份（文件名时间戳可排序）。
  Future<void> _prune(Directory backupDir) async {
    final files = await backupDir
        .list()
        .where((e) => e is File && p.basename(e.path).startsWith('auto_backup_'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    final toDelete = files.length - maxBackups;
    for (var i = 0; i < toDelete; i++) {
      await files[i].delete();
    }
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
