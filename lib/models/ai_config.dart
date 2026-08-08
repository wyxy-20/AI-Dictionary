import '../core/config/app_config.dart';

/// AI 服务配置（OpenAI 兼容接口：OpenAI / DeepSeek / Qwen / 本地模型）。
class AiConfig {
  const AiConfig({
    this.baseUrl = AppConfig.defaultAiBaseUrl,
    this.apiKey = '',
    this.modelName = AppConfig.defaultAiModelName,
  });

  final String baseUrl;
  final String apiKey;
  final String modelName;

  /// 是否已具备调用 AI 服务的基本条件。
  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      modelName.trim().isNotEmpty;

  factory AiConfig.fromMap(Map<String, Object?> map) {
    return AiConfig(
      baseUrl: map['base_url'] as String? ?? AppConfig.defaultAiBaseUrl,
      apiKey: map['api_key'] as String? ?? '',
      modelName: map['model_name'] as String? ?? AppConfig.defaultAiModelName,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': 1,
      'base_url': baseUrl,
      'api_key': apiKey,
      'model_name': modelName,
    };
  }
}
