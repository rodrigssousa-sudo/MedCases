import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao_clinical_response_consistency_guard.dart';

void main() {
  group('M77 massive hemothorax post-provider authority', () {
    test('Spanish inverted threshold sentence is canonicalized', () {
      const raw = '''
HEMOTÓRAX MASIVO
• Si el drenaje no drena ≥1500 mL o >200 mL/h durante 2-4 h, considerar cirugía.
''';
      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'hemotórax masivo traumático',
        assistantOutput: raw,
      );
      expect(out, isNot(contains('no drena')));
      expect(out, isNot(contains('2-4 h')));
      expect(out, contains('>1500 mL iniciales o >200 mL/h durante 3 horas consecutivas'));
      expect(out, contains('integrando fisiología'));
    });

    test('Portuguese malformed threshold duration is canonicalized', () {
      const raw = '''
HEMOTÓRAX MACIÇO
• Considerar cirurgia se não drenar >1500 mL ou >200 mL/h por 4 horas.
''';
      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'hemotórax maciço traumático',
        assistantOutput: raw,
      );
      expect(out, isNot(contains('não drenar')));
      expect(out, contains('>1500 mL iniciais ou >200 mL/h por 3 horas consecutivas'));
      expect(out, contains('integrando fisiologia'));
    });

    test('canonical correction is idempotent', () {
      const raw = '• Si no drena 1500 mL o 200 mL/h por 2 horas, considerar toracotomía.';
      final once = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'hemotórax masivo',
        assistantOutput: raw,
      );
      final twice = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'hemotórax masivo',
        assistantOutput: once,
      );
      expect(twice, once);
    });

    test('same numbers in unrelated pathology are untouched', () {
      const raw = 'Balance: 1500 mL; débito 200 mL/h.';
      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'choque séptico',
        assistantOutput: raw,
      );
      expect(out, raw);
    });
  });
}
