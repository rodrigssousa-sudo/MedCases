import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String lab;
  late String home;
  late String homeV2;
  late String mainSource;
  late String model;
  late String catalog;
  late String modules;

  setUpAll(() {
    lab = File('lib/screens/laboratory_screen.dart').readAsStringSync();
    home = File('lib/screens/home_screen.dart').readAsStringSync();
    homeV2 = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
    model = File('lib/models/lab_reference_model.dart').readAsStringSync();
    catalog = File('lib/data/laboratory/lab_reference_catalog.dart')
        .readAsStringSync();
    modules = File('lib/home_v2/components/home_v2_modules_view.dart')
        .readAsStringSync();
  });

  test('Laboratório is a MainShell workspace with a reset bridge', () {
    expect(lab, contains('class LaboratoryMainShellWorkspace'));
    expect(lab, contains('abstract final class LaboratorySessionBridge'));
    expect(lab, contains('ValueNotifier<int> resetSerial'));
    expect(mainSource, contains('LaboratoryMainShellWorkspace'));
    expect(
      mainSource,
      contains('LaboratoryMainShellWorkspace(onBack: _closeLaboratory)'),
    );
    expect(mainSource, contains('void _closeLaboratory() => _onTabChange(0);'));
    expect(mainSource, contains('if (_tab == 9 && t != 9)'));
    expect(mainSource, contains('LaboratorySessionBridge.reset();'));
  });

  test('Home opens tab 9 instead of a parallel Navigator route', () {
    expect(home, contains('widget.onTabChange(9);'));
    expect(home, isNot(contains('LaboratoryScreen(')));
    expect(homeV2, contains('HomeAssessmentNotesTimerCard('));
    expect(homeV2, contains('onTabChange: onTabChange,'));
  });

  test('global footer remains single-owner in MainShell', () {
    expect(
      RegExp(r'class\s+_FloatingFooter\s+extends\s+StatefulWidget')
          .allMatches(mainSource)
          .length,
      1,
    );
    expect(
        RegExp(r'return\s+_FloatingFooter\s*\(').hasMatch(mainSource), isTrue);
    expect(lab, isNot(contains('_FloatingFooter(')));
    expect(lab, isNot(contains('bottomNavigationBar:')));
  });

  test('iPad persistent AI split remains intact', () {
    expect(mainSource,
        contains('final bool showPersistentAiSplit = width >= 1024;'));
    expect(mainSource, contains('_staticScreens[leftPaneIndex]'));
    expect(mainSource, contains('_staticScreens[2]'));
  });

  test('root visual contract is compact and physical-card based', () {
    expect(lab, contains("'FILTRO'"));
    expect(lab, contains("widget.isEs ? 'Limpiar' : 'Limpar'"));
    expect(lab, contains('color: surface'));
    expect(lab, contains('const Color(0xFFFFFFFF)'));
    expect(lab, contains('const Color(0xFF252930)'));
    expect(lab, contains('BorderRadius.circular(8)'));
    expect(lab, contains('EdgeInsets.fromLTRB(4, 8, 4, bottomClearance)'));
    expect(lab, contains('EdgeInsets.fromLTRB(4, 6, 4, bottomClearance)'));
    expect(lab, contains('EdgeInsets.only(bottom: 3)'));
    expect(lab, contains('SizedBox(width: 3)'));
    expect(lab, contains('114.0 + safeBottom'));
    expect(lab, contains('fontSize: 9.8'));
    expect(lab, isNot(contains('Consulta clínica de referencia')));
    expect(lab, isNot(contains('Consulta clínica de referência')));
  });

  test('topbar keeps centered title and physically left back action', () {
    expect(lab, contains('height: topPad + 48'));
    expect(lab, contains('ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14)'));
    expect(lab, contains('left: 4'));
    expect(lab, contains('width: 36'));
    expect(lab, contains('height: 36'));
    expect(lab, contains('fontSize: 16'));
    expect(lab, contains('letterSpacing: 1.2'));
  });

  test('age sex pregnancy and method filters are source-driven', () {
    for (final token in <String>[
      "String _age = 'all';",
      "String _sex = 'all';",
      "String _pregnancy = 'all';",
      "String _method = 'all';",
      'abstract final class _LabPresentationFilter',
      'static bool methodMatches',
      'static List<LabValueLine> lines',
      'static bool recordMatches',
      'static _AgeSpan? _ageSpan',
      "pregnancy == 'pregnant'",
    ]) {
      expect(lab, contains(token), reason: token);
    }
  });

  test('category detail stays inside Lab workspace instead of pushing route',
      () {
    expect(lab, contains('LabReferenceCategory? _selectedCategory;'));
    expect(lab, contains('setState(() => _selectedCategory = category);'));
    expect(lab, contains('setState(() => _selectedCategory = null)'));
  });

  test('clinical model catalog and Home visual owner still exist', () {
    expect(model, contains('class LabReferenceRecord'));
    expect(model, contains('class LabValueLine'));
    expect(catalog,
        contains('static List<LabReferenceRecord> recordsForCategory'));
    expect(modules, contains('onLaboratory'));
  });
}
