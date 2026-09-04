import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  const partial = '🟥 GLICEMIA ALTA — MANEJO DIABETES';

  const complete = """
🟥 GLICEMIA ALTA — MANEJO DIABETES
Conducta inmediata:
• Evaluar cetonuria y estado de hidratación
• Controlar glucemia capilar
Tratamiento farmacológico:
• Insulina regular según protocolo institucional
""";

  final diagnosisOnly = ClinicalStructuredOutput(
    diagnosticoHeuristico: 'Glicemia alta — manejo diabetes',
    condutaImediata: '',
    prescricao: const <ClinicalPrescriptionItem>[],
  );

  Widget subject({
    required String rawText,
    required bool isStreaming,
    required ValueNotifier<String> notifier,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: GuardiaClinicalResponseView(
          key: const ValueKey('guardia_handoff_subject'),
          rawText: rawText,
          output: diagnosisOnly,
          dark: true,
          languageCode: 'pt',
          onCopy: () {},
          isStreaming: isStreaming,
          streamingTextNotifier: notifier,
        ),
      ),
    );
  }

  group(
    'H5C1-G1-V12-M10 — raw final canônico',
    () {
      testWidgets(
        'final substitui snapshot parcial sem trocar o Element',
        (tester) async {
          final notifier = ValueNotifier<String>(partial);
          late StateSetter updateHost;
          var rawText = partial;
          var isStreaming = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: StatefulBuilder(
                builder: (context, setState) {
                  updateHost = setState;

                  return Scaffold(
                    body: GuardiaClinicalResponseView(
                      key: const ValueKey(
                        'guardia_handoff_subject',
                      ),
                      rawText: rawText,
                      output: diagnosisOnly,
                      dark: true,
                      languageCode: 'pt',
                      onCopy: () {},
                      isStreaming: isStreaming,
                      streamingTextNotifier: notifier,
                    ),
                  );
                },
              ),
            ),
          );

          final rootFinder = find.byKey(
            const ValueKey('guardia_clinical_response'),
          );
          final before = tester.element(rootFinder);

          expect(
            find.textContaining(
              'Evaluar cetonuria',
              findRichText: true,
            ),
            findsNothing,
          );
          expect(
            find.byKey(
              const ValueKey('guardia_streaming_cursor'),
            ),
            findsOneWidget,
          );

          updateHost(() {
            rawText = complete;
            isStreaming = false;
          });
          await tester.pump();

          final after = tester.element(rootFinder);

          expect(identical(before, after), isTrue);
          expect(
            find.textContaining(
              'Evaluar cetonuria',
              findRichText: true,
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              'Controlar glucemia capilar',
              findRichText: true,
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              'Insulina regular',
              findRichText: true,
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const ValueKey('guardia_streaming_cursor'),
            ),
            findsNothing,
          );

          notifier.dispose();
        },
      );

      testWidgets(
        'build final ignora notifier parcial já preenchido',
        (tester) async {
          final notifier = ValueNotifier<String>(partial);

          await tester.pumpWidget(
            subject(
              rawText: complete,
              isStreaming: false,
              notifier: notifier,
            ),
          );

          expect(
            find.textContaining(
              'Evaluar cetonuria',
              findRichText: true,
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              'Insulina regular',
              findRichText: true,
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const ValueKey('guardia_copy_action'),
            ),
            findsOneWidget,
          );

          notifier.dispose();
        },
      );

      testWidgets(
        'streaming continua obedecendo ao notifier',
        (tester) async {
          final notifier = ValueNotifier<String>(partial);

          await tester.pumpWidget(
            subject(
              rawText: complete,
              isStreaming: true,
              notifier: notifier,
            ),
          );

          expect(
            find.textContaining(
              'Evaluar cetonuria',
              findRichText: true,
            ),
            findsNothing,
          );

          notifier.value = """
$partial
Conducta inmediata:
• Evaluar cetonuria y estado de hidratación
""";
          await tester.pump();

          expect(
            find.textContaining(
              'Evaluar cetonuria',
              findRichText: true,
            ),
            findsOneWidget,
          );

          notifier.dispose();
        },
      );
    },
  );
}
