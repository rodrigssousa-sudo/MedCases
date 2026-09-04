import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_finalization_shadow_snapshot.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_persistence_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_retrieval_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_validation_shadow_adapter.dart';

void main() {
  test('bound protocol provenance survives persistence preparation', () {
    final request = PlantaoRequest(
      requestId: 'req-retrieval-persistence',
      sessionId: 'session-retrieval-persistence',
      question: 'Conduta na sepse',
      language: PlantaoLanguage.ptBr,
      trigger: PlantaoRequestTrigger.userInput,
      continuationType: PlantaoContinuationType.initial,
      requestedSections: const [],
      strictClinicalMode: true,
    );
    final finalization = PlantaoFinalizationShadowSnapshot(
      requestId: request.requestId,
      status: PlantaoFinalizationShadowStatus.structured,
      rawText: 'Resposta observada',
      sanitizedText: 'Resposta observada',
      canonicalStatus: 'ready',
      usedBackendStructuredOutput: false,
      usedLocalClinicalAdapter: true,
      usedPlantaoParser: true,
      deferredMedicationCount: 0,
      missingRequestedSections: const [],
      observedAt: DateTime.utc(2026, 7, 27),
    );
    const retrievalAdapter = PlantaoRetrievalShadowAdapter();
    final retrieval = retrievalAdapter.bindLegacyProtocolMatches(
      request: request,
      matches: [
        PlantaoLegacyProtocolMatch(
          documentId: 'protocol:sepse',
          version: 'legacy_protocols_database_v1',
          title: 'Sepse',
          recognize: 'Disfunção orgânica por infecção',
          definition: 'Emergência clínica',
          actions: const ['Lactato', 'Antibiótico precoce'],
        ),
      ],
    );
    const validationAdapter = PlantaoValidationShadowAdapter();
    final validation = validationAdapter.validate(
      request: request,
      finalization: finalization,
      evidenceBundle: retrieval.evidenceBundle,
    );
    const persistenceAdapter = PlantaoPersistenceShadowAdapter();
    final persistence = persistenceAdapter.observe(
      request: request,
      finalization: finalization,
      validation: validation,
    );
    final json = persistence.record.toJson();
    final provenance = json['provenance']! as Map<String, Object?>;

    expect(provenance['matchedClinicalDocumentIds'], ['protocol:sepse']);
    expect(
      (provenance['documentVersions']!
          as Map<String, Object?>)['protocol:sepse'],
      'legacy_protocols_database_v1',
    );
    expect(PlantaoPersistenceShadowSnapshot.writeAttempted, isFalse);
    expect(
      PlantaoPersistenceShadowSnapshot.productiveHistoryConnected,
      isFalse,
    );
  });
}
