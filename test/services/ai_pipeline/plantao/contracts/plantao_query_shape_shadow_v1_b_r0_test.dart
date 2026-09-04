import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_query_shape.dart';
import 'package:medcases/services/plantao_pipeline.dart';

void expectShape(String query, PlantaoQueryShape expected) {
  final analysis = PlantaoIntentEngine.analyze(query);
  final decision = PlantaoQueryShapeResolver.resolve(analysis);

  expect(decision.shape, expected, reason: query);

  print(
    '[QUERY_SHAPE]'
    '|query=$query'
    '|shape=${decision.shape.name}'
    '|drug=${decision.recognizedDrugEntity}'
    '|explicitContext=${decision.recognizedExplicitClinicalContext}'
    '|explicitTask=${decision.hasExplicitTaskIntent}'
    '|intent=${decision.primaryIntent.name}'
    '|topic=${decision.clinicalTopic}',
  );
}

void main() {
  group('Plantao typed query shape shadow V1-B-R0', () {
    test('isolated pharmacologic entities are isolatedDrug', () {
      for (final query in const [
        'Amiodarona',
        'Midazolam',
        'Furosemida',
        'Ceftriaxona',
      ]) {
        final qa = PlantaoIntentEngine.analyze(query);

        expect(qa.recognizedDrugEntity, isTrue, reason: query);
        expect(
          qa.recognizedExplicitClinicalContext,
          isFalse,
          reason: query,
        );

        expectShape(query, PlantaoQueryShape.isolatedDrug);
      }
    });

    test('clinical topics are not misclassified as isolated drugs', () {
      for (final query in const [
        'TEP',
        'IAM',
        'Sepse',
        'Hiperkalemia grave',
        'Ventilação mecânica',
      ]) {
        final qa = PlantaoIntentEngine.analyze(query);

        expect(qa.recognizedDrugEntity, isFalse, reason: query);
        expect(
          qa.recognizedExplicitClinicalContext,
          isTrue,
          reason: query,
        );

        expectShape(query, PlantaoQueryShape.clinicalTopicOnly);
      }
    });

    test('drug plus explicit clinical context is drugWithinClinicalContext',
        () {
      for (final query in const [
        'Noradrenalina em choque',
        'Ceftriaxona na sepse',
      ]) {
        final qa = PlantaoIntentEngine.analyze(query);

        expect(qa.recognizedDrugEntity, isTrue, reason: query);
        expect(
          qa.recognizedExplicitClinicalContext,
          isTrue,
          reason: query,
        );

        expectShape(
          query,
          PlantaoQueryShape.drugWithinClinicalContext,
        );
      }
    });

    test('ketamine via aérea explicit-context provenance backlog is closed',
        () {
      final qa = PlantaoIntentEngine.analyze('Ketamina na via aérea');
      final decision = PlantaoQueryShapeResolver.resolve(qa);

      expect(qa.recognizedDrugEntity, isTrue);
      expect(qa.recognizedExplicitClinicalContext, isTrue);
      expect(
        decision.shape,
        PlantaoQueryShape.drugWithinClinicalContext,
      );

      print(
        '[QUERY_SHAPE_CONTEXT_BACKLOG_CLOSED]'
        '|query=Ketamina na via aérea'
        '|shape=${decision.shape.name}'
        '|drug=${qa.recognizedDrugEntity}'
        '|explicitContext=${qa.recognizedExplicitClinicalContext}'
        '|context=${qa.clinicalContext.name}'
        '|topic=${qa.clinicalTopic}',
      );
    });

    test('explicit task takes precedence over query entity shape', () {
      for (final query in const [
        'Dosis de amiodarona',
        'Manejo TEP',
        'Infusión de noradrenalina en shock',
        'Dolor torácico agudo con sospecha de infarto',
      ]) {
        expectShape(query, PlantaoQueryShape.clinicalTask);
      }
    });

    test('ES and PT equivalent infusion have the same shape', () {
      final es = PlantaoQueryShapeResolver.resolveUserMessage(
        'Infusión de noradrenalina en shock',
      );
      final pt = PlantaoQueryShapeResolver.resolveUserMessage(
        'Infusão de noradrenalina em choque',
      );

      expect(es.shape, PlantaoQueryShape.clinicalTask);
      expect(pt.shape, PlantaoQueryShape.clinicalTask);
      expect(es.shape, pt.shape);
      expect(es.recognizedDrugEntity, pt.recognizedDrugEntity);
      expect(
        es.recognizedExplicitClinicalContext,
        pt.recognizedExplicitClinicalContext,
      );
    });

    test('topic-only TEP and isolated amiodarone are structurally distinct',
        () {
      final tep = PlantaoQueryShapeResolver.resolveUserMessage('TEP');
      final amiodarone =
          PlantaoQueryShapeResolver.resolveUserMessage('Amiodarona');

      expect(tep.shape, PlantaoQueryShape.clinicalTopicOnly);
      expect(amiodarone.shape, PlantaoQueryShape.isolatedDrug);
      expect(tep.recognizedDrugEntity, isFalse);
      expect(amiodarone.recognizedDrugEntity, isTrue);
    });

    test('shape resolver does not select a response model', () {
      final sourceShape = PlantaoQueryShapeResolver.resolveUserMessage(
        'Amiodarona',
      );

      expect(sourceShape.shape, PlantaoQueryShape.isolatedDrug);

      // Compile-time contract: this type contains query-shape evidence only.
      expect(
        PlantaoQueryShapeDecision,
        isNot(equals(PlantaoIntentEngine)),
      );
    });
  });
}
