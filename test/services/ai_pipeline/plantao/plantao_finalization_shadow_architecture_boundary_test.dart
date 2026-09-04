import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 3D adapters reuse canonical components and have no productive seams', () {
    final adapter = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_finalization_shadow_adapter.dart',
    ).readAsStringSync();
    final structure = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_response_structure_shadow_adapter.dart',
    ).readAsStringSync();

    expect(adapter, contains('AiResponseFinalizationProcessor'));
    expect(adapter, contains('AiTruncationRepairCoordinator'));
    expect(adapter, contains('PlantaoLocalClinicalOutputAdapter'));
    expect(adapter, contains('_ShadowRepairDisabledPort'));
    expect(adapter, isNot(contains('provider_router_service.dart')));
    expect(adapter, isNot(contains('firestore_service.dart')));
    expect(adapter, isNot(contains('ai_service.dart')));
    expect(adapter, isNot(contains('gpt_sse_client.dart')));
    expect(adapter, isNot(contains('gemini_service')));
    expect(adapter, isNot(contains('.execute(')));
    expect(structure, isNot(contains('RegExp(')));
    expect(structure, contains('medications: const []'));
  });
}
