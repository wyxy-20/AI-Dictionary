import 'package:desktop_multi_window/desktop_multi_window.dart';

/// 悬浮快捷搜索子窗口的启动参数（用于区分主窗口与子窗口）。
const String quickSearchWindowArgument = 'quick_search';

/// 子窗口 -> 主窗口 的单向通道。
///
/// 主窗口注册 handler，子窗口调用 `search` / `selectTerm` / `getState`。
const WindowMethodChannel quickSearchMainChannel = WindowMethodChannel(
  'ai_dict/quick_search/main',
  mode: ChannelMode.unidirectional,
);
