import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfiNoIsolate;

/// 确保测试环境可以加载 sqlite3 原生库。
///
/// sqlite3 3.5+ 使用 Dart native assets：`flutter test` 会自动构建/下载
/// 原生库，因此这里只需初始化 ffi 工厂。
void ensureSqliteAvailable() {
  sqfliteFfiInit();
}
