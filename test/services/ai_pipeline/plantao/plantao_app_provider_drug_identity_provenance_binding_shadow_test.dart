import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider stores a separate drug identity provenance snapshot', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains('PlantaoDrugIdentityProvenanceBindingShadowAdapter'),
    );
    expect(source, contains('lastPlantaoDrugIdentityProvenanceBindingShadow'));
    expect(
      source,
      contains('_plantaoDrugIdentityProvenanceBindingShadowAdapter.bind'),
    );
    expect(
      source,
      contains('validationProvenance: validationSnapshot.provenance'),
    );
    expect(source, contains('join: drugEvidenceJoin'));
  });

  test('binding occurs after request-scoped join', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final join = source.indexOf(
      '_plantaoDrugEvidenceFinalizationJoinShadowAdapter.join',
      finalizationStart,
    );
    final binding = source.indexOf(
      '_plantaoDrugIdentityProvenanceBindingShadowAdapter.bind',
      finalizationStart,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(join, greaterThan(finalizationStart));
    expect(binding, greaterThan(join));
  });

  test('existing validation and persistence snapshots remain owners', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains('_lastPlantaoValidationShadow = validationSnapshot'),
    );
    expect(
      source,
      contains('_lastPlantaoPersistenceShadow = persistenceSnapshot'),
    );
    expect(
      source,
      isNot(
        contains(
          '_lastPlantaoValidationShadow = drugIdentityProvenanceBinding',
        ),
      ),
    );
    expect(
      source,
      isNot(contains('validation: drugIdentityProvenanceBinding')),
    );
    expect(
      source,
      isNot(contains('provenance: drugIdentityProvenanceBinding')),
    );
    expect(source, contains('matchedDrugSummaries: const []'));
  });
}
