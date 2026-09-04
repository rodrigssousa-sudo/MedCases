import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/plantao_continuation_button.dart';

void main() {
  testWidgets('Plantão continuation is delicate, arrow-only and debounced', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlantaoContinuationButton(
            label: 'Definir destino',
            accentColor: const Color(0xFF0E8000),
            dark: true,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Definir destino'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);

    await tester.tap(find.text('Definir destino'));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.text('Definir destino'));
    await tester.pump();
    expect(taps, 1);

    await tester.pump(const Duration(milliseconds: 650));
  });

  test(
    'source keeps Study-like geometry and has no clinical/network owner',
    () {
      final source = File(
        'lib/screens/ai/widgets/plantao_continuation_button.dart',
      ).readAsStringSync();
      final normalized = source.replaceAll(RegExp(r'\s+'), ' ');

      for (final token in <String>[
        'EdgeInsets.fromLTRB(12, 8, 12, 0)',
        'BoxConstraints(minHeight: 44)',
        'BorderRadius.circular(12)',
        'horizontal: 14',
        'vertical: 8',
        'fontSize: 13.0',
        'height: 1.25',
        'Icons.arrow_forward_rounded',
        'size: 18',
        'Duration(milliseconds: 600)',
      ]) {
        expect(normalized, contains(token), reason: token);
      }

      for (final forbidden in <String>[
        'FirebaseFirestore',
        'sendAiMessage(',
        'PlantaoGlobalClinicalResponseGate',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    },
  );

  test('ActionButtonsRow keeps old seams and adds isolated Plantão branch', () {
    final row = File(
      'lib/screens/ai/widgets/action_buttons_row.dart',
    ).readAsStringSync();

    for (final token in <String>[
      'PlantaoContinuationPolicy.resolve(',
      'PlantaoContinuationButton(',
      'effectivePlantaoAction.promptToSend',
      'effectivePlantaoAction.continuationType',
      'effectivePlantaoAction.requestedSections',
      'hasStudyNext || action.label.isNotEmpty',
      'hasStudyNext ? effectiveStudyPrompt : action.promptToSend',
      ': action.continuationType',
      ': action.requestedSections',
      'visibleLabel: aiLabel',
      'final calcBtn = link != null',
    ]) {
      expect(row, contains(token), reason: token);
    }
  });
}
