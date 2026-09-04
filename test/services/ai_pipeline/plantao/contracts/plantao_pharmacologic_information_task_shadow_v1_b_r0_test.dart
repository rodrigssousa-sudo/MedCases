import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_query_shape.dart';
import 'package:medcases/services/plantao_pipeline.dart';

PlantaoQueryShapeDecision decisionFor(String query) {
  final analysis = PlantaoIntentEngine.analyze(query);
  return PlantaoQueryShapeResolver.resolve(analysis);
}

void expectTask(
  String query,
  PlantaoPharmacologicInformationTask expectedTask,
) {
  final analysis = PlantaoIntentEngine.analyze(query);
  final decision = PlantaoQueryShapeResolver.resolve(analysis);

  print(
    '[PHARM_INFO_TASK]'
    '|query=$query'
    '|intent=${analysis.primaryIntent.name}'
    '|shape=${decision.shape.name}'
    '|drug=${analysis.recognizedDrugEntity}'
    '|adverse=${analysis.recognizedAdverseEffectTask}'
    '|safety=${analysis.recognizedMedicationSafetyTask}'
    '|explicitTask=${decision.hasExplicitTaskIntent}'
    '|tasks=${decision.pharmacologicInformationTasks.map((e) => e.name).join(",")}',
  );

  expect(analysis.recognizedDrugEntity, isTrue, reason: query);
  expect(decision.shape, PlantaoQueryShape.clinicalTask, reason: query);
  expect(decision.hasExplicitTaskIntent, isTrue, reason: query);
  expect(decision.pharmacologicInformationTasks, contains(expectedTask),
      reason: query);
}

void main() {
  group('Plantao pharmacologic information task shadow V1-B-R0', () {
    test('adverse effect variants become clinicalTask in PT and ES', () {
      for (final query in const [
        'Efeitos adversos da amiodarona',
        'Efectos adversos de amiodarona',
        'Reações adversas da amiodarona',
        'Reacciones adversas de amiodarona',
        'Efeitos colaterais da amiodarona',
        'Efectos secundarios de amiodarona',
        'Efeitos adversos do sulfato de magnésio',
      ]) {
        expectTask(query, PlantaoPharmacologicInformationTask.adverseEffects);
      }
    });

    test('medication safety variants become clinicalTask in PT and ES', () {
      for (final query in const [
        'Segurança da amiodarona',
        'Seguridad de amiodarona',
      ]) {
        expectTask(query, PlantaoPharmacologicInformationTask.medicationSafety);
      }
    });

    test('pure drug names remain isolatedDrug', () {
      for (final query in const ['Amiodarona', 'Sulfato de magnésio']) {
        final analysis = PlantaoIntentEngine.analyze(query);
        final decision = PlantaoQueryShapeResolver.resolve(analysis);
        expect(analysis.recognizedDrugEntity, isTrue);
        expect(analysis.recognizedAdverseEffectTask, isFalse);
        expect(analysis.recognizedMedicationSafetyTask, isFalse);
        expect(decision.pharmacologicInformationTasks, isEmpty);
        expect(decision.shape, PlantaoQueryShape.isolatedDrug);
      }
    });

    test('dose and contraindication remain legacy-intent clinicalTask', () {
      for (final query in const [
        'Dose de amiodarona',
        'Dosis de amiodarona',
        'Contraindicações da amiodarona',
        'Contraindicaciones de amiodarona',
      ]) {
        final analysis = PlantaoIntentEngine.analyze(query);
        final decision = PlantaoQueryShapeResolver.resolve(analysis);
        expect(decision.shape, PlantaoQueryShape.clinicalTask);
        expect(decision.hasExplicitTaskIntent, isTrue);
        expect(decision.pharmacologicInformationTasks, isEmpty);
      }
    });

    test('PT and ES adverse effects converge', () {
      final pt = decisionFor('Efeitos adversos da amiodarona');
      final es = decisionFor('Efectos adversos de amiodarona');
      expect(pt.shape, PlantaoQueryShape.clinicalTask);
      expect(es.shape, PlantaoQueryShape.clinicalTask);
      expect(
          pt.pharmacologicInformationTasks, es.pharmacologicInformationTasks);
    });
  });
}
