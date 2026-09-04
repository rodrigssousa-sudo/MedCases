import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_drug_relation.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_persistence_record.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_provenance.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_structure.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/ai_pipeline/plantao/ports/plantao_provider_port.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_finalization_shadow_snapshot.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_persistence_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_validation_shadow_adapter.dart';

PlantaoRequest request() => PlantaoRequest(
      requestId: 'req-persist',
      sessionId: 'session-persist',
      question: 'Conduta clínica',
      language: PlantaoLanguage.ptBr,
      trigger: PlantaoRequestTrigger.userInput,
      continuationType: PlantaoContinuationType.initial,
      requestedSections: const <PlantaoSection>[],
    );

PlantaoFinalizationShadowSnapshot finalization({int deferred = 0}) {
  return PlantaoFinalizationShadowSnapshot(
    requestId: 'req-persist',
    status: PlantaoFinalizationShadowStatus.structured,
    rawText: 'texto bruto',
    sanitizedText: 'texto sanitizado',
    canonicalStatus: 'ready',
    structure: PlantaoResponseStructure(
      sections: const <PlantaoResponseSection>[
        PlantaoResponseSection(
          section: PlantaoSection.summary,
          content: 'Resumo',
        ),
      ],
      medications: const [],
    ),
    usedBackendStructuredOutput: true,
    usedLocalClinicalAdapter: false,
    usedPlantaoParser: true,
    deferredMedicationCount: deferred,
    missingRequestedSections: const <String>[],
    observedAt: DateTime.utc(2026, 7, 26),
  );
}

PlantaoValidationShadowSnapshot validation({
  PlantaoValidationShadowStatus status =
      PlantaoValidationShadowStatus.notEvaluated,
  bool compatible = true,
  List<PlantaoMedicationItem> medications = const <PlantaoMedicationItem>[],
}) {
  return PlantaoValidationShadowSnapshot(
    requestId: 'req-persist',
    status: status,
    routePlan: PlantaoProviderRoutePlan.currentPlantaoPaidFirst(),
    provenance: PlantaoProvenance(
      provider: 'shadow_route_plan_not_executed',
      model: 'unexecuted',
      sourceMode: compatible
          ? PlantaoSourceMode.localRag
          : PlantaoSourceMode.modelNative,
      matchedClinicalDocumentIds: const <String>[],
      matchedDrugDocumentIds: medications
          .map((PlantaoMedicationItem item) => item.drugDocumentId),
      validatedDose: medications.isNotEmpty,
      validatorReason: compatible ? 'compatible' : 'incompatible',
      usedExternalGrounding: false,
      continuationType: PlantaoContinuationType.initial,
      documentVersions: const <String, String>{},
    ),
    medications: medications,
    reasons: const <String>[],
    strictModeCompatible: compatible,
    observedAt: DateTime.utc(2026, 7, 26),
  );
}

void main() {
  test('non-pharmacologic finalized output prepares a shadow record', () {
    const adapter = PlantaoPersistenceShadowAdapter();
    final snapshot = adapter.observe(
      request: request(),
      finalization: finalization(),
      validation: validation(),
    );

    expect(snapshot.record.status, PlantaoPersistenceRecordStatus.prepared);
    expect(snapshot.futurePersistenceEligible, isTrue);
    expect(snapshot.record.sanitizedText, 'texto sanitizado');
    expect(PlantaoPersistenceShadowSnapshot.writeAttempted, isFalse);
  });

  test('incomplete pharmacology remains blocked and never written', () {
    const adapter = PlantaoPersistenceShadowAdapter();
    final snapshot = adapter.observe(
      request: request(),
      finalization: finalization(deferred: 1),
      validation: validation(
        status: PlantaoValidationShadowStatus.incompleteEvidence,
        compatible: false,
      ),
    );

    expect(snapshot.record.status, PlantaoPersistenceRecordStatus.blocked);
    expect(snapshot.futurePersistenceEligible, isFalse);
    expect(snapshot.reasons, contains('validation_not_acceptable'));
    expect(snapshot.reasons, contains('shadow_write_not_attempted'));
  });

  test('validated medication is merged only from typed validation output', () {
    const medication = PlantaoMedicationItem(
      drugName: 'AAS',
      relation: PlantaoDrugRelationType.concomitant,
      indication: 'SCA',
      dose: 300,
      unit: 'mg',
      route: 'VO',
      frequency: 'dose de ataque',
      drugDocumentId: 'drug-aas-v1',
      evidenceVersion: '1.0.0',
      validationStatus: PlantaoDrugValidationStatus.validated,
    );
    const adapter = PlantaoPersistenceShadowAdapter();
    final snapshot = adapter.observe(
      request: request(),
      finalization: finalization(deferred: 1),
      validation: validation(
        status: PlantaoValidationShadowStatus.validated,
        medications: const <PlantaoMedicationItem>[medication],
      ),
    );

    expect(snapshot.futurePersistenceEligible, isTrue);
    expect(snapshot.record.structure?.medications, [medication]);
  });
}
