import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String block(String s, String id) {
  final at = s.indexOf("id: '$id'");
  expect(at, greaterThanOrEqualTo(0), reason: id);
  final a = s.lastIndexOf('ProtocolModel(', at);
  final n = s.indexOf('\n  ProtocolModel(', at);
  return s.substring(a, n < 0 ? s.length : n);
}

void main() {
  group('Toxicologia Batch01 Da toxina a conduta 2026', () {
    late String db, renderer, library, model;
    const batch = <String>[
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
    ];
    const tox40 = <String>[
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
      db = File('lib/data/protocols_database.dart').readAsStringSync();
      renderer = File('lib/screens/protocols_screen.dart').readAsStringSync();
      library = File('lib/screens/library_screen.dart').readAsStringSync();
      model = File('lib/models/protocol_model.dart').readAsStringSync();
    });
    test('exclusive toxicology gate plus learning journey', () {
      expect(tox40.toSet(), hasLength(40));
      expect(
        renderer,
        contains('_toxicologySimulationIds2026.contains(protocol.id)'),
      );
      expect(
        renderer,
        contains('protocol.getDynamic(protocol.severityCriteria'),
      );
      expect(
        renderer,
        isNot(
          contains('final sev=protocol.getString(protocol.severityCriteria'),
        ),
      );
      for (final id in batch) {
        expect(renderer, contains("'$id',"), reason: id);
      }
      final gateStart = renderer.indexOf(
        'const Set<String> _toxicologySimulationIds2026',
      );
      final gateEnd = renderer.indexOf('};', gateStart);
      final gate = renderer.substring(gateStart, gateEnd);
      expect(gate, isNot(contains("'intox_co2_espaco_confinado',")));
      for (final t in <String>[
        'DA TOXINA À CONDUTA',
        'CASO',
        'DECISÕES',
        'DECISIONES',
        'EVOLUÇÃO',
        'EVOLUCIÓN',
        'CONDUTA',
        'CONDUCTA',
        'REPASSO',
        'REPASO',
        'TOXINA → ALVO → FISIOLOGIA → CLÍNICA → EXAME → RISCO → TRATAMENTO',
        'TOXINA → DIANA → FISIOLOGÍA → CLÍNICA → EXAMEN → RIESGO → TRATAMIENTO',
      ]) {
        expect(renderer, contains(t), reason: t);
      }
    });
    test('batch01 full bilingual rich source', () {
      for (final id in batch) {
        expect("id: '$id'".allMatches(db).length, 1, reason: id);
        final b = block(db, id);
        for (final f in <String>[
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
        ]) {
          expect(b, contains(f), reason: '$id $f');
        }
        expect(b, contains('MECANISMO 1'), reason: id);
        expect(
          b,
          contains('Mecanismo de toxicidade —'),
          reason: '$id legacy PT label',
        );
        expect(
          b,
          contains('Mecanismo de toxicidad —'),
          reason: '$id legacy ES label',
        );
        expect(b, contains('RESUMO 30 S'), reason: id);
        expect(b, contains('RESUMEN 30 S'), reason: id);
        expect(
          'https://'.allMatches(b).length,
          greaterThanOrEqualTo(6),
          reason: id,
        );
      }
    });
    test('40 taxonomy and model preserved', () {
      final at = library.indexOf("titlePt: 'Toxicologia'");
      expect(at, greaterThanOrEqualTo(0));
      final a = library.lastIndexOf('_GrupoConfig(', at),
          n = library.indexOf('\n    ),', at),
          g = library.substring(a, n);
      for (final id in tox40) {
        expect("'$id',".allMatches(g).length, 1, reason: id);
        expect("id: '$id'".allMatches(db).length, 1, reason: id);
      }
      for (final f in <String>[
        'physiopathology',
        'scenarios',
        'monitoring',
        'references',
      ]) {
        expect(model, contains(f));
      }
    });
    test('critical current safety semantics', () {
      expect(
        block(db, 'intox_paracetamol'),
        allOf(
          contains('ACMT 2026'),
          contains('APAP <10'),
          contains('INR <2'),
          contains('300 mg/kg'),
          contains('21 h'),
        ),
      );
      expect(
        block(db, 'intox_opioides'),
        allOf(contains('0,2–2 mg'), contains('2–4 mg'), contains('2/3')),
      );
      expect(
        block(db, 'intox_benzodiazepinas'),
        contains('Não usar flumazenil rotineiramente'),
      );
      expect(
        block(db, 'intox_organofosforados'),
        allOf(
          contains('dobrar a cada 5 min'),
          contains('2 g IV'),
          contains('1 g/h'),
        ),
      );
      expect(
        block(db, 'intox_triciclicos'),
        allOf(
          contains('50–150 mEq'),
          contains('Na >155'),
          contains('pH >7,55'),
        ),
      );
      expect(
        block(db, 'intox_betabloqueadores'),
        allOf(contains('1–10 U/kg/h'), contains('2–10 mg')),
      );
      expect(
        block(db, 'intox_monoxido_carbono'),
        allOf(contains('O2 100%'), contains('25–30%'), contains('Gestação')),
      );
      expect(
        block(db, 'intox_metanol_etilenoglicol'),
        allOf(
          contains('15 mg/kg'),
          contains('a cada 4 h'),
          contains('pH ≤7,15'),
          contains('AG >27'),
        ),
      );
    });
  });
}
