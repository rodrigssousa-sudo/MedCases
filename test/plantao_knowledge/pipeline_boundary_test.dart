import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';
import 'package:medcases/services/plantao_knowledge/remote_knowledge.dart';
import 'knowledge_fixture.dart';

class _EmptySource implements PlantaoMachineNativeRegistrySource {
  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async => [];
  @override
  Future<List<Map<String, dynamic>>> loadPathology(
          String collection, String canonicalKey,
          {String fieldPath = 'canonicalPathologyKey'}) async =>
      [];
}

void main() {
  test(
      'remote supplement binds attestation but cannot create clinical authority',
      () async {
    final service = PlantaoMachineNativeContextPrefetch(source: _EmptySource());
    final result = await service.prefetchAttested(
        userText: 'TEST_CONTEXT',
        language: 'pt',
        supplementalEvidence: (internal) async {
          expect(internal.authoritative, isFalse);
          return 'REMOTE_TEST_EVIDENCE';
        });
    expect(result.providerInput, 'TEST_CONTEXT\n\nREMOTE_TEST_EVIDENCE');
    expect(result.attestation.safetyEvidence.items, isEmpty);
    expect(result.attestation.authoritative, isFalse);
    expect(
        result.attestation
            .consumeForProviderInput('TEST_CONTEXT', language: 'pt'),
        isFalse);
    expect(
        result.attestation
            .consumeForProviderInput(result.providerInput, language: 'pt'),
        isTrue);
    expect(
        result.attestation
            .consumeForProviderInput(result.providerInput, language: 'pt'),
        isFalse);
  });
  test('failed supplement retains exact existing pipeline input', () async {
    final service = PlantaoMachineNativeContextPrefetch(source: _EmptySource());
    final result = await service.prefetchAttested(
        userText: 'TEST_CONTEXT',
        language: 'es',
        supplementalEvidence: (_) async => throw StateError('TEST_FAILURE'));
    expect(result.providerInput, 'TEST_CONTEXT');
    expect(result.attestation.safetyEvidence.items, isEmpty);
    expect(
        result.attestation
            .consumeForProviderInput('TEST_CONTEXT', language: 'es'),
        isTrue);
  });
  test('new followup is bound to same context and canonical provider pipeline',
      () {
    final screen = File('lib/screens/ai_screen.dart').readAsStringSync();
    final provider = File('lib/providers/app_provider.dart').readAsStringSync();
    expect(
        screen, contains('preserveClinicalContext: therapeuticAlternatives'));
    expect(
        screen, contains('providerInputOverride:_therapeuticContexts[msg.id]'));
    expect(screen, contains('therapeuticAlternatives:true'));
    expect(screen,
        contains('canonicalPlantaoAttestation: m71dRuntimeAttestation'));
    expect(provider, contains('!(preserveClinicalContext && fromButton)'));
    expect(provider, contains('bool preserveClinicalContext = false'));
  });
  test(
      'future followups require explicit applicability and are included in clinical hash',
      () {
    final p = syntheticProtocol();
    p['contextualFollowUps'] = [
      {
        'id': 'TEST_FOLLOWUP',
        'kind': 'renal_adjustment',
        'applicable': false,
        'label': {'pt': 'TEST_PT', 'es': 'TEST_ES'}
      }
    ];
    p['clinicalContentSha256'] = clinicalKnowledgeHash(p);
    expect(
        RemoteKnowledgeProtocol.parse(p).json['contextualFollowUps'][0]
            ['applicable'],
        false);
    p['contextualFollowUps'][0]['applicable'] = true;
    expect(() => RemoteKnowledgeProtocol.parse(p), throwsException);
    p['contextualFollowUps'][0].remove('applicable');
    p['clinicalContentSha256'] = clinicalKnowledgeHash(p);
    expect(() => RemoteKnowledgeProtocol.parse(p), throwsException);
  });
}
