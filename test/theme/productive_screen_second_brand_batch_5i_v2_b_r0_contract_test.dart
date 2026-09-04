import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String theme;
  late String internacion;
  late String farmacos;

  setUpAll(() {
    theme = File(
      'lib/screens/internacion/components/internacion_theme.dart',
    ).readAsStringSync();
    internacion = File('lib/screens/internacion/internacion_screen.dart')
        .readAsStringSync();
    farmacos = File(
      'lib/screens/internacion/components/farmacos_accordion.dart',
    ).readAsStringSync();
  });

  test('Internacion brand and legacy aliases use canonical MedCases accent',
      () {
    expect(
      theme,
      contains(
        'static const Color accentLight = Color(0xFF0D6B57); // accent canônico MedCases',
      ),
    );
    expect(
      theme,
      contains(
        'static const Color accentDark = Color(0xFF0D6B57); // accent canônico MedCases',
      ),
    );
    expect(
      theme,
      contains(
        'static const Color cyan = Color(0xFF0D6B57); // compat alias -> canonical brand',
      ),
    );
    expect(
      theme,
      contains(
        'static const Color cyanDark = Color(0xFF0D6B57); // compat alias -> canonical brand',
      ),
    );
  });

  test('Semantic status tokens preserve previous green independently', () {
    expect(
      theme,
      contains('static const Color semanticSuccess = Color(0xFF059669);'),
    );
    expect(
      theme,
      contains('static const Color semanticStable = Color(0xFF059669);'),
    );
    expect(
      theme,
      contains('static const Color semanticProcessing = Color(0xFF059669);'),
    );
    expect(
      theme,
      contains('static const Color semanticActiveStatus = Color(0xFF059669);'),
    );

    expect(
      internacion,
      contains(
        'return InternacionTheme.semanticStable; // green = stable',
      ),
    );
    expect(
      RegExp(r'backgroundColor: InternacionTheme\.semanticSuccess,')
          .allMatches(internacion)
          .length,
      3,
    );
    expect(
      internacion,
      contains(
        'InternacionTheme.semanticActiveStatus.withOpacity(0.7)',
      ),
    );
    expect(
      internacion,
      contains('InternacionTheme.semanticProcessing'),
    );
  });

  test('Farmacos keeps its pharmacology accent independent from brand', () {
    expect(
      theme,
      contains(
        'dark ? const Color(0xFF34D399) : const Color(0xFF059669);',
      ),
    );
    expect(farmacos, isNot(contains('theme.accent')));
    expect(
      RegExp(r'theme\.pharmaAccent').allMatches(farmacos).length,
      12,
    );
  });

  test('Evolution and pharmacology taxonomy colors remain explicit', () {
    expect(
      theme,
      contains('static const Color evolutionAccent = Color(0xFF059669);'),
    );
    expect(
      internacion,
      contains('InternacionTheme.evolutionAccent,'),
    );
    expect(
      internacion,
      contains(
        "addSection('Fármacos', Icons.medication_rounded, const Color(0xFF059669));",
      ),
    );

    // SOAP section taxonomy and mixed clinical control remain untouched.
    expect(internacion, contains('? const Color(0xFF34D399)'));
    expect(
      internacion,
      contains('? const Color(0xFF10B981).withOpacity(0.72)'),
    );
  });

  test('Internacion brand gradients no longer expose the former green pair',
      () {
    expect(
      RegExp(
        r'colors: \[Color\(0xFF0D6B57\), Color\(0xFF0D6B57\)\],',
      ).allMatches(theme).length,
      2,
    );
    expect(
      theme,
      isNot(
        contains('colors: [Color(0xFF34D399), Color(0xFF059669)],'),
      ),
    );
    expect(
      theme,
      isNot(
        contains('colors: [Color(0xFF059669), Color(0xFF047857)],'),
      ),
    );
  });
}
