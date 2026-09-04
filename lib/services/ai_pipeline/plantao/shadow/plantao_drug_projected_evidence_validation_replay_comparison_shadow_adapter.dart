import '../contracts/plantao_request.dart';

enum PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus {
  replayCompared,
  overlayNotPrepared,
  replayUnavailable,
  stale,
  failed,
}

class PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowSnapshot {
  PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowSnapshot({
    required this.requestId,
    required this.status,
    required this.originalValidationStatus,
    required this.replayValidationStatus,
    required Map<String, Object?> originalProvenance,
    required Map<String, Object?> replayProvenance,
    required Iterable<String> originalRouteProviders,
    required Iterable<String> replayRouteProviders,
    required this.statusChanged,
    required this.provenanceChanged,
    required this.routeChanged,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : originalProvenance = _freezeMap(originalProvenance),
       replayProvenance = _freezeMap(replayProvenance),
       originalRouteProviders = List<String>.unmodifiable(
         originalRouteProviders,
       ),
       replayRouteProviders = List<String>.unmodifiable(replayRouteProviders),
       reasons = List<String>.unmodifiable(reasons);

  static const bool originalValidationReplaced = false;
  static const bool productiveValidationOwnerReplaced = false;
  static const bool productiveEvidenceOwnerReplaced = false;
  static const bool persistenceRecomputed = false;
  static const bool candidateValidationUsedForPersistence = false;
  static const bool candidateValidationUsedForPrompt = false;
  static const bool candidateValidationUsedForRendering = false;
  static const bool firestoreConnected = false;
  static const bool writeExecuted = false;
  static const bool writeEligible = false;
  static const bool cutoverReadinessGranted = false;
  static const bool cutoverAuthorized = false;
  static const bool persistenceOwnerReplaced = false;
  static const bool persistenceEligibilityPromoted = false;
  static const bool medicationMaterializationEnabled = false;

  final String requestId;
  final PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus status;
  final String originalValidationStatus;
  final String replayValidationStatus;
  final Map<String, Object?> originalProvenance;
  final Map<String, Object?> replayProvenance;
  final List<String> originalRouteProviders;
  final List<String> replayRouteProviders;
  final bool statusChanged;
  final bool provenanceChanged;
  final bool routeChanged;
  final List<String> reasons;
  final DateTime observedAt;

  bool get replayCompared =>
      status ==
      PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus
          .replayCompared;

  bool get anyDifference => statusChanged || provenanceChanged || routeChanged;
}

class PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowAdapter {
  const PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowAdapter();

  PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowSnapshot compare({
    required PlantaoRequest request,
    required bool overlayPrepared,
    required String originalValidationRequestId,
    required String originalValidationStatus,
    required Map<String, Object?> originalProvenance,
    required Iterable<String> originalRouteProviders,
    String? replayValidationRequestId,
    String? replayValidationStatus,
    Map<String, Object?>? replayProvenance,
    Iterable<String>? replayRouteProviders,
  }) {
    request.ensureValid();

    if (originalValidationRequestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status:
            PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus.stale,
        reasons: const <String>[
          'projected_evidence_validation_replay_original_request_id_mismatch',
        ],
      );
    }

    if (!overlayPrepared) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus
            .overlayNotPrepared,
        originalValidationStatus: originalValidationStatus,
        originalProvenance: originalProvenance,
        originalRouteProviders: originalRouteProviders,
        reasons: const <String>[
          'projected_evidence_validation_replay_overlay_not_prepared',
        ],
      );
    }

    if (replayValidationRequestId == null ||
        replayValidationStatus == null ||
        replayProvenance == null ||
        replayRouteProviders == null) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus
            .replayUnavailable,
        originalValidationStatus: originalValidationStatus,
        originalProvenance: originalProvenance,
        originalRouteProviders: originalRouteProviders,
        reasons: const <String>[
          'projected_evidence_validation_replay_unavailable',
        ],
      );
    }

    if (replayValidationRequestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status:
            PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus.stale,
        originalValidationStatus: originalValidationStatus,
        originalProvenance: originalProvenance,
        originalRouteProviders: originalRouteProviders,
        reasons: const <String>[
          'projected_evidence_validation_replay_request_id_mismatch',
        ],
      );
    }

    try {
      final frozenOriginalProvenance = _freezeMap(originalProvenance);
      final frozenReplayProvenance = _freezeMap(replayProvenance);
      final frozenOriginalRoute = List<String>.unmodifiable(
        originalRouteProviders,
      );
      final frozenReplayRoute = List<String>.unmodifiable(replayRouteProviders);

      final statusChanged = originalValidationStatus != replayValidationStatus;
      final provenanceChanged = !_deepEquals(
        frozenOriginalProvenance,
        frozenReplayProvenance,
      );
      final routeChanged = !_deepEquals(frozenOriginalRoute, frozenReplayRoute);

      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus
            .replayCompared,
        originalValidationStatus: originalValidationStatus,
        replayValidationStatus: replayValidationStatus,
        originalProvenance: frozenOriginalProvenance,
        replayProvenance: frozenReplayProvenance,
        originalRouteProviders: frozenOriginalRoute,
        replayRouteProviders: frozenReplayRoute,
        statusChanged: statusChanged,
        provenanceChanged: provenanceChanged,
        routeChanged: routeChanged,
        reasons: <String>{
          'canonical_drug_projected_evidence_validation_replay_compared',
          if (statusChanged)
            'projected_evidence_validation_status_changed'
          else
            'projected_evidence_validation_status_unchanged',
          if (provenanceChanged)
            'projected_evidence_validation_provenance_changed'
          else
            'projected_evidence_validation_provenance_unchanged',
          if (routeChanged)
            'projected_evidence_validation_route_changed'
          else
            'projected_evidence_validation_route_unchanged',
          'original_validation_preserved',
          'persistence_recomputation_not_authorized',
          'productive_cutover_not_authorized',
        },
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status:
            PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus.failed,
        originalValidationStatus: originalValidationStatus,
        originalProvenance: originalProvenance,
        originalRouteProviders: originalRouteProviders,
        reasons: <String>[
          'projected_evidence_validation_replay_failure:${error.runtimeType}',
        ],
      );
    }
  }

  static PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowSnapshot
  _snapshot({
    required String requestId,
    required PlantaoDrugProjectedEvidenceValidationReplayComparisonStatus
    status,
    String originalValidationStatus = '',
    String replayValidationStatus = '',
    Map<String, Object?> originalProvenance = const <String, Object?>{},
    Map<String, Object?> replayProvenance = const <String, Object?>{},
    Iterable<String> originalRouteProviders = const <String>[],
    Iterable<String> replayRouteProviders = const <String>[],
    bool statusChanged = false,
    bool provenanceChanged = false,
    bool routeChanged = false,
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugProjectedEvidenceValidationReplayComparisonShadowSnapshot(
      requestId: requestId,
      status: status,
      originalValidationStatus: originalValidationStatus,
      replayValidationStatus: replayValidationStatus,
      originalProvenance: originalProvenance,
      replayProvenance: replayProvenance,
      originalRouteProviders: originalRouteProviders,
      replayRouteProviders: replayRouteProviders,
      statusChanged: statusChanged,
      provenanceChanged: provenanceChanged,
      routeChanged: routeChanged,
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

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key)) return false;
      if (!_deepEquals(entry.value, right[entry.key])) return false;
    }
    return true;
  }
  if (left is Iterable && right is Iterable) {
    final leftValues = left.toList(growable: false);
    final rightValues = right.toList(growable: false);
    if (leftValues.length != rightValues.length) return false;
    for (var index = 0; index < leftValues.length; index += 1) {
      if (!_deepEquals(leftValues[index], rightValues[index])) return false;
    }
    return true;
  }
  return left == right;
}
