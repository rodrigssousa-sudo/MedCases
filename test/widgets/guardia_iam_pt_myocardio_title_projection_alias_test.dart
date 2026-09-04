import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  testWidgets(
    'PT IAM + MYOCARDIO keeps confirmed title and medication presentation',
    (tester) async {
      const rawText = '''
🟥 INFARTO AGUDO DO MYOCÁRDIO — CONDUTA IMEDIATA

Conduta imediata:
• Monitorizar continuamente

Tratamento farmacológico:
• AAS 300 mg VO

Pontos-chave:
• Avaliar estratégia de reperfusão
''';

      final output = ClinicalStructuredOutput(
        diagnosticoHeuristico: 'INFARTO AGUDO DO MYOCÁRDIO',
        condutaImediata: 'AAS 300 mg VO',
        prescricao: const <ClinicalPrescriptionItem>[
          ClinicalPrescriptionItem(
            farmaco: 'AAS',
            posologia: '300 mg VO',
          ),
        ],
        condutaImediataItens: const <String>[
          'Monitorizar continuamente',
        ],
        pontosChave: const <String>[
          'Avaliar estratégia de reperfusão',
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardiaClinicalResponseView(
                rawText: rawText,
                output: output,
                dark: true,
                languageCode: 'pt',
                userText: 'IAM',
                typedTreatmentVisualEnabled: false,
                onCopy: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Orientação clínica'), findsNothing);
      expect(
        find.textContaining(
          'INFARTO AGUDO DO MYOCÁRDIO',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('guardia_pharmacologic_section')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'AAS 300 mg VO',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );
}
