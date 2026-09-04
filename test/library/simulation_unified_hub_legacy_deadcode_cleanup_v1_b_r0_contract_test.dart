import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simulation unified hub legacy dead-code cleanup V1-B-R0', () {
    late String source;

    setUpAll(() {
      source = File('lib/screens/library_screen.dart').readAsStringSync();
    });

    test('obsolete dual-hub symbols are physically absent', () {
      for (final symbol in <String>[
        '_buildSimulacoesSliver',
        '_buildFluxosSliver',
        '_SegmentBtn',
        '_CategoryFilter',
        '_searchFluxoCtrl',
        '_queryFluxo',
        '_fluxoCat',
        '_catDefs',
        '_catIndexForId',
      ]) {
        expect(source, isNot(contains(symbol)), reason: symbol);
      }
    });

    test('unified hub remains canonical', () {
      expect(
        source,
        contains(
          'MEDCASES_SIMULACOES_UNIFIED_HUB_LEGACY_DEADCODE_CLEANUP_V1_B_R0',
        ),
      );
      expect(
        source,
        contains(
          'MEDCASES_SIMULACOES_UNIFIED_SINGLE_HUB_SPECIALTY_CARDS_V1_B_R0',
        ),
      );
      expect(source, contains('_buildUnifiedHubSliver(allDB, dark, isEs, p)'));
      expect(source, contains('class _GrupoConfig'));
      expect(source, contains('class _GrupoCard'));
      expect(source, contains('class _SimulacoesGroupPage'));
    });

    test('topbar global search remains canonical', () {
      expect(
        source,
        contains(
          'MEDCASES_SIMULACOES_TOPBAR_GLOBAL_SEARCH_GUIDE_PATTERN_V1_B_R0',
        ),
      );
      expect(source, contains('SIMULATION_SEARCH_EXACT_TITLE_ROW'));
      expect(source, contains('_showSimulationPortalSearch'));
      expect(source, contains('class _SimulationPortalSearchDelegate'));
      expect(source, contains('openSimulationProtocolPage(context, selected)'));
    });

    test('Toxicologia group still exists', () {
      expect(source, contains("titlePt: 'Toxicologia'"));
      expect(source, contains("'botulismo_neuroparalitico'"));
      expect(source, contains("'ofidismo_bothrops_alternatus_yarara'"));
      expect(source, contains("'araneismo_latrodectus'"));
    });
  });
}
