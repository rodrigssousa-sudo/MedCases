import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider stores a separate semantic equality snapshot', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains('PlantaoDrugProvenanceSemanticEqualityGateShadowAdapter'),
    );
    expect(source, contains('lastPlantaoDrugProvenanceSemanticEqualityShadow'));
    expect(
      source,
      contains(
        '_plantaoDrugProvenanceSemanticEqualityGateShadowAdapter.verify',
      ),
    );
    expect(source, contains('parity: drugProvenancePersistencePayloadParity'));
    expect(source, contains('binding: drugIdentityProvenanceBinding'));
  });

  test('semantic gate runs after payload parity', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final parity = source.indexOf(
      '_plantaoDrugProvenancePersistencePayloadParityGateShadowAdapter.verify',
      finalizationStart,
    );
    final semantic = source.indexOf(
      '_plantaoDrugProvenanceSemanticEqualityGateShadowAdapter.verify',
      finalizationStart,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(parity, greaterThan(finalizationStart));
    expect(semantic, greaterThan(parity));
  });

  test('persistence owner and cutover state remain unchanged', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains('_lastPlantaoPersistenceShadow = persistenceSnapshot'),
    );
    expect(
      source,
      isNot(
        contains(
          '_lastPlantaoPersistenceShadow = drugProvenanceSemanticEquality',
        ),
      ),
    );
    expect(
      source,
      isNot(contains('persistence: drugProvenanceSemanticEquality')),
    );
    expect(source, isNot(contains('cutoverReadinessGranted = true')));
    expect(source, isNot(contains('cutoverAuthorized = true')));
    expect(source, contains('matchedDrugSummaries: const []'));
  });
}
