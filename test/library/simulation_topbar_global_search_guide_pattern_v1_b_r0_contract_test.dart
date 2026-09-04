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
  group('Simulation topbar global search guide pattern V1-B-R0', () {
    late String source;
    late String topbarZone;
    late String delegate;

    setUpAll(() {
      source = File('lib/screens/library_screen.dart').readAsStringSync();
      topbarZone = between(
        source,
        '// ── CAMADA 2: Conteúdo interativo',
        '// BUILD 331 — TOPBAR BIBLIOTECA',
      );
      delegate = between(
        source,
        'class _SimulationPortalSearchDelegate',
        'class _GuidePortalSearchDelegate',
      );
    });

    test('simulation receives same right-side search geometry as guide', () {
      expect(topbarZone, contains('if (isSimulation)'));
      expect(topbarZone, contains('SIMULATION_SEARCH_EXACT_TITLE_ROW'));
      expect(topbarZone, contains('right: 8'));
      expect(topbarZone, contains('width: 46'));
      expect(topbarZone, contains('height: 46'));
      expect(
        topbarZone,
        contains('icon: const Icon(Icons.search_rounded, size: 30)'),
      );
      expect(
        topbarZone,
        contains('onPressed: () => _showSimulationPortalSearch(p, isEs)'),
      );
    });

    test('showSearch searches all protocols and reuses canonical route', () {
      expect(
        source,
        contains('_showSimulationPortalSearch(AppProvider p, bool isEs)'),
      );
      expect(
        source,
        contains('p.protocolsDB.where((item) => seen.add(item.id))'),
      );
      expect(source, contains('showSearch<ProtocolModel?>('));
      expect(source, contains('_SimulationPortalSearchDelegate('));
      expect(source, contains('openSimulationProtocolPage(context, selected)'));
    });

    test('search indexes PT ES id and specialty', () {
      expect(delegate, contains("_title(item, 'pt')"));
      expect(delegate, contains("_title(item, 'es')"));
      expect(delegate, contains('_normalizeSimulationSearch(item.id)'));
      expect(
        delegate,
        contains('_simulationSearchCategoryLabel(item.id, false)'),
      );
      expect(
        delegate,
        contains('_simulationSearchCategoryLabel(item.id, true)'),
      );
      expect(delegate, contains('categoryPt.contains(normalizedQuery)'));
      expect(delegate, contains('categoryEs.contains(normalizedQuery)'));
    });

    test('search normalizes accents and id separators', () {
      final normalizer = between(
        source,
        'String _normalizeSimulationSearch',
        'int _simulationSearchCategoryIndex',
      );
      expect(normalizer, contains("'á': 'a'"));
      expect(normalizer, contains("'ç': 'c'"));
      expect(normalizer, contains("'ñ': 'n'"));
      expect(normalizer, contains("RegExp(r'[_\\-]+')"));
    });

    test('search retains same specialty vocabulary', () {
      for (final label in <String>[
        'Emergências',
        'Cardiologia',
        'Neurologia',
        'Pneumologia',
        'Infectologia',
        'Gastroenterologia & Hepatologia',
        'Endocrinologia & Metabólico',
        'Nefrologia & Eletrólitos',
        'Pediatria',
        'Ginecologia & Obstetrícia',
        'Trauma & Cirurgia',
        'Hematologia',
        'Psiquiatria',
        'Toxicologia',
        'ORL & Medicina Geral',
        'Outros',
      ]) {
        expect(source, contains("'$label'"), reason: label);
      }
    });

    test('empty query does not replace unified hub', () {
      expect(delegate, contains('if (normalizedQuery.isEmpty)'));
      expect(
        source,
        contains(
          'MEDCASES_SIMULACOES_UNIFIED_SINGLE_HUB_SPECIALTY_CARDS_V1_B_R0',
        ),
      );
      expect(source, contains('_buildUnifiedHubSliver(allDB, dark, isEs, p)'));
    });
  });
}
