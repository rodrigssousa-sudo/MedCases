import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String login;
  late String svg;
  setUpAll(() {
    login = File('lib/screens/login_screen.dart').readAsStringSync();
    svg = File('assets/icons/home_v2/auth_google_g.svg').readAsStringSync();
  });

  group('Login current contract after R13A', () {
    test('owner stack remains coherent', () {
      expect(
          login,
          contains(
              'MEDCASES_LOGIN_V4_BREATHING_BRANDED_SOCIAL_KEYBOARD_FLOW_V1_B_R13A'));
      expect(login,
          contains('MEDCASES_LOGIN_V3_CANONICAL_DARK_VISUAL_CUTOVER_V1_B_R3'));
      expect(login, contains('REGISTER_V3_SINGLE_SCREEN'));
      expect(login, isNot(contains('_regStep')));
    });

    test('R13A vertical balance is active', () {
      expect(login, contains('width: keyboardOpen ? 64 : 78'));
      expect(login, contains('height: keyboardOpen ? 64 : 78'));
      expect(
          login,
          contains(
              'final top = isLogin ? (keyboardOpen ? 10.0 : 26.0) : 16.0;'));
      expect(
          login,
          contains(
              'final bottom = keyboardOpen ? 18.0 : (isLogin ? 104.0 : 16.0);'));
      expect(login, contains('if (isLogin && !keyboardOpen)'));
      expect(login, contains('bottom: 10'));
    });

    test('social buttons remain 46px and branded', () {
      final start = login.indexOf('Widget _buildSocialLoginSection()');
      final end = login.indexOf('Widget _socialAuthButton(', start);
      final region = login.substring(start, end);
      expect(region, contains('height: 46'));
      expect(region, contains("label: 'Google'"));
      expect(region, contains("label: 'Apple'"));
      expect(region, contains("'assets/icons/home_v2/auth_google_g.svg'"));
    });

    test('Google icon remains true vector', () {
      expect(svg, contains('viewBox="0 0 48 48"'));
      expect(svg, isNot(contains('<image')));
      expect(svg, isNot(contains('base64')));
    });

    test('keyboard and auth remain preserved', () {
      expect(login, contains('ScrollViewKeyboardDismissBehavior.onDrag'));
      expect(login, contains('AuthService.login('));
      expect(login, contains('AuthService.register('));
      expect(login, contains('AuthService.resetPassword('));
      expect(login, contains('SocialAuthService.signInWithGoogle'));
      expect(login, contains('SocialAuthService.signInWithApple'));
    });
  });
}
