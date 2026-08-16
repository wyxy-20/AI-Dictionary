import 'dart:convert';

import 'package:ai_dictionary/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('解析最新 Release：返回版本号与页面 URL', () async {
    final service = AppUpdateService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v9.9.9',
            'html_url': 'https://github.com/wyxy-20/AI-Dictionary/releases/tag/v9.9.9',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.checkLatestRelease();
    expect(result, isNotNull);
    expect(result!.$1, '9.9.9');
    expect(result.$2, contains('releases/tag/v9.9.9'));
    expect(service.hasUpdate('9.9.9'), isTrue);
  });

  test('查询失败返回 null（静默）', () async {
    final service = AppUpdateService(
      client: MockClient((request) async {
        throw http.ClientException('connection refused');
      }),
    );

    final result = await service.checkLatestRelease();
    expect(result, isNull);
  });

  test('HTTP 非 200 返回 null', () async {
    final service = AppUpdateService(
      client: MockClient((request) async => http.Response('oops', 500)),
    );

    final result = await service.checkLatestRelease();
    expect(result, isNull);
  });

  test('版本比较：当前版本高于最新时不提示更新', () {
    final service = AppUpdateService();
    expect(service.hasUpdate('0.0.1'), isFalse);
  });
}
