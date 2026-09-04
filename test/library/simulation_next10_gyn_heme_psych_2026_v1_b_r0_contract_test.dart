import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simulation next10 Gyn Heme Psych 2026 V1-B-R0', () {
    late String db;
    const ids = <String>[
      'obstetr_gravidez_ectopica_rota',
      'obstetr_placenta_previa_hemorragia',
      'obstetr_abortamento_septico',
      'obstetr_distocia_ombro',
      'hemat_pti_sangramento_grave',
      'hemat_ptt_microangiopatia',
      'hemat_reacao_transfusional_hemolitica_aguda',
      'psiqui_primeiro_surto_psicotico',
      'psiqui_episodio_maniaco_agudo',
      'psiqui_crise_suicida_alto_risco',
    ];
    setUpAll(() {
      db = File('lib/data/protocols_database.dart').readAsStringSync();
    });
    test('10 ids exactly once and baseline remains at least 189', () {
      expect(
        RegExp(r'ProtocolModel\s*\(').allMatches(db).length,
        greaterThanOrEqualTo(189),
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
    test('critical 2026 semantics encoded', () {
      expect(db, contains('NÃO usar escala ou classificação baixo/médio/alto'));
      expect(db, contains('ASH 2026'));
      expect(db, contains('ISTH atualizou guideline em 2025'));
      expect(db, contains('RCOG atualizou Green-top 27a em junho de 2026'));
      expect(db, contains('NÃO aplicar pressão fúndica'));
      expect(db, contains('PARAR A TRANSFUSÃO IMEDIATAMENTE'));
      expect(db, contains('NÃO esperar ADAMTS13'));
    });
  });
}
