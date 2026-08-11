import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 调试工具：打印最近的浏览历史（用于验证快捷搜索是否选中词条）。
Future<void> main() async {
  sqfliteFfiInit();
  final appData = Platform.environment['APPDATA'];
  if (appData == null) {
    stdout.writeln('APPDATA not set');
    return;
  }
  final path =
      p.join(appData, 'com.aidictionary', 'AI Dictionary', 'ai_dictionary.db');
  if (!File(path).existsSync()) {
    stdout.writeln('DB not found: $path');
    return;
  }
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(readOnly: true),
  );
  final rows = await db.rawQuery(
    'SELECT h.id, t.english_name, h.view_time FROM history h '
    'JOIN terms t ON t.id = h.term_id ORDER BY h.view_time DESC LIMIT 8',
  );
  for (final row in rows) {
    stdout.writeln(row);
  }
  await db.close();
}
