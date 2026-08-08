import 'package:flutter/material.dart';

import '../core/config/app_config.dart';

/// 启动加载页：展示自动同步词库的状态。
class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    this.status = '正在初始化本地词库...',
    this.detail = '',
  });

  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              AppConfig.appNameZh,
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
              status,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
            Text(
              'v${AppConfig.version} · 词库 v${AppConfig.seedDictionaryVersion}',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
