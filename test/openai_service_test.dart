import 'dart:convert';

import 'package:ai_dictionary/models/ai_config.dart';
import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/services/ai/ai_service.dart';
import 'package:ai_dictionary/services/ai/openai_compatible_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Term makeTerm(String en) {
  return Term(
    englishName: en,
    chineseName: '测试',
    category: '测试',
    difficulty: 1,
    shortDescription: '简介',
    detailDescription: '详细',
    application: const ['场景'],
    relatedTerms: const ['AI'],
    firstCreated: 0,
  );
}

void main() {
  test('正确调用 chat/completions 并解析回复', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      expect(request.headers['Authorization'], 'Bearer sk-test');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'deepseek-chat');
      return http.Response(
        jsonEncode({
          'choices': [
            {'message': {'content': '【一句话理解】\n测试解释'}},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = OpenAiCompatibleAiService(
      const AiConfig(baseUrl: 'https://api.deepseek.com', apiKey: 'sk-test', modelName: 'deepseek-chat'),
      client: client,
    );

    final content = await service.explainTerm(makeTerm('Transformer'));
    expect(content, contains('测试解释'));
    expect(requested.path, '/chat/completions');
    expect(requested.host, 'api.deepseek.com');
  });

  test('baseUrl 尾随斜杠 / 已带路径时都能正确拼接', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        jsonEncode({'choices': [{'message': {'content': 'ok'}}]}),
        200,
      );
    });

    final a = OpenAiCompatibleAiService(
      const AiConfig(baseUrl: 'https://x.com/', apiKey: 'k', modelName: 'm'),
      client: client,
    );
    await a.explainTerm(makeTerm('AI'));

    final b = OpenAiCompatibleAiService(
      const AiConfig(baseUrl: 'https://x.com/v1/chat/completions', apiKey: 'k', modelName: 'm'),
      client: client,
    );
    await b.explainTerm(makeTerm('AI'));

    expect(paths, ['/chat/completions', '/v1/chat/completions']);
  });

  test('401 抛出配置异常并给出明确提示', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error': {'message': 'Authentication Fails'},
        }),
        401,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = OpenAiCompatibleAiService(
      const AiConfig(baseUrl: 'https://api.deepseek.com', apiKey: 'sk-bad', modelName: 'deepseek-chat'),
      client: client,
    );

    expect(
      () => service.explainTerm(makeTerm('AI')),
      throwsA(
        isA<AiConfigException>().having(
          (e) => e.message,
          'message',
          contains('401'),
        ),
      ),
    );
  });

  test('未配置 API Key 抛出配置异常', () async {
    final service = OpenAiCompatibleAiService(const AiConfig());
    expect(
      () => service.explainTerm(makeTerm('AI')),
      throwsA(isA<AiConfigException>()),
    );
    expect(
      () => service.testConnection(),
      throwsA(isA<AiConfigException>()),
    );
  });

  test('testConnection 返回模型回复', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'choices': [
            {'message': {'content': '连接成功'}},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = OpenAiCompatibleAiService(
      const AiConfig(baseUrl: 'https://api.deepseek.com', apiKey: 'sk-test', modelName: 'deepseek-chat'),
      client: client,
    );
    expect(await service.testConnection(), contains('连接成功'));
  });
}
