import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/config/app_config.dart';

/// 系统托盘服务：
///
/// - 右下角显示应用图标（`assets/branding/app_icon.ico`）；
/// - 菜单：显示主界面 / 快捷搜索 / 退出；
/// - 主窗口点击关闭时隐藏到托盘（进程继续运行，全局快捷键仍可用）。
class TrayService with TrayListener, WindowListener {
  TrayService({
    required this.onShowQuickSearch,
    required this.onHideQuickSearch,
  });

  final VoidCallback onShowQuickSearch;
  final Future<void> Function() onHideQuickSearch;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // 测试环境没有原生插件，通道调用会挂起，直接跳过。
    if (const bool.fromEnvironment('FLUTTER_TEST')) return;
    trayManager.addListener(this);
    windowManager.addListener(this);
    try {
      // tray_manager 会把相对路径拼到 <exe>/data/flutter_assets 下。
      await trayManager
          .setIcon('assets/branding/app_icon.ico')
          .timeout(const Duration(seconds: 3), onTimeout: () {});
      await trayManager
          .setToolTip(AppConfig.appTitle)
          .timeout(const Duration(seconds: 3), onTimeout: () {});
      await trayManager
          .setContextMenu(
            Menu(
              items: [
                MenuItem(key: 'show_main', label: '显示主界面'),
                MenuItem(key: 'quick_search', label: '快捷搜索'),
                MenuItem.separator(),
                MenuItem(key: 'quit', label: '退出'),
              ],
            ),
          )
          .timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {
      // 托盘初始化失败不阻塞软件（例如测试环境无插件）。
    }
  }

  Future<void> showMainWindow() async {
    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // 忽略。
    }
  }

  /// 关闭主窗口时隐藏到托盘（不退出进程）。
  Future<void> hideToTray() async {
    try {
      await onHideQuickSearch();
      await windowManager.hide();
    } catch (_) {
      // 忽略。
    }
  }

  /// 完全退出：销毁托盘图标并退出消息循环。
  Future<void> quit() async {
    try {
      await trayManager.destroy();
    } catch (_) {
      // 忽略。
    }
    try {
      await windowManager.destroy();
    } catch (_) {
      // 忽略。
    }
  }

  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  // ---------- WindowListener：点 X 关闭 → 隐藏到托盘 ----------
  @override
  void onWindowClose() {
    unawaited(hideToTray());
  }

  // ---------- TrayListener ----------
  @override
  void onTrayIconMouseDown() {
    unawaited(showMainWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_main':
        unawaited(showMainWindow());
        break;
      case 'quick_search':
        onShowQuickSearch();
        break;
      case 'quit':
        unawaited(quit());
        break;
    }
  }
}
