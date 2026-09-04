import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_clinical_regimen_output_guard.dart';

void main() {
  group('M77 STEMI invasive timing output safety', () {
    test('Spanish explicit IAMCEST removes NSTE <24h invasive timing', () {
      const raw = '''
CONDUCTA
• Reperfusión urgente.
• Considerar cateterismo en <24h si alto riesgo.
''';
      final out = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAMCEST confirmado con elevación persistente del ST',
        assistantOutput: raw,
        languageCode: 'es',
      );
      expect(out.modified, isTrue);
      expect(out.text, isNot(contains('<24h')));
      expect(out.text, contains('estrategia de reperfusión urgente'));
      expect(out.text, contains('no diferir el manejo como SCASEST'));
    });

    test('Portuguese explicit STEMI removes NSTE 24 h catheterization timing', () {
      const raw = '''
CONDUTA
• Reperfusão imediata.
• Coronariografia em 24 h se alto risco.
''';
      final out = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'STEMI confirmado com elevação do ST',
        assistantOutput: raw,
        languageCode: 'pt',
      );
      expect(out.modified, isTrue);
      expect(out.text, isNot(contains('24 h')));
      expect(out.text, contains('estratégia de reperfusão urgente'));
      expect(out.text, contains('não diferir o manejo como SCA sem supra'));
    });

    test('explicit NSTEMI keeps legitimate <24h invasive wording unchanged', () {
      const raw = '• Considerar cateterismo em <24h se alto risco.';
      final out = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'NSTEMI confirmado de alto risco',
        assistantOutput: raw,
        languageCode: 'pt',
      );
      expect(out.text, raw);
    });

    test('non ACS output is byte exact', () {
      const raw = '• Monitorar por 24 h e reavaliar.';
      final out = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'asma aguda',
        assistantOutput: raw,
        languageCode: 'pt',
      );
      expect(out.text, raw);
      expect(out.modified, isFalse);
    });

    test('correction is idempotent', () {
      const raw = '• Considerar cateterismo en <24h si alto riesgo.';
      final once = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAMCEST confirmado',
        assistantOutput: raw,
        languageCode: 'es',
      );
      final twice = PlantaoClinicalRegimenOutputGuard.enforce(
        userInput: 'IAMCEST confirmado',
        assistantOutput: once.text,
        languageCode: 'es',
      );
      expect(twice.text, once.text);
    });
  });
}
