import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_pipeline/ai_response_structure_parser.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_response_structure_shadow_adapter.dart';
import 'package:medcases/services/plantao_pipeline.dart';

void main() {
  test('maps typed canonical outputs without inventing medication fields', () {
    final request = PlantaoRequest(
      requestId: 'req-structure',
      sessionId: 'session-1',
      question: 'Manejo de choque séptico',
      language: PlantaoLanguage.ptBr,
      trigger: PlantaoRequestTrigger.userInput,
      continuationType: PlantaoContinuationType.initial,
      requestedSections: const <PlantaoSection>[],
    );
    final clinical = ClinicalStructuredOutput(
      diagnosticoHeuristico: 'Choque séptico',
      condutaImediata: 'Iniciar ressuscitação.',
      prescricao: const <ClinicalPrescriptionItem>[
        ClinicalPrescriptionItem(
          farmaco: 'Noradrenalina',
          posologia: '0,05 mcg/kg/min EV',
        ),
      ],
      primeiraLinha: const <ClinicalPrescriptionItem>[
        ClinicalPrescriptionItem(
          farmaco: 'Noradrenalina',
          posologia: '0,05 mcg/kg/min EV',
        ),
      ],
      pontosChave: const <String>['Meta de PAM individualizada'],
    );
    final parsed = AiResponseStructureOutcome(
      text: 'texto',
      mode: AiRequestMode.plantao,
      plantaoResponse: const PlantaoResponse(
        conduta: 'Choque séptico',
        primeiraLinha: 'Noradrenalina 0,05 mcg/kg/min EV',
        monitorar: 'PAM e diurese',
      ),
      clinicalOutput: clinical,
      structuredOutputStatus: AiStructuredOutputStatus.valid,
    );

    final outcome = PlantaoResponseStructureShadowAdapter.build(
      request: request,
      parsed: parsed,
      clinicalOutput: clinical,
    );

    final sections = outcome.structure.sections
        .map((item) => item.section)
        .toSet();
    expect(sections, contains(PlantaoSection.summary));
    expect(sections, contains(PlantaoSection.firstLine));
    expect(sections, contains(PlantaoSection.monitoring));
    expect(outcome.structure.medications, isEmpty);
    expect(outcome.deferredMedicationCount, 1);
  });
}
