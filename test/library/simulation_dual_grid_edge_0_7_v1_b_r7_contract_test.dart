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
  group('Simulation former dual grid migrated to unified specialty grid', () {
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

    test('one two-column grid owns cases and former flows', () {
      expect(unified, contains('for (final item in allDB)'));
      expect(unified, contains('_unifiedSimulationCategoryIndex(item.id)'));
      expect(unified, contains('buckets[categoryIndex].add(item.id)'));
      expect(unified, contains('sliver: SliverGrid('));
      expect(unified, isNot(contains('sliver: SliverList(')));
    });

    test('0.7 outer edges and 3px gaps remain canonical', () {
      expect(unified, contains('EdgeInsets.fromLTRB(0.7, 0, 0.7, 112 + safeBottom)'));
      expect(unified, contains('crossAxisSpacing: 3'));
      expect(unified, contains('mainAxisSpacing: 3'));
      expect(unified, contains('mainAxisExtent: 104'));
    });

    test('legacy dual-hub engine is fully removed after unified migration', () {
      expect(source, isNot(contains('List<Widget> _buildFluxosSliver(')));
      final state = between(
        source,
        'class _CasosDeEstudoTabState extends State<_CasosDeEstudoTab> {',
        'class _GrupoConfig {',
      );
      final visibleBuild = between(
        state,
        'Widget build(BuildContext context) {',
        '  bool _isUnifiedToxicologyId(String id)',
      );
      expect(visibleBuild, isNot(contains('_buildFluxosSliver(')));
    });
  });
}
