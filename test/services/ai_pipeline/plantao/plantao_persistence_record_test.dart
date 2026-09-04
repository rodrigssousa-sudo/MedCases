import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_persistence_record.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_provenance.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_structure.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';

PlantaoPersistenceRecord record() => PlantaoPersistenceRecord(
      recordId: 'plantao-shadow-req-1',
      requestId: 'req-1',
      sessionId: 'session-1',
      language: PlantaoLanguage.ptBr,
      trigger: PlantaoRequestTrigger.userInput,
      continuationType: PlantaoContinuationType.initial,
      requestedSections: const <PlantaoSection>[],
      status: PlantaoPersistenceRecordStatus.prepared,
      finalizationStatus: 'structured',
      validationStatus: 'notEvaluated',
      sanitizedText: 'Conduta clínica sanitizada.',
      structure: PlantaoResponseStructure(
        sections: const <PlantaoResponseSection>[
          PlantaoResponseSection(
            section: PlantaoSection.summary,
            content: 'Resumo',
          ),
        ],
        medications: const [],
      ),
      provenance: PlantaoProvenance(
        provider: 'shadow_route_plan_not_executed',
        model: 'unexecuted',
        sourceMode: PlantaoSourceMode.localRag,
        matchedClinicalDocumentIds: const <String>['clinical-1'],
        matchedDrugDocumentIds: const <String>[],
        validatedDose: false,
        validatorReason: 'no_sensitive_pharmacology',
        usedExternalGrounding: false,
        continuationType: PlantaoContinuationType.initial,
        documentVersions: const <String, String>{'clinical-1': '2.0.0'},
      ),
      reasons: const <String>['shadow_write_not_attempted'],
      strictModeCompatible: true,
      futurePersistenceEligible: true,
      observedAt: DateTime.utc(2026, 7, 26, 21, 30),
    );

void main() {
  test('persistence record round-trips without raw prompt or patient context', () {
    final original = record();
    original.ensureValid();
    final json = original.toJson();
    final restored = PlantaoPersistenceRecord.fromJson(json);

    expect(restored.toJson(), json);
    expect(json, isNot(contains('question')));
    expect(json, isNot(contains('patientContext')));
    expect(json['containsRawQuestion'], isFalse);
    expect(json['containsPatientContext'], isFalse);
    expect(json['productionHistoryEligible'], isFalse);
  });

  test('future persistence rejects incompatible provenance continuation', () {
    final invalid = PlantaoPersistenceRecord(
      recordId: 'record',
      requestId: 'request',
      sessionId: 'session',
      language: PlantaoLanguage.es,
      trigger: PlantaoRequestTrigger.userInput,
      continuationType: PlantaoContinuationType.initial,
      requestedSections: const <PlantaoSection>[],
      status: PlantaoPersistenceRecordStatus.blocked,
      finalizationStatus: 'structured',
      validationStatus: 'blocked',
      sanitizedText: 'texto',
      structure: null,
      provenance: PlantaoProvenance(
        provider: 'none',
        model: 'none',
        sourceMode: PlantaoSourceMode.modelNative,
        matchedClinicalDocumentIds: const <String>[],
        matchedDrugDocumentIds: const <String>[],
        validatedDose: false,
        validatorReason: 'blocked',
        usedExternalGrounding: false,
        continuationType: PlantaoContinuationType.monitoring,
        documentVersions: const <String, String>{},
      ),
      reasons: const <String>['blocked'],
      strictModeCompatible: false,
      futurePersistenceEligible: false,
      observedAt: DateTime.utc(2026, 7, 26),
    );
    expect(
      invalid.validate(),
      contains('provenance continuationType mismatch'),
    );
  });
}
