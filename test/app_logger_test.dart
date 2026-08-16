import 'dart:io';

import 'package:ai_dictionary/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('app_logger_test');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('写入日志并读取', () async {
    final logger = AppLogger.instance;
    await logger.initWithDirectory(tempDir.path);

    await logger.info('test', 'hello info');
    await logger.warn('test', 'hello warn');
    await logger.error('test', 'hello error');

    final content = await logger.readLog();
    expect(content, contains('[INFO] [test] hello info'));
    expect(content, contains('[WARN] [test] hello warn'));
    expect(content, contains('[ERROR] [test] hello error'));
  });

  test('未初始化时日志静默丢弃，不抛错', () async {
    final logger = AppLogger.instance;
    await logger.clear(); // 未就绪时调用应安全
    await logger.info('test', 'should be dropped');
    expect(await logger.readLog(), isEmpty);
  });

  test('超过大小上限后轮转日志文件', () async {
    final logger = AppLogger.instance;
    await logger.initWithDirectory(tempDir.path);
    final logFile = File('${tempDir.path}${Platform.pathSeparator}app.log');
    await logFile.writeAsString('x' * (AppLogger.maxLogBytes + 10));

    await logger.info('test', 'trigger rotate');

    // 超限后旧文件轮转为 .old
    final old = File('${logFile.path}.old');
    expect(await old.exists(), isTrue, reason: '超限后应轮转为 .old');

    // 轮转后再次写入会创建新的日志文件
    await logger.info('test', 'after rotate');
    expect(await logFile.exists(), isTrue, reason: '轮转后新日志文件应被创建');
    expect(await logFile.length(), lessThan(1024));
  });
}
