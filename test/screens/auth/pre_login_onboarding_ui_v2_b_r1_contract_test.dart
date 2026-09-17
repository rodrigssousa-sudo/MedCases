import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const ownerPath = 'lib/screens/pre_login_screen.dart';

  String owner() => File(ownerPath).readAsStringSync();

  group('Pre-login canonical R719/R77 release contract', () {
    test('keeps login consent and language routing wired', () {
      final source = owner();

      for (final token in <String>[
        'ConsentGate.hasConsented()',
        "prefs.setString('lang', newLang)",
        'LoginScreen(onBack: _backToPreview)',
        'ConsentModal(lang: _lang, onAccepted: _onConsentAccepted)',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('contains current Premium plan architecture', () {
      final source = owner();

      for (final token in <String>[
        '_R719PremiumPrice',
        '_R719PlanFeature',
        '30 días gratis',
        '30 dias grátis',
        'US\\\$ 14,99',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('contains current educational disclaimer', () {
      final source = owner();

      for (final token in <String>[
        '_R77Disclaimer',
        'HERRAMIENTA EDUCATIVA DE APOYO CLÍNICO',
        'FERRAMENTA EDUCATIVA DE APOIO CLÍNICO',
        'La decisión y verificación de dosis son responsabilidad exclusiva del médico asistente.',
        'A decisão e a verificação das doses são responsabilidade exclusiva do médico assistente.',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test('does not regress to retired sample-access copy', () {
      final source = owner();

      for (final stale in <String>[
        'Acceso de muestra',
        'Acesso demonstrativo',
        'Crear mi cuenta gratuita',
        'Criar minha conta gratuita',
        'Aprobado por administrador',
        'Aprovado pelo administrador',
      ]) {
        expect(source, isNot(contains(stale)), reason: stale);
      }
    });
  });
}
