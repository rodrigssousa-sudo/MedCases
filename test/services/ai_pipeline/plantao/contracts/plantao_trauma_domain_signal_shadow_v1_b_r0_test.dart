import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_route_decision.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_query_shape.dart';
import 'package:medcases/services/plantao_pipeline.dart';

void main() {
  group('Plantao trauma domain signal shadow V1-B-R0-R1', () {
    test('PT and ES trauma acquire trauma domain', () {
      for (final query in const [
        'Manejo inicial de traumatismo craneoencefálico',
        'Manejo inicial de traumatismo cranioencefálico',
        'Manejo inicial do trauma torácico',
        'Manejo inicial del trauma torácico',
      ]) {
        final analysis = PlantaoIntentEngine.analyze(query);
        final shape = PlantaoQueryShapeResolver.resolve(analysis);
        final canonical =
            PlantaoCanonicalRouteResolver.resolveAnalysis(analysis);

        print(
          '[TRAUMA_DOMAIN]'
          '|query=$query'
          '|shape=${shape.shape.name}'
          '|domains=${shape.clinicalTaskDomains.map((e) => e.name).join(",")}'
          '|canonical=${canonical.responseModelId?.name ?? "NONE"}',
        );

        expect(shape.shape, PlantaoQueryShape.clinicalTask, reason: query);
        expect(
          shape.clinicalTaskDomains,
          contains(PlantaoClinicalTaskDomainSignal.trauma),
          reason: query,
        );
        expect(
          canonical.responseModelId?.name,
          'trauma',
          reason: query,
        );
        expect(
          canonical.decisionSource,
          PlantaoCanonicalRouteDecisionSource.typedClinicalTaskManifest,
          reason: query,
        );
      }
    });

    test('previous 26 S15 negative collisions do not acquire trauma domain',
        () {
      const negatives = <String>[
        'Manejo inicial de pancreatite aguda',
        'Manejo inicial de pancreatitis aguda',
        'Manejo inicial de colecistite aguda',
        'Manejo inicial de colecistitis aguda',
        'Manejo inicial de meningitis bacteriana',
        'Manejo inicial de asma grave',
        'Manejo inicial de anafilaxia',
        'Manejo inicial de crisis convulsiva',
        'Manejo inicial de pneumonia grave',
        'Manejo inicial de neumonía grave',
        'Manejo inicial de apendicite aguda',
        'Manejo inicial de apendicitis aguda',
        'Manejo inicial de pielonefrite aguda',
        'Manejo inicial de pielonefritis aguda',
        'Manejo inicial de gastrite aguda',
        'Manejo de insuficiência cardíaca aguda',
        'Manejo de insuficiencia cardíaca aguda',
        'Tratamento inicial de pneumonia comunitária',
        'Tratamiento inicial de neumonía comunitaria',
        'Manejo de dor abdominal aguda',
        'Manejo de dolor abdominal agudo',
        'Manejo de febre neutropênica',
        'Manejo de fiebre neutropénica',
        'Manejo inicial de meningite bacteriana',
        'Manejo inicial de crise convulsiva',
        'Manejo inicial de gastritis aguda',
      ];

      expect(negatives, hasLength(26));

      for (final query in negatives) {
        final analysis = PlantaoIntentEngine.analyze(query);
        final shape = PlantaoQueryShapeResolver.resolve(analysis);
        final canonical =
            PlantaoCanonicalRouteResolver.resolveAnalysis(analysis);

        expect(
          shape.clinicalTaskDomains,
          isNot(contains(PlantaoClinicalTaskDomainSignal.trauma)),
          reason: query,
        );
        expect(canonical.responseModelId, isNull, reason: query);
      }
    });

    test('canonical isolated-drug rule remains active', () {
      final canonical =
          PlantaoCanonicalRouteResolver.resolveUserMessage('Amiodarona');

      expect(canonical.hasCanonicalDecision, isTrue);
      expect(
        canonical.queryShapeDecision.shape,
        PlantaoQueryShape.isolatedDrug,
      );
    });
  });
}
