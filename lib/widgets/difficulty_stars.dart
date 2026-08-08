import 'package:flutter/material.dart';

/// 难度星级显示（1~3 星）。
class DifficultyStars extends StatelessWidget {
  const DifficultyStars({super.key, required this.difficulty, this.size = 14});

  final int difficulty;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          _label(difficulty),
          style: TextStyle(
            fontSize: size - 2,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _label(int difficulty) {
    return switch (difficulty) {
      >= 3 => '高级',
      2 => '进阶',
      _ => '入门',
    };
  }
}
