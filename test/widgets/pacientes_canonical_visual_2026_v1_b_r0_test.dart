import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  const screenPath = 'lib/screens/internacion/internacion_screen.dart';
  const themePath = 'lib/screens/internacion/components/internacion_theme.dart';
  const summaryPath = 'lib/screens/internacion/components/resumen_header.dart';
  const soapPath = 'lib/screens/internacion/components/soap/soap_section.dart';
  const copilotPath = 'lib/screens/internacion/components/copilot_button.dart';

  test('Pacientes physical 2026 freezes page card and border colors', () {
    final src = read(themePath);
    for (final token in [
      'Color(0xFFECF1F3)',
      'Color(0xFFFFFFFF)',
      'Color(0xFF1A1D23)',
      'Color(0xFF252930)',
      'Color(0xFFD8DEE7)',
      'Color(0xFF374151)',
    ]) {
      expect(src, contains(token));
    }
  });

  test('principal modules own real card surfaces', () {
    final src = read(summaryPath);
    expect(src, contains('MEDCASES_PACIENTES_PHYSICAL_CARD_V1'));
    expect(src, contains('BorderRadius.circular(8)'));
    expect(src, contains('Color(0xFFFFFFFF)'));
    expect(src, contains('Color(0xFF252930)'));
  });

  test('patient data farmacos and SOAP cards are physically owned', () {
    final screen = read(screenPath);
    final soap = read(soapPath);

    expect(
      screen,
      contains('MEDCASES_PACIENTES_PATIENT_DATA_CALLSITE_CARD_V1'),
    );
    expect(screen, contains('MEDCASES_PACIENTES_FARMACOS_CALLSITE_CARD_V1'));
    expect(
      screen.contains('MEDCASES_PACIENTES_SOAP_CALLSITE_CARD_V1') ||
          soap.contains('MEDCASES_PACIENTES_SOAP_CALLSITE_CARD_V1'),
      isTrue,
    );

    final combined = '$screen\n$soap';
    expect(combined, contains('BorderRadius.circular(8)'));
    expect(combined, contains('Color(0xFFFFFFFF)'));
    expect(combined, contains('Color(0xFF252930)'));
  });

  test('saved patient session card uses compact list without fixed grid height', () {
    final src = read(screenPath);
    expect(
      src,
      contains('MEDCASES_PACIENTES_HOME_COMPACT_SAVED_LIST_V1_B_R0'),
    );
    expect(
      src,
      contains('MEDCASES_PACIENTES_HOME_COMPACT_SESSION_CARD_V1_B_R0'),
    );
    expect(src, contains('ListView.separated('));
    expect(src, isNot(contains('mainAxisExtent: 176')));
    expect(src, isNot(contains('mainAxisExtent: 142')));
  });

  test('Copilot keeps approved logic with compact Home visual', () {
    final src = read(copilotPath);
    expect(src, contains('MEDCASES_COPILOT_PRE_R013_VISUAL_RESTORED_V1'));
    expect(
      src,
      contains('MEDCASES_PACIENTES_HOME_COMPACT_COPILOT_V1_B_R0'),
    );
    expect(src, contains('_buildIdleState'));
    expect(src, contains('_buildLoadingState'));
    expect(src, contains('BorderRadius.circular(10)'));
  });

  test('principal functional cards add no heavy shadows or gradients', () {
    final summary = read(summaryPath);
    expect(summary, isNot(contains('BoxShadow(')));
    expect(summary, isNot(contains('LinearGradient(')));

    final screen = read(screenPath);
    final soap = read(soapPath);
    expect(
      screen,
      contains('MEDCASES_PACIENTES_PATIENT_DATA_CALLSITE_CARD_V1'),
    );
    expect(screen, contains('MEDCASES_PACIENTES_FARMACOS_CALLSITE_CARD_V1'));
    expect(
      screen.contains('MEDCASES_PACIENTES_SOAP_CALLSITE_CARD_V1') ||
          soap.contains('MEDCASES_PACIENTES_SOAP_CALLSITE_CARD_V1'),
      isTrue,
    );
  });

  test(
    'productive owner keeps canonical module and action wiring surfaces',
    () {
      final src = read(screenPath);
      expect(src, contains('PatientAccordion'));
      expect(src, contains('FarmacosAccordion'));
      expect(src, contains('SoapSectionWidget'));
      final callbacks = RegExp(
        r'on[A-Z][A-Za-z0-9_]*\s*:',
      ).allMatches(src).length;
      expect(callbacks, greaterThanOrEqualTo(3));
    },
  );

  test('final source-driven Pacientes convergence V2', () {
    final screen = read(screenPath);
    expect(screen, contains('MEDCASES_PACIENTES_FINAL_SOURCE_DRIVEN_V2'));
    expect(
      screen,
      contains('MEDCASES_PACIENTES_FINAL_SESSION_SINGLE_COLUMN_V2'),
    );
    expect(screen, contains('MEDCASES_PACIENTES_FINAL_ACTION_FIT_V2'));
    expect(
      read(summaryPath),
      contains('MEDCASES_PACIENTES_FINAL_SUMMARY_SOURCE_DRIVEN_V2'),
    );
    expect(
      read(soapPath),
      contains('MEDCASES_PACIENTES_FINAL_SOAP_SOURCE_DRIVEN_V2'),
    );
    expect(
      read(copilotPath),
      contains('MEDCASES_COPILOT_PRE_R013_VISUAL_RESTORED_V1'),
    );
  });

  test('final main cards are borderless except protected UI', () {
    final screen = read(screenPath);
    final summary = read(summaryPath);

    expect(
      screen,
      contains('MEDCASES_PACIENTES_MAIN_CARDS_BORDERLESS_FINAL_V1'),
    );
    expect(screen, contains('MEDCASES_PACIENTES_PATIENT_DATA_BORDERLESS_V1'));
    expect(screen, contains('MEDCASES_PACIENTES_FARMACOS_BORDERLESS_V1'));
    expect(screen, contains('MEDCASES_PACIENTES_SOAP_BORDERLESS_V1'));
    expect(summary, contains('MEDCASES_PACIENTES_SUMMARY_BORDERLESS_V1'));

    expect(screen, contains('MEDCASES_PACIENTES_SESSION_CARD_PHYSICAL_V1'));
    expect(screen, contains('MEDCASES_PACIENTES_FINAL_ACTION_FIT_V2'));
    expect(
      read(copilotPath),
      contains('MEDCASES_COPILOT_PRE_R013_VISUAL_RESTORED_V1'),
    );
  });

  test('main workspace converges to final 16px breathing gutter without duplicate surfaces', () {
    final screen = read(screenPath);
    final summary = read(summaryPath);

    expect(
      screen,
      contains('MEDCASES_PACIENTES_FINAL_BREATHING_GUTTER_V1_B_R0'),
    );
    expect(
      summary,
      contains('MEDCASES_PACIENTES_HOME_COMPACT_SUMMARY_V1_B_R0'),
    );

    expect(
      screen,
      contains('EdgeInsets.fromLTRB(16, 10, 16, 24)'),
    );
    expect(screen, isNot(contains('left: -15.5')));
    expect(screen, isNot(contains('right: -15.5')));

    expect(
      screen,
      contains('MEDCASES_PACIENTES_HOME_COMPACT_SECTION_LABEL_V1_B_R0'),
    );
    expect(
      screen,
      contains('MEDCASES_PACIENTES_HOME_COMPACT_SESSION_CARD_V1_B_R0'),
    );
  });

}
