import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  const raw = '''
🟥 INFARTO AGUDO DE MIOCARDIO — CONDUTA INMEDIATA
🚨 Conducta inmediata:
* AAS **300 mg VO** — masticar si es posible
* Monitoreo continuo de signos vitales
* Acceso a vía intravenosa
💊 Tratamiento farmacológico:
* **Clopidogrel** — dosis a definir según estrategia clínica
* **Nitroglicerina** — según tolerancia y dolor anginoso
🔑 Puntos clave:
* Evaluar función cardíaca y riesgo de complicaciones
* Considerar estrategia de reperfusión si indica el cuadro
🚩 RED FLAGS:
* Hipotensión severa, signos de choque o complicaciones agudas
📌 Iniciar manejo agresivo en base a protocolos establecidos.
''';

  final partialOutput = ClinicalStructuredOutput(
    diagnosticoHeuristico: 'INFARTO AGUDO DE MIOCARDIO',
    condutaImediata: 'AAS 300 mg VO — masticar si es posible',
    prescricao: const <ClinicalPrescriptionItem>[
      ClinicalPrescriptionItem(
        farmaco: 'AAS',
        posologia: '300 mg VO — masticar si es posible',
      ),
    ],
    condutaImediataItens: const <String>[
      'Monitoreo continuo de signos vitales',
      'Acceso a vía intravenosa',
    ],
    pontosChave: const <String>[
      'Evaluar función cardíaca y riesgo de complicaciones',
      'Considerar estrategia de reperfusión si indica el cuadro',
    ],
    hardStops: const <String>[
      'Hipotensión severa, signos de choque o complicaciones agudas',
    ],
  );

  Widget host() {
    return MaterialApp(
      home: Scaffold(
        body: GuardiaClinicalResponseView(
          rawText: raw,
          userText: 'IAM',
          output: partialOutput,
          dark: true,
          languageCode: 'es',
          onCopy: () {},
          typedTreatmentVisualEnabled: false,
        ),
      ),
    );
  }

  int visibleTextCount(String text) {
    return find.textContaining(text, findRichText: true).evaluate().length;
  }

  testWidgets(
    'partial typed DTO enriches raw medication section without deleting nonnumeric drugs',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      expect(
        find.byKey(const ValueKey('guardia_pharmacologic_section')),
        findsOneWidget,
      );
      expect(visibleTextCount('AAS 300 mg VO'), 1);
      expect(
        visibleTextCount(
          'Clopidogrel — dosis a definir según estrategia clínica',
        ),
        1,
      );
      expect(
        visibleTextCount('Nitroglicerina — según tolerancia y dolor anginoso'),
        1,
      );
      expect(find.text('Orientación clínica'), findsNothing);
    },
  );
}
