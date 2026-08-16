import 'dart:io';

import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

Term makeTerm(String en) {
  return Term(
    englishName: en,
    chineseName: en,
    category: '测试',
    difficulty: 1,
    shortDescription: '简介',
    detailDescription: '详细',
    application: const ['场景'],
    relatedTerms: const ['AI'],
    firstCreated: 0,
  );
}

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    ensureSqliteAvailable();
    tempDir = await Directory.systemTemp.createTemp('backup_test');
    // 使用真实文件数据库（内存库没有可复制的文件路径）。
    db = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      directory: tempDir.path,
    );
    await db.open();
    await TermDao(db).insertAll([makeTerm('Agent'), makeTerm('RAG')]);
  });

  tearDown(() async {
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('到期备份：生成备份文件并记录状态', () async {
    final service = BackupService(db, directory: tempDir.path);

    await service.maybeBackup();

    final backupDir = Directory('${tempDir.path}${Platform.pathSeparator}backups');
    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('auto_backup_'))
        .toList();
    expect(files, hasLength(1));

    // 状态文件记录时间
    final stateFile = File('${tempDir.path}${Platform.pathSeparator}backup_state.json');
    expect(await stateFile.exists(), isTrue);
    expect(await stateFile.readAsString(), contains('last_backup_time'));
  });

  test('间隔内重复调用不重复备份', () async {
    final service = BackupService(db, directory: tempDir.path);

    await service.maybeBackup();
    await service.maybeBackup(); // 间隔内，应跳过

    final backupDir = Directory('${tempDir.path}${Platform.pathSeparator}backups');
    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('auto_backup_'))
        .toList();
    expect(files, hasLength(1));
  });

  test('超过保留上限时清理旧备份（保留最近 5 份）', () async {
    // 直接预置 7 份旧备份 + 伪造过期状态
    final backupDir = Directory('${tempDir.path}${Platform.pathSeparator}backups');
    await backupDir.create(recursive: true);
    for (var i = 0; i < 7; i++) {
      await File('${backupDir.path}${Platform.pathSeparator}auto_backup_2026010${i}_000000.db')
          .writeAsString('data-$i');
    }
    final stale = DateTime.now()
        .subtract(const Duration(days: 8))
        .millisecondsSinceEpoch;
    await File('${tempDir.path}${Platform.pathSeparator}backup_state.json')
        .writeAsString('{"last_backup_time": $stale}');

    final service = BackupService(db, directory: tempDir.path);
    await service.maybeBackup();

    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('auto_backup_'))
        .toList();
    expect(files, hasLength(BackupService.maxBackups));
  });
}
