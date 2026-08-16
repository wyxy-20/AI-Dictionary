import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../database/term_dao.dart';

/// 数据管理服务：导出词库备份。
class DataExportService {
  DataExportService(this.database);

  final AppDatabase database;

  /// 将词库导出为 JSON 备份文件，返回文件路径。
  ///
  /// [directory] 用于测试注入备份目录；为空时导出到
  /// `文档/AIDictionary/backups`（path_provider 不可用时回退到当前目录）。
  Future<String> exportBackup({String? directory}) async {
    final terms = await TermDao(database).getAll();
    final payload = jsonEncode({
      'app': 'AI Dictionary',
      'format_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'terms': terms.map((t) => t.toJson()).toList(),
    });

    Directory base;
    if (directory != null) {
      base = Directory(directory);
    } else {
      try {
        base = await getApplicationDocumentsDirectory();
      } catch (_) {
        base = Directory.current;
      }
    }
    final dir = Directory(p.join(base.path, 'AIDictionary', 'backups'));
    await dir.create(recursive: true);

    final stamp = DateTime.now()
        .toString()
        .split('.')
        .first
        .replaceAll(':', '-')
        .replaceAll(' ', '_');
    final file = File(p.join(dir.path, 'ai_dictionary_backup_$stamp.json'));
    await file.writeAsString(payload, flush: true);
    return file.path;
  }

  /// 在资源管理器中定位并选中指定文件（Windows）。
  Future<void> revealInExplorer(String path) async {
    await Process.run('explorer.exe', ['/select,', path]);
  }
}
