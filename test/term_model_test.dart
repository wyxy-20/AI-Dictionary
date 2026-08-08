import 'package:ai_dictionary/models/term.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Term 模型', () {
    test('fromJson / toMap / fromMap 往返一致', () {
      final json = {
        'english_name': 'Transformer',
        'chinese_name': 'Transformer',
        'category': '深度学习',
        'difficulty': 2,
        'short_description': '短介绍',
        'detail_description': '详细介绍',
        'application': ['机器翻译', '大模型'],
        'related_terms': ['Attention', 'LLM'],
      };
      final term = Term.fromJson(json);

      expect(term.englishName, 'Transformer');
      expect(term.application, ['机器翻译', '大模型']);
      expect(term.relatedTerms, ['Attention', 'LLM']);
      expect(term.difficulty, 2);
      expect(term.favorite, isFalse);
      expect(term.id, isNull);

      final restored = Term.fromMap(term.toMap());
      expect(restored.englishName, term.englishName);
      expect(restored.chineseName, term.chineseName);
      expect(restored.category, term.category);
      expect(restored.difficulty, term.difficulty);
      expect(restored.shortDescription, term.shortDescription);
      expect(restored.detailDescription, term.detailDescription);
      expect(restored.application, term.application);
      expect(restored.relatedTerms, term.relatedTerms);
      expect(restored.firstCreated, term.firstCreated);
    });

    test('firstLetter 提取正确', () {
      Term term(String name) => Term(
            englishName: name,
            chineseName: '',
            category: 'c',
            difficulty: 1,
            shortDescription: '',
            detailDescription: '',
            application: const [],
            relatedTerms: const [],
            firstCreated: 0,
          );

      expect(term('Agent').firstLetter, 'A');
      expect(term('api').firstLetter, 'A');
      expect(term('123GPT').firstLetter, '#');
      expect(term('').firstLetter, '#');
    });

    test('favorite copyWith 生效', () {
      final t = Term(
        englishName: 'AI',
        chineseName: '人工智能',
        category: 'c',
        difficulty: 1,
        shortDescription: '',
        detailDescription: '',
        application: const [],
        relatedTerms: const [],
        firstCreated: 0,
      );
      final fav = t.copyWith(favorite: true);
      expect(fav.favorite, isTrue);
      expect(t.favorite, isFalse);
      expect(fav.englishName, 'AI');
    });
  });
}
