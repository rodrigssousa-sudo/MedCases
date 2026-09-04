import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  const hyperglycemiaPayload = """
🟥 SI DESHIDRATACIÓN, ADMINISTRAR SOLUCIÓN SALINA 0.9% IV
HIPERGLUCEMIA AGUDA
🚨 Conducta inmediata:
* Evaluar cetonas y estado mental
💊 Tratamiento farmacologico:
1ª linea:
* **Insulina rápida 0.1 U/kg SC**
🔑 Puntos clave:
* Descartar cetoacidosis o estado hiperosmolar
Resumo: Manejo de glucemia > 250 mg/dL para prevenir complicaciones
""";

  const screenshotHyperglycemiaPayload = """
🟥 SI DESHIDRATACIÓN, ADMINISTRAR SOLUCIÓN SALINA 0.9% IV
💊 Tratamiento farmacologico:
* **Insulina rápida 0.1 U/kg SC (si no cetoacidosis)**
🔑 Puntos clave:
* Si deshidratación, administrar Solución Salina 0.9% IV
* Cetoacidosis o estado hiperosmolar requieren UCI
* Investigar causa subyacente y ajustar tratamiento
Resumo: Manejo de glucemia > 250 mg/dL para prevenir complicaciones
""";

  const hypertensivePayload = """
🟥 CRISIS HIPERTENSIVA — URGENCIA/EMERGENCIA
💊 Tratamiento farmacologico:
* **Urgencia: Captopril 25 mg VO/SL**
* **Emergencia: Nitroprusiato 0,25-5 mcg/kg/min IV**
Evaluar daño a órgano diana
Conducta:
Confirmar PA en reposo
Si emergencia: reducir 25% PAM en 1h
Si urgencia: reducir en 24-48h
Droga de elección:
Urgencia: Captopril 25 mg VO/SL
Emergencia: Nitroprusiato 0,25-5 mcg/kg/min IV
Meta:
Emergencia: PAM -25% en 1 hora
Urgencia: PA normal en 24-48h
""";

  Widget buildSubject(String rawText) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GuardiaClinicalResponseView(
            rawText: rawText,
            output: null,
            dark: true,
            languageCode: 'es',
            onCopy: () {},
          ),
        ),
      ),
    );
  }

  test(
    'adaptador rejeita título-conduta e preserva o literal na conduta',
    () {
      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
        hyperglycemiaPayload,
      );

      expect(output, isNotNull);
      expect(
        output?.diagnosticoHeuristico,
        'HIPERGLUCEMIA AGUDA',
      );
      expect(
        output?.condutaImediataItens,
        contains(
          'SI DESHIDRATACIÓN, ADMINISTRAR SOLUCIÓN SALINA 0.9% IV',
        ),
      );
      expect(output?.primeiraLinha, hasLength(1));
    },
  );

  test(
    'adaptador encerra pontos-chave ao encontrar Resumo',
    () {
      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
        hyperglycemiaPayload,
      );

      expect(output, isNotNull);
      expect(
        output?.pontosChave,
        <String>[
          'Descartar cetoacidosis o estado hiperosmolar',
        ],
      );
      expect(
        output?.pontosChave.join(' '),
        isNot(contains('Resumo')),
      );
    },
  );

  testWidgets(
    'renderer não apresenta conduta como diagnóstico',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(
          screenshotHyperglycemiaPayload,
        ),
      );

      expect(find.text('🔴'), findsNothing);
      expect(
        find.textContaining(
          'SI DESHIDRATACIÓN, ADMINISTRAR SOLUCIÓN SALINA 0.9% IV',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Resumo'),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Insulina rápida 0.1 U/kg SC',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renderer reorganiza crise hipertensiva por títulos literais',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(hypertensivePayload),
      );

      expect(find.text('🔴'), findsNothing);
      expect(
        find.text(
          'CRISIS HIPERTENSIVA — URGENCIA/EMERGENCIA',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Conducta inmediata'),
        findsOneWidget,
      );
      expect(
        find.text('Tratamiento farmacológico'),
        findsOneWidget,
      );
      expect(
        find.text('Puntos clave'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Evaluar daño a órgano diana',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Emergencia: PAM -25% en 1 hora',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Conducta'), findsNothing);
      expect(find.text('Droga de elección'), findsNothing);
      expect(find.text('Meta'), findsNothing);
    },
  );

  test(
    'classificação farmacológica continua sem prioridade inferida',
    () {
      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
        hypertensivePayload,
      );

      expect(output, isNotNull);
      expect(output?.primeiraLinha, isEmpty);
      expect(output?.segundaLinha, isEmpty);
      expect(output?.prescricao, isNotEmpty);
    },
  );
}
