import '../contracts/plantao_canonical_drug_evidence.dart';
import '../ports/plantao_drug_evidence_port.dart';
import 'plantao_drug_candidate_resolver.dart';
import 'plantao_drug_original_input_identity_extractor.dart';

enum PlantaoDrugEvidenceShadowStatus {
  notEvaluated,
  complete,
  partial,
  empty,
  ambiguous,
  failed,
}

class PlantaoDrugEvidenceShadowSnapshot {
  PlantaoDrugEvidenceShadowSnapshot({
    required this.status,
    required this.manifest,
    required Iterable<PlantaoCanonicalDrugCandidate> candidates,
    required Iterable<PlantaoCanonicalDrugEvidenceDocument> documents,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : candidates = List<PlantaoCanonicalDrugCandidate>.unmodifiable(
         candidates,
       ),
       documents = List<PlantaoCanonicalDrugEvidenceDocument>.unmodifiable(
         documents,
       ),
       reasons = List<String>.unmodifiable(reasons);

  static const bool productiveExecutionEnabled = false;
  static const bool providerConnected = false;
  static const bool promptMutationEnabled = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;
  static const bool appProviderConnected = false;
  static const bool medicationMaterializationEnabled = false;

  final PlantaoDrugEvidenceShadowStatus status;
  final PlantaoDrugEvidenceManifest? manifest;
  final List<PlantaoCanonicalDrugCandidate> candidates;
  final List<PlantaoCanonicalDrugEvidenceDocument> documents;
  final List<String> reasons;
  final DateTime observedAt;

  bool get hasCanonicalEvidence => documents.isNotEmpty;
}

class PlantaoDrugEvidenceShadowAdapter {
  const PlantaoDrugEvidenceShadowAdapter({
    required this.port,
    this.resolver = const PlantaoDrugCandidateResolver(),
    this.originalInputExtractor =
        const PlantaoDrugOriginalInputIdentityExtractor(),
    this.maximumTerms = 8,
  });

  final PlantaoDrugEvidencePort port;
  final PlantaoDrugCandidateResolver resolver;
  final PlantaoDrugOriginalInputIdentityExtractor originalInputExtractor;
  final int maximumTerms;

  Future<PlantaoDrugEvidenceShadowSnapshot> retrieveOriginalUserInput({
    required String originalUserInput,
    required String languageCode,
    required PlantaoDrugOriginalInputIntent intent,
  }) async {
    if (intent == PlantaoDrugOriginalInputIntent.none) {
      return PlantaoDrugEvidenceShadowSnapshot(
        status: PlantaoDrugEvidenceShadowStatus.notEvaluated,
        manifest: null,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        documents: const <PlantaoCanonicalDrugEvidenceDocument>[],
        reasons: const <String>['explicit_pharmacology_intent_absent'],
        observedAt: DateTime.now().toUtc(),
      );
    }

    try {
      final manifest = await port.loadManifest();
      final index = await port.loadIndex(manifest);
      final extraction = originalInputExtractor.extract(
        originalUserInput: originalUserInput,
        languageCode: languageCode,
        intent: intent,
        entries: index,
        maximumCandidates: maximumTerms,
      );

      if (!extraction.isMatched) {
        return PlantaoDrugEvidenceShadowSnapshot(
          status: switch (extraction.status) {
            PlantaoDrugOriginalInputExtractionStatus.notEvaluated =>
              PlantaoDrugEvidenceShadowStatus.notEvaluated,
            PlantaoDrugOriginalInputExtractionStatus.empty =>
              PlantaoDrugEvidenceShadowStatus.empty,
            PlantaoDrugOriginalInputExtractionStatus.ambiguous =>
              PlantaoDrugEvidenceShadowStatus.ambiguous,
            PlantaoDrugOriginalInputExtractionStatus.invalidInput =>
              PlantaoDrugEvidenceShadowStatus.failed,
            PlantaoDrugOriginalInputExtractionStatus.matched =>
              PlantaoDrugEvidenceShadowStatus.failed,
          },
          manifest: manifest,
          candidates: extraction.candidates,
          documents: const <PlantaoCanonicalDrugEvidenceDocument>[],
          reasons: extraction.reasons,
          observedAt: DateTime.now().toUtc(),
        );
      }

      final typedSnapshot = await retrieveTypedTerms(
        terms: extraction.candidates.map((candidate) => candidate.documentId),
        languageCode: languageCode,
      );
      return PlantaoDrugEvidenceShadowSnapshot(
        status: typedSnapshot.status,
        manifest: typedSnapshot.manifest,
        candidates: extraction.candidates,
        documents: typedSnapshot.documents,
        reasons: <String>{...extraction.reasons, ...typedSnapshot.reasons},
        observedAt: typedSnapshot.observedAt,
      );
    } catch (error) {
      return PlantaoDrugEvidenceShadowSnapshot(
        status: PlantaoDrugEvidenceShadowStatus.failed,
        manifest: null,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        documents: const <PlantaoCanonicalDrugEvidenceDocument>[],
        reasons: <String>[
          'original_input_drug_identity_failure:${error.runtimeType}',
        ],
        observedAt: DateTime.now().toUtc(),
      );
    }
  }

  Future<PlantaoDrugEvidenceShadowSnapshot> retrieveTypedTerms({
    required Iterable<String> terms,
    required String languageCode,
  }) async {
    final normalizedTerms = <String>[];
    for (final term in terms) {
      final normalized = PlantaoDrugCandidateResolver.normalize(term);
      if (normalized.isNotEmpty && !normalizedTerms.contains(normalized)) {
        normalizedTerms.add(normalized);
      }
    }

    if (normalizedTerms.isEmpty) {
      return PlantaoDrugEvidenceShadowSnapshot(
        status: PlantaoDrugEvidenceShadowStatus.notEvaluated,
        manifest: null,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        documents: const <PlantaoCanonicalDrugEvidenceDocument>[],
        reasons: const <String>['typed_drug_identity_terms_absent'],
        observedAt: DateTime.now().toUtc(),
      );
    }
    if (normalizedTerms.length > maximumTerms) {
      return PlantaoDrugEvidenceShadowSnapshot(
        status: PlantaoDrugEvidenceShadowStatus.failed,
        manifest: null,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        documents: const <PlantaoCanonicalDrugEvidenceDocument>[],
        reasons: <String>[
          'typed_drug_identity_term_limit_exceeded:${normalizedTerms.length}',
        ],
        observedAt: DateTime.now().toUtc(),
      );
    }

    try {
      final manifest = await port.loadManifest();
      final index = await port.loadIndex(manifest);
      final candidates = <String, PlantaoCanonicalDrugCandidate>{};
      final reasons = <String>[];
      var ambiguous = false;

      for (final term in normalizedTerms) {
        final resolution = resolver.resolve(
          term: term,
          languageCode: languageCode,
          entries: index,
        );
        reasons.addAll(resolution.reasons);
        if (resolution.status ==
            PlantaoDrugCandidateResolutionStatus.ambiguous) {
          ambiguous = true;
        }
        if (resolution.hasSingleMatch) {
          final candidate = resolution.candidates.single;
          candidates.putIfAbsent(candidate.documentId, () => candidate);
        }
      }

      final documents = <PlantaoCanonicalDrugEvidenceDocument>[];
      for (final candidate in candidates.values) {
        final document = await port.loadDocument(
          documentId: candidate.documentId,
          manifest: manifest,
        );
        documents.add(document);
        if (!document.supportsMedicationMaterialization) {
          reasons.add(
            'typed_regimen_unavailable:${document.documentId}:'
            '${document.completeness.name}',
          );
        }
      }

      final hasResolutionFailures = reasons.any(
        (reason) =>
            reason.startsWith('drug_identity_not_found') ||
            reason.startsWith('ambiguous_'),
      );
      final status = documents.isNotEmpty
          ? hasResolutionFailures
                ? PlantaoDrugEvidenceShadowStatus.partial
                : PlantaoDrugEvidenceShadowStatus.complete
          : ambiguous
          ? PlantaoDrugEvidenceShadowStatus.ambiguous
          : PlantaoDrugEvidenceShadowStatus.empty;

      return PlantaoDrugEvidenceShadowSnapshot(
        status: status,
        manifest: manifest,
        candidates: candidates.values,
        documents: documents,
        reasons: reasons,
        observedAt: DateTime.now().toUtc(),
      );
    } catch (error) {
      return PlantaoDrugEvidenceShadowSnapshot(
        status: PlantaoDrugEvidenceShadowStatus.failed,
        manifest: null,
        candidates: const <PlantaoCanonicalDrugCandidate>[],
        documents: const <PlantaoCanonicalDrugEvidenceDocument>[],
        reasons: <String>[
          'canonical_drug_evidence_failure:${error.runtimeType}',
        ],
        observedAt: DateTime.now().toUtc(),
      );
    }
  }
}
