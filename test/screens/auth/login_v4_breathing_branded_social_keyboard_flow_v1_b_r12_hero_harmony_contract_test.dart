import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  setUpAll(() {
    source = File('lib/screens/login_screen.dart').readAsStringSync();
  });

  group('Login hero harmony continued by R13A', () {
    test('M+ is 78px closed and 64px keyboard-open', () {
      expect(
          source,
          contains(
              'MEDCASES_LOGIN_V4_BREATHING_BRANDED_SOCIAL_KEYBOARD_FLOW_V1_B_R13A'));
      expect(source, contains('width: keyboardOpen ? 64 : 78'));
      expect(source, contains('height: keyboardOpen ? 64 : 78'));
    });

    test('title and subtitle remain R12 sizes', () {
      expect(source, contains('fontSize: keyboardOpen ? 24 : 28'));
      expect(source, contains('fontSize: 13.5'));
    });

    test('body is lowered through real current layout variables', () {
      expect(
          source,
          contains(
              'final top = isLogin ? (keyboardOpen ? 10.0 : 26.0) : 16.0;'));
      expect(source, contains('SizedBox(height: isLogin ? 26 : 16)'));
      expect(source, contains('SizedBox(height: keyboardOpen ? 18 : 28)'));
    });

    test('footer is fixed to 10px bottom outside login scroll flow', () {
      expect(source, contains('if (isLogin && !keyboardOpen)'));
      expect(source, contains('bottom: 10'));
      expect(source, contains('if (!isLogin) ...['));
    });

    test('social row remains 46px', () {
      final start = source.indexOf('Widget _buildSocialLoginSection()');
      final end = source.indexOf('Widget _socialAuthButton(', start);
      final region = source.substring(start, end);
      expect(region, contains('height: 46'));
      expect(region, isNot(contains('height: 56')));
    });
  });
}
