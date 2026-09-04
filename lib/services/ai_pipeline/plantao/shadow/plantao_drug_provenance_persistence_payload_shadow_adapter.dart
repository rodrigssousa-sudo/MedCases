import '../contracts/plantao_request.dart';
import 'plantao_drug_identity_provenance_binding_shadow_adapter.dart';

enum PlantaoDrugProvenancePersistencePayloadStatus {
  payloadPrepared,
  notBound,
  stale,
  failed,
}

class PlantaoDrugProvenancePersistencePayloadShadowSnapshot {
  PlantaoDrugProvenancePersistencePayloadShadowSnapshot({
    required this.requestId,
    required this.status,
    required Map<String, Object?> payload,
    required this.baseFuturePersistenceEligible,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : payload = _freezeMap(payload),
       reasons = List<String>.unmodifiable(reasons);

  static const bool firestoreConnected = false;
  static const bool persistenceOwnerReplaced = false;
  static const bool persistenceEligibilityPromoted = false;
  static const bool productivePersistenceConnected = false;
  static const bool productiveRenderingConnected = false;

  final String requestId;
  final PlantaoDrugProvenancePersistencePayloadStatus status;
  final Map<String, Object?> payload;
  final bool baseFuturePersistenceEligible;
  final List<String> reasons;
  final DateTime observedAt;

  bool get payloadPrepared =>
      status == PlantaoDrugProvenancePersistencePayloadStatus.payloadPrepared;
}

class PlantaoDrugProvenancePersistencePayloadShadowAdapter {
  const PlantaoDrugProvenancePersistencePayloadShadowAdapter();

  PlantaoDrugProvenancePersistencePayloadShadowSnapshot prepare({
    required PlantaoRequest request,
    required Map<String, Object?> basePersistencePayload,
    required bool baseFuturePersistenceEligible,
    required PlantaoDrugIdentityProvenanceBindingShadowSnapshot binding,
  }) {
    request.ensureValid();

    final basePayload = Map<String, Object?>.from(basePersistencePayload);
    final baseRequestId = (basePayload['requestId'] as String?)?.trim() ?? '';

    if (baseRequestId != request.requestId ||
        binding.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistencePayloadStatus.stale,
        payload: basePayload,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: const <String>[
          'drug_provenance_persistence_payload_request_id_mismatch',
        ],
      );
    }

    if (!binding.identityEvidenceBound) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistencePayloadStatus.notBound,
        payload: basePayload,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>{
          'drug_identity_provenance_not_available_for_payload',
          ...binding.reasons,
        },
      );
    }

    try {
      final enrichedPayload = Map<String, Object?>.from(basePayload)
        ..['provenance'] = binding.provenance.toJson();

      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistencePayloadStatus.payloadPrepared,
        payload: enrichedPayload,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>{
          'canonical_drug_provenance_persistence_payload_prepared',
          'base_persistence_eligibility_preserved',
          ...binding.reasons,
        },
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistencePayloadStatus.failed,
        payload: basePayload,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>[
          'drug_provenance_persistence_payload_failure:${error.runtimeType}',
        ],
      );
    }
  }

  static PlantaoDrugProvenancePersistencePayloadShadowSnapshot _snapshot({
    required String requestId,
    required PlantaoDrugProvenancePersistencePayloadStatus status,
    required Map<String, Object?> payload,
    required bool baseFuturePersistenceEligible,
    required Iterable<String> reasons,
  }) {
    return PlantaoDrugProvenancePersistencePayloadShadowSnapshot(
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
