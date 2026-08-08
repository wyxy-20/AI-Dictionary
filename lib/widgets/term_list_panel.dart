import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/term.dart';
import '../providers/dictionary_provider.dart';
import 'empty_state.dart';
import 'term_tile.dart';

/// 中间栏：词条列表（分组展示 / 搜索结果）。
class TermListPanel extends StatelessWidget {
  const TermListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<DictionaryProvider>();
    final terms = provider.visibleTerms;
    final filtered =
        provider.query.isNotEmpty || provider.letter != null || provider.view != ViewFilter.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  provider.filterLabel,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (filtered)
                TextButton.icon(
                  onPressed: provider.clearFilters,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                  label: const Text('清除筛选', style: TextStyle(fontSize: 12)),
                ),
              Text(
                '${terms.length} 条',
                style: TextStyle(fontSize: 11.5, color: scheme.outline),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: !provider.loaded
              ? const Center(child: CircularProgressIndicator())
              : terms.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: '未找到相关词条',
                      subtitle: '换个关键词试试，支持中英文与模糊搜索',
                    )
                  : provider.grouped
                      ? _GroupedList(terms: terms)
                      : _FlatList(
                          terms: terms,
                          highlightQuery: provider.query,
                        ),
        ),
      ],
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.terms});

  final List<Term> terms;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <String, List<Term>>{};
    for (final term in terms) {
      groups.putIfAbsent(term.firstLetter, () => []).add(term);
    }
    final letters = groups.keys.toList()..sort();

    return CustomScrollView(
      slivers: [
        for (final letter in letters) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Text(
                    letter,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Divider(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: groups[letter]!.length,
            itemBuilder: (context, index) {
              final term = groups[letter]![index];
              return _listTile(context, term);
            },
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _listTile(BuildContext context, Term term) {
    final provider = context.read<DictionaryProvider>();
    final selected = provider.selectedTerm?.id == term.id;
    return TermTile(
      term: term,
      selected: selected,
      onTap: () => provider.selectTerm(term),
    );
  }
}

class _FlatList extends StatelessWidget {
  const _FlatList({required this.terms, required this.highlightQuery});

  final List<Term> terms;
  final String highlightQuery;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: terms.length,
      itemBuilder: (context, index) {
        final term = terms[index];
        final provider = context.read<DictionaryProvider>();
        return TermTile(
          term: term,
          selected: provider.selectedTerm?.id == term.id,
          highlightQuery: highlightQuery,
          onTap: () => provider.selectTerm(term),
        );
      },
    );
  }
}
