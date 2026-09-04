import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

Widget subject({
  required String raw,
  required String user,
  bool action = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GuardiaClinicalResponseView(
          rawText: raw,
          userText: user,
          userInitiatedByAction: action,
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
  group('M65 refined continuation presentation', () {
    testWidgets('Definir destino gets specific title and spaced subheads', (
      tester,
    ) async {
      const raw = '''
Criterios para observación, ingreso, UCI o alta en caso de anafilaxia:
Observación:
Paciente estable tras respuesta al tratamiento.
Ingreso:
Síntomas persistentes o dosis repetidas.
UCI:
Shock persistente o hipoxemia.
Alta:
Resolución completa y estabilidad hemodinámica.
''';

      await tester.pumpWidget(subject(raw: raw, user: 'Definir destino'));
      await tester.pumpAndSettle();

      expect(find.text('Destino del paciente'), findsOneWidget);
      expect(find.text('Orientación clínica'), findsNothing);
      expect(find.text('Observación'), findsOneWidget);
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text('UCI'), findsOneWidget);
      expect(find.text('Alta'), findsOneWidget);

      final heading = tester.widget<Text>(find.text('Observación'));
      expect(heading.style?.fontSize, 15.5);
      expect(heading.style?.fontWeight, FontWeight.w700);
    });

    testWidgets(
      'Completar estudios gets specific title and readable labeled rows',
      (tester) async {
        const raw = '''
Estudios complementarios que pueden aportar información útil:
1. Hemograma completo: Puede aportar información contextual.
2. Gasometría arterial: Útil si existe hipoxemia o disnea severa.
3. Función renal y electrolitos: Considerar según evolución clínica.
''';

        await tester.pumpWidget(subject(raw: raw, user: 'Completar estudios'));
        await tester.pumpAndSettle();

        expect(find.text('Estudios complementarios'), findsOneWidget);
        expect(find.text('Orientación clínica'), findsNothing);
        expect(
          find.textContaining('Hemograma completo:', findRichText: true),
          findsOneWidget,
        );
      },
    );

    testWidgets('initial response does not get continuation title', (
      tester,
    ) async {
      const raw = '''
Patología/diagnóstico: Anafilaxia.
Conducta inmediata:
Administrar adrenalina IM.
''';

      await tester.pumpWidget(
        subject(
          raw: raw,
          user: 'Paciente con anafilaxia. ¿Conducta?',
          action: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Destino del paciente'), findsNothing);
      expect(find.text('Estudios complementarios'), findsNothing);
    });
  });
}
