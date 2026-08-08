/// AI 解释缓存记录（对应 ai_explanation_cache 表）。
class AiExplanation {
  const AiExplanation({
    this.id,
    required this.termId,
    required this.termVersion,
    required this.content,
    required this.modelName,
    required this.createdTime,
    required this.updatedTime,
  });

  final int? id;
  final int termId;
  final int termVersion;
  final String content;
  final String modelName;
  final int createdTime;
  final int updatedTime;

  factory AiExplanation.fromMap(Map<String, Object?> map) {
    return AiExplanation(
      id: map['id'] as int?,
      termId: (map['term_id'] as num).toInt(),
      termVersion: (map['term_version'] as num).toInt(),
      content: map['content'] as String,
      modelName: map['model_name'] as String? ?? '',
      createdTime: (map['created_time'] as num).toInt(),
      updatedTime: (map['updated_time'] as num).toInt(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'term_id': termId,
      'term_version': termVersion,
      'content': content,
      'model_name': modelName,
      'created_time': createdTime,
      'updated_time': updatedTime,
    };
  }
}
