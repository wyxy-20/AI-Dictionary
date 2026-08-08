import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dictionary_provider.dart';

/// 顶部实时搜索框。
class SearchField extends StatefulWidget {
  const SearchField({super.key});

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    context.read<DictionaryProvider>().setQuery('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DictionaryProvider>();
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: provider.setQuery,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search AI terms...',
        hintStyle: TextStyle(fontSize: 14, color: scheme.outline),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: scheme.outline),
        suffixIcon: provider.query.isNotEmpty
            ? IconButton(
                tooltip: '清空',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: _clear,
              )
            : null,
      ),
    );
  }
}
