import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_route_decision.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_query_shape.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart';

class PositiveProbe {
  final String id;
  final String lang;
  final String query;
  final PlantaoResponseModelId expected;
  const PositiveProbe(this.id, this.lang, this.query, this.expected);
}

class NegativeProbe {
  final String id;
  final String lang;
  final String query;
  const NegativeProbe(this.id, this.lang, this.query);
}

void main() {
  group('Canonical route clinicalTask manifest V1-B-R0', () {
    test('32 positives select exact manifested model', () {
      const p = <PositiveProbe>[
        PositiveProbe('S01_ES', 'es', 'Cómo interpretar anion gap elevado',
            PlantaoResponseModelId.alteracaoLaboratorialCalculoClinico),
        PositiveProbe('S01_PT', 'pt', 'Como interpretar ânion gap elevado',
            PlantaoResponseModelId.alteracaoLaboratorialCalculoClinico),
        PositiveProbe(
            'S02_ES',
            'es',
            'Manejo de fibrilación auricular inestable',
            PlantaoResponseModelId.arritmia),
        PositiveProbe('S02_PT', 'pt', 'Manejo de fibrilação atrial instável',
            PlantaoResponseModelId.arritmia),
        PositiveProbe('S03_ES', 'es', 'Manejo de ACV isquémico agudo',
            PlantaoResponseModelId.avc),
        PositiveProbe('S03_PT', 'pt', 'Manejo de AVC isquêmico agudo',
            PlantaoResponseModelId.avc),
        PositiveProbe('S04_ES', 'es', 'Tratamiento inicial del TEP',
            PlantaoResponseModelId.casoClinicoEmergencia),
        PositiveProbe('S04_PT', 'pt', 'Tratamento inicial do TEP',
            PlantaoResponseModelId.casoClinicoEmergencia),
        PositiveProbe('S05_ES', 'es', 'Manejo de shock cardiogénico',
            PlantaoResponseModelId.choque),
        PositiveProbe('S05_PT', 'pt', 'Manejo de choque cardiogênico',
            PlantaoResponseModelId.choque),
        PositiveProbe(
            'S06_ES',
            'es',
            'Emergencia hipertensiva con lesión de órgano diana',
            PlantaoResponseModelId.criseHipertensiva),
        PositiveProbe(
            'S06_PT',
            'pt',
            'Emergência hipertensiva com lesão de órgão-alvo',
            PlantaoResponseModelId.criseHipertensiva),
        PositiveProbe('S07_ES', 'es', 'Tratamiento de hiperkalemia grave',
            PlantaoResponseModelId.disturbioEletrolitico),
        PositiveProbe('S07_PT', 'pt', 'Tratamento da hipercalemia grave',
            PlantaoResponseModelId.disturbioEletrolitico),
        PositiveProbe(
            'S08_ES',
            'es',
            'Dolor torácico agudo con sospecha de infarto',
            PlantaoResponseModelId.dorToracicaAguda),
        PositiveProbe(
            'S08_PT',
            'pt',
            'Dor torácica aguda com suspeita de infarto',
            PlantaoResponseModelId.dorToracicaAguda),
        PositiveProbe('S09_ES', 'es', 'Efectos adversos de amiodarona',
            PlantaoResponseModelId.efeitosAdversosMedicamentosos),
        PositiveProbe('S09_PT', 'pt', 'Efeitos adversos da amiodarona',
            PlantaoResponseModelId.efeitosAdversosMedicamentosos),
        PositiveProbe(
            'S10_ES',
            'es',
            'Interpretación de acidosis metabólica en gasometría',
            PlantaoResponseModelId.gasometriaAcidoBase),
        PositiveProbe(
            'S10_PT',
            'pt',
            'Interpretação de acidose metabólica na gasometria',
            PlantaoResponseModelId.gasometriaAcidoBase),
        PositiveProbe('S11_ES', 'es', 'Cómo titular noradrenalina',
            PlantaoResponseModelId.infusaoTitulacaoDesmame),
        PositiveProbe('S11_PT', 'pt', 'Como titular noradrenalina',
            PlantaoResponseModelId.infusaoTitulacaoDesmame),
        PositiveProbe('S12_ES', 'es', 'Infusión de noradrenalina en shock',
            PlantaoResponseModelId.infusaoTitulacaoDesmame),
        PositiveProbe('S12_PT', 'pt', 'Infusão de noradrenalina em choque',
            PlantaoResponseModelId.infusaoTitulacaoDesmame),
        PositiveProbe('S13_ES', 'es', 'Manejo de lesión renal aguda KDIGO 2',
            PlantaoResponseModelId.lesaoRenalAguda),
        PositiveProbe('S13_PT', 'pt', 'Manejo de lesão renal aguda KDIGO 2',
            PlantaoResponseModelId.lesaoRenalAguda),
        PositiveProbe('S14_ES', 'es', 'Manejo de sepsis sin shock',
            PlantaoResponseModelId.sepseChoqueSeptico),
        PositiveProbe('S14_PT', 'pt', 'Manejo de sepse sem choque',
            PlantaoResponseModelId.sepseChoqueSeptico),
        PositiveProbe(
            'S15_ES',
            'es',
            'Manejo inicial de traumatismo craneoencefálico',
            PlantaoResponseModelId.trauma),
        PositiveProbe(
            'S15_PT',
            'pt',
            'Manejo inicial de traumatismo cranioencefálico',
            PlantaoResponseModelId.trauma),
        PositiveProbe(
            'S16_ES',
            'es',
            'Parámetros iniciales de ventilación mecánica',
            PlantaoResponseModelId.viaAereaVentilacaoMecanica),
        PositiveProbe(
            'S16_PT',
            'pt',
            'Parâmetros iniciais da ventilação mecânica',
            PlantaoResponseModelId.viaAereaVentilacaoMecanica),
      ];
      expect(p, hasLength(32));
      for (final x in p) {
        final d = PlantaoCanonicalRouteResolver.resolveUserMessage(x.query,
            languageCode: x.lang);
        print(
            '[CANONICAL_TASK_MANIFEST_POSITIVE]|id=${x.id}|model=${d.responseModelId?.wireName ?? "NONE"}|source=${d.decisionSource.name}');
        expect(d.queryShapeDecision.shape, PlantaoQueryShape.clinicalTask,
            reason: x.id);
        expect(d.responseModelId, x.expected, reason: x.id);
        expect(d.contract?.id, x.expected, reason: x.id);
        expect(d.decisionSource,
            PlantaoCanonicalRouteDecisionSource.typedClinicalTaskManifest,
            reason: x.id);
        expect(d.conflictReasons, isEmpty, reason: x.id);
      }
    });

    test('40 negative controls remain fail-closed', () {
      const n = <NegativeProbe>[
        NegativeProbe('N01_PT', 'pt', 'Manejo inicial de pancreatite aguda'),
        NegativeProbe('N01_ES', 'es', 'Manejo inicial de pancreatitis aguda'),
        NegativeProbe('N02_PT', 'pt', 'Manejo inicial de colecistite aguda'),
        NegativeProbe('N02_ES', 'es', 'Manejo inicial de colecistitis aguda'),
        NegativeProbe('N03_PT', 'pt', 'Manejo inicial de meningite bacteriana'),
        NegativeProbe(
            'N03_ES', 'es', 'Manejo inicial de meningitis bacteriana'),
        NegativeProbe('N04_PT', 'pt', 'Manejo inicial de asma grave'),
        NegativeProbe('N04_ES', 'es', 'Manejo inicial de asma grave'),
        NegativeProbe(
            'N05_PT', 'pt', 'Manejo inicial de cetoacidose diabética'),
        NegativeProbe(
            'N05_ES', 'es', 'Manejo inicial de cetoacidosis diabética'),
        NegativeProbe('N06_PT', 'pt', 'Manejo inicial de anafilaxia'),
        NegativeProbe('N06_ES', 'es', 'Manejo inicial de anafilaxia'),
        NegativeProbe('N07_PT', 'pt', 'Manejo inicial de crise convulsiva'),
        NegativeProbe('N07_ES', 'es', 'Manejo inicial de crisis convulsiva'),
        NegativeProbe('N08_PT', 'pt', 'Manejo inicial de pneumonia grave'),
        NegativeProbe('N08_ES', 'es', 'Manejo inicial de neumonía grave'),
        NegativeProbe('N09_PT', 'pt', 'Manejo inicial de apendicite aguda'),
        NegativeProbe('N09_ES', 'es', 'Manejo inicial de apendicitis aguda'),
        NegativeProbe('N10_PT', 'pt', 'Manejo inicial de pielonefrite aguda'),
        NegativeProbe('N10_ES', 'es', 'Manejo inicial de pielonefritis aguda'),
        NegativeProbe('N11_PT', 'pt', 'Manejo inicial de gastrite aguda'),
        NegativeProbe('N11_ES', 'es', 'Manejo inicial de gastritis aguda'),
        NegativeProbe(
            'N12_PT', 'pt', 'Manejo inicial de intoxicação por paracetamol'),
        NegativeProbe(
            'N12_ES', 'es', 'Manejo inicial de intoxicación por paracetamol'),
        NegativeProbe('N13_PT', 'pt', 'Interpretar lactato elevado'),
        NegativeProbe('N13_ES', 'es', 'Interpretar lactato elevado'),
        NegativeProbe('N14_PT', 'pt', 'Efeitos adversos da furosemida'),
        NegativeProbe('N14_ES', 'es', 'Efectos adversos de furosemida'),
        NegativeProbe('N15_PT', 'pt', 'Efeitos adversos da ceftriaxona'),
        NegativeProbe('N15_ES', 'es', 'Efectos adversos de ceftriaxona'),
        NegativeProbe('N16_PT', 'pt', 'Infusão de adrenalina'),
        NegativeProbe('N16_ES', 'es', 'Infusión de adrenalina'),
        NegativeProbe('N17_PT', 'pt', 'Manejo de insuficiência cardíaca aguda'),
        NegativeProbe('N17_ES', 'es', 'Manejo de insuficiencia cardíaca aguda'),
        NegativeProbe(
            'N18_PT', 'pt', 'Tratamento inicial de pneumonia comunitária'),
        NegativeProbe(
            'N18_ES', 'es', 'Tratamiento inicial de neumonía comunitaria'),
        NegativeProbe('N19_PT', 'pt', 'Manejo de dor abdominal aguda'),
        NegativeProbe('N19_ES', 'es', 'Manejo de dolor abdominal agudo'),
        NegativeProbe('N20_PT', 'pt', 'Manejo de febre neutropênica'),
        NegativeProbe('N20_ES', 'es', 'Manejo de fiebre neutropénica'),
      ];
      expect(n, hasLength(40));
      for (final x in n) {
        final d = PlantaoCanonicalRouteResolver.resolveUserMessage(x.query,
            languageCode: x.lang);
        print(
            '[CANONICAL_TASK_MANIFEST_NEGATIVE]|id=${x.id}|shape=${d.queryShapeDecision.shape.name}|model=${d.responseModelId?.wireName ?? "NONE"}|source=${d.decisionSource.name}');
        expect(d.responseModelId, isNull, reason: x.id);
        expect(
            d.decisionSource,
            isNot(
                PlantaoCanonicalRouteDecisionSource.typedClinicalTaskManifest),
            reason: x.id);
      }
    });

    test('unmanifested clinicalTask stays null', () {
      for (final x in const <(String, String)>[
        ('Dosis de amiodarona', 'es'),
        ('Dose de amiodarona', 'pt'),
        ('Contraindicaciones de amiodarona', 'es'),
        ('Contraindicações da amiodarona', 'pt'),
      ]) {
        final d = PlantaoCanonicalRouteResolver.resolveUserMessage(x.$1,
            languageCode: x.$2);
        expect(d.queryShapeDecision.shape, PlantaoQueryShape.clinicalTask,
            reason: x.$1);
        expect(d.responseModelId, isNull, reason: x.$1);
        expect(
            d.decisionSource, PlantaoCanonicalRouteDecisionSource.unadjudicated,
            reason: x.$1);
      }
    });

    test('isolatedDrug rule remains preserved', () {
      final d = PlantaoCanonicalRouteResolver.resolveUserMessage('Amiodarona');
      expect(d.responseModelId, PlantaoResponseModelId.farmacoIsolado);
      expect(d.decisionSource,
          PlantaoCanonicalRouteDecisionSource.typedIsolatedDrug);
    });
  });
}
