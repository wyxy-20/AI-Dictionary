import 'dart:convert';

/// 词条模型：对应 SQLite 的 terms 表。
class Term {
  const Term({
    this.id,
    required this.englishName,
    required this.chineseName,
    required this.category,
    required this.difficulty,
    required this.shortDescription,
    required this.detailDescription,
    required this.application,
    required this.relatedTerms,
    required this.firstCreated,
    this.version = 1,
    this.favorite = false,
  });

  final int? id;
  final String englishName;
  final String chineseName;
  final String category;

  /// 难度等级 1~3（入门 / 进阶 / 高级）。
  final int difficulty;
  final String shortDescription;
  final String detailDescription;
  final List<String> application;
  final List<String> relatedTerms;
  final int firstCreated;
  final int version;
  final bool favorite;

  /// 首字母（非字母归为 '#'）。
  String get firstLetter {
    final t = englishName.trim();
    if (t.isEmpty) return '#';
    final c = t[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
  }

  /// 从 JSON 种子数据解析（键名为 snake_case）。
  factory Term.fromJson(Map<String, dynamic> json) {
    return Term(
      englishName: json['english_name'] as String? ?? '',
      chineseName: json['chinese_name'] as String? ?? '',
      category: json['category'] as String? ?? '未分类',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      shortDescription: json['short_description'] as String? ?? '',
      detailDescription: json['detail_description'] as String? ?? '',
      application: _toStringList(json['application']),
      relatedTerms: _toStringList(json['related_terms']),
      firstCreated: (json['first_created'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  /// 从数据库行解析。
  factory Term.fromMap(Map<String, Object?> map) {
    return Term(
      id: map['id'] as int?,
      englishName: map['english_name'] as String? ?? '',
      chineseName: map['chinese_name'] as String? ?? '',
      category: map['category'] as String? ?? '未分类',
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 1,
      shortDescription: map['short_description'] as String? ?? '',
      detailDescription: map['detail_description'] as String? ?? '',
      application: _decodeList(map['application']),
      relatedTerms: _decodeList(map['related_terms']),
      firstCreated: (map['first_created'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 1,
      favorite: (map['favorite'] as num?)?.toInt() == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'english_name': englishName,
      'chinese_name': chineseName,
      'category': category,
      'difficulty': difficulty,
      'short_description': shortDescription,
      'detail_description': detailDescription,
      'application': jsonEncode(application),
      'related_terms': jsonEncode(relatedTerms),
      'first_created': firstCreated,
      'version': version,
      'favorite': favorite ? 1 : 0,
    };
  }

  /// 导出 JSON（供备份 / 词库分发使用）。
  Map<String, dynamic> toJson() {
    return {
      'english_name': englishName,
      'chinese_name': chineseName,
      'category': category,
      'difficulty': difficulty,
      'short_description': shortDescription,
      'detail_description': detailDescription,
      'application': application,
      'related_terms': relatedTerms,
    };
  }

  /// 内容签名：用于判断远程同步时词条内容是否变化（变化则 version +1）。
  String get contentSignature {
    return [
      chineseName,
      category,
      difficulty,
      shortDescription,
      detailDescription,
      application.join('\n'),
      relatedTerms.join('\n'),
    ].join('||');
  }

  Term copyWith({bool? favorite, int? firstCreated, int? version}) {
    return Term(
      id: id,
      englishName: englishName,
      chineseName: chineseName,
      category: category,
      difficulty: difficulty,
      shortDescription: shortDescription,
      detailDescription: detailDescription,
      application: application,
      relatedTerms: relatedTerms,
      firstCreated: firstCreated ?? this.firstCreated,
      version: version ?? this.version,
      favorite: favorite ?? this.favorite,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String) {
      return value
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<String> _decodeList(Object? value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    final s = value.toString();
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      // 忽略并回退到按行拆分。
    }
    return s
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
