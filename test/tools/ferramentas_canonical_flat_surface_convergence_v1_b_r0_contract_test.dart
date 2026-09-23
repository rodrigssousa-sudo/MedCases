import '../architecture/architectural_runtime_harness.dart';
import '../tools/tools_hub_runtime_harness.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String classBlock(String source, String name) {
  final match = RegExp(
    '^class\\s+${RegExp.escape(name)}\\b',
    multiLine: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: name);

  final start = match!.start;
  final next = RegExp(r'^class\s+[A-Za-z_]\w*\b', multiLine: true)
      .allMatches(source, match.end)
      .firstOrNull;

  return next == null
      ? source.substring(start)
      : source.substring(start, next.start);
}

void main() {
  late String tools;
  late String importChip;
  late String nefro;
  late String cardio;
  late String electro;
  late String hepato;

  setUpAll(() {
    tools = read('lib/screens/tools_screen.dart');
    importChip = read('lib/screens/tools_patient_import.dart');
    nefro = read('lib/screens/nephrology_tools_screen.dart');
    cardio = read('lib/screens/cardio_tools_screen.dart');
    electro = read('lib/screens/electrolytes_tools_screen.dart');
    hepato = read('lib/screens/hepatology_tools_screen.dart');
  });

  testWidgets('hub produtivo preserva geometria, paleta e rotas PT/ES',
      (tester) async {
    for (final dark in [false, true]) {
      for (final es in [false, true]) {
        await verifyToolsHub(tester, dark: dark, isEs: es);
      }
    }
  });

  test('importar paciente fica compacto e sem escala interna', () {
    final owner = classBlock(importChip, 'ToolsPatientImportChip');
    expect(owner, contains('height: 40'));
    expect(owner, contains('BorderRadius.circular(8)'));
    expect(owner, contains('fontSize: 12.5'));
    expect(owner, isNot(contains('Transform.scale(')));
    expect(owner, contains('onTap: onTap'));
  });

  testWidgets("Nefro e Hepato removem faixas grandes de seção", (tester) async {
    for (final dark in [false, true]) {
      await verifyAdaptiveScoreInputs(tester, dark: dark);
    }
  });

  test('Cardio e Eletrólitos removem section bands centralizadas', () {
    for (final source in [cardio, electro]) {
      final card = classBlock(source, '_InputCard');
      expect(card, contains('fontSize: 12.5'));
      expect(card, contains('Divider('));
      expect(card, isNot(contains('ColoredBox(')));
      expect(card, isNot(contains('textAlign: TextAlign.center')));
    }
  });

  test('inputs principais convergem para superfície canônica', () {
    final owners = <String>[
      classBlock(nefro, '_FieldBox'),
      classBlock(cardio, '_NField'),
      classBlock(electro, '_NField'),
      classBlock(hepato, '_FieldBox'),
      classBlock(hepato, '_FieldBoxFreeText'),
    ];

    for (final owner in owners) {
      expect(owner, contains('Color(0xFF20252D)'));
      expect(owner, contains('Color(0xFF2A3039)'));
      expect(owner, contains('BorderRadius.circular(10)'));
    }
  });

  test('wiring clínico, importação e clearance do footer permanecem', () {
    for (final source in [nefro, cardio, electro, hepato]) {
      expect(
        source,
        contains('InternacionFirestoreService.updatePatientLaboratories('),
      );
      expect(source, contains('showToolsPatientSelectionSheet('));
      expect(source, contains('return 114.0 + safeBottom;'));
      expect(source, contains('widthFactor: 0.90'));
      expect(source, contains('height: 46,'));
    }

    for (final token in const <String>[
      'TabController(length: 4',
      'NephrologyToolsScreen',
      'CardioToolsScreen',
      'ElectrolytesToolsScreen',
      'HepatologyToolsScreen',
    ]) {
      expect(tools, contains(token), reason: token);
    }
  });
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
