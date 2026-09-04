import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assets = <String>[
    'sim_emergencias.svg',
    'sim_cardiologia.svg',
    'sim_neurologia.svg',
    'sim_pneumologia.svg',
    'sim_infectologia.svg',
    'sim_gastro_hepato.svg',
    'sim_endocrino_metabolico.svg',
    'sim_nefro_eletrolitos.svg',
    'sim_pediatria.svg',
    'sim_gineco_obstetricia.svg',
    'sim_trauma_cirurgia.svg',
    'sim_hematologia.svg',
    'sim_psiquiatria.svg',
    'sim_toxicologia.svg',
    'sim_orl_medicina.svg',
    'sim_outros.svg',
  ];
  late String source;
  setUpAll(() =>
      source = File('lib/screens/library_screen.dart').readAsStringSync());

  group('Simulation specialty SVG cutover V1-B-R4', () {
    test('16 SVG assets exist', () {
      for (final a in assets) {
        final f = File('assets/icons/simulation/$a');
        expect(f.existsSync(), isTrue, reason: a);
        expect(f.lengthSync(), greaterThan(0), reason: a);
      }
    });
    test('owner maps all 16 assets', () {
      expect(
          source, contains("import 'package:flutter_svg/flutter_svg.dart';"));
      expect(source, contains('MEDCASES_SIMULATION_SPECIALTY_SVG_V1_B_R4'));
      for (final a in assets)
        expect(source, contains('assets/icons/simulation/$a'));
    });
    test('root 56x48 and group page 40x40 render SVG', () {
      expect(
          source, contains('emoji: _simulationGroupSvgAsset(group.titlePt),'));
      expect(source, contains('SvgPicture.asset('));
      expect(source, contains('width: 56'));
      expect(source, contains('height: 48'));
      expect(source, contains('width: 48'));
      expect(source, contains('width: 40'));
      expect(source, contains('height: 40'));
      expect(source, contains('const SizedBox(height: 4)'));
    });
    test('R8 geometry and routes remain', () {
      expect(source, contains('EdgeInsets.fromLTRB(0.7, 0, 0.7, 112 + safeBottom)'));
      expect(source, contains('crossAxisCount: 2'));
      expect(source, contains('crossAxisSpacing: 3'));
      expect(source, contains('mainAxisSpacing: 3'));
      expect(source, contains('mainAxisExtent: 104'));
      expect(source, contains('_SimulacoesGroupPage('));
      expect(source, contains('openSimulationProtocolPage(context, caso)'));
      expect(source, contains('_unifiedSimulationCategoryIndex(item.id)'));
      expect(source, contains('buckets[categoryIndex].add(item.id)'));
    });
    test('legacy emoji helper remains preserved but hub uses SVG call-site',
        () {
      expect(source, contains('String _simulationGroupEmoji(String title)'));
      expect(
          source, contains('emoji: _simulationGroupSvgAsset(group.titlePt),'));
      expect(
        source,
        isNot(contains('emoji: _simulationGroupEmoji(group.titlePt),')),
      );
    });
  });
}
