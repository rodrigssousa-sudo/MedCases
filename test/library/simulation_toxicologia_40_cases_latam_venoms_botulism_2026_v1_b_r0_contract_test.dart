import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String pb(String s, String id) {
  final at = s.indexOf("id: '$id'");
  expect(at, greaterThanOrEqualTo(0));
  final a = s.lastIndexOf('ProtocolModel(', at);
  final n = s.indexOf('\n  ProtocolModel(', at);
  return s.substring(a, n < 0 ? s.length : n);
}

void main() {
  group('Toxicologia 40 LATAM venoms botulism 2026', () {
    late String lib, db, model, renderer;
    const ids = <String>[
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
    const newIds = <String>[
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
      lib = File('lib/screens/library_screen.dart').readAsStringSync();
      db = File('lib/data/protocols_database.dart').readAsStringSync();
      model = File('lib/models/protocol_model.dart').readAsStringSync();
      renderer = File('lib/screens/protocols_screen.dart').readAsStringSync();
    });
    test('40 unique cases', () {
      expect(ids.toSet(), hasLength(40));
      final at = lib.indexOf("titlePt: 'Toxicologia'");
      final a = lib.lastIndexOf('_GrupoConfig(', at);
      final n = lib.indexOf('\n    ),', at);
      final g = lib.substring(a, n);
      for (final id in ids) {
        expect("'$id',".allMatches(g).length, 1, reason: id);
        expect("id: '$id'".allMatches(db).length, 1, reason: id);
      }
    });
    test('new rich schema mechanism refs', () {
      const fields = <String>[
        'definition:',
        'classification:',
        'severityCriteria:',
        'physiopathology:',
        'redFlags:',
        'differentialDiagnosis:',
        'exams:',
        'objectives:',
        'drugsFirstLine:',
        'drugsSecondLine:',
        'drugsConditional:',
        'drugsContraindicated:',
        'scenarios:',
        'monitoring:',
        'complications:',
        'doNotDo:',
        'pearls:',
        'references:',
        'recognize:',
        'actions:',
        'avoid:',
      ];
      for (final id in newIds) {
        final b = pb(db, id);
        for (final f in fields) {
          expect(b, contains(f), reason: '$id $f');
        }
        expect(b, contains('Mecanismo de toxicidade —'));
        expect(b, contains('Mecanismo de toxicidad —'));
        expect('https://'.allMatches(b).length, greaterThanOrEqualTo(6));
      }
    });
    test('regional distinctions', () {
      expect(
        pb(db, 'escorpionismo_tityus_argentina'),
        contains('Tityus carrilloi'),
      );
      expect(
        pb(db, 'escorpionismo_tityus_argentina'),
        contains('T. confluens'),
      );
      expect(pb(db, 'escorpionismo_tityus_brasil'), contains('T. serrulatus'));
      expect(
        pb(db, 'araneismo_latrodectus'),
        contains('indisponibilidade rotineira'),
      );
      expect(
        pb(db, 'araneismo_latrodectus'),
        contains('antiveneno latrodéctico ANLIS'),
      );
      expect(pb(db, 'ofidismo_crotalus_durissus'), contains('crotoxina'));
      expect(
        pb(db, 'ofidismo_micrurus_coral'),
        contains('receptores nicotínicos'),
      );
      expect(pb(db, 'botulismo_neuroparalitico'), contains('SNARE'));
    });
    test('model renderer frozen semantics', () {
      expect(model, contains('final Map<String, String>? physiopathology;'));
      expect(
        renderer,
        contains("label: isEs ? 'FISIOPATOLOGÍA' : 'FISIOPATOLOGIA'"),
      );
    });
  });
}
