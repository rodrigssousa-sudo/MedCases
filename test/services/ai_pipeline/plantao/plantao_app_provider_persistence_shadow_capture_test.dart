import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider prepares persistence only inside the existing shadow future', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(source, contains('PlantaoPersistenceShadowAdapter'));
    expect(source, contains('lastPlantaoPersistenceShadow'));
    expect(source, contains('_plantaoPersistenceShadowAdapter.observe('));
    expect(source, contains('_lastPlantaoPersistenceShadow ='));
    expect(source, isNot(contains('PlantaoPersistencePort(')));
    expect(source, isNot(contains('PlantaoResponsePipeline().execute(')));

    final start = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow({',
    );
    final end = source.indexOf('\n  // ═', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    expect(method, contains('_plantaoValidationShadowAdapter'));
    expect(method, contains('_plantaoPersistenceShadowAdapter'));
    expect(
      method.indexOf('_plantaoValidationShadowAdapter'),
      lessThan(method.indexOf('_plantaoPersistenceShadowAdapter')),
    );
    expect(method, isNot(contains('notifyListeners')));
    expect(method, isNot(contains('Firestore')));
    expect(method, isNot(contains('.write(')));
  });
}
