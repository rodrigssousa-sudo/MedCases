import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/plantao_continuation_policy.dart';

const genericTreatmentEs = SmartNextAction(
  label: 'Conductas y dosis',
  promptToSend:
      '¿Cuáles son las conductas clínicas inmediatas y las dosis recomendadas para este caso?',
  continuationType: PlantaoContinuationType.treatmentExpansion,
  requestedSections: <PlantaoSection>[
    PlantaoSection.immediateActions,
    PlantaoSection.fullTreatment,
  ],
);

void main() {
  group('Plantão continuation final surgical', () {
    test('covered treatment advances to reassessment', () {
      final action = PlantaoContinuationPolicy.resolve(
        baseAction: genericTreatmentEs,
        lastUserMessage: 'Anafilaxia',
        lastAiResponse: '''
Patología/diagnóstico: Anafilaxia.
Conducta inmediata: adrenalina IM 0,01 mg/kg.
Tratamiento farmacológico: adrenalina IM como primera línea.
''',
        chatHistory: const <String>[],
        languageCode: 'es',
      );

      expect(action.label, 'Reevaluar respuesta');
      expect(
        action.requestedSections,
        contains(PlantaoSection.responseCriteria),
      );
    });

    test('escalation without explicit disposition advances to destination', () {
      final action = PlantaoContinuationPolicy.resolve(
        baseAction: genericTreatmentEs,
        lastUserMessage: 'Anafilaxia',
        lastAiResponse: '''
Patología/diagnóstico: Anafilaxia.
Conducta inmediata: adrenalina IM 0,01 mg/kg.
Tratamiento farmacológico: primera línea completada.
Monitorización: vigilar SpO2 y presión.
Reevaluar la respuesta clínica tras cada intervención.
Red flags/escalamiento: shock, hipoxemia, refractariedad; escalar a emergencias/UCI.
''',
        chatHistory: const <String>[],
        languageCode: 'es',
      );

      expect(action.label, 'Definir destino');
      expect(
        action.continuationType,
        PlantaoContinuationType.prognosisDisposition,
      );
      expect(action.requestedSections, contains(PlantaoSection.disposition));
    });

    test('complete case emits no filler action', () {
      final action = PlantaoContinuationPolicy.resolve(
        baseAction: genericTreatmentEs,
        lastUserMessage: 'Anafilaxia',
        lastAiResponse: '''
Patología/diagnóstico: Anafilaxia.
Conducta inmediata: adrenalina IM 0,01 mg/kg.
Tratamiento farmacológico: primera línea completada.
Monitorización: vigilar SpO2 y presión.
Reevaluar la respuesta clínica tras cada intervención.
Red flags/escalamiento: shock, hipoxemia o refractariedad.
Destino: observación; ingreso/UCI si persiste inestabilidad; alta solo tras resolución y criterios de seguridad.
''',
        chatHistory: const <String>[],
        languageCode: 'es',
      );

      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test(
      'generic evolution with monitoring but no studies asks for studies',
      () {
        const base = SmartNextAction(
          label: 'Estudios y evolución',
          promptToSend: '¿Qué estudios y monitorización debo realizar?',
          continuationType: PlantaoContinuationType.examsEvolution,
          requestedSections: <PlantaoSection>[
            PlantaoSection.exams,
            PlantaoSection.monitoring,
          ],
        );

        final action = PlantaoContinuationPolicy.resolve(
          baseAction: base,
          lastUserMessage: 'Seguimiento',
          lastAiResponse: '''
Monitorización: vigilar SpO2, presión y frecuencia cardíaca.
Reevaluar respuesta clínica.
''',
          chatHistory: const <String>[],
          languageCode: 'es',
        );

        expect(action.label, 'Completar estudios');
        expect(action.requestedSections, <PlantaoSection>[
          PlantaoSection.exams,
        ]);
      },
    );

    test('specific pathology action remains canonical until already used', () {
      const specific = SmartNextAction(
        label: 'Estrategia de reperfusión',
        promptToSend:
            'IAMCEST confirmado: detalla la estrategia de reperfusión inmediata.',
        continuationType: PlantaoContinuationType.treatmentExpansion,
      );

      final first = PlantaoContinuationPolicy.resolve(
        baseAction: specific,
        lastUserMessage: 'IAMCEST',
        lastAiResponse: 'IAMCEST confirmado.',
        chatHistory: const <String>[],
        languageCode: 'es',
      );
      expect(identical(first, specific), isTrue);

      final repeated = PlantaoContinuationPolicy.resolve(
        baseAction: specific,
        lastUserMessage: 'IAMCEST',
        lastAiResponse: 'IAMCEST confirmado.',
        chatHistory: const <String>[
          'IAMCEST confirmado: detalla la estrategia de reperfusión inmediata.',
        ],
        languageCode: 'es',
      );
      expect(repeated.label, isEmpty);
    });

    test('PT parity uses short follow-up label', () {
      const pt = SmartNextAction(
        label: 'Condutas e dosagens',
        promptToSend: 'Quais são as condutas e doses neste caso?',
        continuationType: PlantaoContinuationType.treatmentExpansion,
      );

      final action = PlantaoContinuationPolicy.resolve(
        baseAction: pt,
        lastUserMessage: 'Caso agudo',
        lastAiResponse:
            'Conduta imediata: tratamento de primeira linha e dose indicados.',
        chatHistory: const <String>[],
        languageCode: 'pt',
      );

      expect(action.label, 'Reavaliar resposta');
    });
  });
}
