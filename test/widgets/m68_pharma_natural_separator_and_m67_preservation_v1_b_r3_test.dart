import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

Widget subject({
  required String raw,
  String lang = 'es',
  String user = '',
  bool action = false,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: GuardiaClinicalResponseView(
          rawText: raw,
          userText: user,
          userInitiatedByAction: action,
          dark: true,
          languageCode: lang,
          typedTreatmentVisualEnabled: false,
          onCopy: () {},
        ),
      ),
    ),
  );
}

List<TextSpan> flattenTextSpans(InlineSpan span) {
  final out = <TextSpan>[];
  if (span is TextSpan) {
    out.add(span);
    for (final child in span.children ?? const <InlineSpan>[]) {
      out.addAll(flattenTextSpans(child));
    }
  }
  return out;
}

RichText findRichTextContaining(WidgetTester tester, String needle) {
  final matches = tester
      .widgetList<RichText>(find.byType(RichText))
      .where((widget) => widget.text.toPlainText().contains(needle))
      .toList(growable: false);
  expect(matches, isNotEmpty, reason: 'No RichText contained: $needle');
  return matches.first;
}

void main() {
  group('M68 pharmacologic presentation', () {
    testWidgets(
      'natural medication core has no artificial plus separators and preserves M67 weights',
      (tester) async {
        const raw = """
Síndrome clínico
Conducta inmediata:
- Administrar Fármaco X IV como primera línea.
Tratamiento farmacológico:
- Fármaco X IV 10 mg/kg de la solución 20 mg/mL; administrar en 30 minutos; máximo 1 g.
Monitorización y reevaluación:
- Reevaluar respuesta.
Puntos clave:
- Verificar respuesta.
Red flags/escalamiento:
- Escalar si empeora.
Limitaciones / datos faltantes:
- Peso actual no proporcionado.
""";

        await tester.pumpWidget(subject(raw: raw));
        await tester.pumpAndSettle();

        final rich = findRichTextContaining(tester, 'Fármaco X IV 10 mg/kg');
        final visible = rich.text.toPlainText();

        expect(
          visible,
          contains(
            'Fármaco X IV 10 mg/kg de la solución 20 mg/mL; '
            'administrar en 30 minutos; máximo 1 g',
          ),
        );
        expect(visible, isNot(contains(' + ')));

        final spans = flattenTextSpans(rich.text);
        final drug = spans.firstWhere(
          (span) => (span.text ?? '').contains('Fármaco X IV'),
        );
        final dose = spans.firstWhere(
          (span) => (span.text ?? '').contains('10 mg/kg'),
        );
        final qualifier = spans.firstWhere(
          (span) => (span.text ?? '').contains('; administrar'),
        );

        expect(drug.style?.fontWeight, FontWeight.w800);
        expect(dose.style?.fontWeight, FontWeight.w800);
        expect(
          qualifier.style?.fontWeight?.value ?? 0,
          lessThanOrEqualTo(FontWeight.w500.value),
        );
      },
    );

    testWidgets('M67 limitations and canonical headings remain intact', (
      tester,
    ) async {
      const raw = """
Síndrome clínico
Conducta inmediata:
- Medida inicial.
Tratamiento farmacológico:
- Fármaco X IV 10 mg; según respuesta.
Monitorización y reevaluación:
- Reevaluar respuesta.
Puntos clave:
- Punto clínico.
Red flags/escalamiento:
- Escalar ante deterioro.
Limitaciones / datos faltantes:
- Peso actual no proporcionado.
""";

      await tester.pumpWidget(subject(raw: raw));
      await tester.pumpAndSettle();

      expect(find.text('Monitorización y reevaluación'), findsOneWidget);
      expect(find.text('Red flags/escalamiento'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('guardia_limitations_section')),
        findsOneWidget,
      );
      expect(find.text('Limitaciones / datos faltantes'), findsOneWidget);
    });
  });
}
