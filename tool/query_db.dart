// 开发工具：直接查询应用数据库（词条数 / 版本 / 收藏）。
// ignore_for_file: avoid_print
import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  final dbPath = args.isEmpty
      ? r'<appdata>\com.aidictionary\AI Dictionary\ai_dictionary.db'
      : args.first;
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
