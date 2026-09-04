import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_evidence_bundle.dart';

void main() {
  test('canonical hash is deterministic across ordering and whitespace', () {
    const first = PlantaoEvidenceItem(
      kind: ' protocol ',
      sourceId: 'guideline-1',
      sourceVersion: '2026',
      documentId: 'doc-a',
      contentHash: 'abc',
      boundedExcerpt: '  invasive   strategy ',
      clinicalFacts: <String>['fact B', 'fact A'],
      retrievalScore: 0.91,
      validated: true,
    );
    const second = PlantaoEvidenceItem(
      kind: 'drug',
      sourceId: 'calculator',
      sourceVersion: 'main',
      documentId: 'aas',
      contentHash: 'def',
      boundedExcerpt: 'AAS',
      exactIdentity: true,
      validated: true,
    );

    final hashA = PlantaoEvidenceBundle.computeCanonicalBundleHash(
      locale: 'pt',
      queryFingerprint: 'iam sem supra',
      protocolEvidence: const <PlantaoEvidenceItem>[first],
      drugEvidence: const <PlantaoEvidenceItem>[second],
      validationStatus: PlantaoEvidenceValidationStatus.validated,
      limitations: const <String>['missing GRACE', 'renal pending'],
    );
    final hashB = PlantaoEvidenceBundle.computeCanonicalBundleHash(
      locale: ' pt ',
      queryFingerprint: 'iam   sem supra',
      protocolEvidence: const <PlantaoEvidenceItem>[first],
      drugEvidence: const <PlantaoEvidenceItem>[second],
      validationStatus: PlantaoEvidenceValidationStatus.validated,
      limitations: const <String>['renal pending', 'missing GRACE'],
    );

    expect(hashA, hashB);
    expect(hashA, hasLength(8));
  });

  test('protocol and drug evidence remain separate in the hash', () {
    const item = PlantaoEvidenceItem(
      kind: 'drug',
      sourceId: 'calculator',
      sourceVersion: 'main',
      documentId: 'aas',
      contentHash: 'abc',
      boundedExcerpt: 'AAS',
      exactIdentity: true,
      validated: true,
    );

    final protocolHash = PlantaoEvidenceBundle.computeCanonicalBundleHash(
      locale: 'pt',
      queryFingerprint: 'query',
      protocolEvidence: const <PlantaoEvidenceItem>[item],
    );
    final drugHash = PlantaoEvidenceBundle.computeCanonicalBundleHash(
      locale: 'pt',
      queryFingerprint: 'query',
      drugEvidence: const <PlantaoEvidenceItem>[item],
    );

    expect(protocolHash, isNot(drugHash));
  });

  test('validation status changes the bundle identity', () {
    final unavailable = PlantaoEvidenceBundle.computeCanonicalBundleHash(
      locale: 'pt',
      queryFingerprint: 'query',
    );
    final validated = PlantaoEvidenceBundle.computeCanonicalBundleHash(
      locale: 'pt',
      queryFingerprint: 'query',
      validationStatus: PlantaoEvidenceValidationStatus.validated,
    );

    expect(unavailable, isNot(validated));
  });

  // BEGIN PHASE3I TARGETED CANONICAL BUNDLE TEST
  group('PlantaoEvidenceBundle direct canonical bindings', () {
    test('binds canonical identity, hash, and separated evidence', () {
      const requestIdValue = 'phase3i-request-id';
      const sessionIdHashValue = 'phase3i-session-hash';
      const localeValue = 'pt-BR';
      const queryFingerprintValue = 'phase3i-query-fingerprint';
      const createdAtEpochMsValue = 1700000000000;
      const validationStatusValue = PlantaoEvidenceValidationStatus.unavailable;
      final protocolItem = PlantaoEvidenceItem(
              kind: 'protocol_kind',
              sourceId: 'protocol_sourceId',
              sourceVersion: 'protocol_sourceVersion',
              documentId: 'protocol_documentId',
              contentHash: 'protocol_contentHash',
              boundedExcerpt: 'protocol_boundedExcerpt',
            );
      final protocolEvidenceValue = <PlantaoEvidenceItem>[protocolItem];
      final drugEvidenceValue = <PlantaoEvidenceItem>[];
      const limitationsValue = <String>['phase3i-test-only'];
      final expectedBundleHash = PlantaoEvidenceBundle.computeCanonicalBundleHash(
              locale: localeValue,
              queryFingerprint: queryFingerprintValue,
              protocolEvidence: protocolEvidenceValue,
              drugEvidence: drugEvidenceValue,
              validationStatus: validationStatusValue,
              limitations: limitationsValue,
            );
      final repeatedBundleHash = PlantaoEvidenceBundle.computeCanonicalBundleHash(
              locale: localeValue,
              queryFingerprint: queryFingerprintValue,
              protocolEvidence: protocolEvidenceValue,
              drugEvidence: drugEvidenceValue,
              validationStatus: validationStatusValue,
              limitations: limitationsValue,
            );
      final changedBundleHash = PlantaoEvidenceBundle.computeCanonicalBundleHash(
              locale: localeValue,
              queryFingerprint: 'phase3i-query-fingerprint-altered',
              protocolEvidence: protocolEvidenceValue,
              drugEvidence: drugEvidenceValue,
              validationStatus: validationStatusValue,
              limitations: limitationsValue,
            );
      final clinicalDocumentsValue = const <PlantaoEvidenceDocument>[];
      final drugDocumentsValue = const <PlantaoDrugEvidenceDocument>[];
      final protocolDocumentsValue = const <PlantaoEvidenceDocument>[];
      final patientFactsValue = const <PlantaoEvidenceDocument>[];
      final caseEvidenceValue = const <PlantaoEvidenceDocument>[];
      final externalGroundingValue = const <PlantaoEvidenceDocument>[];
      final documentVersionsValue = const <String, String>{};
      final coverageValue = const PlantaoEvidenceCoverage(hasClinical: false, hasDrug: false, hasProtocol: false, hasPatientFacts: false);
      final missingRequirementsValue = const <String>[];
      final retrievalStatusValue = PlantaoRetrievalStatus.complete;
      final bundle = PlantaoEvidenceBundle(
              clinicalDocuments: clinicalDocumentsValue,
              drugDocuments: drugDocumentsValue,
              protocolDocuments: protocolDocumentsValue,
              patientFacts: patientFactsValue,
              caseEvidence: caseEvidenceValue,
              externalGrounding: externalGroundingValue,
              documentVersions: documentVersionsValue,
              coverage: coverageValue,
              missingRequirements: missingRequirementsValue,
              retrievalStatus: retrievalStatusValue,
              requestId: requestIdValue,
              sessionIdHash: sessionIdHashValue,
              locale: localeValue,
              queryFingerprint: queryFingerprintValue,
              protocolEvidence: protocolEvidenceValue,
              drugEvidence: drugEvidenceValue,
              validationStatus: validationStatusValue,
              bundleHash: expectedBundleHash,
              createdAtEpochMs: createdAtEpochMsValue,
              limitations: limitationsValue,
            );
      final legacyCompatibleBundle = PlantaoEvidenceBundle(
              clinicalDocuments: clinicalDocumentsValue,
              drugDocuments: drugDocumentsValue,
              protocolDocuments: protocolDocumentsValue,
              patientFacts: patientFactsValue,
              caseEvidence: caseEvidenceValue,
              externalGrounding: externalGroundingValue,
              documentVersions: documentVersionsValue,
              coverage: coverageValue,
              missingRequirements: missingRequirementsValue,
              retrievalStatus: retrievalStatusValue,
            );

      expect(bundle.requestId, requestIdValue);
      expect(bundle.bundleHash, expectedBundleHash);
      expect(bundle.bundleHash, isNotEmpty);
      expect(repeatedBundleHash, expectedBundleHash);
      expect(changedBundleHash, isNot(expectedBundleHash));
      expect(bundle.protocolEvidence, hasLength(1));
      expect(bundle.protocolEvidence.first, same(protocolItem));
      expect(bundle.drugEvidence, isEmpty);
      expect(legacyCompatibleBundle, isA<PlantaoEvidenceBundle>());
    });
  });
  // END PHASE3I TARGETED CANONICAL BUNDLE TEST
}
