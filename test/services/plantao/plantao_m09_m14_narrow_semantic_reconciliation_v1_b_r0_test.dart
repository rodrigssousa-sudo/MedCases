import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_route_decision.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_query_shape.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart';
import 'package:medcases/services/plantao_pipeline.dart';

class P {
  final String group;
  final String id;
  final String lang;
  final String q;

  const P(this.group, this.id, this.lang, this.q);
}

void main() {
  group('M09/M14 narrow semantic reconciliation V1-B-R0', () {
    test('all 8 M09 variants converge to toxicology clinicalTopicOnly', () {
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
        final classifier = PlantaoIntentClassifier.classify(p.q);

        print(
          '[M09_RECONCILED]'
          '|id=${p.id}'
          '|primary=${a.primaryIntent.name}'
          '|context=${a.clinicalContext.name}'
          '|topic=${a.clinicalTopic}'
          '|shape=${s.shape.name}'
          '|classifier=${classifier.intent.name}'
          '|canonical=${c.responseModelId?.name ?? "NONE"}',
        );

        expect(a.primaryIntent, PlantaoIntent.geral, reason: p.id);
        expect(a.clinicalContext, PlantaoContext.toxicologia, reason: p.id);
        expect(a.clinicalTopic, 'INTOXICAÇÃO', reason: p.id);
        expect(
          a.recognizedExplicitClinicalContext,
          isTrue,
          reason: p.id,
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
      }
    });

    test('all 8 M14 variants converge to PCR clinicalTopicOnly', () {
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

        print(
          '[M14_RECONCILED]'
          '|id=${p.id}'
          '|primary=${a.primaryIntent.name}'
          '|context=${a.clinicalContext.name}'
          '|topic=${a.clinicalTopic}'
          '|shape=${s.shape.name}'
          '|canonical=${c.responseModelId?.name ?? "NONE"}',
        );

        expect(a.clinicalContext, PlantaoContext.pcr, reason: p.id);
        expect(a.clinicalTopic, 'PCR', reason: p.id);
        expect(
          a.recognizedExplicitClinicalContext,
          isTrue,
          reason: p.id,
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
      }
    });

    test('real dose queries remain dose', () {
      for (final q in const [
        'Dose de amiodarona',
        'Dosis de amiodarona',
        'Qual a dose de ceftriaxona',
      ]) {
        final a = PlantaoIntentEngine.analyze(q);
        expect(a.primaryIntent, PlantaoIntent.dose, reason: q);
      }
    });

    test('acidosis false dosis regression remains fixed', () {
      final a = PlantaoIntentEngine.analyze(
        'Interpretación de acidosis metabólica en gasometría',
      );
      expect(a.primaryIntent, PlantaoIntent.interpretacao);
    });
  });
}
