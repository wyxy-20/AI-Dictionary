import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';

/// 难度星级显示（1~3 星）。
class DifficultyStars extends StatelessWidget {
  const DifficultyStars({super.key, required this.difficulty, this.size = 14});

  final int difficulty;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < difficulty ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: i < difficulty ? const Color(0xFFF5A623) : scheme.outlineVariant,
          ),
        const SizedBox(width: 6),
        Text(
          _label(s, difficulty),
          style: TextStyle(
            fontSize: size - 2,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _label(AppStrings s, int difficulty) {
    return switch (difficulty) {
      >= 3 => s.difficultyAdvanced,
      2 => s.difficultyIntermediate,
      _ => s.difficultyBeginner,
    };
  }
}
