import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';

void main() {
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

  test('missing required action removes actionable treatment sections only',
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

    expect(degraded.finalText, isNot(contains('Acción todavía no validada')));
    expect(degraded.finalText, isNot(contains('Fármaco todavía no validado')));
    expect(degraded.finalText, contains('West Haven'));
    expect(degraded.finalText, contains('Reevaluar estado neurológico'));
    expect(degraded.finalText, contains('Nota de validación'));
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
