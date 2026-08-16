import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../providers/dictionary_provider.dart';

/// 顶部实时搜索框（带防抖：输入停顿后才触发搜索，避免逐键全量重算）。
class SearchField extends StatefulWidget {
  const SearchField({super.key});

  /// 防抖延迟。测试可改为 [Duration.zero] 以同步触发。
  @visibleForTesting
  static Duration debounceDelay = const Duration(milliseconds: 200);

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    context.read<DictionaryProvider>().setQuery('');
    _focusNode.requestFocus();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(SearchField.debounceDelay, () {
      if (mounted) context.read<DictionaryProvider>().setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DictionaryProvider>();
    final scheme = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search AI terms...',
        hintStyle: TextStyle(fontSize: 14, color: scheme.outline),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: scheme.outline),
        suffixIcon: provider.query.isNotEmpty
            ? IconButton(
                tooltip: s.clearSearch,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: _clear,
              )
            : null,
      ),
    );
  }
}
