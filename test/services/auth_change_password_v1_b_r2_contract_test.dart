import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AUTH_CHANGE_PASSWORD_V1_B_R0', () {
    late String auth;

    setUpAll(() {
      auth = File('lib/services/auth_service.dart').readAsStringSync();
    });

    test('owner público existe', () {
      expect(auth, contains('static Future<AuthResult> changePassword({'));
      expect(auth, contains('required String currentPassword'));
      expect(auth, contains('required String newPassword'));
    });

    test('nativo reautentica antes de updatePassword', () {
      final reauth = auth.indexOf(
        'await user.reauthenticateWithCredential(credential)',
      );
      final update = auth.indexOf('await user.updatePassword(next)');
      expect(reauth, greaterThanOrEqualTo(0));
      expect(update, greaterThan(reauth));
      expect(auth, contains('EmailAuthProvider.credential('));
    });

    test('Web usa sessão REST e resetPassword', () {
      final start = auth.indexOf(
        'static Future<AuthResult> changePassword({',
      );
      final end = auth.indexOf(
        'static String _profilePasswordError(',
        start,
      );
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final method = auth.substring(start, end);
      expect(method, contains('if (kIsWeb)'));
      expect(method, contains('webUser.value?.email.trim()'));
      expect(method, contains('return resetPassword(email)'));
    });

    test('erros comuns estão em PT/ES', () {
      expect(auth, contains("case 'wrong-password':"));
      expect(auth, contains("case 'invalid-credential':"));
      expect(auth, contains("case 'requires-recent-login':"));
      expect(auth, contains("'A senha atual está incorreta.'"));
      expect(auth, contains("'La contraseña actual es incorrecta.'"));
    });
  });
}
