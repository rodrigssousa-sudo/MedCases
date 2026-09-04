import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_route_decision.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_query_shape.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart';
import 'package:medcases/services/plantao_pipeline.dart';

PlantaoQueryShapeDecision shapeFor(String query) {
  return PlantaoQueryShapeResolver.resolve(
    PlantaoIntentEngine.analyze(query),
  );
}

void expectDomain(
  String query,
  PlantaoClinicalTaskDomainSignal expected, {
  PlantaoClinicalTaskDomainSignal? absent,
}) {
  final analysis = PlantaoIntentEngine.analyze(query);
  final shape = PlantaoQueryShapeResolver.resolve(analysis);
  final canonical = PlantaoCanonicalRouteResolver.resolveAnalysis(analysis);

  print(
    '[CLINICAL_TASK_DOMAIN]'
    '|query=$query'
    '|shape=${shape.shape.name}'
    '|intent=${analysis.primaryIntent.name}'
    '|context=${analysis.clinicalContext.name}'
    '|topic=${analysis.clinicalTopic}'
    '|domains=${shape.clinicalTaskDomains.map((e) => e.name).join(",")}'
    '|canonical=${canonical.responseModelId?.wireName ?? "NONE"}',
  );

  expect(shape.shape, PlantaoQueryShape.clinicalTask, reason: query);
  expect(shape.clinicalTaskDomains, contains(expected), reason: query);

  if (absent != null) {
    expect(
      shape.clinicalTaskDomains,
      isNot(contains(absent)),
      reason: query,
    );
  }

  final expectedCanonicalByQuery = <String, String>{
    'Interpretación de acidosis metabólica en gasometría':
        'gasometriaAcidoBase',
    'Interpretação de acidose metabólica na gasometria': 'gasometriaAcidoBase',
    'Cómo interpretar anion gap elevado': 'alteracaoLaboratorialCalculoClinico',
    'Como interpretar ânion gap elevado': 'alteracaoLaboratorialCalculoClinico',
    'Manejo de sepsis sin shock': 'sepseChoqueSeptico',
    'Manejo de sepse sem choque': 'sepseChoqueSeptico',
    'Manejo de shock cardiogénico': 'choque',
    'Manejo de choque cardiogênico': 'choque',
  };

  final expectedCanonical = expectedCanonicalByQuery[query];

  expect(
    expectedCanonical,
    isNotNull,
    reason: 'query sem adjudicação esperada no teste: $query',
  );
  expect(
    canonical.responseModelId?.name,
    expectedCanonical,
    reason: query,
  );
  expect(
    canonical.decisionSource,
    PlantaoCanonicalRouteDecisionSource.typedClinicalTaskManifest,
    reason: query,
  );
}

void main() {
  group('Plantao clinical task domain signals shadow V1-B-R0-R1', () {
    test('gasometry acid-base PT/ES gets one typed domain', () {
      for (final query in const [
        'Interpretación de acidosis metabólica en gasometría',
        'Interpretação de acidose metabólica na gasometria',
      ]) {
        expectDomain(
          query,
          PlantaoClinicalTaskDomainSignal.gasometryAcidBase,
          absent: PlantaoClinicalTaskDomainSignal.laboratoryCalculation,
        );
      }
    });

    test('anion gap PT/ES gets laboratory calculation domain', () {
      for (final query in const [
        'Cómo interpretar anion gap elevado',
        'Como interpretar ânion gap elevado',
      ]) {
        expectDomain(
          query,
          PlantaoClinicalTaskDomainSignal.laboratoryCalculation,
          absent: PlantaoClinicalTaskDomainSignal.gasometryAcidBase,
        );
      }
    });

    test('sepsis without shock activates sepsis but not shock', () {
      for (final query in const [
        'Manejo de sepsis sin shock',
        'Manejo de sepse sem choque',
      ]) {
        expectDomain(
          query,
          PlantaoClinicalTaskDomainSignal.sepsis,
          absent: PlantaoClinicalTaskDomainSignal.shock,
        );
      }
    });

    test('cardiogenic shock activates shock but not sepsis', () {
      for (final query in const [
        'Manejo de shock cardiogénico',
        'Manejo de choque cardiogênico',
      ]) {
        expectDomain(
          query,
          PlantaoClinicalTaskDomainSignal.shock,
          absent: PlantaoClinicalTaskDomainSignal.sepsis,
        );
      }
    });

    test('PT and ES collision pairs converge', () {
      expect(
        shapeFor(
          'Interpretación de acidosis metabólica en gasometría',
        ).clinicalTaskDomains,
        shapeFor(
          'Interpretação de acidose metabólica na gasometria',
        ).clinicalTaskDomains,
      );

      expect(
        shapeFor('Cómo interpretar anion gap elevado').clinicalTaskDomains,
        shapeFor('Como interpretar ânion gap elevado').clinicalTaskDomains,
      );

      expect(
        shapeFor('Manejo de sepsis sin shock').clinicalTaskDomains,
        shapeFor('Manejo de sepse sem choque').clinicalTaskDomains,
      );

      expect(
        shapeFor('Manejo de shock cardiogénico').clinicalTaskDomains,
        shapeFor('Manejo de choque cardiogênico').clinicalTaskDomains,
      );
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
