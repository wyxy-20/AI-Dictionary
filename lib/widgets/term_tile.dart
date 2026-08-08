import 'package:flutter/material.dart';

import '../models/term.dart';
import '../utils/string_utils.dart';

/// 词条列表项。
class TermTile extends StatelessWidget {
  const TermTile({
    super.key,
    required this.term,
    required this.onTap,
    this.selected = false,
    this.highlightQuery,
    this.showLetterAvatar = true,
  });

  final Term term;
  final VoidCallback onTap;
  final bool selected;
  final String? highlightQuery;
  final bool showLetterAvatar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final titleStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: selected ? scheme.primary : scheme.onSurface,
    );
    final highlightStyle = titleStyle?.copyWith(
      color: scheme.primary,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.55),
      fontWeight: FontWeight.w700,
    );

    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.45),
      onTap: onTap,
      leading: showLetterAvatar
          ? CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                term.firstLetter,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            )
          : null,
      title: Text.rich(
        TextSpan(
          children: StringUtils.highlightMatches(
            term.englishName,
            highlightQuery ?? '',
            titleStyle!,
            highlightStyle!,
          ),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: term.chineseName.isEmpty
          ? null
          : Text(
              term.chineseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
      trailing: term.favorite
          ? Icon(Icons.star_rounded, size: 18, color: const Color(0xFFF5A623))
          : null,
    );
  }
}
