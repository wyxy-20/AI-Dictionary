import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/ai_config.dart';
import 'app_database.dart';

/// ai_settings 表的数据访问层（单行）。
class AiSettingsDao {
  AiSettingsDao(this.database);

  final AppDatabase database;

  Database get _db => database.database;

  Future<AiConfig> get() async {
    final rows = await _db.query('ai_settings', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      const config = AiConfig();
      await _db.insert('ai_settings', config.toMap());
      return config;
    }
    return AiConfig.fromMap(rows.first);
  }

  Future<void> save(AiConfig config) async {
    await _db.insert(
      'ai_settings',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
