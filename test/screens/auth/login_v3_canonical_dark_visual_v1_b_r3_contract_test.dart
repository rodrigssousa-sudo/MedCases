import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/login_screen.dart').readAsStringSync();
  });

  group('Login V3 dark palette with current V4 social override', () {
    test('V3 canonical dark palette remains intact', () {
      for (final token in <String>[
        'MEDCASES_LOGIN_V3_CANONICAL_DARK_VISUAL_CUTOVER_V1_B_R3',
        'kAuthBg = Color(0xFF0F1116)',
        'kAuthBgTop = Color(0xFF151A22)',
        'kAuthSurface = Color(0xFF181D25)',
        'kAuthSurfaceSoft = Color(0xFF141920)',
        'kAuthBorder = Color(0xFF374151)',
        'kAuthAccent = Color(0xFF0E8000)',
        'kAuthAccentDeep = Color(0xFF0E8000)',
        'kAuthText = Color(0xFFF8FAFC)',
        'kAuthMuted = Color(0xFF94A3B8)',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('current V4 social row supersedes old R3 width-factor marker', () {
      expect(source, isNot(contains('R3_SOCIAL_VISUAL_WIDTH_FACTOR_085')));
      expect(source, contains("provider: 'google'"));
      expect(source, contains("label: 'Google'"));
      expect(source, contains("provider: 'apple'"));
      expect(source, contains("label: 'Apple'"));
      expect(source, contains('height: 46'));
      expect(source, contains('const SizedBox(width: 12)'));
    });

    test('Google and Apple branded surfaces remain correct', () {
      expect(source, contains("'assets/icons/home_v2/auth_google_g.svg'"));
      expect(source, contains('const Color(0xFF202124)'));
      expect(source, contains('const Color(0xFFDADCE0)'));
      expect(source, contains('const Color(0xFF000000)'));
      expect(source, contains('Icons.apple'));
    });

    test('social auth behavior remains canonical', () {
      expect(source, contains('SocialAuthService.signInWithGoogle'));
      expect(source, contains('SocialAuthService.signInWithApple'));
      expect(source, contains('SocialAuthService.cancelledResultCode'));
      expect(source, contains('_socialLoadingProvider'));
    });
  });
}
