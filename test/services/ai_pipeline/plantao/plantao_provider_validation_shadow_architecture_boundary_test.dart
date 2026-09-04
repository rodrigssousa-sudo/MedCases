import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider port is contract-only and preserves paid-first route', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/ports/plantao_provider_port.dart',
    ).readAsStringSync();
    expect(source, contains('PlantaoProviderKind.gptPaid'));
    expect(source, contains('PlantaoProviderKind.geminiPaid'));
    expect(
      source.indexOf('PlantaoProviderKind.gptPaid'),
      lessThan(source.indexOf('PlantaoProviderKind.geminiPaid')),
    );
    expect(source, contains('productiveConnectionEnabled = false'));
    expect(source, isNot(contains('provider_router_service.dart')));
    expect(source, isNot(contains('gpt_sse_client.dart')));
    expect(source, isNot(contains('gemini_service')));
  });

  test('validation shadow has no provider, Firestore, RAG, rendering or text parser', () {
    final validator = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_deterministic_drug_validator.dart',
    ).readAsStringSync();
    final adapter = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_validation_shadow_adapter.dart',
    ).readAsStringSync();
    final combined = '$validator\n$adapter';
    for (final forbidden in <String>[
      'provider_router_service.dart',
      'gpt_sse_client.dart',
      'gemini_service',
      'firestore_service.dart',
      'ai_service.dart',
      'notifyListeners',
      '.execute(',
      'sanitizedText',
      'RegExp(',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(validator, contains('PlantaoMedicationItem('));
    expect(validator, contains('hasDeterministicDrugEvidence'));
    expect(adapter, contains('phase3e_retrieval_not_connected'));
    expect(adapter, contains('providerConnected = false'));
    expect(adapter, contains('persistenceEnabled = false'));
    expect(adapter, contains('ragConnected = false'));
  });
}
