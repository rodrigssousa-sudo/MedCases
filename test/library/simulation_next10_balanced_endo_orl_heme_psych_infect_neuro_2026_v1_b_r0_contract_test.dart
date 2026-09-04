import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simulation next10 balanced 2026 V1-B-R0', () {
    late String db;
    const ids = <String>[
      'endocr_coma_mixedematoso',
      'endocr_crise_hipercalcemica',
      'orl_epistaxe_posterior_grave',
      'orl_abscesso_peritonsilar',
      'hemat_sindrome_lise_tumoral',
      'hemat_hemofilia_sangramento_grave',
      'psiqui_catatonia_maligna',
      'psiqui_depressao_psicotica_grave',
      'infect_endocardite_infecciosa_aguda',
      'neuro_miastenia_crise',
    ];
    setUpAll(() {
      db = File('lib/data/protocols_database.dart').readAsStringSync();
    });
    test('10 ids exactly once and baseline remains at least 199', () {
      expect(
        RegExp(r'ProtocolModel\s*\(').allMatches(db).length,
        greaterThanOrEqualTo(199),
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
    });
    test('all cases bilingual rich and referenced', () {
      for (final id in ids) {
        final a = db.indexOf("id: '$id'");
        final s = db.lastIndexOf('ProtocolModel(', a);
        final n = db.indexOf('ProtocolModel(', a + 1);
        final b = db.substring(s, n < 0 ? db.length : n);
        for (final t in <String>[
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
          expect(b, contains(t), reason: '$id -> $t');
        }
      }
    });
    test('high-value safety semantics encoded', () {
      expect(db, contains('Hidrocortisona 100 mg IV 8/8h'));
      expect(db, contains('limitar geralmente a 48–72 h por taquifilaxia'));
      expect(db, contains('ligadura arterial endoscópica ou embolização'));
      expect(db, contains('drenagem por aspiração com agulha ou incisão'));
      expect(db, contains('NÃO dar rasburicase em G6PD deficiente'));
      expect(db, contains('NÃO esperar imagem antes de fator'));
      expect(db, contains('suspender antagonistas dopaminérgicos'));
      expect(db, contains('revisado em janeiro de 2026'));
      expect(db, contains('três grandes razões ESC'));
      expect(db, contains('IVIG ou plasmaférese'));
    });
  });
}
