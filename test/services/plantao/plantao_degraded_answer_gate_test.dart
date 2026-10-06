import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';

void main() {
  test('all-filtered answers retain a localized explanation', () {
    for (final language in ['pt', 'es']) {
      final text = PlantaoGlobalClinicalResponseGate.limitUnvalidatedSpecificity(
        '5 mg IV\nM59_REGISTRY_FAILED', language: language);
      expect(text, isNotEmpty);
      expect(text, isNot(contains('5 mg')));
      expect(text, isNot(contains('M59_')));
      expect(text, contains(language == 'pt' ? 'Não foi possível' : 'No fue posible'));
    }
  });

  test('unavailable registry strips dose lines and internal markers, preserves assessment', () {
    final actual = PlantaoGlobalClinicalResponseGate.limitUnvalidatedSpecificity('Avaliar estado clínico\nAdministrar 5 mg IV\nM59_REGISTRY_FAILED\nReavaliar sinais de alarme');
    expect(actual, contains('Avaliar estado clínico'));
    expect(actual, contains('Reavaliar sinais de alarme'));
    expect(actual, isNot(contains('5 mg')));
    expect(actual, isNot(contains('M59_')));
  });

  test('structural critical issue preserves useful clinical text', () {
    const result = PlantaoGlobalClinicalGateResult(
      finalText: 'Encefalopatía hepática\n\n'
          'Clasificación\n'
          'Evaluar estado mental y factores precipitantes.',
      issues: <PlantaoGlobalClinicalGateIssue>[
        PlantaoGlobalClinicalGateIssue(
          code: 'generic_task_title',
          critical: true,
          detail: 'Structural presentation issue.',
        ),
      ],
      projected: true,
      machineAuthorityEvaluated: true,
    );

    final degraded =
        PlantaoGlobalClinicalResponseGate.degradeCriticalResultForPresentation(
      result: result,
      language: 'es',
    );

    expect(degraded.finalText, contains('Encefalopatía hepática'));
    expect(degraded.finalText, contains('Evaluar estado mental'));
    expect(degraded.finalText, isNot(contains('VALIDACIÓN CLÍNICA')));
  });

  test('missing catalog action preserves general treatment',
      () {
    const result = PlantaoGlobalClinicalGateResult(
      finalText: 'Encefalopatía hepática\n\n'
          'Conducta inmediata\n'
          '- Acción todavía no validada\n\n'
          'Tratamiento farmacológico\n'
          '- Fármaco todavía no validado\n\n'
          'Clasificación\n'
          '- West Haven según hallazgos clínicos\n\n'
          'Monitorización y reevaluación\n'
          '- Reevaluar estado neurológico',
      issues: <PlantaoGlobalClinicalGateIssue>[
        PlantaoGlobalClinicalGateIssue(
          code: 'required_action_missing',
          critical: true,
          detail: 'required authored action',
        ),
      ],
      projected: true,
      machineAuthorityEvaluated: true,
    );

    final degraded =
        PlantaoGlobalClinicalResponseGate.degradeCriticalResultForPresentation(
      result: result,
      language: 'es',
    );

    expect(degraded.finalText, contains('Acción todavía no validada'));
    expect(degraded.finalText, contains('Fármaco todavía no validado'));
    expect(degraded.finalText, contains('West Haven'));
    expect(degraded.finalText, contains('Reevaluar estado neurológico'));
    expect(degraded.finalText, isNot(contains('Nota de validación')));
  });

  test(
    'prohibited positive recommendation is removed, safe content remains',
    () {
      const result = PlantaoGlobalClinicalGateResult(
        finalText: 'Tema clínico\n\n'
            'Conducta inmediata\n'
            '- Administrar medicamento prohibido ahora\n'
            '- Obtener laboratorio y monitorizar\n\n'
            'RED FLAGS\n'
            '- Deterioro hemodinámico',
        issues: <PlantaoGlobalClinicalGateIssue>[
          PlantaoGlobalClinicalGateIssue(
            code: 'prohibited_action_present',
            critical: true,
            detail: 'administrar medicamento prohibido',
          ),
        ],
        projected: true,
        machineAuthorityEvaluated: true,
      );

      final degraded = PlantaoGlobalClinicalResponseGate
          .degradeCriticalResultForPresentation(
        result: result,
        language: 'es',
      );

      expect(
        degraded.finalText.toLowerCase(),
        isNot(contains('administrar medicamento prohibido')),
      );
      expect(degraded.finalText, contains('Obtener laboratorio'));
      expect(degraded.finalText, contains('Deterioro hemodinámico'));
    },
  );

  test('M58 and M59 source use degraded-answer contract', () {
    final source = File('lib/screens/ai_screen.dart').readAsStringSync();

    expect(
      source,
      contains('M59_MACHINE_NATIVE_REGISTRY_DEGRADED_PROVIDER_V2'),
    );
    expect(source, contains('m59RegistryDegradedMode'));
    expect(source, contains('[M59_REGISTRY_DEGRADED]'));
    expect(source, isNot(contains('m59RegistryFailureText')));

    expect(source, contains('M58_DEGRADED_ANSWER_INSTEAD_OF_FULL_BLOCK_V2'));
    expect(source, contains('degradeCriticalResultForPresentation'));
    expect(source, contains('blocked=false degraded=true'));
  });
}
