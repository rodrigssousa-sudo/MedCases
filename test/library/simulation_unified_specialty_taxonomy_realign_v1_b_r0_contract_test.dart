import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simulation unified specialty taxonomy realign V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/screens/library_screen.dart').readAsStringSync();
    });

    test('hub and search share the same deterministic override map', () {
      expect(
        source,
        contains(
          'MEDCASES_SIMULACOES_UNIFIED_SPECIALTY_TAXONOMY_REALIGN_V1_B_R0',
        ),
      );
      expect(
        source,
        contains('final explicitCategory = _simulationSpecialtyOverrides[id];'),
      );
      expect(
        source,
        contains(
          'final explicitCategory = _simulationSpecialtyOverrides[raw];',
        ),
      );
    });

    test(
      'known Other misclassifications receive clinical specialty owners',
      () {
        const expected = <String, int>{
          'choque_hipovolemico': 0,
          'sindrome_coronariana_sem_st': 1,
          'hemoptise_macica': 3,
          'dengue_manejo': 4,
          'colangite_aguda': 5,
          'crise_adrenal': 6,
          'rabdomiolise_aguda': 7,
          'descolamento_placenta': 9,
          'hemorragia_pos_parto': 9,
          'obstrucao_intestinal': 10,
          'delirium_tremens': 12,
          'mastoidite_aguda': 14,
        };

        for (final entry in expected.entries) {
          expect(
            source,
            contains("'${entry.key}': ${entry.value}"),
            reason: entry.key,
          );
        }
      },
    );

    test('true uncategorized cases remain available to Outros', () {
      expect(source, isNot(contains("'crise_gota':")));
      expect(source, isNot(contains("'priapismo_emergencia':")));
      expect(source, contains("('Outros', 'Otros')"));
    });

    test('unified hub, global search and Toxicologia remain canonical', () {
      expect(
        source,
        contains(
          'MEDCASES_SIMULACOES_UNIFIED_SINGLE_HUB_SPECIALTY_CARDS_V1_B_R0',
        ),
      );
      expect(
        source,
        contains(
          'MEDCASES_SIMULACOES_TOPBAR_GLOBAL_SEARCH_GUIDE_PATTERN_V1_B_R0',
        ),
      );
      expect(source, contains("titlePt: 'Toxicologia'"));
      expect(source, contains("'botulismo_neuroparalitico'"));
      expect(source, contains("'araneismo_latrodectus'"));
    });
  });
}
