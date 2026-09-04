import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';

const _required = <String>[
  'Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL en la cara anterolateral del muslo; máximo 0,5 mg en el adulto.',
  'Evaluar de inmediato vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.',
  'Obtener acceso IV y usar cristaloide isotónico rápidamente si hay hipotensión/shock.',
];

const _destination = """
Anafilaxia — criterios de destino

| Condición | Criterio |
|---|---|
| Observación | Respuesta adecuada a la adrenalina, sin compromiso de vías respiratorias ni signos de shock. |
| Ingreso | Síntomas persistentes después de la primera dosis de adrenalina, necesidad de múltiples dosis, o síntomas moderados como disnea. |
| UCI | Compromiso severo de vías respiratorias, shock persistente, hipoxemia, o necesidad de soporte ventilatorio avanzado. |
| Alta | Resolución completa de los síntomas, sin necesidad adicional de tratamiento y con educación sobre signos de alarma. |
""";

PlantaoGlobalClinicalContextPack _pack({
  List<String> prohibitedActions = const <String>[],
}) {
  return PlantaoGlobalClinicalContextPack(
    pathologyKey: 'fixture',
    protocolKey: 'fixture_protocol',
    authoritative: true,
    requiredActions: _required,
    prohibitedActions: prohibitedActions,
  );
}

void main() {
  group('M64 focused continuation machine gate scope', () {
    test('focused disposition does not replay historical requiredActions', () {
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText:
            '¿Qué criterios definen observación, ingreso, UCI o alta en este caso?',
        rawText: _destination,
        language: 'es',
        contextPack: _pack(),
        enforceRequiredActions: false,
      );

      expect(result.hasCriticalIssue, isFalse);
      expect(
        result.issues.where((e) => e.code == 'required_action_missing'),
        isEmpty,
      );
    });

    test('default/initial validation still fails closed on same omission', () {
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText:
            'Paciente con anafilaxia. ¿Cuál es el diagnóstico y la conducta inmediata?',
        rawText: _destination,
        language: 'es',
        contextPack: _pack(),
      );

      final missing = result.issues.where(
        (e) => e.code == 'required_action_missing',
      );
      expect(missing.length, _required.length);
      expect(result.hasCriticalIssue, isTrue);
    });

    test('focused continuation still enforces prohibitedActions', () {
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'Definir destino.',
        rawText: """
Anafilaxia — criterios de destino

Observación: respuesta estable.
Ingreso: síntomas persistentes.
UCI: shock persistente.
Alta: resolución completa.

Administrar adrenalina IV en bolo.
""",
        language: 'es',
        contextPack: _pack(
          prohibitedActions: const <String>[
            'Administrar adrenalina IV en bolo.',
          ],
        ),
        enforceRequiredActions: false,
      );

      expect(
        result.issues.any((e) => e.code == 'prohibited_action_present'),
        isTrue,
      );
      expect(result.hasCriticalIssue, isTrue);
    });

    test('ai_screen wiring is generic by requested section class', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(
        source,
        contains('M64_FOCUSED_CONTINUATION_GATE_SCOPE_RUNTIME_V1'),
      );
      expect(source, contains('PlantaoSection.disposition'));
      expect(source, contains('PlantaoSection.exams'));
      expect(source, contains('PlantaoSection.monitoring'));
      expect(source, contains('PlantaoSection.evolution'));
      expect(source, contains('PlantaoSection.responseCriteria'));
      expect(source, contains('PlantaoSection.worseningCriteria'));
      expect(source, contains('requestedSections.isNotEmpty &&'));
      expect(
        source,
        contains(
          'm64EnforceHistoricalRequiredActions =\n                  !m64FocusedContinuation',
        ),
      );
      expect(
        source,
        contains(
          'enforceRequiredActions:\n                        m64EnforceHistoricalRequiredActions',
        ),
      );

      expect(source, isNot(contains("pathologyKey == 'anafilaxia'")));
      expect(
        source,
        isNot(
          contains(
            'continuationType == PlantaoContinuationType.prognosisDisposition',
          ),
        ),
      );
    });
  });
}
