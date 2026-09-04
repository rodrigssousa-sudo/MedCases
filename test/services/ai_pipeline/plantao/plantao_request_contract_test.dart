import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_pipeline.dart';

void main() {
  group('PlantaoRequest', () {
    test('round-trips all required contract fields', () {
      final PlantaoRequest request = PlantaoRequest(
        requestId: 'req-1',
        sessionId: 'session-1',
        question: 'Quais exames e critérios de piora?',
        language: PlantaoLanguage.ptBr,
        trigger: PlantaoRequestTrigger.nextAction,
        continuationType: PlantaoContinuationType.examsEvolution,
        requestedSections: const <PlantaoSection>[
          PlantaoSection.exams,
          PlantaoSection.monitoring,
          PlantaoSection.evolution,
          PlantaoSection.responseCriteria,
          PlantaoSection.worseningCriteria,
        ],
        patientContext: const <String, Object?>{'age': 64},
        memoryContext: const <String, Object?>{'topic': 'IAM'},
      );

      final PlantaoRequest decoded = PlantaoRequest.fromJson(request.toJson());

      expect(decoded.requestId, request.requestId);
      expect(decoded.sessionId, request.sessionId);
      expect(decoded.question, request.question);
      expect(decoded.language, PlantaoLanguage.ptBr);
      expect(decoded.trigger, PlantaoRequestTrigger.nextAction);
      expect(decoded.continuationType, PlantaoContinuationType.examsEvolution);
      expect(decoded.requestedSections, request.requestedSections);
      expect(decoded.strictClinicalMode, isTrue);
      expect(decoded.validate(), isEmpty);
    });

    test('next action cannot lose continuation type', () {
      final PlantaoRequest request = PlantaoRequest(
        requestId: 'req-2',
        sessionId: 'session-2',
        question: 'Continuar',
        language: PlantaoLanguage.es,
        trigger: PlantaoRequestTrigger.nextAction,
        continuationType: PlantaoContinuationType.initial,
        requestedSections: const <PlantaoSection>[],
      );

      expect(
        request.validate(),
        contains('next_action requires a non-initial continuationType'),
      );
      expect(
        request.ensureValid,
        throwsA(isA<PlantaoRequestValidationException>()),
      );
    });

    test('examsEvolution rejects treatment replay sections', () {
      final PlantaoRequest request = PlantaoRequest(
        requestId: 'req-3',
        sessionId: 'session-3',
        question: 'Exames e evolução',
        language: PlantaoLanguage.ptBr,
        trigger: PlantaoRequestTrigger.nextAction,
        continuationType: PlantaoContinuationType.examsEvolution,
        requestedSections: const <PlantaoSection>[
          PlantaoSection.exams,
          PlantaoSection.fullTreatment,
          PlantaoSection.completeMatrixReplay,
        ],
      );

      expect(
        request.validate(),
        containsAll(<String>[
          'examsEvolution does not allow fullTreatment',
          'examsEvolution does not allow completeMatrixReplay',
        ]),
      );
    });
  });
}
