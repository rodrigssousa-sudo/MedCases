import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider stores a separate validation replay comparison', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(
      source,
      contains(
        'PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowAdapter',
      ),
    );
    expect(
      source,
      contains(
        'lastPlantaoDrugProjectedEvidenceValidationReplayComparisonShadow',
      ),
    );
    expect(
      source,
      contains(
        '_plantaoDrugProjectedEvidenceValidationReplayComparisonShadowAdapter',
      ),
    );
    expect(source, contains('evidenceBundle:'));
    expect(
      source,
      contains('drugProjectedEvidenceBundleOverlay.candidateBundle!'),
    );
    expect(source, contains('originalValidationRequestId:'));
    expect(source, contains('validationSnapshot.requestId'));
    expect(source, contains('replayValidationRequestId:'));
    expect(source, contains('projectedEvidenceReplayValidation?.requestId'));
  });

  test('candidate validation runs after overlay and original persistence', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final finalizationStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final originalValidation = source.indexOf(
      '_plantaoValidationShadowAdapter.validate',
      finalizationStart,
    );
    final originalPersistence = source.indexOf(
      '_plantaoPersistenceShadowAdapter.observe',
      finalizationStart,
    );
    final overlay = source.indexOf(
      '_plantaoDrugProjectedEvidenceBundleOverlayShadowAdapter.prepare',
      finalizationStart,
    );
    final replayValidation = source.indexOf(
      '_plantaoValidationShadowAdapter.validate',
      originalValidation + 1,
    );
    final comparison = source.indexOf(
      '_plantaoDrugProjectedEvidenceValidationReplayComparisonShadowAdapter',
      overlay,
    );

    expect(finalizationStart, greaterThanOrEqualTo(0));
    expect(originalValidation, greaterThan(finalizationStart));
    expect(originalPersistence, greaterThan(originalValidation));
    expect(overlay, greaterThan(originalPersistence));
    expect(replayValidation, greaterThan(overlay));
    expect(comparison, greaterThan(replayValidation));
  });

  test('replay never replaces original validation or recomputes persistence', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final methodStart = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
    );
    final methodEnd = source.indexOf(
      '// ══════════════════════════════════════════════════════════════════════════',
      methodStart,
    );
    final method = source.substring(methodStart, methodEnd);

    expect(
      method,
      contains('_lastPlantaoValidationShadow = validationSnapshot'),
    );
    expect(
      method,
      contains('_lastPlantaoPersistenceShadow = persistenceSnapshot'),
    );
    expect(
      RegExp(
        r'_plantaoPersistenceShadowAdapter\.observe\(',
      ).allMatches(method).length,
      1,
    );
    expect(
      method,
      isNot(
        contains(
          '_lastPlantaoValidationShadow = projectedEvidenceReplayValidation',
        ),
      ),
    );
    expect(
      method,
      isNot(
        contains(
          '_lastPlantaoPersistenceShadow = projectedEvidenceReplayValidation',
        ),
      ),
    );
    expect(
      method,
      isNot(contains('validation: projectedEvidenceReplayValidation')),
    );
    expect(source, isNot(contains('originalValidationReplaced = true')));
    expect(source, isNot(contains('persistenceRecomputed = true')));
    expect(source, isNot(contains('writeEligible = true')));
    expect(source, isNot(contains('cutoverAuthorized = true')));
    expect(source, contains('matchedDrugSummaries: const []'));
  });
}
