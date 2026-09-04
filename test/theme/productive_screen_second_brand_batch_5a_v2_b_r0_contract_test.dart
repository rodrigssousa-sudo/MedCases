import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String mainSource;
  late String library;
  late String notes;
  late String professionalGate;
  late String patientImport;
  late String restoreBanner;
  late String commonWidgets;
  late String internacionTheme;
  late String meuPlantao;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    library = File('lib/screens/library_screen.dart').readAsStringSync();
    notes = File('lib/screens/notes_screen.dart').readAsStringSync();
    professionalGate =
        File('lib/screens/professional_gate_screen.dart').readAsStringSync();
    patientImport =
        File('lib/screens/tools_patient_import.dart').readAsStringSync();
    restoreBanner =
        File('lib/screens/tools_restore_banner.dart').readAsStringSync();
    commonWidgets = File('lib/widgets/common_widgets.dart').readAsStringSync();
    internacionTheme = File(
      'lib/screens/internacion/components/internacion_theme.dart',
    ).readAsStringSync();
    meuPlantao =
        File('lib/widgets/meu_plantao_dashboard.dart').readAsStringSync();
  });

  test('Main IA generic identity has no legacy cyan or teal literals', () {
    expect(mainSource, isNot(contains('0xFF00E5FF')));
    expect(mainSource, isNot(contains('0xFF008CA4')));
    expect(
      mainSource,
      contains(
        'dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57),',
      ),
    );
  });

  test('Library active underline and Notes add action are canonical', () {
    expect(library, isNot(contains('0xFF00E5FF')));
    expect(
      library,
      contains('BorderSide(color: Color(0xFF0D6B57), width: 2.0)'),
    );

    expect(notes, isNot(contains('0xFF00E5FF')));
    expect(notes, contains('color: Color(0xFF0D6B57)'));
  });

  test('Professional Gate uses an explicit canonical brand token', () {
    expect(professionalGate, isNot(contains('0xFF00E5FF')));
    expect(professionalGate, isNot(contains('_cyan')));
    expect(
      professionalGate,
      contains('static const _accentBrand      = Color(0xFF0D6B57);'),
    );
  });

  test('Patient Import and Restore remove stale cyan token identity', () {
    expect(patientImport, isNot(contains('0xFF00E5FF')));
    expect(patientImport, isNot(contains('_kCyan')));
    expect(patientImport, contains('_kAccentBrand'));
    expect(patientImport, contains('const _kPetroleo = Color(0xFF1A365D);'));

    expect(restoreBanner, isNot(contains('0xFF00E5FF')));
    expect(restoreBanner, isNot(contains('_kCyan')));
    expect(restoreBanner, contains('_kAccentBrand'));
    expect(restoreBanner, contains('const _kAmber'));
    expect(restoreBanner, contains('const _kRed'));
  });

  test('Common widgets premium gold stays gold in both modes', () {
    expect(
      commonWidgets,
      contains(
        'Color get gold => dark ? const Color(0xFFC5A365) : const Color(0xFFC5A365);',
      ),
    );
    expect(
      commonWidgets,
      isNot(
        contains(
          'Color get gold => dark ? const Color(0xFF00E5FF)',
        ),
      ),
    );
  });

  test('Internacion aliases advance while taxonomy owners remain preserved',
      () {
    expect(
      internacionTheme,
      contains(
        'static const Color cyan = Color(0xFF0D6B57); // compat alias -> canonical brand',
      ),
    );
    expect(
      internacionTheme,
      contains(
        'static const Color cyanDark = Color(0xFF0D6B57); // compat alias -> canonical brand',
      ),
    );

    expect(meuPlantao, contains("labelPt: 'Nefrologia'"));
    expect(meuPlantao, contains('color: Color(0xFF00E5FF)'));
  });
}
