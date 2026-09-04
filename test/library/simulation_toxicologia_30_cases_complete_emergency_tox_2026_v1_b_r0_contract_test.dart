import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Toxicologia previous 30 retention after 40-case expansion', () {
    late String lib, db;
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
    ];
    setUpAll(() {
      lib = File('lib/screens/library_screen.dart').readAsStringSync();
      db = File('lib/data/protocols_database.dart').readAsStringSync();
    });
    test('previous 30 remain unique narrative protocols with mechanism', () {
      expect(ids.toSet(), hasLength(30));
      for (final id in ids) {
        expect(lib, contains("'$id'"));
        expect("id: '$id'".allMatches(db).length, 1);
        final at = db.indexOf("id: '$id'");
        final s = db.lastIndexOf('ProtocolModel(', at);
        final n = db.indexOf('\n  ProtocolModel(', at);
        final b = db.substring(s, n < 0 ? db.length : n);
        expect(b, contains('Mecanismo de toxicidade —'));
        expect(b, contains('Mecanismo de toxicidad —'));
      }
    });
  });
}
