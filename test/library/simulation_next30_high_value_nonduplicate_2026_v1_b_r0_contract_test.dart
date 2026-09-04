import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simulation next30 high value nonduplicate 2026 V1-B-R0', () {
    late String db;
    late String library;
    const ids = <String>[
      'nefro_glomerulonefrite_rapidamente_progressiva',
      'nefro_infarto_renal_agudo',
      'nefro_uropatia_obstrutiva_anuria',
      'nefro_peritonite_dialise_peritoneal',
      'nefro_sindrome_nefrotica_trombose',
      'psiqui_mania_aguda_grave_psicotica',
      'psiqui_anorexia_instabilidade_medica',
      'obstetr_rotura_uterina_aguda',
      'obstetr_embolia_liquido_amniotico',
      'gineco_torcao_ovariana_aguda',
      'hemat_trombocitopenia_induzida_heparina_trombose',
      'hemat_reacao_hemolitica_transfusional_aguda',
      'oftalmo_glaucoma_agudo_angulo_fechado',
      'oftalmo_oclusao_arteria_central_retina',
      'infect_celulite_orbitaria',
      'orl_abscesso_retrofaringeo',
      'endocr_sindrome_realimentacao_grave',
      'endocr_hiponatremia_sintomatica_grave_siad',
      'neuro_porfiria_aguda_intermitente_crise',
      'pedi_corpo_estranho_via_aerea',
      'pedi_cetoacidose_diabetica_edema_cerebral',
      'pedi_kawasaki_choque',
      'pedi_desidratacao_grave_choque',
      'pedi_hiperbilirrubinemia_encefalopatia_aguda',
      'cardio_rotura_musculo_papilar_pos_iam',
      'cardio_comunicacao_interventricular_pos_iam',
      'cardio_trombose_protese_valvar',
      'cardio_insuficiencia_aortica_aguda_grave',
      'neuro_trombose_venosa_cerebral',
      'infect_abscesso_epidural_espinhal',
    ];

    setUpAll(() {
      db = File('lib/data/protocols_database.dart').readAsStringSync();
      library = File('lib/screens/library_screen.dart').readAsStringSync();
    });

    test(
      '30 selected ids exist exactly once and total reaches at least 250',
      () {
        expect(
          RegExp(r'ProtocolModel\s*\(').allMatches(db).length,
          greaterThanOrEqualTo(250),
        );
        for (final id in ids) {
          expect(
            RegExp(
              "id: ['\\\"]" + RegExp.escape(id) + "['\\\"]",
            ).allMatches(db).length,
            1,
            reason: id,
          );
        }
      },
    );

    test('all 30 are bilingual rich and referenced', () {
      for (final id in ids) {
        final a = db.indexOf("id: '$id'");
        final s = db.lastIndexOf('ProtocolModel(', a);
        final n = db.indexOf('ProtocolModel(', a + 1);
        final b = db.substring(s, n < 0 ? db.length : n);
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
          expect(b, contains(token), reason: '$id -> $token');
        }
        expect(
          b.contains('recognize: {"pt": ['),
          isFalse,
          reason: '$id recognize must be Map<String,String>',
        );
        expect(
          b.contains('recognize: {"pt": "'),
          isTrue,
          reason: '$id recognize string schema',
        );
        expect(
          b.contains('references: {"pt": ['),
          isTrue,
          reason: '$id references must be Map<String,List<String>>',
        );
      }
    });

    test('critical clinical semantics are encoded', () {
      for (final token in <String>[
        'plasmaférese',
        'descompressão urgente',
        'intraperitoneal',
        'Valproato',
        'Laparotomia',
        'trombólise',
        'IVIG 2 g/kg',
        'manitol 0,5–1 g/kg',
        'salina 3% 2,5–5 mL/kg',
        'exsanguineotransfusão',
        'cirurgia mitral emergencial',
        'IABP',
        'prótese mecânica',
        'NÃO usar IABP',
        'LMWH',
        'RM com gadolínio urgente',
      ]) {
        expect(db, contains(token), reason: token);
      }
    });

    test('required new taxonomy overrides exist exactly once', () {
      const overrides = <String, int>{
        'endocr_hiponatremia_sintomatica_grave_siad': 6,
        'neuro_porfiria_aguda_intermitente_crise': 2,
        'neuro_trombose_venosa_cerebral': 2,
        'infect_abscesso_epidural_espinhal': 2,
        'oftalmo_glaucoma_agudo_angulo_fechado': 14,
        'oftalmo_oclusao_arteria_central_retina': 14,
        'infect_celulite_orbitaria': 14,
        'pedi_corpo_estranho_via_aerea': 8,
        'pedi_cetoacidose_diabetica_edema_cerebral': 8,
        'pedi_kawasaki_choque': 8,
        'pedi_desidratacao_grave_choque': 8,
        'pedi_hiperbilirrubinemia_encefalopatia_aguda': 8,
      };
      for (final e in overrides.entries) {
        expect(
          RegExp(
            "'" +
                RegExp.escape(e.key) +
                "'\\s*:\\s*" +
                e.value.toString() +
                "\\s*,",
          ).allMatches(library).length,
          1,
          reason: e.key,
        );
      }
      expect(library, contains('_simulationSpecialtyOverrides[id]'));
      expect(library, contains('_simulationSpecialtyOverrides[raw]'));
    });
  });
}
