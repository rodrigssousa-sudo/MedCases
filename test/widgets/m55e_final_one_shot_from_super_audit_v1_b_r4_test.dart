import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';
import 'package:medcases/services/plantao_iamcest_killip_classification_guard.dart';
import 'package:medcases/services/plantao_pipeline.dart';

bool hasPictographic(String value) => value.runes.any(
  (rune) =>
      (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      rune == 0xFE0F ||
      rune == 0x200D ||
      rune == 0x20E3,
);

void main() {
  group('M55E R4 final IAM physical surface', () {
    const physicalCase =
        'Varón de 58 años con dolor retroesternal opresivo de 50 minutos, '
        'irradiado al brazo izquierdo, con náuseas. ECG con elevación persistente '
        'del ST en V2–V5. Troponina elevada. PA 128/78 mmHg, FC 86 lpm, '
        'SpO₂ 96% al aire ambiente. Está consciente, bien perfundido. '
        'Auscultación pulmonar sin estertores. Sin edema periférico ni '
        'ingurgitación yugular. ¿Cuál es el diagnóstico, cuál es la clasificación '
        'del IAM y cuál es la clase de Killip? Explica qué significa esa clase, '
        'por qué corresponde a este paciente y cuál es la conducta inicial.';

    const physicalBadRaw =
        '🟥 IAMCEST (Infarto Agudo de Miocardio con Elevación del ST)\n'
        '🔑 Puntos clave:\n'
        '* **Clasificación del paciente: IAMCEST** — elevación persistente del ST en V2–V5 y troponina elevada.\n'
        '* **Clase de Killip: I** — ausencia de signos de congestión pulmonar o de choque cardiogénico.\n'
        '📌 Clasificación final: IAMCEST, Killip I.\n'
        '**Significado de la clase de Killip:** Clase I sin insuficiencia cardíaca.\n'
        '🚨 **Conducta inmediata:**\n'
        '1. MONITORIZACIÓN: ECG continuo, SpO2, PA cada 15 min\n'
        '2. O2 si SpO2 <90%\n'
        '3. AAS 300 mg VO masticar + Ticagrelor 180 mg VO (o Prasugrel 60 mg si ICP)\n'
        '4. Anticoagulación: HNF 60–70 UI/kg IV bolo, máximo 5000 UI + infusión continua 12–15 UI/kg/h\n'
        '📌 Proceder con la conducta inicial según protocolos verificados';

    String guarded() => PlantaoIamcestKillipClassificationGuard.materialize(
      userInput: physicalCase,
      assistantOutput: physicalBadRaw,
      languageCode: 'es',
    );

    test('policy canonicalizes title, de-duplicates it and strips pictographs', () {
      final title = GuardiaM55ePresentationPolicy.canonicalDiseaseTitle(
        parsedDiagnosis:
            'IAMCEST (Infarto Agudo de Miocardio con Elevación del Segmento ST)',
        rawText: guarded(),
        isSpanish: true,
      );
      expect(
        title,
        'INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)',
      );
      final filtered = GuardiaM55ePresentationPolicy.withoutDuplicatedDiseaseTitle(
        items: const <String>[
          'IAMCEST (Infarto Agudo de Miocardio con Elevación del Segmento ST)',
          'Activar estrategia de reperfusión inmediata.',
        ],
        title: title,
      );
      expect(filtered, hasLength(1));
      expect(filtered.single, contains('reperfusión'));
      expect(
        hasPictographic(
          GuardiaM55ePresentationPolicy.visibleText(
            '🟥 IAMCEST 🔑 Killip I 🚨',
          ),
        ),
        isFalse,
      );
    });

    testWidgets(
      'physical final has canonical disease title, explicit classification heading and responsive 2-column table',
      (tester) async {
        final raw = guarded();
        expect(
          raw,
          startsWith(
            'IAMCEST (Infarto Agudo de Miocardio con Elevación del Segmento ST)',
          ),
        );
        expect(raw, contains('Conducta inmediata:'));
        expect(raw, contains('Tratamiento farmacológico:'));
        expect(
          raw,
          contains('| Criterio / clasificación | Resultado en este paciente |'),
        );
        expect(PlantaoParser.parse(raw), isNotNull);

        final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(raw);
        expect(output, isNotNull);
        expect(output!.condutaImediataItens, isNotEmpty);
        expect(output.prescricao, isNotEmpty);
        expect(output.pontosChave, isNotEmpty);
        expect(output.hardStops, isNotEmpty);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: SingleChildScrollView(
                  child: GuardiaClinicalResponseView(
                    rawText: raw,
                    output: output,
                    userText: physicalCase,
                    dark: true,
                    languageCode: 'es',
                    typedTreatmentVisualEnabled: false,
                    onCopy: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final title = find.text(
          'INFARTO AGUDO DE MIOCARDIO CON ELEVACIÓN DEL ST (IAMCEST)',
        );
        final immediate = find.text('Conducta inmediata');
        final classificationHeading = find.text('Clasificación');
        final tableFinder = find.byType(Table);
        expect(title, findsOneWidget);
        expect(immediate, findsOneWidget);
        expect(classificationHeading, findsOneWidget);
        expect(tableFinder, findsOneWidget);
        expect(
          tester.getTopLeft(title).dy,
          lessThan(tester.getTopLeft(immediate).dy),
        );
        expect(
          tester.getTopLeft(classificationHeading).dy,
          lessThan(tester.getTopLeft(tableFinder).dy),
        );

        final table = tester.widget<Table>(tableFinder);
        expect(table.columnWidths?[0], isA<FractionColumnWidth>());
        expect(table.columnWidths?[1], isA<FractionColumnWidth>());
        expect(tester.getSize(tableFinder).width, lessThanOrEqualTo(390));

        final visible = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
            .join('\n');
        expect(hasPictographic(visible), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
