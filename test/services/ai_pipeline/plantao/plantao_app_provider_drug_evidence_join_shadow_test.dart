import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AppProvider stores request-scoped evidence future and joined snapshot',
    () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(source, contains('Future<PlantaoDrugEvidenceRequestSnapshot>?'));
      expect(source, contains('_plantaoDrugEvidenceRequestFuture'));
      expect(source, contains('lastPlantaoDrugEvidenceFinalizationJoinShadow'));
      expect(source, contains('observeRequest('));
      expect(source, contains('requestId: request.requestId'));
      expect(
        source,
        contains('drugEvidenceFuture: _plantaoDrugEvidenceRequestFuture'),
      );
    },
  );

  test('join occurs after existing validation and persistence shadow work', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final validation = source.indexOf(
      '_plantaoValidationShadowAdapter.validate',
      finalizationStart,
    );
    final persistence = source.indexOf(
      '_plantaoPersistenceShadowAdapter.observe',
      finalizationStart,
    );
    final join = source.indexOf(
      '_plantaoDrugEvidenceFinalizationJoinShadowAdapter.join',
      finalizationStart,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(validation, greaterThan(finalizationStart));
    expect(persistence, greaterThan(validation));
    expect(join, greaterThan(persistence));
  });

  test(
    'join remains observational and cannot feed productive or validation paths',
    () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(source, contains('matchedDrugSummaries: const []'));
      expect(source, contains('proprietaryDrugContext: null'));
      expect(source, isNot(contains('matchedDrugSummaries: drugEvidenceJoin')));
      expect(source, isNot(contains('evidenceBundle: drugEvidenceJoin')));
      expect(source, isNot(contains('validation: drugEvidenceJoin')));
      expect(source, isNot(contains('persistence: drugEvidenceJoin')));
    },
  );
}
