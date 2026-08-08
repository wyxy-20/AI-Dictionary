import 'package:flutter/material.dart';

/// UI 常量：难度标签、主题选项等。
class AppConstants {
  AppConstants._();

  static const List<String> difficultyLabels = ['入门', '进阶', '高级'];

  static const List<String> themeOptions = ['system', 'light', 'dark'];
  static const Map<String, String> themeLabels = {
    'system': '跟随系统',
    'light': '浅色模式',
    'dark': '深色模式',
  };
  static const Map<String, IconData> themeIcons = {
    'system': Icons.brightness_auto,
    'light': Icons.light_mode,
    'dark': Icons.dark_mode,
  };

  static const List<String> languageOptions = ['zh', 'en'];
  static const Map<String, String> languageLabels = {
    'zh': '简体中文',
    'en': 'English',
  };
}
