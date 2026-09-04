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
  group('Simulation mixed layout migrated to single catalog V1-B-R0', () {
    late String source;
    late String state;
    late String unified;

    setUpAll(() {
      source = File('lib/screens/library_screen.dart').readAsStringSync();
      state = between(
        source,
        'class _CasosDeEstudoTabState extends State<_CasosDeEstudoTab> {',
        'class _GrupoConfig {',
      );
      unified = between(
        source,
        '  List<Widget> _buildUnifiedHubSliver(',
        '  // ── Sub-segmento 0: Simulações',
      );
    });

    test('visible state has exactly one unified catalog invocation', () {
      expect(
        '_buildUnifiedHubSliver(allDB, dark, isEs, p)'.allMatches(state).length,
        1,
      );
      expect(state, isNot(contains("label: isEs ? 'Simulaciones'")));
      expect(state, isNot(contains("'Flujos simulados' : 'Fluxos simulados'")));
    });

    test('all ProtocolModels receive one category bucket', () {
      expect(unified, contains('for (final item in allDB)'));
      expect(unified, contains('buckets[categoryIndex].add(item.id)'));
      expect(
        unified,
        contains('for (var index = 0; index < definitions.length; index++)'),
      );
    });

    test('global search lives in topbar and legacy flow search is removed', () {
      expect(source, isNot(contains('List<Widget> _buildFluxosSliver(')));
      expect(source, contains('SIMULATION_SEARCH_EXACT_TITLE_ROW'));
      expect(source, contains('_showSimulationPortalSearch'));
      expect(source, contains('class _SimulationPortalSearchDelegate'));
      expect(source, isNot(contains('controller: _searchFluxoCtrl')));
      expect(unified, isNot(contains('controller: _searchFluxoCtrl')));
    });
  });
}
