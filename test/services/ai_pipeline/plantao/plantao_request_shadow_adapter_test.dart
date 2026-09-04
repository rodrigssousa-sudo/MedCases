import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_request_shadow_adapter.dart';

void main() {
  test('direct user input becomes an initial Plantão shadow request', () {
    final request = PlantaoRequestShadowAdapter.build(
      requestId: 'req-1',
      sessionId: 'session-1',
      question: 'Tratamento da hiperglicemia de 320 mg/dL',
      languageCode: 'pt',
      fromButton: false,
      continuationType: PlantaoContinuationType.examsEvolution,
      requestedSections: const <PlantaoSection>[PlantaoSection.exams],
    );
    expect(request.trigger, PlantaoRequestTrigger.userInput);
    expect(request.continuationType, PlantaoContinuationType.initial);
    expect(request.requestedSections, isEmpty);
    expect(request.strictClinicalMode, isTrue);
    expect(request.clientContext?['shadowMode'], isTrue);
  });

  test('button metadata survives as focused examsEvolution request', () {
    final request = PlantaoRequestShadowAdapter.build(
      requestId: 'req-2',
      sessionId: 'session-1',
      question: 'Quais exames solicitar e como monitorar a evolução?',
      languageCode: 'es_AR',
      fromButton: true,
      continuationType: PlantaoContinuationType.examsEvolution,
      requestedSections: const <PlantaoSection>[
        PlantaoSection.exams,
        PlantaoSection.monitoring,
        PlantaoSection.evolution,
        PlantaoSection.responseCriteria,
        PlantaoSection.worseningCriteria,
      ],
    );
    expect(request.language, PlantaoLanguage.es);
    expect(request.trigger, PlantaoRequestTrigger.nextAction);
    expect(request.continuationType, PlantaoContinuationType.examsEvolution);
    expect(request.requestedSections.length, plantaoExamsEvolutionAllowedSections.length);
    expect(request.requestedSections, containsAll(plantaoExamsEvolutionAllowedSections));
    expect(request.validate(), isEmpty);
  });
}
