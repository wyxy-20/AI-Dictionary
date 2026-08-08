import 'package:flutter/material.dart';

import '../database/settings_dao.dart';
import '../models/app_settings.dart';

/// 设置状态：主题、语言。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this.dao);

  final SettingsDao dao;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  ThemeMode get themeMode {
    return switch (_settings.theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> load() async {
    _settings = await dao.getSettings();
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    await dao.updateTheme(theme);
    _settings = _settings.copyWith(theme: theme);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    await dao.updateLanguage(language);
    _settings = _settings.copyWith(language: language);
    notifyListeners();
  }
}
