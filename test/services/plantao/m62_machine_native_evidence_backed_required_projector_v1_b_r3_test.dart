import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

const physicalCaseEs = '''
Mujer de 34 años, minutos después de ingerir maní desarrolla urticaria generalizada, edema labial, disnea con sibilancias, mareo y PA 82/48 mmHg. FC 124 lpm, SpO₂ 91%. Está consciente pero muy sintomática.
¿Cuál es el diagnóstico y cuál es la conducta inmediata en orden de prioridad? Incluye tratamiento de primera línea, monitorización, reevaluación y criterios de escalamiento.
''';

const physicalRawEs = '''
🟥 CONDUCTA CLÍNICA INMEDIATA

**Diagnóstico:** Anafilaxia.

**Conducta inmediata en orden de prioridad:**

1. **Administrar adrenalina IM**: 0,01 mg/kg (máximo 0,5 mg) en el muslo anterolateral.

2. **Evaluar vía aérea, ventilación y circulación**: Asegurar permeabilidad de la vía aérea e iniciar soporte ventilatorio si es necesario.

3. **Administrar oxígeno**: Para mantener la saturación SpO₂ por encima del 92%.

4. **Obtener acceso IV**: Usar cristaloide isotónico rápidamente si hay hipotensión (PA 82/48 mmHg).

**Tratamiento farmacológico:**

- **Adrenalina IM** (primera línea).

- Antihistamínicos solo para síntomas cutáneos como tratamiento secundario, nunca como sustitutos de la adrenalina.

**Monitorización y reevaluación:**

- Observar al paciente hasta la resolución completa de síntomas.

- Prolongar la observación en caso de reacción grave o si se requirieron más de una dosis de adrenalina.

- Reevaluar la respuesta clínica inmediatamente después de cada intervenci
''';

PlantaoGlobalClinicalGateResult pass1(
  String raw,
  PlantaoGlobalClinicalContextPack pack,
) => PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
  userText: physicalCaseEs,
  rawText: raw,
  language: 'es',
  contextPack: pack,
);

PlantaoGlobalClinicalGateResult repair(
  PlantaoGlobalClinicalGateResult initial,
  PlantaoGlobalClinicalContextPack pack,
) =>
    PlantaoGlobalClinicalResponseGate.repairEvidenceBackedRequiredActionsForPresentation(
      userText: physicalCaseEs,
      language: 'es',
      pass1: initial,
      contextPack: pack,
    );

PlantaoGlobalClinicalContextPack fixturePack({
  required List<String> required,
  List<String> prohibited = const <String>[],
  List<String> classificationDependencies = const <String>[],
  List<String> scoreDependencies = const <String>[],
  bool authoritative = true,
}) => PlantaoGlobalClinicalContextPack(
  pathologyKey: 'fixture',
  protocolKey: 'fixture::protocol',
  guidelineVersion: '2026.09',
  clinicalReviewDate: '2026-09-01',
  requiredActions: required,
  prohibitedActions: prohibited,
  conditionalActions: const <String>[],
  classificationDependencies: classificationDependencies,
  scoreDependencies: scoreDependencies,
  authoritative: authoritative,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M62 evidence-backed machine-native projector', () {
    test(
      'exact physical M62 dual issue becomes clean pass 2 with missing-only materialization',
      () async {
        final prefetch = PlantaoMachineNativeContextPrefetch(
          source: PlantaoBundledPhase24MachineNativeRegistrySource(),
          cacheTtl: Duration.zero,
        );
        final resolved = await prefetch.prefetch(
          userText: physicalCaseEs,
          language: 'es',
        );
        expect(resolved.authoritative, isTrue);
        expect(resolved.canonicalPathologyKey, 'anafilaxia');
        final pack = resolved.contextPack!;
        expect(pack.requiredActions.length, 3);

        final initial = pass1(physicalRawEs, pack);
        expect(initial.hasCriticalIssue, isTrue);
        expect(initial.issues.length, 2);
        expect(
          initial.issues.every((i) => i.code == 'required_action_missing'),
          isTrue,
        );

        final finalResult = repair(initial, pack);
        expect(identical(finalResult, initial), isFalse);
        expect(finalResult.issues, isEmpty);
        expect(finalResult.hasCriticalIssue, isFalse);
        expect(finalResult.machineAuthorityEvaluated, isTrue);

        final missingDetails = initial.issues
            .where((i) => i.code == 'required_action_missing')
            .map((i) => i.detail)
            .toList(growable: false);
        expect(missingDetails.length, 2);
        for (final missing in missingDetails) {
          expect(finalResult.finalText, contains(missing));
        }

        // M62 is deliberately minimal: only actions that were missing on pass 1
        // are materialized verbatim. Required action 3 was already semantically
        // satisfied by the provider, so its provider-authored line must survive
        // instead of being rewritten to the canonical authored sentence.
        final alreadySatisfied = pack.requiredActions
            .where((required) => !missingDetails.contains(required))
            .toList(growable: false);
        expect(alreadySatisfied.length, 1);
        expect(
          alreadySatisfied.single,
          contains('Obtener acceso IV y usar cristaloide isotónico'),
        );
        expect(finalResult.finalText, isNot(contains(alreadySatisfied.single)));
        expect(
          finalResult.finalText,
          contains(
            '4. **Obtener acceso IV**: Usar cristaloide isotónico rápidamente '
            'si hay hipotensión (PA 82/48 mmHg).',
          ),
        );

        expect(finalResult.finalText, contains('solución 1 mg/mL'));
        expect(
          finalResult.finalText,
          contains(
            'Evaluar de inmediato vía aérea, ventilación y circulación; '
            'administrar oxígeno y soporte ventilatorio según necesidad.',
          ),
        );
        expect(finalResult.finalText, contains('cristaloide isotónico'));
      },
    );

    test('true complete omission of adrenaline remains fail closed', () async {
      final prefetch = PlantaoMachineNativeContextPrefetch(
        source: PlantaoBundledPhase24MachineNativeRegistrySource(),
        cacheTtl: Duration.zero,
      );
      final resolved = await prefetch.prefetch(
        userText: physicalCaseEs,
        language: 'es',
      );
      final pack = resolved.contextPack!;
      final raw = physicalRawEs.replaceFirst(
        '1. **Administrar adrenalina IM**: 0,01 mg/kg (máximo 0,5 mg) en el muslo anterolateral.\n\n',
        '',
      );
      final initial = pass1(raw, pack);
      final finalResult = repair(initial, pack);
      expect(identical(finalResult, initial), isTrue);
      expect(finalResult.hasCriticalIssue, isTrue);
      expect(
        finalResult.issues.any(
          (i) =>
              i.code == 'required_action_missing' &&
              i.detail.contains('solución 1 mg/mL'),
        ),
        isTrue,
      );
    });

    test('weak adrenaline mention cannot authorize missing dose details', () {
      const required =
          'Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL en la cara anterolateral del muslo; máximo 0,5 mg en el adulto.';
      final pack = fixturePack(required: const <String>[required]);
      final initial = pass1(
        'ANAFILAXIA\n\nConducta inmediata\n- Administrar adrenalina IM.',
        pack,
      );
      final finalResult = repair(initial, pack);
      expect(identical(finalResult, initial), isTrue);
      expect(finalResult.hasCriticalIssue, isTrue);
    });

    test('negated required action cannot be projected into a positive action', () {
      const required =
          'Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL en la cara anterolateral del muslo; máximo 0,5 mg en el adulto.';
      final pack = fixturePack(required: const <String>[required]);
      final initial = pass1(
        'ANAFILAXIA\n\nConducta inmediata\n'
        '- No administrar adrenalina IM 0,01 mg/kg en el muslo anterolateral.',
        pack,
      );
      final finalResult = repair(initial, pack);
      expect(identical(finalResult, initial), isTrue);
      expect(finalResult.hasCriticalIssue, isTrue);
    });

    test('prohibited action issue blocks projector entirely', () {
      const required =
          'Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL en la cara anterolateral del muslo; máximo 0,5 mg en el adulto.';
      const prohibited = 'Usar corticoide de rutina como tratamiento inicial.';
      final pack = fixturePack(
        required: const <String>[required],
        prohibited: const <String>[prohibited],
      );
      final initial = pass1(
        'ANAFILAXIA\n\nConducta inmediata\n'
        '- Administrar adrenalina IM 0,01 mg/kg máximo 0,5 mg en muslo anterolateral.\n'
        '- Usar corticoide de rutina como tratamiento inicial.',
        pack,
      );
      expect(
        initial.issues.any((i) => i.code == 'prohibited_action_present'),
        isTrue,
      );
      final finalResult = repair(initial, pack);
      expect(identical(finalResult, initial), isTrue);
      expect(finalResult.hasCriticalIssue, isTrue);
    });

    test('no authority or dependency-bearing pack remains fail closed', () {
      const required =
          'Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL en la cara anterolateral del muslo; máximo 0,5 mg en el adulto.';
      const raw =
          'ANAFILAXIA\n\nConducta inmediata\n- Administrar adrenalina IM 0,01 mg/kg máximo 0,5 mg en muslo anterolateral.';

      for (final pack in <PlantaoGlobalClinicalContextPack>[
        fixturePack(required: const <String>[required], authoritative: false),
        fixturePack(
          required: const <String>[required],
          classificationDependencies: const <String>['classification'],
        ),
        fixturePack(
          required: const <String>[required],
          scoreDependencies: const <String>['score'],
        ),
      ]) {
        final initial = pass1(raw, pack);
        final finalResult = repair(initial, pack);
        expect(identical(finalResult, initial), isTrue);
      }
    });

    test('M61 matcher-only split-line semantics remain unchanged', () {
      const required =
          'Evaluar de inmediato vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.';
      final pack = fixturePack(required: const <String>[required]);
      final initial = pass1(
        'ANAFILAXIA\n\nConducta inmediata\n'
        '- Evaluar de inmediato vía aérea, ventilación y circulación.\n'
        '- Administrar oxígeno y soporte ventilatorio según necesidad.',
        pack,
      );
      // Old finalize still does NOT aggregate across lines. M62 is a separate,
      // explicit runtime recovery layer, not a weakening of M61 matcher.
      expect(
        initial.issues.any((i) => i.code == 'required_action_missing'),
        isTrue,
      );
    });

    test(
      'runtime projector sits before M58 with zero provider/network path',
      () {
        final source = File('lib/screens/ai_screen.dart').readAsStringSync();
        final m62 = source.indexOf(
          'M62_MACHINE_NATIVE_EVIDENCE_BACKED_REQUIRED_PROJECTOR_RUNTIME_V1',
        );
        final m58 = source.indexOf(
          'M58_MACHINE_NATIVE_FINAL_COMMIT_FAIL_CLOSED',
          m62,
        );
        final visible = source.indexOf('text: safeFinalText,', m58);
        expect(m62, greaterThanOrEqualTo(0));
        expect(m58, greaterThan(m62));
        expect(visible, greaterThan(m58));

        final recoveryWindow = source.substring(m62, m58);
        expect(recoveryWindow, isNot(contains('sendAiMessage(')));
        expect(recoveryWindow, isNot(contains('gptProxy')));
        expect(recoveryWindow, isNot(contains('FirebaseFirestore')));
        expect(recoveryWindow, contains('m56bGlobalGate.hasCriticalIssue'));
        expect(recoveryWindow, contains('m62EffectiveGate'));

        final guardWindow = source.substring(m58, visible);
        expect(guardWindow, contains('m56cMachineContext.authoritative'));
        expect(guardWindow, contains('m56bGlobalGate.hasCriticalIssue'));
        expect(guardWindow, contains('m62EffectiveGate.hasCriticalIssue'));
        expect(
          guardWindow,
          contains('blocked=true reason=critical_machine_gate'),
        );
        expect(guardWindow, contains('blocked=false reason=machine_gate_pass'));
        expect(
          guardWindow,
          contains('safeFinalText = m62MachineProjectionApplied'),
        );
        expect(guardWindow, contains('? m62EffectiveGate.finalText'));
        expect(guardWindow, contains(': m56bGlobalGate.finalText;'));
      },
    );
  });
}
