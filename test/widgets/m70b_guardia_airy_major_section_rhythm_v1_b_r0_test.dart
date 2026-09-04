import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  testWidgets(
    'M70B keeps title divider and clean flat sections after airy spacing change',
    (tester) async {
      const raw = '''
Síndrome clínico
Conducta inmediata:
- Acción inmediata.
Tratamiento farmacológico:
- MedicamentoAlfa IV 10 mg; según respuesta.
Monitorización y reevaluación:
- Reevaluar.
Puntos clave:
- Punto útil.
Red flags/escalamiento:
- Escalar si empeora.
Limitaciones / datos faltantes:
- Dato relevante ausente.
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardiaClinicalResponseView(
                rawText: raw,
                userText: '',
                userInitiatedByAction: false,
                dark: true,
                languageCode: 'es',
                typedTreatmentVisualEnabled: false,
                onCopy: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('guardia_divider_before_immediate')),
        findsOneWidget,
      );
      expect(find.text('Conducta inmediata'), findsOneWidget);
      expect(find.text('Tratamiento farmacológico'), findsOneWidget);
      expect(find.text('Monitorización y reevaluación'), findsOneWidget);
      expect(find.text('Puntos clave'), findsOneWidget);
      expect(find.text('Red flags/escalamiento'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('guardia_limitations_section')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('M70B source owns 20px major gaps without restoring section lines', () {
    final source = File(
      'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
    ).readAsStringSync();

    final gap20 = RegExp(
      r"if\s*\(\s*content\.hasContentBefore[A-Za-z]+\s*\)\s*"
      r"const\s+SizedBox\(height:\s*20\)",
      multiLine: true,
    ).allMatches(source).length;
    final stale12 = RegExp(
      r"if\s*\(\s*content\.hasContentBefore[A-Za-z]+\s*\)\s*"
      r"const\s+SizedBox\(height:\s*12\)",
      multiLine: true,
    ).allMatches(source).length;
    final dividerCalls = RegExp(
      r"_GuardiaSectionDivider\(\s*"
      r"key:\s*const\s*ValueKey\('guardia_divider_before_[^']+'\),",
      multiLine: true,
    ).allMatches(source).length;

    expect(gap20, greaterThanOrEqualTo(7));
    expect(stale12, 0);
    expect(dividerCalls, 1);
    expect(source, contains('guardia_divider_before_immediate'));
    expect(source, contains('M70B_AIRY_MAJOR_SECTION_RHYTHM_V1'));
    expect(source, contains('TableBorder('));
    expect(source, contains('horizontalInside:'));
    expect(source, contains('verticalInside:'));
    expect(source, contains('guardia_destination_table_vertical'));
    expect(source, contains('M67_MEDICATION_CORE_FULL_BOLD_V1'));
    expect(source, contains('M68_PHARMA_NATURAL_SEPARATOR_V1'));
  });
}
