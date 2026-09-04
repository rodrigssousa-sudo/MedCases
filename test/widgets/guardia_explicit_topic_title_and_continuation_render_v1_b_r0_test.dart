import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  testWidgets(
    'tema explícito com variação ortográfica de 1 caractere preserva o título',
    (tester) async {
      const raw = """
🟥 HEMOTÓRAX MASIVO — EXÁMENES COMPLEMENTARIOS Y MONITOREO
🚨 Exámenes complementarios:
* Radiografía de tórax — evaluar extensión del hemotórax.
* Ecografía torácica — detectar líquido en cavidad pleural.
* Hemograma completo — evaluar hemoglobina y plaquetas.
* Coagulograma — identificar alteraciones en la coagulación.
* Gasometría arterial — monitorizar oxigenación y acidemia.
🔑 Monitoreo de evolución:
* Signos vitales cada 15-30 minutos — presión arterial, FC, FR, saturación.
* Evaluar respuesta a fluidoterapia y transfusiones.
* Monitorizar diuresis — indicador de perfusión renal.
* Evaluar cambios en la capacidad respiratoria y auscultación pulmonar.
📌 Revaluar frecuentemente según clínica y resultados de exámenes.
""";

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardiaClinicalResponseView(
              rawText: raw,
              userText: 'HEMOTORAX MASSIVO',
              dark: true,
              languageCode: 'es',
              typedTreatmentVisualEnabled: false,
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('HEMOTORAX MASSIVO'),
        findsOneWidget,
      );
      expect(find.text('Orientación clínica'), findsNothing);

      expect(find.text('Exámenes complementarios'), findsOneWidget);
      expect(find.text('Monitorización y reevaluación'), findsOneWidget);

      expect(
        find.textContaining(
          'Radiografía de tórax — evaluar extensión del hemotórax',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Signos vitales cada 15-30 minutos — presión arterial, FC, FR, saturación',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Revaluar frecuentemente según clínica y resultados de exámenes',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sintoma inespecífico não ganha diagnóstico inferido como título',
    (tester) async {
      const raw = """
🟥 SÍNDROME CORONARIO AGUDO
🚨 Conducta inmediata:
* Realizar ECG de 12 derivaciones.
""";

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardiaClinicalResponseView(
              rawText: raw,
              userText: 'dolor torácico',
              dark: true,
              languageCode: 'es',
              typedTreatmentVisualEnabled: false,
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(find.text('Orientación clínica'), findsOneWidget);
      expect(find.text('SÍNDROME CORONARIO AGUDO'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
