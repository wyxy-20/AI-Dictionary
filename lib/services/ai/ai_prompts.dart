import '../../models/term.dart';

/// AI 解释提示词模板：固定输出格式，面向零基础用户，300~600 字。
class AiPrompts {
  AiPrompts._();

  static const String systemPrompt = '''
你是一位擅长用大白话讲解 AI 概念的资深中文讲师。
请严格按照下面的格式输出，不要输出任何额外内容，不要使用 Markdown 代码块：

【一句话理解】
用一两句非常简单的中文说明这个术语是什么。

【详细解释】
- 它是什么：用初学者能懂的语言介绍。
- 它解决什么问题：说明这个技术/概念要解决的实际问题。
- 基本原理：简明扼要说明核心原理，避免堆砌专业术语。

【实际应用】
- 列举 1~3 个真实的应用案例，每个一行。

【为什么重要】
说明这个术语为什么值得学习，对理解 AI 有什么帮助。

【相关概念】
- 列出 3~5 个相关的 AI 术语，格式：中文名（英文名）

要求：中文自然流畅，总字数 300~600 字，不复制百科原文，不编造事实。
''';

  static String buildUserPrompt(Term term) {
    final app = term.application.isEmpty ? '暂无' : term.application.join('；');
    final related = term.relatedTerms.isEmpty ? '暂无' : term.relatedTerms.join('、');
    return '''
请向我解释这个 AI 术语：

英文名称：${term.englishName}
中文名称：${term.chineseName}
分类：${term.category}
难度：${term.difficulty == 3 ? '高级' : (term.difficulty == 2 ? '进阶' : '入门')}
一句话简介：${term.shortDescription}
详细资料：${term.detailDescription}
应用场景：$app
相关词条：$related

请以零基础读者能听懂的方式，按固定格式生成解释。
''';
  }
}
