import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  const painPayload = """
🟥 DOLOR CÓLICO
💊 Tratamiento farmacologico:
* **Opción 1: Dipirona 1 g IV**
* **Opción 2: Butilbromuro de escopolamina 20 mg IV**
* **Opción 3: Morfina 2-4 mg IV si dolor intenso**
🔑 Puntos clave:
* Opción 1: Dipirona 1 g IV
* Opción 2: Butilbromuro de escopolamina 20 mg IV
* Opción 3: Morfina 2-4 mg IV si dolor intenso
* Investigar causa y definir etiología
⚠️ Alerta clínico: - No asociar AINEs si hay riesgo renal
📌 Próximo: - Reevaluar respuesta y signos de alarma
""";

  const explicitHardStopPayload = """
🟥 DOLOR CÓLICO
💊 Tratamiento farmacologico:
* **Dipirona 1 g IV**
HARD STOP: - No administrar si existe antecedente de agranulocitosis
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

  testWidgets(
    'medicamentos aparecem uma vez e não se repetem em puntos clave',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(painPayload),
      );

      for (final medication in <String>[
        'Opción 1: Dipirona 1 g IV',
        'Opción 2: Butilbromuro de escopolamina 20 mg IV',
        'Opción 3: Morfina 2-4 mg IV si dolor intenso',
      ]) {
        expect(
          find.textContaining(
            medication,
            findRichText: true,
          ),
          findsOneWidget,
          reason: 'medicamento duplicado: $medication',
        );
      }

      expect(
        find.text('Puntos clave'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Investigar causa y definir etiología',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'alerta inline tem seção própria e próximo é descartado',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(painPayload),
      );

      expect(
        find.text('Alerta clínica'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'No asociar AINEs si hay riesgo renal',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text('HARD STOP:'),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Próximo',
          findRichText: true,
        ),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Reevaluar respuesta',
          findRichText: true,
        ),
        findsNothing,
      );
    },
  );

  test(
    'adaptador não mistura alerta ou próximo em pontos-chave',
    () {
      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
        painPayload,
      );

      expect(output, isNotNull);
      expect(
        output?.pontosChave,
        <String>[
          'Investigar causa y definir etiología',
        ],
      );
      expect(output?.hardStops, isEmpty);
      expect(
        output?.pontosChave.join(' '),
        isNot(contains('Próximo')),
      );
    },
  );

  test(
    'hard stop explícito continua tipado como hard stop',
    () {
      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
        explicitHardStopPayload,
      );

      expect(output, isNotNull);
      expect(
        output?.hardStops,
        contains(
          'No administrar si existe antecedente de agranulocitosis',
        ),
      );
    },
  );

  test(
    'hierarquia tipográfica separa fármaco dose e qualificador',
    () {
      final source = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('final parts = _MedicationTextParts.from(text);'),
      );
      expect(
        source,
        contains('fontWeight: FontWeight.w600'),
      );
      expect(
        source,
        contains('fontWeight: FontWeight.w500'),
      );
      expect(
        source,
        contains('fontSize: 14.4'),
      );
      expect(
        source,
        contains('fontSize: 13.4'),
      );
    },
  );
}
