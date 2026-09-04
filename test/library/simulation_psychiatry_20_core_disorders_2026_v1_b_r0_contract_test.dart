import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String protocolBlock(String protocols, String id) {
  final at = protocols.indexOf("id: '$id'");
  expect(at, greaterThanOrEqualTo(0), reason: id);
  final start = protocols.lastIndexOf('ProtocolModel(', at);
  final next = protocols.indexOf('\n  ProtocolModel(', at);
  return protocols.substring(start, next < 0 ? protocols.length : next);
}

void main() {
  group('Psychiatry 20 core disorders 2026 V1-B-R2', () {
    late String protocols;
    late String library;

    const ids = <String>[
      "psiqui_esquizofrenia_recaida_psicotica",
      "psiqui_transtorno_esquizoafetivo",
      "psiqui_depressao_maior",
      "psiqui_bipolar_episodio_depressivo",
      "psiqui_bipolar_episodio_misto",
      "psiqui_ansiedade_generalizada",
      "psiqui_transtorno_panico",
      "psiqui_ansiedade_social",
      "psiqui_toc_grave",
      "psiqui_tept",
      "psiqui_tdah_adulto",
      "psiqui_tdah_infantojuvenil",
      "psiqui_tea_avaliacao",
      "psiqui_borderline_crise",
      "psiqui_bulimia_nervosa",
      "psiqui_compulsao_alimentar",
      "psiqui_depressao_pos_parto",
      "psiqui_psicose_pos_parto",
      "psiqui_psicose_induzida_substancias",
      "psiqui_transtorno_uso_alcool",
    ];

    const semantic = <String, String>{
      "psiqui_esquizofrenia_recaida_psicotica": "clozapina",
      "psiqui_bipolar_episodio_depressivo": "quetiapina",
      "psiqui_bipolar_episodio_misto": "valproato",
      "psiqui_toc_grave": "ERP",
      "psiqui_tept": "EMDR",
      "psiqui_tdah_adulto": "dois ou mais contextos",
      "psiqui_tea_avaliacao": "características centrais",
      "psiqui_borderline_crise": "DBT",
      "psiqui_bulimia_nervosa": "bupropiona",
      "psiqui_psicose_pos_parto": "emergência psiquiátrica",
      "psiqui_transtorno_uso_alcool": "naltrexona",
    };

    setUpAll(() {
      protocols = File('lib/data/protocols_database.dart').readAsStringSync();
      library = File('lib/screens/library_screen.dart').readAsStringSync();
    });

    test(
      '20 new ids are unique, psychiatry-prefixed and total is future-proof >=270',
      () {
        final total = RegExp(
          r'^\s*ProtocolModel\(',
          multiLine: true,
        ).allMatches(protocols).length;
        expect(total, greaterThanOrEqualTo(270));
        expect(ids, hasLength(20));
        expect(ids.toSet(), hasLength(20));
        for (final id in ids) {
          expect(id.startsWith('psiqui_'), isTrue, reason: id);
          expect("id: '$id'".allMatches(protocols).length, 1, reason: id);
        }
      },
    );

    test(
      'all 20 are bilingual rich clinical protocols with exact model schemas',
      () {
        const required = <String>[
          'title:',
          'severity:',
          'definition:',
          'physiopathology:',
          'recognize:',
          'redFlags:',
          'differentialDiagnosis:',
          'exams:',
          'objectives:',
          'actions:',
          'monitoring:',
          'complications:',
          'doNotDo:',
          'pearls:',
          'references:',
          'avoid:',
          'drugs:',
        ];

        for (final id in ids) {
          final block = protocolBlock(protocols, id);
          for (final token in required) {
            expect(block, contains(token), reason: '$id -> $token');
          }
          expect(block, contains('"pt"'), reason: '$id PT');
          expect(block, contains('"es"'), reason: '$id ES');
          expect(
            block,
            contains('recognize: {"pt": "'),
            reason: '$id recognize Map<String,String>',
          );
          expect(
            block.contains('recognize: {"pt": <String>['),
            isFalse,
            reason: '$id recognize must not be list',
          );
          expect(
            block,
            contains('references: {"pt": <String>['),
            reason: '$id references Map<String,List<String>>',
          );
          expect(
            'https://'.allMatches(block).length,
            greaterThanOrEqualTo(4),
            reason: '$id >=2 URLs per language',
          );
        }
      },
    );

    test('high-value psychiatric safety semantics are encoded', () {
      for (final entry in semantic.entries) {
        final block = protocolBlock(protocols, entry.key);
        expect(block, contains(entry.value), reason: entry.key);
      }
    });

    test(
      'TEPT false-positive TEP substring is explicitly owned by Psychiatry',
      () {
        final mapStart = library.indexOf(
          'const Map<String, int> _simulationSpecialtyOverrides',
        );
        final mapEnd = library.indexOf(
          'String _normalizeSimulationSearch',
          mapStart,
        );
        expect(mapStart, greaterThanOrEqualTo(0));
        expect(mapEnd, greaterThan(mapStart));
        final overrideMap = library.substring(mapStart, mapEnd);
        expect(overrideMap, contains("'psiqui_tept': 12,"));
        expect(overrideMap, isNot(contains("'psiqui_tept': 3,")));
      },
    );
  });
}
