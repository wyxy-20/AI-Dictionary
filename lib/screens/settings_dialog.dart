import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../models/ai_config.dart';
import '../providers/ai_config_provider.dart';
import '../providers/dictionary_provider.dart';
import '../providers/settings_provider.dart';
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
        const SnackBar(content: Text('请填写 AI 服务地址与模型名称')),
      );
      return;
    }
    await _run(() async {
      await provider.save(AiConfig(baseUrl: baseUrl, apiKey: apiKey, modelName: modelName));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 服务配置已保存')),
        );
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportData() async {
    final provider = context.read<DictionaryProvider>();
    await _run(() async {
      final path = await DataExportService(provider.database).exportBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导出到：$path'),
          action: SnackBarAction(
            label: '打开位置',
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
        title: const Text('清空浏览历史'),
        content: const Text('确定要清空所有浏览历史记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
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
        title: const Text('重置为初始数据'),
        content: const Text('将删除本地词库与历史记录，并从内置 JSON 词库重新导入。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('重置'),
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
          const SnackBar(content: Text('已重置为初始词库')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<DictionaryProvider>();
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('设置'),
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
                  _SectionTitle(icon: Icons.palette_outlined, title: '外观'),
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
                                      Text(AppConstants.themeLabels[theme]!),
                                    ],
                                  ),
                                  value: theme,
                                ),
                            ],
                          ),
                        ),
                        const Divider(),
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
                  _SectionTitle(icon: Icons.storage_rounded, title: '数据管理'),
                  _GroupCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '词条 ${provider.totalCount} · 收藏 ${provider.favoriteCount}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        _ActionRow(
                          icon: Icons.upload_file_rounded,
                          label: '导出词库备份',
                          caption: '将全部词条导出为 JSON 文件',
                          onTap: _busy ? null : _exportData,
                        ),
                        _ActionRow(
                          icon: Icons.history_rounded,
                          label: '清空浏览历史',
                          caption: '删除所有历史记录',
                          onTap: _busy ? null : _clearHistory,
                        ),
                        _ActionRow(
                          icon: Icons.restart_alt_rounded,
                          label: '重置为初始数据',
                          caption: '重新导入内置 JSON 词库',
                          onTap: _busy ? null : _resetData,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    icon: Icons.settings_input_component_rounded,
                    title: 'AI 服务设置',
                  ),
                  _GroupCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            '支持 OpenAI / DeepSeek / Qwen / 本地模型等 OpenAI 兼容接口',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                        TextField(
                          controller: _baseUrlCtrl,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'AI 服务地址（Base URL）',
                            hintText: 'https://api.openai.com/v1',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _apiKeyCtrl,
                          enabled: !_busy,
                          obscureText: _obscureKey,
                          decoration: InputDecoration(
                            labelText: 'API Key',
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
                          decoration: const InputDecoration(
                            labelText: '模型名称（Model）',
                            hintText: 'gpt-4o-mini / deepseek-chat / qwen-plus',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _busy ? null : _saveAiConfig,
                          icon: const Icon(Icons.save_rounded, size: 16),
                          label: const Text('保存 AI 服务配置'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: Icons.auto_awesome_rounded, title: 'AI 功能（即将推出）'),
                  _GroupCard(
                    child: Column(
                      children: const [
                        _FutureFeatureRow(
                          icon: Icons.auto_awesome_rounded,
                          title: 'AI 解释',
                          caption: '已上线 · 点击词条详情中的 AI 解释按钮体验',
                          released: true,
                        ),
                        _FutureFeatureRow(
                          icon: Icons.compare_arrows_rounded,
                          title: '术语对比',
                          caption: '对比两个术语（如 RAG vs Fine-tuning）',
                        ),
                        _FutureFeatureRow(
                          icon: Icons.forum_outlined,
                          title: 'AI 问答',
                          caption: '就 AI 概念自由提问',
                        ),
                        _FutureFeatureRow(
                          icon: Icons.route_rounded,
                          title: '学习路径',
                          caption: '输入目标，自动生成学习路线',
                        ),
                        _FutureFeatureRow(
                          icon: Icons.link_rounded,
                          title: '知识库连接',
                          caption: '对接 Obsidian / Markdown / 个人 AI 大脑',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(icon: Icons.info_outline_rounded, title: '关于软件'),
                  _GroupCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${AppConfig.appName}（${AppConfig.appNameZh}）',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '版本 ${AppConfig.version}\n'
                            '面向 AI 学习者的专业术语词典，数据本地存储，支持离线查询。',
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
          child: const Text('关闭'),
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
