import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider stores a separate explicit regimen projection', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains(
        'PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowAdapter',
      ),
    );
    expect(
      source,
      contains('lastPlantaoDrugExplicitTypedRegimenEvidenceProjectionShadow'),
    );
    expect(
      source,
      contains(
        '_plantaoDrugExplicitTypedRegimenEvidenceProjectionShadowAdapter.project',
      ),
    );
    expect(source, contains('join: drugEvidenceJoin'));
    expect(
      source,
      contains('capabilityMatrix: drugTypedRegimenCapabilityMatrix'),
    );
  });

  test('projection runs only after the capability matrix', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final matrix = source.indexOf(
      '_plantaoDrugTypedRegimenCapabilityMatrixShadowAdapter.audit',
      finalizationStart,
    );
    final projection = source.indexOf(
      '_plantaoDrugExplicitTypedRegimenEvidenceProjectionShadowAdapter.project',
      finalizationStart,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(matrix, greaterThan(finalizationStart));
    expect(projection, greaterThan(matrix));
  });

  test('projection never feeds validation, prompt or persistence', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains('_lastPlantaoPersistenceShadow = persistenceSnapshot'),
    );
    expect(
      source,
      isNot(
        contains(
          '_lastPlantaoPersistenceShadow = '
          'drugExplicitTypedRegimenEvidenceProjection',
        ),
      ),
    );
    expect(
      source,
      isNot(
        contains('persistence: drugExplicitTypedRegimenEvidenceProjection'),
      ),
    );
    expect(
      source,
      isNot(contains('validation: drugExplicitTypedRegimenEvidenceProjection')),
    );
    expect(
      source,
      isNot(
        contains('evidenceBundle: drugExplicitTypedRegimenEvidenceProjection'),
      ),
    );
    expect(source, isNot(contains('validationConnected = true')));
    expect(source, isNot(contains('evidenceBundleMutationEnabled = true')));
    expect(source, isNot(contains('writeEligible = true')));
    expect(source, isNot(contains('cutoverAuthorized = true')));
    expect(source, contains('matchedDrugSummaries: const []'));
  });
}
