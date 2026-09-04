import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_retrieval_shadow_adapter.dart';

import 'package:medcases/data/protocols_database.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_evidence_bundle.dart';
void main() {
  PlantaoRequest request() => PlantaoRequest(
    requestId: 'req-3g',
    sessionId: 'session-3g',
    question: 'Conduta no IAM com supra',
    language: PlantaoLanguage.ptBr,
    trigger: PlantaoRequestTrigger.userInput,
    continuationType: PlantaoContinuationType.initial,
    requestedSections: const [],
    strictClinicalMode: true,
  );

  test('binds and deduplicates legacy protocol matches as typed evidence', () {
    const adapter = PlantaoRetrievalShadowAdapter();
    final snapshot = adapter.bindLegacyProtocolMatches(
      request: request(),
      matches: [
        PlantaoLegacyProtocolMatch(
          documentId: 'protocol:iam_congestao',
          version: 'legacy_protocols_database_v1',
          title: 'Síndrome Coronariana Aguda',
          recognize: 'Dor torácica e supra de ST',
          definition: 'Emergência cardiovascular',
          actions: const ['ECG em 10 minutos', 'Reperfusão'],
        ),
        PlantaoLegacyProtocolMatch(
          documentId: 'protocol:iam_congestao',
          version: 'legacy_protocols_database_v1',
          title: 'Duplicado',
          recognize: '',
          definition: '',
          actions: const [],
        ),
      ],
    );

    expect(snapshot.requestId, 'req-3g');
    expect(snapshot.evidenceBundle.retrievalStatus.name, 'partial');
    expect(snapshot.evidenceBundle.protocolDocuments, hasLength(1));
    expect(snapshot.evidenceBundle.coverage.hasProtocol, isTrue);
    expect(snapshot.evidenceBundle.coverage.hasDrug, isFalse);
    expect(snapshot.matchedProtocolDocumentIds, ['protocol:iam_congestao']);
    expect(
      snapshot.evidenceBundle.documentVersions['protocol:iam_congestao'],
      'legacy_protocols_database_v1',
    );
    expect(
      snapshot.evidenceBundle.protocolDocuments.single.excerpt,
      contains('ECG em 10 minutos'),
    );
    expect(snapshot.reasons, contains('drug_retrieval_not_connected'));
  });

  test('empty legacy retrieval remains explicit and fail-safe', () {
    const adapter = PlantaoRetrievalShadowAdapter();
    final snapshot = adapter.bindLegacyProtocolMatches(
      request: request(),
      matches: const [],
    );

    expect(snapshot.evidenceBundle.isEmpty, isTrue);
    expect(snapshot.evidenceBundle.retrievalStatus.name, 'empty');
    expect(
      snapshot.evidenceBundle.missingRequirements,
      contains('legacy_protocol_retrieval_empty'),
    );
    expect(PlantaoRetrievalShadowSnapshot.providerConnected, isFalse);
    expect(PlantaoRetrievalShadowSnapshot.firestoreConnected, isFalse);
    expect(PlantaoRetrievalShadowSnapshot.persistenceWriteEnabled, isFalse);
  });


  test('binds exact protocol identity into canonical rich evidence', () {
    final protocol = protocolsDatabase.first;
    final request = PlantaoRequest(
      requestId: 'req-protocol-binding',
      sessionId: 'session-protocol-binding',
      question: 'Dor torácica com hipotensão',
      language: PlantaoLanguage.ptBr,
      trigger: PlantaoRequestTrigger.userInput,
      continuationType: PlantaoContinuationType.initial,
      requestedSections: const [],
      patientContext: null,
      memoryContext: null,
      clientContext: null,
    );
    final adapter = const PlantaoRetrievalShadowAdapter();
    final snapshot = adapter.bindLegacyProtocolMatches(
      request: request,
      matches: <PlantaoLegacyProtocolMatch>[
        PlantaoLegacyProtocolMatch(
          documentId: 'protocol:${protocol.id}',
          version: 'legacy_protocols_database_v1',
          title: 'Protocol binding test',
          recognize: 'recognize',
          definition: 'definition',
          actions: const <String>['action'],
          metadata: <String, Object?>{
            'legacyProtocolId': protocol.id,
            'sourcePath': 'lib/data/protocols_database.dart',
            'retrievalOwner': 'AppProvider._matchProtocols',
          },
        ),
      ],
    );

    final evidence = snapshot.evidenceBundle;
    expect(evidence.requestId, request.requestId);
    expect(evidence.sessionIdHash, isNotEmpty);
    expect(evidence.sessionIdHash, isNot(request.sessionId));
    expect(evidence.locale, 'pt');
    expect(evidence.queryFingerprint, isNotEmpty);
    expect(evidence.protocolEvidence, hasLength(1));
    expect(evidence.protocolEvidence.single.sourceId, protocol.id);
    expect(evidence.protocolEvidence.single.documentId, protocol.id);
    expect(
      evidence.validationStatus,
      PlantaoEvidenceValidationStatus.validated,
    );
    expect(evidence.limitations, isEmpty);
    expect(evidence.createdAtEpochMs, greaterThan(0));
    expect(
      evidence.bundleHash,
      PlantaoEvidenceBundle.computeCanonicalBundleHash(
        locale: evidence.locale,
        queryFingerprint: evidence.queryFingerprint,
        protocolEvidence: evidence.protocolEvidence,
        drugEvidence: evidence.drugEvidence,
        validationStatus: evidence.validationStatus,
        limitations: evidence.limitations,
      ),
    );

    final rejected = adapter.bindLegacyProtocolMatches(
      request: request,
      matches: <PlantaoLegacyProtocolMatch>[
        PlantaoLegacyProtocolMatch(
          documentId: 'protocol:${protocol.id}',
          version: 'legacy_protocols_database_v1',
          title: 'Protocol mismatch test',
          recognize: 'recognize',
          definition: 'definition',
          actions: const <String>['action'],
          metadata: const <String, Object?>{
            'legacyProtocolId': 'different-protocol-id',
          },
        ),
      ],
    ).evidenceBundle;

    expect(rejected.protocolEvidence, isEmpty);
    expect(
      rejected.validationStatus,
      PlantaoEvidenceValidationStatus.rejected,
    );
    expect(rejected.limitations, contains('protocol_identity_mismatch'));
  });
}
