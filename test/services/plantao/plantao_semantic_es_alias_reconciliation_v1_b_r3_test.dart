import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_pipeline.dart';

String matrixFor(PlantaoQueryAnalysis qa, String lang) {
  final mandate = PlantaoIntentEngine.buildIntentMandateV2(qa, lang);
  return RegExp(
        r'USE EXCLUSIVAMENTE A MATRIZ\s+(\d+)',
        caseSensitive: false,
      ).firstMatch(mandate)?.group(1) ??
      'UNRESOLVED';
}

bool specialTemplateFor(PlantaoQueryAnalysis qa, String lang) {
  return PlantaoIntentEngine.buildIntentMandateV2(
    qa,
    lang,
  ).contains('TEMPLATE FARMACOLÓGICO');
}

void expectParity(String esText, String ptText) {
  final es = PlantaoIntentEngine.analyze(esText);
  final pt = PlantaoIntentEngine.analyze(ptText);

  expect(es.primaryIntent, pt.primaryIntent, reason: '$esText × $ptText');
  expect(es.clinicalContext, pt.clinicalContext, reason: '$esText × $ptText');
  expect(es.clinicalTopic, pt.clinicalTopic, reason: '$esText × $ptText');
  expect(matrixFor(es, 'es'), matrixFor(pt, 'pt'), reason: '$esText × $ptText');
  expect(
    specialTemplateFor(es, 'es'),
    specialTemplateFor(pt, 'pt'),
    reason: '$esText × $ptText',
  );
}

void main() {
  group('Plantao semantic ES alias reconciliation V1-B-R3', () {
    test('the 9 audited ES/PT mismatches converge', () {
      const pairs = <(String, String)>[
        (
          'Manejo de fibrilación auricular inestable',
          'Manejo de fibrilação atrial instável',
        ),
        (
          'Interpretación de acidosis metabólica en gasometría',
          'Interpretação de acidose metabólica na gasometria',
        ),
        (
          'Intoxicación por paracetamol',
          'Intoxicação por paracetamol',
        ),
        (
          'Manejo de ACV isquémico agudo',
          'Manejo de AVC isquêmico agudo',
        ),
        (
          'Parámetros iniciales de ventilación mecánica',
          'Parâmetros iniciais da ventilação mecânica',
        ),
        (
          'Manejo de lesión renal aguda KDIGO 2',
          'Manejo de lesão renal aguda KDIGO 2',
        ),
        (
          'Emergencia hipertensiva con lesión de órgano diana',
          'Emergência hipertensiva com lesão de órgão-alvo',
        ),
        (
          'Infusión de noradrenalina en shock',
          'Infusão de noradrenalina em choque',
        ),
        (
          'Dolor torácico agudo con sospecha de infarto',
          'Dor torácica aguda com suspeita de infarto',
        ),
      ];

      var mismatches = 0;

      for (final pair in pairs) {
        final es = PlantaoIntentEngine.analyze(pair.$1);
        final pt = PlantaoIntentEngine.analyze(pair.$2);

        final same = es.primaryIntent == pt.primaryIntent &&
            es.clinicalContext == pt.clinicalContext &&
            es.clinicalTopic == pt.clinicalTopic &&
            matrixFor(es, 'es') == matrixFor(pt, 'pt') &&
            specialTemplateFor(es, 'es') == specialTemplateFor(pt, 'pt');

        if (!same) mismatches++;

        print(
          '[R3_ES_PARITY]'
          '|es=${pair.$1}'
          '|pt=${pair.$2}'
          '|esIntent=${es.primaryIntent.name}'
          '|ptIntent=${pt.primaryIntent.name}'
          '|esContext=${es.clinicalContext.name}'
          '|ptContext=${pt.clinicalContext.name}'
          '|esTopic=${es.clinicalTopic}'
          '|ptTopic=${pt.clinicalTopic}'
          '|esMatrix=${matrixFor(es, "es")}'
          '|ptMatrix=${matrixFor(pt, "pt")}'
          '|esSpecial=${specialTemplateFor(es, "es")}'
          '|ptSpecial=${specialTemplateFor(pt, "pt")}'
          '|same=$same',
        );

        expectParity(pair.$1, pair.$2);
      }

      print(
          '[R3_ES_PARITY_SUMMARY]|pairs=${pairs.length}|mismatches=$mismatches');
      expect(mismatches, 0);
    });

    test('acidosis no longer produces false dose intent from dosis substring',
        () {
      final qa = PlantaoIntentEngine.analyze(
        'Interpretación de acidosis metabólica en gasometría',
      );

      expect(qa.primaryIntent, PlantaoIntent.interpretacao);
      expect(qa.primaryIntent, isNot(PlantaoIntent.dose));
      expect(matrixFor(qa, 'es'), '20');
    });

    test('real Spanish dosis remains a dose intent', () {
      final qa = PlantaoIntentEngine.analyze(
        'Dosis de amiodarona',
      );

      expect(qa.primaryIntent, PlantaoIntent.dose);
    });

    test('ACV token works alone without substring normalization', () {
      final qa = PlantaoIntentEngine.analyze('ACV isquémico agudo');

      expect(qa.clinicalContext, PlantaoContext.neurologia);
      expect(qa.clinicalTopic, 'AVC ISQUÊMICO');
      expect(matrixFor(qa, 'es'), '11');
    });

    test('Spanish infusion resolves to infusion intent', () {
      final qa = PlantaoIntentEngine.analyze(
        'Infusión de noradrenalina en shock',
      );

      expect(qa.primaryIntent, PlantaoIntent.infusao);
      expect(matrixFor(qa, 'es'), '3');
      expect(specialTemplateFor(qa, 'es'), isFalse);
    });

    test('isolated-drug heuristic is intentionally not fixed in R3', () {
      final tep = PlantaoIntentEngine.analyze('TEP');
      final mandate = PlantaoIntentEngine.buildIntentMandateV2(tep, 'es');

      // Observational regression guard only: query-shape adjudication is a
      // separate front and must not be silently changed by lexical parity.
      print(
        '[R3_QUERY_SHAPE_BACKLOG]'
        '|query=TEP'
        '|intent=${tep.primaryIntent.name}'
        '|context=${tep.clinicalContext.name}'
        '|topic=${tep.clinicalTopic}'
        '|special=${mandate.contains("TEMPLATE FARMACOLÓGICO")}',
      );
    });
  });
}
