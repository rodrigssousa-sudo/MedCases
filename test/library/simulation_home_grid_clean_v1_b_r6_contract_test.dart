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
  group('Simulation Home card grammar retained in unified hub', () {
    late String source;
    late String card;
    late String unified;

    setUpAll(() {
      source = File('lib/screens/library_screen.dart').readAsStringSync();
      card = between(
        source,
        'class _GrupoCard extends StatelessWidget {',
        'class _SimulacoesGroupPage extends StatelessWidget {',
      );
      unified = between(
        source,
        '  List<Widget> _buildUnifiedHubSliver(',
        '  // ── Sub-segmento 0: Simulações',
      );
    });

    test('group cards keep Home interaction and full-page route', () {
      expect(card, contains('HomeV2PressSurface('));
      expect(card, contains('height: 104'));
      expect(card, contains('_SimulacoesGroupPage('));
      expect(card, contains('emoji'));
    });

    test('unified catalog feeds the same group card component', () {
      expect(unified, contains('return _GrupoCard('));
      expect(
          unified, contains('emoji: _simulationGroupSvgAsset(group.titlePt)'));
      expect(unified, contains('ids: group.ids'));
      expect(unified, contains('allDB: allDB'));
    });

    test('group page still opens simulation protocol route', () {
      expect(source, contains('openSimulationProtocolPage(context, caso)'));
    });
  });
}
