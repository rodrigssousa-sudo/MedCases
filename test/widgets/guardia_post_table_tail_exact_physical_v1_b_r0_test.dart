import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  Widget subject(String raw, {String languageCode = 'es'}) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GuardiaClinicalResponseView(
            rawText: raw,
            dark: true,
            languageCode: languageCode,
            onCopy: () {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'exact physical anaphylaxis tail renders after classification table',
    (tester) async {
      const raw = '''
Patología/diagnóstico: Anafilaxia.

Conducta inmediata:
- Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL.
- Evaluar vía aérea, ventilación y circulación.

Tratamiento farmacológico:
- Adrenalina IM como primera línea.

Clasificación
| Clasificación | Detalle |
|---------------|---------|
| Tipo | Anafilaxia severa |
| Síntomas | Urticaria, disnea, hipotensión |

Monitorización y reevaluación: Observar hasta la resolución completa; prolongar la observación si fue grave. Reevaluar la respuesta clínica inmediatamente después de cada intervención.

Puntos clave: La adrenalina es el tratamiento de primera línea y no se debe retrasar por otros tratamientos.

Red flags/escalamiento:
- Escalar de inmediato a equipo de emergencias/UCI ante shock, obstrucción de vía aérea, hipoxemia o refractariedad.
''';

      await tester.pumpWidget(subject(raw));
      await tester.pumpAndSettle();

      final table = find.byKey(const ValueKey('guardia_markdown_table_0'));
      final evolution = find.byKey(const ValueKey('guardia_evolution_section'));
      final keyPoints = find.byKey(
        const ValueKey('guardia_key_points_section'),
      );
      final hardStop = find.byKey(const ValueKey('guardia_hard_stop_section'));

      expect(table, findsOneWidget);
      expect(evolution, findsOneWidget);
      expect(keyPoints, findsOneWidget);
      expect(hardStop, findsOneWidget);

      expect(
        find.textContaining(
          'Observar hasta la resolución completa',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'no se debe retrasar por otros tratamientos',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Escalar de inmediato a equipo de emergencias/UCI',
          findRichText: true,
        ),
        findsOneWidget,
      );

      expect(
        tester.getTopLeft(evolution).dy,
        greaterThan(tester.getTopLeft(table).dy),
      );
      expect(
        tester.getTopLeft(keyPoints).dy,
        greaterThan(tester.getTopLeft(evolution).dy),
      );
      expect(
        tester.getTopLeft(hardStop).dy,
        greaterThan(tester.getTopLeft(keyPoints).dy),
      );
    },
  );

  testWidgets('Portuguese aliases have the same tail ownership', (
    tester,
  ) async {
    const raw = '''
Patologia/diagnóstico: Anafilaxia.
Conduta imediata: administrar adrenalina IM.
Monitorização e reavaliação: observar resolução e reavaliar após cada intervenção.
Pontos-chave: adrenalina é primeira linha.
Red flags/escalonamento:
- Escalonar para emergência/UTI diante de choque ou refratariedade.
''';

    await tester.pumpWidget(subject(raw, languageCode: 'pt'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('guardia_evolution_section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('guardia_key_points_section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('guardia_hard_stop_section')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'observar resolução e reavaliar após cada intervenção',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('adrenalina é primeira linha', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Escalonar para emergência/UTI', findRichText: true),
      findsOneWidget,
    );
  });
}
