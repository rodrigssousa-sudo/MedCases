import 'dart:io';

import '../../../lib/services/plantao_machine_native_context_prefetch.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyRegistrySource implements PlantaoMachineNativeRegistrySource {
  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  }) async => const <Map<String, dynamic>>[];
}

void main() {
  group('M71D runtime canonical attestation', () {
    test('attestation binds exact input/language and is one-shot', () async {
      final prefetch = PlantaoMachineNativeContextPrefetch(
        source: _EmptyRegistrySource(),
        cacheTtl: Duration.zero,
      );

      final attested = await prefetch.prefetchAttested(
        userText: 'caso clinico de teste',
        language: 'es',
      );

      expect(attested.providerInput, isNotEmpty);

      expect(
        attested.attestation.consumeForProviderInput(
          attested.providerInput,
          language: 'pt',
        ),
        isFalse,
      );
      expect(
        attested.attestation.consumeForProviderInput(
          '${attested.providerInput} alterado',
          language: 'es',
        ),
        isFalse,
      );
      expect(
        attested.attestation.consumeForProviderInput(
          attested.providerInput,
          language: 'es',
        ),
        isTrue,
      );
      expect(
        attested.attestation.consumeForProviderInput(
          attested.providerInput,
          language: 'es',
        ),
        isFalse,
        reason: 'attestation must be one-shot',
      );
    });

    test(
      'static M71 wiring flag alone is insufficient at provider boundary',
      () {
        final app = File('lib/providers/app_provider.dart').readAsStringSync();
        final oldGuard = app.indexOf(
          'M71_PLANTAO_CANONICAL_SINGLE_ENTRYPOINT_GUARD_V1',
        );
        final marker = app.indexOf('M71D_RUNTIME_ATTESTATION_PROVIDER_GATE_V1');

        expect(oldGuard, isNonNegative);
        expect(marker, greaterThan(oldGuard));
        expect(app, contains('if (!canonicalPlantaoWiring)'));
        expect(app, contains("onError('PLANTAO_CANONICAL_WIRING_REQUIRED')"));

        final window = app.substring(
          marker,
          (marker + 2600).clamp(0, app.length),
        );
        expect(window, contains('consumeForProviderInput('));
        expect(window, contains('language: _lang'));
        expect(
          window,
          contains('PLANTAO_CANONICAL_RUNTIME_ATTESTATION_REQUIRED'),
        );
        expect(window, contains('return false;'));
      },
    );

    test(
      'AiScreen binds attested prefetch to the one canonical Plantao call',
      () {
        final screen = File('lib/screens/ai_screen.dart').readAsStringSync();
        final prefetch = screen.indexOf(
          'PlantaoMachineNativeContextPrefetch.instance.prefetchAttested(',
        );
        final send = screen.indexOf('await p.sendAiMessage(', prefetch);
        final done = screen.indexOf('onDone: (finalText) {', send);
        final gate = screen.indexOf(
          'PlantaoGlobalClinicalResponseGate.finalizeForPresentation(',
          done,
        );

        expect(prefetch, isNonNegative);
        expect(send, greaterThan(prefetch));
        expect(done, greaterThan(send));
        expect(gate, greaterThan(done));

        final callWindow = screen.substring(send, done);
        expect(callWindow, contains('m56cProviderInput'));
        expect(callWindow, contains('canonicalPlantaoWiring: true'));
        expect(
          callWindow,
          contains('canonicalPlantaoAttestation: m71dRuntimeAttestation'),
        );
      },
    );

    test(
      'profile-safe runtime chain markers exist outside assert contract',
      () {
        final screen = File('lib/screens/ai_screen.dart').readAsStringSync();
        expect(
          screen,
          contains('[M71D_RUNTIME_ATTESTATION] stage=prefetch_complete'),
        );
        expect(screen, contains('[M71D_RUNTIME_CHAIN] stage=on_done_callback'));
        expect(
          screen,
          contains('[M71D_RUNTIME_CHAIN] stage=global_gate_applied'),
        );

        final app = File('lib/providers/app_provider.dart').readAsStringSync();
        expect(app, contains('[M71D_RUNTIME_ATTESTATION] allowed=true'));
        expect(app, contains('[M71D_RUNTIME_ATTESTATION] allowed=false'));
      },
    );

    test('M70C M58 M68 safety owners remain present', () {
      final gate = File(
        'lib/services/plantao_global_clinical_response_gate.dart',
      ).readAsStringSync();
      final ai = File('lib/services/ai_service.dart').readAsStringSync();

      expect(
        gate,
        contains(
          'M70C_PRE_DEDUP_MACHINE_VALIDATION_POST_DEDUP_PRESENTATION_V1',
        ),
      );
      expect(ai, contains('M58_MACHINE_NATIVE_SYSTEM_PROMPT_V1'));
      expect(ai, contains('M68_GLOBAL_TREATMENT_DOSE_SINGLE_OWNER'));
    });
  });
}
