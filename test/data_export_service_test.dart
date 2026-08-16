import 'dart:convert';
import 'dart:io';

import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/database/term_dao.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/services/data_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'test_utils.dart';

Term makeTerm(String en) {
  return Term(
    englishName: en,
    chineseName: en,
    category: '测试',
    difficulty: 1,
    shortDescription: '简介 $en',
    detailDescription: '详细 $en',
    application: const ['场景'],
    relatedTerms: const ['AI'],
    firstCreated: 0,
  );
}

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    ensureSqliteAvailable();
    db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    await TermDao(db).insertAll([makeTerm('Agent'), makeTerm('RAG')]);
    tempDir = await Directory.systemTemp.createTemp('export_test');
  });

  tearDown(() async {
    await db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('导出备份生成合法 JSON 文件（含词条与元信息）', () async {
    final service = DataExportService(db);
    final path = await service.exportBackup(directory: tempDir.path);

    expect(File(path).existsSync(), isTrue);
    expect(p.basename(path), startsWith('ai_dictionary_backup_'));

    final decoded = jsonDecode(await File(path).readAsString());
    expect(decoded['app'], 'AI Dictionary');
    expect(decoded['format_version'], 1);
    expect(decoded['exported_at'], isA<String>());
    final terms = decoded['terms'] as List;
    expect(terms, hasLength(2));
    final first = terms.first as Map<String, dynamic>;
    expect(first['english_name'], isNotEmpty);
    expect(first['chinese_name'], isNotEmpty);
  });

  test('备份目录自动创建（多级路径）', () async {
    final nested = p.join(tempDir.path, 'a', 'b');
    final service = DataExportService(db);
    final path = await service.exportBackup(directory: nested);

    expect(File(path).existsSync(), isTrue);
    expect(p.dirname(path), p.join(nested, 'AIDictionary', 'backups'));
  });
}
