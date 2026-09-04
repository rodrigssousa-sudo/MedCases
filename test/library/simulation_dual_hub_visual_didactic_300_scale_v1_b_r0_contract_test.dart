import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String between(String source, String start, String end) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: 'start missing: $start');
  expect(b, greaterThan(a), reason: 'end missing: $end');
  return source.substring(a, b);
}

void main() {
  group('Simulation dual-hub contract migrated to one didactic catalog', () {
    late String source;
    late String unified;

    setUpAll(() {
      source = File('lib/screens/library_screen.dart').readAsStringSync();
      unified = between(
        source,
        '  List<Widget> _buildUnifiedHubSliver(',
        '  // ── Sub-segmento 0: Simulações',
      );
    });

    test('specialty taxonomy is bilingual and deterministic', () {
      for (final token in <String>[
        "'Emergências'",
        "'Cardiologia'",
        "'Neurologia'",
        "'Pneumologia'",
        "'Infectologia'",
        "'Gastroenterologia & Hepatologia'",
        "'Endocrinologia & Metabólico'",
        "'Nefrologia & Eletrólitos'",
        "'Pediatria'",
        "'Ginecologia & Obstetrícia'",
        "'Trauma & Cirurgia'",
        "'Hematologia'",
        "'Psiquiatria'",
        "'Toxicologia'",
        "'ORL & Medicina Geral'",
        "'Outros'",
        "'Emergencias'",
        "'Cardiología'",
        "'Toxicología'",
      ]) {
        expect(unified, contains(token), reason: token);
      }
    });

    test('Toxicologia has explicit precedence over generic classification', () {
      expect(source, contains("group.titlePt == 'Toxicologia'"));
      expect(source, contains("'botulismo'"));
      expect(source, contains("'ofidismo'"));
      expect(source, contains("'escorpionismo'"));
      expect(source, contains("'araneismo'"));
      expect(source, contains("'sindrome_serotoninergica'"));
    });

    test(
      'search lives in the canonical topbar while unified builder stays clean',
      () {
        expect(unified, isNot(contains('TextField(')));
        expect(unified, isNot(contains('_searchFluxoCtrl')));
        expect(unified, isNot(contains('_fluxoCat')));
        expect(source, isNot(contains('_searchFluxoCtrl')));
      },
    );
  });
}
