import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String login;
  late String common;
  late String tools;
  late String admin;
  late String history;
  late String actionRow;
  late String internacionTheme;
  late String labReview;

  setUpAll(() {
    login = File('lib/screens/login_screen.dart').readAsStringSync();
    common = File('lib/widgets/common_widgets.dart').readAsStringSync();
    tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    admin = File('lib/screens/admin_screen.dart').readAsStringSync();
    history = File('lib/screens/history_screen.dart').readAsStringSync();
    actionRow = File('lib/screens/ai/widgets/action_buttons_row.dart')
        .readAsStringSync();
    internacionTheme =
        File('lib/screens/internacion/components/internacion_theme.dart')
            .readAsStringSync();
    labReview = File('lib/screens/lab_review_screen.dart').readAsStringSync();
  });

  group('MedCases brand green Pasto cutover', () {
    test('login visual brand tokens use exact #0E8000', () {
      expect(
        login,
        contains('static const kAuthAccent = Color(0xFF0E8000);'),
      );
      expect(
        login,
        contains('static const kAuthAccentDeep = Color(0xFF0E8000);'),
      );
      expect(login, contains('static const kGreen = Color(0xFF0E8000);'));
      expect(login, contains('static const kGreenMid = Color(0xFF0E8000);'));
      expect(login, contains('const accent = Color(0xFF0E8000);'));

      expect(
        login,
        isNot(contains('static const kAuthAccentDeep = Color(0xFF0B7F69);')),
      );
      expect(
        login,
        isNot(contains('static const kGreen = Color(0xFF0D6B57);')),
      );
    });

    test('R13A physical-login layout contract remains present', () {
      expect(
        login,
        contains(
          'MEDCASES_LOGIN_V4_BREATHING_BRANDED_SOCIAL_KEYBOARD_FLOW_V1_B_R13A',
        ),
      );
      expect(login, contains('width: keyboardOpen ? 64 : 78'));
      expect(login, contains('height: keyboardOpen ? 64 : 78'));
      expect(login, contains('bottom: 10'));
      expect(
        login,
        contains('ScrollViewKeyboardDismissBehavior.onDrag'),
      );
    });

    test('canonical app green owner becomes Pasto', () {
      expect(common, contains('const kGreen = Color(0xFF0E8000);'));
      expect(tools, contains('const kToolGreen = Color(0xFF0E8000);'));
      expect(
        history,
        contains('const kGreen = Color(0xFF0E8000);'),
      );

      final adminDecl = RegExp(
        r'static const kGreen = Color\(0xFF0E8000\);',
      );
      expect(adminDecl.allMatches(admin).length, greaterThanOrEqualTo(1));
    });

    test('unified AI action row uses Pasto as brand/action accent', () {
      expect(
        actionRow,
        contains('static const _kToolBtn = Color(0xFF0E8000);'),
      );
      expect(
        RegExp(r'accentColor:\s*_kToolBtn,').allMatches(actionRow).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        actionRow,
        isNot(contains('static const _kToolBtn = Color(0xFF0D6B57);')),
      );
    });

    test('semantic common green palette remains independent', () {
      expect(
        common,
        contains(
          'Color get green => dark ? const Color(0xFF10B981) : const Color(0xFF075f45);',
        ),
      );
    });

    test('semantic stable green in Internacion remains separate', () {
      expect(
        internacionTheme,
        contains('static const Color green = Color(0xFF22C55E);'),
      );
      expect(internacionTheme, contains('semanticStable'));
    });

    test('lab normal/status green remains separate', () {
      expect(labReview, contains('static const green'));
      expect(labReview, contains('Color(0xFF46E28C)'));
    });

    test('auth behavior stays wired', () {
      expect(login, contains('AuthService.login('));
      expect(login, contains('AuthService.register('));
      expect(login, contains('AuthService.resetPassword('));
      expect(login, contains('SocialAuthService.signInWithGoogle'));
      expect(login, contains('SocialAuthService.signInWithApple'));
      expect(login, contains('session_keep_logged_in'));
    });
  });
}
