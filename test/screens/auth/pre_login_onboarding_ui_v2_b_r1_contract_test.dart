import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const ownerPath = 'lib/screens/pre_login_screen.dart';

  String owner() => File(ownerPath).readAsStringSync();

  group('Pre-login Onboarding UI V2 B R1', () {
    test('uses canonical MedCases Pro dark identity', () {
      final source = owner();

      for (final token in <String>[
        'MEDCASES_PRE_LOGIN_ONBOARDING_UI_V2_B_R1',
        'const _kBg          = Color(0xFF1A1D23);',
        'const _kBgCard      = Color(0xFF252930);',
        'const _kGreen       = Color(0xFF0D6B57);',
        'const _kGreenMid    = Color(0xFF0D6B57);',
        'const _kGreenLight  = Color(0xFF0D6B57);',
        'const _kNeon        = Color(0xFF0D6B57);',
        'const _kNeonGlow    = Color(0xFF0D6B57);',
        'const _kBorder      = Color(0xFF374151);',
      ]) {
        expect(source, contains(token), reason: token);
      }

      for (final stale in <String>[
        'Color(0xFF06110C)',
        'Color(0xFF0E1A14)',
        'Color(0xFF0E7C52)',
        'Color(0xFF13A06A)',
        'Color(0xFF1DBF7B)',
        'Color(0xFF33FF88)',
        'Color(0xFF2AF07A)',
        'MedixAI',
      ]) {
        expect(source, isNot(contains(stale)), reason: stale);
      }
    });

    test('login consent and language routing stay wired', () {
      final source = owner();

      for (final token in <String>[
        'ConsentGate.hasConsented()',
        "prefs.setString('lang', newLang)",
        'LoginScreen(onBack: _backToPreview)',
        'ConsentModal(lang: _lang, onAccepted: _onConsentAccepted)',
      ]) {
        expect(source, contains(token), reason: token);
      }

      expect(
        source,
        matches(
          RegExp(
            r'void\s+_onConsentAccepted\(\)\s*=>\s*setState\(\(\)\s*=>\s*_hasConsented\s*=\s*true\);',
          ),
        ),
      );
      expect(
        source,
        matches(
          RegExp(
            r'void\s+_goLogin\(\)\s*=>\s*setState\(\(\)\s*=>\s*_showLogin\s*=\s*true\);',
          ),
        ),
      );
      expect(
        source,
        matches(
          RegExp(
            r'void\s+_backToPreview\(\)\s*=>\s*setState\(\(\)\s*=>\s*_showLogin\s*=\s*false\);',
          ),
        ),
      );
    });

    test('keeps the onboarding content hierarchy', () {
      final source = owner();

      for (final token in <String>[
        '_IaBlockDark(onTap: _goLogin, isEs: _isEs)',
        '_MetricsRow(isEs: _isEs)',
        '..._protocols.map((p) => _ProtoCard(',
        '_CritCard(data: c, onTap: _goLogin, isEs: _isEs)',
        "'Choque Séptico'",
        "'ACV Isquémico'",
        "'Dosis de noradrenalina en choque séptico'",
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('removes stale manual-admin approval copy', () {
      final source = owner();

      expect(source, isNot(contains('Aprobado por administrador')));
      expect(source, isNot(contains('Aprovado pelo administrador')));
      expect(
        source,
        contains('Acceso gratuito · Para profesionales de salud'),
      );
      expect(
        source,
        contains('Acesso gratuito · Para profissionais de saúde'),
      );
    });

    test('retains restrained premium depth instead of green aura', () {
      final source = owner();

      expect(source, contains('Color(0x12000000)'));
      expect(source, contains('Color(0x0A000000)'));
      expect(source, isNot(contains('blurRadius: 55')));
      expect(source, isNot(contains('spreadRadius: 6')));
    });

    test('header and CTA preserve productive actions', () {
      final source = owner();

      expect(
        source,
        contains(
          '_DarkHeader(isEs: _isEs, onToggleLang: _toggleLang, onLogin: _goLogin)',
        ),
      );
      expect(source, contains('_CtaDark('));
      expect(source, contains('onPressed: onTap'));
      expect(source, contains("isEs ? 'PT' : 'ES'"));
    });

    test('keeps PT ES onboarding copy', () {
      final source = owner();

      for (final token in <String>[
        "'Crear mi cuenta gratuita'",
        "'Criar minha conta gratuita'",
        "'Acceso de muestra'",
        "'Acesso demonstrativo'",
        "'Actualizados con evidencia reciente'",
        "'Atualizados com evidência recente'",
        "'Casos de máxima urgencia clínica'",
        "'Casos de máxima urgência clínica'",
      ]) {
        expect(source, contains(token), reason: token);
      }
    });
  });
}
