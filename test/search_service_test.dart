import 'package:ai_dictionary/models/term.dart';
import 'package:ai_dictionary/services/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

Term buildTerm(String en, String zh, {String detail = '', List<String> app = const [], String category = ''}) {
  return Term(
    englishName: en,
    chineseName: zh,
    category: category,
    difficulty: 1,
    shortDescription: detail,
    detailDescription: detail,
    application: app,
    relatedTerms: const [],
    firstCreated: 0,
  );
}

void main() {
  const search = SearchService();
  final terms = [
    buildTerm('Agent', '智能体', detail: '能够自主完成任务的AI系统', app: ['AI助手', '自动化']),
    buildTerm('AGI', '通用人工智能'),
    buildTerm('Transformer', 'Transformer', detail: '基于注意力机制的模型'),
    buildTerm('RAG', '检索增强生成', detail: '先检索再生成'),
    buildTerm('Fine-tuning', '微调', category: '模型训练'),
  ];

  group('SearchService', () {
    test('英文搜索：前缀命中 Transformer', () {
      final result = search.search(terms, 'tran');
      expect(result.first.englishName, 'Transformer');
    });

    test('英文搜索：精确命中 Agent', () {
      final result = search.search(terms, 'Agent');
      expect(result.first.englishName, 'Agent');
    });

    test('中文搜索：智能体', () {
      final result = search.search(terms, '智能体');
      expect(result.first.englishName, 'Agent');
    });

    test('关键词搜索：AI助手 命中 application 字段', () {
      final result = search.search(terms, 'AI助手');
      expect(result, isNotEmpty);
      expect(result.first.englishName, 'Agent');
    });

    test('模糊搜索：tansformer 命中 Transformer', () {
      final result = search.search(terms, 'tansformer');
      expect(result, isNotEmpty);
      expect(result.first.englishName, 'Transformer');
    });

    test('多关键词 AND：agent + 智能 命中 Agent', () {
      final result = search.search(terms, 'agent 智能');
      expect(result, isNotEmpty);
      expect(result.first.englishName, 'Agent');
    });

    test('空查询返回全部', () {
      expect(search.search(terms, '').length, terms.length);
    });

    test('无匹配返回空', () {
      expect(search.search(terms, 'zzzz'), isEmpty);
    });
  });
}
