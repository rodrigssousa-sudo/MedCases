import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/calculator_origin_policy.dart';

void main() {
  test('public Wix document loads only as a frame, never as a bridge origin', () {
    final policy = CalculatorOriginPolicy();
    const url = 'https://b047deb0-a06e-4403-942c-743fbdb9667b.filesusr.com/html/817a38_55582a1776679463f24dc9b1f9870c9d.html';
    expect(policy.allowsNavigation(url, isMainFrame: false), isTrue);
    expect(policy.allowsNavigation(url, isMainFrame: true), isFalse);
    expect(policy.allows(url), isFalse);
    for (final other in [url.replaceFirst('https:', 'http:'),
      url.replaceFirst('.filesusr.com', '.filesusr.com.evil.test'),
      url.replaceFirst('/html/', '/other/'),
      url.replaceFirst('https://', 'https://user@'),
      url.replaceFirst('.html', '-other.html')]) {
      expect(policy.allowsNavigation(other, isMainFrame: false), isFalse);
    }
    for (final host in ['medcasescalcu.com', 'www.medcasescalcu.com']) {
      expect(policy.allowsNavigation('https://$host/?tab=farmacos&lang=es', isMainFrame: true), isTrue);
    }
  });
  test('drug routes use the MCC1 HTTPS document even with cached HTML', () {
    for (final locale in ['pt', 'es']) {
      expect(
          CalculatorOriginPolicy.requiresOnlineDrugDocument(
              'https://www.medcasescalcu.com/?tab=farmacos&lang=$locale&q=metformina'),
          isTrue);
    }
    for (final url in [
      'https://www.medcasescalcu.com/?tab=scores',
      'https://www.medcasescalcu.com/',
      'file:///cache/index.html?tab=farmacos',
      'https://evil.test/?tab=farmacos',
      'http://www.medcasescalcu.com/?tab=farmacos',
    ]) {
      expect(CalculatorOriginPolicy.requiresOnlineDrugDocument(url), isFalse);
    }
  });

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
