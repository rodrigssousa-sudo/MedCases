import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String classBlock(String source, String className) {
  final startToken = 'class $className';
  final start = source.indexOf(startToken);
  expect(start, greaterThanOrEqualTo(0), reason: startToken);

  final next = source.indexOf('\nclass ', start + startToken.length);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  group('Light Mode Premium V1-A-R14', () {
    late String main;
    late String tools;
    late String nephro;
    late String cardio;
    late String electro;
    late String hepato;
    late String history;
    late String recorder;
    late String patients;

    setUpAll(() {
      main = read('lib/main.dart');
      tools = read('lib/screens/tools_screen.dart');
      nephro = read('lib/screens/nephrology_tools_screen.dart');
      cardio = read('lib/screens/cardio_tools_screen.dart');
      electro = read('lib/screens/electrolytes_tools_screen.dart');
      hepato = read('lib/screens/hepatology_tools_screen.dart');
      history = read('lib/screens/history_screen.dart');
      recorder = read('lib/screens/clinical_recorder_sheet.dart');
      patients = read('lib/screens/internacion/internacion_screen.dart');
    });

    test('root light theme exposes premium clinical contrast tokens', () {
      for (final token in const <String>[
        'LIGHT_MODE_PREMIUM_V1_A_R14_ROOT_THEME',
        'Color(0xFFF4F7FA)',
        'Color(0xFF0F172A)',
        'Color(0xFF475569)',
        'Color(0xFF64748B)',
        'Color(0xFF94A3B8)',
        'Color(0xFFCBD5E1)',
        'Color(0xFFE2E8F0)',
        'Color(0xFF059669)',
        'inputDecorationTheme: dark',
        'InputDecorationTheme(',
      ]) {
        expect(main, contains(token), reason: token);
      }
    });

    test('theme state and instant transition remain frozen', () {
      for (final token in const <String>[
        'class MedCasesApp extends StatefulWidget',
        'class _MedCasesAppState extends State<MedCasesApp>',
        'navigatorKey: _rootNavigatorKey',
        'home: _stableAuthGate',
        'themeAnimationDuration: Duration.zero',
        'themeAnimationCurve: Curves.linear',
      ]) {
        expect(main, contains(token), reason: token);
      }
    });

    test('fixed graphite tool tabs remain readable in light', () {
      final owner = classBlock(tools, '_ToolsFlatTabState');

      expect(owner, contains('LIGHT_MODE_PREMIUM_V1_A_R14_TOOLS_TAB'));
      expect(owner, contains('Color(0xFFA8B2C1)'));
      expect(owner, isNot(contains('Color(0xFF0F1116).withOpacity(0.45)')));
    });

    test(
      'four tool families expose adaptive inputs and real section owners',
      () {
        for (final entry in <String, String>{
          'nephro': nephro,
          'cardio': cardio,
          'electro': electro,
          'hepato': hepato,
        }.entries) {
          expect(
            entry.value,
            contains('LIGHT_MODE_PREMIUM_V1_A_R14_'),
            reason: entry.key,
          );
          expect(
            entry.value,
            contains('LIGHT_MODE_PREMIUM_V1_A_R14_SECTION_LABELS'),
            reason: '${entry.key}: section owner marker',
          );
          expect(entry.value, contains('Brightness.dark'), reason: entry.key);
          expect(
            entry.value,
            contains('Color(0xFF475569)'),
            reason: '${entry.key}: premium light section text',
          );
        }
      },
    );

    test('H Clínica OCR and vitals are explicitly light-aware', () {
      final vitals = classBlock(history, '_VitalSignsWidgetState');
      final ocr = classBlock(history, '_OcrExamButton');

      expect(
        RegExp(
          r'class _VitalSignsWidgetState extends '
          r'State<_VitalSignsWidget> \{\s*'
          r'// LIGHT_MODE_PREMIUM_V1_A_R14_VITALS',
        ).hasMatch(vitals),
        isTrue,
      );

      final expectedCounts = <String, int>{
        'LIGHT_MODE_PREMIUM_V1_A_R14_VITALS': 1,
        'Theme.of(context).brightness == Brightness.dark': 4,
        'Color(0xFF0F172A)': 3,
        'Color(0xFF475569)': 1,
        'Color(0xFF64748B)': 4,
        'Color(0xFF94A3B8)': 2,
        'Color(0xFFCBD5E1)': 4,
        'Color(0xFFFFFFFF)': 2,
        'MediaQuery.viewInsetsOf(context).bottom + 36': 2,
      };

      for (final entry in expectedCounts.entries) {
        expect(
          entry.key.allMatches(vitals).length,
          entry.value,
          reason: entry.key,
        );
      }

      for (final token in const <String>[
        '_parseExisting(widget.controller.text)',
        'c.addListener(_syncToController)',
        'c.removeListener(_syncToController)',
        "widget.controller.text = parts.join(' | ')",
        'FilteringTextInputFormatter.digitsOnly',
        'TextInputAction.next',
        'TextInputAction.done',
      ]) {
        expect(vitals, contains(token), reason: token);
      }

      expect(ocr, contains('LIGHT_MODE_PREMIUM_V1_A_R14_OCR'));
      expect(ocr, contains('color: Colors.white'));
      expect(ocr, contains('Color(0xFFCBD5E1)'));
    });

    test('new history flow options are readable on white sheet', () {
      final owner = classBlock(recorder, '_FlowOption');

      for (final token in const <String>[
        'LIGHT_MODE_PREMIUM_V1_A_R14_FLOW_OPTION',
        'final titleColor',
        'final subtitleColor',
        'final dividerColor',
        'Color(0xFF0F172A)',
        'Color(0xFF64748B)',
        'Color(0xFFE2E8F0)',
      ]) {
        expect(owner, contains(token), reason: token);
      }

      for (final token in const <String>[
        'onManual();',
        'RecorderMode.continuous',
        'RecorderMode.soapBlocks',
        'onSoapData: onSoapData',
      ]) {
        expect(recorder, contains(token), reason: token);
      }
    });

    test('patients topbar is graphite and productive owners remain', () {
      expect(patients, contains('LIGHT_MODE_PREMIUM_V1_A_R14_PATIENTS_TOPBAR'));
      expect(patients, contains('Color(0xFF252930)'));
      for (final token in const <String>[
        'PatientAccordion(',
        'FarmacosAccordion(',
        'SoapSectionWidget(',
        'InternacionFirestoreService.sessionsStream(uid)',
      ]) {
        expect(patients, contains(token), reason: token);
      }
    });
  });
}
