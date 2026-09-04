import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_query_shape.dart';
import 'package:medcases/services/plantao_pipeline.dart';

void main() {
  group('Plantao explicit context via aérea shadow V1-B-R0', () {
    test('PT and ES contextual ketamine are drugWithinClinicalContext', () {
      for (final query in const [
        'Ketamina na via aérea',
        'Ketamina en vía aérea',
      ]) {
        final analysis = PlantaoIntentEngine.analyze(query);
        final decision = PlantaoQueryShapeResolver.resolve(analysis);

        print(
          '[VIA_AEREA_CONTEXT]'
          '|query=$query'
          '|shape=${decision.shape.name}'
          '|drug=${analysis.recognizedDrugEntity}'
          '|explicitContext=${analysis.recognizedExplicitClinicalContext}'
          '|intent=${analysis.primaryIntent.name}'
          '|context=${analysis.clinicalContext.name}'
          '|topic=${analysis.clinicalTopic}',
        );

        expect(analysis.recognizedDrugEntity, isTrue, reason: query);
        expect(
          analysis.recognizedExplicitClinicalContext,
          isTrue,
          reason: query,
        );
        expect(
          decision.shape,
          PlantaoQueryShape.drugWithinClinicalContext,
          reason: query,
        );
      }
    });

    test('pure ketamine remains isolatedDrug', () {
      final analysis = PlantaoIntentEngine.analyze('Ketamina');
      final decision = PlantaoQueryShapeResolver.resolve(analysis);

      expect(analysis.recognizedDrugEntity, isTrue);
      expect(analysis.recognizedExplicitClinicalContext, isFalse);
      expect(decision.shape, PlantaoQueryShape.isolatedDrug);
    });

    test('existing explicit-context controls remain correct', () {
      for (final query in const [
        'Noradrenalina em choque',
        'Ceftriaxona na sepse',
      ]) {
        final analysis = PlantaoIntentEngine.analyze(query);
        final decision = PlantaoQueryShapeResolver.resolve(analysis);

        expect(analysis.recognizedDrugEntity, isTrue);
        expect(analysis.recognizedExplicitClinicalContext, isTrue);
        expect(
          decision.shape,
          PlantaoQueryShape.drugWithinClinicalContext,
        );
      }
    });

    test('pharmacologic information task remains clinicalTask', () {
      final analysis =
          PlantaoIntentEngine.analyze('Efeitos adversos da amiodarona');
      final decision = PlantaoQueryShapeResolver.resolve(analysis);

      expect(decision.shape, PlantaoQueryShape.clinicalTask);
    });
  });
}
