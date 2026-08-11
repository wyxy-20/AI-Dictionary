import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../core/l10n/app_strings.dart';
import '../models/ai_config.dart';
import '../providers/ai_config_provider.dart';
import '../providers/dictionary_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/openai_compatible_ai_service.dart';
import '../services/data_export_service.dart';
import '../services/seed_service.dart';

/// 设置对话框：外观、数据管理、AI 功能预览、关于。
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _busy = false;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _modelCtrl;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final config = context.read<AiConfigProvider>().config;
    _baseUrlCtrl = TextEditingController(text: config.baseUrl);
    _apiKeyCtrl = TextEditingController(text: config.apiKey);
    _modelCtrl = TextEditingController(text: config.modelName);
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAiConfig() async {
    final provider = context.read<AiConfigProvider>();
    final baseUrl = _baseUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();
    final modelName = _modelCtrl.text.trim();
    if (baseUrl.isEmpty || modelName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).fillRequired)),
      );
      return;
    }
    await _run(() async {
      await provider.save(AiConfig(baseUrl: baseUrl, apiKey: apiKey, modelName: modelName));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).configSaved)),
        );
      }
    });
  }

  Future<void> _testAiConnection() async {
    final baseUrl = _baseUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();
    final modelName = _modelCtrl.text.trim();
    if (baseUrl.isEmpty || modelName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).fillRequired)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final service = OpenAiCompatibleAiService(
        AiConfig(baseUrl: baseUrl, apiKey: apiKey, modelName: modelName),
      );
      final reply = await service.testConnection();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppStrings.of(context).connectionSuccess),
          content: Text(AppStrings.of(context).connectionOkBody(reply)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.of(context).close),
            ),
          ],
        ),
      );
    } on AiConfigException catch (e) {
      _showAiTestError(e.message);
    } on AiTimeoutException catch (e) {
      _showAiTestError(e.message);
    } on AiNetworkException catch (e) {
      _showAiTestError(e.message);
    } on AiServiceException catch (e) {
      _showAiTestError(e.message);
    } on Exception catch (e) {
      _showAiTestError('连接失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAiTestError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.of(context).connectionFailed),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppStrings.of(context).close),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _themeLabel(AppStrings s, String theme) {
    return switch (theme) {
      'system' => s.themeSystem,
      'light' => s.themeLight,
      'dark' => s.themeDark,
      _ => theme,
    };
  }

  Future<void> _exportData() async {
    final provider = context.read<DictionaryProvider>();
    await _run(() async {
      final path = await DataExportService(provider.database).exportBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.of(context).exportedTo}$path'),
          action: SnackBarAction(
            label: AppStrings.of(context).openLocation,
            onPressed: () => DataExportService(provider.database).revealInExplorer(path),
          ),
        ),
      );
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx).clearHistoryTitle),
        content: Text(AppStrings.of(ctx).clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.of(ctx).clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final provider = context.read<DictionaryProvider>();
      await provider.historyDao.clear();
      await provider.refreshAll();
    });
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(ctx).resetTitle),
        content: Text(AppStrings.of(ctx).resetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(AppStrings.of(ctx).reset),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final provider = context.read<DictionaryProvider>();
      await SeedService(provider.database).resetDatabase();
      await provider.refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).resetDone)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<DictionaryProvider>();
    final scheme = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(s.settings),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      content: SizedBox(
        width: 520,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle(icon: Icons.palette_outlined, title: s.appearance),
                  _GroupCard(
                    child: Column(
                      children: [
                        RadioGroup<String>(
                          groupValue: settings.settings.theme,
                          onChanged: (v) {
                            if (_busy || v == null) return;
                            settings.setTheme(v);
                          },
                          child: Column(
                            children: [
                              for (final theme in AppConstants.themeOptions)
                                RadioListTile<String>(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Row(
                                    children: [
                                      Icon(
                                        AppConstants.themeIcons[theme],
                                        size: 18,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_themeLabel(s, theme)),
                                    ],
                                  ),
                                  value: theme,
                                ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              s.languageLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        RadioGroup<String>(
                          groupValue: settings.settings.language,
                          onChanged: (v) {
                            if (_busy || v == null) return;
                            settings.setLanguage(v);
                          },
                          child: Column(
                            children: [
                              for (final lang in AppConstants.languageOptions)
                                RadioListTile<String>(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(AppConstants.languageLabels[lang]!),
                                  value: lang,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: Icons.storage_rounded, title: s.dataManagement),
                  _GroupCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            s.statsLine(provider.totalCount, provider.favoriteCount),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        _ActionRow(
                          icon: Icons.upload_file_rounded,
                          label: s.exportBackup,
                          caption: s.exportCaption,
                          onTap: _busy ? null : _exportData,
                        ),
                        _ActionRow(
                          icon: Icons.history_rounded,
                          label: s.clearHistory,
                          caption: s.clearHistoryCaption,
                          onTap: _busy ? null : _clearHistory,
                        ),
                        _ActionRow(
                          icon: Icons.restart_alt_rounded,
                          label: s.resetData,
                          caption: s.resetCaption,
                          onTap: _busy ? null : _resetData,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    icon: Icons.settings_input_component_rounded,
                    title: s.aiServiceSettings,
                  ),
                  _GroupCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            s.aiServiceHint,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                        TextField(
                          controller: _baseUrlCtrl,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: s.baseUrlLabel,
                            hintText: '如 https://api.deepseek.com 或 https://api.openai.com/v1',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _apiKeyCtrl,
                          enabled: !_busy,
                          obscureText: _obscureKey,
                          decoration: InputDecoration(
                            labelText: s.apiKeyLabel,
                            hintText: 'sk-...',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureKey
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                size: 18,
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _obscureKey = !_obscureKey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _modelCtrl,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: s.modelLabel,
                            hintText: 'deepseek-chat / gpt-4o-mini / qwen-plus',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _testAiConnection,
                                icon: const Icon(Icons.wifi_tethering_rounded, size: 16),
                                label: Text(s.testConnection),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _saveAiConfig,
                                icon: const Icon(Icons.save_rounded, size: 16),
                                label: Text(s.saveConfig),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: Icons.auto_awesome_rounded, title: s.aiFeatures),
                  _GroupCard(
                    child: Column(
                      children: [
                        _FutureFeatureRow(
                          icon: Icons.auto_awesome_rounded,
                          title: s.aiExplain,
                          caption: s.aiExplainReleased,
                          released: true,
                        ),
                        _FutureFeatureRow(
                          icon: Icons.compare_arrows_rounded,
                          title: s.compareTerms,
                          caption: s.compareTermsCaption,
                        ),
                        _FutureFeatureRow(
                          icon: Icons.forum_outlined,
                          title: s.aiQa,
                          caption: s.aiQaCaption,
                        ),
                        _FutureFeatureRow(
                          icon: Icons.route_rounded,
                          title: s.learningPath,
                          caption: s.learningPathCaption,
                        ),
                        _FutureFeatureRow(
                          icon: Icons.link_rounded,
                          title: s.knowledgeBase,
                          caption: s.knowledgeBaseCaption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: Icons.info_outline_rounded, title: s.about),
                  _GroupCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${AppConfig.appName}（${s.appNameZh}）',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${s.versionLine(AppConfig.version, AppConfig.seedDictionaryVersion)}\n'
                            '${s.aboutDescription}',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.6,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: scheme.surface.withValues(alpha: 0.6),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(s.close),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
      title: Text(label, style: const TextStyle(fontSize: 13.5)),
      subtitle: Text(caption, style: TextStyle(fontSize: 11.5, color: scheme.outline)),
      trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
      onTap: onTap,
    );
  }
}

class _FutureFeatureRow extends StatelessWidget {
  const _FutureFeatureRow({
    required this.icon,
    required this.title,
    required this.caption,
    this.released = false,
  });

  final IconData icon;
  final String title;
  final String caption;
  final bool released;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: scheme.primary.withValues(alpha: 0.8)),
      title: Text(title, style: const TextStyle(fontSize: 13.5)),
      subtitle: Text(caption, style: TextStyle(fontSize: 11.5, color: scheme.outline)),
      trailing: released
          ? Icon(Icons.check_circle_rounded, size: 16, color: scheme.primary)
          : Icon(Icons.schedule_rounded, size: 16, color: scheme.outline),
    );
  }
}
