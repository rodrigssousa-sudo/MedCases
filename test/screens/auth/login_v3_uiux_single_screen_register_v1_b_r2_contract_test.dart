import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/login_screen.dart').readAsStringSync();
  });

  group('Login V3 single-screen register with R13A vertical balance', () {
    test('register remains a single scrollable screen', () {
      expect(source, contains('REGISTER_V3_SINGLE_SCREEN'));
      expect(source, contains('_registerPhotoPicker()'));
      expect(source, contains('_confirmPasswordField()'));
      expect(source, contains('_studyCtrl'));
      expect(source, contains('_MedicalDisclaimerCheckbox('));
      expect(source, isNot(contains('_regStep')));
      expect(source, isNot(contains('_buildStepIndicator()')));
      expect(source, contains('SingleChildScrollView('));
    });

    test('Google and Apple remain one side-by-side branded row at 46px', () {
      final start = source.indexOf('Widget _buildSocialLoginSection()');
      final end = source.indexOf('Widget _socialAuthButton(', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final region = source.substring(start, end);
      expect(region, contains("provider: 'google'"));
      expect(region, contains("label: 'Google'"));
      expect(region, contains("provider: 'apple'"));
      expect(region, contains("label: 'Apple'"));
      expect(region, contains('height: 46'));
      expect(region, isNot(contains('height: 56')));
    });

    test('R13A hero grows M+ by exactly 10px', () {
      expect(
          source,
          contains(
              'MEDCASES_LOGIN_V4_BREATHING_BRANDED_SOCIAL_KEYBOARD_FLOW_V1_B_R13A'));
      expect(source, contains('width: keyboardOpen ? 64 : 78'));
      expect(source, contains('height: keyboardOpen ? 64 : 78'));
      expect(source, contains('fontSize: keyboardOpen ? 24 : 28'));
      expect(source, contains('fontSize: 13.5'));
    });

    test('login legal footer is fixed 10px from physical bottom', () {
      expect(source, contains('if (isLogin && !keyboardOpen)'));
      expect(source, contains('bottom: 10'));
      expect(source, contains('if (!isLogin) ...['));
      expect(
          source,
          contains(
              'final bottom = keyboardOpen ? 18.0 : (isLogin ? 104.0 : 16.0);'));
    });

    test('keyboard remains native and scrollable', () {
      expect(source, contains('ScrollViewKeyboardDismissBehavior.onDrag'));
      final padding = RegExp(
        r'scrollPadding:\s*(?:const\s+)?EdgeInsets\.only\(\s*'
        r'bottom:\s*96\s*,?\s*\)',
        multiLine: true,
      );
      expect(padding.allMatches(source).length, greaterThanOrEqualTo(2));
    });

    test('auth routes remain untouched', () {
      expect(source, contains('AuthService.login('));
      expect(source, contains('AuthService.register('));
      expect(source, contains('AuthService.resetPassword('));
      expect(source, contains('SocialAuthService.signInWithGoogle'));
      expect(source, contains('SocialAuthService.signInWithApple'));
      expect(source, contains('session_keep_logged_in'));
    });
  });
}
