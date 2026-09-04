import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider observes finalization only after productive callbacks', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    expect(source, contains('PlantaoFinalizationShadowAdapter'));
    expect(source, contains('PlantaoFinalizationShadowSnapshot? get lastPlantaoFinalizationShadow'));
    expect(source, contains('unawaited('));
    expect(source, contains('_capturePlantaoFinalizationShadow('));
    expect(source.indexOf('notifyListeners();'),
        lessThan(source.lastIndexOf('_capturePlantaoFinalizationShadow(')));
    expect(source, isNot(contains('PlantaoResponsePipeline().execute(')));
  });
}
