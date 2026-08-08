import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/term.dart';

/// AI 解释结果弹窗：按固定格式分模块展示，支持复制。
class AiExplanationDialog extends StatelessWidget {
  const AiExplanationDialog({super.key, required this.term, required this.content});

  final Term term;
  final String content;

  /// 解析 AI 输出中的【模块标题】结构。
  static List<({String title, String body})> parseSections(String content) {
    final result = <({String title, String body})>[];
    final regex = RegExp(r'【([^】]+)】');
    final matches = regex.allMatches(content).toList();
    if (matches.isEmpty) {
      return [(title: '', body: content)];
    }

    String currentTitle = '';
    var lastEnd = 0;
    for (final match in matches) {
      final between = content.substring(lastEnd, match.start).trim();
      if (currentTitle.isNotEmpty && between.isNotEmpty) {
        result.add((title: currentTitle, body: between));
      }
      currentTitle = match.group(1)!.trim();
      lastEnd = match.end;
    }
    final tail = content.substring(lastEnd).trim();
    if (currentTitle.isNotEmpty && tail.isNotEmpty) {
      result.add((title: currentTitle, body: tail));
    }
    return result.isEmpty ? [(title: '', body: content)] : result;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sections = parseSections(content);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI解释 · ${term.englishName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      content: SizedBox(
        width: 560,
        height: 460,
        child: sections.length == 1 && sections.first.title.isEmpty
            ? SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(fontSize: 14, height: 1.7),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return _SectionCard(
                    title: section.title,
                    body: section.body,
                  );
                },
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: content));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('解释内容已复制到剪贴板')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('复制'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 加载弹窗：展示"正在生成AI解释..."。
class AiLoadingDialog extends StatelessWidget {
  const AiLoadingDialog({super.key, this.label = '正在生成AI解释...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 18),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            body,
            style: const TextStyle(fontSize: 13.5, height: 1.6),
          ),
        ],
      ),
    );
  }
}
