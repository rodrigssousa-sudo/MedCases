import '../contracts/plantao_request.dart';
import 'plantao_drug_identity_provenance_binding_shadow_adapter.dart';
import 'plantao_drug_provenance_persistence_payload_parity_gate_shadow_adapter.dart';
import 'plantao_drug_provenance_persistence_payload_shadow_adapter.dart';

enum PlantaoDrugProvenanceSemanticEqualityStatus {
  semanticEqualityVerified,
  parityNotVerified,
  payloadNotPrepared,
  stale,
  semanticMismatch,
  failed,
}

class PlantaoDrugProvenanceSemanticEqualityShadowSnapshot {
  PlantaoDrugProvenanceSemanticEqualityShadowSnapshot({
    required this.requestId,
    required this.status,
    required this.baseFuturePersistenceEligible,
    required Iterable<String> comparedProvenanceKeys,
    required Iterable<String> mismatchPaths,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : comparedProvenanceKeys = List<String>.unmodifiable(
         comparedProvenanceKeys,
       ),
       mismatchPaths = List<String>.unmodifiable(mismatchPaths),
       reasons = List<String>.unmodifiable(reasons);

  static const bool firestoreConnected = false;
  static const bool writeExecuted = false;
  static const bool cutoverReadinessGranted = false;
  static const bool cutoverAuthorized = false;
  static const bool persistenceOwnerReplaced = false;
  static const bool persistenceEligibilityPromoted = false;
  static const bool medicationMaterializationEnabled = false;

  final String requestId;
  final PlantaoDrugProvenanceSemanticEqualityStatus status;
  final bool baseFuturePersistenceEligible;
  final List<String> comparedProvenanceKeys;
  final List<String> mismatchPaths;
  final List<String> reasons;
  final DateTime observedAt;

  bool get semanticEqualityVerified =>
      status ==
          PlantaoDrugProvenanceSemanticEqualityStatus
              .semanticEqualityVerified &&
      mismatchPaths.isEmpty;
}

class PlantaoDrugProvenanceSemanticEqualityGateShadowAdapter {
  const PlantaoDrugProvenanceSemanticEqualityGateShadowAdapter();

  PlantaoDrugProvenanceSemanticEqualityShadowSnapshot verify({
    required PlantaoRequest request,
    required bool baseFuturePersistenceEligible,
    required PlantaoDrugProvenancePersistencePayloadShadowSnapshot
    preparedPayload,
    required PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot parity,
    required PlantaoDrugIdentityProvenanceBindingShadowSnapshot binding,
  }) {
    request.ensureValid();

    if (preparedPayload.requestId != request.requestId ||
        parity.requestId != request.requestId ||
        binding.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenanceSemanticEqualityStatus.stale,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: const <String>['drug_provenance_semantic_request_id_mismatch'],
      );
    }

    if (!preparedPayload.payloadPrepared) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenanceSemanticEqualityStatus.payloadNotPrepared,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>{
          'drug_provenance_semantic_payload_not_prepared',
          ...preparedPayload.reasons,
        },
      );
    }

    if (!parity.parityVerified) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenanceSemanticEqualityStatus.parityNotVerified,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>{
          'drug_provenance_semantic_parity_not_verified',
          ...parity.reasons,
          ...parity.unexpectedPaths,
        },
      );
    }

    try {
      final mismatchPaths = <String>[];

      if (preparedPayload.baseFuturePersistenceEligible !=
          baseFuturePersistenceEligible) {
        mismatchPaths.add('eligibility:prepared_payload');
      }
      if (parity.baseFuturePersistenceEligible !=
          baseFuturePersistenceEligible) {
        mismatchPaths.add('eligibility:parity_snapshot');
      }

      final payloadRequestId =
          (preparedPayload.payload['requestId'] as String?)?.trim() ?? '';
      if (payloadRequestId != request.requestId) {
        mismatchPaths.add('payload.requestId');
      }

      final actualProvenance = _stringObjectMap(
        preparedPayload.payload['provenance'],
      );
      final expectedProvenance = Map<String, Object?>.from(
        binding.provenance.toJson(),
      );

      if (actualProvenance == null) {
        mismatchPaths.add('provenance:invalid_map');
      } else {
        _collectMismatchPaths(
          expectedProvenance,
          actualProvenance,
          'provenance',
          mismatchPaths,
        );
      }

      mismatchPaths.sort();
      final comparedKeys = expectedProvenance.keys.toList(growable: false)
        ..sort();
      final status = mismatchPaths.isEmpty
          ? PlantaoDrugProvenanceSemanticEqualityStatus.semanticEqualityVerified
          : PlantaoDrugProvenanceSemanticEqualityStatus.semanticMismatch;

      return _snapshot(
        requestId: request.requestId,
        status: status,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        comparedProvenanceKeys: comparedKeys,
        mismatchPaths: mismatchPaths,
        reasons: <String>{
          if (mismatchPaths.isEmpty)
            'canonical_drug_provenance_semantic_equality_verified'
          else
            'canonical_drug_provenance_semantic_mismatch',
          'cutover_readiness_not_granted',
          'persistence_write_not_authorized',
        },
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenanceSemanticEqualityStatus.failed,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>[
          'drug_provenance_semantic_failure:${error.runtimeType}',
        ],
      );
    }
  }

  static PlantaoDrugProvenanceSemanticEqualityShadowSnapshot _snapshot({
    required String requestId,
    required PlantaoDrugProvenanceSemanticEqualityStatus status,
    required bool baseFuturePersistenceEligible,
    Iterable<String> comparedProvenanceKeys = const <String>[],
    Iterable<String> mismatchPaths = const <String>[],
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugProvenanceSemanticEqualityShadowSnapshot(
      requestId: requestId,
      status: status,
      baseFuturePersistenceEligible: baseFuturePersistenceEligible,
      comparedProvenanceKeys: comparedProvenanceKeys,
      mismatchPaths: mismatchPaths,
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }
}

Map<String, Object?>? _stringObjectMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _collectMismatchPaths(
  Object? expected,
  Object? actual,
  String path,
  List<String> mismatches,
) {
  if (expected is Map && actual is Map) {
    final keys = <Object?>{...expected.keys, ...actual.keys}.toList()
      ..sort((left, right) => '$left'.compareTo('$right'));
    for (final key in keys) {
      final childPath = '$path.$key';
      if (!expected.containsKey(key)) {
        mismatches.add('$childPath:unexpected');
      } else if (!actual.containsKey(key)) {
        mismatches.add('$childPath:missing');
      } else {
        _collectMismatchPaths(
          expected[key],
          actual[key],
          childPath,
          mismatches,
        );
      }
    }
    return;
  }

  if (expected is Iterable && actual is Iterable) {
    final expectedItems = expected.toList(growable: false);
    final actualItems = actual.toList(growable: false);
    if (expectedItems.length != actualItems.length) {
      mismatches.add('$path:length');
      return;
    }
    for (var index = 0; index < expectedItems.length; index++) {
      _collectMismatchPaths(
        expectedItems[index],
        actualItems[index],
        '$path[$index]',
        mismatches,
      );
    }
    return;
  }

  if (expected != actual) {
    mismatches.add(path);
  }
}
