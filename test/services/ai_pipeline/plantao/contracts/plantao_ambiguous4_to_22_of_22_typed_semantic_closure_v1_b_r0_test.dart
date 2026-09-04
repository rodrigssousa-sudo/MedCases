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
  final PlantaoResponseModelId expected;
  const P(this.group, this.id, this.lang, this.q, this.expected);
}

void main() {
  group('Ambiguous4 -> 22/22 typed semantic closure V1-B-R0', () {
    test('32 target variants route by typed semantic family', () {
      const probes = <P>[
        P('M07', 'M07_SEED_ES', 'es', 'Antibiótico para neumonía grave',
            PlantaoResponseModelId.antibioticoterapia),
        P('M07', 'M07_SEED_PT', 'pt', 'Antibiótico para pneumonia grave',
            PlantaoResponseModelId.antibioticoterapia),
        P(
            'M07',
            'M07_CAP_ES',
            'es',
            'Antibiótico empírico para neumonía adquirida en la comunidad',
            PlantaoResponseModelId.antibioticoterapia),
        P(
            'M07',
            'M07_CAP_PT',
            'pt',
            'Antibiótico empírico para pneumonia adquirida na comunidade',
            PlantaoResponseModelId.antibioticoterapia),
        P(
            'M07',
            'M07_HAP_ES',
            'es',
            'Antibioticoterapia para neumonía hospitalaria',
            PlantaoResponseModelId.antibioticoterapia),
        P(
            'M07',
            'M07_HAP_PT',
            'pt',
            'Antibioticoterapia para pneumonia hospitalar',
            PlantaoResponseModelId.antibioticoterapia),
        P(
            'M07',
            'M07_MENINGITIS_ES',
            'es',
            'Antibiótico empírico para meningitis bacteriana',
            PlantaoResponseModelId.antibioticoterapia),
        P(
            'M07',
            'M07_MENINGITIS_PT',
            'pt',
            'Antibiótico empírico para meningite bacteriana',
            PlantaoResponseModelId.antibioticoterapia),
        P('M13', 'M13_SEED_ES', 'es', 'Disnea aguda con edema pulmonar',
            PlantaoResponseModelId.dispneiaAguda),
        P('M13', 'M13_SEED_PT', 'pt', 'Dispneia aguda com edema pulmonar',
            PlantaoResponseModelId.dispneiaAguda),
        P('M13', 'M13_HYPOX_ES', 'es', 'Disnea aguda con hipoxemia',
            PlantaoResponseModelId.dispneiaAguda),
        P('M13', 'M13_HYPOX_PT', 'pt', 'Dispneia aguda com hipoxemia',
            PlantaoResponseModelId.dispneiaAguda),
        P('M13', 'M13_DYSPNEA_ES', 'es', 'Paciente con disnea súbita',
            PlantaoResponseModelId.dispneiaAguda),
        P('M13', 'M13_DYSPNEA_PT', 'pt', 'Paciente com dispneia súbita',
            PlantaoResponseModelId.dispneiaAguda),
        P(
            'M13',
            'M13_PULM_EDEMA_ES',
            'es',
            'Edema agudo de pulmón con disnea intensa',
            PlantaoResponseModelId.dispneiaAguda),
        P(
            'M13',
            'M13_PULM_EDEMA_PT',
            'pt',
            'Edema agudo de pulmão com dispneia intensa',
            PlantaoResponseModelId.dispneiaAguda),
        P('M18', 'M18_SEED_ES', 'es', 'Hemorragia digestiva alta grave',
            PlantaoResponseModelId.hemorragia),
        P('M18', 'M18_SEED_PT', 'pt', 'Hemorragia digestiva alta grave',
            PlantaoResponseModelId.hemorragia),
        P('M18', 'M18_UGIB_ES', 'es', 'Sangrado digestivo alto con hematemesis',
            PlantaoResponseModelId.hemorragia),
        P(
            'M18',
            'M18_UGIB_PT',
            'pt',
            'Sangramento digestivo alto com hematêmese',
            PlantaoResponseModelId.hemorragia),
        P(
            'M18',
            'M18_LGIB_ES',
            'es',
            'Hemorragia digestiva baja con inestabilidad',
            PlantaoResponseModelId.hemorragia),
        P(
            'M18',
            'M18_LGIB_PT',
            'pt',
            'Hemorragia digestiva baixa com instabilidade',
            PlantaoResponseModelId.hemorragia),
        P(
            'M18',
            'M18_MASSIVE_ES',
            'es',
            'Sangrado activo grave con shock hemorrágico',
            PlantaoResponseModelId.hemorragia),
        P(
            'M18',
            'M18_MASSIVE_PT',
            'pt',
            'Sangramento ativo grave com choque hemorrágico',
            PlantaoResponseModelId.hemorragia),
        P('M21', 'M21_SEED_ES', 'es', 'Resumen clínico de pancreatitis aguda',
            PlantaoResponseModelId.consultaClinicaGeral),
        P('M21', 'M21_SEED_PT', 'pt', 'Resumo clínico de pancreatite aguda',
            PlantaoResponseModelId.consultaClinicaGeral),
        P('M21', 'M21_CHOLE_ES', 'es', 'Resumen clínico de colecistitis aguda',
            PlantaoResponseModelId.consultaClinicaGeral),
        P('M21', 'M21_CHOLE_PT', 'pt', 'Resumo clínico de colecistite aguda',
            PlantaoResponseModelId.consultaClinicaGeral),
        P('M21', 'M21_APPEND_ES', 'es', 'Resumen clínico de apendicitis aguda',
            PlantaoResponseModelId.consultaClinicaGeral),
        P('M21', 'M21_APPEND_PT', 'pt', 'Resumo clínico de apendicite aguda',
            PlantaoResponseModelId.consultaClinicaGeral),
        P(
            'M21',
            'M21_SYNDROME_ES',
            'es',
            'Resumen clínico de síndrome nefrótico',
            PlantaoResponseModelId.consultaClinicaGeral),
        P(
            'M21',
            'M21_SYNDROME_PT',
            'pt',
            'Resumo clínico de síndrome nefrótica',
            PlantaoResponseModelId.consultaClinicaGeral),
      ];

      expect(probes, hasLength(32));

      for (final p in probes) {
        final a = PlantaoIntentEngine.analyze(p.q);
        final s = PlantaoQueryShapeResolver.resolve(a);
        final c = PlantaoCanonicalRouteResolver.resolveAnalysis(
          a,
          languageCode: p.lang,
        );

        expect(c.responseModelId, p.expected, reason: p.id);
        expect(
          c.decisionSource,
          PlantaoCanonicalRouteDecisionSource.typedSemanticFamilyManifest,
          reason: p.id,
        );
        expect(c.contract, isNotNull, reason: p.id);

        if (p.group == 'M07') {
          expect(
            s.clinicalInformationTasks,
            contains(PlantaoClinicalInformationTask.antibioticotherapy),
            reason: p.id,
          );
          expect(s.shape, PlantaoQueryShape.clinicalTask, reason: p.id);
        } else if (p.group == 'M13') {
          expect(
            s.clinicalTopicDomains,
            contains(PlantaoClinicalTopicDomainSignal.acuteDyspnea),
            reason: p.id,
          );
          expect(s.shape, PlantaoQueryShape.clinicalTopicOnly, reason: p.id);
        } else if (p.group == 'M18') {
          expect(
            s.clinicalTopicDomains,
            contains(PlantaoClinicalTopicDomainSignal.hemorrhage),
            reason: p.id,
          );
          expect(s.shape, PlantaoQueryShape.clinicalTopicOnly, reason: p.id);
        } else if (p.group == 'M21') {
          expect(
            s.clinicalInformationTasks,
            contains(PlantaoClinicalInformationTask.clinicalSummary),
            reason: p.id,
          );
          expect(s.shape, PlantaoQueryShape.clinicalTask, reason: p.id);
        }
      }
    });

    test('hard semantic precedence does not misroute', () {
      const probes = <P>[
        P('H', 'H01_ES', 'es', 'Antibiótico para sepsis',
            PlantaoResponseModelId.sepseChoqueSeptico),
        P('H', 'H01_PT', 'pt', 'Antibiótico para sepse',
            PlantaoResponseModelId.sepseChoqueSeptico),
        P('H', 'H02_ES', 'es', 'Resumen clínico de TEP',
            PlantaoResponseModelId.casoClinicoEmergencia),
        P('H', 'H02_PT', 'pt', 'Resumo clínico de TEP',
            PlantaoResponseModelId.casoClinicoEmergencia),
        P('H', 'H03_ES', 'es', 'Disnea aguda por TEP',
            PlantaoResponseModelId.casoClinicoEmergencia),
        P('H', 'H03_PT', 'pt', 'Dispneia aguda por TEP',
            PlantaoResponseModelId.casoClinicoEmergencia),
        P('H', 'H04_ES', 'es', 'Manejo de trauma con hemorragia grave',
            PlantaoResponseModelId.trauma),
        P('H', 'H04_PT', 'pt', 'Manejo de trauma com hemorragia grave',
            PlantaoResponseModelId.trauma),
      ];

      for (final p in probes) {
        final c = PlantaoCanonicalRouteResolver.resolveUserMessage(
          p.q,
          languageCode: p.lang,
        );

        expect(
          c.responseModelId == PlantaoResponseModelId.antibioticoterapia,
          isFalse,
          reason: p.id,
        );
        expect(
          c.responseModelId == PlantaoResponseModelId.dispneiaAguda,
          isFalse,
          reason: p.id,
        );
        expect(
          c.responseModelId == PlantaoResponseModelId.hemorragia,
          isFalse,
          reason: p.id,
        );
        expect(
          c.responseModelId == PlantaoResponseModelId.consultaClinicaGeral,
          isFalse,
          reason: p.id,
        );
      }
    });
  });
}
