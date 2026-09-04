import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  Widget subject(String rawText) {
    return MaterialApp(
      home: Scaffold(
        body: GuardiaClinicalResponseView(
          rawText: rawText,
          dark: false,
          languageCode: 'es',
          onCopy: () {},
        ),
      ),
    );
  }

  group('Plantao true Markdown table render V1-B-R4', () {
    testWidgets(
      'materializa tabela Markdown AHA ACC como Table Flutter real',
      (tester) async {
        const raw = '''
🟥 CATEGORÍAS AHA/ACC TEP

| Categoría | Descripción | Tratamiento recomendado |
|-----------|-------------|--------------------------|
| A | Subclínico | Evaluación clínica |
| B1 | Sintomático de baja severidad | Considerar manejo ambulatorio |
| C3 | VD anormal Y biomarcador anormal | Hospitalización y monitorización |
| D2 | Shock normotensivo / hipoperfusión | Alta vigilancia y PERT |

📌 Utilizar esta tabla para evaluar la gravedad del TEP y dirigir el tratamiento.
''';

        await tester.pumpWidget(subject(raw));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('guardia_markdown_table_0')),
          findsOneWidget,
        );
        expect(find.byType(Table), findsOneWidget);
        expect(find.text('Categoría'), findsOneWidget);
        expect(find.text('Descripción'), findsOneWidget);
        expect(find.text('Tratamiento recomendado'), findsOneWidget);
        expect(find.text('C3'), findsOneWidget);
        expect(find.text('D2'), findsOneWidget);
        expect(find.textContaining('|-----------|'), findsNothing);
      },
    );

    testWidgets(
      'lista clínica normal continua sem ser convertida em tabela',
      (tester) async {
        const raw = '''
🟥 TROMBOEMBOLISMO PULMONAR — CONDUCTA INMEDIATA

🚨 Conducta inmediata:
* Confirmar diagnóstico mediante angioTC tórax.
* Iniciar anticoagulación según indicación.
''';

        await tester.pumpWidget(subject(raw));
        await tester.pumpAndSettle();

        expect(find.byType(Table), findsNothing);
        expect(
          find.byKey(const ValueKey('guardia_markdown_table_0')),
          findsNothing,
        );
        final visibleClinicalText = find.byWidgetPredicate((widget) {
          if (widget is Text) {
            final value = widget.data ?? widget.textSpan?.toPlainText() ?? '';
            return value.contains('Confirmar diagnóstico');
          }
          if (widget is RichText) {
            return widget.text.toPlainText().contains('Confirmar diagnóstico');
          }
          return false;
        });
        expect(visibleClinicalText, findsWidgets);
      },
    );

    testWidgets(
      'tabela aceita alinhamento Markdown e pipe escapado na célula',
      (tester) async {
        const raw = r'''
🟥 TABLA DE PRUEBA

| Grupo | Regla |
|:------|------:|
| C2 | VD anormal O biomarcador |
| C3 | VD anormal \| biomarcador |
''';

        await tester.pumpWidget(subject(raw));
        await tester.pumpAndSettle();

        expect(find.byType(Table), findsOneWidget);
        expect(find.text('VD anormal | biomarcador'), findsOneWidget);
      },
    );
  });
}
