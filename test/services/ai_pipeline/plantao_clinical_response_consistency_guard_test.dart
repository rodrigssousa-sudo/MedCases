import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao_clinical_response_consistency_guard.dart';

void main() {
  const nsteCase = '''
ECG sem supradesnivelamento de ST.
Infradesnivelamento de ST em V4, V5 e V6.
Troponina ultrassensível crescente.
''';

  group('PlantaoClinicalResponseConsistencyGuard', () {
    test('removes standalone first and second line headings', () {
      const response = '''
💊 Tratamento farmacológico:
1ª linha:
• AAS 160 mg VO
2ª linha:
• Clopidogrel 600 mg VO
''';

      final guarded = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: nsteCase,
        assistantOutput: response,
      );

      expect(guarded, isNot(contains('1ª linha')));
      expect(guarded, isNot(contains('2ª linha')));
      expect(guarded, contains('AAS 160 mg VO'));
      expect(guarded, contains('Clopidogrel 600 mg VO'));
    });

    test('preserves medication written inline after a legacy heading', () {
      const response = '1ª linha: AAS 160 mg VO';

      final guarded = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'Dor torácica sem dados de ECG.',
        assistantOutput: response,
      );

      expect(guarded, '• AAS 160 mg VO');
    });

    test('corrects affirmative Portuguese SCACEST title', () {
      const response =
          '🔴 SCACEST (SÍNDROME CORONARIANA AGUDA COM ELEVAÇÃO DO ST)';

      final guarded = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: nsteCase,
        assistantOutput: response,
      );

      expect(guarded, contains('SCASEST'));
      expect(guarded, contains('SEM ELEVAÇÃO DO ST'));
      expect(guarded, isNot(contains('SCACEST')));
    });

    test('corrects affirmative Spanish STEMI title', () {
      const response = '🟥 STEMI CON ELEVACIÓN DEL ST';
      const input = '''
ECG sin elevación del ST.
Depresión del ST en V4-V6.
Troponina en ascenso.
''';

      final guarded = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: input,
        assistantOutput: response,
      );

      expect(guarded, contains('NSTEMI'));
      expect(guarded, contains('SIN ELEVACIÓN DEL ST'));
    });

    test('does not alter a true elevation case', () {
      const input = 'Supradesnivelamento de ST em V2-V5.';
      const response = '🟥 SCACEST COM ELEVAÇÃO DO ST';

      final guarded = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: input,
        assistantOutput: response,
      );

      expect(guarded, response);
    });

    test('does not rewrite a negated differential statement', () {
      const response = 'Não é SCACEST; manter investigação de SCASEST.';

      final guarded = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: nsteCase,
        assistantOutput: response,
      );

      expect(guarded, response);
    });

    test('is idempotent', () {
      const response = '''
🟥 SCACEST COM ELEVAÇÃO DO ST
1ª linha:
• AAS 160 mg VO
''';

      final once = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: nsteCase,
        assistantOutput: response,
      );
      final twice = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: nsteCase,
        assistantOutput: once,
      );

      expect(twice, once);
    });
  });
}
