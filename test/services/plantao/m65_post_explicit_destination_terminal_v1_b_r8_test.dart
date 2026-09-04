import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/plantao_continuation_policy.dart';

const genericStudies = SmartNextAction(
  label: 'Completar estudios',
  promptToSend: 'Completar estudios útiles.',
  continuationType: PlantaoContinuationType.examsEvolution,
  requestedSections: <PlantaoSection>[PlantaoSection.exams],
);

const specificAction = SmartNextAction(
  label: 'Revisar soporte respiratorio',
  promptToSend: 'Revisar soporte respiratorio ahora.',
  continuationType: PlantaoContinuationType.monitoring,
  requestedSections: <PlantaoSection>[PlantaoSection.monitoring],
);

const physicalDestination = '''
Criterios para observación, ingreso, UCI o alta en caso de anafilaxia:
Observación:
Paciente estable tras respuesta al tratamiento.
Ingreso:
Síntomas persistentes o necesidad de dosis repetidas.
UCI:
Shock persistente, hipoxemia o soporte avanzado.
Alta:
Resolución completa y estabilidad hemodinámica.
''';

const physicalDestinationTable = '''
Criterios para observación, ingreso, UCI o alta:
| Condición | Criterio |
| --- | --- |
| Observación | Respuesta adecuada y estabilidad. |
| Ingreso | Síntomas persistentes o dosis repetidas. |
| UCI | Shock persistente o hipoxemia. |
| Alta | Resolución completa y estabilidad. |
''';

const physicalDestinationPt = '''
Critérios para observação, internação, UTI ou alta:
Observação:
Resposta adequada e estabilidade.
Internação:
Sintomas persistentes ou necessidade de doses repetidas.
UTI:
Choque persistente ou hipoxemia.
Alta:
Resolução completa e estabilidade.
''';

SmartNextAction resolve({
  required SmartNextAction base,
  required String answer,
  String language = 'es',
}) {
  return PlantaoContinuationPolicy.resolve(
    baseAction: base,
    lastUserMessage: 'Definir destino',
    lastAiResponse: answer,
    chatHistory: const <String>[],
    languageCode: language,
  );
}

void main() {
  group('M65 explicit destination true terminal', () {
    test(
      'four-way destination suppresses Completar estudios specific base',
      () {
        final action = resolve(
          base: genericStudies,
          answer: physicalDestination,
        );
        expect(action.label, isEmpty);
        expect(action.promptToSend, isEmpty);
      },
    );

    test('physical table destination also suppresses filler', () {
      final action = resolve(
        base: genericStudies,
        answer: physicalDestinationTable,
      );
      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test('terminal destination wins before any other specific base action', () {
      final action = resolve(base: specificAction, answer: physicalDestination);
      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test('PT four-way destination is terminal', () {
      final action = resolve(
        base: genericStudies,
        answer: physicalDestinationPt,
        language: 'pt',
      );
      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test('isolated UCI escalation is not terminal disposition', () {
      const answer = '''
Diagnóstico: cuadro agudo.
Conducta inmediata: manejo inicial.
Monitorización: reevaluar respuesta.
Red flags/escalonamiento: shock o hipoxemia; escalar a UCI.
''';
      final action = resolve(base: genericStudies, answer: answer);
      expect(action.label, isNotEmpty);
    });

    test('monitoring-only observar hasta resolución is not terminal', () {
      const answer = '''
Monitorización y reevaluación:
Observar hasta la resolución completa de los síntomas.
''';
      final action = resolve(base: genericStudies, answer: answer);
      expect(action.label, isNotEmpty);
    });

    test('lone ingreso hospitalario remains non-terminal for specific CTA', () {
      const answer = '''
Destino clínico parcial:
Considerar ingreso hospitalario si persisten los síntomas.
''';
      final action = resolve(base: specificAction, answer: answer);
      expect(action.label, 'Revisar soporte respiratorio');
    });
  });
}
