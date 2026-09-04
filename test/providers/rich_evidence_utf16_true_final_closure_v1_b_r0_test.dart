import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_compliance_guard.dart';

void main() {
  group('Rich evidence + true UTF16 final closure V1-B-R0', () {
    test('75 kg adult maintenance 30-35 physical output is fail-closed', () {
      const raw = '''
🟥 FLUIDO DE MANUTENÇÃO — CÁLCULO EM ADULTO

🚨 Conduta imediata:
• Calcular o volume de fluidos utilizando a fórmula padrão.
• Considerar 30-35 mL/kg/dia para adultos.
• 75 kg × 30-35 mL/kg/dia = 2250 a 2625 mL/dia.
''';

      final result =
          ClinicalCrosscuttingEvidenceComplianceGuard.enforceByEvidenceId(
            query:
                'Paciente adulto de 75 kg, sem comorbidades. Quanto de fluido de manutenção devo passar por dia?',
            assistantOutput: raw,
            lang: 'pt',
            evidenceId: 'adult_iv_fluid_therapy',
          );

      expect(result.modified, isTrue);
      expect(result.violations, contains('per_kg_day_range_mismatch'));
      expect(result.text, contains('25–30 mL/kg/dia'));
      expect(result.text, contains('1875–2250 mL/dia'));
      expect(result.text, contains('78–94 mL/h'));
      expect(result.text, isNot(contains('30-35 mL/kg/dia')));
      expect(result.text, isNot(contains('2625 mL/dia')));
    });

    test(
      'classification follow-up is sovereign without phrase enumeration',
      () {
        const raw = '''
🟥 CLASSIFICAÇÃO DO PACIENTE

🔑 Pontos-chave:
• Classificação do paciente: Hidratação normal — paciente sem comorbidades e adequado para fluido de manutenção.

📌 Classificação final: Hidratação normal, sem necessidade de intervenções específicas.
''';

        final result =
            ClinicalCrosscuttingEvidenceComplianceGuard.enforceByEvidenceId(
              query: 'E qual a classificação?',
              assistantOutput: raw,
              lang: 'pt',
              evidenceId: 'adult_iv_fluid_therapy',
            );

        expect(result.modified, isTrue);
        expect(
          result.violations,
          contains('classification_authoritative_replacement'),
        );
        expect(
          result.text,
          contains('Categoria terapêutica: manutenção IV rotineira'),
        );
        expect(
          result.text,
          contains('Estado volêmico: dados insuficientes para classificar'),
        );
        expect(result.text.toLowerCase(), isNot(contains('hidratação normal')));
      },
    );

    test(
      'canonical replacement is idempotent on repeated compliance passes',
      () {
        final first =
            ClinicalCrosscuttingEvidenceComplianceGuard.enforceByEvidenceId(
              query: 'E qual a classificação?',
              assistantOutput: 'Hidratação normal.',
              lang: 'pt',
              evidenceId: 'adult_iv_fluid_therapy',
            );

        final second =
            ClinicalCrosscuttingEvidenceComplianceGuard.enforceByEvidenceId(
              query: 'E qual a classificação?',
              assistantOutput: first.text,
              lang: 'pt',
              evidenceId: 'adult_iv_fluid_therapy',
            );

        expect(first.modified, isTrue);
        expect(second.modified, isFalse);
        expect(second.text, first.text);
      },
    );

    testWidgets('renderer repairs malformed UTF16 at its own final boundary', (
      tester,
    ) async {
      final malformed = String.fromCharCodes(<int>[0xD83D]);
      final raw =
          '''
🟥 TESTE UTF16

🚨 Conduta imediata:
• Texto clínico válido antes $malformed depois.
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuardiaClinicalResponseView(
                rawText: raw,
                userText: 'teste',
                userInitiatedByAction: false,
                dark: true,
                languageCode: 'pt',
                typedTreatmentVisualEnabled: false,
                onCopy: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        expect(_hasUnpairedSurrogate(rich.text.toPlainText()), isFalse);
      }
    });

    testWidgets('streaming notifier path also repairs malformed UTF16', (
      tester,
    ) async {
      final malformed = String.fromCharCodes(<int>[0xD83D]);
      final notifier = ValueNotifier<String>(
        '🟥 STREAM\\n🚨 Conduta imediata:\\n• início',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardiaClinicalResponseView(
              rawText: '',
              userText: 'teste',
              userInitiatedByAction: false,
              dark: false,
              languageCode: 'pt',
              isStreaming: true,
              streamingTextNotifier: notifier,
              typedTreatmentVisualEnabled: false,
              onCopy: () {},
            ),
          ),
        ),
      );

      notifier.value =
          '🟥 STREAM\\n🚨 Conduta imediata:\\n• início $malformed fim';
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      notifier.dispose();
    });
  });
}

bool _hasUnpairedSurrogate(String value) {
  final units = value.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 >= units.length) return true;
      final next = units[++i];
      if (next < 0xDC00 || next > 0xDFFF) return true;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return true;
    }
  }
  return false;
}
