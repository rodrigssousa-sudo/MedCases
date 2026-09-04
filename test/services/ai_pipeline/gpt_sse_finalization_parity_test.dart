import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/services/ai/ai_finalization_transaction.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';
import 'package:medcases/services/ai_smart_router.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';

class FixedInspector implements AiTruncationInspectorPort {
  final TruncationCheckResult result;

  int calls = 0;

  FixedInspector(this.result);

  @override
  TruncationCheckResult inspect(String text) {
    calls++;
    return result;
  }
}

class FixedRepairPort implements AiTruncationRepairPort {
  final TruncationRepairResult result;

  int calls = 0;

  FixedRepairPort(this.result);

  @override
  Future<TruncationRepairResult> repair({
    required String originalText,
    required String requestId,
    required bool isPlantaoMode,
    required String appLanguage,
  }) async {
    calls++;
    return result;
  }
}

class LegacyTransformOutcome {
  final String finalText;
  final bool failed;
  final String? failureReason;
  final int repairCalls;

  const LegacyTransformOutcome({
    required this.finalText,
    required this.failed,
    required this.failureReason,
    required this.repairCalls,
  });
}

Future<LegacyTransformOutcome> runLegacyTransform({
  required String rawText,
  required String requestId,
  required AiRequestMode mode,
  required AiRequestLocale locale,
  required FixedInspector inspector,
  required FixedRepairPort repairPort,
}) async {
  String barrierText = rawText;

  final inspection = inspector.inspect(rawText);

  final shouldRepair = inspection.isTruncated &&
      (mode == AiRequestMode.plantao ||
          inspection.confidenceLevel == TruncationConfidence.high);

  if (shouldRepair) {
    final repair = await repairPort.repair(
      originalText: rawText,
      requestId: requestId,
      isPlantaoMode: mode == AiRequestMode.plantao,
      appLanguage: locale == AiRequestLocale.es ? 'es' : 'pt',
    );

    if (!repair.isValid) {
      return LegacyTransformOutcome(
        finalText: '',
        failed: true,
        failureReason: repair.failureReason ?? 'repair_failed',
        repairCalls: repairPort.calls,
      );
    }

    barrierText = repair.text;
  }

  final sanitized = barrierText.isNotEmpty
      ? AiSmartRouter.sanitizeAndCheck(
          barrierText,
          isPlantaoMode: mode == AiRequestMode.plantao,
          appLanguage: locale == AiRequestLocale.es ? 'es' : 'pt',
        )
      : null;

  return LegacyTransformOutcome(
    finalText: sanitized?.text ?? barrierText,
    failed: false,
    failureReason: null,
    repairCalls: repairPort.calls,
  );
}

AiResponseFinalizationProcessor buildProcessor({
  required FixedInspector inspector,
  required FixedRepairPort repairPort,
}) {
  return AiResponseFinalizationProcessor(
    truncationCoordinator: AiTruncationRepairCoordinator(
      inspector: inspector,
      repairPort: repairPort,
    ),
  );
}

FinalOutputSnapshot buildSnapshot({
  required String rawText,
  required String requestId,
}) {
  return FinalOutputSnapshot(
    rawOutput: rawText,
    sessionId: 'session-parity',
    parentRequestId: requestId,
    frozenAt: DateTime.utc(2026, 7, 22),
  );
}

const cleanInspection = TruncationCheckResult(
  isTruncated: false,
  confidenceLevel: TruncationConfidence.low,
  violationReason: 'none',
);

const highTruncation = TruncationCheckResult(
  isTruncated: true,
  confidenceLevel: TruncationConfidence.high,
  violationReason: 'unclosed_markdown_bold_at_eof',
);

const mediumTruncation = TruncationCheckResult(
  isTruncated: true,
  confidenceLevel: TruncationConfidence.medium,
  violationReason: 'possible_incomplete_sentence',
);

ClinicalStructuredOutput buildClinicalOutput() {
  return ClinicalStructuredOutput(
    diagnosticoHeuristico: 'Choque séptico',
    condutaImediata: 'Iniciar ressuscitação.',
    prescricao: const [
      ClinicalPrescriptionItem(
        farmaco: 'Noradrenalina',
        posologia: '0,05 mcg/kg/min EV',
      ),
    ],
  );
}

void main() {
  group(
    'GPT SSE legacy versus canonical processor parity',
    () {
      test(
        'texto limpo em Estudo mantém paridade integral',
        () async {
          const rawText = '## Pneumonia\n'
              'Explicação clínica completa.';

          final legacy = await runLegacyTransform(
            rawText: rawText,
            requestId: 'req-clean-study',
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.pt,
            inspector: FixedInspector(
              cleanInspection,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.clean('unused'),
            ),
          );

          final processor = buildProcessor(
            inspector: FixedInspector(
              cleanInspection,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.clean('unused'),
            ),
          );

          final outcome = await processor.process(
            snapshot: buildSnapshot(
              rawText: rawText,
              requestId: 'req-clean-study',
            ),
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 2,
          );

          expect(legacy.failed, isFalse);
          expect(outcome.isReady, isTrue);

          expect(
            outcome.result?.finalText,
            legacy.finalText,
          );

          expect(
            outcome.result?.displayText,
            legacy.finalText,
          );

          expect(legacy.repairCalls, 0);

          expect(
            processor.release(
              'req-clean-study',
            ),
            isTrue,
          );
        },
      );

      test(
        'texto com âncoras em Guardia mantém paridade',
        () async {
          const rawText = '🟥 Hipoglucemia sintomática\n'
              '💊 Administrar glucosa EV\n'
              '📌 Controlar glucemia en 15 minutos';

          final legacy = await runLegacyTransform(
            rawText: rawText,
            requestId: 'req-guardia',
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.es,
            inspector: FixedInspector(
              cleanInspection,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.clean('unused'),
            ),
          );

          final processor = buildProcessor(
            inspector: FixedInspector(
              cleanInspection,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.clean('unused'),
            ),
          );

          final outcome = await processor.process(
            snapshot: buildSnapshot(
              rawText: rawText,
              requestId: 'req-guardia',
            ),
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.es,
            provider: 'gpt_sse',
            attempt: 2,
          );

          expect(outcome.isReady, isTrue);

          expect(
            outcome.result?.finalText,
            legacy.finalText,
          );

          expect(
            outcome.structure?.plantaoResponse,
            isNotNull,
          );

          expect(
            processor.release(
              'req-guardia',
            ),
            isTrue,
          );
        },
      );

      test(
        'truncamento alto executa um reparo e preserva telemetria',
        () async {
          const rawText = 'Dose: **0,0';

          const repairedText = 'Dose: **0,05 mcg/kg/min EV**.';

          final legacyRepair = FixedRepairPort(
            TruncationRepairResult.repaired(repairedText),
          );

          final legacy = await runLegacyTransform(
            rawText: rawText,
            requestId: 'req-high-repair',
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.pt,
            inspector: FixedInspector(
              highTruncation,
            ),
            repairPort: legacyRepair,
          );

          final processorRepair = FixedRepairPort(
            TruncationRepairResult.repaired(repairedText),
          );

          final processor = buildProcessor(
            inspector: FixedInspector(
              highTruncation,
            ),
            repairPort: processorRepair,
          );

          final outcome = await processor.process(
            snapshot: buildSnapshot(
              rawText: rawText,
              requestId: 'req-high-repair',
            ),
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 2,
          );

          expect(legacyRepair.calls, 1);
          expect(processorRepair.calls, 1);

          expect(outcome.isReady, isTrue);

          expect(
            outcome.result?.finalText,
            legacy.finalText,
          );

          expect(
            outcome.result?.repairStatus,
            AiRepairStatus.repaired,
          );

          final inspection = outcome.truncation?.inspection;

          expect(inspection, isNotNull);
          expect(
            inspection?.isTruncated,
            isTrue,
          );
          expect(
            inspection?.didRetry,
            isTrue,
          );
          expect(
            inspection?.didFix,
            isTrue,
          );

          expect(
            inspection?.violationReason,
            'unclosed_markdown_bold_at_eof',
          );

          expect(
            processor.release(
              'req-high-repair',
            ),
            isTrue,
          );
        },
      );

      test(
        'truncamento médio respeita a política de cada modo',
        () async {
          const studyText = 'Explicação possivelmente incompleta.';

          final studyRepair = FixedRepairPort(
            TruncationRepairResult.repaired(
              'não deve executar',
            ),
          );

          final studyProcessor = buildProcessor(
            inspector: FixedInspector(
              mediumTruncation,
            ),
            repairPort: studyRepair,
          );

          final studyOutcome = await studyProcessor.process(
            snapshot: buildSnapshot(
              rawText: studyText,
              requestId: 'req-medium-study',
            ),
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 2,
          );

          expect(studyRepair.calls, 0);
          expect(studyOutcome.isReady, isTrue);

          expect(
            studyOutcome.result?.repairStatus,
            AiRepairStatus.notAttempted,
          );

          const plantaoText = '🟥 Conduta incompleta';

          const repairedPlantao = '🟥 Conduta imediata\n'
              '📌 Reavaliar sinais vitais';

          final plantaoRepair = FixedRepairPort(
            TruncationRepairResult.repaired(
              repairedPlantao,
            ),
          );

          final plantaoProcessor = buildProcessor(
            inspector: FixedInspector(
              mediumTruncation,
            ),
            repairPort: plantaoRepair,
          );

          final plantaoOutcome = await plantaoProcessor.process(
            snapshot: buildSnapshot(
              rawText: plantaoText,
              requestId: 'req-medium-plantao',
            ),
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 2,
          );

          expect(plantaoRepair.calls, 1);
          expect(
            plantaoOutcome.isReady,
            isTrue,
          );

          expect(
            plantaoOutcome.result?.finalText,
            repairedPlantao,
          );

          expect(
            plantaoOutcome.structure?.plantaoResponse,
            isNotNull,
          );

          expect(
            studyProcessor.release(
              'req-medium-study',
            ),
            isTrue,
          );

          expect(
            plantaoProcessor.release(
              'req-medium-plantao',
            ),
            isTrue,
          );
        },
      );

      test(
        'falha catastrófica permanece DROP_PAYLOAD',
        () async {
          const rawText = 'Dose: **';

          final legacy = await runLegacyTransform(
            rawText: rawText,
            requestId: 'req-drop',
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            inspector: FixedInspector(
              highTruncation,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.catastrophicFailure(
                'repair_proxy_failed',
              ),
            ),
          );

          final processor = buildProcessor(
            inspector: FixedInspector(
              highTruncation,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.catastrophicFailure(
                'repair_proxy_failed',
              ),
            ),
          );

          final outcome = await processor.process(
            snapshot: buildSnapshot(
              rawText: rawText,
              requestId: 'req-drop',
            ),
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 2,
          );

          expect(legacy.failed, isTrue);

          expect(
            legacy.failureReason,
            'repair_proxy_failed',
          );

          expect(
            outcome.status,
            AiResponseFinalizationStatus.repairFailed,
          );

          expect(outcome.result, isNull);

          expect(
            outcome.failureReason,
            'repair_proxy_failed',
          );

          final inspection = outcome.truncation?.inspection;

          expect(
            inspection?.didRetry,
            isTrue,
          );

          expect(
            inspection?.didFix,
            isFalse,
          );

          expect(
            processor.release('req-drop'),
            isTrue,
          );
        },
      );

      test(
        'ClinicalStructuredOutput mantém identidade',
        () async {
          const rawText = '🟥 Choque séptico\n'
              '📌 Monitorar PAM e diurese';

          final clinical = buildClinicalOutput();

          final processor = buildProcessor(
            inspector: FixedInspector(
              cleanInspection,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.clean('unused'),
            ),
          );

          final outcome = await processor.process(
            snapshot: buildSnapshot(
              rawText: rawText,
              requestId: 'req-structured',
            ),
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 2,
            structuredOutput: clinical,
          );

          expect(outcome.isReady, isTrue);

          expect(
            outcome.result?.structuredOutput,
            same(clinical),
          );

          expect(
            outcome.structure?.clinicalOutput,
            same(clinical),
          );

          expect(
            processor.release(
              'req-structured',
            ),
            isTrue,
          );
        },
      );

      test(
        'diferenças de política para saída vazia ficam documentadas',
        () async {
          const metaOnly = '[SYSTEM] conteúdo técnico interno';

          final legacyMeta = await runLegacyTransform(
            rawText: metaOnly,
            requestId: 'req-meta-only',
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            inspector: FixedInspector(
              cleanInspection,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.clean('unused'),
            ),
          );

          final metaProcessor = buildProcessor(
            inspector: FixedInspector(
              cleanInspection,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.clean('unused'),
            ),
          );

          final metaOutcome = await metaProcessor.process(
            snapshot: buildSnapshot(
              rawText: metaOnly,
              requestId: 'req-meta-only',
            ),
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 2,
          );

          expect(legacyMeta.failed, isFalse);
          expect(
            legacyMeta.finalText,
            isEmpty,
          );

          expect(
            metaOutcome.status,
            AiResponseFinalizationStatus.sanitizationFailed,
          );

          expect(
            metaOutcome.failureReason,
            'empty_after_sanitization',
          );

          final emptyProcessor = buildProcessor(
            inspector: FixedInspector(
              cleanInspection,
            ),
            repairPort: FixedRepairPort(
              TruncationRepairResult.clean('unused'),
            ),
          );

          final emptyOutcome = await emptyProcessor.process(
            snapshot: buildSnapshot(
              rawText: '',
              requestId: 'req-empty',
            ),
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.es,
            provider: 'gpt_sse',
            attempt: 2,
          );

          expect(
            emptyOutcome.status,
            AiResponseFinalizationStatus.sanitizationFailed,
          );

          expect(emptyOutcome.result, isNull);

          expect(
            metaProcessor.release(
              'req-meta-only',
            ),
            isTrue,
          );

          expect(
            emptyProcessor.release(
              'req-empty',
            ),
            isTrue,
          );
        },
      );
    },
  );
}
