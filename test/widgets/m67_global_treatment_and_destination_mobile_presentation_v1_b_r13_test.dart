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
  group('M67 global treatment and mobile presentation', () {
    testWidgets(
      'pharmacologic core is bold and post-semicolon detail stays normal',
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
- Verificar respuesta clínica.
Red flags/escalamiento:
- Escalar si existe deterioro.
Limitaciones / datos faltantes:
- Peso actual no proporcionado.
""";

        await tester.pumpWidget(subject(raw: raw));
        await tester.pumpAndSettle();

        // Validate the actual visible semantic owner. Do not bind this
        // contract to a private ValueKey implementation detail.
        final rich = findRichTextContaining(tester, 'Fármaco X IV 10 mg/kg');
        final renderedMedication = rich.text.toPlainText();
        expect(
          renderedMedication,
          contains(
            'Fármaco X IV 10 mg/kg de la solución 20 mg/mL; '
            'administrar en 30 minutos; máximo 1 g',
          ),
        );

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

        // R10 behavioral authority. These prints make any future owner drift
        // diagnosable without guessing source shape.
        // ignore: avoid_print
        print(
          'M67_R10_MEDICATION_WEIGHTS '
          'drug=${drug.style?.fontWeight?.value} '
          'dose=${dose.style?.fontWeight?.value} '
          'qualifier=${qualifier.style?.fontWeight?.value}',
        );

        expect(drug.style?.fontWeight, FontWeight.w800);
        expect(dose.style?.fontWeight, FontWeight.w800);
        expect(
          qualifier.style?.fontWeight?.value ?? 0,
          lessThanOrEqualTo(FontWeight.w500.value),
        );
        expect(
          rich.text.toPlainText(),
          contains('; administrar en 30 minutos; máximo 1 g'),
        );
      },
    );

    testWidgets(
      'canonical section labels render and limitations leave red flags',
      (tester) async {
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
        expect(
          find.textContaining(
            'Peso actual no proporcionado',
            findRichText: true,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'PT limitations heading with slash is separated from red flags',
      (tester) async {
        const raw = """
Síndrome clínico
Conduta imediata:
- Medida inicial.
Tratamento farmacológico:
- Fármaco X IV 10 mg; conforme resposta.
Monitorização e reavaliação:
- Reavaliar resposta.
Pontos-chave:
- Ponto clínico.
Red flags/escalonamento:
- Escalonar diante de deterioração.
Limitações / dados faltantes:
- Peso atual não informado.
""";

        await tester.pumpWidget(subject(raw: raw, lang: 'pt'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('guardia_limitations_section')),
          findsOneWidget,
        );
        expect(find.text('Limitações / dados faltantes'), findsOneWidget);
        expect(
          find.textContaining('Peso atual não informado', findRichText: true),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ES four-way destination table becomes vertical and owns the title',
      (tester) async {
        const raw = """
| Criterios | Definición |
| --- | --- |
| Observación | Estabilidad con reevaluación seriada. |
| Ingreso | Persistencia clínica que requiere hospitalización. |
| UCI | Deterioro con necesidad de soporte avanzado. |
| Alta | Resolución clínica y estabilidad. |
""";

        await tester.pumpWidget(subject(raw: raw, user: '', action: false));
        await tester.pumpAndSettle();

        expect(find.text('Destino del paciente'), findsOneWidget);
        expect(find.text('Orientación clínica'), findsNothing);
        expect(
          find.byKey(const ValueKey('guardia_destination_table_vertical')),
          findsOneWidget,
        );
        expect(find.text('Observación'), findsOneWidget);
        expect(find.text('Ingreso'), findsOneWidget);
        expect(find.text('UCI'), findsOneWidget);
        expect(find.text('Alta'), findsOneWidget);
        expect(find.byType(Table), findsNothing);

        final heading = tester.widget<Text>(find.text('Observación'));
        expect(heading.style?.fontSize, 16.0);
        expect(heading.style?.fontWeight, FontWeight.w700);
        expect(heading.style?.height, 1.28);
      },
    );

    testWidgets('PT four-way destination table gets the same mobile contract', (
      tester,
    ) async {
      const raw = """
| Critérios | Definição |
| --- | --- |
| Observação | Estabilidade com reavaliação seriada. |
| Internação | Persistência clínica que exige hospitalização. |
| UTI | Deterioração com necessidade de suporte avançado. |
| Alta | Resolução clínica e estabilidade. |
""";

      await tester.pumpWidget(
        subject(raw: raw, lang: 'pt', user: '', action: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Destino do paciente'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('guardia_destination_table_vertical')),
        findsOneWidget,
      );
      expect(find.text('Internação'), findsOneWidget);
      expect(find.text('UTI'), findsOneWidget);
      expect(find.byType(Table), findsNothing);
    });

    testWidgets('ordinary two-column table remains a true Table', (
      tester,
    ) async {
      const raw = """
Classificação
| Critério | Resultado |
| --- | --- |
| Classe | I |
| Estado | Estável |
""";

      await tester.pumpWidget(subject(raw: raw, lang: 'pt'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('guardia_destination_table_vertical')),
        findsNothing,
      );
      expect(find.byType(Table), findsOneWidget);
    });
  });
}
