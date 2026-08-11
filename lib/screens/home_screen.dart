import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/l10n/app_strings.dart';
import '../providers/ai_explanation_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/ai_explanation_panel.dart';
import '../widgets/left_nav_panel.dart';
import '../widgets/search_field.dart';
import '../widgets/term_detail_panel.dart';
import '../widgets/term_list_panel.dart';
import 'settings_dialog.dart';

/// 主界面：顶部搜索栏 + 三栏布局（字母导航 / 词条列表 / 词条详情）。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final aiPanel = context.watch<AiExplanationProvider>();
    return Scaffold(
      body: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 184, child: LeftNavPanel()),
                const VerticalDivider(),
                SizedBox(
                  width: aiPanel.isOpen ? 300 : 380,
                  child: const TermListPanel(),
                ),
                const VerticalDivider(),
                const Expanded(child: TermDetailPanel()),
                if (aiPanel.isOpen) ...[
                  const VerticalDivider(),
                  const SizedBox(width: 340, child: AiExplanationPanel()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final aiPanel = context.watch<AiExplanationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = AppStrings.of(context);

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A5CFF), Color(0xFF7B61FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConfig.appName,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
              Text(
                s.appNameZh,
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(width: 20),
          const Expanded(child: SearchField()),
          const SizedBox(width: 8),
          IconButton(
            tooltip: aiPanel.isOpen ? s.hideAiPanel : s.showAiPanel,
            onPressed: aiPanel.toggle,
            icon: Icon(
              aiPanel.isOpen
                  ? Icons.auto_awesome_rounded
                  : Icons.auto_awesome_outlined,
              size: 20,
              color: aiPanel.isOpen ? scheme.primary : null,
            ),
          ),
          IconButton(
            tooltip: isDark ? s.switchLight : s.switchDark,
            onPressed: () => settings.setTheme(isDark ? 'light' : 'dark'),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: s.settings,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
            icon: const Icon(Icons.settings_rounded, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
