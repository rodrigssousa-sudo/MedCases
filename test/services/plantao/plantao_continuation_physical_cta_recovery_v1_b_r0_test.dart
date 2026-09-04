import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/plantao_continuation_policy.dart';

const emptyBase = SmartNextAction(label: '', promptToSend: '');

void main() {
  group('physical CTA recovery — exact anaphylaxis semantics', () {
    test(
      'generic observation plus UCI escalation is not explicit disposition',
      () {
        const physical = '''
Patología/Diagnóstico: Anafilaxia.

Conducta Inmediata:
1. Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL en la cara anterolateral del muslo; máximo 0,5 mg en el adulto.
2. Evaluar de inmediato vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.
3. Obtener acceso IV y usar cristaloide isotónico rápidamente si hay hipotensión/shock.

Tratamiento Farmacológico: Adrenalina como primera línea; antihistamínicos solo como tratamiento secundario para síntomas cutáneos.

Monitorización y Reevaluación: Observar hasta la resolución completa y prolongar la observación si la reacción fue grave o requirió más de una dosis de adrenalina. Reevaluar la respuesta clínica inmediatamente después de cada intervención y de cada dosis de adrenalina.

Puntos clave:
- La adrenalina es el tratamiento de primera línea.
- No retrasar la administración de adrenalina por otros tratamientos.
- Red Flags/Escalamiento: Escalar a equipo de emergencias/UCI ante shock, obstrucción de vía aérea, hipoxemia o refractariedad.
''';

        final action = PlantaoContinuationPolicy.resolve(
          baseAction: emptyBase,
          lastUserMessage:
              'Paciente con anafilaxia después de medicación, con urticaria, disnea e hipotensión. ¿Cuál es el diagnóstico y la conducta inmediata?',
          lastAiResponse: physical,
          chatHistory: const <String>[],
          languageCode: 'es',
        );

        expect(action.label, 'Definir destino');
        expect(
          action.continuationType,
          PlantaoContinuationType.prognosisDisposition,
        );
        expect(action.requestedSections, contains(PlantaoSection.disposition));
      },
    );

    test('destination-only follow-up closes CTA using prior clinical answer', () {
      const previousClinical = '''
Patología/Diagnóstico: Anafilaxia.
Conducta inmediata: administrar adrenalina IM 0,01 mg/kg de solución 1 mg/mL.
Tratamiento farmacológico: adrenalina como primera línea.
Monitorización y reevaluación: vigilar SpO2 y presión; reevaluar respuesta clínica después de cada intervención.
Red Flags/Escalamiento: shock, hipoxemia, obstrucción de vía aérea o refractariedad; escalar a emergencias/UCI.
''';

      const destinationOnly = '''
Destino: mantener observación clínica; ingreso hospitalario/UCI si persiste inestabilidad o requiere soporte avanzado; alta solo tras resolución completa y criterios de seguridad.
''';

      final action = PlantaoContinuationPolicy.resolve(
        baseAction: emptyBase,
        lastUserMessage:
            '¿Qué criterios definen observación, ingreso, UCI o alta en este caso?',
        lastAiResponse: destinationOnly,
        chatHistory: const <String>[
          previousClinical,
          '¿Qué criterios definen observación, ingreso, UCI o alta en este caso?',
        ],
        languageCode: 'es',
      );

      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test('UCI escalation alone never closes destination gap', () {
      const partial = '''
Conducta inmediata: tratamiento de primera línea con dosis.
Monitorización: vigilar SpO2.
Reevaluar respuesta clínica.
Red Flags/Escalamiento: escalar a UCI si hay shock refractario.
''';

      final action = PlantaoContinuationPolicy.resolve(
        baseAction: emptyBase,
        lastUserMessage: 'Caso agudo',
        lastAiResponse: partial,
        chatHistory: const <String>[],
        languageCode: 'es',
      );

      expect(action.label, 'Definir destino');
    });
  });
}
