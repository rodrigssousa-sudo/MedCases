import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  const screenPath = 'lib/screens/internacion/internacion_screen.dart';
  const summaryPath = 'lib/screens/internacion/components/resumen_header.dart';
  const soapPath = 'lib/screens/internacion/components/soap/soap_section.dart';

  test('legacy cardless contract migrates to physical card surfaces', () {
    final summary = read(summaryPath);
    expect(summary, contains('MEDCASES_PACIENTES_PHYSICAL_CARD_V1'));
    expect(summary, contains('Color(0xFFFFFFFF)'));
    expect(summary, contains('Color(0xFF252930)'));

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
    expect(combined, contains('Color(0xFFFFFFFF)'));
    expect(combined, contains('Color(0xFF252930)'));
  });

  test('session card uses compact list without fixed grid extent', () {
    final src = read(screenPath);
    expect(src, isNot(contains('mainAxisExtent: 176')));
    expect(src, isNot(contains('mainAxisExtent: 142')));
    expect(src, contains('_SessionCard168'));
    expect(
      src,
      contains('MEDCASES_PACIENTES_HOME_COMPACT_SESSION_CARD_V1_B_R0'),
    );
  });

  test('principal modules stay free of heavy visual effects', () {
    final src = read(summaryPath);
    expect(src, isNot(contains('BoxShadow(')));
    expect(src, isNot(contains('LinearGradient(')));
  });

  test('productive Patients owner retains callback wiring', () {
    final src = read(screenPath);
    final callbacks = RegExp(
      r'on[A-Z][A-Za-z0-9_]*\s*:',
    ).allMatches(src).length;
    expect(callbacks, greaterThanOrEqualTo(3));
  });

  test('source-driven saved-patient phone convergence V2', () {
    final screen = read(screenPath);
    expect(
      screen,
      contains('MEDCASES_PACIENTES_FINAL_SESSION_SINGLE_COLUMN_V2'),
    );
    expect(screen, contains('MEDCASES_PACIENTES_FINAL_ACTION_FIT_V2'));
  });

  test('main functional cards borderless final contract', () {
    final screen = read(screenPath);
    expect(screen, contains('MEDCASES_PACIENTES_PATIENT_DATA_BORDERLESS_V1'));
    expect(screen, contains('MEDCASES_PACIENTES_FARMACOS_BORDERLESS_V1'));
    expect(screen, contains('MEDCASES_PACIENTES_SOAP_BORDERLESS_V1'));
    expect(screen, contains('MEDCASES_PACIENTES_SESSION_CARD_PHYSICAL_V1'));
  });

  test('Home visual parity preserves saved patients and actions', () {
    final screen = read(screenPath);
    expect(
      screen,
      contains('MEDCASES_PACIENTES_FINAL_BREATHING_GUTTER_V1_B_R0'),
    );
    expect(screen, contains('EdgeInsets.fromLTRB(16, 10, 16, 24)'));
    expect(screen, isNot(contains('left: -15.5')));
    expect(screen, isNot(contains('right: -15.5')));
    expect(screen, contains('MEDCASES_PACIENTES_SESSION_CARD_PHYSICAL_V1'));
    expect(screen, contains('MEDCASES_PACIENTES_FINAL_ACTION_FIT_V2'));
  });

}
