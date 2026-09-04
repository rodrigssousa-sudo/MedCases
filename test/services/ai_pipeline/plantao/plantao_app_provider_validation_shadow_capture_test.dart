import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider records validation only inside the existing finalization shadow', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final adapter = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_validation_shadow_adapter.dart',
    ).readAsStringSync();

    expect(source, contains('PlantaoValidationShadowAdapter'));
    expect(source, contains('lastPlantaoValidationShadow'));
    expect(source, contains('observeWithoutRetrieval('));
    expect(adapter, contains('phase3e_retrieval_not_connected'));
    expect(source, isNot(contains('PlantaoResponsePipeline().execute(')));

    final start = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow({',
    );
    final end = source.indexOf('\n  // ═', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, isNot(contains('notifyListeners')));
    expect(method, isNot(contains('Firestore')));
    expect(method, isNot(contains('ProviderRouterService')));
  });
}
