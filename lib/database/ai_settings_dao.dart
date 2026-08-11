import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/config/app_config.dart';
import '../models/ai_config.dart';
import '../services/ai/secure_key_store.dart';
import 'app_database.dart';

/// ai_settings 表的数据访问层（单行）。
class AiSettingsDao {
  AiSettingsDao(this.database, {SecureKeyStore? keyStore})
      : _keyStore = keyStore ?? const NoopSecureKeyStore();

  final AppDatabase database;
  final SecureKeyStore _keyStore;

  Database get _db => database.database;

  Future<AiConfig> get() async {
    final rows = await _db.query('ai_settings', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      const config = AiConfig();
      await _db.insert('ai_settings', config.toMap());
      return config;
    }
    final row = rows.first;
    final storedKey = row['api_key'] as String? ?? '';
    final plainKey = _keyStore.isEncrypted(storedKey)
        ? _keyStore.unprotect(storedKey)
        : storedKey;
    if (plainKey.isNotEmpty && !_keyStore.isEncrypted(storedKey)) {
      // 旧版明文数据：立即迁移为加密存储
      await _db.update(
        'ai_settings',
        {'api_key': _keyStore.protect(plainKey)},
        where: 'id = 1',
      );
    }
    return AiConfig(
      baseUrl: row['base_url'] as String? ?? AppConfig.defaultAiBaseUrl,
      apiKey: plainKey,
      modelName: row['model_name'] as String? ?? AppConfig.defaultAiModelName,
    );
  }

  Future<void> save(AiConfig config) async {
    final map = config.toMap();
    map['api_key'] =
        config.apiKey.isEmpty ? '' : _keyStore.protect(config.apiKey);
    await _db.insert(
      'ai_settings',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
