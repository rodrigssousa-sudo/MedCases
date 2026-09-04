import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('Plantao full management + pharma + no emoji V1-B-R5', () {
    test(
      'Spanish management contract is active in actual Plantao early-return',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'es',
          matchedProtocolSummaries: const <String>[
            'PROTOCOLO_CLINICO_ATIVO: síndrome coronario agudo',
          ],
          matchedDrugSummaries: const <String>[],
          userQuery:
              'Analiza el caso e indica la conducta inicial y el tratamiento completo.',
          isFirstMessage: false,
          isPlantaoMode: true,
        );

        expect(prompt, contains('[PLANTAO_FULL_MANAGEMENT_PHARMA_ACTIVE_V2]'));
        expect(prompt, contains('NO aplicar el limite de 900 caracteres'));
        expect(
          prompt,
          contains('TODOS los componentes farmacologicos de primera linea'),
        );
        expect(
          prompt,
          contains(
            'nombre, dosis, via y carga/frecuencia/intervalo cuando corresponda',
          ),
        );
      },
    );

    test(
      'Portuguese management contract is active in actual Plantao early-return',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'pt',
          matchedProtocolSummaries: const <String>[
            'PROTOCOLO_CLINICO_ATIVO: síndrome coronariana aguda',
          ],
          matchedDrugSummaries: const <String>[],
          userQuery:
              'Analise o caso e indique a conduta inicial e o tratamento completo.',
          isFirstMessage: false,
          isPlantaoMode: true,
        );

        expect(prompt, contains('[PLANTAO_FULL_MANAGEMENT_PHARMA_ACTIVE_V2]'));
        expect(prompt, contains('NAO aplicar o limite de 900 caracteres'));
        expect(
          prompt,
          contains('TODOS os componentes farmacologicos de primeira linha'),
        );
      },
    );

    test(
      'classification-only keeps classification contract without management expansion',
      () {
        final prompt = AiService.buildClinicalSystemPrompt(
          lang: 'es',
          matchedProtocolSummaries: const <String>[
            'CLASSIFICACAO_VERIFICADA: Killip I',
          ],
          matchedDrugSummaries: const <String>[],
          userQuery: '¿Y cuál es la clasificación?',
          isFirstMessage: false,
          isPlantaoMode: true,
        );

        expect(prompt, contains('[PLANTAO_CLASSIFICATION_ACTIVE_CONTRACT_V2]'));
        expect(
          prompt,
          isNot(contains('[PLANTAO_FULL_MANAGEMENT_PHARMA_ACTIVE_V2]')),
        );
      },
    );

    test('combined classification plus treatment activates both contracts', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[
          'CLASSIFICACAO_VERIFICADA: Killip I',
        ],
        matchedDrugSummaries: const <String>[],
        userQuery: 'Clasifica al paciente e indica el tratamiento completo.',
        isFirstMessage: false,
        isPlantaoMode: true,
      );

      expect(prompt, contains('[PLANTAO_CLASSIFICATION_ACTIVE_CONTRACT_V2]'));
      expect(prompt, contains('[PLANTAO_FULL_MANAGEMENT_PHARMA_ACTIVE_V2]'));
    });

    test('Study does not receive Plantao management mandate', () {
      final prompt = AiService.buildClinicalSystemPrompt(
        lang: 'es',
        matchedProtocolSummaries: const <String>[],
        matchedDrugSummaries: const <String>[],
        userQuery: 'Explícame el tratamiento del IAM.',
        isFirstMessage: true,
        isPlantaoMode: false,
      );

      expect(
        prompt,
        isNot(contains('[PLANTAO_FULL_MANAGEMENT_PHARMA_ACTIVE_V2]')),
      );
    });

    test('AiScreen keeps Plantao on the dedicated Guardia surface', () {
      final screen = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(
        screen,
        contains(
          'final bool useGuardiaPresentation = !_longResponse && !isSafeCard;',
        ),
      );
      expect(screen, contains('if (useGuardiaPresentation)'));
      expect(screen, contains('GuardiaClinicalResponseView('));
      expect(screen, contains('output: msg.clinicalOutput,'));
    });

    testWidgets(
      'legacy differential raw keeps Evaluación inicial and RED FLAGS parsing',
      (tester) async {
        const differentialRaw = '''
🟥 DOLOR TORÁCICO — DIFERENCIALES PRIORITARIOS
🚨 Evaluación inicial:
* ECG y signos vitales según contexto
🚩 RED FLAGS:
* Inestabilidad hemodinámica o deterioro clínico
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GuardiaClinicalResponseView(
                  rawText: differentialRaw,
                  userText: 'Paciente con dolor torácico.',
                  output: null,
                  dark: false,
                  languageCode: 'es',
                  onCopy: () {},
                  isStreaming: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Evaluación inicial'), findsOneWidget);
        expect(find.text('Red flags/escalamiento'), findsOneWidget);
        expect(find.text('HARD STOP:'), findsNothing);

        for (final glyph in <String>['🟥', '🚨', '🚩', '🔴']) {
          expect(
            find.textContaining(glyph, findRichText: true),
            findsNothing,
            reason: 'emoji textual visível no formato diferencial: $glyph',
          );
        }
      },
    );

    testWidgets(
      'final Plantao renders pharmacologic treatment without textual emoji',
      (tester) async {
        const raw = '''
🟥 IAMCEST — CONDUCTA INMEDIATA
🚨 Conducta inmediata:
* Monitorización continua y acceso venoso.
💊 Tratamiento farmacológico:
* **AAS 300 mg VO** — carga masticable si no hay contraindicación.
* **Ticagrelor 180 mg VO** — carga si la estrategia clínica lo indica.
🔑 Puntos clave:
* Definir estrategia de reperfusión.
🚩 RED FLAGS:
* Choque cardiogénico o deterioro hemodinámico.
📌 Siguiente paso: activar estrategia de reperfusión.
''';

        final output = ClinicalStructuredOutput(
          diagnosticoHeuristico: 'IAMCEST',
          condutaImediata: 'Monitorización continua y acceso venoso.',
          prescricao: const <ClinicalPrescriptionItem>[
            ClinicalPrescriptionItem(farmaco: 'AAS', posologia: '300 mg VO'),
            ClinicalPrescriptionItem(
              farmaco: 'Ticagrelor',
              posologia: '180 mg VO',
            ),
          ],
          pontosChave: const <String>['Definir estrategia de reperfusión.'],
          hardStops: const <String>[
            'Choque cardiogénico o deterioro hemodinámico.',
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GuardiaClinicalResponseView(
                  rawText: raw,
                  userText:
                      'Paciente con IAMCEST confirmado y elevación persistente del ST.',
                  output: output,
                  dark: false,
                  languageCode: 'es',
                  onCopy: () {},
                  isStreaming: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.textContaining('Tratamiento farmacológico', findRichText: true),
          findsWidgets,
        );
        expect(find.textContaining('AAS', findRichText: true), findsWidgets);
        expect(
          find.textContaining('300 mg VO', findRichText: true),
          findsWidgets,
        );
        expect(
          find.textContaining('Ticagrelor', findRichText: true),
          findsWidgets,
        );
        expect(
          find.textContaining('180 mg VO', findRichText: true),
          findsWidgets,
        );

        for (final glyph in <String>[
          '🟥',
          '🚨',
          '💊',
          '🔑',
          '🚩',
          '📌',
          '⛔',
          '🔴',
          '⚠',
          '🚫',
          '🛑',
        ]) {
          expect(
            find.textContaining(glyph, findRichText: true),
            findsNothing,
            reason: 'emoji textual visível: $glyph',
          );
        }
      },
    );
  });
}
