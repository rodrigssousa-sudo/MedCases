import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

Widget subject(String raw) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GuardiaClinicalResponseView(
          rawText: raw,
          userText: 'Definir destino',
          userInitiatedByAction: true,
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
  group('M66 continuation typography and vertical rhythm', () {
    testWidgets(
      'numbered destination headings render bold and preserve number',
      (tester) async {
        const raw = """
Criterios que definen observación, ingreso, UCI o alta:
1. Observación:
Mejora clínica tras la primera dosis de adrenalina.
2. Ingreso:
Síntomas graves persistentes.
3. UCI:
Shock persistente o hipoxemia.
4. Alta:
Resolución completa de los síntomas.
""";

        await tester.pumpWidget(subject(raw));
        await tester.pumpAndSettle();

        for (final label in <String>[
          '1. Observación',
          '2. Ingreso',
          '3. UCI',
          '4. Alta',
        ]) {
          expect(find.text(label), findsOneWidget);
          final heading = tester.widget<Text>(find.text(label));
          expect(heading.style?.fontSize, 16.0);
          expect(heading.style?.fontWeight, FontWeight.w700);
          expect(heading.style?.height, 1.28);
        }
      },
    );

    testWidgets('continuation paragraphs keep rendered clinical content', (
      tester,
    ) async {
      const raw = """
1. Observación:
Mejora clínica tras la primera dosis de adrenalina.
Síntomas leves a moderados sin compromiso de vía aérea.
""";

      await tester.pumpWidget(subject(raw));
      await tester.pumpAndSettle();

      // The Guardia fallback parser may merge adjacent lines or render them
      // through RichText. Validate the clinical text as rendered, without
      // requiring a 1:1 raw-line -> Text widget mapping.
      expect(
        find.textContaining(
          'Mejora clínica tras la primera dosis de adrenalina',
          findRichText: true,
        ),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.textContaining(
          'Síntomas leves a moderados sin compromiso de vía aérea',
          findRichText: true,
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('unnumbered destination headings remain supported', (
      tester,
    ) async {
      const raw = """
Observación:
Paciente estable.
Ingreso:
Persistencia de síntomas.
UCI:
Shock persistente.
Alta:
Resolución completa.
""";

      await tester.pumpWidget(subject(raw));
      await tester.pumpAndSettle();

      expect(find.text('Observación'), findsOneWidget);
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text('UCI'), findsOneWidget);
      expect(find.text('Alta'), findsOneWidget);
    });

    testWidgets('M65 action-specific destination title remains preserved', (
      tester,
    ) async {
      const raw = """
Observación:
Paciente estable.
Ingreso:
Persistencia de síntomas.
UCI:
Shock persistente.
Alta:
Resolución completa.
""";

      await tester.pumpWidget(subject(raw));
      await tester.pumpAndSettle();

      expect(find.text('Destino del paciente'), findsOneWidget);
      expect(find.text('Orientación clínica'), findsNothing);
    });

    testWidgets('M65 studies title remains preserved under M66 typography', (
      tester,
    ) async {
      const raw = """
Estudios complementarios que pueden aportar información útil:
1. Hemograma completo: Puede aportar información contextual.
2. Gasometría arterial: Útil si existe hipoxemia.
""";

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardiaClinicalResponseView(
                rawText: raw,
                userText: 'Completar estudios',
                userInitiatedByAction: true,
                dark: true,
                languageCode: 'es',
                typedTreatmentVisualEnabled: false,
                onCopy: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Estudios complementarios'), findsOneWidget);
      expect(find.text('Orientación clínica'), findsNothing);
      expect(
        find.textContaining('Hemograma completo', findRichText: true),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
