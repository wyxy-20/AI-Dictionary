/// 全局应用配置：名称、版本、数据库、种子数据等。
class AppConfig {
  AppConfig._();

  static const String appName = 'AI Dictionary';
  static const String appNameZh = 'AI时代词典';
  static const String appTitle = 'AI Dictionary · AI时代词典';
  static const String version = '1.9.3';

  static const String databaseFileName = 'ai_dictionary.db';
  static const int databaseVersion = 4;

  /// 内置 JSON 词库的版本号（本地词典初始版本）。
  /// 应与远程词库当前版本一致：一致时启动直接跳过下载，
  /// 只有远程词库更新（version 升高）才会触发增量同步。
  static const String seedDictionaryVersion = '1.4.0';

  /// 词库种子数据：单个 JSON 文件（完整词库，随版本内置）。
  /// 由 tool/sync_seed.ps1 从远程词库同步生成。
  static const String seedAssetFolder = 'assets/data/terms';
  static const String seedTermsFile = '$seedAssetFolder/terms.json';

  /// 历史记录最多保留的条数。
  static const int maxHistoryEntries = 100;

  /// 最近浏览面板最多显示的条数。
  static const int recentLimit = 50;

  /// 词库最低词条数量（用于测试与启动自检）。
  static const int minSeedTerms = 300;

  /// 远程词库来源（多源回退链，按顺序尝试，第一个可达的生效）。
  /// 发布新词库时请替换为你的仓库地址，结构：
  ///   `<baseUrl>/version.json`
  ///   `<baseUrl>/terms.json`
  ///
  /// 源 1：jsDelivr CDN（国内可达性最好，免费，自动同步 GitHub 仓库；
  ///       `@main` 分支内容最长缓存 12 小时，对每周更新节奏无感）；
  /// 源 2：GitHub Raw（海外 / 无污染网络环境）。
  static const List<String> remoteDictionaryBaseUrls = [
    'https://cdn.jsdelivr.net/gh/wyxy-20/AI-Terms-Database@main',
    'https://raw.githubusercontent.com/wyxy-20/AI-Terms-Database/main',
  ];

  /// 兼容旧配置：单个源的便捷访问（取第一个源）。
  static String get remoteDictionaryBaseUrl => remoteDictionaryBaseUrls.first;

  /// GitHub 仓库相关 URL（应用内检查更新 / 反馈入口）。
  static const String repoUrl = 'https://github.com/wyxy-20/AI-Dictionary';
  static const String releasesApiUrl = '$repoUrl/releases/latest';
  static const String releasesUrl = '$repoUrl/releases';
  static const String issuesUrl = '$repoUrl/issues/new/choose';

  /// 自动检查更新的最小间隔（避免每次启动重复下载）。
  static const Duration remoteCheckInterval = Duration(hours: 24);

  /// 远程请求超时（网络异常时快速降级到本地词库）。
  /// 注：terms.json（约 450KB）经国内网络 / 代理通道可能较慢，需留足余量。
  static const Duration remoteTimeout = Duration(seconds: 30);

  /// AI 服务默认配置（OpenAI 兼容接口）。
  static const String defaultAiBaseUrl = 'https://api.openai.com/v1';
  static const String defaultAiModelName = 'gpt-4o-mini';

  /// AI 请求超时与输出上限。
  static const Duration aiRequestTimeout = Duration(seconds: 30);
  static const int aiMaxTokens = 900;
}
