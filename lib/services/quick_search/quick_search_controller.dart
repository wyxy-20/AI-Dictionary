import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../providers/dictionary_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/quick_search_dialog.dart';

/// 全局快捷搜索控制器：
/// 注册系统级快捷键（任意界面按下即弹出搜索弹窗），并在设置变更后重注册。
class QuickSearchController extends ChangeNotifier {
  QuickSearchController(this._settingsProvider, this._dictionaryProvider);

  final SettingsProvider _settingsProvider;
  final DictionaryProvider _dictionaryProvider;

  /// 用于在全局快捷键触发时弹出搜索弹窗。
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 测试环境置为 true 可跳过平台插件调用（避免挂起计时器）。
  static bool debugDisablePlatform = false;

  bool _registered = false;
  bool get registered => _registered;

  String? _lastError;
  String? get lastError => _lastError;

  /// 可配置的快捷键预设：显示名 -> HotKey 描述字符串。
  static const Map<String, String> hotkeyPresets = {
    'Ctrl+K': 'Ctrl+K',
    'Ctrl+Shift+K': 'Ctrl+Shift+K',
    'Alt+K': 'Alt+K',
    'Ctrl+Alt+K': 'Ctrl+Alt+K',
    'F8': 'F8',
    'F9': 'F9',
  };

  /// 解析预设字符串为 HotKey；无法解析返回 null。
  static HotKey? parseHotKey(String preset) {
    final modifiers = <HotKeyModifier>[];
    var keyPart = preset;
    if (preset.contains('Ctrl')) {
      modifiers.add(HotKeyModifier.control);
      keyPart = keyPart.replaceAll('Ctrl', '').trim();
    }
    if (preset.contains('Shift')) {
      modifiers.add(HotKeyModifier.shift);
      keyPart = keyPart.replaceAll('Shift', '').trim();
    }
    if (preset.contains('Alt')) {
      modifiers.add(HotKeyModifier.alt);
      keyPart = keyPart.replaceAll('Alt', '').trim();
    }
    keyPart = keyPart.replaceAll('+', '').trim();

    final key = switch (keyPart.toUpperCase()) {
      'K' => LogicalKeyboardKey.keyK,
      'F8' => LogicalKeyboardKey.f8,
      'F9' => LogicalKeyboardKey.f9,
      _ => null,
    };
    if (key == null) return null;
    return HotKey(key: key, modifiers: modifiers.isEmpty ? null : modifiers);
  }

  /// 根据当前设置注册 / 注销全局快捷键。
  Future<void> syncRegistration() async {
    _lastError = null;
    if (debugDisablePlatform) {
      _registered = false;
      notifyListeners();
      return;
    }
    try {
      await hotKeyManager
          .unregisterAll()
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      if (!_settingsProvider.settings.quickSearchEnabled) {
        _registered = false;
        notifyListeners();
        return;
      }
      final hotKey = parseHotKey(_settingsProvider.settings.quickSearchHotkey);
      if (hotKey == null) {
        _lastError = '快捷键配置无效';
        _registered = false;
        notifyListeners();
        return;
      }
      await hotKeyManager
          .register(
            hotKey,
            keyDownHandler: (_) => showQuickSearch(),
          )
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      _registered = true;
    } catch (e) {
      _registered = false;
      _lastError = e.toString();
    }
    notifyListeners();
  }

  /// 弹出快捷搜索弹窗（全局快捷键回调与测试入口）。
  void showQuickSearch() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    showDialog<void>(
      context: navigator.context,
      builder: (_) => QuickSearchDialog(dictionaryProvider: _dictionaryProvider),
    );
  }

  @override
  void dispose() {
    try {
      hotKeyManager.unregisterAll().catchError((_) {});
    } catch (_) {
      // 插件不可用时忽略（例如测试环境）。
    }
    super.dispose();
  }
}
