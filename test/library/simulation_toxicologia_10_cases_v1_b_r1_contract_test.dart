import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String between(String source, String start, String end) {
  final a = source.indexOf(start);
  expect(a, greaterThanOrEqualTo(0), reason: start);
  final b = source.indexOf(end, a + start.length);
  expect(b, greaterThan(a), reason: end);
  return source.substring(a, b);
}

void main() {
  group('Toxicologia original 10 retention after 20-case expansion', () {
    late String library;
    late String protocols;
    const originalIds = <String>[
      'intoxicacao_exogena',
      'intox_paracetamol',
      'intox_opioides',
      'intox_benzodiazepinas',
      'intox_organofosforados',
      'intox_triciclicos',
      'intox_betabloqueadores',
      'intox_monoxido_carbono',
      'intox_metanol_etilenoglicol',
      'intoxicacao_overdose',
    ];

    setUpAll(() {
      library = File('lib/screens/library_screen.dart').readAsStringSync();
      protocols = File('lib/data/protocols_database.dart').readAsStringSync();
    });

    test('original 10 remain narrative, unique and in Toxicologia', () {
      final narrative = between(
        library,
        'static const Set<String> _casoNarrativoIds = {',
        'static const List<_GrupoConfig> _gruposSimulacao = [',
      );
      final groups = between(
        library,
        'static const List<_GrupoConfig> _gruposSimulacao = [',
        '// ── Categorias para sub-segmento',
      );
      final at = groups.indexOf("titlePt: 'Toxicologia'");
      final left = groups.lastIndexOf('_GrupoConfig(', at);
      final right = groups.indexOf('\n    ),', at);
      final toxicology = groups.substring(left, right);
      expect(originalIds.toSet(), hasLength(10));
      for (final id in originalIds) {
        expect(narrative, contains("'$id'"), reason: id);
        expect(toxicology, contains("'$id'"), reason: id);
        expect("id: '$id'".allMatches(protocols).length, 1, reason: id);
      }
    });

    test('original 10 now expose explicit bilingual toxic mechanism', () {
      for (final id in originalIds) {
        final at = protocols.indexOf("id: '$id'");
        final start = protocols.lastIndexOf('ProtocolModel(', at);
        final next = protocols.indexOf('\n  ProtocolModel(', at);
        final block = protocols.substring(
          start,
          next < 0 ? protocols.length : next,
        );
        expect(block, contains('physiopathology:'), reason: id);
        expect(block, contains('Mecanismo de toxicidade —'), reason: id);
        expect(block, contains('Mecanismo de toxicidad —'), reason: id);
        expect(block, contains('references:'), reason: id);
      }
    });
  });
}
