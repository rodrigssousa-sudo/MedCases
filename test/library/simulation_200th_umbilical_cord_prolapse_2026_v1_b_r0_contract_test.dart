import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simulation 200th umbilical cord prolapse 2026 V1-B-R0', () {
    late String db;

    setUpAll(() {
      db = File('lib/data/protocols_database.dart').readAsStringSync();
    });

    test(
      '200th case exists exactly once and global baseline remains at least 200',
      () {
        expect(
          RegExp(r'ProtocolModel\s*\(').allMatches(db).length,
          greaterThanOrEqualTo(200),
        );
        expect(
          RegExp(
            "id: ['\\\"]obstetr_prolapso_cordao_umbilical['\\\"]",
          ).allMatches(db).length,
          1,
        );
      },
    );

    test('case is bilingual rich and safety-complete', () {
      final a = db.indexOf("id: 'obstetr_prolapso_cordao_umbilical'");
      expect(a, greaterThanOrEqualTo(0));
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
        'drugsConditional:',
        'monitoring:',
        'complications:',
        'doNotDo:',
        'pearls:',
        'references:',
        '"pt"',
        '"es"',
        'https://',
      ]) {
        expect(b, contains(t), reason: t);
      }
    });

    test('cord prolapse emergency semantics are encoded', () {
      expect(db, contains('PROLAPSO DE CORDÃO'));
      expect(db, contains('elevação da apresentação'));
      expect(db, contains('500–750 mL'));
      expect(db, contains('terbutalina 0,25 mg SC'));
      expect(db, contains('categoria 1 visando nascimento em até 30 minutos'));
      expect(db, contains('NÃO empurrar o cordão de volta'));
      expect(db, contains('revisado em dezembro de 2024'));
    });
  });
}
