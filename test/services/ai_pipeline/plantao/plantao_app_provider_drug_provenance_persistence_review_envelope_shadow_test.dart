import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider stores a separate persistence review envelope', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains('PlantaoDrugProvenancePersistenceReviewEnvelopeShadowAdapter'),
    );
    expect(
      source,
      contains('lastPlantaoDrugProvenancePersistenceReviewEnvelopeShadow'),
    );
    expect(
      source,
      contains(
        '_plantaoDrugProvenancePersistenceReviewEnvelopeShadowAdapter.prepare',
      ),
    );
    expect(
      source,
      contains('semanticEquality: drugProvenanceSemanticEquality'),
    );
    expect(source, contains('parity: drugProvenancePersistencePayloadParity'));
  });

  test('review envelope runs only after semantic equality', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final semantic = source.indexOf(
      '_plantaoDrugProvenanceSemanticEqualityGateShadowAdapter.verify',
      finalizationStart,
    );
    final review = source.indexOf(
      '_plantaoDrugProvenancePersistenceReviewEnvelopeShadowAdapter.prepare',
      finalizationStart,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(semantic, greaterThan(finalizationStart));
    expect(review, greaterThan(semantic));
  });

  test('review envelope never replaces persistence or authorizes cutover', () {
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
          'drugProvenancePersistenceReviewEnvelope',
        ),
      ),
    );
    expect(
      source,
      isNot(contains('persistence: drugProvenancePersistenceReviewEnvelope')),
    );
    expect(source, isNot(contains('writeEligible = true')));
    expect(source, isNot(contains('cutoverReadinessGranted = true')));
    expect(source, isNot(contains('cutoverAuthorized = true')));
    expect(source, contains('matchedDrugSummaries: const []'));
  });
}
