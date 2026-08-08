import '../../models/term.dart';

/// AI 服务异常体系：UI 层据此展示友好提示，任何异常都不会导致崩溃。
class AiConfigException implements Exception {
  const AiConfigException([this.message = '请先配置AI服务。']);
  final String message;
  @override
  String toString() => message;
}

class AiNetworkException implements Exception {
  const AiNetworkException([this.message = 'AI服务暂时不可用。']);
  final String message;
  @override
  String toString() => message;
}

class AiTimeoutException implements Exception {
  const AiTimeoutException([this.message = '请求超时，请稍后重试。']);
  final String message;
  @override
  String toString() => message;
}

class AiEmptyResponseException implements Exception {
  const AiEmptyResponseException([this.message = 'AI 返回内容为空，请重试。']);
  final String message;
  @override
  String toString() => message;
}

class AiServiceException implements Exception {
  const AiServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 未来 AI 功能服务接口（预留架构）。
///
/// UI 层只通过 Provider 调用本接口，禁止直接接触 API。
/// 当前实现：OpenAI 兼容接口（OpenAI / DeepSeek / Qwen / 本地模型）。
abstract class AiService {
  /// AI 解释：面向零基础用户解释一个术语（固定输出格式）。
  Future<String> explainTerm(Term term);

  /// AI 问答：回答用户关于 AI 概念的问题。
  Future<String> askQuestion(String question);

  /// 学习路径：根据目标自动生成推荐学习路线。
  Future<List<String>> learningPath(String goal);

  // 未来扩展（预留，本次不实现）：
  // Future<String> compareTerms(Term a, Term b);
  // Future<String> generateNewTerm(String keyword);
}

/// 占位实现：用于测试与无 API Key 时的降级。
class StubAiService implements AiService {
  const StubAiService();

  @override
  Future<String> explainTerm(Term term) async {
    return '【一句话理解】\n${term.englishName}（${term.chineseName}）是 AI 领域的一个重要概念，可以用简单的方式理解它。\n\n'
        '【详细解释】\n- 它是什么：${term.chineseName}，英文 ${term.englishName}。\n'
        '- 它解决什么问题：帮助人们理解和使用 AI 技术。\n'
        '- 基本原理：${term.shortDescription}\n\n'
        '【实际应用】\n- ${term.application.isNotEmpty ? term.application.first : 'AI 学习与开发'}\n\n'
        '【为什么重要】\n理解 ${term.englishName} 是学习 AI 的重要一步。\n\n'
        '【相关概念】\n${term.relatedTerms.take(3).join('、')}';
  }

  @override
  Future<String> askQuestion(String question) async {
    return 'AI 问答功能即将上线。你问的是：$question';
  }

  @override
  Future<List<String>> learningPath(String goal) async {
    return const ['学习路径功能即将上线', '接入 AiService 后自动生成学习路线'];
  }
}
