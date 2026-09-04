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

  group('Simulation action bar safe margin V1-B-R0', () {
    test('unified simulation hub owns dynamic bottom safe area', () {
      expect(
        unified,
        contains('MEDCASES_SIMULACAO_ACTION_BAR_SAFE_MARGIN_V1_B_R0'),
      );
      expect(
        unified,
        contains('final safeBottom = MediaQuery.paddingOf(context).bottom;'),
      );
      expect(
        unified,
        contains(
          'padding: EdgeInsets.fromLTRB(0.7, 0, 0.7, 112 + safeBottom),',
        ),
      );
      expect(
        unified,
        isNot(contains('EdgeInsets.fromLTRB(0.7, 0, 0.7, 100)')),
      );
    });

    test('only bottom clearance changes; canonical grid stays intact', () {
      for (final token in <String>[
        'crossAxisCount: 2',
        'crossAxisSpacing: 3',
        'mainAxisSpacing: 3',
        'mainAxisExtent: 104',
        'return _GrupoCard(',
      ]) {
        expect(unified, contains(token), reason: token);
      }
    });

    test('productive Simulation shell and route remain intact', () {
      expect(
        source,
        contains('class ClinicalSimulationScreen extends StatelessWidget'),
      );
      expect(
        source,
        contains('_buildUnifiedHubSliver(allDB, dark, isEs, p)'),
      );
      expect(
        source,
        contains('openSimulationProtocolPage(context, caso)'),
      );
    });

    test('guide clearance is not rewritten by this Simulation-only patch', () {
      expect(
        source,
        contains('EdgeInsets.fromLTRB(4, 4, 4, 114 + safeBottom)'),
      );
    });
  });
}
