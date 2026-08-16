import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../utils/app_logger.dart';
import '../utils/version_utils.dart';

/// 应用更新检查：查询 GitHub Releases 最新版本。
///
/// 仅用于"设置 -> 检查更新"；查询失败返回 null（静默，不打扰用户）。
class AppUpdateService {
  AppUpdateService({this.client});

  final http.Client? client;

  /// 查询最新 Release。
  ///
  /// 返回 (最新版本号, Release 页面 URL)；查询失败返回 null。
  Future<(String, String)?> checkLatestRelease() async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse(AppConfig.releasesApiUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final tag = decoded['tag_name'] as String? ?? '';
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (version.isEmpty) return null;
      final htmlUrl =
          decoded['html_url'] as String? ?? AppConfig.releasesUrl;
      return (version, htmlUrl);
    } catch (e) {
      await AppLogger.instance.warn('app_update', '检查更新失败：$e');
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// 判断最新版本是否高于当前版本（存在可用更新）。
  bool hasUpdate(String latestVersion) =>
      VersionUtils.compare(latestVersion, AppConfig.version) > 0;
}
