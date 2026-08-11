import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../models/term.dart';
import '../providers/ai_explanation_provider.dart';

/// AI 解释右侧侧边栏：加载状态 / 分模块内容 / 错误提示，支持显示与隐藏。
class AiExplanationPanel extends StatelessWidget {
  const AiExplanationPanel({super.key});

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
    final provider = context.watch<AiExplanationProvider>();
    final term = provider.term;
    final s = AppStrings.of(context);

    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  s.aiExplainTitle,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    term?.englishName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: s.closeAiPanel,
                  onPressed: provider.close,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(child: _buildBody(context, provider, term)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AiExplanationProvider provider,
    Term? term,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);

    switch (provider.status) {
      case AiExplanationStatus.loading:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 18),
                Text(
                  s.generating,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                if (term != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    term.englishName,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        );

      case AiExplanationStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 40, color: scheme.error),
                const SizedBox(height: 14),
                Text(
                  provider.error ?? '生成失败',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                if (term != null)
                  OutlinedButton.icon(
                    onPressed: () => provider.generate(term, force: true),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(s.regenerate),
                  ),
              ],
            ),
          ),
        );

      case AiExplanationStatus.prompt:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline_rounded, size: 42, color: scheme.primary),
                const SizedBox(height: 14),
                Text(
                  term == null
                      ? s.noAiRecordGeneric
                      : s.noAiRecord(term.englishName),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.askGenerate,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: provider.skipPrompt,
                        child: Text(s.skipForNow),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: term == null
                            ? null
                            : () => provider.generate(term),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(s.generateNow),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      case AiExplanationStatus.success:
        final content = provider.content ?? '';
        final sections = parseSections(content);
        return Column(
          children: [
            Expanded(
              child: sections.length == 1 && sections.first.title.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        content,
                        style: const TextStyle(fontSize: 13.5, height: 1.7),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
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
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: term == null
                          ? null
                          : () => provider.generate(term, force: true),
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: Text(s.regenerate),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: content));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.copied)),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: Text(s.copy),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case AiExplanationStatus.idle:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_outlined, size: 40, color: scheme.outline),
                const SizedBox(height: 14),
                Text(
                  s.idleHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
    }
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
