import 'package:ai_dictionary/services/quick_search/hotkey_codec.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

void main() {
  group('QuickSearchHotkeyCodec 编解码', () {
    test('旧预设字符串可解析', () {
      final ctrlK = QuickSearchHotkeyCodec.decode('Ctrl+K');
      expect(ctrlK, isNotNull);
      expect(ctrlK!.logicalKey, LogicalKeyboardKey.keyK);
      expect(ctrlK.modifiers, contains(HotKeyModifier.control));

      final f8 = QuickSearchHotkeyCodec.decode('F8');
      expect(f8!.logicalKey, LogicalKeyboardKey.f8);
      expect(f8.modifiers, isNull);

      expect(QuickSearchHotkeyCodec.decode('Unknown'), isNull);
    });

    test('任意组合往返一致', () {
      for (final combo in [
        'Ctrl+Shift+K',
        'Ctrl+Alt+K',
        'Alt+Space',
        'Ctrl+9',
        'Ctrl+ArrowUp',
        'Shift+F10',
        'Ctrl+Alt+Shift+Win+Enter',
      ]) {
        final hotKey = QuickSearchHotkeyCodec.decode(combo);
        expect(hotKey, isNotNull, reason: combo);
        expect(QuickSearchHotkeyCodec.encode(hotKey!), combo, reason: combo);
      }
    });

    test('修饰键顺序固定：Ctrl+Alt+Shift+Win', () {
      final hotKey = QuickSearchHotkeyCodec.decode('Alt+Ctrl+K');
      expect(QuickSearchHotkeyCodec.encode(hotKey!), 'Ctrl+Alt+K');
    });

    test('有效性校验', () {
      HotKey make(String combo) => QuickSearchHotkeyCodec.decode(combo)!;

      expect(QuickSearchHotkeyCodec.isValid(make('Ctrl+K')), isTrue);
      expect(QuickSearchHotkeyCodec.isValid(make('F8')), isTrue);
      expect(QuickSearchHotkeyCodec.isValid(make('K')), isFalse);
      expect(
        QuickSearchHotkeyCodec.isValid(
          HotKey(
            key: PhysicalKeyboardKey.controlLeft,
            modifiers: const [HotKeyModifier.control],
          ),
        ),
        isFalse,
      );
    });
  });
}
