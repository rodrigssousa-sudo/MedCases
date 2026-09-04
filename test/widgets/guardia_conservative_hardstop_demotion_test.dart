import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  group('PHASE3I-J2F11C8-R1 conservative HARD STOP demotion', () {
    testWidgets(
      'demotes only explicit general recommendations',
      (tester) async {
        const rawText = 'Pneumonia adquirida na comunidade\n\n'
            'HARD STOP:\n'
            '• Alergia a betalactâmicos\n'
            '• Reavaliar a terapia antibiótica após 48–72 horas\n'
            '• Incluir medidas de suporte, como hidratação e analgesia\n'
            '• Educar o paciente sobre adesão ao tratamento\n';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GuardiaClinicalResponseView(
                rawText: rawText,
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
                widget.text.toPlainText().contains('Alergia a betalactâmicos'),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(
                      'Reavaliar a terapia antibiótica após 48–72 horas',
                    ),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(
                      'Incluir medidas de suporte, como hidratação e analgesia',
                    ),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(
                      'Educar o paciente sobre adesão ao tratamento',
                    ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('guardia_hard_stop_section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('guardia_key_points_section')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'demotes bracketed pure clinical action from HARD STOP',
      (tester) async {
        Future<void> verifyCase({
          required String action,
          required String languageCode,
        }) async {
          final rawText = 'Pneumonia adquirida na comunidade\n\n'
              'HARD STOP:\n'
              '• Alergia a penicilinas\n'
              '• $action\n';

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GuardiaClinicalResponseView(
                  rawText: rawText,
                  dark: true,
                  languageCode: languageCode,
                  typedTreatmentVisualEnabled: false,
                  onCopy: () {},
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byKey(const ValueKey('guardia_hard_stop_section')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('guardia_key_points_section')),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText().contains(action),
            ),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText().contains('Alergia a penicilinas'),
            ),
            findsOneWidget,
          );
        }

        await verifyCase(
          action:
              '[acción clínica pura — iniciar tratamiento antibiótico empírico]',
          languageCode: 'es',
        );
        await verifyCase(
          action: '[ação clínica pura — iniciar tratamento antibiótico empírico]',
          languageCode: 'pt',
        );
      },
    );

    testWidgets(
      'demotes unbracketed immediate antibiotic action '
      'and keeps negative blocker',
      (tester) async {
        Future<void> verifyDemotion({
          required String action,
          required String blocker,
          required String languageCode,
        }) async {
          final rawText = 'Pneumonia adquirida na comunidade\n\n'
              'HARD STOP:\n'
              '• $blocker\n'
              '• $action\n';

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GuardiaClinicalResponseView(
                  rawText: rawText,
                  dark: true,
                  languageCode: languageCode,
                  typedTreatmentVisualEnabled: false,
                  onCopy: () {},
                ),
              ),
            ),
          );
          await tester.pump();

          final actionFinder = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(action),
          );
          final blockerFinder = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(blocker),
          );
          final hardStopTitle =
              find.byKey(const ValueKey('guardia_hard_stop_section'));

          expect(
            find.byKey(const ValueKey('guardia_key_points_section')),
            findsOneWidget,
          );
          expect(hardStopTitle, findsOneWidget);
          expect(actionFinder, findsOneWidget);
          expect(blockerFinder, findsOneWidget);
          expect(
            tester.getTopLeft(actionFinder).dy,
            lessThan(tester.getTopLeft(hardStopTitle).dy),
          );
          expect(
            tester.getTopLeft(blockerFinder).dy,
            greaterThan(tester.getTopLeft(hardStopTitle).dy),
          );
        }

        await verifyDemotion(
          action:
              'Iniciar tratamiento antibiótico de inmediato según guías clínicas',
          blocker:
              'No utilizar antibióticos si hay antecedentes de reacción '
              'alérgica severa a penicilinas',
          languageCode: 'es',
        );
        await verifyDemotion(
          action:
              'Iniciar tratamento antibiótico de imediato conforme diretrizes clínicas',
          blocker: 'Não utilizar penicilinas em caso de alergia grave',
          languageCode: 'pt',
        );

        const negativeBlocker =
            'No iniciar tratamiento antibiótico si existe anafilaxia '
            'sin alternativa segura';
        const blockerOnlyRaw = 'Pneumonia adquirida en la comunidad\n\n'
            'HARD STOP:\n'
            '• $negativeBlocker\n';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GuardiaClinicalResponseView(
                rawText: blockerOnlyRaw,
                dark: true,
                languageCode: 'es',
                typedTreatmentVisualEnabled: false,
                onCopy: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('guardia_hard_stop_section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('guardia_key_points_section')),
          findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(negativeBlocker),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'splits inline pinned immediate antibiotic action from HARD STOP',
      (tester) async {
        Future<void> verifyInlineSplit({
          required String blocker,
          required String action,
          required String languageCode,
        }) async {
          final rawText = 'Pneumonia adquirida na comunidade\n\n'
              'HARD STOP:\n'
              '• $blocker   📌 $action\n';

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GuardiaClinicalResponseView(
                  rawText: rawText,
                  dark: true,
                  languageCode: languageCode,
                  typedTreatmentVisualEnabled: false,
                  onCopy: () {},
                ),
              ),
            ),
          );
          await tester.pump();

          final actionFinder = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(action),
          );
          final blockerFinder = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(blocker),
          );
          final hardStopTitle =
              find.byKey(const ValueKey('guardia_hard_stop_section'));

          expect(
            find.byKey(const ValueKey('guardia_key_points_section')),
            findsOneWidget,
          );
          expect(hardStopTitle, findsOneWidget);
          expect(actionFinder, findsOneWidget);
          expect(blockerFinder, findsOneWidget);
          expect(
            tester.getTopLeft(actionFinder).dy,
            lessThan(tester.getTopLeft(hardStopTitle).dy),
          );
          expect(
            tester.getTopLeft(blockerFinder).dy,
            greaterThan(tester.getTopLeft(hardStopTitle).dy),
          );
        }

        await verifyInlineSplit(
          blocker: 'Alergia grave a penicilinas ou cefalosporinas',
          action: 'iniciar antibiótico imediatamente',
          languageCode: 'pt',
        );
        await verifyInlineSplit(
          blocker: 'Alergia grave a penicilinas o cefalosporinas',
          action: 'iniciar antibiótico inmediatamente',
          languageCode: 'es',
        );

        const negativeAction =
            'não iniciar antibiótico se houver anafilaxia sem alternativa segura';
        const negativeRaw = 'Pneumonia adquirida na comunidade\n\n'
            'HARD STOP:\n'
            '• Alergia grave a penicilinas   📌 $negativeAction\n';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GuardiaClinicalResponseView(
                rawText: negativeRaw,
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
          find.byKey(const ValueKey('guardia_hard_stop_section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('guardia_key_points_section')),
          findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(negativeAction),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'demotes plural rapid antibiotic action from HARD STOP',
      (tester) async {
        Future<void> verifyDemotion({
          required String blocker,
          required String action,
          required String languageCode,
        }) async {
          final rawText = 'Pneumonia adquirida na comunidade\n\n'
              'HARD STOP:\n'
              '• $blocker\n'
              '• $action\n';

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GuardiaClinicalResponseView(
                  rawText: rawText,
                  dark: true,
                  languageCode: languageCode,
                  typedTreatmentVisualEnabled: false,
                  onCopy: () {},
                ),
              ),
            ),
          );
          await tester.pump();

          final actionFinder = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(action),
          );

          final blockerFinder = find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(blocker),
          );

          final hardStopTitle = find.byKey(
            const ValueKey(
              'guardia_hard_stop_section',
            ),
          );

          expect(
            find.byKey(
              const ValueKey(
                'guardia_key_points_section',
              ),
            ),
            findsOneWidget,
          );

          expect(
            hardStopTitle,
            findsOneWidget,
          );

          expect(
            actionFinder,
            findsOneWidget,
          );

          expect(
            blockerFinder,
            findsOneWidget,
          );

          expect(
            tester.getTopLeft(actionFinder).dy,
            lessThan(
              tester.getTopLeft(hardStopTitle).dy,
            ),
          );

          expect(
            tester.getTopLeft(blockerFinder).dy,
            greaterThan(
              tester.getTopLeft(hardStopTitle).dy,
            ),
          );
        }

        await verifyDemotion(
          blocker:
              'Alergia a betalactâmicos – evite uso de Ceftriaxona e Pip-Tazo',
          action:
              'Iniciar antibióticos rapidamente para melhorar prognóstico',
          languageCode: 'pt',
        );

        await verifyDemotion(
          blocker:
              'Alergia a betalactámicos – evite Ceftriaxona y Pip-Tazo',
          action:
              'Iniciar antibióticos rápidamente para mejorar el pronóstico',
          languageCode: 'es',
        );

        const negativeAction =
            'Não iniciar antibióticos rapidamente '
            'se houver anafilaxia sem alternativa segura';

        const negativeRaw =
            'Pneumonia adquirida na comunidade\n\n'
            'HARD STOP:\n'
            '• $negativeAction\n';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GuardiaClinicalResponseView(
                rawText: negativeRaw,
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
          find.byKey(
            const ValueKey(
              'guardia_hard_stop_section',
            ),
          ),
          findsOneWidget,
        );

        expect(
          find.byKey(
            const ValueKey(
              'guardia_key_points_section',
            ),
          ),
          findsNothing,
        );

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text
                    .toPlainText()
                    .contains(negativeAction),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keeps exact HARD STOP note duplicate suppressed',
      (tester) async {
        const duplicate =
            'Iniciar tratamento antibiótico emergencial — sem atrasos';
        const rawText = 'Pneumonia adquirida na comunidade\n\n'
            'HARD STOP:\n'
            '• Iniciar tratamento antibiótico emergencial — sem atrasos\n\n'
            '📌 Iniciar tratamento antibiótico emergencial — sem atrasos\n';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GuardiaClinicalResponseView(
                rawText: rawText,
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
                widget.text.toPlainText().contains(duplicate),
          ),
          findsOneWidget,
        );
        expect(find.text('📌 $duplicate'), findsNothing);
      },
    );
  });
}
