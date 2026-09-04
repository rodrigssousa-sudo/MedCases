import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String legacySource;

  setUpAll(() {
    source = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
    legacySource = File('lib/screens/home_screen.dart').readAsStringSync();
  });

  group('Injeção de Calculadora e Fármacos na Home V2', () {
    test('HomeScreen preserva slot opcional canônico', () {
      expect(
        legacySource,
        contains('final Widget? calculatorDrugsCard;'),
      );
      expect(
        legacySource,
        contains('this.calculatorDrugsCard,'),
      );
      expect(
        legacySource,
        contains('widget.calculatorDrugsCard ??'),
      );
    });

    test('HomeScreenV2 monta diretamente o wrapper real', () {
      expect(
        RegExp(
          r'\bHomeCalculatorDrugsCard\s*\(',
        ).allMatches(source).length,
        1,
      );
      expect(source, isNot(contains('calculatorDrugsCard:')));
      expect(source, contains('dark: dark'));
      expect(source, contains('isEs: isEs'));
    });

    test('não utiliza os placeholders separados', () {
      expect(
        RegExp(r'\bCalculatorCard\s*\(').hasMatch(source),
        isFalse,
      );
      expect(
        RegExp(r'\bDrugsCard\s*\(').hasMatch(source),
        isFalse,
      );
    });
  });
}
