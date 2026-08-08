/// 本地 / 远程词库版本信息。
class DictionaryVersion {
  const DictionaryVersion({
    required this.version,
    this.updateTime = '',
    this.termsCount = 0,
    this.lastCheckTime = 0,
  });

  /// 词库版本号（语义化版本，如 1.1.0）。
  final String version;

  /// 词库更新时间（如 2026-08-08）。
  final String updateTime;

  /// 词库词条总数。
  final int termsCount;

  /// 最近一次成功检查更新的时间（毫秒时间戳）。
  final int lastCheckTime;

  factory DictionaryVersion.fromMap(Map<String, Object?> map) {
    return DictionaryVersion(
      version: map['version'] as String? ?? '1.0.0',
      updateTime: map['update_time'] as String? ?? '',
      termsCount: (map['terms_count'] as num?)?.toInt() ?? 0,
      lastCheckTime: (map['last_check_time'] as num?)?.toInt() ?? 0,
    );
  }

  factory DictionaryVersion.fromJson(Map<String, dynamic> json) {
    return DictionaryVersion(
      version: json['version'] as String? ?? '',
      updateTime: json['update_time'] as String? ?? '',
      termsCount: (json['terms_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': 1,
      'version': version,
      'update_time': updateTime,
      'terms_count': termsCount,
      'last_check_time': lastCheckTime,
    };
  }
}
