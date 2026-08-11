import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/app_settings.dart';
import 'app_database.dart';

/// settings 表的数据访问层（单行）。
class SettingsDao {
  SettingsDao(this.database);

  final AppDatabase database;

  Database get _db => database.database;

  Future<AppSettings> getSettings() async {
    final rows = await _db.query('settings', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      const settings = AppSettings();
      await _db.insert('settings', {
        'id': 1,
        'theme': settings.theme,
        'language': settings.language,
      });
      return settings;
    }
    return AppSettings.fromMap(rows.first);
  }

  Future<void> updateTheme(String theme) async {
    await _db.update('settings', {'theme': theme}, where: 'id = 1');
  }

  Future<void> updateLanguage(String language) async {
    await _db.update('settings', {'language': language}, where: 'id = 1');
  }

  Future<void> updateQuickSearchHotkey(String hotkey) async {
    await _db.update(
      'settings',
      {'quick_search_hotkey': hotkey},
      where: 'id = 1',
    );
  }

  Future<void> updateQuickSearchEnabled(bool enabled) async {
    await _db.update(
      'settings',
      {'quick_search_enabled': enabled ? 1 : 0},
      where: 'id = 1',
    );
  }
}
