import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/global_scores_batch01_contract.dart';

void main() {
  group('Global scores Batch01 P0 clinical contract', () {
    test('registry recognizes all 10 Batch01 pathologies', () {
      final cases = <String, String>{
        'cetoacidosis diabetica': 'dka',
        'acute ischemic stroke': 'ais',
        'sepsis con shock septico': 'sepsis',
        'status epilepticus': 'status',
        'purpura trombocitopenica trombotica': 'ttp',
        'acute respiratory distress syndrome': 'ards',
        'preeclampsia': 'preeclampsia',
        'neonatal sepsis': 'neonatal_sepsis',
        'hemorragia intracerebral': 'ich',
        'coagulacion intravascular diseminada': 'dic',
      };

      for (final entry in cases.entries) {
        expect(
          GlobalScoresBatch01Contract.topicForTesting(entry.key),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('neonatal sepsis specificity beats generic sepsis', () {
      expect(
        GlobalScoresBatch01Contract.topicForTesting(
          'neonatal sepsis early onset',
        ),
        'neonatal_sepsis',
      );
    });

    test('Spanish contracts contain explainability and no inference', () {
      final result = GlobalScoresBatch01Contract.build(
        lang: 'es',
        context: 'sepsis con shock septico',
      );

      expect(result, contains('[GLOBAL_SCORES_BATCH01_P0_EXPLAINABILITY_V1]'));
      expect(result, contains('GS26B01_SEPSIS_CURRENT'));
      expect(result, contains('POR QUE ESTE PACIENTE'));
      expect(result, contains('DATOS FALTANTES'));
      expect(result, contains('NO calcular ni inferir'));
      expect(result, contains('qSOFA NO diagnostica sepsis'));
    });

    test('Portuguese contracts contain explainability and no inference', () {
      final result = GlobalScoresBatch01Contract.build(
        lang: 'pt',
        context: 'cetoacidose diabetica',
      );

      expect(result, contains('[GLOBAL_SCORES_BATCH01_P0_EXPLAINABILITY_V1]'));
      expect(result, contains('GS26B01_DKA_CURRENT'));
      expect(result, contains('POR QUE ESTE PACIENTE'));
      expect(result, contains('DADOS FALTANTES'));
      expect(result, contains('NAO calcular nem inferir'));
    });

    test('DKA exact thresholds and missing variables are explicit', () {
      final pt = GlobalScoresBatch01Contract.build(
        lang: 'pt',
        context: 'cetoacidose diabetica',
      );

      expect(pt, contains('glicose >=200 mg/dL'));
      expect(pt, contains('beta-hidroxibutirato >=3,0 mmol/L'));
      expect(pt, contains('pH <7,30'));
      expect(pt, contains('HCO3 15–18'));
      expect(pt, contains('HCO3 10–<15'));
      expect(pt, contains('pH <7,0'));
      expect(
        pt,
        contains(
          'historia de diabetes/glicose, cetonas/beta-hidroxibutirato e pH/bicarbonato',
        ),
      );
    });

    test('DIC 2025 boundaries are explicit', () {
      final result = GlobalScoresBatch01Contract.build(
        lang: 'es',
        context: 'coagulacion intravascular diseminada',
      );

      expect(result, contains('plaquetas <50=2'));
      expect(result, contains('50–<100=1'));
      expect(result, contains('D-dimero >7x ULN=3'));
      expect(result, contains('>3x ULN=2'));
      expect(result, contains('PT >=6 s=2'));
      expect(result, contains('>=3–<6 s=1'));
      expect(result, contains('fibrinogeno <100 mg/dL=1'));
      expect(result, contains('total >=5'));
      expect(result, contains('SIC'));
    });

    test('semantic hazards are blocked by topic contract', () {
      final sepsis = GlobalScoresBatch01Contract.build(
        lang: 'es',
        context: 'sepsis',
      );
      final ttp = GlobalScoresBatch01Contract.build(lang: 'es', context: 'TTP');
      final ais = GlobalScoresBatch01Contract.build(
        lang: 'es',
        context: 'acute ischemic stroke',
      );
      final ich = GlobalScoresBatch01Contract.build(
        lang: 'es',
        context: 'hemorragia intracerebral',
      );
      final pre = GlobalScoresBatch01Contract.build(
        lang: 'es',
        context: 'preeclampsia',
      );
      final neo = GlobalScoresBatch01Contract.build(
        lang: 'es',
        context: 'neonatal sepsis',
      );

      expect(sepsis, contains('qSOFA NO diagnostica sepsis'));
      expect(ttp, contains('NO confirman TTP'));
      expect(ais, contains('Ninguno confirma el diagnostico'));
      expect(ich, contains('NO debe ser la unica base'));
      expect(pre, contains('ISSHP 2021 recomienda'));
      expect(neo, contains('No existe un score universal'));
    });

    test('Plantao classification prompt receives current Batch01 contract', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[
          'PROTOCOLO_CLINICO_ATIVO: sepsis con shock septico',
          'CLASIFICACION_VERIFICADA: contexto local',
        ],
        matchedDrugSummaries: const <String>[],
        userQuery: '¿Y cuál es la clasificación?',
        isFirstMessage: false,
        isPlantaoMode: true,
      );

      expect(prompt, contains('[GLOBAL_SCORES_BATCH01_P0_EXPLAINABILITY_V1]'));
      expect(prompt, contains('GS26B01_SEPSIS_CURRENT'));
    });

    test(
      'contextual follow-up can resolve pathology from protocol summaries',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'pt',
          matchedProtocolSummaries: const <String>[
            'PROTOCOLO_CLINICO_ATIVO: cetoacidose diabetica',
          ],
          matchedDrugSummaries: const <String>[],
          userQuery: 'E qual é a classificação?',
          isFirstMessage: false,
          isPlantaoMode: true,
        );

        expect(prompt, contains('GS26B01_DKA_CURRENT'));
      },
    );

    test('Study does not receive Batch01 Plantao classification contract', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[
          'PROTOCOLO_CLINICO_ATIVO: sepsis',
        ],
        matchedDrugSummaries: const <String>[],
        userQuery: '¿Cuál es la clasificación?',
        isFirstMessage: false,
        isPlantaoMode: false,
      );

      expect(
        prompt,
        isNot(contains('[GLOBAL_SCORES_BATCH01_P0_EXPLAINABILITY_V1]')),
      );
    });

    test(
      'non-classification Plantao query does not receive Batch01 contract',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'es',
          matchedProtocolSummaries: const <String>[
            'PROTOCOLO_CLINICO_ATIVO: sepsis',
          ],
          matchedDrugSummaries: const <String>[],
          userQuery: '¿Y el tratamiento?',
          isFirstMessage: false,
          isPlantaoMode: true,
        );

        expect(
          prompt,
          isNot(contains('[GLOBAL_SCORES_BATCH01_P0_EXPLAINABILITY_V1]')),
        );
      },
    );

    test('pre-existing classification transport remains in AppProvider', () {
      final app = File('lib/providers/app_provider.dart').readAsStringSync();
      expect(app, contains('PLANTAO_GLOBAL_CLASSIFICATION_TRANSPORT_V1'));
      expect(app, contains('CLASSIFICACAO_VERIFICADA'));
      expect(app, contains('CLASIFICACION_VERIFICADA'));
      expect(app, contains('CRITERIOS_DE_GRAVIDADE'));
      expect(app, contains('CRITERIOS_DE_GRAVEDAD'));
    });
  });
}
