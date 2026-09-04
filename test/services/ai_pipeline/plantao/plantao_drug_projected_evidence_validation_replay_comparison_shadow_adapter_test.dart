import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_projected_evidence_validation_replay_comparison_shadow_adapter.dart';

PlantaoRequest request(String id) => PlantaoRequest(
  requestId: id,
  sessionId: 'session-$id',
  question: 'Qual a dose da furosemida?',
  language: PlantaoLanguage.ptBr,
  trigger: PlantaoRequestTrigger.userInput,
  continuationType: PlantaoContinuationType.initial,
  requestedSections: const [],
  strictClinicalMode: true,
);

void main() {
  const adapter =
      PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowAdapter();

  test('records status and provenance changes from the candidate replay', () {
    final snapshot = adapter.compare(
      request: request('req-replay'),
      overlayPrepared: true,
      originalValidationRequestId: 'req-replay',
      originalValidationStatus: 'incomplete',
      originalProvenance: const <String, Object?>{
        'validatedDose': false,
        'matchedDrugDocumentIds': <Object?>[],
      },
      originalRouteProviders: const <String>['gptPaid'],
      replayValidationRequestId: 'req-replay',
      replayValidationStatus: 'validated',
      replayProvenance: const <String, Object?>{
        'validatedDose': true,
        'matchedDrugDocumentIds': <Object?>['furosemida'],
      },
      replayRouteProviders: const <String>['gptPaid'],
    );

    expect(snapshot.replayCompared, isTrue);
    expect(snapshot.statusChanged, isTrue);
    expect(snapshot.provenanceChanged, isTrue);
    expect(snapshot.routeChanged, isFalse);
    expect(snapshot.anyDifference, isTrue);
    expect(snapshot.originalValidationStatus, 'incomplete');
    expect(snapshot.replayValidationStatus, 'validated');
    expect(snapshot.reasons, contains('original_validation_preserved'));
  });

  test('records an unchanged replay without promoting it', () {
    final provenance = <String, Object?>{
      'validatedDose': false,
      'documentVersions': <String, Object?>{
        'protocol:icfer': 'legacy_protocols_database_v1',
      },
    };
    final snapshot = adapter.compare(
      request: request('req-unchanged'),
      overlayPrepared: true,
      originalValidationRequestId: 'req-unchanged',
      originalValidationStatus: 'incomplete',
      originalProvenance: provenance,
      originalRouteProviders: const <String>['gptPaid', 'geminiPaid'],
      replayValidationRequestId: 'req-unchanged',
      replayValidationStatus: 'incomplete',
      replayProvenance: provenance,
      replayRouteProviders: const <String>['gptPaid', 'geminiPaid'],
    );

    expect(snapshot.replayCompared, isTrue);
    expect(snapshot.anyDifference, isFalse);
    expect(
      PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowSnapshot
          .originalValidationReplaced,
      isFalse,
    );
    expect(
      PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowSnapshot
          .persistenceRecomputed,
      isFalse,
    );
  });

  test('an unavailable overlay prevents the replay comparison', () {
    final snapshot = adapter.compare(
      request: request('req-no-overlay'),
      overlayPrepared: false,
      originalValidationRequestId: 'req-no-overlay',
      originalValidationStatus: 'incomplete',
      originalProvenance: const <String, Object?>{},
      originalRouteProviders: const <String>[],
    );

    expect(
      snapshot.status,
      PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus
          .overlayNotPrepared,
    );
    expect(snapshot.replayCompared, isFalse);
  });

  test('missing replay values remain explicit and fail-safe', () {
    final snapshot = adapter.compare(
      request: request('req-no-replay'),
      overlayPrepared: true,
      originalValidationRequestId: 'req-no-replay',
      originalValidationStatus: 'incomplete',
      originalProvenance: const <String, Object?>{},
      originalRouteProviders: const <String>[],
    );

    expect(
      snapshot.status,
      PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus
          .replayUnavailable,
    );
  });

  test('a stale replay request is rejected', () {
    final snapshot = adapter.compare(
      request: request('req-current'),
      overlayPrepared: true,
      originalValidationRequestId: 'req-current',
      originalValidationStatus: 'incomplete',
      originalProvenance: const <String, Object?>{},
      originalRouteProviders: const <String>[],
      replayValidationRequestId: 'req-old',
      replayValidationStatus: 'validated',
      replayProvenance: const <String, Object?>{},
      replayRouteProviders: const <String>[],
    );

    expect(
      snapshot.status,
      PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus.stale,
    );
  });

  test('comparison maps and routes are deeply immutable', () {
    final snapshot = adapter.compare(
      request: request('req-immutable'),
      overlayPrepared: true,
      originalValidationRequestId: 'req-immutable',
      originalValidationStatus: 'incomplete',
      originalProvenance: const <String, Object?>{
        'documentVersions': <String, Object?>{'furosemida': 'v1'},
      },
      originalRouteProviders: const <String>['gptPaid'],
      replayValidationRequestId: 'req-immutable',
      replayValidationStatus: 'validated',
      replayProvenance: const <String, Object?>{
        'documentVersions': <String, Object?>{'furosemida': 'v1'},
      },
      replayRouteProviders: const <String>['gptPaid'],
    );

    expect(
      () => snapshot.originalProvenance['validatedDose'] = true,
      throwsUnsupportedError,
    );
    final versions =
        snapshot.originalProvenance['documentVersions']!
            as Map<Object?, Object?>;
    expect(() => versions['furosemida'] = 'v2', throwsUnsupportedError);
    expect(
      () => snapshot.replayRouteProviders.add('geminiPaid'),
      throwsUnsupportedError,
    );
  });
}
