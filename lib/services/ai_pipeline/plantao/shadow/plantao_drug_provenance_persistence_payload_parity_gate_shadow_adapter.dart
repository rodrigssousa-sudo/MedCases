import '../contracts/plantao_request.dart';
import 'plantao_drug_identity_provenance_binding_shadow_adapter.dart';
import 'plantao_drug_provenance_persistence_payload_shadow_adapter.dart';

enum PlantaoDrugProvenancePersistencePayloadParityStatus {
  parityVerified,
  notPrepared,
  stale,
  unexpectedMutation,
  failed,
}

class PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot {
  PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot({
    required this.requestId,
    required this.status,
    required this.baseFuturePersistenceEligible,
    required Iterable<String> changedTopLevelKeys,
    required Iterable<String> changedProvenanceKeys,
    required Iterable<String> unexpectedPaths,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : changedTopLevelKeys = List<String>.unmodifiable(changedTopLevelKeys),
       changedProvenanceKeys = List<String>.unmodifiable(changedProvenanceKeys),
       unexpectedPaths = List<String>.unmodifiable(unexpectedPaths),
       reasons = List<String>.unmodifiable(reasons);

  static const bool firestoreConnected = false;
  static const bool writeExecuted = false;
  static const bool cutoverAuthorized = false;
  static const bool persistenceOwnerReplaced = false;
  static const bool persistenceEligibilityPromoted = false;
  static const Set<String> allowedTopLevelDeltaKeys = <String>{'provenance'};
  static const Set<String> allowedProvenanceDeltaKeys = <String>{
    'sourceMode',
    'matchedDrugDocumentIds',
    'validatorReason',
    'documentVersions',
  };

  final String requestId;
  final PlantaoDrugProvenancePersistencePayloadParityStatus status;
  final bool baseFuturePersistenceEligible;
  final List<String> changedTopLevelKeys;
  final List<String> changedProvenanceKeys;
  final List<String> unexpectedPaths;
  final List<String> reasons;
  final DateTime observedAt;

  bool get parityVerified =>
      status ==
          PlantaoDrugProvenancePersistencePayloadParityStatus.parityVerified &&
      unexpectedPaths.isEmpty;
}

class PlantaoDrugProvenancePersistencePayloadParityGateShadowAdapter {
  const PlantaoDrugProvenancePersistencePayloadParityGateShadowAdapter();

  PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot verify({
    required PlantaoRequest request,
    required Map<String, Object?> basePersistencePayload,
    required bool baseFuturePersistenceEligible,
    required PlantaoDrugProvenancePersistencePayloadShadowSnapshot
    preparedPayload,
    required PlantaoDrugIdentityProvenanceBindingShadowSnapshot binding,
  }) {
    request.ensureValid();

    final basePayload = Map<String, Object?>.from(basePersistencePayload);
    final baseRequestId = (basePayload['requestId'] as String?)?.trim() ?? '';

    if (baseRequestId != request.requestId ||
        preparedPayload.requestId != request.requestId ||
        binding.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistencePayloadParityStatus.stale,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: const <String>[
          'drug_provenance_payload_parity_request_id_mismatch',
        ],
      );
    }

    if (!preparedPayload.payloadPrepared) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistencePayloadParityStatus.notPrepared,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>{
          'drug_provenance_payload_not_prepared',
          ...preparedPayload.reasons,
        },
      );
    }

    try {
      final enrichedPayload = preparedPayload.payload;
      final changedTopLevelKeys = _changedKeys(basePayload, enrichedPayload);
      final unexpectedPaths = <String>[];

      for (final key in changedTopLevelKeys) {
        if (!PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot
            .allowedTopLevelDeltaKeys
            .contains(key)) {
          unexpectedPaths.add('topLevel:$key');
        }
      }

      if (!changedTopLevelKeys.contains('provenance')) {
        unexpectedPaths.add('topLevel:provenance_not_changed');
      }

      if (preparedPayload.baseFuturePersistenceEligible !=
          baseFuturePersistenceEligible) {
        unexpectedPaths.add('eligibility:futurePersistenceEligible');
      }

      final baseProvenance = _stringObjectMap(basePayload['provenance']);
      final enrichedProvenance = _stringObjectMap(
        enrichedPayload['provenance'],
      );
      if (baseProvenance == null || enrichedProvenance == null) {
        unexpectedPaths.add('provenance:invalid_map');
        return _snapshot(
          requestId: request.requestId,
          status: PlantaoDrugProvenancePersistencePayloadParityStatus
              .unexpectedMutation,
          baseFuturePersistenceEligible: baseFuturePersistenceEligible,
          changedTopLevelKeys: changedTopLevelKeys,
          unexpectedPaths: unexpectedPaths,
          reasons: const <String>[
            'drug_provenance_payload_parity_invalid_provenance_map',
          ],
        );
      }

      final changedProvenanceKeys = _changedKeys(
        baseProvenance,
        enrichedProvenance,
      );
      for (final key in changedProvenanceKeys) {
        if (!PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot
            .allowedProvenanceDeltaKeys
            .contains(key)) {
          unexpectedPaths.add('provenance:$key');
        }
      }

      if (!_deepEquals(
        baseProvenance['validatedDose'],
        enrichedProvenance['validatedDose'],
      )) {
        unexpectedPaths.add('provenance:validatedDose');
      }

      final enrichedDrugIds = _stringSet(
        enrichedProvenance['matchedDrugDocumentIds'],
      );
      final expectedDrugIds = binding.provenance.matchedDrugDocumentIds.toSet();
      if (!_setEquals(enrichedDrugIds, expectedDrugIds)) {
        unexpectedPaths.add('provenance:matchedDrugDocumentIds_mismatch');
      }

      final enrichedVersions = _stringObjectMap(
        enrichedProvenance['documentVersions'],
      );
      if (enrichedVersions == null) {
        unexpectedPaths.add('provenance:documentVersions_invalid');
      } else {
        for (final documentId in binding.canonicalDocumentIds) {
          if (enrichedVersions[documentId] !=
              binding.provenance.documentVersions[documentId]) {
            unexpectedPaths.add(
              'provenance:documentVersion_mismatch:$documentId',
            );
          }
        }
      }

      final status = unexpectedPaths.isEmpty
          ? PlantaoDrugProvenancePersistencePayloadParityStatus.parityVerified
          : PlantaoDrugProvenancePersistencePayloadParityStatus
                .unexpectedMutation;

      return _snapshot(
        requestId: request.requestId,
        status: status,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        changedTopLevelKeys: changedTopLevelKeys,
        changedProvenanceKeys: changedProvenanceKeys,
        unexpectedPaths: unexpectedPaths,
        reasons: <String>{
          if (unexpectedPaths.isEmpty)
            'canonical_drug_provenance_payload_parity_verified'
          else
            'canonical_drug_provenance_payload_unexpected_mutation',
          'persistence_eligibility_unchanged',
          'persistence_write_not_authorized',
        },
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProvenancePersistencePayloadParityStatus.failed,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>[
          'drug_provenance_payload_parity_failure:${error.runtimeType}',
        ],
      );
    }
  }

  static PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot _snapshot({
    required String requestId,
    required PlantaoDrugProvenancePersistencePayloadParityStatus status,
    required bool baseFuturePersistenceEligible,
    Iterable<String> changedTopLevelKeys = const <String>[],
    Iterable<String> changedProvenanceKeys = const <String>[],
    Iterable<String> unexpectedPaths = const <String>[],
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot(
      requestId: requestId,
      status: status,
      baseFuturePersistenceEligible: baseFuturePersistenceEligible,
      changedTopLevelKeys: changedTopLevelKeys,
      changedProvenanceKeys: changedProvenanceKeys,
      unexpectedPaths: unexpectedPaths,
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }
}

List<String> _changedKeys(
  Map<String, Object?> before,
  Map<String, Object?> after,
) {
  final keys = <String>{...before.keys, ...after.keys};
  final changed = keys
      .where((key) => !_deepEquals(before[key], after[key]))
      .toList(growable: false);
  return changed..sort();
}

Map<String, Object?>? _stringObjectMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) return null;
    result[key] = entry.value;
  }
  return result;
}

Set<String> _stringSet(Object? value) {
  if (value is! Iterable) return const <String>{};
  return value.whereType<String>().toSet();
}

bool _setEquals(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final key in left.keys) {
      if (!right.containsKey(key) || !_deepEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  if (left is Iterable && right is Iterable) {
    final leftIterator = left.iterator;
    final rightIterator = right.iterator;
    while (true) {
      final leftHasNext = leftIterator.moveNext();
      final rightHasNext = rightIterator.moveNext();
      if (leftHasNext != rightHasNext) return false;
      if (!leftHasNext) return true;
      if (!_deepEquals(leftIterator.current, rightIterator.current)) {
        return false;
      }
    }
  }
  return left == right;
}
