import 'package:ai_dictionary/utils/version_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionUtils', () {
    test('相同版本返回 0', () {
      expect(VersionUtils.compare('1.1.0', '1.1.0'), 0);
      expect(VersionUtils.compare('1.0.0', '1.0.0'), 0);
    });

    test('低版本小于高版本', () {
      expect(VersionUtils.compare('1.0.0', '1.1.0'), lessThan(0));
      expect(VersionUtils.compare('1.9.9', '2.0.0'), lessThan(0));
      expect(VersionUtils.compare('1.1.0', '1.10.0'), lessThan(0));
    });

    test('高版本大于低版本', () {
      expect(VersionUtils.compare('1.1.0', '1.0.0'), greaterThan(0));
      expect(VersionUtils.compare('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('v 前缀与缺失段容错', () {
      expect(VersionUtils.compare('v1.1.0', '1.1.0'), 0);
      expect(VersionUtils.compare('1.1', '1.1.0'), 0);
      expect(VersionUtils.compare('abc', '1.0.0'), lessThan(0));
    });
  });
}
