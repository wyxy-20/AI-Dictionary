// 开发工具：直接查询应用数据库（词条数 / 版本 / 收藏）。
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final dbPath = args.isEmpty ? _defaultDbPath() : args.first;
  final db = sqlite3.open(dbPath);
  final terms = db.select('SELECT COUNT(*) AS c FROM terms').first['c'];
  final version =
      db.select('SELECT version, terms_count, last_check_time FROM dictionary_version');
  final favorites = db.select('SELECT COUNT(*) AS c FROM terms WHERE favorite = 1').first['c'];
  print('词条总数: $terms');
  print('收藏数: $favorites');
  print('词库版本表: $version');
  db.close();
}

/// 默认数据库路径：从 APPDATA 环境变量动态获取，避免硬编码本机路径。
String _defaultDbPath() {
  final appData = Platform.environment['APPDATA'];
  if (appData == null || appData.isEmpty) {
    throw StateError('APPDATA 环境变量未设置，请通过参数指定数据库路径');
  }
  return '$appData\\com.aidictionary\\AI Dictionary\\ai_dictionary.db';
}
