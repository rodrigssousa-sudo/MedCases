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
  group('Simulation canonical density migrated to unified hub V1-B-R0', () {
    late String source;
    late String state;

    setUpAll(() {
      source = File('lib/screens/library_screen.dart').readAsStringSync();
      state = between(
        source,
        'class _CasosDeEstudoTabState extends State<_CasosDeEstudoTab> {',
        'class _GrupoConfig {',
      );
    });

    test('single visible hub replaces dual segment selector', () {
      expect(
        state,
        contains(
          'MEDCASES_SIMULACOES_UNIFIED_SINGLE_HUB_SPECIALTY_CARDS_V1_B_R0',
        ),
      );
      expect(state, contains('_buildUnifiedHubSliver(allDB, dark, isEs, p)'));
      expect(state, isNot(contains('if (_segment == 0)')));
      expect(state, isNot(contains('active: _segment == 0')));
      expect(state, isNot(contains('active: _segment == 1')));
    });

    test('canonical compact geometry remains unchanged', () {
      for (final token in <String>[
        'EdgeInsets.fromLTRB(0.7, 0, 0.7, 112 + safeBottom)',
        'crossAxisCount: 2',
        'crossAxisSpacing: 3',
        'mainAxisSpacing: 3',
        'mainAxisExtent: 104',
      ]) {
        expect(state, contains(token), reason: token);
      }
    });

    test('topbar and route remain connected', () {
      expect(source, contains("isEs ? 'SIMULACIÓN' : 'SIMULAÇÃO'"));
      expect(source, contains('openSimulationProtocolPage(context, caso)'));
      expect(source, contains('class ClinicalSimulationScreen'));
    });
  });
}
