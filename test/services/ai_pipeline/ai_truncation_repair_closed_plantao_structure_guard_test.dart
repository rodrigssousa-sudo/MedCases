import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';

class FixedInspector implements AiTruncationInspectorPort {
  final TruncationCheckResult result;

  const FixedInspector(this.result);

  @override
  TruncationCheckResult inspect(String text) => result;
}

class CountingRepairPort implements AiTruncationRepairPort {
  int calls = 0;

  @override
  Future<TruncationRepairResult> repair({
    required String originalText,
    required String requestId,
    required bool isPlantaoMode,
    required String appLanguage,
  }) async {
    calls++;
    return TruncationRepairResult.repaired('$originalText\nREPAIRED');
  }
}

void main() {
  group('PHASE3I-J2F10C-M closed Plantao structure repair guard', () {
    const abrupt = TruncationCheckResult(
      isTruncated: true,
      confidenceLevel: TruncationConfidence.medium,
      violationReason: 'abrupt_non_punctuation_termination',
    );

    test('closed explicit Plantao block does not call repair', () async {
      const text = """
🟥 TRATAMENTO INICIAL COMBINADO

💊 Tratamento farmacológico:
• AAS 300 mg VO
• Clopidogrel 300 mg VO

⚠️ Alerta clínico:
• Monitorar pressão arterial e sinais de sangramento

⛔ HARD STOP:
• Não administrar em caso de sangramento ativo grave
""";

      final repair = CountingRepairPort();
      final coordinator = AiTruncationRepairCoordinator(
        inspector: const FixedInspector(abrupt),
        repairPort: repair,
      );

      final outcome = await coordinator.process(
        originalText: text,
        requestId: 'closed-literal',
        mode: AiRequestMode.plantao,
        locale: AiRequestLocale.pt,
      );

      expect(repair.calls, 0);
      expect(outcome.text, text);
      expect(outcome.repairAttempted, isFalse);
      expect(outcome.repairStatus, AiRepairStatus.notAttempted);
      expect(outcome.isValid, isTrue);
    });

    test('incomplete HARD STOP still repairs', () async {
      const text = """
🟥 TRATAMENTO INICIAL COMBINADO
💊 Tratamento farmacológico:
• AAS 300 mg VO
⚠️ Alerta clínico:
• Monitorar
⛔ HARD STOP:
""";

      final repair = CountingRepairPort();
      final coordinator = AiTruncationRepairCoordinator(
        inspector: const FixedInspector(abrupt),
        repairPort: repair,
      );

      final outcome = await coordinator.process(
        originalText: text,
        requestId: 'incomplete-hard-stop',
        mode: AiRequestMode.plantao,
        locale: AiRequestLocale.pt,
      );

      expect(repair.calls, 1);
      expect(outcome.wasRepaired, isTrue);
    });

    test('MAX_TOKENS bypasses guard and repairs', () async {
      const text = """
🟥 TRATAMENTO INICIAL COMBINADO
💊 Tratamento farmacológico:
• AAS 300 mg VO
⚠️ Alerta clínico:
• Monitorar
⛔ HARD STOP:
• Sangramento ativo grave
""";

      final repair = CountingRepairPort();
      final coordinator = AiTruncationRepairCoordinator(
        inspector: const FixedInspector(abrupt),
        repairPort: repair,
      );

      final outcome = await coordinator.process(
        originalText: text,
        requestId: 'max-tokens',
        mode: AiRequestMode.plantao,
        locale: AiRequestLocale.pt,
        providerFinishReason: 'MAX_TOKENS',
      );

      expect(repair.calls, 1);
      expect(outcome.wasRepaired, isTrue);
    });

    test('Estudo mode is unchanged', () async {
      const text = """
🟥 TRATAMENTO INICIAL COMBINADO
💊 Tratamento farmacológico:
• AAS 300 mg VO
⚠️ Alerta clínico:
• Monitorar
⛔ HARD STOP:
• Sangramento ativo grave
""";

      final repair = CountingRepairPort();
      final coordinator = AiTruncationRepairCoordinator(
        inspector: const FixedInspector(abrupt),
        repairPort: repair,
      );

      final outcome = await coordinator.process(
        originalText: text,
        requestId: 'estudo-unchanged',
        mode: AiRequestMode.estudo,
        locale: AiRequestLocale.pt,
      );

      expect(repair.calls, 0);
      expect(outcome.repairAttempted, isFalse);
      expect(outcome.repairStatus, AiRepairStatus.notAttempted);
    });
  });
}
