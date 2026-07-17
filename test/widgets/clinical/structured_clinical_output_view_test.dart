import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/widgets/clinical/structured_clinical_output_view.dart';

void main() {
  ClinicalStructuredOutput buildOutput({
    List<ClinicalPrescriptionItem>? prescriptions,
  }) {
    return ClinicalStructuredOutput(
      diagnosticoHeuristico: 'Infarto agudo do miocárdio inferior',
      condutaImediata: 'Monitorizar e iniciar reperfusão sem atraso.',
      prescricao: prescriptions ??
          const [
            ClinicalPrescriptionItem(
              farmaco: 'Ticagrelor',
              posologia: '180 mg VO em dose de ataque',
            ),
          ],
    );
  }

  Widget buildSubject({
    required bool isPlantaoMode,
    String languageCode = 'pt',
    List<ClinicalPrescriptionItem>? prescriptions,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: themeMode,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StructuredClinicalOutputView(
            output: buildOutput(prescriptions: prescriptions),
            isPlantaoMode: isPlantaoMode,
            languageCode: languageCode,
          ),
        ),
      ),
    );
  }

  testWidgets('Plantão prioriza ação imediata e exibe prescrição tipada',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(isPlantaoMode: true),
    );

    expect(find.text('Ação imediata'), findsOneWidget);
    expect(find.text('HIPÓTESE PRINCIPAL'), findsOneWidget);
    expect(find.text('CONDUTA IMEDIATA'), findsOneWidget);
    expect(find.text('Ticagrelor'), findsOneWidget);
    expect(find.text('180 mg VO em dose de ataque'), findsOneWidget);
  });

  testWidgets('Estudo apresenta síntese clínica sem alterar o conteúdo',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(isPlantaoMode: false),
    );

    expect(find.text('Síntese clínica'), findsOneWidget);
    expect(
      find.text('Infarto agudo do miocárdio inferior'),
      findsOneWidget,
    );
    expect(
      find.text('Monitorizar e iniciar reperfusão sem atraso.'),
      findsOneWidget,
    );
  });

  testWidgets('renderiza labels em espanhol', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        isPlantaoMode: true,
        languageCode: 'es',
      ),
    );

    expect(find.text('Acción inmediata'), findsOneWidget);
    expect(find.text('HIPÓTESIS PRINCIPAL'), findsOneWidget);
    expect(find.text('CONDUCTA INMEDIATA'), findsOneWidget);
    expect(find.text('Prescripción estructurada'), findsOneWidget);
  });

  testWidgets('omite bloco de prescrição quando a lista está vazia',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(
        isPlantaoMode: true,
        prescriptions: const [],
      ),
    );

    expect(
      find.byKey(const ValueKey('clinical_prescription_section')),
      findsNothing,
    );
  });

  testWidgets('renderiza corretamente em dark mode', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        isPlantaoMode: true,
        themeMode: ThemeMode.dark,
      ),
    );

    expect(
      find.byKey(const ValueKey('structured_clinical_output')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
