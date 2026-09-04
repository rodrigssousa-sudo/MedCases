import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String mainSource;
  late String homePalette;
  late String notes;
  late String waHeader;
  late String copilot;
  late String aiStatus;
  late String library;
  late String meuPlantao;
  late String homePreview;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    homePalette =
        File('lib/home_v2/theme/home_v2_palette.dart').readAsStringSync();
    notes = File('lib/screens/notes_screen.dart').readAsStringSync();
    waHeader = File('lib/screens/ai/widgets/wa_header.dart').readAsStringSync();
    copilot = File(
      'lib/screens/internacion/components/copilot_button.dart',
    ).readAsStringSync();

    aiStatus =
        File('lib/screens/ai/widgets/ai_status_sheet.dart').readAsStringSync();
    library = File('lib/screens/library_screen.dart').readAsStringSync();
    meuPlantao =
        File('lib/widgets/meu_plantao_dashboard.dart').readAsStringSync();
    homePreview = File(
      'lib/home_v2/preview/home_v2_preview_screen.dart',
    ).readAsStringSync();
  });

  test('Main generic footer/nav and Notes panel use canonical brand', () {
    expect(
      mainSource,
      contains('static const _medcasesGreen = Color(0xFF0D6B57);'),
    );
    expect(
      mainSource,
      contains('static const _menuLightGreen = Color(0xFF0D6B57);'),
    );
    expect(
      RegExp(
        r'dark \? const Color\(0xFF0D6B57\) : const Color\(0xFF0D6B57\);',
      ).allMatches(mainSource).length,
      greaterThanOrEqualTo(3),
    );

    // The success card remains green/status semantics.
    expect(mainSource, contains('Nueva consulta iniciada'));
    expect(mainSource, contains('Nova consulta iniciada'));
    expect(
      RegExp(r'const Color\(0xFF00C781\)').allMatches(mainSource).length,
      2,
    );
    expect(
      RegExp(r'const Color\(0xFF008F66\)').allMatches(mainSource).length,
      2,
    );
  });

  test('Home V2 productive palette is canonical in light and dark', () {
    expect(homePalette, contains('accent: Color(0xFF0D6B57),'));
    expect(
      RegExp(r'accent: Color\(0xFF0D6B57\),').allMatches(homePalette).length,
      2,
    );
    expect(homePalette, contains('accentSoft: Color(0x1F0D6B57),'));
    expect(homePalette, contains('accentSoft: Color(0x140D6B57),'));
    expect(homePalette, isNot(contains('0xFF00C781')));
    expect(homePalette, isNot(contains('0xFF008F66')));
  });

  test('Notes editor/reminder and WA IA brand use canonical accent', () {
    expect(
      RegExp(
        r'final accent = dark \? const Color\(0xFF0D6B57\) : const Color\(0xFF0D6B57\);',
      ).allMatches(notes).length,
      2,
    );
    expect(notes, isNot(contains('0xFF00C781')));
    expect(notes, isNot(contains('0xFF008F66')));

    expect(waHeader, contains("text: ' IA',"));
    expect(waHeader, contains('color: Color(0xFF0D6B57),'));
    expect(waHeader, isNot(contains('0xFF00C781')));
  });

  test('Copilot submit generic gradient is canonical', () {
    expect(
      copilot,
      contains('colors: [Color(0xFF0D6B57), Color(0xFF0D6B57)],'),
    );
    expect(
      copilot,
      isNot(
        contains('colors: [Color(0xFF34D399), Color(0xFF047857)],'),
      ),
    );
  });

  test('Status/taxonomy/preview colors stay intentionally distinct', () {
    expect(
      aiStatus,
      contains(
        'dark ? const Color(0xFF00C781) : const Color(0xFF008F66);',
      ),
    );
    expect(
      library,
      contains(
        'return dark ? const Color(0xFF00C781) : const Color(0xFF008F66);',
      ),
    );
    expect(meuPlantao, contains("labelPt: 'Nefrologia',"));
    expect(meuPlantao, contains('color: Color(0xFF00E5FF)'));

    // Preview surface is not part of the productive-palette patch.
    expect(
      homePreview,
      contains(
        'static const accent = lightPreview ? Color(0xFF008F66) : Color(0xFF00C781);',
      ),
    );
  });
}
