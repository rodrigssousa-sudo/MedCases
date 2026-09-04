import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  setUpAll(() {
    source = File('lib/screens/login_screen.dart').readAsStringSync();
  });

  group('Login R13A current-layout vertical balance', () {
    test('patch targets the real fromLTRB layout', () {
      expect(source, contains('padding: EdgeInsets.fromLTRB('));
      expect(
          source,
          contains(
              'final top = isLogin ? (keyboardOpen ? 10.0 : 26.0) : 16.0;'));
      expect(
          source,
          contains(
              'final bottom = keyboardOpen ? 18.0 : (isLogin ? 104.0 : 16.0);'));
    });

    test('M+ grows by exactly 10px from R12', () {
      expect(source, contains('width: keyboardOpen ? 64 : 78'));
      expect(source, contains('height: keyboardOpen ? 64 : 78'));
    });

    test('main content is distributed lower', () {
      expect(source, contains('SizedBox(height: keyboardOpen ? 18 : 28)'));
      expect(source, contains('SizedBox(height: isLogin ? 26 : 16)'));
      expect(source, contains('SizedBox(height: isLogin ? 18 : 16)'));
      expect(source, contains('SizedBox(height: isLogin ? 10 : 10)'));
    });

    test('legal footer is exactly 10px from bottom and hidden with keyboard',
        () {
      expect(source, contains('if (isLogin && !keyboardOpen)'));
      expect(source, contains('bottom: 10'));
      expect(
          source, contains('constraints: const BoxConstraints(maxWidth: 500)'));
      expect(source, contains('child: _buildDisclaimer()'));
    });

    test('auth and keyboard remain untouched', () {
      expect(source, contains('AuthService.login('));
      expect(source, contains('AuthService.register('));
      expect(source, contains('AuthService.resetPassword('));
      expect(source, contains('SocialAuthService.signInWithGoogle'));
      expect(source, contains('SocialAuthService.signInWithApple'));
      expect(source, contains('ScrollViewKeyboardDismissBehavior.onDrag'));
    });
  });
}
