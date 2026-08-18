/// AI 服务预设：一键填入官方已验证的地址与模型名，降低新手配置门槛。
class AiServicePreset {
  const AiServicePreset({
    required this.name,
    required this.baseUrl,
    required this.modelName,
  });

  final String name;
  final String baseUrl;
  final String modelName;
}

class AiServicePresets {
  AiServicePresets._();

  /// 下拉框中"自定义"选项的取值。
  static const String customKey = 'custom';

  /// 常用 OpenAI 兼容服务预设（地址与模型名均为官方验证可用值）。
  static const List<AiServicePreset> all = [
    AiServicePreset(
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      modelName: 'deepseek-v4-flash',
    ),
    AiServicePreset(
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      modelName: 'gpt-4o-mini',
    ),
    AiServicePreset(
      name: '通义千问（Qwen）',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      modelName: 'qwen-plus',
    ),
    AiServicePreset(
      name: '本地模型（Ollama）',
      baseUrl: 'http://localhost:11434/v1',
      modelName: 'llama3.2',
    ),
  ];

  /// 根据当前地址与模型名匹配预设；不匹配返回 null（视为自定义）。
  static String? match(String baseUrl, String modelName) {
    final b = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final m = modelName.trim();
    for (final p in all) {
      if (p.baseUrl.trim().replaceAll(RegExp(r'/+$'), '') == b &&
          p.modelName.trim() == m) {
        return p.name;
      }
    }
    return null;
  }

  static AiServicePreset? byName(String name) {
    for (final p in all) {
      if (p.name == name) return p;
    }
    return null;
  }
}
