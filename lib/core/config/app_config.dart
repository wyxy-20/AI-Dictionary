/// 全局应用配置：名称、版本、数据库、种子数据等。
class AppConfig {
  AppConfig._();

  static const String appName = 'AI Dictionary';
  static const String appNameZh = 'AI时代词典';
  static const String appTitle = 'AI Dictionary · AI时代词典';
  static const String version = '1.0.0';

  static const String databaseFileName = 'ai_dictionary.db';
  static const int databaseVersion = 1;

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
}
