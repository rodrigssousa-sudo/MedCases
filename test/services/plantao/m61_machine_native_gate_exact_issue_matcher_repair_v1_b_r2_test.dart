import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

const physicalProviderRawEs = '''
🟥 CONDUCTA CLÍNICA INMEDIATA

Patología/diagnóstico: Anafilaxia.

Conducta inmediata:

1. Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL (máximo 0,5 mg en adultos) en la cara anterolateral del muslo.

2. Evaluar inmediatamente la vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.

3. Obtener acceso IV y administrar cristaloide isotónico rápidamente debido a la hipotensión.

Tratamiento farmacológico:

- Adrenalina IM (primera línea).

- Antihistamínicos como tratamiento secundario solo para síntomas cutáneos.

Monitorización y reevaluación:

- Observar la respuesta clínica hasta la resolución completa.

- Reevaluar después de cada intervención y cada dosis de adrenalina.

Puntos clave:

- No retrasar la administración de adrenalina por otras medidas (antihistamínicos, corticoides).

- Los antihistamínicos no sustituyen a la adrenalina.

Red flags/escalamiento:

- Escalar a equipo de emergencias/UCI ante shock, obstrucci
''';

// R2: Phase24 rich fields are normalized upstream into this public pack API.
PlantaoGlobalClinicalContextPack fixturePack({
  List<String> requiredActions = const <String>[],
  List<String> prohibitedActions = const <String>[],
  List<String> classificationDependencies = const <String>[],
  List<String> scoreDependencies = const <String>[],
  bool authoritative = true,
}) {
  return PlantaoGlobalClinicalContextPack(
    pathologyKey: 'matcher_fixture',
    protocolKey: 'fixture::matcher',
    guidelineVersion: 'TEST_CURRENT',
    clinicalReviewDate: '2026-09-01',
    requiredActions: requiredActions,
    prohibitedActions: prohibitedActions,
    conditionalActions: const <String>[],
    classificationDependencies: classificationDependencies,
    scoreDependencies: scoreDependencies,
    authoritative: authoritative,
  );
}

PlantaoGlobalClinicalGateResult run(
  String raw,
  PlantaoGlobalClinicalContextPack pack,
) => PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
  userText: 'fixture',
  rawText: raw,
  language: 'es',
  contextPack: pack,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M61 exact physical matcher repair', () {
    test(
      'real bundled Phase24 physical RAW no longer false-negatives',
      () async {
        final prefetch = PlantaoMachineNativeContextPrefetch(
          source: PlantaoBundledPhase24MachineNativeRegistrySource(),
          cacheTtl: Duration.zero,
        );
        final resolved = await prefetch.prefetch(
          userText: 'anafilaxia',
          language: 'es',
        );

        expect(resolved.authoritative, isTrue);
        expect(resolved.canonicalPathologyKey, 'anafilaxia');
        final pack = resolved.contextPack!;
        expect(pack.requiredActions, isNotEmpty);

        final result =
            PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
              userText: 'anafilaxia',
              rawText: physicalProviderRawEs,
              language: 'es',
              contextPack: pack,
            );

        expect(
          result.issues.where((i) => i.code == 'required_action_missing'),
          isEmpty,
        );
        expect(result.hasCriticalIssue, isFalse);
        expect(result.machineAuthorityEvaluated, isTrue);
      },
    );

    test('same-line multi-clause paraphrase aggregates after exact mismatch', () {
      const required =
          'Evaluar de inmediato vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.';
      final result = run(
        'ANAFILAXIA\n\nConducta inmediata\n'
        '- Evaluar inmediatamente la vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.',
        fixturePack(requiredActions: const <String>[required]),
      );
      expect(
        result.issues.where((i) => i.code == 'required_action_missing'),
        isEmpty,
      );
    });

    test(
      'same authored action split across separate lines does not aggregate',
      () {
        const required =
            'Evaluar de inmediato vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.';
        final result = run(
          'ANAFILAXIA\n\nConducta inmediata\n'
          '- Evaluar de inmediato vía aérea, ventilación y circulación.\n'
          '- Administrar oxígeno y soporte ventilatorio según necesidad.',
          fixturePack(requiredActions: const <String>[required]),
        );
        expect(
          result.issues.any((i) => i.code == 'required_action_missing'),
          isTrue,
        );
      },
    );

    test('negated positive required directive remains rejected', () {
      const required = 'Administrar adrenalina IM inmediatamente.';
      final result = run(
        'ANAFILAXIA\n\nConducta inmediata\n- No administrar adrenalina IM inmediatamente.',
        fixturePack(requiredActions: const <String>[required]),
      );
      expect(
        result.issues.any((i) => i.code == 'required_action_missing'),
        isTrue,
      );
    });

    test('negative prohibited guidance remains safe', () {
      const prohibited =
          'No usar corticoide con el objetivo de prevenir una reacción bifásica.';
      final result = run(
        'ANAFILAXIA\n\nPuntos clave\n- No usar corticoide con el objetivo de prevenir una reacción bifásica.',
        fixturePack(prohibitedActions: const <String>[prohibited]),
      );
      expect(
        result.issues.any((i) => i.code == 'prohibited_action_present'),
        isFalse,
      );
    });

    test('positive prohibited action remains detected', () {
      const prohibited = 'Usar corticoide de rutina como tratamiento.';
      final result = run(
        'ANAFILAXIA\n\nConducta inmediata\n- Usar corticoide de rutina como tratamiento.',
        fixturePack(prohibitedActions: const <String>[prohibited]),
      );
      expect(
        result.issues.any((i) => i.code == 'prohibited_action_present'),
        isTrue,
      );
    });

    test('true omission of one real core action remains fail-closed', () async {
      final prefetch = PlantaoMachineNativeContextPrefetch(
        source: PlantaoBundledPhase24MachineNativeRegistrySource(),
        cacheTtl: Duration.zero,
      );
      final resolved = await prefetch.prefetch(
        userText: 'anafilaxia',
        language: 'es',
      );
      final pack = resolved.contextPack!;

      final withoutAirwayLine = physicalProviderRawEs.replaceFirst(
        '2. Evaluar inmediatamente la vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.\n\n',
        '',
      );
      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'anafilaxia',
        rawText: withoutAirwayLine,
        language: 'es',
        contextPack: pack,
      );
      expect(
        result.issues.any((i) => i.code == 'required_action_missing'),
        isTrue,
      );
      expect(result.hasCriticalIssue, isTrue);
    });

    test(
      'M61 changes gate matcher only; M58/M60 runtime owners stay external',
      () {
        final gate = File(
          'lib/services/plantao_global_clinical_response_gate.dart',
        ).readAsStringSync();
        final screen = File('lib/screens/ai_screen.dart').readAsStringSync();
        final prefetch = File(
          'lib/services/plantao_machine_native_context_prefetch.dart',
        ).readAsStringSync();

        expect(
          gate,
          contains('M61_MACHINE_NATIVE_LINE_AGGREGATE_TOKEN_FALLBACK_V1'),
        );
        expect(gate, contains('M56C_MACHINE_NATIVE_ACTION_MATCHER_V3'));
        expect(gate, contains('M56C_R6_DIRECTIVE_POLARITY_V3'));
        expect(screen, contains('M58_MACHINE_NATIVE_FINAL_COMMIT_FAIL_CLOSED'));
        expect(prefetch, contains('M60_BUNDLED_PHASE24_REGISTRY_SOURCE_V1'));
        expect(
          prefetch,
          contains('PlantaoFailoverMachineNativeRegistrySource'),
        );
      },
    );
  });
}
