import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../models/term.dart';
import '../providers/dictionary_provider.dart';
import '../services/search_service.dart';

/// 快捷搜索弹窗：全局快捷键触发，输入即实时搜索词条。
class QuickSearchDialog extends StatefulWidget {
  const QuickSearchDialog({super.key, required this.dictionaryProvider});

  final DictionaryProvider dictionaryProvider;

  @override
  State<QuickSearchDialog> createState() => _QuickSearchDialogState();
}

class _QuickSearchDialogState extends State<QuickSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Term> get _results {
    if (_query.trim().isEmpty) return const [];
    return SearchService().search(widget.dictionaryProvider.allTerms, _query).take(8).toList();
  }

  void _select(Term term) {
    Navigator.of(context).pop();
    widget.dictionaryProvider.selectTerm(term);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final results = _results;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      title: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Text(s.quickSearchTitle, style: const TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 380,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: s.quickSearchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        _query.trim().isEmpty
                            ? s.quickSearchTypeToStart
                            : s.quickSearchNoResults,
                        style: TextStyle(fontSize: 13, color: scheme.outline),
                      ),
                    )
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final term = results[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              term.firstLetter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(term.englishName),
                          subtitle: Text(
                            term.chineseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _select(term),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.close),
        ),
      ],
    );
  }
}
