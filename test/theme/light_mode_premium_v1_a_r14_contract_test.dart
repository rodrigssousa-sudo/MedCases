import '../theme/current_theme_runtime_harness.dart';
import '../history_clinical/history_release_runtime_harness.dart';
import '../architecture/architectural_runtime_harness.dart';
import '../tools/tools_hub_runtime_harness.dart';
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
    late String history;
    late String recorder;
    late String patients;

    setUpAll(() {
      main = read('lib/main.dart');
      history = read('lib/screens/history_screen.dart');
      recorder = read('lib/screens/clinical_recorder_sheet.dart');
      patients = read('lib/screens/internacion/internacion_screen.dart');
    });

    testWidgets("root light theme exposes premium clinical contrast tokens",
        (tester) async {
      await verifyRootTheme(tester);
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

    testWidgets('productive specialty hub remains readable in light and dark',
        (tester) async {
      for (final dark in [false, true]) {
        for (final es in [false, true]) {
          await verifyToolsHub(tester, dark: dark, isEs: es);
        }
      }
    });

    testWidgets(
        "four tool families expose adaptive inputs and real section owners",
        (tester) async {
      for (final dark in [false, true]) {
        await verifyAdaptiveScoreInputs(tester, dark: dark);
      }
    });

    testWidgets("H Clínica OCR and vitals are explicitly light-aware",
        (tester) async {
      for (final dark in [false, true]) {
        await verifyHistoryVitals(tester, dark: dark);
        await verifyHistoryOcrPicker(tester, dark: dark);
      }
      final vitals = classBlock(history, '_VitalSignsWidgetState');
      for (final token in const <String>[
        '_parseExisting(widget.controller.text)',
        'c.addListener(_syncToController)',
        'c.removeListener(_syncToController)',
        "widget.controller.text = parts.join(' | ')",
        'FilteringTextInputFormatter.digitsOnly',
        'TextInputAction.next',
        'TextInputAction.done'
      ]) {
        expect(vitals, contains(token), reason: token);
      }
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
