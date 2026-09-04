import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider stores a separate typed regimen capability matrix', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains('PlantaoDrugTypedRegimenCapabilityMatrixShadowAdapter'),
    );
    expect(
      source,
      contains('lastPlantaoDrugTypedRegimenCapabilityMatrixShadow'),
    );
    expect(
      source,
      contains('_plantaoDrugTypedRegimenCapabilityMatrixShadowAdapter.audit'),
    );
    expect(source, contains('join: drugEvidenceJoin'));
    expect(source, contains('binding: drugIdentityProvenanceBinding'));
    expect(
      source,
      contains('cutoverBlockerAudit: drugPersistenceCutoverBlockerAudit'),
    );
  });

  test('the capability matrix runs after the cutover blocker audit', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final blockerAudit = source.indexOf(
      '_plantaoDrugPersistenceCutoverBlockerAuditShadowAdapter.audit',
      finalizationStart,
    );
    final matrix = source.indexOf(
      '_plantaoDrugTypedRegimenCapabilityMatrixShadowAdapter.audit',
      finalizationStart,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(blockerAudit, greaterThan(finalizationStart));
    expect(matrix, greaterThan(blockerAudit));
  });

  test('the matrix never feeds prompt, persistence or cutover', () {
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
          'drugTypedRegimenCapabilityMatrix',
        ),
      ),
    );
    expect(
      source,
      isNot(contains('persistence: drugTypedRegimenCapabilityMatrix')),
    );
    expect(source, isNot(contains('freeTextDoseExtractionEnabled = true')));
    expect(source, isNot(contains('inferredTypedRegimenEnabled = true')));
    expect(source, isNot(contains('writeEligible = true')));
    expect(source, isNot(contains('cutoverReadinessGranted = true')));
    expect(source, isNot(contains('cutoverAuthorized = true')));
    expect(source, contains('matchedDrugSummaries: const []'));
  });
}
