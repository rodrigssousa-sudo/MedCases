import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/plantao_canonical_phenotype_resolver.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

class _AnaphylaxisSource implements PlantaoMachineNativeRegistrySource {
  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async {
    if (collection != PlantaoMachineNativeContextPrefetch.identities) {
      return const <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'canonicalKey': 'anafilaxia',
        'enabled': true,
        'aliases': <String>['anafilaxia', 'anaphylaxis'],
      },
      <String, dynamic>{
        'canonicalKey': 'asma_grave',
        'enabled': true,
        'aliases': <String>['asma grave'],
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  }) async {
    if (canonicalKey != 'anafilaxia') {
      return const <Map<String, dynamic>>[];
    }

    if (collection == PlantaoMachineNativeContextPrefetch.protocols) {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'canonicalPathologyKey': 'anafilaxia',
          'protocolKey': 'anafilaxia',
          'enabled': true,
          'priority': 230,
          'version': '2026.09',
        },
      ];
    }

    if (collection == PlantaoMachineNativeContextPrefetch.management) {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'canonicalPathologyKey': 'anafilaxia',
          'protocolKey': 'anafilaxia',
          'enabled': true,
          'managementReady': true,
          'priority': 230,
          'guidelineVersion': 'ANAPHYLAXIS_CURRENT',
          'clinicalReviewDate': '2026-08-31',
          'provenancePolicy': 'AUTHORITATIVE_CURRENT_OR_FAIL_CLOSED',
          'resolutionPolicy': 'authoritative_current_machine_management',
          'initialActions': <Map<String, String>>[
            <String, String>{
              'key': 'anaphylaxis.epinephrine',
              'pt': 'Administrar adrenalina IM imediatamente.',
              'es': 'Administrar adrenalina IM inmediatamente.',
            },
            <String, String>{
              'key': 'anaphylaxis.shock_fluid',
              'pt':
                  'Em choque, obter acesso IV e administrar cristaloide isotônico rápido.',
              'es':
                  'En shock, obtener acceso IV y administrar cristaloide isotónico rápido.',
            },
          ],
          'conditionalActions': <Map<String, String>>[
            <String, String>{
              'key': 'anaphylaxis.repeat',
              'pt':
                  'Repetir adrenalina IM em 5 minutos se persistirem problemas ABC.',
              'es':
                  'Repetir adrenalina IM a los 5 minutos si persisten problemas ABC.',
            },
          ],
          'contraindicatedActions': <Map<String, String>>[
            <String, String>{
              'key': 'anaphylaxis.steroid_routine',
              'pt': 'Usar corticoide de rotina como tratamento da anafilaxia.',
              'es':
                  'Usar corticoide de rutina como tratamiento de la anafilaxia.',
            },
          ],
          'monitoring': <Map<String, String>>[
            <String, String>{
              'key': 'anaphylaxis.monitoring',
              'pt': 'Monitorizar ECG, PA e SpO2 continuamente.',
              'es': 'Monitorizar ECG, PA y SpO2 continuamente.',
            },
          ],
          'reassessment': <Map<String, String>>[
            <String, String>{
              'key': 'anaphylaxis.reassessment',
              'pt': 'Reavaliar ABC e resposta em 5 minutos.',
              'es': 'Reevaluar ABC y respuesta a los 5 minutos.',
            },
          ],
          'escalationCriteria': <Map<String, String>>[
            <String, String>{
              'key': 'anaphylaxis.escalation',
              'pt':
                  'Após 2 doses IM adequadas com persistência grave, escalar para equipe experiente/UTI e infusão IV titulada em ambiente monitorado.',
              'es':
                  'Tras 2 dosis IM adecuadas con persistencia grave, escalar a equipo experto/UCI e infusión IV titulada en ambiente monitorizado.',
            },
          ],
        },
      ];
    }

    return const <Map<String, dynamic>>[];
  }
}

const physicalEs = '''
Mujer de 34 años, minutos después de ingerir maní desarrolla urticaria generalizada, edema labial, disnea con sibilancias, mareo y PA 82/48 mmHg. FC 124 lpm, SpO₂ 91%. Está consciente pero muy sintomática.

¿Cuál es el diagnóstico y cuál es la conducta inmediata en orden de prioridad? Incluye tratamiento de primera línea, monitorización, reevaluación y criterios de escalamiento.
''';

void main() {
  group('M58 phenotype -> canonical identity -> machine authority', () {
    test('exact physical phenotype resolves anaphylaxis without disease name',
        () {
      final result = PlantaoCanonicalPhenotypeResolver.resolve(physicalEs);
      expect(result, isNotNull);
      expect(result!.canonicalPathologyKey, 'anafilaxia');
      expect(
        result.ruleId,
        PlantaoCanonicalPhenotypeResolver.anaphylaxisRule,
      );
    });

    test('isolated findings do not overdiagnose anaphylaxis', () {
      for (final text in <String>[
        'Urticaria aislada después de comer, PA normal, sin disnea.',
        'Sibilancias aisladas en paciente asmático, sin urticaria ni hipotensión.',
        'Sibilos isolados em paciente asmático, sem urticária nem hipotensão.',
        'PA 82/48 mmHg por probable deshidratación, sin urticaria ni disnea.',
        'Hipotensión aislada, sin urticaria, sin angioedema y sin disnea.',
      ]) {
        expect(
          PlantaoCanonicalPhenotypeResolver.resolve(text),
          isNull,
          reason: text,
        );
      }
    });

    test(
        'R0 regression: negated skin/circulation terms cannot become positive signals',
        () {
      expect(
        PlantaoCanonicalPhenotypeResolver.resolve(
          'Sibilancias aisladas en paciente asmático, sin urticaria ni hipotensión.',
        ),
        isNull,
      );
      expect(
        PlantaoCanonicalPhenotypeResolver.resolve(
          'Sibilos isolados em paciente asmático, sem urticária nem hipotensão.',
        ),
        isNull,
      );
    });

    test('prefetch becomes authoritative via phenotype', () async {
      final prefetch = PlantaoMachineNativeContextPrefetch(
        source: _AnaphylaxisSource(),
      );
      final result =
          await prefetch.prefetch(userText: physicalEs, language: 'es');

      expect(result.authoritative, isTrue);
      expect(result.canonicalPathologyKey, 'anafilaxia');
      expect(result.reason, 'authoritative_pack_ready_via_phenotype');
      expect(
        result.providerPromptBlock,
        contains('[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]'),
      );
      expect(result.providerPromptBlock, contains('cristaloide isotónico'));
      expect(result.providerPromptBlock, contains('monitoring='));
      expect(result.providerPromptBlock, contains('reassessment='));
      expect(result.providerPromptBlock, contains('escalationCriteria='));
    });

    test('explicit alias keeps original lexical path', () async {
      final prefetch = PlantaoMachineNativeContextPrefetch(
        source: _AnaphylaxisSource(),
      );
      final result = await prefetch.prefetch(
        userText: 'Anafilaxia con shock',
        language: 'es',
      );
      expect(result.authoritative, isTrue);
      expect(result.canonicalPathologyKey, 'anafilaxia');
      expect(result.reason, 'authoritative_pack_ready');
    });
  });

  group('M58 runtime retirement of historical prompt authority', () {
    test('machine-native Plantao prompt is lean', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery: '$physicalEs\n\n'
            '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]\n'
            'pathology=anafilaxia\n'
            'requiredActions=Administrar adrenalina IM inmediatamente.',
        isPlantaoMode: true,
      );

      expect(prompt, contains('[MEDCASES_MACHINE_NATIVE_SYSTEM_V1]'));
      expect(prompt, contains('requiredActions'));
      expect(prompt, contains('prohibitedActions'));
      expect(prompt, contains('monitoring'));
      expect(prompt, contains('reassessment'));
      expect(prompt, contains('escalationCriteria'));
      expect(prompt, isNot(contains('ORDEM')));
      expect(prompt, isNot(contains('ORDEN 32')));
      expect(prompt, isNot(contains('M01-M21')));
      expect(prompt, isNot(contains('[AUTORIDADE_FINAL_')));
      expect(prompt, isNot(contains('[AUTORIDAD_FINAL_')));
      expect(prompt, isNot(contains('MATRIX_COMPLETION_INJECTED')));
      expect(prompt, isNot(contains('UX_FLOW_DOCTRINE_ACTIVE')));
    });

    test('Study does not enter M58 Plantao early return', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery: '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1] anafilaxia',
        isPlantaoMode: false,
      );
      expect(prompt, isNot(contains('[MEDCASES_MACHINE_NATIVE_SYSTEM_V1]')));
    });

    test('source topology places M58 before legacy Plantao assembly', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();
      final method =
          source.indexOf('static String buildClinicalSystemPrompt({');
      final m58 = source.indexOf('M58_MACHINE_NATIVE_SYSTEM_PROMPT_V1', method);
      final legacy = source.indexOf('if (isPlantaoMode)', m58);
      expect(method, greaterThanOrEqualTo(0));
      expect(m58, greaterThan(method));
      expect(legacy, greaterThan(m58));
    });
  });

  group('M58 critical gate -> no unsafe visible clinical commit', () {
    test('physical screenshot-style incomplete answer is critical', () async {
      final prefetch = PlantaoMachineNativeContextPrefetch(
        source: _AnaphylaxisSource(),
      );
      final resolved =
          await prefetch.prefetch(userText: physicalEs, language: 'es');

      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: physicalEs,
        rawText: '''
ANAFILAXIA

Conducta inmediata
- Adrenalina 0,3–0,5 mg IM inmediatamente.
- Oxígeno de alto flujo.

Puntos clave
- Reevaluar en 5–15 minutos.
- Considerar corticoides y antihistamínicos como apoyo.
''',
        language: 'es',
        contextPack: resolved.contextPack,
      );

      expect(result.hasCriticalIssue, isTrue);
      expect(
        result.issues.any((issue) => issue.code == 'required_action_missing'),
        isTrue,
      );
    });

    test('screen commit guard is after global gate and before visible commit',
        () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();
      final gate = source.indexOf(
        'PlantaoGlobalClinicalResponseGate.finalizeForPresentation(',
      );
      final guard = source.indexOf(
        'M58_MACHINE_NATIVE_FINAL_COMMIT_FAIL_CLOSED',
        gate,
      );
      final visible = source.indexOf('text: safeFinalText,', guard);

      expect(gate, greaterThanOrEqualTo(0));
      expect(guard, greaterThan(gate));
      expect(visible, greaterThan(guard));

      final window = source.substring(guard, visible);
      expect(window, contains('m56cMachineContext.authoritative'));
      expect(window, contains('m56bGlobalGate.hasCriticalIssue'));
      expect(window, contains('blocked=true reason=critical_machine_gate'));
    });
  });
}
