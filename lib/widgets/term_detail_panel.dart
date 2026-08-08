import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/term.dart';
import '../providers/dictionary_provider.dart';
import 'difficulty_stars.dart';
import 'empty_state.dart';

/// 右侧栏：词条详情。
class TermDetailPanel extends StatelessWidget {
  const TermDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DictionaryProvider>();
    final term = provider.selectedTerm;

    if (term == null) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: '选择一个词条查看详情',
        subtitle: '点击左侧或中间列表中的词条，即可查看完整解释',
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      term.englishName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (term.chineseName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        term.chineseName,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: term.favorite ? '取消收藏' : '收藏',
                onPressed: () => provider.toggleFavorite(term),
                icon: Icon(
                  term.favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: term.favorite ? const Color(0xFFF5A623) : scheme.onSurfaceVariant,
                  size: 26,
                ),
              ),
              IconButton(
                tooltip: 'AI 解释',
                onPressed: () => _showAiExplain(context, provider, term),
                icon: Icon(Icons.auto_awesome_rounded, color: scheme.primary),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InfoChip(
                    icon: Icons.sell_outlined,
                    label: term.category,
                  ),
                  DifficultyStars(difficulty: term.difficulty),
                ],
              ),
              const SizedBox(height: 18),
              _DetailSection(
                icon: Icons.bolt_rounded,
                title: '一句话解释',
                child: Text(
                  term.shortDescription,
                  style: const TextStyle(fontSize: 14.5, height: 1.55),
                ),
              ),
              const SizedBox(height: 14),
              _DetailSection(
                icon: Icons.article_outlined,
                title: '详细解释',
                child: Text(
                  term.detailDescription,
                  style: const TextStyle(fontSize: 14, height: 1.7),
                ),
              ),
              if (term.application.isNotEmpty) ...[
                const SizedBox(height: 14),
                _DetailSection(
                  icon: Icons.apps_rounded,
                  title: '应用场景',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final app in term.application)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  app,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (term.relatedTerms.isNotEmpty) ...[
                const SizedBox(height: 14),
                _DetailSection(
                  icon: Icons.link_rounded,
                  title: '相关词条',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in term.relatedTerms)
                        ActionChip(
                          label: Text(name, style: const TextStyle(fontSize: 12.5)),
                          onPressed: () => _jumpToRelated(context, provider, name),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () => _showAiExplain(context, provider, term),
                icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                label: const Text('AI 解释（即将上线）'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAiExplain(
    BuildContext context,
    DictionaryProvider provider,
    Term term,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final answer = await provider.aiService.explainTerm(term.englishName);
    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('AI 解释 · ${term.englishName}'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SelectableText(
            answer,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _jumpToRelated(
    BuildContext context,
    DictionaryProvider provider,
    String name,
  ) async {
    final term = await provider.findTermByName(name);
    if (term == null || !context.mounted) return;
    await provider.selectTerm(term);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
