import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  Widget subject({
    required String rawText,
    ClinicalStructuredOutput? output,
    String languageCode = 'pt',
  }) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GuardiaClinicalResponseView(
            rawText: rawText,
            output: output,
            dark: true,
            languageCode: languageCode,
            onCopy: () {},
            isStreaming: false,
            scrollGeneration: 1,
          ),
        ),
      ),
    );
  }

  final misleadingTypedOutput = ClinicalStructuredOutput(
    diagnosticoHeuristico: 'Hiperglicemia aguda',
    condutaImediata: 'Conduta genérica do DTO',
    prescricao: const <ClinicalPrescriptionItem>[],
    condutaImediataItens: const <String>[
      'Conduta genérica do DTO',
    ],
    pontosChave: const <String>[
      'Ponto genérico do DTO',
    ],
    hardStops: const <String>[
      'Hard stop genérico do DTO',
    ],
  );

  testWidgets(
    'Exames e evolução preservam o raw final como estrutura canônica',
    (tester) async {
      const raw = """
🟥 HIPERGLICEMIA AGUDA — EXAMES E MONITORIZAÇÃO
Exames complementares:
* Glicemia capilar seriada
* Gasometria venosa e eletrólitos
Monitorização da evolução:
* Monitorar glicemia e potássio a cada 2 horas
* Reavaliar hidratação e diurese
⛔ HARD STOP:
* Não iniciar insulina se K+ menor que 3,3 mEq/L
📌 Reavaliar a resposta clínica a cada 1-2 horas
""";

      await tester.pumpWidget(
        subject(
          rawText: raw,
          output: misleadingTypedOutput,
        ),
      );

      expect(find.text('Exames complementares'), findsOneWidget);
      expect(find.text('Monitorização e reavaliação'), findsOneWidget);

      for (final item in <String>[
        'Glicemia capilar seriada',
        'Gasometria venosa e eletrólitos',
        'Monitorar glicemia e potássio a cada 2 horas',
        'Reavaliar hidratação e diurese',
      ]) {
        expect(
          find.textContaining(
            item,
            findRichText: true,
          ),
          findsOneWidget,
        );
      }

      expect(find.text('Conduta imediata'), findsNothing);
      expect(find.text('Pontos-chave'), findsNothing);
      expect(find.textContaining('Conduta genérica do DTO'), findsNothing);
      expect(find.textContaining('Ponto genérico do DTO'), findsNothing);
      expect(find.textContaining('Hard stop genérico do DTO'), findsNothing);

      expect(
        find.textContaining(
          'Não iniciar insulina',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text('Reavaliar a resposta clínica a cada 1-2 horas'),
        findsOneWidget,
      );

      final hardStopTop = tester.getTopLeft(find.byKey(const ValueKey('guardia_hard_stop_section'))).dy;
      final noteTop = tester
          .getTopLeft(
            find.text(
              'Reavaliar a resposta clínica a cada 1-2 horas',
            ),
          )
          .dy;

      expect(noteTop, greaterThan(hardStopTop));
    },
  );

  testWidgets(
    'Perguntas-chave não são convertidas em Pontos-chave',
    (tester) async {
      const raw = """
🟥 HIPERGLICEMIA AGUDA — PERGUNTAS-CHAVE
Perguntas-chave:
* Quando começou a hiperglicemia?
* Usa insulina ou antidiabéticos?
* Houve febre, infecção ou omissão de doses?
* Apresenta poliúria, polidipsia ou vômitos?
* Há alteração do sensório?
* Qual foi a última alimentação?
""";

      await tester.pumpWidget(
        subject(
          rawText: raw,
          output: misleadingTypedOutput,
        ),
      );

      expect(find.text('Perguntas-chave'), findsOneWidget);
      expect(find.text('Pontos-chave'), findsNothing);
      expect(find.text('Conduta imediata'), findsNothing);

      for (final item in <String>[
        'Quando começou a hiperglicemia?',
        'Usa insulina ou antidiabéticos?',
        'Houve febre, infecção ou omissão de doses?',
        'Apresenta poliúria, polidipsia ou vômitos?',
        'Há alteração do sensório?',
        'Qual foi a última alimentação?',
      ]) {
        expect(
          find.textContaining(
            item,
            findRichText: true,
          ),
          findsOneWidget,
        );
      }

      expect(find.textContaining('Ponto genérico do DTO'), findsNothing);
      expect(find.textContaining('Hard stop genérico do DTO'), findsNothing);
    },
  );

  testWidgets(
    'Perguntas para orientação preserva as sete perguntas físicas da H12',
    (tester) async {
      const raw = """
🟥 HIPERGLICEMIA AGUDA — PERGUNTAS-CHAVE
🚨 Perguntas para orientação:
* Há histórico de diabetes? Qual a última glicemia conhecida?
* Está utilizando insulina ou antidiabéticos orais regularmente? Qual a dose?
* Notou sinais de infecção, como febre, dor ou sintomas respiratórios?
* Quando foi a última refeição e o que foi consumido?
* Tem sentido polidipsia, poliúria ou perda de peso recente?
* Está tomando outros medicamentos que possam influenciar a glicemia?
* Já teve episódios semelhantes? Como foram tratados?
📌 Esses questionamentos ajudam a identificar a causa e a direcionar o manejo adequado.
""";

      await tester.pumpWidget(
        subject(
          rawText: raw,
          output: misleadingTypedOutput,
        ),
      );

      expect(find.text('Perguntas-chave'), findsOneWidget);
      expect(find.text('Pontos-chave'), findsNothing);
      expect(find.text('Conduta imediata'), findsNothing);

      for (final item in <String>[
        'Há histórico de diabetes? Qual a última glicemia conhecida?',
        'Está utilizando insulina ou antidiabéticos orais regularmente? Qual a dose?',
        'Notou sinais de infecção, como febre, dor ou sintomas respiratórios?',
        'Quando foi a última refeição e o que foi consumido?',
        'Tem sentido polidipsia, poliúria ou perda de peso recente?',
        'Está tomando outros medicamentos que possam influenciar a glicemia?',
        'Já teve episódios semelhantes? Como foram tratados?',
      ]) {
        expect(
          find.textContaining(
            item,
            findRichText: true,
          ),
          findsOneWidget,
        );
      }

      expect(
        find.textContaining(
          'Esses questionamentos ajudam a identificar a causa e a direcionar o manejo adequado',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Conduta genérica do DTO'), findsNothing);
      expect(find.textContaining('Ponto genérico do DTO'), findsNothing);
      expect(find.textContaining('Hard stop genérico do DTO'), findsNothing);
    },
  );

  testWidgets(
    'Preguntas para orientación usa o mesmo owner semântico',
    (tester) async {
      const raw = """
🟥 HIPERGLUCEMIA AGUDA — PREGUNTAS CLAVE
🚨 Preguntas para orientación:
* ¿Tiene antecedente de diabetes?
* ¿Usa insulina regularmente?
""";

      await tester.pumpWidget(
        subject(
          rawText: raw,
          languageCode: 'es',
        ),
      );

      expect(find.text('Preguntas clave'), findsOneWidget);
      expect(
        find.textContaining(
          '¿Tiene antecedente de diabetes?',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '¿Usa insulina regularmente?',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '📌 Próximo continua descartado e não vira nota visível',
    (tester) async {
      const raw = """
🟥 HIPERGLICEMIA AGUDA
🔑 Pontos-chave:
* Monitorar potássio
📌 Próximo: - Reavaliar resposta e sinais de alarme
""";

      await tester.pumpWidget(
        subject(
          rawText: raw,
        ),
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
          'Reavaliar resposta',
          findRichText: true,
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'headings espanhóis usam as mesmas seções flat',
    (tester) async {
      const raw = """
🟥 HIPERGLUCEMIA AGUDA
Exámenes complementarios:
* Glucemia capilar seriada
Monitorización de la evolución:
* Controlar potasio
Preguntas clave:
* ¿Cuándo comenzó?
""";

      await tester.pumpWidget(
        subject(
          rawText: raw,
          languageCode: 'es',
        ),
      );

      expect(find.text('Exámenes complementarios'), findsOneWidget);
      expect(
        find.text('Monitorización y reevaluación'),
        findsOneWidget,
      );
      expect(find.text('Preguntas clave'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(AnimatedContainer), findsNothing);
    },
  );
}
