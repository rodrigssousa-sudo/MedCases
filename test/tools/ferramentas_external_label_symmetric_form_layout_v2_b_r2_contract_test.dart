import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final pattern =
      RegExp('^class\\s+${RegExp.escape(className)}\\b', multiLine: true);
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: 'missing $className');
  final start = match!.start;
  final remaining = source.substring(match.end);
  final nextMatch =
      RegExp(r'^class\s+[A-Za-z_]\w*\b', multiLine: true).firstMatch(remaining);
  return nextMatch == null
      ? source.substring(start)
      : source.substring(start, match.end + nextMatch.start);
}

void expectExternalField(
  String block, {
  required bool hasHint,
}) {
  final animated = block.indexOf('AnimatedBuilder(');
  expect(animated, greaterThan(0));

  final before = block.substring(0, animated);
  final inside = block.substring(animated);

  expect(before, contains('Text('));
  expect(before, contains('label'));
  expect(before, contains('SizedBox(height: 5)'));

  expect(
    RegExp(r'Text\s*\(\s*label\b').hasMatch(inside),
    isFalse,
    reason: 'label must stay outside the input surface',
  );

  expect(
      block,
      contains(
        'final fill = dark ? const Color(0xFF20252D) : const Color(0xFFF7F9FB);',
      ));
  expect(inside, contains('BoxConstraints(minHeight: 48)'));
  expect(inside, contains('BorderRadius.circular(10)'));
  expect(inside, contains('size: 17'));
  expect(inside, contains('0xFF10B981'));
  expect(inside, contains('controller: ctrl'));
  expect(block, contains('flow.nodeFor(ctrl)'));
  expect(inside, contains('flow.advance(ctrl)'));

  if (hasHint) {
    expect(block, contains('hint'));
    expect(inside, isNot(contains('hintText:')));
    expect(inside, isNot(contains('hintStyle:')));
  }
}

void main() {
  late String nephro;
  late String cardio;
  late String electro;
  late String hepato;

  setUpAll(() {
    nephro =
        File('lib/screens/nephrology_tools_screen.dart').readAsStringSync();
    cardio = File('lib/screens/cardio_tools_screen.dart').readAsStringSync();
    electro =
        File('lib/screens/electrolytes_tools_screen.dart').readAsStringSync();
    hepato =
        File('lib/screens/hepatology_tools_screen.dart').readAsStringSync();
  });

  group('Ferramentas external-label symmetric form V2-B-R2', () {
    test('all five field owners use external labels and compact 48px surfaces',
        () {
      expectExternalField(classBlock(nephro, '_FieldBox'), hasHint: false);
      expectExternalField(classBlock(cardio, '_NField'), hasHint: true);
      expectExternalField(classBlock(electro, '_NField'), hasHint: true);
      expectExternalField(classBlock(hepato, '_FieldBox'), hasHint: true);
      expectExternalField(
        classBlock(hepato, '_FieldBoxFreeText'),
        hasHint: true,
      );
    });

    test('electrolytes reference range is outside the value box', () {
      final field = classBlock(electro, '_NField');
      final animated = field.indexOf('AnimatedBuilder(');
      final ref = field.indexOf('refRange.isNotEmpty');
      expect(ref, greaterThan(0));
      expect(ref, lessThan(animated));
      expect(field, contains('fontSize: 11.5'));
    });

    test('section hierarchy is stronger without touching section structure',
        () {
      expect(classBlock(nephro, '_SectionLabel'), contains('fontSize: 12.5'));
      expect(classBlock(cardio, '_InputCard'), contains('fontSize: 12.5'));
      expect(classBlock(electro, '_InputCard'), contains('fontSize: 12.5'));
      expect(classBlock(hepato, '_SectionLabel'), contains('fontSize: 12.5'));
    });

    test('sex selectors align to the new input height and keep R5 semantics',
        () {
      final nephroSex = classBlock(nephro, '_SexToggle');
      final cardioSex = classBlock(cardio, '_SexToggle');

      expect(nephroSex, contains('height: 48'));
      expect(nephroSex, contains('SizedBox(height: 18.5)'));
      expect(cardioSex, contains('height: 48'));

      for (final token in <String>[
        '0xFFEFF6FF',
        '0xFF1D4ED8',
        '0xFFFDF2F8',
        '0xFFBE185D',
        '0xFF3B82F6',
        '0xFFEC4899',
      ]) {
        expect(cardioSex, contains(token), reason: token);
      }
    });

    test('clinical input wiring remains present', () {
      final nephroField = classBlock(nephro, '_FieldBox');
      final cardioField = classBlock(cardio, '_NField');
      final electroField = classBlock(electro, '_NField');
      final hepatoField = classBlock(hepato, '_FieldBox');

      expect(nephroField, contains('FilteringTextInputFormatter.allow'));
      expect(nephroField, contains('validator: validator'));
      expect(cardioField, contains('validator: validator'));
      expect(electroField, contains('validator: validator'));
      expect(hepatoField, contains('FilteringTextInputFormatter.allow'));
      expect(hepatoField, contains('validator: validator'));

      for (final source in <String>[nephro, cardio, electro, hepato]) {
        expect(source, isNot(contains('autovalidateMode')));
      }
    });
  });
}
