import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/plantao_continuation_policy.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';
import 'package:medcases/services/plantao_machine_native_rich_phase_completion.dart';

const physicalUser =
    'Paciente con anafilaxia después de medicación, con urticaria, disnea e hipotensión. '
    '¿Cuál es el diagnóstico y la conducta inmediata?';

const physicalRaw = '''
🟥 CONDUCTA CLÍNICA INMEDIATA

**Diagnóstico:** Anafilaxia.

**Conducta inmediata:**

- Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL en la cara anterolateral del muslo; máximo 0,5 mg en el adulto.
- Evaluar de inmediato vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.
- Obtener acceso IV y usar cristaloide isotónico rápidamente si hay hipotensión o shock.
''';

const genericEvolutionEs = SmartNextAction(
  label: 'Estudios y evolución',
  promptToSend: 'Completar estudios y evolución del caso.',
  continuationType: PlantaoContinuationType.examsEvolution,
  requestedSections: <PlantaoSection>[
    PlantaoSection.exams,
    PlantaoSection.evolution,
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'physical anaphylaxis RAW becomes destination-ready from typed phases',
    () async {
      final prefetch = PlantaoMachineNativeContextPrefetch(
        source: PlantaoBundledPhase24MachineNativeRegistrySource(),
        cacheTtl: Duration.zero,
      );
      final resolved = await prefetch.prefetch(
        userText: physicalUser,
        language: 'es',
      );

      expect(resolved.authoritative, isTrue);
      expect(resolved.canonicalPathologyKey, 'anafilaxia');
      expect(resolved.monitoring, isNotEmpty);
      expect(resolved.reassessment, isNotEmpty);
      expect(resolved.escalationCriteria, isNotEmpty);

      final gate = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: physicalUser,
        rawText: physicalRaw,
        language: 'es',
        contextPack: resolved.contextPack,
      );
      expect(gate.issues, isEmpty);
      expect(gate.hasCriticalIssue, isFalse);

      final completion = PlantaoMachineNativeRichPhaseCompletion.complete(
        text: gate.finalText,
        userText: physicalUser,
        language: 'es',
        enabled: true,
        monitoring: resolved.monitoring,
        reassessment: resolved.reassessment,
        escalationCriteria: resolved.escalationCriteria,
      );

      expect(completion.applied, isTrue);
      expect(completion.addedMonitoring, greaterThan(0));
      expect(completion.addedReassessment, greaterThan(0));
      expect(completion.addedEscalation, greaterThan(0));
      expect(completion.text, contains('Monitorización y reevaluación'));
      expect(completion.text, contains('Red flags/escalamiento'));

      for (final value in <String>[
        ...resolved.monitoring,
        ...resolved.reassessment,
        ...resolved.escalationCriteria,
      ]) {
        expect(completion.text, contains(value));
      }

      final action = PlantaoContinuationPolicy.resolve(
        baseAction: genericEvolutionEs,
        lastUserMessage: physicalUser,
        lastAiResponse: completion.text,
        chatHistory: const <String>[],
        languageCode: 'es',
      );
      expect(action.label, 'Definir destino');
      expect(
        action.continuationType,
        PlantaoContinuationType.prognosisDisposition,
      );
    },
  );

  test('completion is idempotent', () {
    const monitoring = <String>['Observar evolución clínica.'];
    const reassessment = <String>['Reevaluar respuesta al tratamiento.'];
    const escalation = <String>['Escalar ante deterioro clínico.'];
    const base = 'Conducta inmediata\n\n- Tratamiento inicial realizado.';

    final first = PlantaoMachineNativeRichPhaseCompletion.complete(
      text: base,
      userText: '¿Cuál es la conducta?',
      language: 'es',
      enabled: true,
      monitoring: monitoring,
      reassessment: reassessment,
      escalationCriteria: escalation,
    );
    expect(first.applied, isTrue);

    final second = PlantaoMachineNativeRichPhaseCompletion.complete(
      text: first.text,
      userText: '¿Cuál es la conducta?',
      language: 'es',
      enabled: true,
      monitoring: monitoring,
      reassessment: reassessment,
      escalationCriteria: escalation,
    );
    expect(second.applied, isFalse);
    expect(second.text, first.text);
  });

  test('classification-only surface is not expanded into management', () {
    final result = PlantaoMachineNativeRichPhaseCompletion.complete(
      text: 'Clasificación del paciente: clase I.',
      userText: '¿Cuál es la clasificación?',
      language: 'es',
      enabled: true,
      monitoring: const <String>['Monitorizar continuamente.'],
      reassessment: const <String>['Reevaluar después de intervención.'],
      escalationCriteria: const <String>['Escalar ante deterioro.'],
    );
    expect(result.applied, isFalse);
  });

  test(
    'runtime wiring stays after M62 and before M58 with zero provider path',
    () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();
      final m62 = source.indexOf(
        'M62_MACHINE_NATIVE_EVIDENCE_BACKED_REQUIRED_PROJECTOR_RUNTIME_V1',
      );
      final m73 = source.indexOf(
        'M73B_TYPED_RICH_PHASES_FINAL_COMPLETENESS_RUNTIME_V1',
        m62,
      );
      final m58 = source.indexOf(
        'M58_MACHINE_NATIVE_FINAL_COMMIT_FAIL_CLOSED',
        m73,
      );
      final visible = source.indexOf('text: safeFinalText,', m58);

      expect(m62, isNonNegative);
      expect(m73, greaterThan(m62));
      expect(m58, greaterThan(m73));
      expect(visible, greaterThan(m58));

      final window = source.substring(m73, m58);
      expect(window, isNot(contains('sendAiMessage(')));
      expect(window, isNot(contains('gptProxy')));
      expect(window, isNot(contains('FirebaseFirestore')));
      expect(window, contains('m56cMachineContext.monitoring'));
      expect(window, contains('m56cMachineContext.reassessment'));
      expect(window, contains('m56cMachineContext.escalationCriteria'));

      final guard = source.substring(m58, visible);
      expect(guard, contains('m58BlockUnsafeClinicalCommit'));
      expect(guard, contains('blocked=true reason=critical_machine_gate'));
      expect(guard, contains('blocked=false reason=machine_gate_pass'));
      expect(guard, contains('safeFinalText = m62MachineProjectionApplied'));
      expect(guard, contains('? m62EffectiveGate.finalText'));
      expect(guard, contains(': m56bGlobalGate.finalText;'));
      expect(guard, contains('M73B_M62_SAFE_FINAL_CONTRACT_PRESERVATION_V1'));
      expect(guard, contains('safeFinalText = m73bRichPhaseCompletion.text;'));
    },
  );
}
