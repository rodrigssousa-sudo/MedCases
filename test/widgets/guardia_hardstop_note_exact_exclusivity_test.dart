import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  group('PHASE3I-J2F11C5 exact hardStop/note visual exclusivity', () {
    const duplicateLine =
        'Iniciar tratamento antibiótico emergencial — sem atrasos';

    testWidgets('exact note duplicate of HARD STOP renders once',
        (tester) async {
      final output = ClinicalStructuredOutput(
        diagnosticoHeuristico: 'Pneumonia adquirida na comunidade',
        condutaImediata: 'Iniciar antibiótico',
        prescricao: const <ClinicalPrescriptionItem>[
          ClinicalPrescriptionItem(
            farmaco: 'Ceftriaxona',
            posologia: '1–2 g IV/dia',
          ),
        ],
        primeiraLinha: const <ClinicalPrescriptionItem>[
          ClinicalPrescriptionItem(
            farmaco: 'Ceftriaxona',
            posologia: '1–2 g IV/dia',
          ),
        ],
        segundaLinha: const <ClinicalPrescriptionItem>[
          ClinicalPrescriptionItem(
            farmaco: 'Piperacilina-tazobactam',
            posologia: '4,5 g IV a cada 6h',
          ),
        ],
        hardStops: const <String>[duplicateLine],
      );

      const rawText = '''
🔴 Pneumonia adquirida na comunidade

Tratamento farmacológico:
1ª linha:
• Ceftriaxona 1–2 g IV/dia

2ª linha:
• Piperacilina-tazobactam 4,5 g IV a cada 6h

HARD STOP:
• Iniciar tratamento antibiótico emergencial — sem atrasos

📌 Iniciar tratamento antibiótico emergencial — sem atrasos
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardiaClinicalResponseView(
              rawText: rawText,
              output: output,
              dark: true,
              languageCode: 'pt',
              typedTreatmentVisualEnabled: false,
              onCopy: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains(duplicateLine),
        ),
        findsOneWidget,
      );
      expect(find.text('📌 $duplicateLine'), findsNothing);
      expect(
        find.byKey(const ValueKey('guardia_hard_stop_section')),
        findsOneWidget,
      );
    });

    testWidgets('distinct note remains visible', (tester) async {
      final output = ClinicalStructuredOutput(
        diagnosticoHeuristico: 'Pneumonia adquirida na comunidade',
        condutaImediata: 'Iniciar antibiótico',
        prescricao: const <ClinicalPrescriptionItem>[],
        hardStops: const <String>['Alergia grave sem alternativa segura'],
      );

      const rawText = '''
🔴 Pneumonia adquirida na comunidade

HARD STOP:
• Alergia grave sem alternativa segura

📌 Reavaliar resposta clínica em 48–72h
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardiaClinicalResponseView(
              rawText: rawText,
              output: output,
              dark: true,
              languageCode: 'pt',
              typedTreatmentVisualEnabled: false,
              onCopy: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text
                  .toPlainText()
                  .contains('Alergia grave sem alternativa segura'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data ?? '')
                  .contains('Reavaliar resposta clínica em 48–72h'),
        ),
        findsOneWidget,
      );
    });
  });
}
