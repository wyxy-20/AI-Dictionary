import 'package:flutter/foundation.dart';

import '../models/term.dart';
import '../services/ai/ai_service.dart';
import 'dictionary_provider.dart';

/// AI 解释面板状态：控制右侧侧边栏的显示/隐藏、加载/成功/错误状态。
enum AiExplanationStatus { idle, loading, success, error }

class AiExplanationProvider extends ChangeNotifier {
  AiExplanationProvider(this._dictionaryProvider) {
    // 跟随词条切换：面板打开时，选中词条变化自动加载对应解释。
    _dictionaryProvider.addListener(_onDictionaryChanged);
  }

  final DictionaryProvider _dictionaryProvider;

  bool _isOpen = false;
  AiExplanationStatus _status = AiExplanationStatus.idle;
  Term? _term;
  String? _content;
  String? _error;
  int? _handledTermId;

  bool get isOpen => _isOpen;
  AiExplanationStatus get status => _status;
  Term? get term => _term;
  String? get content => _content;
  String? get error => _error;

  void toggle() {
    _isOpen = !_isOpen;
    notifyListeners();
    _syncWithSelection();
  }

  void open() {
    if (_isOpen) {
      _syncWithSelection();
      return;
    }
    _isOpen = true;
    notifyListeners();
    _syncWithSelection();
  }

  void close() {
    _isOpen = false;
    notifyListeners();
  }

  /// 生成（或读取缓存）指定词条的 AI 解释，并打开侧边栏展示。
  ///
  /// [force] 为 true 时忽略缓存，重新调用 AI 并覆盖缓存。
  Future<void> generate(Term term, {bool force = false}) async {
    _handledTermId = term.id;
    _term = term;
    _status = AiExplanationStatus.loading;
    _content = null;
    _error = null;
    _isOpen = true;
    notifyListeners();

    try {
      final result = await _dictionaryProvider.explainTerm(term, force: force);
      _content = result;
      _status = AiExplanationStatus.success;
    } on Exception catch (e) {
      _error = _friendlyMessage(e);
      _status = AiExplanationStatus.error;
    }
    notifyListeners();
  }

  /// 面板打开时，把侧边栏同步到当前选中的词条（缓存优先）。
  void _syncWithSelection() {
    final selected = _dictionaryProvider.selectedTerm;
    final selectedId = selected?.id;
    if (!_isOpen || selectedId == null) return;
    if (_handledTermId == selectedId) return;
    _handledTermId = selectedId;
    generate(selected!);
  }

  void _onDictionaryChanged() {
    _syncWithSelection();
  }

  @override
  void dispose() {
    _dictionaryProvider.removeListener(_onDictionaryChanged);
    super.dispose();
  }

  static String _friendlyMessage(Object error) {
    if (error is AiConfigException) return error.message;
    if (error is AiTimeoutException) return error.message;
    if (error is AiNetworkException) return error.message;
    if (error is AiEmptyResponseException) return error.message;
    if (error is AiServiceException) return error.message;
    return 'AI 解释生成失败，请稍后重试。';
  }
}
