import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

Widget subject(String raw) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: GuardiaClinicalResponseView(
          rawText: raw,
          userText: '',
          userInitiatedByAction: false,
          dark: true,
          languageCode: 'es',
          typedTreatmentVisualEnabled: false,
          onCopy: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('M69 keeps only the divider immediately below the main title', (
    tester,
  ) async {
    const raw = """
Síndrome clínico
Conducta inmediata:
- Acción inmediata.
Tratamiento farmacológico:
- Fármaco X IV 10 mg; según respuesta.
Exámenes complementarios:
- Estudio A.
Monitorización y reevaluación:
- Reevaluar respuesta.
Preguntas clave:
- Pregunta A.
Puntos clave:
- Punto A.
Red flags/escalamiento:
- Escalar ante deterioro.
Limitaciones / datos faltantes:
- Peso no informado.
""";

    await tester.pumpWidget(subject(raw));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('guardia_divider_before_immediate')),
      findsOneWidget,
    );

    for (final key in <String>[
      'guardia_divider_before_medication',
      'guardia_divider_before_exams',
      'guardia_divider_before_evolution',
      'guardia_divider_before_questions',
      'guardia_divider_before_key_points',
      'guardia_divider_before_alert',
      'guardia_divider_before_hard_stop',
    ]) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
    }

    expect(find.text('Conducta inmediata'), findsOneWidget);
    expect(find.text('Tratamiento farmacológico'), findsOneWidget);
    expect(find.text('Monitorización y reevaluación'), findsOneWidget);
    expect(find.text('Puntos clave'), findsOneWidget);
    expect(find.text('Red flags/escalamiento'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guardia_limitations_section')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'M69 source keeps one section-divider call and preserves table borders',
    () {
      final source = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      final calls = RegExp(
        r"_GuardiaSectionDivider\(\s*"
        r"key:\s*const\s*ValueKey\('guardia_divider_before_[^']+'\),",
        multiLine: true,
      ).allMatches(source).length;

      expect(calls, 1);
      expect(source, contains('guardia_divider_before_immediate'));
      expect(source, isNot(contains('guardia_divider_before_medication')));
      expect(source, isNot(contains('guardia_divider_before_exams')));
      expect(source, isNot(contains('guardia_divider_before_evolution')));
      expect(source, isNot(contains('guardia_divider_before_questions')));
      expect(source, isNot(contains('guardia_divider_before_key_points')));
      expect(source, isNot(contains('guardia_divider_before_alert')));
      expect(source, isNot(contains('guardia_divider_before_hard_stop')));

      expect(source, contains('TableBorder('));
      expect(source, contains('horizontalInside:'));
      expect(source, contains('verticalInside:'));
      expect(
        source,
        contains('M69_SINGLE_TITLE_DIVIDER_CLEAN_SECTION_RHYTHM_V1'),
      );
    },
  );
}
