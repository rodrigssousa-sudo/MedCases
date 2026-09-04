import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_route_decision.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_query_shape.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart';

void expectIsolatedDrugCanonical(
  String query, {
  String languageCode = 'pt',
}) {
  final resolved = PlantaoCanonicalRouteResolver.resolveUserMessage(
    query,
    languageCode: languageCode,
  );

  print(
    '[CANONICAL_ROUTE]'
    '|query=$query'
    '|shape=${resolved.queryShapeDecision.shape.name}'
    '|model=${resolved.responseModelId?.wireName ?? "NONE"}'
    '|source=${resolved.decisionSource.name}'
    '|legacy=${resolved.legacyObservation?.legacyMatrixModelId.wireName ?? "NONE"}'
    '|legacyConflict=${resolved.legacyObservation?.hasStructuralConflict ?? false}',
  );

  expect(
    resolved.queryShapeDecision.shape,
    PlantaoQueryShape.isolatedDrug,
    reason: query,
  );
  expect(resolved.queryShapeDecision.recognizedDrugEntity, isTrue);
  expect(
    resolved.queryShapeDecision.recognizedExplicitClinicalContext,
    isFalse,
  );
  expect(resolved.queryShapeDecision.hasExplicitTaskIntent, isFalse);
  expect(
    resolved.queryShapeDecision.pharmacologicInformationTasks,
    isEmpty,
  );
  expect(
    resolved.responseModelId,
    PlantaoResponseModelId.farmacoIsolado,
    reason: query,
  );
  expect(
    resolved.contract?.id,
    PlantaoResponseModelId.farmacoIsolado,
    reason: query,
  );
  expect(
    resolved.decisionSource,
    PlantaoCanonicalRouteDecisionSource.typedIsolatedDrug,
    reason: query,
  );
  expect(resolved.conflictReasons, isEmpty, reason: query);
  expect(resolved.hasCanonicalDecision, isTrue, reason: query);
}

void expectFailClosed(
  String query,
  PlantaoQueryShape expectedShape, {
  String languageCode = 'pt',
}) {
  final resolved = PlantaoCanonicalRouteResolver.resolveUserMessage(
    query,
    languageCode: languageCode,
  );

  print(
    '[CANONICAL_FAIL_CLOSED]'
    '|query=$query'
    '|shape=${resolved.queryShapeDecision.shape.name}'
    '|model=${resolved.responseModelId?.wireName ?? "NONE"}'
    '|source=${resolved.decisionSource.name}',
  );

  expect(
    resolved.queryShapeDecision.shape,
    expectedShape,
    reason: query,
  );
  expect(resolved.responseModelId, isNull, reason: query);
  expect(resolved.contract, isNull, reason: query);
  expect(
    resolved.decisionSource,
    PlantaoCanonicalRouteDecisionSource.unadjudicated,
    reason: query,
  );
  expect(
    resolved.conflictReasons,
    contains(
      PlantaoCanonicalRouteConflictReason.queryShapeNotAdjudicated,
    ),
    reason: query,
  );
  expect(resolved.hasCanonicalDecision, isFalse, reason: query);
}

void main() {
  group('Plantao canonical route decision shadow isolated drug V1-B-R0', () {
    test('clean isolated drugs select only farmacoIsolado', () {
      const cases = <(String, String)>[
        ('Amiodarona', 'pt'),
        ('Amiodarona', 'es'),
        ('Adenosina', 'es'),
        ('Noradrenalina', 'es'),
        ('Ceftriaxona', 'es'),
        ('Midazolam', 'es'),
        ('Fentanil', 'es'),
        ('Furosemida', 'es'),
        ('Enoxaparina', 'es'),
        ('Ketamina', 'es'),
        ('Sulfato de magnésio', 'es'),
      ];

      for (final item in cases) {
        expectIsolatedDrugCanonical(
          item.$1,
          languageCode: item.$2,
        );
      }
    });

    test('unmanifested clinicalTask remains fail-closed', () {
      for (final item in const <(String, String)>[
        ('Dosis de amiodarona', 'es'),
        ('Dose de amiodarona', 'pt'),
        ('Contraindicaciones de amiodarona', 'es'),
        ('Contraindicações da amiodarona', 'pt'),
      ]) {
        expectFailClosed(
          item.$1,
          PlantaoQueryShape.clinicalTask,
          languageCode: item.$2,
        );
      }
    });

    test('clinicalTopicOnly remains fail-closed', () {
      for (final query in const [
        'TEP',
        'IAM',
        'Sepse',
        'Hiperkalemia grave',
        'Ventilação mecânica',
      ]) {
        expectFailClosed(
          query,
          PlantaoQueryShape.clinicalTopicOnly,
        );
      }
    });

    test('drugWithinClinicalContext remains fail-closed', () {
      for (final item in const <(String, String)>[
        ('Noradrenalina em choque', 'pt'),
        ('Ceftriaxona na sepse', 'pt'),
        ('Ketamina na via aérea', 'pt'),
        ('Ketamina en vía aérea', 'es'),
      ]) {
        expectFailClosed(
          item.$1,
          PlantaoQueryShape.drugWithinClinicalContext,
          languageCode: item.$2,
        );
      }
    });

    test('unadjudicated ambiguous remains fail-closed', () {
      for (final item in const <(String, String)>[
        ('FA com resposta ventricular rápida', 'pt'),
        ('Paciente com queixa inespecífica', 'pt'),
        ('Paciente sem outros dados', 'pt'),
        ('Paciente con queja inespecífica', 'es'),
        ('Paciente sin otros datos', 'es'),
      ]) {
        expectFailClosed(
          item.$1,
          PlantaoQueryShape.ambiguous,
          languageCode: item.$2,
        );
      }
    });

    test(
        'canonical decision ignores conflicting legacy model for isolated drug',
        () {
      final amiodarone =
          PlantaoCanonicalRouteResolver.resolveUserMessage('Amiodarona');

      expect(
        amiodarone.responseModelId,
        PlantaoResponseModelId.farmacoIsolado,
      );
      expect(amiodarone.legacyObservation, isNotNull);
      expect(
        amiodarone.legacyObservation!.legacyMatrixModelId,
        PlantaoResponseModelId.arritmia,
      );
      expect(
        amiodarone.legacyObservation!.specialTemplateModelId,
        PlantaoResponseModelId.farmacoIsolado,
      );
      expect(amiodarone.legacyObservation!.hasStructuralConflict, isTrue);
    });

    test('magnesium uses typed shape even when legacy observation differs', () {
      final magnesium = PlantaoCanonicalRouteResolver.resolveUserMessage(
        'Sulfato de magnésio',
      );

      expect(
        magnesium.responseModelId,
        PlantaoResponseModelId.farmacoIsolado,
      );
      expect(magnesium.legacyObservation, isNotNull);
      expect(
        magnesium.legacyObservation!.legacyMatrixModelId,
        PlantaoResponseModelId.disturbioEletrolitico,
      );
      expect(magnesium.legacyObservation!.specialTemplateModelId, isNull);
    });

    test('PT and ES pure drug route to the same canonical model', () {
      final pt = PlantaoCanonicalRouteResolver.resolveUserMessage(
        'Amiodarona',
        languageCode: 'pt',
      );
      final es = PlantaoCanonicalRouteResolver.resolveUserMessage(
        'Amiodarona',
        languageCode: 'es',
      );

      expect(pt.responseModelId, es.responseModelId);
      expect(
        pt.responseModelId,
        PlantaoResponseModelId.farmacoIsolado,
      );
    });

    test('only isolatedDrug is adjudicated in this version', () {
      for (final shape in PlantaoQueryShape.values) {
        if (shape == PlantaoQueryShape.isolatedDrug) continue;

        expect(
          shape,
          isNot(PlantaoQueryShape.isolatedDrug),
        );
      }

      // Guard semântico: o owner contém uma única atribuição produtiva
      // de modelo canônico nesta versão, farmacoIsolado.
      expect(
        PlantaoResponseModelId.farmacoIsolado.wireName,
        'farmaco_isolado',
      );
    });
  });
}
