import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Toxicologia previous 20 retention after 30-case expansion', () {
    late String library;
    late String protocols;
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
    ];
    setUpAll(() {
      library = File('lib/screens/library_screen.dart').readAsStringSync();
      protocols = File('lib/data/protocols_database.dart').readAsStringSync();
    });
    test(
      'previous 20 remain unique narrative protocols with bilingual mechanism',
      () {
        expect(ids.toSet(), hasLength(20));
        for (final id in ids) {
          expect(library, contains("'$id'"), reason: id);
          expect("id: '$id'".allMatches(protocols).length, 1, reason: id);
          final at = protocols.indexOf("id: '$id'");
          final s = protocols.lastIndexOf('ProtocolModel(', at);
          final n = protocols.indexOf('\n  ProtocolModel(', at);
          final b = protocols.substring(s, n < 0 ? protocols.length : n);
          expect(b, contains('Mecanismo de toxicidade —'), reason: '$id PT');
          expect(b, contains('Mecanismo de toxicidad —'), reason: '$id ES');
        }
      },
    );
  });
}
