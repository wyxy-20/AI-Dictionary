import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../models/ai_config.dart';
import '../../models/term.dart';
import 'ai_prompts.dart';
import 'ai_service.dart';

/// OpenAI 兼容接口的 AI 服务实现。
///
/// 兼容 OpenAI、DeepSeek、Qwen、本地模型（Ollama / LM Studio 等）：
/// 只要提供 baseUrl + apiKey + modelName 即可。
class OpenAiCompatibleAiService implements AiService {
  OpenAiCompatibleAiService(this.config, {this.client});

  final AiConfig config;
  final http.Client? client;

  Uri get _endpoint => Uri.parse('${config.baseUrl.trimRight()}/chat/completions');

  @override
  Future<String> explainTerm(Term term) async {
    if (!config.isConfigured) {
      throw const AiConfigException();
    }

    final payload = {
      'model': config.modelName,
      'messages': [
        {'role': 'system', 'content': AiPrompts.systemPrompt},
        {'role': 'user', 'content': AiPrompts.buildUserPrompt(term)},
      ],
      'temperature': 0.5,
      'max_tokens': AppConfig.aiMaxTokens,
    };

    final content = await _chat(payload);
    if (content.trim().isEmpty) {
      throw const AiEmptyResponseException();
    }
    return content;
  }

  Future<String> _chat(Map<String, Object?> payload) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: jsonEncode(payload),
          )
          .timeout(AppConfig.aiRequestTimeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const AiConfigException('API Key 无效，请检查 AI 服务配置。');
      }
      if (response.statusCode != 200) {
        throw AiServiceException('AI 服务返回异常（HTTP ${response.statusCode}）。');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final choices = decoded['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) {
        throw const AiEmptyResponseException();
      }
      final message = choices.first['message'] as Map<String, dynamic>?;
      return message?['content'] as String? ?? '';
    } on TimeoutException {
      throw const AiTimeoutException();
    } on SocketException {
      throw const AiNetworkException();
    } on http.ClientException {
      throw const AiNetworkException();
    } finally {
      if (client == null) httpClient.close();
    }
  }

  @override
  Future<String> askQuestion(String question) async {
    throw const AiServiceException('AI 问答功能即将上线。');
  }

  @override
  Future<List<String>> learningPath(String goal) async {
    throw const AiServiceException('学习路径功能即将上线。');
  }
}
