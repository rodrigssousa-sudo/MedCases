import '../contracts/plantao_persistence_record.dart';
import '../contracts/plantao_request.dart';
import '../contracts/plantao_response_structure.dart';
import '../contracts/plantao_drug_relation.dart';
import 'plantao_finalization_shadow_snapshot.dart';
import 'plantao_validation_shadow_adapter.dart';

class PlantaoPersistenceShadowSnapshot {
  PlantaoPersistenceShadowSnapshot({
    required this.record,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : reasons = List<String>.unmodifiable(reasons);

  static const bool writeAttempted = false;
  static const bool persistencePortConnected = false;
  static const bool firestoreConnected = false;
  static const bool productiveHistoryConnected = false;
  static const bool renderingEnabled = false;

  final PlantaoPersistenceRecord record;
  final List<String> reasons;
  final DateTime observedAt;

  bool get futurePersistenceEligible => record.futurePersistenceEligible;
}

class PlantaoPersistenceShadowAdapter {
  const PlantaoPersistenceShadowAdapter();

  PlantaoPersistenceShadowSnapshot observe({
    required PlantaoRequest request,
    required PlantaoFinalizationShadowSnapshot finalization,
    required PlantaoValidationShadowSnapshot validation,
  }) {
    request.ensureValid();

    final reasons = <String>[
      ...validation.reasons,
      'shadow_write_not_attempted',
      'productive_history_isolated',
    ];

    final finalizationReady =
        finalization.isReady && finalization.sanitizedText.trim().isNotEmpty;
    final validationAcceptable =
        validation.status == PlantaoValidationShadowStatus.validated ||
            (validation.status == PlantaoValidationShadowStatus.notEvaluated &&
                finalization.deferredMedicationCount == 0);
    final futurePersistenceEligible = finalizationReady &&
        validation.strictModeCompatible &&
        validationAcceptable &&
        finalization.missingRequestedSections.isEmpty;

    if (!finalizationReady) reasons.add('finalization_not_ready');
    if (!validation.strictModeCompatible) {
      reasons.add('strict_mode_incompatible');
    }
    if (!validationAcceptable) reasons.add('validation_not_acceptable');
    if (finalization.missingRequestedSections.isNotEmpty) {
      reasons.add('requested_sections_incomplete');
    }

    final status = _status(
      finalization: finalization,
      futurePersistenceEligible: futurePersistenceEligible,
    );
    final structure = _mergeStructure(
      finalization.structure,
      validation.medications,
    );
    final record = PlantaoPersistenceRecord(
      recordId: 'plantao-shadow-${request.requestId}',
      requestId: request.requestId,
      sessionId: request.sessionId,
      language: request.language,
      trigger: request.trigger,
      continuationType: request.continuationType,
      requestedSections: request.requestedSections,
      status: status,
      finalizationStatus: finalization.status.name,
      validationStatus: validation.status.name,
      sanitizedText: finalization.sanitizedText,
      structure: structure,
      provenance: validation.provenance,
      reasons: reasons,
      strictModeCompatible: validation.strictModeCompatible,
      futurePersistenceEligible: futurePersistenceEligible,
      observedAt: DateTime.now().toUtc(),
    );
    record.ensureValid();

    return PlantaoPersistenceShadowSnapshot(
      record: record,
      reasons: reasons,
      observedAt: record.observedAt,
    );
  }

  static PlantaoPersistenceRecordStatus _status({
    required PlantaoFinalizationShadowSnapshot finalization,
    required bool futurePersistenceEligible,
  }) {
    if (futurePersistenceEligible) {
      return PlantaoPersistenceRecordStatus.prepared;
    }
    if (finalization.status == PlantaoFinalizationShadowStatus.failed) {
      return PlantaoPersistenceRecordStatus.failed;
    }
    if (finalization.status == PlantaoFinalizationShadowStatus.rejected ||
        finalization.status ==
            PlantaoFinalizationShadowStatus.repairUnavailable) {
      return PlantaoPersistenceRecordStatus.unavailable;
    }
    return PlantaoPersistenceRecordStatus.blocked;
  }

  static PlantaoResponseStructure? _mergeStructure(
    PlantaoResponseStructure? structure,
    List<PlantaoMedicationItem> medications,
  ) {
    if (structure == null && medications.isEmpty) return null;
    return PlantaoResponseStructure(
      sections: structure?.sections ?? const <PlantaoResponseSection>[],
      medications: medications,
    );
  }
}
