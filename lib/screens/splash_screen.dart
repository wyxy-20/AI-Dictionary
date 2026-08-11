import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/l10n/app_strings.dart';

/// 启动加载页：展示自动同步词库的状态。
class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    this.statusKey = 'init',
    this.detailKey = '',
  });

  /// 'init' | 'sync'
  final String statusKey;

  /// '' | 'checking' | 'downloading' | 'updating' | 'done'
  final String detailKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/branding/app_icon.png',
                width: 108,
                height: 108,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              AppConfig.appName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              s.appNameZh,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 30),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(
              _statusText(s),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _detailText(s),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
            Text(
              s.versionLine(AppConfig.version, AppConfig.seedDictionaryVersion),
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(AppStrings s) => statusKey == 'sync' ? s.syncing : s.initLocal;

  String _detailText(AppStrings s) {
    return switch (detailKey) {
      'checking' => s.checkingUpdates,
      'downloading' => s.downloadingTerms,
      'updating' => s.updatingDatabase,
      'done' => s.syncDone,
      _ => '',
    };
  }
}
