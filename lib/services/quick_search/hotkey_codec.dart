import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// 自定义全局快捷键的编解码器。
///
/// 使用规范字符串（如 `Ctrl+Shift+K`、`F8`、`Ctrl+Alt+Space`）在数据库与
/// [HotKey] 之间转换，支持任意修饰键（Ctrl / Alt / Shift / Win）与任意主键
/// 组合，不再局限于预设下拉选项。
class QuickSearchHotkeyCodec {
  QuickSearchHotkeyCodec._();

  static const List<PhysicalKeyboardKey> _modifierKeys = [
    PhysicalKeyboardKey.controlLeft,
    PhysicalKeyboardKey.controlRight,
    PhysicalKeyboardKey.altLeft,
    PhysicalKeyboardKey.altRight,
    PhysicalKeyboardKey.shiftLeft,
    PhysicalKeyboardKey.shiftRight,
    PhysicalKeyboardKey.metaLeft,
    PhysicalKeyboardKey.metaRight,
    PhysicalKeyboardKey.capsLock,
    PhysicalKeyboardKey.fn,
  ];

  static const Map<String, LogicalKeyboardKey> _keysByLabel = {
    'A': LogicalKeyboardKey.keyA,
    'B': LogicalKeyboardKey.keyB,
    'C': LogicalKeyboardKey.keyC,
    'D': LogicalKeyboardKey.keyD,
    'E': LogicalKeyboardKey.keyE,
    'F': LogicalKeyboardKey.keyF,
    'G': LogicalKeyboardKey.keyG,
    'H': LogicalKeyboardKey.keyH,
    'I': LogicalKeyboardKey.keyI,
    'J': LogicalKeyboardKey.keyJ,
    'K': LogicalKeyboardKey.keyK,
    'L': LogicalKeyboardKey.keyL,
    'M': LogicalKeyboardKey.keyM,
    'N': LogicalKeyboardKey.keyN,
    'O': LogicalKeyboardKey.keyO,
    'P': LogicalKeyboardKey.keyP,
    'Q': LogicalKeyboardKey.keyQ,
    'R': LogicalKeyboardKey.keyR,
    'S': LogicalKeyboardKey.keyS,
    'T': LogicalKeyboardKey.keyT,
    'U': LogicalKeyboardKey.keyU,
    'V': LogicalKeyboardKey.keyV,
    'W': LogicalKeyboardKey.keyW,
    'X': LogicalKeyboardKey.keyX,
    'Y': LogicalKeyboardKey.keyY,
    'Z': LogicalKeyboardKey.keyZ,
    '0': LogicalKeyboardKey.digit0,
    '1': LogicalKeyboardKey.digit1,
    '2': LogicalKeyboardKey.digit2,
    '3': LogicalKeyboardKey.digit3,
    '4': LogicalKeyboardKey.digit4,
    '5': LogicalKeyboardKey.digit5,
    '6': LogicalKeyboardKey.digit6,
    '7': LogicalKeyboardKey.digit7,
    '8': LogicalKeyboardKey.digit8,
    '9': LogicalKeyboardKey.digit9,
    'F1': LogicalKeyboardKey.f1,
    'F2': LogicalKeyboardKey.f2,
    'F3': LogicalKeyboardKey.f3,
    'F4': LogicalKeyboardKey.f4,
    'F5': LogicalKeyboardKey.f5,
    'F6': LogicalKeyboardKey.f6,
    'F7': LogicalKeyboardKey.f7,
    'F8': LogicalKeyboardKey.f8,
    'F9': LogicalKeyboardKey.f9,
    'F10': LogicalKeyboardKey.f10,
    'F11': LogicalKeyboardKey.f11,
    'F12': LogicalKeyboardKey.f12,
    'Space': LogicalKeyboardKey.space,
    'Enter': LogicalKeyboardKey.enter,
    'Tab': LogicalKeyboardKey.tab,
    'Escape': LogicalKeyboardKey.escape,
    'Backspace': LogicalKeyboardKey.backspace,
    'Delete': LogicalKeyboardKey.delete,
    'Home': LogicalKeyboardKey.home,
    'End': LogicalKeyboardKey.end,
    'PageUp': LogicalKeyboardKey.pageUp,
    'PageDown': LogicalKeyboardKey.pageDown,
    'ArrowUp': LogicalKeyboardKey.arrowUp,
    'ArrowDown': LogicalKeyboardKey.arrowDown,
    'ArrowLeft': LogicalKeyboardKey.arrowLeft,
    'ArrowRight': LogicalKeyboardKey.arrowRight,
    '-': LogicalKeyboardKey.minus,
    '=': LogicalKeyboardKey.equal,
    '[': LogicalKeyboardKey.bracketLeft,
    ']': LogicalKeyboardKey.bracketRight,
    '\\': LogicalKeyboardKey.backslash,
    ';': LogicalKeyboardKey.semicolon,
    "'": LogicalKeyboardKey.quote,
    '`': LogicalKeyboardKey.backquote,
    ',': LogicalKeyboardKey.comma,
    '.': LogicalKeyboardKey.period,
    '/': LogicalKeyboardKey.slash,
  };

  static final Map<LogicalKeyboardKey, String> _labelsByKey = {
    for (final entry in _keysByLabel.entries) entry.value: entry.key,
  };

  static const Map<HotKeyModifier, String> _modifierLabels = {
    HotKeyModifier.control: 'Ctrl',
    HotKeyModifier.alt: 'Alt',
    HotKeyModifier.shift: 'Shift',
    HotKeyModifier.meta: 'Win',
  };

  static const List<HotKeyModifier> _modifierOrder = [
    HotKeyModifier.control,
    HotKeyModifier.alt,
    HotKeyModifier.shift,
    HotKeyModifier.meta,
  ];

  /// 将 [HotKey] 编码为规范字符串；无法识别的主键返回 null。
  static String? encode(HotKey hotKey) {
    final keyLabel = _labelsByKey[hotKey.logicalKey];
    if (keyLabel == null) return null;
    final parts = <String>[
      for (final modifier in _modifierOrder)
        if (hotKey.modifiers?.contains(modifier) ?? false)
          _modifierLabels[modifier]!,
      keyLabel,
    ];
    return parts.join('+');
  }

  /// 将规范字符串解析为 [HotKey]；非法或无法识别的字符串返回 null。
  static HotKey? decode(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('+').map((p) => p.trim()).toList();
    final modifiers = <HotKeyModifier>[];
    String? keyLabel;
    for (final part in parts) {
      if (part.isEmpty) return null;
      switch (part) {
        case 'Ctrl':
          modifiers.add(HotKeyModifier.control);
          break;
        case 'Alt':
          modifiers.add(HotKeyModifier.alt);
          break;
        case 'Shift':
          modifiers.add(HotKeyModifier.shift);
          break;
        case 'Win':
          modifiers.add(HotKeyModifier.meta);
          break;
        default:
          if (keyLabel != null) return null; // 只能有一个主键
          keyLabel = part;
      }
    }
    if (keyLabel == null) return null;
    final key = _keysByLabel[keyLabel];
    if (key == null) return null;
    return HotKey(
      key: key,
      modifiers: modifiers.isEmpty ? null : modifiers,
    );
  }

  /// 判断组合是否适合作为全局快捷键：
  /// 主键不能是修饰键，且必须带修饰键或使用 F1–F12（避免拦截日常输入）。
  static bool isValid(HotKey hotKey) {
    if (_modifierKeys.contains(hotKey.physicalKey)) return false;
    final key = hotKey.logicalKey;
    final isFunctionKey = key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.f3 ||
        key == LogicalKeyboardKey.f4 ||
        key == LogicalKeyboardKey.f5 ||
        key == LogicalKeyboardKey.f6 ||
        key == LogicalKeyboardKey.f7 ||
        key == LogicalKeyboardKey.f8 ||
        key == LogicalKeyboardKey.f9 ||
        key == LogicalKeyboardKey.f10 ||
        key == LogicalKeyboardKey.f11 ||
        key == LogicalKeyboardKey.f12;
    if (isFunctionKey) return true;
    return (hotKey.modifiers?.isNotEmpty ?? false);
  }

  /// 当前显示用的快捷键文本（无效时原样返回）。
  static String display(String stored) {
    final hotKey = decode(stored);
    if (hotKey == null) return stored;
    return encode(hotKey) ?? stored;
  }
}
