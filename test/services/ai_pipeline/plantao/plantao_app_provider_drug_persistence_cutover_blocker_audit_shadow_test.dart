import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider stores a separate cutover blocker audit', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains('PlantaoDrugPersistenceCutoverBlockerAuditShadowAdapter'),
    );
    expect(
      source,
      contains('lastPlantaoDrugPersistenceCutoverBlockerAuditShadow'),
    );
    expect(
      source,
      contains('_plantaoDrugPersistenceCutoverBlockerAuditShadowAdapter.audit'),
    );
    expect(
      source,
      contains('reviewEnvelope: drugProvenancePersistenceReviewEnvelope'),
    );
    expect(source, contains('binding: drugIdentityProvenanceBinding'));
  });

  test('cutover blocker audit runs after the review envelope', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final review = source.indexOf(
      '_plantaoDrugProvenancePersistenceReviewEnvelopeShadowAdapter.prepare',
      finalizationStart,
    );
    final audit = source.indexOf(
      '_plantaoDrugPersistenceCutoverBlockerAuditShadowAdapter.audit',
      finalizationStart,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(review, greaterThan(finalizationStart));
    expect(audit, greaterThan(review));
  });

  test('audit never replaces persistence or authorizes cutover', () {
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
          'drugPersistenceCutoverBlockerAudit',
        ),
      ),
    );
    expect(
      source,
      isNot(contains('persistence: drugPersistenceCutoverBlockerAudit')),
    );
    expect(source, isNot(contains('writeEligible = true')));
    expect(source, isNot(contains('cutoverReadinessGranted = true')));
    expect(source, isNot(contains('cutoverAuthorized = true')));
    expect(source, contains('matchedDrugSummaries: const []'));
  });
}
