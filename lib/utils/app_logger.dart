import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 极简文件日志器：写入应用支持目录下的 logs/app.log。
///
/// 设计原则：
/// - 日志系统自身绝不抛错，任何写失败都静默忽略；
/// - 未初始化（如测试环境无 path_provider 插件）时所有日志安全丢弃；
/// - 日志文件超过 [maxLogBytes] 时轮转为 app.log.old 并重新开始。
class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  /// 日志文件大小上限（512KB），超出后轮转。
  static const int maxLogBytes = 512 * 1024;

  File? _file;
  bool _ready = false;

  /// 当前日志文件路径；未初始化时为 null。
  String? get filePath => _file?.path;

  /// 真实环境初始化：日志写入 getApplicationSupportDirectory()/logs/app.log。
  ///
  /// 测试环境（flutter test 会设置 FLUTTER_TEST=true）中 path_provider 的
  /// 平台通道调用不会完成，会导致启动流程挂起，因此直接保持未就绪。
  Future<void> init() async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      _ready = false;
      return;
    }
    try {
      final dir = await getApplicationSupportDirectory();
      await initWithDirectory('${dir.path}${Platform.pathSeparator}logs');
    } catch (_) {
      // path_provider 不可用（如测试环境）：保持未就绪，日志静默丢弃。
      _ready = false;
    }
  }

  /// 测试注入：将日志写入指定目录。
  Future<void> initWithDirectory(String directory) async {
    try {
      final logDir = Directory(directory);
      await logDir.create(recursive: true);
      _file = File(p.join(directory, 'app.log'));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> info(String tag, String message) =>
      _write('INFO', tag, message);

  Future<void> warn(String tag, String message) =>
      _write('WARN', tag, message);

  Future<void> error(String tag, String message) =>
      _write('ERROR', tag, message);

  Future<void> _write(String level, String tag, String message) async {
    final file = _file;
    if (!_ready || file == null) return;
    try {
      final line =
          '[${DateTime.now().toIso8601String()}] [$level] [$tag] $message\n';
      await file.writeAsString(line, mode: FileMode.append);
      if (await file.length() > maxLogBytes) {
        await _rotate(file);
      }
    } catch (_) {
      // 日志失败不向上传播。
    }
  }

  Future<void> _rotate(File file) async {
    try {
      final old = File('${file.path}.old');
      if (await old.exists()) await old.delete();
      await file.rename(old.path);
    } catch (_) {
      // 轮转失败不影响后续写入。
    }
  }

  /// 读取完整日志内容（用于"导出日志"）。
  Future<String> readLog() async {
    final file = _file;
    if (!_ready || file == null) return '';
    try {
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// 清空日志（测试用）。
  Future<void> clear() async {
    final file = _file;
    if (!_ready || file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
