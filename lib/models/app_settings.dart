/// 应用设置模型：对应 settings 表（单行）。
class AppSettings {
  const AppSettings({this.theme = 'system', this.language = 'zh'});

  /// system / light / dark
  final String theme;

  /// zh / en
  final String language;

  factory AppSettings.fromMap(Map<String, Object?> map) {
    return AppSettings(
      theme: map['theme'] as String? ?? 'system',
      language: map['language'] as String? ?? 'zh',
    );
  }

  AppSettings copyWith({String? theme, String? language}) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
    );
  }
}
