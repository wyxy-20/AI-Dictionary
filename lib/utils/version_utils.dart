/// 语义化版本号比较工具。
class VersionUtils {
  VersionUtils._();

  /// 比较两个版本号：
  /// 返回 >0 表示 a 较新，<0 表示 b 较新，=0 表示相同。
  static int compare(String a, String b) {
    final pa = _parse(a);
    final pb = _parse(b);
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return 0;
  }

  /// 将版本字符串解析为最多三段的数字（主/次/修订），非法段按 0 处理。
  static List<int> _parse(String version) {
    final cleaned = version.trim().replaceAll(RegExp(r'^v'), '');
    final segments = cleaned.split(RegExp(r'[.\-+]'));
    final result = <int>[0, 0, 0];
    for (var i = 0; i < segments.length && i < 3; i++) {
      result[i] = int.tryParse(segments[i]) ?? 0;
    }
    return result;
  }
}
