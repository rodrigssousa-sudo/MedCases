import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/global_scores_batch01_contract.dart';

void main() {
  group('Global scores Batch02 P1 clinical contract', () {
    test('registry recognizes all 10 Batch02 pathologies', () {
      final cases = <String, String>{
        'asma': 'asthma',
        'DPOC': 'copd',
        'hipertensão arterial': 'hypertension',
        'dissecção aórtica': 'aortic_dissection',
        'cirrose e hipertensão portal': 'cirrhosis_portal',
        'síndrome de Cushing': 'cushing',
        'hiperaldosteronismo primário': 'primary_aldosteronism',
        'feocromocitoma / paraganglioma': 'ppgl',
        'osteoporose': 'osteoporosis',
        'hipertensão pulmonar': 'pulmonary_hypertension',
      };

      for (final entry in cases.entries) {
        expect(
          GlobalScoresBatch01Contract.topicForTesting(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('specific hypertension topics beat systemic hypertension', () {
      expect(
        GlobalScoresBatch01Contract.topicForTesting('hipertensão pulmonar'),
        'pulmonary_hypertension',
      );
      expect(
        GlobalScoresBatch01Contract.topicForTesting(
          'hiperaldosteronismo primário em hipertensão arterial',
        ),
        'primary_aldosteronism',
      );
    });

    test('GINA 2026 separates asthma control from severity', () {
      final es = GlobalScoresBatch01Contract.build(lang: 'es', context: 'asma');
      final pt = GlobalScoresBatch01Contract.build(lang: 'pt', context: 'asma');

      expect(es, contains('GS26B02_ASTHMA_CURRENT'));
      expect(es, contains('0 criterios = bien controlada'));
      expect(es, contains('1–2 = parcialmente controlada'));
      expect(es, contains('3–4 = no controlada'));
      expect(es, contains('control NO equivale a gravedad'));
      expect(pt, contains('controle NAO equivale a gravidade'));
      expect(pt, contains('SABA'));
      expect(pt, contains('ICS-formoterol'));
    });

    test('GOLD 2026 grade and ABE axes are separated', () {
      final es = GlobalScoresBatch01Contract.build(lang: 'es', context: 'EPOC');

      expect(es, contains('FEV1/FVC post-broncodilatador <0,70'));
      expect(es, contains('GOLD 1 FEV1 >=80%'));
      expect(es, contains('GOLD 2 50–<80%'));
      expect(es, contains('GOLD 3 30–<50%'));
      expect(es, contains('GOLD 4 <30%'));
      expect(es, contains('>=1 exacerbacion moderada o grave'));
      expect(es, contains('Grupo E'));
      expect(es, contains('CAAT'));
      expect(es, contains('mMRC'));
      expect(es, contains('ABE no sustituye el grado GOLD 1–4'));
    });

    test('ACC AHA 2025 and ESC 2024 hypertension divergence is explicit', () {
      final es = GlobalScoresBatch01Contract.build(
        lang: 'es',
        context: 'hipertension arterial',
      );

      expect(es, contains('ACC/AHA 2025'));
      expect(es, contains('ESC 2024'));
      expect(es, contains('estadio 1 = 130–139 O 80–89'));
      expect(es, contains('hipertension de consultorio >=140/90'));
      expect(es, contains('NO “emergencia hipertensiva”'));
      expect(es, contains('dano agudo de organo diana'));
    });

    test('aortic dissection preserves old and current classifications', () {
      final pt = GlobalScoresBatch01Contract.build(
        lang: 'pt',
        context: 'dissecção aórtica',
      );

      expect(pt, contains('Stanford e DeBakey = HISTORIC_BUT_STILL_USED'));
      expect(pt, contains('hiperaguda <24 h'));
      expect(pt, contains('aguda 1–14 dias'));
      expect(pt, contains('subaguda 15–90 dias'));
      expect(pt, contains('cronica >90 dias'));
      expect(pt, contains('TEM'));
      expect(pt, contains('GERAADA'));
      expect(pt, contains('NAO diagnostico'));
    });

    test('cirrhosis keeps CTP MELD3 and Baveno axes distinct', () {
      final pt = GlobalScoresBatch01Contract.build(
        lang: 'pt',
        context: 'cirrose e hipertensão portal',
      );

      expect(pt, contains('CTP: 5–6=A, 7–9=B, 10–15=C'));
      expect(pt, contains('OPTN MELD 3.0'));
      expect(pt, contains('MELD-Na foi substituido para alocacao OPTN'));
      expect(pt, contains('LSM <=15 kPa + plaquetas >=150x10^9/L'));
      expect(pt, contains('LSM >=25 kPa'));
      expect(pt, contains('risco >=60%'));
    });

    test('Cushing has diagnostic algorithm but no invented severity score', () {
      final es = GlobalScoresBatch01Contract.build(
        lang: 'es',
        context: 'síndrome de Cushing',
      );

      expect(es, contains('no existe un score universal de gravedad'));
      expect(es, contains('UFC al menos 2 mediciones'));
      expect(es, contains('cortisol salival nocturno 2 mediciones'));
      expect(es, contains('DST 1 mg'));
      expect(es, contains('>1,8 mcg/dL'));
      expect(es, contains('ACTH aleatoria NO son pruebas de screening'));
    });

    test('primary aldosteronism treats ARR as assay dependent screening', () {
      final pt = GlobalScoresBatch01Contract.build(
        lang: 'pt',
        context: 'hiperaldosteronismo primário',
      );

      expect(pt, contains('Endocrine Society 2025'));
      expect(pt, contains('aldosterona + renina'));
      expect(pt, contains('ARR >20'));
      expect(pt, contains('>70'));
      expect(pt, contains('dependem de ensaio'));
      expect(pt, contains('NAO sao diagnostico absoluto'));
      expect(pt, contains('AVS'));
      expect(pt, contains('nao inferir por CT isolada'));
    });

    test(
      'PPGL does not use benign malignant or pathology scores as certainty',
      () {
        final es = GlobalScoresBatch01Contract.build(
          lang: 'es',
          context: 'feocromocitoma',
        );

        expect(
          es,
          contains('WHO 2022 abandono la dicotomia simple benigno/maligno'),
        );
        expect(es, contains('PASS'));
        expect(es, contains('GAPP/COPPS'));
        expect(es, contains('LIMITED_USE'));
        expect(es, contains('no por un PASS/GAPP alto aislado'));
      },
    );

    test('osteoporosis separates diagnosis from country specific risk', () {
      final pt = GlobalScoresBatch01Contract.build(
        lang: 'pt',
        context: 'osteoporose',
      );

      expect(pt, contains('normal >=-1'));
      expect(pt, contains('osteoporose <=-2,5'));
      expect(
        pt,
        contains(
          'limiar diagnostico NAO e automaticamente limiar de tratamento',
        ),
      );
      expect(pt, contains('FRAX'));
      expect(pt, contains('especificos por pais'));
      expect(pt, contains('T-score <=-3,5'));
      expect(pt, contains('>=7,5 mg/dia'));
    });

    test(
      'pulmonary hypertension haemodynamics and PAH risk scope are exact',
      () {
        final es = GlobalScoresBatch01Contract.build(
          lang: 'es',
          context: 'hipertension pulmonar',
        );

        expect(es, contains('mPAP >20 mmHg'));
        expect(es, contains('PAWP <=15 + PVR >2 WU'));
        expect(es, contains('PAWP >15 + PVR <=2'));
        expect(es, contains('PAWP >15 + PVR >2'));
        expect(es, contains('WHO-FC I–IV'));
        expect(es, contains('para PAH/HAP (grupo 1), NO para toda PH'));
        expect(es, contains('6MWD >440=1'));
        expect(es, contains('320–440=2'));
        expect(es, contains('165–319=3'));
        expect(es, contains('<165=4'));
        expect(es, contains('NT-proBNP <300/300–649/650–1100/>1100'));
      },
    );

    test('Plantao active classification receives Batch02 contract', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[
          'PROTOCOLO_CLINICO_ATIVO: EPOC',
          'CLASIFICACION_VERIFICADA: contexto local',
        ],
        matchedDrugSummaries: const <String>[],
        userQuery: '¿Y cuál es la clasificación?',
        isFirstMessage: false,
        isPlantaoMode: true,
      );

      expect(prompt, contains('GS26B02_COPD_CURRENT'));
      expect(prompt, contains('[GLOBAL_SCORES_BATCH01_P0_EXPLAINABILITY_V1]'));
    });

    test('contextual classification resolves topic from protocol context', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'pt',
        matchedProtocolSummaries: const <String>[
          'PROTOCOLO_CLINICO_ATIVO: hipertensão pulmonar',
        ],
        matchedDrugSummaries: const <String>[],
        userQuery: 'E qual é a classificação?',
        isFirstMessage: false,
        isPlantaoMode: true,
      );

      expect(prompt, contains('GS26B02_PH_CURRENT'));
    });

    test('Study remains free of Batch02 Plantao contract', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[
          'PROTOCOLO_CLINICO_ATIVO: asma',
        ],
        matchedDrugSummaries: const <String>[],
        userQuery: '¿Cuál es la clasificación?',
        isFirstMessage: false,
        isPlantaoMode: false,
      );

      expect(prompt, isNot(contains('GS26B02_ASTHMA_CURRENT')));
    });

    test(
      'non-classification Plantao query remains free of Batch02 contract',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'es',
          matchedProtocolSummaries: const <String>[
            'PROTOCOLO_CLINICO_ATIVO: hipertension arterial',
          ],
          matchedDrugSummaries: const <String>[],
          userQuery: '¿Y el tratamiento?',
          isFirstMessage: false,
          isPlantaoMode: true,
        );

        expect(prompt, isNot(contains('GS26B02_HTN_CURRENT')));
      },
    );

    test('Batch01 remains fully recognized after Batch02 extension', () {
      expect(
        GlobalScoresBatch01Contract.topicForTesting('cetoacidose diabetica'),
        'dka',
      );
      expect(GlobalScoresBatch01Contract.topicForTesting('sepsis'), 'sepsis');
      expect(
        GlobalScoresBatch01Contract.topicForTesting(
          'coagulacao intravascular disseminada',
        ),
        'dic',
      );
    });
  });
}
