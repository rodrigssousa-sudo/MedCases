import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/login_screen.dart').readAsStringSync();
  });

  group('Auth R4 compatibility with current V3/V4 owner', () {
    test('historical dark single-owner intent remains', () {
      expect(
        source,
        contains('MEDCASES_AUTH_FLAT_SINGLE_SURFACE_CREATE_ACCOUNT_V1_B_R0_R4'),
      );
      expect(source, contains('kAuthBg = Color(0xFF0F1116)'));
      expect(source, contains('kAuthSurface = Color(0xFF181D25)'));
      expect(source, contains('kAuthSurfaceSoft = Color(0xFF141920)'));
      expect(source, contains('kAuthBorder = Color(0xFF374151)'));
      expect(source, contains('BorderRadius.circular(13)'));
      expect(source, isNot(contains('Color(0xFFF0F4F0)')));
      expect(source, isNot(contains('static const kPanelCard')));
    });

    test('current fields use dark fill and explicit outline hierarchy', () {
      expect(source, contains('fillColor: kAuthSurfaceSoft'));
      expect(source, contains('BorderSide(color: kAuthBorder'));
      expect(source, contains('BorderSide(color: kAuthAccent'));
      expect(source, contains('horizontal: 15'));
      expect(source, contains('vertical: 12'));
    });

    test('current canonical palette supersedes the older flat geometry', () {
      expect(source, contains('kAuthAccent = Color(0xFF0E8000)'));
      expect(source, contains('kAuthAccentDeep = Color(0xFF0E8000)'));
      expect(source, contains('kAuthText = Color(0xFFF8FAFC)'));
      expect(source, contains('kAuthMuted = Color(0xFF94A3B8)'));
    });

    test('account creation copy remains direct PT ES', () {
      expect(source, contains("'Crear cuenta'"));
      expect(source, contains("'Criar conta'"));
      expect(source, contains("'Crea tu cuenta para acceder a MedCases Pro'"));
      expect(source, contains("'Crie sua conta para acessar o MedCases Pro'"));
      expect(source, isNot(contains('Solicitar acceso')));
      expect(source, isNot(contains('Solicitar acesso')));
    });

    test('session wording and auth behavior remain intact', () {
      expect(source, contains("'Mantener sesión activa'"));
      expect(source, contains("'Manter sessão ativa'"));
      for (final literal in <String>[
        'AuthService.login(',
        'AuthService.register(',
        'AuthService.resetPassword(',
        '_switchMode(_Mode.register)',
        '_switchMode(_Mode.reset)',
        '_keepLoggedIn',
        'obscureText:',
        'Icons.visibility',
      ]) {
        expect(source, contains(literal), reason: literal);
      }
    });

    test('current CTA uses canonical V3 accent treatment', () {
      expect(source, contains('final widthFactor = isLogin ? 0.60 : 0.82'));
      expect(source, contains('final height = isLogin ? 42.0 : 45.0'));
      expect(source, contains('kAuthAccentDeep'));
      expect(source, contains('Color(0xFF0E8000)'));
      expect(source, contains('backgroundColor: Colors.transparent'));
      expect(source, contains('shadowColor: Colors.transparent'));
    });
  });
}
