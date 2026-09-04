import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider stores a separate enriched persistence payload', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains('PlantaoDrugProvenancePersistencePayloadShadowAdapter'),
    );
    expect(
      source,
      contains('lastPlantaoDrugProvenancePersistencePayloadShadow'),
    );
    expect(
      source,
      contains('_plantaoDrugProvenancePersistencePayloadShadowAdapter.prepare'),
    );
    expect(
      source,
      contains('basePersistencePayload: persistenceSnapshot.record.toJson()'),
    );
    expect(
      source,
      matches(
        RegExp(
          r'baseFuturePersistenceEligible:\s*'
          r'persistenceSnapshot\.futurePersistenceEligible',
        ),
      ),
    );
    expect(source, contains('binding: drugIdentityProvenanceBinding'));
  });

  test('payload is prepared only after canonical provenance binding', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final binding = source.indexOf(
      '_plantaoDrugIdentityProvenanceBindingShadowAdapter.bind',
      finalizationStart,
    );
    final payload = source.indexOf(
      '_plantaoDrugProvenancePersistencePayloadShadowAdapter.prepare',
      finalizationStart,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(binding, greaterThan(finalizationStart));
    expect(payload, greaterThan(binding));
  });

  test('existing persistence snapshot remains the owner', () {
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
          'drugProvenancePersistencePayload',
        ),
      ),
    );
    expect(
      source,
      isNot(contains('persistence: drugProvenancePersistencePayload')),
    );
    expect(source, contains('matchedDrugSummaries: const []'));
  });
}
