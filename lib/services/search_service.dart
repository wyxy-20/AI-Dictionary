import 'dart:math' as math;

import '../models/term.dart';
import '../utils/string_utils.dart';

/// 高级搜索服务：
/// - 英文搜索（精确 / 前缀 / 包含）
/// - 中文搜索（包含）
/// - 关键词搜索（简介、详细解释、应用场景、相关词条）
/// - 模糊搜索（编辑距离 ≤ 2）
///
/// 返回按相关度降序排列的结果。
class SearchService {
  const SearchService();

  List<Term> search(List<Term> terms, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return List.of(terms);

    final tokens = query
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return List.of(terms);

    final scored = <({Term term, int score})>[];
    for (final term in terms) {
      final score = _scoreTerm(term, tokens);
      if (score != null) {
        scored.add((term: term, score: score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.term.englishName
          .toLowerCase()
          .compareTo(b.term.englishName.toLowerCase());
    });

    return scored.map((e) => e.term).toList();
  }

  int? _scoreTerm(Term term, List<String> tokens) {
    var total = 0;
    for (final token in tokens) {
      final score = _scoreToken(term, token);
      if (score == null) return null;
      total += score;
    }
    return total;
  }

  int? _scoreToken(Term term, String token) {
    if (token.isEmpty) return 0;

    final en = term.englishName.toLowerCase();
    final zh = term.chineseName.toLowerCase();
    final category = term.category.toLowerCase();
    final short = term.shortDescription.toLowerCase();
    final detail = term.detailDescription.toLowerCase();
    final application = term.application.join(' ').toLowerCase();
    final related = term.relatedTerms.join(' ').toLowerCase();

    final scores = <int>[];
    if (en == token) return 120;
    if (en.startsWith(token)) scores.add(105);
    if (en.contains(token)) scores.add(85);
    if (zh.contains(token)) scores.add(95);
    if (category.contains(token)) scores.add(55);
    if (short.contains(token) || detail.contains(token)) scores.add(45);
    if (application.contains(token) || related.contains(token)) scores.add(35);

    // 模糊匹配：仅对较短的英文查询生效，避免误匹配长串。
    if (token.length >= 3 && token.length <= 12 && RegExp(r'^[a-z0-9]+$').hasMatch(token)) {
      final distance = StringUtils.levenshtein(en, token);
      if (distance > 0 && distance <= 2) {
        scores.add(60 - distance * 10);
      }
    }

    if (scores.isEmpty) return null;
    return scores.reduce(math.max);
  }
}
