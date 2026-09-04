import '../contracts/plantao_canonical_drug_evidence.dart';
import 'plantao_drug_evidence_shadow_adapter.dart';
import 'plantao_drug_original_input_identity_extractor.dart';
import 'plantao_drug_original_input_intent_resolver.dart';

enum PlantaoDrugEvidenceRequestStatus {
  notEvaluated,
  ready,
  empty,
  ambiguous,
  failed,
}

class PlantaoDrugEvidenceRequestSnapshot {
  PlantaoDrugEvidenceRequestSnapshot({
    required this.requestId,
    required this.status,
    required this.intent,
    required this.evidence,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : reasons = List<String>.unmodifiable(reasons);

  static const bool originalUserInputPersisted = false;
  static const bool productiveValidationConnected = false;
  static const bool productiveProvenanceConnected = false;
  static const bool productivePersistenceConnected = false;

  final String requestId;
  final PlantaoDrugEvidenceRequestStatus status;
  final PlantaoDrugOriginalInputIntent intent;
  final PlantaoDrugEvidenceShadowSnapshot evidence;
  final List<String> reasons;
  final DateTime observedAt;

  bool get hasCanonicalEvidence => evidence.hasCanonicalEvidence;
}

class PlantaoDrugEvidenceRequestObserver {
  const PlantaoDrugEvidenceRequestObserver({
    required this.adapter,
    this.intentResolver = const PlantaoDrugOriginalInputIntentResolver(),
  });

  static const bool productivePromptConnected = false;
  static const bool productiveProviderConnected = false;
  static const bool productiveRenderingConnected = false;
  static const bool productivePersistenceConnected = false;
  static const bool userQuestionTransmittedToDrugRepository = false;

  final PlantaoDrugEvidenceShadowAdapter adapter;
  final PlantaoDrugOriginalInputIntentResolver intentResolver;

  Future<PlantaoDrugEvidenceRequestSnapshot> observeRequest({
    required String requestId,
    required String originalUserInput,
    required String languageCode,
    required String legacyQueryIntent,
    required bool legacyDirectQuery,
  }) async {
    final normalizedRequestId = requestId.trim();
    final intent = intentResolver.resolve(
      originalUserInput: originalUserInput,
      legacyQueryIntent: legacyQueryIntent,
      legacyDirectQuery: legacyDirectQuery,
    );

    if (normalizedRequestId.isEmpty) {
      final failedEvidence = PlantaoDrugEvidenceShadowSnapshot(
        status: PlantaoDrugEvidenceShadowStatus.failed,
        manifest: null,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        documents: const <PlantaoCanonicalDrugEvidenceDocument>[],
        reasons: const <String>['drug_evidence_request_id_empty'],
        observedAt: DateTime.now().toUtc(),
      );
      return PlantaoDrugEvidenceRequestSnapshot(
        requestId: normalizedRequestId,
        status: PlantaoDrugEvidenceRequestStatus.failed,
        intent: intent,
        evidence: failedEvidence,
        reasons: failedEvidence.reasons,
        observedAt: DateTime.now().toUtc(),
      );
    }

    final evidence = await adapter.retrieveOriginalUserInput(
      originalUserInput: originalUserInput,
      languageCode: languageCode,
      intent: intent,
    );

    return PlantaoDrugEvidenceRequestSnapshot(
      requestId: normalizedRequestId,
      status: _requestStatus(evidence.status),
      intent: intent,
      evidence: evidence,
      reasons: evidence.reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }

  static PlantaoDrugEvidenceRequestStatus _requestStatus(
    PlantaoDrugEvidenceShadowStatus status,
  ) {
    switch (status) {
      case PlantaoDrugEvidenceShadowStatus.notEvaluated:
        return PlantaoDrugEvidenceRequestStatus.notEvaluated;
      case PlantaoDrugEvidenceShadowStatus.complete:
      case PlantaoDrugEvidenceShadowStatus.partial:
        return PlantaoDrugEvidenceRequestStatus.ready;
      case PlantaoDrugEvidenceShadowStatus.empty:
        return PlantaoDrugEvidenceRequestStatus.empty;
      case PlantaoDrugEvidenceShadowStatus.ambiguous:
        return PlantaoDrugEvidenceRequestStatus.ambiguous;
      case PlantaoDrugEvidenceShadowStatus.failed:
        return PlantaoDrugEvidenceRequestStatus.failed;
    }
  }

  Future<PlantaoDrugEvidenceShadowSnapshot> observe({
    required String originalUserInput,
    required String languageCode,
    required String legacyQueryIntent,
    required bool legacyDirectQuery,
  }) {
    final intent = intentResolver.resolve(
      originalUserInput: originalUserInput,
      legacyQueryIntent: legacyQueryIntent,
      legacyDirectQuery: legacyDirectQuery,
    );
    return adapter.retrieveOriginalUserInput(
      originalUserInput: originalUserInput,
      languageCode: languageCode,
      intent: intent,
    );
  }
}
