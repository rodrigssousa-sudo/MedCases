import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_pipeline/ai_response_structure_parser.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_response_structure_shadow_adapter.dart';
import 'package:medcases/services/plantao_pipeline.dart';

void main() {
  test('examsEvolution filters every treatment section from shadow structure', () {
    final request = PlantaoRequest(
      requestId: 'req-exams',
      sessionId: 'session-1',
      question: 'Quais exames e como acompanhar?',
      language: PlantaoLanguage.ptBr,
      trigger: PlantaoRequestTrigger.nextAction,
      continuationType: PlantaoContinuationType.examsEvolution,
      requestedSections: const <PlantaoSection>[
        PlantaoSection.monitoring,
        PlantaoSection.evolution,
        PlantaoSection.responseCriteria,
        PlantaoSection.worseningCriteria,
      ],
    );
    final parsed = AiResponseStructureOutcome(
      text: 'texto',
      mode: AiRequestMode.plantao,
      plantaoResponse: const PlantaoResponse(
        conduta: 'Pneumonia',
        primeiraLinha: 'Amoxicilina 500 mg VO',
        monitorar: 'Saturação e frequência respiratória',
        metas: 'Melhora clínica em 48 horas',
        alerta: 'Piora da hipoxemia',
        proxPasso: 'Reavaliar em 24 a 48 horas',
      ),
      clinicalOutput: null,
      structuredOutputStatus: AiStructuredOutputStatus.absent,
    );

    final outcome = PlantaoResponseStructureShadowAdapter.build(
      request: request,
      parsed: parsed,
    );
    final sections = outcome.structure.sections
        .map((item) => item.section)
        .toSet();

    expect(sections, contains(PlantaoSection.monitoring));
    expect(sections, contains(PlantaoSection.evolution));
    expect(sections, contains(PlantaoSection.responseCriteria));
    expect(sections, contains(PlantaoSection.worseningCriteria));
    expect(sections, isNot(contains(PlantaoSection.firstLine)));
    expect(sections, isNot(contains(PlantaoSection.fullTreatment)));
    expect(sections, isNot(contains(PlantaoSection.dosageClarification)));
  });
}
