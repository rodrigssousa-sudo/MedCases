import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  const screenshotPayload = """
LÍNEA RESIDUAL EN PORTUGUÉS
🟥 HIPERGLUCEMIA — AGUDA
🚨 Conducta inmediata:
* Evaluar cetonuria/cetonemia
* Buscar causas precipitantes
Tratamiento:
* **Insulina regular 0.1 U/kg SC si paciente estable**
* **Insulina rápida 0.1 U/kg SC cada 2-4 horas**
* **Si cetoacidosis/hiperosmolar: Insulina regular 0.1 U/kg IV bolo, luego 0.1 U/kg/h infusión**
HARD STOP:
* Hipoglucemia (< 70 mg/dL)
* Ajustar dosis de insulina según respuesta
Próximo paso:
* Monitorear glucemia capilar cada 2-4 horas
* Evaluar necesidad de consulta endocrinología
""";

  Widget buildSubject({
    required String rawText,
    ClinicalStructuredOutput? output,
    bool isStreaming = false,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GuardiaClinicalResponseView(
            rawText: rawText,
            output: output,
            dark: true,
            languageCode: 'es',
            onCopy: () {},
            isStreaming: isStreaming,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'Tratamiento simples encerra conduta e medicamentos aparecem uma vez',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(rawText: screenshotPayload),
      );

      for (final medication in <String>[
        'Insulina regular 0.1 U/kg SC si paciente estable',
        'Insulina rápida 0.1 U/kg SC cada 2-4 horas',
        'Si cetoacidosis/hiperosmolar: Insulina regular 0.1 U/kg IV bolo, luego 0.1 U/kg/h infusión',
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
        find.text('Conducta inmediata'),
        findsOneWidget,
      );
      expect(
        find.text('Tratamiento farmacológico'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Tratamiento:',
          findRichText: true,
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Próximo paso encerra HARD STOP e continuidade não é renderizada',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(rawText: screenshotPayload),
      );

      expect(find.text('Red flags/escalamiento'), findsOneWidget);
      expect(
        find.textContaining(
          'Hipoglucemia',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Ajustar dosis de insulina',
          findRichText: true,
        ),
        findsOneWidget,
      );

      for (final forbidden in <String>[
        'Próximo paso',
        'Monitorear glucemia capilar',
        'Evaluar necesidad de consulta endocrinología',
      ]) {
        expect(
          find.textContaining(
            forbidden,
            findRichText: true,
          ),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    'fallback residual fica oculto no final estruturado e visível no streaming',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(rawText: screenshotPayload),
      );

      expect(
        find.textContaining(
          'LÍNEA RESIDUAL EN PORTUGUÉS',
          findRichText: true,
        ),
        findsNothing,
      );

      await tester.pumpWidget(
        buildSubject(
          rawText: screenshotPayload,
          isStreaming: true,
        ),
      );

      expect(
        find.textContaining(
          'LÍNEA RESIDUAL EN PORTUGUÉS',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'conduta tipada duplicada com medicamento é removida',
    (tester) async {
      const medication = 'Insulina regular 0.1 U/kg SC si paciente estable';

      final output = ClinicalStructuredOutput(
        diagnosticoHeuristico: 'Hiperglucemia aguda',
        condutaImediata: medication,
        prescricao: const <ClinicalPrescriptionItem>[
          ClinicalPrescriptionItem(
            farmaco: 'Insulina regular',
            posologia: '0.1 U/kg SC si paciente estable',
          ),
        ],
        condutaImediataItens: const <String>[
          'Evaluar cetonuria/cetonemia',
          medication,
        ],
      );

      await tester.pumpWidget(
        buildSubject(
          rawText: screenshotPayload,
          output: output,
        ),
      );

      expect(
        find.textContaining(
          medication,
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Evaluar cetonuria/cetonemia',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  test(
    'adaptador reconhece Tratamiento e três variantes de continuidade',
    () {
      for (final heading in <String>[
        'Próximo paso:',
        'Próximo passo:',
        'Siguiente paso:',
      ]) {
        final payload = screenshotPayload.replaceFirst(
          'Próximo paso:',
          heading,
        );

        final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
          payload,
        );

        expect(output, isNotNull);
        expect(
          output?.condutaImediataItens,
          <String>[
            'Evaluar cetonuria/cetonemia',
            'Buscar causas precipitantes',
          ],
          reason: heading,
        );
        expect(output?.prescricao, hasLength(3));
        expect(
          output?.hardStops,
          <String>[
            'Hipoglucemia (< 70 mg/dL)',
            'Ajustar dosis de insulina según respuesta',
          ],
          reason: heading,
        );
      }
    },
  );
}
