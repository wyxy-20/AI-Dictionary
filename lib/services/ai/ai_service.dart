/// 未来 AI 功能服务接口（预留架构）。
///
/// 第一版仅提供 [StubAiService] 占位实现；
/// 后续接入 OpenAI / DeepSeek 等 API 时，实现本接口并替换注入即可，
/// UI 层无需改动。
abstract class AiService {
  /// AI 解释：用大白话解释一个术语。
  Future<String> explainTerm(String term, {String? userQuestion});

  /// AI 问答：回答用户关于 AI 概念的问题。
  Future<String> askQuestion(String question);

  /// 学习路径：根据目标自动生成推荐学习路线。
  Future<List<String>> learningPath(String goal);
}

/// 占位实现：提示功能尚未开放。
class StubAiService implements AiService {
  const StubAiService();

  @override
  Future<String> explainTerm(String term, {String? userQuestion}) async {
    return '“$term”的 AI 解释功能即将上线。\n\n'
        '架构已预留 AiService 接口，接入 API Key 后即可自动生成小白友好的解释。';
  }

  @override
  Future<String> askQuestion(String question) async {
    return 'AI 问答功能即将上线。\n\n'
        '你问的是：“$question”\n'
        '接入 AiService 真实实现后，这里会返回大模型回答。';
  }

  @override
  Future<List<String>> learningPath(String goal) async {
    return const ['学习路径功能即将上线', '接入 AiService 后自动生成学习路线'];
  }
}
