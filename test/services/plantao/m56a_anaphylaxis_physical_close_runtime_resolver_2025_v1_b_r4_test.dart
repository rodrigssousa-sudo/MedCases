import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';

void main() {
  const physical = '''
Mujer de 34 años, minutos después de ingerir maní desarrolla urticaria generalizada, edema labial, disnea con sibilancias, mareo y PA 82/48 mmHg. FC 124 lpm, SpO₂ 91%. Está consciente pero muy sintomática.
¿Cuál es el diagnóstico y cuál es la conducta inmediata en orden de prioridad? Incluye tratamiento de primera línea, monitorización, reevaluación y criterios de escalamiento.
''';

  test(
    'exact physical phenotype gets complete current anaphylaxis contract',
    () {
      final es = AiService.buildM54PhysicalHomologationContractForTesting(
        physical,
        isEs: true,
      );
      expect(es, contains('M55B_ANAFILAXIS_FIRST_ACTION_PRIORITY'));
      expect(es, contains('ADRENALINA IM es el ítem 1'));
      expect(es, contains('repetir a los 5 min'));
      expect(es, contains('cristaloide isotónico rápido'));
      expect(es, contains('Corticoides NO son tratamiento rutinario'));
      expect(es, contains('tras 2 dosis IM adecuadas'));
      expect(es, contains('NO sustituyen ni retrasan adrenalina IM'));
    },
  );

  test(
    'generic first heading then ANAFILAXIA resolves protocol, not adrenaline',
    () {
      final result = ClinicalReferenceResolver.resolve(
        userText: physical,
        aiText: '''
CONDUCTA CLÍNICA INMEDIATA
ANAFILAXIA
Conducta inmediata:
- ADRENALINA 0,5 mg IM inmediatamente.
''',
        lang: 'es',
      );
      expect(result.protocolId, 'anafilaxia');
      expect(result.sourceType, 'clinical_protocol');
      expect(result.sourceType, isNot('single_drug'));
    },
  );

  test('isolated urticaria without ABC compromise is not anaphylaxis', () {
    final es = AiService.buildM54PhysicalHomologationContractForTesting(
      'Paciente con urticaria aislada, estable, sin disnea, sin sibilancias, sin hipotensión.',
      isEs: true,
    );
    expect(es, isNot(contains('M55B_ANAFILAXIS_FIRST_ACTION_PRIORITY')));
  });

  test(
    'Portuguese isolated urticaria with negated ABC findings is not anaphylaxis',
    () {
      final pt = AiService.buildM54PhysicalHomologationContractForTesting(
        'Paciente com urticária isolada, estável, sem dispneia, sem sibilos e sem hipotensão.',
        isEs: false,
      );
      expect(pt, isNot(contains('M55B_ANAFILAXIA_PRIORIDADE_PRIMEIRA_ACAO')));
    },
  );
}
