import '../contracts/plantao_request.dart';
import 'plantao_drug_provenance_persistence_payload_parity_gate_shadow_adapter.dart';
import 'plantao_drug_provenance_persistence_payload_shadow_adapter.dart';
import 'plantao_drug_provenance_semantic_equality_gate_shadow_adapter.dart';

enum PlantaoDrugProvenancePersistenceReviewEnvelopeStatus {
  reviewEnvelopePrepared,
  payloadNotPrepared,
  parityNotVerified,
  semanticEqualityNotVerified,
  stale,
  eligibilityMismatch,
  failed,
}

class PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot {
  PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot({
    required this.requestId,
    required this.status,
    required Map<String, Object?> payload,
    required this.baseFuturePersistenceEligible,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : payload = _freezeMap(payload),
       reasons = List<String>.unmodifiable(reasons);

  static const bool firestoreConnected = false;
  static const bool writeExecuted = false;
  static const bool writeEligible = false;
  static const bool cutoverReadinessGranted = false;
  static const bool cutoverAuthorized = false;
  static const bool persistenceOwnerReplaced = false;
  static const bool persistenceEligibilityPromoted = false;
  static const bool medicationMaterializationEnabled = false;
  static const bool productiveRenderingConnected = false;

  final String requestId;
  final PlantaoDrugProvenancePersistenceReviewEnvelopeStatus status;
  final Map<String, Object?> payload;
  final bool baseFuturePersistenceEligible;
  final List<String> reasons;
  final DateTime observedAt;

  bool get reviewEnvelopePrepared =>
      status ==
      PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
          .reviewEnvelopePrepared;
}

class PlantaoDrugProvenancePersistenceReviewEnvelopeShadowAdapter {
  const PlantaoDrugProvenancePersistenceReviewEnvelopeShadowAdapter();

  PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot prepare({
    required PlantaoRequest request,
    required bool baseFuturePersistenceEligible,
    required PlantaoDrugProvenancePersistencePayloadShadowSnapshot
    preparedPayload,
    required PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot parity,
    required PlantaoDrugProvenanceSemanticEqualityShadowSnapshot
    semanticEquality,
  }) {
    request.ensureValid();

    if (preparedPayload.requestId != request.requestId ||
        parity.requestId != request.requestId ||
        semanticEquality.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus.stale,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: const <String>[
          'drug_provenance_review_envelope_request_id_mismatch',
        ],
      );
    }

    if (!preparedPayload.payloadPrepared) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
            .payloadNotPrepared,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>{
          'drug_provenance_review_envelope_payload_not_prepared',
          ...preparedPayload.reasons,
        },
      );
    }

    if (!parity.parityVerified) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
            .parityNotVerified,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>{
          'drug_provenance_review_envelope_parity_not_verified',
          ...parity.reasons,
          ...parity.unexpectedPaths,
        },
      );
    }

    if (!semanticEquality.semanticEqualityVerified) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
            .semanticEqualityNotVerified,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>{
          'drug_provenance_review_envelope_semantic_equality_not_verified',
          ...semanticEquality.reasons,
          ...semanticEquality.mismatchPaths,
        },
      );
    }

    if (preparedPayload.baseFuturePersistenceEligible !=
            baseFuturePersistenceEligible ||
        parity.baseFuturePersistenceEligible != baseFuturePersistenceEligible ||
        semanticEquality.baseFuturePersistenceEligible !=
            baseFuturePersistenceEligible) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
            .eligibilityMismatch,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: const <String>[
          'drug_provenance_review_envelope_eligibility_mismatch',
        ],
      );
    }

    final payloadRequestId =
        (preparedPayload.payload['requestId'] as String?)?.trim() ?? '';
    if (payloadRequestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus.stale,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: const <String>[
          'drug_provenance_review_envelope_payload_request_id_mismatch',
        ],
      );
    }

    try {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
            .reviewEnvelopePrepared,
        payload: preparedPayload.payload,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: const <String>[
          'canonical_drug_provenance_review_envelope_prepared',
          'manual_cutover_review_required',
          'persistence_write_not_authorized',
        ],
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus.failed,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>[
          'drug_provenance_review_envelope_failure:${error.runtimeType}',
        ],
      );
    }
  }

  static PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot
  _snapshot({
    required String requestId,
    required PlantaoDrugProvenancePersistenceReviewEnvelopeStatus status,
    required bool baseFuturePersistenceEligible,
    Map<String, Object?> payload = const <String, Object?>{},
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot(
      requestId: requestId,
      status: status,
      payload: payload,
      baseFuturePersistenceEligible: baseFuturePersistenceEligible,
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }
}

Map<String, Object?> _freezeMap(Map<String, Object?> source) {
  return Map<String, Object?>.unmodifiable(
    source.map(
      (key, value) => MapEntry<String, Object?>(key, _freezeValue(value)),
    ),
  );
}

Object? _freezeValue(Object? value) {
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable(
      value.map(
        (key, nestedValue) =>
            MapEntry<Object?, Object?>(key, _freezeValue(nestedValue)),
      ),
    );
  }
  if (value is Iterable) {
    return List<Object?>.unmodifiable(value.map(_freezeValue));
  }
  return value;
}
