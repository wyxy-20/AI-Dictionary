import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';

/// 应用界面文案目录（简体中文 / English）。
///
/// 通过 [of] 获取当前语言对应的文案；语言切换后依赖
/// SettingsProvider 的组件会自动重建，无需重启软件。
class AppStrings {
  const AppStrings(this.language);

  final String language;

  bool get isZh => language == 'zh';

  static AppStrings of(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return AppStrings(settings.settings.language);
  }

  String _p(String zh, String en) => isZh ? zh : en;

  // ---------- 品牌 / 顶栏 ----------
  String get appNameZh => _p('AI时代词典', 'AI Era Dictionary');
  String get clearSearch => _p('清空', 'Clear');
  String get switchLight => _p('切换到浅色模式', 'Switch to light mode');
  String get switchDark => _p('切换到深色模式', 'Switch to dark mode');
  String get settings => _p('设置', 'Settings');
  String get showAiPanel => _p('显示 AI 解释面板', 'Show AI Explain panel');
  String get hideAiPanel => _p('隐藏 AI 解释面板', 'Hide AI Explain panel');

  // ---------- 左侧导航 ----------
  String get browse => _p('浏览', 'Browse');
  String get allTerms => _p('全部词条', 'All Terms');
  String get letterNav => _p('字母导航', 'A-Z');
  String get viewSection => _p('视图', 'View');
  String get favorites => _p('我的收藏', 'Favorites');
  String get recent => _p('最近浏览', 'Recent');
  String totalTerms(int count) => _p('共 $count 个词条', '$count terms');
  String letterTooltip(String letter) =>
      _p('查看字母 $letter 开头的词条', 'Terms starting with $letter');

  // ---------- 词条列表 ----------
  String get filterSearchResults => _p('搜索结果', 'Search Results');
  String filterLetter(String letter) => _p('字母 $letter', 'Letter $letter');
  String get clearFilters => _p('清除筛选', 'Clear Filters');
  String countItems(int count) => _p('$count 条', '$count items');
  String get emptyTitle => _p('未找到相关词条', 'No matching terms');
  String get emptySubtitle => _p(
        '换个关键词试试，支持中英文与模糊搜索',
        'Try another keyword. Supports Chinese, English and fuzzy search.',
      );

  // ---------- 词条详情 ----------
  String get selectTermHint => _p('选择一个词条查看详情', 'Select a term to view details');
  String get selectTermSub => _p(
        '点击左侧或中间列表中的词条，即可查看完整解释',
        'Click a term in the list to see its full explanation.',
      );
  String get oneLineSummary => _p('一句话解释', 'In One Sentence');
  String get detailExplanation => _p('详细解释', 'Detailed Explanation');
  String get applications => _p('应用场景', 'Use Cases');
  String get relatedTerms => _p('相关词条', 'Related Terms');
  String get aiExplain => _p('AI 解释', 'AI Explain');
  String get addFavorite => _p('收藏', 'Add to favorites');
  String get removeFavorite => _p('取消收藏', 'Remove from favorites');

  // ---------- 难度 ----------
  String get difficultyBeginner => _p('入门', 'Beginner');
  String get difficultyIntermediate => _p('进阶', 'Intermediate');
  String get difficultyAdvanced => _p('高级', 'Advanced');

  // ---------- 启动页 ----------
  String get initLocal => _p('正在初始化本地词库...', 'Initializing local dictionary...');
  String get syncing => _p('正在同步最新 AI 知识库...', 'Syncing the latest AI dictionary...');
  String get checkingUpdates => _p('检查更新...', 'Checking for updates...');
  String get downloadingTerms => _p('正在下载新词条...', 'Downloading new terms...');
  String get updatingDatabase => _p('正在更新数据库...', 'Updating database...');
  String get syncDone => _p('完成。', 'Done.');
  String versionLine(String appVersion, String dictVersion) =>
      _p('v$appVersion · 词库 v$dictVersion', 'v$appVersion · Dictionary v$dictVersion');

  // ---------- 设置 ----------
  String get appearance => _p('外观', 'Appearance');
  String get themeSystem => _p('跟随系统', 'System');
  String get themeLight => _p('浅色模式', 'Light');
  String get themeDark => _p('深色模式', 'Dark');
  String get languageLabel => _p('界面语言', 'Language');
  String get dataManagement => _p('数据管理', 'Data');
  String statsLine(int terms, int favorites) =>
      _p('词条 $terms · 收藏 $favorites', 'Terms $terms · Favorites $favorites');
  String get exportBackup => _p('导出词库备份', 'Export Backup');
  String get exportCaption => _p('将全部词条导出为 JSON 文件', 'Export all terms as a JSON file');
  String get clearHistory => _p('清空浏览历史', 'Clear History');
  String get clearHistoryCaption => _p('删除所有历史记录', 'Delete all history records');
  String get resetData => _p('重置为初始数据', 'Reset to Default');
  String get resetCaption => _p('重新导入内置 JSON 词库', 'Re-import the built-in JSON dictionary');
  String get exportedTo => _p('已导出到：', 'Exported to: ');
  String get openLocation => _p('打开位置', 'Open Location');
  String get resetDone => _p('已重置为初始词库', 'Reset to the default dictionary');
  String get aiServiceSettings => _p('AI 服务设置', 'AI Service Settings');
  String get aiServiceHint => _p(
        '支持 OpenAI / DeepSeek / Qwen / 本地模型等 OpenAI 兼容接口',
        'Works with OpenAI-compatible APIs: OpenAI / DeepSeek / Qwen / local models.',
      );
  String get baseUrlLabel => _p('AI 服务地址（Base URL）', 'Base URL');
  String get apiKeyLabel => _p('API Key', 'API Key');
  String get modelLabel => _p('模型名称（Model）', 'Model Name');
  String get saveConfig => _p('保存配置', 'Save');
  String get testConnection => _p('测试连接', 'Test');
  String get configSaved => _p('AI 服务配置已保存', 'AI service configuration saved');
  String get fillRequired => _p('请填写 AI 服务地址与模型名称', 'Please fill in the Base URL and model name');
  String get connectionSuccess => _p('连接成功', 'Connected');
  String get connectionFailed => _p('连接失败', 'Connection Failed');
  String connectionOkBody(String reply) =>
      _p('AI 服务连接正常。\n\n模型回复：$reply', 'AI service is working.\n\nModel reply: $reply');
  String get aiFeatures => _p('AI 功能', 'AI Features');
  String get aiExplainReleased => _p(
        '已上线 · 点击词条详情中的 AI 解释按钮体验',
        'Live - try the AI Explain button in term details.',
      );
  String get compareTerms => _p('术语对比', 'Compare Terms');
  String get compareTermsCaption => _p('对比两个术语（如 RAG vs Fine-tuning）', 'Compare two terms (e.g. RAG vs Fine-tuning)');
  String get aiQa => _p('AI 问答', 'AI Q&A');
  String get aiQaCaption => _p('就 AI 概念自由提问', 'Ask anything about AI concepts');
  String get learningPath => _p('学习路径', 'Learning Path');
  String get learningPathCaption => _p('输入目标，自动生成学习路线', 'Enter a goal and get a learning path');
  String get knowledgeBase => _p('知识库连接', 'Knowledge Base');
  String get knowledgeBaseCaption => _p('对接 Obsidian / Markdown / 个人 AI 大脑', 'Connect Obsidian / Markdown / personal AI brain');
  String get about => _p('关于软件', 'About');
  String get aboutDescription => _p(
        '面向 AI 学习者的专业术语词典，数据本地存储，支持离线查询。',
        'A professional AI terminology dictionary for AI learners. Data is stored locally and works offline.',
      );
  String get close => _p('关闭', 'Close');
  String get cancel => _p('取消', 'Cancel');
  String get clearHistoryTitle => _p('清空浏览历史', 'Clear Browsing History');
  String get clearHistoryConfirm => _p('确定要清空所有浏览历史记录吗？此操作不可撤销。', 'Clear all browsing history? This cannot be undone.');
  String get clear => _p('清空', 'Clear');
  String get resetTitle => _p('重置为初始数据', 'Reset to Default Data');
  String get resetConfirm => _p(
        '将删除本地词库与历史记录，并从内置 JSON 词库重新导入。确定继续吗？',
        'This will delete the local dictionary and history, then re-import from the built-in JSON dictionary. Continue?',
      );
  String get reset => _p('重置', 'Reset');

  // ---------- AI 解释侧边栏 ----------
  String get aiExplainTitle => _p('AI 解释', 'AI Explain');
  String get generating => _p('正在生成AI解释...', 'Generating AI explanation...');
  String get regenerate => _p('重新生成', 'Regenerate');
  String get copy => _p('复制', 'Copy');
  String get copied => _p('解释内容已复制到剪贴板', 'Explanation copied to clipboard');
  String get closeAiPanel => _p('关闭 AI 解释面板', 'Close AI Explain panel');
  String noAiRecord(String name) => _p(
        '「$name」还没有 AI 解释记录',
        'No saved AI explanation for "$name"',
      );
  String get askGenerate => _p('是否现在生成一份小白友好的解释？', 'Generate a beginner-friendly explanation now?');
  String get skipForNow => _p('暂不生成', 'Not now');
  String get generateNow => _p('生成 AI 解释', 'Generate');
  String get idleHint => _p(
        '点击词条详情中的「AI 解释」生成小白友好的解释',
        'Click "AI Explain" in term details to generate an explanation.',
      );
  String get noAiRecordGeneric => _p('该词条还没有 AI 解释记录', 'No saved AI explanation for this term');
}
