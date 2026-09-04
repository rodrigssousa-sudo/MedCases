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
  group('Simulation unified single hub specialty cards V1-B-R0', () {
    late String source;
    late String state;
    late String unified;

    const toxicologyIds = <String>[
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
      'intox_co2_espaco_confinado',
      'intox_cianeto',
      'intox_fumaca_co_cianeto',
      'metahemoglobinemia_adquirida',
      'metahemoglobinemia_dapsona',
      'metahemoglobinemia_nitrito_nitrato',
      'metahemoglobinemia_anestesico_local',
      'metahemoglobinemia_anilina_nitrobenzeno',
      'intox_sulfeto_hidrogenio',
      'intox_cloreto_metileno',
      'intox_salicilatos',
      'intox_bloqueadores_canal_calcio',
      'intox_digoxina_glicosideos',
      'intox_litio',
      'intox_valproato',
      'intox_ferro',
      'intox_isoniazida',
      'intox_cocaina_simpaticomimeticos',
      'sindrome_serotoninergica',
      'intox_anestesico_local_last',
      'botulismo_neuroparalitico',
      'ofidismo_bothrops_alternatus_yarara',
      'ofidismo_bothrops_jararaca_jararacucu',
      'ofidismo_crotalus_durissus',
      'ofidismo_micrurus_coral',
      'escorpionismo_tityus_argentina',
      'escorpionismo_tityus_brasil',
      'araneismo_loxosceles',
      'araneismo_phoneutria',
      'araneismo_latrodectus',
    ];

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

    test('one screen replaces the previous Simulações Fluxos switch', () {
      expect(
        state,
        contains(
          'MEDCASES_SIMULACOES_UNIFIED_SINGLE_HUB_SPECIALTY_CARDS_V1_B_R0',
        ),
      );
      expect(state, contains('_buildUnifiedHubSliver(allDB, dark, isEs, p)'));
      expect(state, isNot(contains('int _segment = 0')));
      expect(state, isNot(contains('if (_segment == 0)')));
      expect(state, isNot(contains("'Flujos simulados' : 'Fluxos simulados'")));
    });

    test(
      'all protocols are assigned through one deterministic bucket pass',
      () {
        expect(unified, contains('for (final item in allDB)'));
        expect(unified, contains('_unifiedSimulationCategoryIndex(item.id)'));
        expect(unified, contains('buckets[categoryIndex].add(item.id)'));
        expect(unified, contains('ids: buckets[index]'));
      },
    );

    test('unified catalog exposes the requested specialty cards', () {
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
        expect(unified, contains("'$label'"), reason: label);
      }
    });

    test('Toxicologia keeps all 40 exact cases', () {
      final groups = between(
        source,
        'static const List<_GrupoConfig> _gruposSimulacao = [',
        '// ── Categorias para sub-segmento',
      );
      final at = groups.indexOf("titlePt: 'Toxicologia'");
      expect(at, greaterThanOrEqualTo(0));
      final left = groups.lastIndexOf('_GrupoConfig(', at);
      final right = groups.indexOf('\n    ),', at);
      expect(left, greaterThanOrEqualTo(0));
      expect(right, greaterThan(at));
      final toxicology = groups.substring(left, right);

      expect(toxicologyIds.toSet(), hasLength(40));
      for (final id in toxicologyIds) {
        expect("'$id',".allMatches(toxicology).length, 1, reason: id);
      }

      expect(source, contains("group.titlePt == 'Toxicologia'"));
      expect(source, contains("'botulismo'"));
      expect(source, contains("'ofidismo'"));
      expect(source, contains("'escorpionismo'"));
      expect(source, contains("'araneismo'"));
    });

    test('visual geometry and canonical routes remain intact', () {
      for (final token in <String>[
        'EdgeInsets.fromLTRB(0.7, 0, 0.7, 112 + safeBottom)',
        'crossAxisCount: 2',
        'crossAxisSpacing: 3',
        'mainAxisSpacing: 3',
        'mainAxisExtent: 104',
        'class ClinicalSimulationScreen',
        'openSimulationProtocolPage(context, caso)',
      ]) {
        expect(source, contains(token), reason: token);
      }
    });

    test(
      'global search is owned by the simulation topbar and hub remains category-first',
      () {
        expect(unified, isNot(contains('TextField(')));
        expect(unified, isNot(contains('_searchFluxoCtrl')));
        expect(source, isNot(contains('controller: _searchFluxoCtrl')));
        expect(source, isNot(contains('List<Widget> _buildFluxosSliver(')));
        expect(source, contains('SIMULATION_SEARCH_EXACT_TITLE_ROW'));
        expect(source, contains('_showSimulationPortalSearch'));
        expect(source, contains('class _SimulationPortalSearchDelegate'));
      },
    );
  });
}
