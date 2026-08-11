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

  /// 兼容多种填法：尾随斜杠、已带 /chat/completions 等。
  String get _endpoint {
    var base = config.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.isEmpty || base.endsWith('/chat/completions')) return base;
    return '$base/chat/completions';
  }

  @override
  Future<String> testConnection() async {
    if (!config.isConfigured) {
      throw const AiConfigException();
    }
    final payload = {
      'model': config.modelName,
      'messages': [
        {'role': 'user', 'content': '你好，请回复"连接成功"四个字。'},
      ],
      'max_tokens': 16,
      'temperature': 0,
    };
    return _chat(payload);
  }

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
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${config.apiKey}',
            },
            body: jsonEncode(payload),
          )
          .timeout(AppConfig.aiRequestTimeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AiConfigException(
          'API Key 无效或已过期（HTTP ${response.statusCode}），请检查 AI 服务配置。',
        );
      }
      if (response.statusCode != 200) {
        final detail = _extractErrorDetail(response);
        throw AiServiceException(
          'AI 服务返回异常（HTTP ${response.statusCode}）$detail',
        );
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

  /// 尝试从常见错误响应中提取服务端错误信息（OpenAI/DeepSeek 格式）。
  String _extractErrorDetail(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) {
            return '：$message';
          }
        } else if (error is String && error.isNotEmpty) {
          return '：$error';
        }
      }
    } catch (_) {
      // 非 JSON 错误体，忽略
    }
    return '';
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
