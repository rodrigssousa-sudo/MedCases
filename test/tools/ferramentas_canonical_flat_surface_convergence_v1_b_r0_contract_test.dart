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

  test('subnav Ferramentas segue geometria canônica MedCases', () {
    final row = classBlock(tools, '_ToolsTabRow');
    final tab = classBlock(tools, '_ToolsFlatTabState');
    final tabWidget = classBlock(tools, '_ToolsFlatTab');

    expect(row, contains('height: 40'));
    expect(row, contains('Color(0xFF252930)'));
    expect(row, contains('Color(0xFFE7EBEF)'));
    expect(row, contains('width: 0.7'));
    expect(row,
        contains("['Nefrología', 'Cardio', 'Electrolitos', 'Hepatología']"));
    expect(row,
        contains("['Nefrologia', 'Cardio', 'Eletrólitos', 'Hepatologia']"));
    expect(row, contains('Icons.favorite_border'));
    expect(tabWidget, contains('final IconData icon;'));
    expect(tab, contains('softWrap: false'));
    expect(tab, contains('textAlign: TextAlign.center'));
    expect(tab, contains('fontSize: 12'));
    expect(tab, contains('height: 2'));
    expect(tab, contains('widget.tabCtrl.animateTo(widget.index)'));
  });

  test('importar paciente fica compacto e sem escala interna', () {
    final owner = classBlock(importChip, 'ToolsPatientImportChip');
    expect(owner, contains('height: 40'));
    expect(owner, contains('BorderRadius.circular(8)'));
    expect(owner, contains('fontSize: 12.5'));
    expect(owner, isNot(contains('Transform.scale(')));
    expect(owner, contains('onTap: onTap'));
  });

  test('Nefro e Hepato removem faixas grandes de seção', () {
    for (final source in [nefro, hepato]) {
      final section = classBlock(source, '_SectionLabel');
      expect(section, contains('fontSize: 12.5'));
      expect(section, contains('letterSpacing: 0.75'));
      expect(section, isNot(contains('textAlign: TextAlign.center')));
      expect(section, isNot(contains('final band =')));

      final body = classBlock(source, '_InputCard');
      expect(body, contains('color: Colors.transparent'));
      expect(body, contains('width: 0.7'));
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
