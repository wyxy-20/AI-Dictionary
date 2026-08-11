import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../providers/dictionary_provider.dart';

/// 左侧栏：视图切换（全部 / 收藏 / 最近浏览）+ A-Z 字母导航。
class LeftNavPanel extends StatelessWidget {
  const LeftNavPanel({super.key});

  static const List<String> _letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<DictionaryProvider>();
    final s = AppStrings.of(context);

    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              s.browse,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: scheme.outline,
              ),
            ),
          ),
          _NavButton(
            icon: Icons.grid_view_rounded,
            label: s.allTerms,
            selected: provider.view == ViewFilter.all && provider.letter == null,
            onTap: () => provider.setView(ViewFilter.all),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              s.letterNav,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: scheme.outline,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final letter in _letters)
                  _LetterButton(
                    letter: letter,
                    selected: provider.letter == letter,
                    onTap: () {
                      provider.setView(ViewFilter.all);
                      provider.setLetter(letter);
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              s.viewSection,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: scheme.outline,
              ),
            ),
          ),
          _NavButton(
            icon: Icons.star_rounded,
            label: s.favorites,
            trailing: Text(
              '${provider.favoriteCount}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            selected: provider.view == ViewFilter.favorites,
            onTap: () => provider.setView(ViewFilter.favorites),
          ),
          _NavButton(
            icon: Icons.history_rounded,
            label: s.recent,
            selected: provider.view == ViewFilter.recent,
            onTap: () => provider.setView(ViewFilter.recent),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              s.totalTerms(provider.totalCount),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = selected
        ? scheme.primaryContainer.withValues(alpha: 0.6)
        : Colors.transparent;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: foreground,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterButton extends StatelessWidget {
  const _LetterButton({
    required this.letter,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = selected ? scheme.primary : Colors.transparent;
    final foreground = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Tooltip(
      message: AppStrings.of(context).letterTooltip(letter),
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? null
                : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
