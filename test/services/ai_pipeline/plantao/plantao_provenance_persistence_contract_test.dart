import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_persistence_record.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_provenance.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';

void main() {
  test('persistable payload retains complete provenance and document versions', () {
    final record = PlantaoPersistenceRecord(
      recordId: 'record-1',
      requestId: 'request-1',
      sessionId: 'session-1',
      language: PlantaoLanguage.es,
      trigger: PlantaoRequestTrigger.nextAction,
      continuationType: PlantaoContinuationType.monitoring,
      requestedSections: const <PlantaoSection>[
        PlantaoSection.monitoring,
      ],
      status: PlantaoPersistenceRecordStatus.prepared,
      finalizationStatus: 'structured',
      validationStatus: 'validated',
      sanitizedText: 'Monitoreo clínico.',
      structure: null,
      provenance: PlantaoProvenance(
        provider: 'gpt_paid',
        model: 'model-version',
        sourceMode: PlantaoSourceMode.mixed,
        matchedClinicalDocumentIds: const <String>['clinical-v2'],
        matchedDrugDocumentIds: const <String>['drug-v3'],
        validatedDose: true,
        validatorReason: 'exact_match',
        usedExternalGrounding: true,
        continuationType: PlantaoContinuationType.monitoring,
        documentVersions: const <String, String>{
          'clinical-v2': '2.0.0',
          'drug-v3': '3.0.0',
        },
      ),
      reasons: const <String>[],
      strictModeCompatible: true,
      futurePersistenceEligible: true,
      observedAt: DateTime.utc(2026, 7, 26),
    );

    final provenance =
        record.toJson()['provenance'] as Map<String, Object?>;
    expect(provenance['provider'], 'gpt_paid');
    expect(provenance['model'], 'model-version');
    expect(provenance['sourceMode'], 'mixed');
    expect(provenance['matchedClinicalDocumentIds'], ['clinical-v2']);
    expect(provenance['matchedDrugDocumentIds'], ['drug-v3']);
    expect(provenance['validatedDose'], isTrue);
    expect(provenance['validatorReason'], 'exact_match');
    expect(provenance['usedExternalGrounding'], isTrue);
    expect(provenance['continuationType'], 'monitoring');
    expect(
      provenance['documentVersions'],
      const <String, String>{
        'clinical-v2': '2.0.0',
        'drug-v3': '3.0.0',
      },
    );
  });
}
