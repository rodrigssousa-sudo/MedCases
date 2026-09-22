import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/calculator_origin_policy.dart';

void main() {
  test('only exact canonical HTTPS origins may host bridges', () {
    final policy = CalculatorOriginPolicy();
    for (final url in [
      'https://medcasescalcu.com/path',
      'https://www.medcasescalcu.com/?lang=pt'
    ]) {
      expect(policy.allows(url), isTrue);
    }
    for (final url in [
      'http://medcasescalcu.com',
      'https://medcasescalcu.com:444',
      'https://medcasescalcu.com.evil.test',
      'https://user@medcasescalcu.com',
      'https://evil.test',
      'javascript:alert(1)',
      'data:text/html,hello',
      'file:///tmp/other.html'
    ]) {
      expect(policy.allows(url), isFalse, reason: url);
    }
  });
  test('offline trust is exact and cleared on online selection', () {
    final policy = CalculatorOriginPolicy();
    policy.selectLocalDocument('file:///cache/index.html?lang=pt');
    expect(policy.allows('file:///cache/index.html?lang=es#drugs'), isTrue);
    expect(policy.allows('file:///cache/other.html'), isFalse);
    expect(policy.allows('file://evil/cache/index.html'), isFalse);
    policy.selectLocalDocument('https://medcasescalcu.com');
    expect(policy.allows('file:///cache/index.html'), isFalse);
  });
}
