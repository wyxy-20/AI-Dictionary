import 'dart:io';

import 'package:ai_dictionary/database/ai_settings_dao.dart';
import 'package:ai_dictionary/database/app_database.dart';
import 'package:ai_dictionary/models/ai_config.dart';
import 'package:ai_dictionary/services/ai/secure_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

/// 可逆的假加密实现：用于证明 DAO 确实对落盘值做了变换。
class ReverseSecureKeyStore implements SecureKeyStore {
  const ReverseSecureKeyStore();

  static const _p = 'rev:';

  @override
  bool isEncrypted(String stored) => stored.startsWith(_p);

  @override
  String protect(String plain) =>
      plain.isEmpty ? '' : '$_p${plain.split('').reversed.join()}';

  @override
  String unprotect(String stored) => isEncrypted(stored)
      ? stored.substring(_p.length).split('').reversed.join()
      : stored;
}

void main() {
  setUp(ensureSqliteAvailable);

  test('保存时 API Key 加密落盘，读取时自动解密', () async {
    final db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    final dao = AiSettingsDao(db, keyStore: const ReverseSecureKeyStore());
    await dao.save(const AiConfig(apiKey: 'sk-12345'));

    final rows = await db.database.query('ai_settings', where: 'id = 1');
    final stored = rows.first['api_key'] as String;
    expect(stored, isNot('sk-12345'));
    expect(stored, startsWith('rev:'));

    final config = await dao.get();
    expect(config.apiKey, 'sk-12345');
    await db.close();
  });

  test('旧版明文 API Key 自动迁移为加密存储', () async {
    final db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    await db.database.insert(
      'ai_settings',
      const AiConfig(apiKey: 'sk-legacy').toMap(),
    );

    final dao = AiSettingsDao(db, keyStore: const ReverseSecureKeyStore());
    final config = await dao.get();
    expect(config.apiKey, 'sk-legacy');

    final rows = await db.database.query('ai_settings', where: 'id = 1');
    expect(rows.first['api_key'], startsWith('rev:'));
    await db.close();
  });

  test('未注入加密实现时保持明文存储（向后兼容）', () async {
    final db = AppDatabase(factory: databaseFactoryFfiNoIsolate);
    await db.openInMemory();
    final dao = AiSettingsDao(db);
    await dao.save(const AiConfig(apiKey: 'sk-plain'));

    final rows = await db.database.query('ai_settings', where: 'id = 1');
    expect(rows.first['api_key'], 'sk-plain');

    final config = await dao.get();
    expect(config.apiKey, 'sk-plain');
    await db.close();
  });

  test('Windows DPAPI 加解密往返一致', () {
    if (!Platform.isWindows) return;
    final store = WindowsDpapiKeyStore();
    const secret = 'sk-test-dpapi-roundtrip-2026';
    final stored = store.protect(secret);
    expect(stored, startsWith(WindowsDpapiKeyStore.prefix));
    expect(stored, isNot(contains(secret)));
    expect(store.unprotect(stored), secret);
    // 旧明文数据直接返回，不做解密
    expect(store.unprotect('legacy-plain'), 'legacy-plain');
  });
}
