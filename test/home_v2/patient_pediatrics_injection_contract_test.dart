import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String legacySource;

  setUpAll(() {
    source = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
    legacySource = File('lib/screens/home_screen.dart').readAsStringSync();
  });

  group('Injeção Paciente e Pediatria na Home V2', () {
    test('HomeScreen preserva slot opcional canônico', () {
      expect(
        legacySource,
        contains('final Widget? patientPediatricsRow;'),
      );
      expect(
        legacySource,
        contains('this.patientPediatricsRow,'),
      );
      expect(
        legacySource,
        contains('widget.patientPediatricsRow ??'),
      );
    });

    test('monta exatamente uma fachada canônica na Home V2', () {
      expect(
        RegExp(
          r'\bHomePatientPediatricsRow\s*\(',
        ).allMatches(source).length,
        1,
      );
      expect(source, isNot(contains('patientPediatricsRow:')));
    });

    test('preserva tema, idioma e openProtocol real', () {
      final start = source.indexOf(
        'HomePatientPediatricsRow(',
      );

      expect(start, greaterThanOrEqualTo(0));

      final fragment = source.substring(
        start,
        (start + 280).clamp(0, source.length),
      );

      expect(fragment, contains('dark: dark'));
      expect(fragment, contains('isEs: isEs'));
      expect(fragment, contains('openProtocol: openProtocol'));
    });
  });
}
