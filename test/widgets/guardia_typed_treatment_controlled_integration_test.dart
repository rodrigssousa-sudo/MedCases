import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  const concomitantFixture = '''
🟥 Síndrome coronariana aguda

Tratamento inicial combinado:
- **AAS** 300 mg VO
- **Clopidogrel** 300 mg VO

Alerta clínico:
- Monitorar hipotensão

HARD STOP:
- Não administrar nitrato com PAS menor de 90 mmHg
''';
  const priorityFixture = '''
🟥 Síndrome coronariana aguda

1ª linha:
- **AAS** 300 mg VO

2ª linha:
- **Clopidogrel** 300 mg VO
''';
  const genericFixture = '''
🟥 Síndrome coronariana aguda

Tratamento farmacológico:
- **AAS** 300 mg VO
- **Clopidogrel** 300 mg VO
''';

  Widget host(String fixture, bool enabled,
      {String languageCode = 'pt', bool dark = false}) {
    final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(fixture);
    expect(output, isNotNull);
    return MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: GuardiaClinicalResponseView(
                    rawText: fixture,
                    output: output,
                    dark: dark,
                    languageCode: languageCode,
                    onCopy: () {},
                    typedTreatmentVisualEnabled: enabled))));
  }

  group('PHASE3I-J2F10B controlled productive visual integration', () {
    testWidgets('default enabled renders typed once', (tester) async {
      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(
          concomitantFixture);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: GuardiaClinicalResponseView(
                  rawText: concomitantFixture,
                  output: output,
                  dark: false,
                  languageCode: 'pt',
                  onCopy: () {}))));
      await tester.pump();
      expect(find.byKey(const ValueKey('guardia_typed_treatment_section')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('guardia_pharmacologic_section')),
          findsNothing);
      expect(find.text('Tratamento concomitante:'), findsOneWidget);
    });
    testWidgets('explicit disabled preserves legacy rollback', (tester) async {
      await tester.pumpWidget(host(concomitantFixture, false));
      await tester.pump();
      expect(find.byKey(const ValueKey('guardia_pharmacologic_section')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('guardia_typed_treatment_section')),
          findsNothing);
    });
    testWidgets('typed owns alert and hard stop without duplication',
        (tester) async {
      await tester.pumpWidget(host(concomitantFixture, true));
      await tester.pump();
      expect(find.text('Alerta clínico:'), findsOneWidget);
      expect(find.text('HARD STOP:'), findsOneWidget);
      expect(find.byKey(const ValueKey('guardia_alert_section')), findsNothing);
      expect(find.byKey(const ValueKey('guardia_hard_stop_section')),
          findsNothing);
    });
    testWidgets('first and second line force legacy', (tester) async {
      await tester.pumpWidget(host(priorityFixture, true));
      await tester.pump();
      expect(find.byKey(const ValueKey('guardia_typed_treatment_section')),
          findsNothing);
      expect(find.byKey(const ValueKey('guardia_first_line_section')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('guardia_second_line_section')),
          findsOneWidget);
    });
    testWidgets('generic prescription forces legacy', (tester) async {
      await tester.pumpWidget(host(genericFixture, true));
      await tester.pump();
      expect(find.byKey(const ValueKey('guardia_typed_treatment_section')),
          findsNothing);
      expect(find.byKey(const ValueKey('guardia_pharmacologic_section')),
          findsOneWidget);
    });
    testWidgets('Spanish dark typed is exclusive and narrow-safe',
        (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final es = concomitantFixture
          .replaceAll('Síndrome coronariana aguda', 'Síndrome coronaria aguda')
          .replaceAll('Tratamento inicial combinado', 'Tratamiento combinado')
          .replaceAll('Monitorar hipotensão', 'Vigilar hipotensión')
          .replaceAll('Não administrar nitrato com PAS menor de 90 mmHg',
              'No administrar nitrato con PAS menor de 90 mmHg');
      await tester.pumpWidget(host(es, true, languageCode: 'es', dark: true));
      await tester.pump();
      expect(find.text('Tratamiento concomitante:'), findsOneWidget);
      expect(find.text('Tratamento concomitante:'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
