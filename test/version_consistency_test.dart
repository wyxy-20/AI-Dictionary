import 'dart:io';

import 'package:ai_dictionary/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// R7：版本号单一来源。
///
/// app_config.dart 中硬编码的版本必须与 pubspec.yaml 保持一致，
/// 防止发版时只改一处导致版本错乱。
void main() {
  test('pubspec.yaml 版本与应用内版本一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml 应包含 version 字段');
    final pubspecVersion = match!.group(1)!.trim().split('+').first;
    expect(
      AppConfig.version,
      pubspecVersion,
      reason: 'app_config.dart 的 AppConfig.version 应与 pubspec.yaml 保持一致',
    );
  });
}
