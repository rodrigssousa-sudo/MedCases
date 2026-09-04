import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simulation 200 neuro myasthenia taxonomy override fix V1-B-R4', () {
    late String library;
    late String db;

    setUpAll(() {
      library = File('lib/screens/library_screen.dart').readAsStringSync();
      db = File('lib/data/protocols_database.dart').readAsStringSync();
    });

    test('myasthenic crisis has one explicit Neurology override', () {
      expect(
        RegExp(
          r"'neuro_miastenia_crise'\s*:\s*2\s*,",
        ).allMatches(library).length,
        1,
      );
    });

    test('hub and search both read the same shared override map directly', () {
      expect(library, contains('_simulationSpecialtyOverrides[id]'));
      expect(library, contains('_simulationSpecialtyOverrides[raw]'));
      expect(
        RegExp(
          r"_simulationSpecialtyOverrides\s*\[",
        ).allMatches(library).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('clinical database is preserved at the 200-case milestone', () {
      expect(RegExp("id: 'neuro_miastenia_crise'").allMatches(db).length, 1);
      expect(
        RegExp(r'ProtocolModel\s*\(').allMatches(db).length,
        greaterThanOrEqualTo(200),
      );
    });

    test('canonical bilingual specialty vocabulary remains present', () {
      expect(library, contains("('Neurologia', 'Neurología')"));
      expect(library, contains("('Outros', 'Otros')"));
      expect(library, contains("titlePt: 'Toxicologia'"));
    });
  });
}
