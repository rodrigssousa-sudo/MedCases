import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final match = RegExp(
    '^class\\s+${RegExp.escape(className)}\\b',
    multiLine: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: className);

  final rest = source.substring(match!.end);
  final next =
      RegExp(r'^class\s+[A-Za-z_]\w*\b', multiLine: true).firstMatch(rest);

  return next == null
      ? source.substring(match.start)
      : source.substring(match.start, match.end + next.start);
}

void expectEmptySurface(String owner) {
  expect(owner, isNot(contains('hintText:')));
  expect(owner, isNot(contains('hintStyle:')));
  expect(owner, contains('controller: ctrl'));
  expect(owner, contains('flow.nodeFor(ctrl)'));
  expect(owner, contains('flow.advance(ctrl)'));
  expect(owner, contains('BoxConstraints(minHeight: 48)'));
  expect(owner, contains('0xFFF7F9FB'));
  expect(owner, contains('0xFF20252D'));
}

void main() {
  late String cardio;
  late String electro;
  late String hepato;
  late String nephro;
  late String v2Contract;

  setUpAll(() {
    cardio = File('lib/screens/cardio_tools_screen.dart').readAsStringSync();
    electro =
        File('lib/screens/electrolytes_tools_screen.dart').readAsStringSync();
    hepato =
        File('lib/screens/hepatology_tools_screen.dart').readAsStringSync();
    nephro =
        File('lib/screens/nephrology_tools_screen.dart').readAsStringSync();
    v2Contract = File(
      'test/tools/ferramentas_external_label_symmetric_form_layout_v2_b_r2_contract_test.dart',
    ).readAsStringSync();
  });

  group('Ferramentas no-sample-hints V2-B-R1', () {
    test('cardio, electro and hepato render empty input surfaces', () {
      expectEmptySurface(classBlock(cardio, '_NField'));
      expectEmptySurface(classBlock(electro, '_NField'));
      expectEmptySurface(classBlock(hepato, '_FieldBox'));
      expectEmptySurface(classBlock(hepato, '_FieldBoxFreeText'));
    });

    test('nephro remains untouched and visually empty', () {
      final nephroField = classBlock(nephro, '_FieldBox');
      expect(nephroField, isNot(contains('hintText:')));
      expect(nephroField, contains('controller: ctrl'));
    });

    test('electro external reference ranges remain visible', () {
      final owner = classBlock(electro, '_NField');
      expect(owner, contains('refRange.isNotEmpty'));
      expect(
        owner.indexOf('refRange.isNotEmpty'),
        lessThan(owner.indexOf('AnimatedBuilder(')),
      );
    });

    test('constructor hint signatures remain for zero caller churn', () {
      expect(
          classBlock(cardio, '_NField'), contains('final String label, hint'));
      expect(
        classBlock(electro, '_NField'),
        contains('final String label, hint, refRange'),
      );
      expect(classBlock(hepato, '_FieldBox'), contains('final String? hint'));
      expect(
        classBlock(hepato, '_FieldBoxFreeText'),
        contains('final String? hint'),
      );
    });

    test('V2 contract was migrated from rendered hints to empty surfaces', () {
      expect(
        v2Contract,
        isNot(contains("expect(inside, contains('hintText: hint'));")),
      );
      expect(
        v2Contract,
        contains("expect(inside, isNot(contains('hintText:')));"),
      );
      expect(
        v2Contract,
        contains("expect(inside, isNot(contains('hintStyle:')));"),
      );
    });
  });
}
