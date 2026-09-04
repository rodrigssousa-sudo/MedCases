import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

class FakeSource implements PlantaoMachineNativeRegistrySource {
  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async {
    if (collection != PlantaoMachineNativeContextPrefetch.identities)
      return const [];
    return [
      {
        'canonicalKey': 'anafilaxia',
        'enabled': true,
        'aliases': ['anafilaxia', 'anaphylaxis'],
      },
      {
        'canonicalKey': 'bronquiolite_aguda',
        'enabled': true,
        'aliases': ['bronquiolitis aguda'],
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String key, {
    String fieldPath = 'canonicalPathologyKey',
  }) async {
    if (key != 'anafilaxia') return const [];
    if (collection == PlantaoMachineNativeContextPrefetch.protocols) {
      return [
        {
          'protocolKey': 'anafilaxia',
          'canonicalPathologyKey': 'anafilaxia',
          'enabled': true,
          'priority': 100,
          'version': '2026.1',
        },
      ];
    }
    if (collection == PlantaoMachineNativeContextPrefetch.management) {
      return [
        {
          'canonicalPathologyKey': 'anafilaxia',
          'enabled': true,
          'priority': 100,
          'guidelineVersion': 'RCUK-2025',
          'clinicalReviewDate': '2026-09-01',
          'initialActions': [
            'adrenalina IM imediatamente',
            'cristaloide isotônico rápido no choque',
          ],
          'contraindicatedActions': ['corticoide de rotina'],
          'conditionalActions': [
            'repetir adrenalina IM em 5 minutos se persistirem problemas ABC',
          ],
        },
      ];
    }
    if (collection == PlantaoMachineNativeContextPrefetch.classifications) {
      return [
        {
          'classificationKey': 'anafilaxia_diagnostico',
          'mode': 'categorical',
          'enabled': true,
        },
      ];
    }
    return const [];
  }
}

class AmbiguousSource implements PlantaoMachineNativeRegistrySource {
  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async => [
    {
      'canonicalKey': 'one',
      'enabled': true,
      'aliases': ['abc syndrome'],
    },
    {
      'canonicalKey': 'two',
      'enabled': true,
      'aliases': ['abc syndrome'],
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String c,
    String k, {
    String fieldPath = 'canonicalPathologyKey',
  }) async => const [];
}

void main() {
  test('registry alias resolves authoritative context pack', () async {
    final p = PlantaoMachineNativeContextPrefetch(source: FakeSource());
    final r = await p.prefetch(
      userText: 'anafilaxia con shock',
      language: 'es',
    );
    expect(r.authoritative, isTrue);
    expect(r.canonicalPathologyKey, 'anafilaxia');
    expect(r.contextPack!.guidelineVersion, 'RCUK-2025');
    expect(
      r.providerPromptBlock,
      contains('[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]'),
    );
    expect(r.contextPack!.prohibitedActions, contains('corticoide de rotina'));
  });

  test('ambiguous alias fails closed', () async {
    final p = PlantaoMachineNativeContextPrefetch(source: AmbiguousSource());
    final r = await p.prefetch(userText: 'abc syndrome', language: 'en');
    expect(r.authoritative, isFalse);
    expect(r.reason, 'identity_not_resolved_or_ambiguous');
  });

  test('same pack validates final answer', () async {
    final p = PlantaoMachineNativeContextPrefetch(source: FakeSource());
    final r = await p.prefetch(userText: 'anafilaxia', language: 'es');
    final good = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
      userText: 'anafilaxia',
      rawText:
          'ANAFILAXIA\n\nConducta inmediata\n- Adrenalina IM inmediatamente.\n- Acceso IV con cristaloide isotónico rápido por shock.',
      language: 'es',
      contextPack: r.contextPack,
    );
    expect(
      good.issues.where((x) => x.code == 'required_action_missing'),
      isEmpty,
    );
    final bad = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
      userText: 'anafilaxia',
      rawText: 'ANAFILAXIA\n\nConducta inmediata\n- Corticoide de rotina.',
      language: 'es',
      contextPack: r.contextPack,
    );
    expect(bad.hasCriticalIssue, isTrue);
    expect(
      bad.issues.any((x) => x.code == 'prohibited_action_present'),
      isTrue,
    );
  });

  test('machine action matching is bilingual and negation-aware', () async {
    final p = PlantaoMachineNativeContextPrefetch(source: FakeSource());
    final r = await p.prefetch(userText: 'anafilaxia', language: 'es');

    final negatedRequired =
        PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
          userText: 'anafilaxia',
          rawText:
              'ANAFILAXIA\n\nConducta inmediata\n- No administrar adrenalina IM.',
          language: 'es',
          contextPack: r.contextPack,
        );
    expect(
      negatedRequired.issues.any((x) => x.code == 'required_action_missing'),
      isTrue,
    );

    final safeNegatedProhibited =
        PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
          userText: 'anafilaxia',
          rawText:
              'ANAFILAXIA\n\nConducta inmediata\n- Adrenalina IM inmediatamente.\n- Acceso IV con cristaloide isotónico rápido por shock.\n\nPuntos clave\n- Corticoides no son de rutina.',
          language: 'es',
          contextPack: r.contextPack,
        );
    expect(
      safeNegatedProhibited.issues.any(
        (x) => x.code == 'prohibited_action_present',
      ),
      isFalse,
    );
  });

  test(
    'screen prefetches before provider and reuses same pack after provider',
    () {
      final s = File('lib/screens/ai_screen.dart').readAsStringSync();
      final pre = s.indexOf('M56C_MACHINE_NATIVE_REGISTRY_PREFETCH');
      final send = s.indexOf('await p.sendAiMessage(', pre);
      final done = s.indexOf('onDone: (finalText) {', send);
      final gate = s.indexOf(
        'PlantaoGlobalClinicalResponseGate.finalizeForPresentation(',
        done,
      );
      expect(pre, greaterThanOrEqualTo(0));
      expect(send, greaterThan(pre));
      expect(done, greaterThan(send));
      expect(gate, greaterThan(done));
      expect(s.substring(send, done), contains('m56cProviderInput'));
      expect(s.substring(send, done), contains('visibleUserInput: trimmed'));
      expect(
        s.substring(gate, gate + 1200),
        contains('contextPack: m56cMachineContext.contextPack'),
      );
    },
  );

  test('prefetch source is read-only and M56B buffer remains', () {
    final p = File(
      'lib/services/plantao_machine_native_context_prefetch.dart',
    ).readAsStringSync();
    expect(p, contains('.get()'));
    expect(p, isNot(contains('.set(')));
    expect(p, isNot(contains('.update(')));
    expect(p, isNot(contains('.delete(')));
    final s = File('lib/screens/ai_screen.dart').readAsStringSync();
    expect(s, contains('M56B_BUFFERED_FINAL_COMMIT'));
    expect(s, contains('m56bBufferedPlantaoText = accumulated;'));
  });
}
