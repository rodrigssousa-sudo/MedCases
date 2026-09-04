import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_route_decision.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_query_shape.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart';
import 'package:medcases/services/plantao_pipeline.dart';

class P {
  final String model;
  final String id;
  final String lang;
  final String q;
  const P(this.model, this.id, this.lang, this.q);
}

void main() {
  group('canonical route M09/M14 clinicalTopicOnly V1-B-R0', () {
    test('M09 PT/ES variants route to intoxicação exógena', () {
      const probes = <P>[
        P('M09', 'M09_SEED_ES', 'es', 'Intoxicación por paracetamol'),
        P('M09', 'M09_SEED_PT', 'pt', 'Intoxicação por paracetamol'),
        P('M09', 'M09_OPIOID_ES', 'es', 'Intoxicación por opioides'),
        P('M09', 'M09_OPIOID_PT', 'pt', 'Intoxicação por opioides'),
        P('M09', 'M09_BZD_ES', 'es', 'Sobredosis de benzodiacepinas'),
        P('M09', 'M09_BZD_PT', 'pt', 'Superdose de benzodiazepínicos'),
        P('M09', 'M09_OP_ES', 'es', 'Intoxicación por organofosforados'),
        P('M09', 'M09_OP_PT', 'pt', 'Intoxicação por organofosforados'),
      ];

      for (final p in probes) {
        final a = PlantaoIntentEngine.analyze(p.q);
        final s = PlantaoQueryShapeResolver.resolve(a);
        final c = PlantaoCanonicalRouteResolver.resolveAnalysis(
          a,
          languageCode: p.lang,
        );

        expect(s.shape, PlantaoQueryShape.clinicalTopicOnly, reason: p.id);
        expect(
          c.responseModelId,
          PlantaoResponseModelId.intoxicacaoExogena,
          reason: p.id,
        );
        expect(
          c.decisionSource,
          PlantaoCanonicalRouteDecisionSource.typedClinicalTopicOnlyManifest,
          reason: p.id,
        );
        expect(c.contract, isNotNull, reason: p.id);
      }
    });

    test('M14 PT/ES variants route to parada cardiorrespiratória', () {
      const probes = <P>[
        P('M14', 'M14_SEED_ES', 'es', 'PCR en fibrilación ventricular'),
        P('M14', 'M14_SEED_PT', 'pt', 'PCR em fibrilação ventricular'),
        P('M14', 'M14_ASYSTOLE_ES', 'es',
            'Paro cardiorrespiratorio en asistolia'),
        P('M14', 'M14_ASYSTOLE_PT', 'pt',
            'Parada cardiorrespiratória em assistolia'),
        P('M14', 'M14_PEA_ES', 'es', 'PCR en actividad eléctrica sin pulso'),
        P('M14', 'M14_PEA_PT', 'pt', 'PCR em atividade elétrica sem pulso'),
        P('M14', 'M14_PVT_ES', 'es',
            'Paro cardíaco con taquicardia ventricular sin pulso'),
        P('M14', 'M14_PVT_PT', 'pt',
            'Parada cardíaca com taquicardia ventricular sem pulso'),
      ];

      for (final p in probes) {
        final a = PlantaoIntentEngine.analyze(p.q);
        final s = PlantaoQueryShapeResolver.resolve(a);
        final c = PlantaoCanonicalRouteResolver.resolveAnalysis(
          a,
          languageCode: p.lang,
        );

        expect(s.shape, PlantaoQueryShape.clinicalTopicOnly, reason: p.id);
        expect(
          c.responseModelId,
          PlantaoResponseModelId.paradaCardiorrespiratoria,
          reason: p.id,
        );
        expect(
          c.decisionSource,
          PlantaoCanonicalRouteDecisionSource.typedClinicalTopicOnlyManifest,
          reason: p.id,
        );
        expect(c.contract, isNotNull, reason: p.id);
      }
    });

    test('unmanifested clinicalTopicOnly remains fail-closed', () {
      for (final q in const [
        'TEP',
        'IAM',
        'Sepse',
        'Hiperkalemia grave',
        'Ventilação mecânica',
      ]) {
        final a = PlantaoIntentEngine.analyze(q);
        final s = PlantaoQueryShapeResolver.resolve(a);
        final c = PlantaoCanonicalRouteResolver.resolveAnalysis(a);

        expect(s.shape, PlantaoQueryShape.clinicalTopicOnly, reason: q);
        expect(c.responseModelId, isNull, reason: q);
        expect(
          c.decisionSource,
          PlantaoCanonicalRouteDecisionSource.unadjudicated,
          reason: q,
        );
      }
    });
  });
}
