/// 应用设置模型：对应 settings 表（单行）。
class AppSettings {
  const AppSettings({
    this.theme = 'system',
    this.language = 'zh',
    this.quickSearchHotkey = 'Ctrl+K',
    this.quickSearchEnabled = false,
  });

  /// system / light / dark
  final String theme;

  /// zh / en
  final String language;
  final String quickSearchHotkey;
  final bool quickSearchEnabled;

  factory AppSettings.fromMap(Map<String, Object?> map) {
    return AppSettings(
      theme: map['theme'] as String? ?? 'system',
      language: map['language'] as String? ?? 'zh',
      quickSearchHotkey: map['quick_search_hotkey'] as String? ?? 'Ctrl+K',
      quickSearchEnabled: (map['quick_search_enabled'] as num?)?.toInt() == 1,
    );
  }

  AppSettings copyWith({
    String? theme,
    String? language,
    String? quickSearchHotkey,
    bool? quickSearchEnabled,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      quickSearchHotkey: quickSearchHotkey ?? this.quickSearchHotkey,
      quickSearchEnabled: quickSearchEnabled ?? this.quickSearchEnabled,
    );
  }
}
