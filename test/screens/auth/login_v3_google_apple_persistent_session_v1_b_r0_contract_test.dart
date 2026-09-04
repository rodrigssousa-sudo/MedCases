import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String login;

  setUpAll(() {
    login = File('lib/screens/login_screen.dart').readAsStringSync();
  });

  group('Login current social auth compatibility', () {
    test('Google and Apple auth routes remain wired', () {
      expect(login, contains('SocialAuthService.signInWithGoogle'));
      expect(login, contains('SocialAuthService.signInWithApple'));
      expect(login, contains("provider: 'google'"));
      expect(login, contains("provider: 'apple'"));
    });

    test('persistent session remains wired', () {
      expect(login, contains('session_keep_logged_in'));
      expect(login, contains('AuthService.saveSession'));
      expect(login, contains('AuthService.clearSession'));
      expect(login, contains('_keepLoggedIn'));
    });

    test('V4 branded provider buttons are current', () {
      expect(login, contains("label: 'Google'"));
      expect(login, contains("label: 'Apple'"));
      expect(login, contains("'assets/icons/home_v2/auth_google_g.svg'"));
      expect(login, contains('const Color(0xFF000000)'));
      expect(login, contains('const Color(0xFF202124)'));
      expect(login, contains('Icons.apple'));
      expect(login, contains('height: 46'));
    });

    test('cancel and loading behavior remain wired', () {
      expect(login, contains('SocialAuthService.cancelledResultCode'));
      expect(login, contains('_socialLoadingProvider'));
      expect(login, contains('result.success'));
    });
  });
}
