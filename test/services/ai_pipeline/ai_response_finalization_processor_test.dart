import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/services/ai/ai_finalization_transaction.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';
import 'package:medcases/services/plantao_pipeline.dart';

class RecordingInspector implements AiTruncationInspectorPort {
  final List<String> log;
  final TruncationCheckResult result;

  int calls = 0;

  RecordingInspector({
    required this.log,
    required this.result,
  });

  @override
  TruncationCheckResult inspect(String text) {
    calls++;
    log.add('inspect');
    return result;
  }
}

class RecordingRepairPort implements AiTruncationRepairPort {
  final List<String> log;
  final TruncationRepairResult result;

  int calls = 0;
  String? capturedText;

  RecordingRepairPort({
    required this.log,
    required this.result,
  });

  @override
  Future<TruncationRepairResult> repair({
    required String originalText,
    required String requestId,
    required bool isPlantaoMode,
    required String appLanguage,
  }) async {
    calls++;
    capturedText = originalText;
    log.add('repair');
    return result;
  }
}

class RecordingSanitizerPort implements AiResponseSanitizerPort {
  final List<String> log;
  final String Function(String) transform;
  final bool recoverable;
  final bool severe;

  int calls = 0;
  String? capturedText;

  RecordingSanitizerPort({
    required this.log,
    required this.transform,
    this.recoverable = true,
    this.severe = false,
  });

  @override
  AiResponseSanitizationOutcome sanitize({
    required String text,
    required AiRequestMode mode,
    required AiRequestLocale locale,
  }) {
    calls++;
    capturedText = text;
    log.add('sanitize');

    final output = transform(text);

    return AiResponseSanitizationOutcome(
      originalText: text,
      text: output,
      mode: mode,
      locale: locale,
      hadMetaLeak: output != text,
      hadSevereLeak: severe,
      isRecoverable: recoverable,
    );
  }
}

class RecordingPlantaoParser implements AiPlantaoParserPort {
  final List<String> log;
  final PlantaoResponse? result;

  int calls = 0;
  String? capturedText;

  RecordingPlantaoParser({
    required this.log,
    this.result,
  });

  @override
  PlantaoResponse? parse(String text) {
    calls++;
    capturedText = text;
    log.add('parse');
    return result;
  }
}

const cleanInspection = TruncationCheckResult(
  isTruncated: false,
  confidenceLevel: TruncationConfidence.low,
  violationReason: 'none',
);

const truncatedInspection = TruncationCheckResult(
  isTruncated: true,
  confidenceLevel: TruncationConfidence.high,
  violationReason: 'test_truncation',
);

FinalOutputSnapshot snapshot({
  String rawOutput = 'Resposta clínica.',
  String sessionId = 'session-1',
  String requestId = 'request-1',
}) {
  return FinalOutputSnapshot(
    rawOutput: rawOutput,
    sessionId: sessionId,
    parentRequestId: requestId,
    frozenAt: DateTime.utc(2026, 7, 22),
  );
}

ClinicalStructuredOutput clinicalOutput() {
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

AiResponseFinalizationProcessor buildProcessor({
  required RecordingInspector inspector,
  required RecordingRepairPort repairPort,
  required RecordingSanitizerPort sanitizerPort,
  required RecordingPlantaoParser plantaoParser,
}) {
  return AiResponseFinalizationProcessor(
    truncationCoordinator: AiTruncationRepairCoordinator(
      inspector: inspector,
      repairPort: repairPort,
    ),
    sanitizer: AiResponseSanitizer(
      port: sanitizerPort,
    ),
    structureParser: AiResponseStructureParser(
      plantaoParser: plantaoParser,
    ),
  );
}

void main() {
  group(
    'AiResponseFinalizationProcessor',
    () {
      test(
        'preserva a ordem reparo, sanitização e parsing',
        () async {
          final log = <String>[];

          final inspector = RecordingInspector(
            log: log,
            result: truncatedInspection,
          );

          final repairPort = RecordingRepairPort(
            log: log,
            result: TruncationRepairResult.repaired(
              '[SYSTEM] interno\n'
              '🟥 CHOQUE SÉPTICO\n'
              '💊 Noradrenalina 0,05 mcg/kg/min EV',
            ),
          );

          final sanitizerPort = RecordingSanitizerPort(
            log: log,
            transform: (text) => text.replaceFirst(
              '[SYSTEM] interno\n',
              '',
            ),
          );

          final plantaoParser = RecordingPlantaoParser(
            log: log,
            result: const PlantaoResponse(
              conduta: 'CHOQUE SÉPTICO',
              primeiraLinha: 'Noradrenalina 0,05 mcg/kg/min EV',
              monitorar: '',
            ),
          );

          final processor = buildProcessor(
            inspector: inspector,
            repairPort: repairPort,
            sanitizerPort: sanitizerPort,
            plantaoParser: plantaoParser,
          );

          final outcome = await processor.process(
            snapshot: snapshot(
              rawOutput: 'Velocidade: **55–7',
            ),
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 1,
          );

          expect(
            log,
            <String>[
              'inspect',
              'repair',
              'sanitize',
              'parse',
            ],
          );

          expect(outcome.isReady, isTrue);

          expect(
            outcome.result?.finalText,
            '🟥 CHOQUE SÉPTICO\n'
            '💊 Noradrenalina 0,05 mcg/kg/min EV',
          );

          expect(
            outcome.result?.repairStatus,
            AiRepairStatus.repaired,
          );

          expect(
            outcome.structure?.plantaoResponse,
            isNotNull,
          );
        },
      );

      test(
        'snapshot fornece identidade e texto bruto',
        () async {
          final log = <String>[];

          final inspector = RecordingInspector(
            log: log,
            result: cleanInspection,
          );

          final repairPort = RecordingRepairPort(
            log: log,
            result: TruncationRepairResult.clean(
              'unused',
            ),
          );

          final sanitizerPort = RecordingSanitizerPort(
            log: log,
            transform: (text) => text,
          );

          final plantaoParser = RecordingPlantaoParser(
            log: log,
          );

          final processor = buildProcessor(
            inspector: inspector,
            repairPort: repairPort,
            sanitizerPort: sanitizerPort,
            plantaoParser: plantaoParser,
          );

          final frozen = snapshot(
            rawOutput: 'Resposta congelada.',
            sessionId: 'session-frozen',
            requestId: 'request-frozen',
          );

          final outcome = await processor.process(
            snapshot: frozen,
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.es,
            provider: 'gemini_free',
            attempt: 2,
          );

          expect(
            outcome.snapshot,
            same(frozen),
          );

          expect(
            outcome.result?.requestId,
            'request-frozen',
          );

          expect(
            outcome.result?.sessionId,
            'session-frozen',
          );

          expect(
            outcome.result?.provider,
            'gemini_free',
          );

          expect(
            outcome.result?.attempt,
            2,
          );

          expect(
            outcome.result?.finalText,
            'Resposta congelada.',
          );

          expect(
            outcome.result?.displayText,
            'Resposta congelada.',
          );

          expect(
            outcome.result?.persistenceStatus,
            AiPersistenceStatus.notAttempted,
          );

          expect(repairPort.calls, 0);
          expect(plantaoParser.calls, 0);
        },
      );

      test(
        'falha catastrófica de reparo bloqueia etapas seguintes',
        () async {
          final log = <String>[];

          final inspector = RecordingInspector(
            log: log,
            result: truncatedInspection,
          );

          final repairPort = RecordingRepairPort(
            log: log,
            result: TruncationRepairResult.catastrophicFailure(
              'repair_proxy_failed',
            ),
          );

          final sanitizerPort = RecordingSanitizerPort(
            log: log,
            transform: (text) => text,
          );

          final plantaoParser = RecordingPlantaoParser(
            log: log,
          );

          final processor = buildProcessor(
            inspector: inspector,
            repairPort: repairPort,
            sanitizerPort: sanitizerPort,
            plantaoParser: plantaoParser,
          );

          final outcome = await processor.process(
            snapshot: snapshot(
              rawOutput: 'Dose: **0,0',
            ),
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 1,
          );

          expect(
            outcome.status,
            AiResponseFinalizationStatus.repairFailed,
          );

          expect(outcome.result, isNull);

          expect(
            outcome.failureCode,
            'truncation_repair_failed',
          );

          expect(
            outcome.failureReason,
            'repair_proxy_failed',
          );

          expect(
            log,
            <String>[
              'inspect',
              'repair',
            ],
          );

          expect(sanitizerPort.calls, 0);
          expect(plantaoParser.calls, 0);
        },
      );

      test(
        'sanitização não recuperável bloqueia parsing',
        () async {
          final log = <String>[];

          final inspector = RecordingInspector(
            log: log,
            result: cleanInspection,
          );

          final repairPort = RecordingRepairPort(
            log: log,
            result: TruncationRepairResult.clean(
              'unused',
            ),
          );

          final sanitizerPort = RecordingSanitizerPort(
            log: log,
            transform: (_) => '',
            recoverable: false,
            severe: true,
          );

          final plantaoParser = RecordingPlantaoParser(
            log: log,
          );

          final processor = buildProcessor(
            inspector: inspector,
            repairPort: repairPort,
            sanitizerPort: sanitizerPort,
            plantaoParser: plantaoParser,
          );

          final outcome = await processor.process(
            snapshot: snapshot(
              rawOutput: '[SYSTEM] somente metadados',
            ),
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            provider: 'gemini_paid',
            attempt: 2,
          );

          expect(
            outcome.status,
            AiResponseFinalizationStatus.sanitizationFailed,
          );

          expect(outcome.result, isNull);
          expect(plantaoParser.calls, 0);

          expect(
            log,
            <String>[
              'inspect',
              'sanitize',
            ],
          );
        },
      );

      test(
        'structured output inválido falha explicitamente',
        () async {
          final log = <String>[];

          final processor = buildProcessor(
            inspector: RecordingInspector(
              log: log,
              result: cleanInspection,
            ),
            repairPort: RecordingRepairPort(
              log: log,
              result: TruncationRepairResult.clean('unused'),
            ),
            sanitizerPort: RecordingSanitizerPort(
              log: log,
              transform: (text) => text,
            ),
            plantaoParser: RecordingPlantaoParser(
              log: log,
            ),
          );

          final outcome = await processor.process(
            snapshot: snapshot(),
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 1,
            structuredOutput: {
              'diagnosticoHeuristico': 'incompleto',
            },
          );

          expect(
            outcome.status,
            AiResponseFinalizationStatus.structuredOutputInvalid,
          );

          expect(outcome.result, isNull);

          expect(
            outcome.failureCode,
            'structured_output_invalid',
          );

          expect(
            outcome.structure?.hasInvalidStructuredOutput,
            isTrue,
          );
        },
      );

      test(
        'texto com âncoras e ClinicalStructuredOutput coexistem',
        () async {
          final log = <String>[];

          final processor = buildProcessor(
            inspector: RecordingInspector(
              log: log,
              result: cleanInspection,
            ),
            repairPort: RecordingRepairPort(
              log: log,
              result: TruncationRepairResult.clean('unused'),
            ),
            sanitizerPort: RecordingSanitizerPort(
              log: log,
              transform: (text) => text,
            ),
            plantaoParser: RecordingPlantaoParser(
              log: log,
              result: const PlantaoResponse(
                conduta: 'Choque séptico',
                monitorar: 'PAM e diurese',
              ),
            ),
          );

          final clinical = clinicalOutput();

          final outcome = await processor.process(
            snapshot: snapshot(
              rawOutput: '🟥 Choque séptico\n'
                  '📌 PAM e diurese',
            ),
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
            provider: 'gpt_sse',
            attempt: 1,
            structuredOutput: clinical,
          );

          expect(outcome.isReady, isTrue);

          expect(
            outcome.structure?.plantaoResponse,
            isNotNull,
          );

          expect(
            outcome.structure?.clinicalOutput,
            same(clinical),
          );

          expect(
            outcome.result?.structuredOutput,
            same(clinical),
          );
        },
      );

      test(
        'MAX_TOKENS força reparo',
        () async {
          final log = <String>[];

          final inspector = RecordingInspector(
            log: log,
            result: cleanInspection,
          );

          final repairPort = RecordingRepairPort(
            log: log,
            result: TruncationRepairResult.repaired(
              'Resposta reparada.',
            ),
          );

          final processor = buildProcessor(
            inspector: inspector,
            repairPort: repairPort,
            sanitizerPort: RecordingSanitizerPort(
              log: log,
              transform: (text) => text,
            ),
            plantaoParser: RecordingPlantaoParser(
              log: log,
            ),
          );

          final outcome = await processor.process(
            snapshot: snapshot(
              rawOutput: 'Resposta parcial',
            ),
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.es,
            provider: 'gemini_free',
            attempt: 1,
            providerFinishReason: 'MAX_TOKENS',
          );

          expect(outcome.isReady, isTrue);
          expect(inspector.calls, 0);
          expect(repairPort.calls, 1);

          expect(
            outcome.result?.finalText,
            'Resposta reparada.',
          );

          expect(
            outcome.result?.repairStatus,
            AiRepairStatus.repaired,
          );
        },
      );

      test(
        'flags terminais são preservados',
        () async {
          final log = <String>[];

          final processor = buildProcessor(
            inspector: RecordingInspector(
              log: log,
              result: cleanInspection,
            ),
            repairPort: RecordingRepairPort(
              log: log,
              result: TruncationRepairResult.clean('unused'),
            ),
            sanitizerPort: RecordingSanitizerPort(
              log: log,
              transform: (text) => text,
            ),
            plantaoParser: RecordingPlantaoParser(
              log: log,
            ),
          );

          final outcome = await processor.process(
            snapshot: snapshot(),
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.pt,
            provider: 'gemini_paid',
            attempt: 3,
            terminalCause: AiTerminalCause.fallback,
            isPartial: true,
            isFallback: true,
          );

          expect(
            outcome.result?.terminalCause,
            AiTerminalCause.fallback,
          );

          expect(
            outcome.result?.isPartial,
            isTrue,
          );

          expect(
            outcome.result?.isFallback,
            isTrue,
          );

          expect(
            outcome.result?.attempt,
            3,
          );
        },
      );

      test(
        'release remove retenção do reparo',
        () async {
          final log = <String>[];

          final processor = buildProcessor(
            inspector: RecordingInspector(
              log: log,
              result: cleanInspection,
            ),
            repairPort: RecordingRepairPort(
              log: log,
              result: TruncationRepairResult.clean('unused'),
            ),
            sanitizerPort: RecordingSanitizerPort(
              log: log,
              transform: (text) => text,
            ),
            plantaoParser: RecordingPlantaoParser(
              log: log,
            ),
          );

          await processor.process(
            snapshot: snapshot(
              requestId: 'request-release',
            ),
            mode: AiRequestMode.estudo,
            locale: AiRequestLocale.pt,
            provider: 'gemini_free',
            attempt: 1,
          );

          expect(
            processor.truncationCoordinator.containsRequest(
              'request-release',
            ),
            isTrue,
          );

          expect(
            processor.release(
              'request-release',
            ),
            isTrue,
          );

          expect(
            processor.truncationCoordinator.containsRequest(
              'request-release',
            ),
            isFalse,
          );
        },
      );

      test(
        'attempt inválido é rejeitado',
        () async {
          final log = <String>[];

          final processor = buildProcessor(
            inspector: RecordingInspector(
              log: log,
              result: cleanInspection,
            ),
            repairPort: RecordingRepairPort(
              log: log,
              result: TruncationRepairResult.clean('unused'),
            ),
            sanitizerPort: RecordingSanitizerPort(
              log: log,
              transform: (text) => text,
            ),
            plantaoParser: RecordingPlantaoParser(
              log: log,
            ),
          );

          expect(
            () => processor.process(
              snapshot: snapshot(),
              mode: AiRequestMode.estudo,
              locale: AiRequestLocale.pt,
              provider: 'gpt',
              attempt: 0,
            ),
            throwsArgumentError,
          );

          expect(log, isEmpty);
        },
      );
    },
  );
}
