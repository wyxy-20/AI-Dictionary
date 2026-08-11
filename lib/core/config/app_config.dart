/// 全局应用配置：名称、版本、数据库、种子数据等。
class AppConfig {
  AppConfig._();

  static const String appName = 'AI Dictionary';
  static const String appNameZh = 'AI时代词典';
  static const String appTitle = 'AI Dictionary · AI时代词典';
  static const String version = '1.7.0';

  static const String databaseFileName = 'ai_dictionary.db';
  static const int databaseVersion = 4;

  /// 内置 JSON 词库的版本号（本地词典初始版本）。
  static const String seedDictionaryVersion = '1.0.0';

  /// 词库种子数据存放目录（每个字母一个 JSON 文件）。
  static const String seedAssetFolder = 'assets/data/terms';
  static const List<String> seedLetters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  /// 历史记录最多保留的条数。
  static const int maxHistoryEntries = 100;

  /// 最近浏览面板最多显示的条数。
  static const int recentLimit = 50;

  /// 词库最低词条数量（用于测试与启动自检）。
  static const int minSeedTerms = 300;

  /// 远程词库来源（第一阶段：GitHub Raw）。
  /// 发布新词库时请替换为你的仓库地址，结构：
  ///   `<baseUrl>/version.json`
  ///   `<baseUrl>/terms.json`
  static const String remoteDictionaryBaseUrl =
      'https://raw.githubusercontent.com/wyxy-20/AI-Terms-Database/main';

  /// 自动检查更新的最小间隔（避免每次启动重复下载）。
  static const Duration remoteCheckInterval = Duration(hours: 24);

  /// 远程请求超时（网络异常时快速降级到本地词库）。
  static const Duration remoteTimeout = Duration(seconds: 8);

  /// AI 服务默认配置（OpenAI 兼容接口）。
  static const String defaultAiBaseUrl = 'https://api.openai.com/v1';
  static const String defaultAiModelName = 'gpt-4o-mini';

  /// AI 请求超时与输出上限。
  static const Duration aiRequestTimeout = Duration(seconds: 30);
  static const int aiMaxTokens = 900;
}
