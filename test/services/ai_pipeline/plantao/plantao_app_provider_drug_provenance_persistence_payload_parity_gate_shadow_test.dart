import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider stores a separate payload parity snapshot', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains(
        'PlantaoDrugProvenancePersistencePayloadParityGateShadowAdapter',
      ),
    );
    expect(
      source,
      contains('lastPlantaoDrugProvenancePersistencePayloadParityShadow'),
    );
    expect(
      source,
      contains(
        '_plantaoDrugProvenancePersistencePayloadParityGateShadowAdapter.verify',
      ),
    );
    expect(
      source,
      contains('preparedPayload: drugProvenancePersistencePayload'),
    );
    expect(source, contains('binding: drugIdentityProvenanceBinding'));
  });

  test('parity gate runs after payload preparation', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final payload = source.indexOf(
      '_plantaoDrugProvenancePersistencePayloadShadowAdapter.prepare',
      finalizationStart,
    );
    final parity = source.indexOf(
      '_plantaoDrugProvenancePersistencePayloadParityGateShadowAdapter.verify',
      finalizationStart,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(payload, greaterThan(finalizationStart));
    expect(parity, greaterThan(payload));
  });

  test('persistence owner and productive paths remain unchanged', () {
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
          'drugProvenancePersistencePayloadParity',
        ),
      ),
    );
    expect(
      source,
      isNot(contains('persistence: drugProvenancePersistencePayloadParity')),
    );
    expect(source, isNot(contains('cutoverAuthorized = true')));
    expect(source, contains('matchedDrugSummaries: const []'));
  });
}
