import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simulation next20 high value nonduplicate 2026 V1-B-R0', () {
    late String db;
    late String library;
    const ids = <String>[
      'neuro_guillain_barre_insuficiencia_respiratoria',
      'neuro_hemorragia_subaracnoidea_aneurismatica',
      'endocr_crise_feocromocitoma',
      'endocr_apoplexia_hipofisaria_aguda',
      'orl_epiglotite_adulto',
      'orl_angina_ludwig_via_aerea',
      'hemat_leucostase_hiperleucocitose_aguda',
      'hemat_falciforme_sindrome_toracica_aguda',
      'obstetr_inversao_uterina_aguda',
      'obstetr_corioamnionite_sepse_intraparto',
      'pedi_sepse_neonatal_choque',
      'emerg_golpe_calor_hipertermia_grave',
      'neuro_sindrome_cauda_equina',
      'infect_fasciite_necrosante',
      'infect_artrite_septica_nativa',
      'cardio_tamponamento_cardiaco_agudo',
      'cirurg_isquemia_aguda_membro',
      'cirurg_torcao_testicular_aguda',
      'infect_tetano_generalizado',
      'emerg_hipotermia_acidental_grave',
    ];

    setUpAll(() {
      db = File('lib/data/protocols_database.dart').readAsStringSync();
      library = File('lib/screens/library_screen.dart').readAsStringSync();
    });

    test('20 ids exactly once and global baseline remains at least 220', () {
      expect(
        RegExp(r'ProtocolModel\s*\(').allMatches(db).length,
        greaterThanOrEqualTo(220),
      );
      for (final id in ids) {
        expect(db.split("id: '$id'").length - 1, 1, reason: id);
      }
    });

    test('all 20 cases remain bilingual rich and referenced', () {
      for (final id in ids) {
        final at = db.indexOf("id: '$id'");
        expect(at, greaterThanOrEqualTo(0), reason: id);
        final start = db.lastIndexOf('ProtocolModel(', at);
        final next = db.indexOf('ProtocolModel(', at + 1);
        final block = db.substring(start, next < 0 ? db.length : next);
        for (final token in <String>[
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
          '"pt"',
          '"es"',
          'https://',
        ]) {
          expect(block, contains(token), reason: '$id -> $token');
        }
      }
    });

    test('time-critical safety semantics are encoded', () {
      expect(db, contains('IVIG 0,4 g/kg/dia por 5 dias'));
      expect(db, contains('dentro de 24 h'));
      expect(db, contains('SOMENTE após bloqueio alfa efetivo'));
      expect(db, contains('hidrocortisona 100–200 mg IV'));
      expect(db, contains('não deve atrasar via aérea/antibiótico'));
      expect(db, contains('50–60 mg/kg/dia'));
      expect(db, contains('transfusão de troca automatizada ou manual'));
      expect(db, contains('NÃO remover placenta ainda aderida'));
      expect(db, contains('WHO 2024'));
      expect(db, contains('imersão em água gelada/fria'));
      expect(db, contains('RM urgente'));
      expect(db, contains('Desbridamento cirúrgico urgente'));
      expect(db, contains('Artrocentese'));
      expect(db, contains('pericardiocentese'));
      expect(db, contains('heparina não fracionada IV'));
      expect(db, contains('Orquidopexia contralateral'));
      expect(db, contains('TIG 500 UI IM'));
      expect(db, contains('centro com ECLS'));
    });

    test(
      'six new explicit category overrides are shared by hub and search',
      () {
        const overrides = <String, int>{
          'neuro_guillain_barre_insuficiencia_respiratoria': 2,
          'neuro_hemorragia_subaracnoidea_aneurismatica': 2,
          'neuro_sindrome_cauda_equina': 2,
          'pedi_sepse_neonatal_choque': 8,
          'emerg_golpe_calor_hipertermia_grave': 0,
          'emerg_hipotermia_acidental_grave': 0,
        };
        for (final entry in overrides.entries) {
          expect(
            library.split("'${entry.key}': ${entry.value},").length - 1,
            1,
            reason: entry.key,
          );
        }
        expect(library, contains('_simulationSpecialtyOverrides[id]'));
        expect(library, contains('_simulationSpecialtyOverrides[raw]'));
      },
    );
  });
}
