import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  final explicitOutput = ClinicalStructuredOutput(
    diagnosticoHeuristico: 'Síndrome coronario agudo',
    condutaImediata: 'ECG e monitorização',
    prescricao: const <ClinicalPrescriptionItem>[
      ClinicalPrescriptionItem(
        farmaco: 'AAS',
        posologia: '300 mg VO',
      ),
      ClinicalPrescriptionItem(
        farmaco: 'Ticagrelor',
        posologia: '180 mg VO',
      ),
      ClinicalPrescriptionItem(
        farmaco: 'Clopidogrel',
        posologia: '300 mg VO',
      ),
    ],
    condutaImediataItens: const <String>[
      'ECG en menos de 10 minutos',
      'Monitorización continua',
    ],
    primeiraLinha: const <ClinicalPrescriptionItem>[
      ClinicalPrescriptionItem(
        farmaco: 'AAS',
        posologia: '300 mg VO',
      ),
      ClinicalPrescriptionItem(
        farmaco: 'Ticagrelor',
        posologia: '180 mg VO',
      ),
    ],
    segundaLinha: const <ClinicalPrescriptionItem>[
      ClinicalPrescriptionItem(
        farmaco: 'Clopidogrel',
        posologia: '300 mg VO',
      ),
    ],
    pontosChave: const <String>[
      'Activar reperfusión cuando esté indicada',
    ],
    hardStops: const <String>[
      'No usar nitratos con PAS menor de 90 mmHg',
    ],
  );

  const explicitRawText = """
🟥 SÍNDROME CORONARIO AGUDO
🚨 Conducta inmediata:
* ECG en menos de 10 minutos
* Monitorización continua
💊 Tratamiento farmacologico:
1ª linea:
* **AAS 300 mg VO**
* **Ticagrelor 180 mg VO**
2ª linea:
* **Clopidogrel 300 mg VO**
🔑 Puntos clave:
* Activar reperfusión cuando esté indicada
⛔ HARD STOP:
* No usar nitratos con PAS menor de 90 mmHg
""";

  Widget buildSubject({
    ClinicalStructuredOutput? output,
    bool useDefaultOutput = true,
    String rawText = explicitRawText,
    VoidCallback? onCopy,
    VoidCallback? onTts,
    bool isStreaming = false,
    ValueNotifier<String>? notifier,
    Key? key,
    void Function(int generation)? onTextRevealed,
  }) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GuardiaClinicalResponseView(
            key: key,
            rawText: rawText,
            output: useDefaultOutput ? (output ?? explicitOutput) : output,
            dark: true,
            languageCode: 'es',
            onCopy: onCopy ?? () {},
            onTts: onTts,
            ttsReady: onTts != null,
            isStreaming: isStreaming,
            streamingTextNotifier: notifier,
            scrollGeneration: 7,
            onTextRevealed: onTextRevealed,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'renderiza as cinco seções em formato plano e compacto',
    (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('🔴'), findsNothing);
      expect(
        find.text('Conducta inmediata:'),
        findsNothing,
      );
      expect(
        find.text('Tratamiento farmacológico'),
        findsOneWidget,
      );
      expect(find.text('1ª línea:'), findsOneWidget);
      expect(find.text('2ª línea:'), findsOneWidget);
      expect(find.text('Puntos clave'), findsOneWidget);
      expect(find.text('Red flags/escalamiento'), findsOneWidget);

      expect(
        find.textContaining(
          'AAS 300 mg VO',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'streaming parcial funciona sem DTO',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(
          useDefaultOutput: false,
          rawText: """
🟥 SCA CON SUPRA
🚨 Conducta inmediata:
* ECG inmediato
💊 Tratamiento farmacologico:
1ª linea:
* **AAS 300 mg VO**
""",
          isStreaming: true,
          key: const ValueKey('guardia_same_message'),
        ),
      );

      expect(find.text('🔴'), findsNothing);
      expect(
        find.text('Conducta inmediata:'),
        findsNothing,
      );
      expect(find.text('1ª línea:'), findsOneWidget);
      expect(
        find.textContaining(
          'AAS 300 mg VO',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('guardia_streaming_cursor'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('guardia_copy_action'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'texto parcial incompleto permanece na mesma superfície',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(
          useDefaultOutput: false,
          rawText: '🟥 SCA\n🚨 Conducta inme',
          isStreaming: true,
        ),
      );

      expect(find.text('🔴'), findsNothing);
      expect(find.text('SCA'), findsOneWidget);
      expect(
        find.text('Conducta inme'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notifier atualiza texto sem reconstruir a tela pai',
    (tester) async {
      final notifier = ValueNotifier<String>(
        '🟥 SCA\n🚨 Conducta inmediata:',
      );
      var revealedGeneration = -1;

      await tester.pumpWidget(
        buildSubject(
          useDefaultOutput: false,
          rawText: notifier.value,
          isStreaming: true,
          notifier: notifier,
          onTextRevealed: (generation) {
            revealedGeneration = generation;
          },
        ),
      );

      notifier.value = """
🟥 SCA
🚨 Conducta inmediata:
* ECG inmediato
""";
      await tester.pump();

      expect(
        find.textContaining(
          'ECG inmediato',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(revealedGeneration, 7);

      await tester.pumpWidget(const SizedBox.shrink());
      notifier.dispose();
    },
  );

  testWidgets(
    'parcial e final preservam o mesmo Element pela key',
    (tester) async {
      const key = ValueKey('guardia_message_42');

      await tester.pumpWidget(
        buildSubject(
          useDefaultOutput: false,
          rawText: '🟥 SCA',
          isStreaming: true,
          key: key,
        ),
      );

      final before = tester.element(
        find.byKey(key),
      );

      await tester.pumpWidget(
        buildSubject(
          rawText: explicitRawText,
          isStreaming: false,
          key: key,
        ),
      );

      final after = tester.element(
        find.byKey(key),
      );

      expect(identical(before, after), isTrue);
      expect(find.text('1ª línea:'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('guardia_streaming_cursor'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('guardia_copy_action'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'payload legado não recebe prioridade inventada',
    (tester) async {
      final legacyOutput = ClinicalStructuredOutput(
        diagnosticoHeuristico: 'Hiperglucemia',
        condutaImediata: 'Evaluar cetonas',
        prescricao: const <ClinicalPrescriptionItem>[
          ClinicalPrescriptionItem(
            farmaco: 'Insulina regular',
            posologia: '0,1 U/kg EV',
          ),
        ],
      );

      const legacyRaw = """
🟥 HIPERGLUCEMIA
🚨 Conducta inmediata:
* Evaluar cetonas
💊 Tratamiento farmacologico:
* **Insulina regular 0,1 U/kg EV**
""";

      await tester.pumpWidget(
        buildSubject(
          output: legacyOutput,
          rawText: legacyRaw,
        ),
      );

      expect(
        find.text('Tratamiento farmacológico'),
        findsOneWidget,
      );
      expect(find.text('1ª línea:'), findsNothing);
      expect(find.text('2ª línea:'), findsNothing);
      expect(
        find.textContaining(
          'Insulina regular 0,1 U/kg EV',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'RED FLAGS e avaliação inicial são aceitos no raw novo',
    (tester) async {
      const differentialRaw = '''
🟥 DOLOR TORÁCICO — DIFERENCIALES PRIORITARIOS
🚨 Evaluación inicial:
* ECG y signos vitales según contexto
🚩 RED FLAGS:
* Inestabilidad hemodinámica o deterioro clínico
''';

      await tester.pumpWidget(
        buildSubject(
          useDefaultOutput: false,
          rawText: differentialRaw,
        ),
      );

      expect(find.text('Evaluación inicial'), findsOneWidget);
      expect(find.text('Red flags/escalamiento'), findsOneWidget);
      expect(find.text('HARD STOP:'), findsNothing);
      expect(
        find.textContaining(
          'Inestabilidad hemodinámica',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'copy e ouvir permanecem funcionais no final',
    (tester) async {
      var copied = false;
      var spoken = false;

      await tester.pumpWidget(
        buildSubject(
          onCopy: () => copied = true,
          onTts: () => spoken = true,
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey('guardia_copy_action'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey('guardia_tts_action'),
        ),
      );

      expect(copied, isTrue);
      expect(spoken, isTrue);
    },
  );
}
