import '../contracts/plantao_evidence_bundle.dart';
import '../contracts/plantao_request.dart';
import 'plantao_drug_evidence_finalization_join_shadow_adapter.dart';
import 'plantao_drug_typed_regimen_capability_matrix_shadow_adapter.dart';

enum PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus {
  projectionRecorded,
  capabilityMatrixNotRecorded,
  joinNotReady,
  stale,
  matrixMismatch,
  failed,
}

class PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowSnapshot {
  PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowSnapshot({
    required this.requestId,
    required this.status,
    required Iterable<PlantaoDrugEvidenceDocument> projectedDocuments,
    required Iterable<String> unavailableDocumentIds,
    required Iterable<String> rejectedEntries,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : projectedDocuments = List<PlantaoDrugEvidenceDocument>.unmodifiable(
         projectedDocuments,
       ),
       unavailableDocumentIds = List<String>.unmodifiable(
         unavailableDocumentIds,
       ),
       rejectedEntries = List<String>.unmodifiable(rejectedEntries),
       reasons = List<String>.unmodifiable(reasons);

  static const bool freeTextDoseExtractionEnabled = false;
  static const bool freeTextRouteExtractionEnabled = false;
  static const bool freeTextFrequencyExtractionEnabled = false;
  static const bool inferredTypedRegimenEnabled = false;
  static const bool validationConnected = false;
  static const bool evidenceBundleMutationEnabled = false;
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
  final PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus status;
  final List<PlantaoDrugEvidenceDocument> projectedDocuments;
  final List<String> unavailableDocumentIds;
  final List<String> rejectedEntries;
  final List<String> reasons;
  final DateTime observedAt;

  bool get projectionRecorded =>
      status ==
      PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
          .projectionRecorded;

  int get projectedRegimenCount => projectedDocuments.length;

  Set<String> get projectedCanonicalDocumentIds => Set<String>.unmodifiable(
    projectedDocuments.map((document) => document.documentId),
  );
}

class PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowAdapter {
  const PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowAdapter();

  PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowSnapshot project({
    required PlantaoRequest request,
    required PlantaoDrugEvidenceFinalizationJoinShadowSnapshot join,
    required PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot
    capabilityMatrix,
  }) {
    request.ensureValid();

    if (join.requestId != request.requestId ||
        capabilityMatrix.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus.stale,
        reasons: const <String>[
          'explicit_typed_regimen_projection_request_id_mismatch',
        ],
      );
    }

    if (!capabilityMatrix.capabilityMatrixRecorded) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
            .capabilityMatrixNotRecorded,
        reasons: <String>{
          'explicit_typed_regimen_projection_matrix_not_recorded',
          ...capabilityMatrix.reasons,
        },
      );
    }

    if (join.status != PlantaoDrugEvidenceFinalizationJoinStatus.ready ||
        join.drugEvidence == null ||
        join.evidenceDocumentIds.isEmpty) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
            .joinNotReady,
        reasons: <String>{
          'explicit_typed_regimen_projection_join_not_ready',
          ...join.reasons,
        },
      );
    }

    try {
      final documents = join.drugEvidence!.evidence.documents;
      final matrixById = <String, PlantaoDrugTypedRegimenCapabilityEntry>{
        for (final entry in capabilityMatrix.entries) entry.documentId: entry,
      };
      final documentIds = documents
          .map((document) => document.documentId)
          .toSet();

      if (!_setEquals(documentIds, matrixById.keys.toSet())) {
        return _snapshot(
          requestId: request.requestId,
          status: PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
              .matrixMismatch,
          reasons: const <String>[
            'explicit_typed_regimen_projection_matrix_document_mismatch',
          ],
        );
      }

      final projected = <PlantaoDrugEvidenceDocument>[];
      final unavailable = <String>[];
      final rejected = <String>[];

      for (final document in documents) {
        final matrixEntry = matrixById[document.documentId]!;
        if (matrixEntry.supportsMedicationMaterialization !=
                document.supportsMedicationMaterialization ||
            matrixEntry.boundAsTypedRegimen !=
                document.supportsMedicationMaterialization) {
          return _snapshot(
            requestId: request.requestId,
            status: PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
                .matrixMismatch,
            reasons: <String>[
              'explicit_typed_regimen_projection_capability_mismatch:'
                  '${document.documentId}',
            ],
          );
        }

        if (!document.supportsMedicationMaterialization) {
          unavailable.add(document.documentId);
          continue;
        }

        final rawRegimens = document.raw['aiRegimens'];
        if (rawRegimens is! List<Object?> || rawRegimens.isEmpty) {
          rejected.add('${document.documentId}:typed_regimen_payload_missing');
          continue;
        }

        for (var index = 0; index < rawRegimens.length; index++) {
          final rawRegimen = rawRegimens[index];
          if (rawRegimen is! Map<Object?, Object?>) {
            rejected.add(
              '${document.documentId}:$index:typed_regimen_not_object',
            );
            continue;
          }

          final dose = rawRegimen['dose'];
          final unit = _requiredString(rawRegimen['unit']);
          final route = _requiredString(rawRegimen['route']);
          final frequency = _requiredString(rawRegimen['frequency']);

          if (dose is! num ||
              unit == null ||
              route == null ||
              frequency == null) {
            rejected.add(
              '${document.documentId}:$index:invalid_explicit_typed_regimen',
            );
            continue;
          }

          final version =
              join.documentVersions[document.documentId] ??
              matrixEntry.documentVersion;
          if (version.trim().isEmpty) {
            rejected.add(
              '${document.documentId}:$index:document_version_absent',
            );
            continue;
          }

          projected.add(
            PlantaoDrugEvidenceDocument(
              documentId: document.documentId,
              version: version,
              excerpt: 'explicit_ai_regimen',
              drugName:
                  document.names['pt'] ??
                  document.names['es'] ??
                  document.documentId,
              dose: dose,
              unit: unit,
              route: route,
              frequency: frequency,
              metadata: <String, Object?>{
                'canonicalSource': document.source,
                'sourceModule': document.sourceModule,
                'regimenSource': 'aiRegimens',
                'regimenIndex': index,
              },
            ),
          );
        }
      }

      unavailable.sort();
      rejected.sort();

      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
            .projectionRecorded,
        projectedDocuments: projected,
        unavailableDocumentIds: unavailable,
        rejectedEntries: rejected,
        reasons: <String>{
          'canonical_drug_explicit_typed_regimen_projection_recorded',
          if (projected.isEmpty)
            'explicit_typed_regimen_projection_empty'
          else
            'explicit_typed_regimen_projection_available',
          if (unavailable.isNotEmpty) 'typed_regimen_contract_unavailable',
          if (rejected.isNotEmpty) 'invalid_explicit_typed_regimen_rejected',
          'free_text_regimen_inference_not_authorized',
          'validation_connection_not_authorized',
          'persistence_write_not_authorized',
        },
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus.failed,
        reasons: <String>[
          'explicit_typed_regimen_projection_failure:${error.runtimeType}',
        ],
      );
    }
  }

  static PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowSnapshot
  _snapshot({
    required String requestId,
    required PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus status,
    Iterable<PlantaoDrugEvidenceDocument> projectedDocuments =
        const <PlantaoDrugEvidenceDocument>[],
    Iterable<String> unavailableDocumentIds = const <String>[],
    Iterable<String> rejectedEntries = const <String>[],
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowSnapshot(
      requestId: requestId,
      status: status,
      projectedDocuments: projectedDocuments,
      unavailableDocumentIds: unavailableDocumentIds,
      rejectedEntries: rejectedEntries,
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }
}

String? _requiredString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

bool _setEquals(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}
