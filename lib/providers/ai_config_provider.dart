import 'package:flutter/foundation.dart';

import '../database/ai_settings_dao.dart';
import '../models/ai_config.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/openai_compatible_ai_service.dart';

/// AI 服务配置状态：负责保存配置并构建当前生效的 [AiService]。
///
/// 更换 baseUrl / apiKey / modelName 后，下次构建即生效，无需重启。
class AiConfigProvider extends ChangeNotifier {
  AiConfigProvider(this.dao, {this.serviceFactory});

  final AiSettingsDao dao;

  /// 允许测试注入自定义服务工厂（默认使用 OpenAI 兼容实现）。
  final AiService Function(AiConfig config)? serviceFactory;

  AiConfig _config = const AiConfig();
  AiConfig get config => _config;

  bool get isConfigured => _config.isConfigured;

  Future<void> load() async {
    _config = await dao.get();
    notifyListeners();
  }

  Future<void> save(AiConfig config) async {
    await dao.save(config);
    _config = config;
    notifyListeners();
  }

  /// 构建当前配置对应的 AI 服务实例。
  AiService buildService() {
    final factory = serviceFactory;
    if (factory != null) return factory(_config);
    return OpenAiCompatibleAiService(_config);
  }
}
