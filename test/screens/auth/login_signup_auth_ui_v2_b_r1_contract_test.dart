import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/login_screen.dart').readAsStringSync();
  });

  group('Login signup current V3/V4 compatibility', () {
    test('canonical dark palette remains current', () {
      for (final token in <String>[
        'MEDCASES_LOGIN_V3_CANONICAL_DARK_VISUAL_CUTOVER_V1_B_R3',
        'kAuthBg = Color(0xFF0F1116)',
        'kAuthBgTop = Color(0xFF151A22)',
        'kAuthSurface = Color(0xFF181D25)',
        'kAuthSurfaceSoft = Color(0xFF141920)',
        'kAuthBorder = Color(0xFF374151)',
        'kAuthAccent = Color(0xFF0E8000)',
        'kAuthAccentDeep = Color(0xFF0E8000)',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('signup remains single-screen', () {
      for (final token in <String>[
        'REGISTER_V3_SINGLE_SCREEN',
        '_registerPhotoPicker()',
        '_confirmPasswordField()',
        '_studyCtrl',
        '_MedicalDisclaimerCheckbox(',
      ]) {
        expect(source, contains(token), reason: token);
      }
      expect(source, isNot(contains('_regStep')));
      expect(source, isNot(contains('_buildStepIndicator()')));
    });

    test('auth and sessions remain intact', () {
      for (final token in <String>[
        'AuthService.login(',
        'AuthService.register(',
        'AuthService.resetPassword(',
        'AuthService.saveSession(',
        'AuthService.clearSession()',
        'session_keep_logged_in',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('medical declaration remains explicit', () {
      expect(source, contains("'Acepto los términos anteriores'"));
      expect(source, contains("'Li e aceito os termos acima'"));
      expect(source, contains('Declaración de uso profesional'));
      expect(source, contains('Declaração de uso profissional'));
      expect(source, contains('_disclaimerError'));
    });
  });
}
