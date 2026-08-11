import 'package:flutter/foundation.dart';

import '../database/ai_explanation_cache_dao.dart';
import '../database/ai_settings_dao.dart';
import '../database/app_database.dart';
import '../database/history_dao.dart';
import '../database/term_dao.dart';
import '../models/term.dart';
import '../models/ai_explanation.dart';
import '../providers/ai_config_provider.dart';
import '../services/ai/ai_service.dart';
import '../services/search_service.dart';

/// 列表视图模式。
enum ViewFilter { all, favorites, recent }

/// 词典核心状态：词库、搜索、视图过滤、选中词条、收藏、历史。
class DictionaryProvider extends ChangeNotifier {
  DictionaryProvider({
    required this.database,
    required this.termDao,
    required this.historyDao,
    SearchService? searchService,
    AiService? aiService,
    AiConfigProvider? aiConfigProvider,
  })  : searchService = searchService ?? const SearchService(),
        aiService = aiService ?? const StubAiService(),
        _aiConfigProvider =
            aiConfigProvider ?? AiConfigProvider(AiSettingsDao(database));

  final AppDatabase database;
  final TermDao termDao;
  final HistoryDao historyDao;
  final SearchService searchService;
  final AiService aiService;
  final AiConfigProvider _aiConfigProvider;

  AiConfigProvider get aiConfigProvider => _aiConfigProvider;
  AiExplanationCacheDao get aiCacheDao =>
      AiExplanationCacheDao(database);

  List<Term> _allTerms = [];
  List<Term> _recentTerms = [];
  bool _loaded = false;
  String _query = '';
  ViewFilter _view = ViewFilter.all;
  String? _letter;
  int? _selectedId;

  List<Term> get allTerms => List.unmodifiable(_allTerms);
  bool get loaded => _loaded;
  String get query => _query;
  ViewFilter get view => _view;
  String? get letter => _letter;
  int get totalCount => _allTerms.length;
  int get favoriteCount => _allTerms.where((t) => t.favorite).length;

  Term? get selectedTerm {
    final id = _selectedId;
    if (id == null) return null;
    for (final term in _allTerms) {
      if (term.id == id) return term;
    }
    return null;
  }

  /// 当前可见词条（应用视图、字母、搜索过滤）。
  List<Term> get visibleTerms {
    Iterable<Term> source = _allTerms;
    if (_view == ViewFilter.favorites) {
      source = source.where((t) => t.favorite);
    } else if (_view == ViewFilter.recent) {
      source = _recentTerms;
    }

    var list = source.toList();
    final letter = _letter;
    if (letter != null) {
      list = list.where((t) => t.firstLetter == letter).toList();
    }
    if (_query.trim().isNotEmpty) {
      list = searchService.search(list, _query);
    }
    return list;
  }

  /// 是否按首字母分组展示（全部视图 + 无搜索 + 无字母过滤时）。
  bool get grouped {
    return _view == ViewFilter.all &&
        _query.trim().isEmpty &&
        _letter == null;
  }

  /// 当前过滤条件的展示名称。
  String get filterLabel {
    if (_query.trim().isNotEmpty) return '搜索结果';
    return switch (_view) {
      ViewFilter.all => _letter == null ? '全部词条' : '字母 $_letter',
      ViewFilter.favorites => '我的收藏',
      ViewFilter.recent => '最近浏览',
    };
  }

  Future<void> load() async {
    _allTerms = await termDao.getAll();
    _recentTerms = await historyDao.getRecentTerms();
    _loaded = true;
    notifyListeners();
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    notifyListeners();
  }

  void setView(ViewFilter view) {
    if (_view == view && _letter == null) return;
    _view = view;
    _letter = null;
    notifyListeners();
  }

  void setLetter(String? letter) {
    if (_letter == letter) return;
    _letter = letter;
    notifyListeners();
  }

  void clearFilters() {
    _view = ViewFilter.all;
    _letter = null;
    _query = '';
    notifyListeners();
  }

  /// 选中词条并记录到历史。
  Future<void> selectTerm(Term term) async {
    _selectedId = term.id;
    notifyListeners();
    final id = term.id;
    if (id != null) {
      await historyDao.recordView(id);
      _recentTerms = await historyDao.getRecentTerms();
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Term term) async {
    final id = term.id;
    if (id == null) return;
    final favorite = !term.favorite;
    await termDao.setFavorite(id, favorite);
    _allTerms = _allTerms
        .map((t) => t.id == id ? t.copyWith(favorite: favorite) : t)
        .toList();
    notifyListeners();
  }

  /// 通过英文名查找词条（用于“相关词条”跳转）。
  Future<Term?> findTermByName(String name) async {
    for (final term in _allTerms) {
      if (term.englishName.toLowerCase() == name.toLowerCase()) return term;
    }
    final term = await termDao.byEnglishName(name);
    if (term != null && !_allTerms.any((t) => t.id == term.id)) {
      _allTerms.add(term);
      _allTerms.sort(
        (a, b) => a.englishName.toLowerCase().compareTo(b.englishName.toLowerCase()),
      );
    }
    return term;
  }

  /// 数据重置 / 清空历史后刷新。
  Future<void> refreshAll() async {
    _allTerms = await termDao.getAll();
    _recentTerms = await historyDao.getRecentTerms();
    notifyListeners();
  }

  void clearSelection() {
    _selectedId = null;
    notifyListeners();
  }

  /// AI 解释：缓存优先 -> 未命中则调用 AI 服务 -> 成功后写入缓存。
  ///
  /// 缓存按 (term_id, term_version, model_name) 校验：
  /// 词条内容更新（version 提升）或切换模型后旧缓存自动失效。
  Future<String> explainTerm(Term term, {bool force = false}) async {
    final id = term.id;
    if (id == null) throw const AiServiceException('词条尚未入库，无法生成解释。');

    final config = _aiConfigProvider.config;
    if (!force) {
      final cache = await aiCacheDao.findValid(id, term.version, config.modelName);
      if (cache != null) return cache.content;
    }

    final content = await _aiConfigProvider.buildService().explainTerm(term);
    final now = DateTime.now().millisecondsSinceEpoch;
    await aiCacheDao.upsert(AiExplanation(
      termId: id,
      termVersion: term.version,
      content: content,
      modelName: config.modelName,
      createdTime: now,
      updatedTime: now,
    ));
    return content;
  }

  /// 读取指定词条的有效 AI 解释缓存；没有则返回 null（不会调用 AI）。
  Future<String?> getCachedExplanation(Term term) async {
    final id = term.id;
    if (id == null) return null;
    final config = _aiConfigProvider.config;
    final cache = await aiCacheDao.findValid(id, term.version, config.modelName);
    return cache?.content;
  }
}
