import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';

class FakeInspector implements AiTruncationInspectorPort {
  final TruncationCheckResult result;

  int calls = 0;
  String? capturedText;

  FakeInspector(this.result);

  @override
  TruncationCheckResult inspect(String text) {
    calls++;
    capturedText = text;
    return result;
  }
}

class FakeRepairPort implements AiTruncationRepairPort {
  TruncationRepairResult result;

  int calls = 0;

  String? capturedOriginalText;
  String? capturedRequestId;
  bool? capturedIsPlantaoMode;
  String? capturedLanguage;

  Completer<TruncationRepairResult>? completer;

  FakeRepairPort(this.result);

  @override
  Future<TruncationRepairResult> repair({
    required String originalText,
    required String requestId,
    required bool isPlantaoMode,
    required String appLanguage,
  }) {
    calls++;

    capturedOriginalText = originalText;
    capturedRequestId = requestId;
    capturedIsPlantaoMode = isPlantaoMode;
    capturedLanguage = appLanguage;

    if (completer != null) {
      return completer!.future;
    }

    return Future<TruncationRepairResult>.value(
      result,
    );
  }
}

const cleanInspection = TruncationCheckResult.clean;

const mediumInspection = TruncationCheckResult(
  isTruncated: true,
  confidenceLevel: TruncationConfidence.medium,
  violationReason: 'abrupt_non_punctuation_termination',
);

const highInspection = TruncationCheckResult(
  isTruncated: true,
  confidenceLevel: TruncationConfidence.high,
  violationReason: 'unclosed_numeric_range',
);

void main() {
  group('AiTruncationRepairCoordinator', () {
    test(
      'reutiliza o TruncationInspector real',
      () {
        const port = ExistingTruncationInspectorPort();

        final truncated = port.inspect(
          'Velocidade: **55–7',
        );

        final clean = port.inspect(
          'Conduta concluída.',
        );

        expect(truncated.isTruncated, isTrue);
        expect(
          truncated.confidenceLevel,
          TruncationConfidence.high,
        );

        expect(clean.isTruncated, isFalse);
      },
    );

    test(
      'texto limpo não chama o reparo',
      () async {
        final inspector = FakeInspector(cleanInspection);

        final repair = FakeRepairPort(
          TruncationRepairResult.repaired(
            'Não deveria ser usado.',
          ),
        );

        final coordinator = AiTruncationRepairCoordinator(
          inspector: inspector,
          repairPort: repair,
        );

        final outcome = await coordinator.process(
          originalText: 'Resposta completa.',
          requestId: 'request-clean',
          mode: AiRequestMode.plantao,
          locale: AiRequestLocale.pt,
        );

        expect(inspector.calls, 1);
        expect(repair.calls, 0);
        expect(outcome.text, 'Resposta completa.');
        expect(outcome.isValid, isTrue);
        expect(outcome.isTruncated, isFalse);
        expect(
          outcome.repairStatus,
          AiRepairStatus.notNeeded,
        );
        expect(outcome.repairAttempted, isFalse);
      },
    );

    test(
      'Plantão repara truncamento de confiança média',
      () async {
        final inspector = FakeInspector(mediumInspection);

        final repair = FakeRepairPort(
          TruncationRepairResult.repaired(
            'Resposta reparada.',
          ),
        );

        final coordinator = AiTruncationRepairCoordinator(
          inspector: inspector,
          repairPort: repair,
        );

        final outcome = await coordinator.process(
          originalText: 'Resposta interrompida',
          requestId: 'request-plantao',
          mode: AiRequestMode.plantao,
          locale: AiRequestLocale.pt,
        );

        expect(repair.calls, 1);
        expect(
          repair.capturedIsPlantaoMode,
          isTrue,
        );
        expect(repair.capturedLanguage, 'pt');
        expect(
          repair.capturedRequestId,
          'request-plantao',
        );
        expect(outcome.text, 'Resposta reparada.');
        expect(outcome.wasRepaired, isTrue);
        expect(
          outcome.repairStatus,
          AiRepairStatus.repaired,
        );
        expect(outcome.inspection.didRetry, isTrue);
        expect(outcome.inspection.didFix, isTrue);
      },
    );

    test(
      'Estudo não repara truncamento somente médio',
      () async {
        final inspector = FakeInspector(mediumInspection);

        final repair = FakeRepairPort(
          TruncationRepairResult.repaired(
            'Não deveria ser usado.',
          ),
        );

        final coordinator = AiTruncationRepairCoordinator(
          inspector: inspector,
          repairPort: repair,
        );

        final outcome = await coordinator.process(
          originalText: 'Resposta interrompida',
          requestId: 'request-estudo-medium',
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.pt,
        );

        expect(repair.calls, 0);
        expect(
          outcome.text,
          'Resposta interrompida',
        );
        expect(outcome.isTruncated, isTrue);
        expect(outcome.repairAttempted, isFalse);
        expect(
          outcome.repairStatus,
          AiRepairStatus.notAttempted,
        );
      },
    );

    test(
      'Estudo repara truncamento de confiança alta',
      () async {
        final inspector = FakeInspector(highInspection);

        final repair = FakeRepairPort(
          TruncationRepairResult.repaired(
            'Respuesta reparada.',
          ),
        );

        final coordinator = AiTruncationRepairCoordinator(
          inspector: inspector,
          repairPort: repair,
        );

        final outcome = await coordinator.process(
          originalText: 'Respuesta 5–',
          requestId: 'request-estudo-high',
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.es,
        );

        expect(repair.calls, 1);
        expect(
          repair.capturedIsPlantaoMode,
          isFalse,
        );
        expect(repair.capturedLanguage, 'es');
        expect(outcome.text, 'Respuesta reparada.');
        expect(outcome.wasRepaired, isTrue);
      },
    );

    test(
      'MAX_TOKENS prevalece sobre a heurística textual',
      () async {
        final inspector = FakeInspector(cleanInspection);

        final repair = FakeRepairPort(
          TruncationRepairResult.repaired(
            'Continuação válida.',
          ),
        );

        final coordinator = AiTruncationRepairCoordinator(
          inspector: inspector,
          repairPort: repair,
        );

        final outcome = await coordinator.process(
          originalText: 'Texto aparentemente completo.',
          requestId: 'request-max-tokens',
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.pt,
          providerFinishReason: 'MAX_TOKENS',
        );

        expect(inspector.calls, 0);
        expect(repair.calls, 1);
        expect(outcome.isTruncated, isTrue);
        expect(
          outcome.inspection.confidenceLevel,
          TruncationConfidence.high,
        );
        expect(
          outcome.inspection.violationReason,
          'provider_finish_reason_max_tokens',
        );
      },
    );

    test(
      'falha catastrófica gera outcome inválido',
      () async {
        final inspector = FakeInspector(highInspection);

        final repair = FakeRepairPort(
          TruncationRepairResult.catastrophicFailure(
            'providers_unavailable',
          ),
        );

        final coordinator = AiTruncationRepairCoordinator(
          inspector: inspector,
          repairPort: repair,
        );

        final outcome = await coordinator.process(
          originalText: 'Dose: 55–',
          requestId: 'request-failed-repair',
          mode: AiRequestMode.plantao,
          locale: AiRequestLocale.pt,
        );

        expect(repair.calls, 1);
        expect(outcome.isValid, isFalse);
        expect(outcome.text, isEmpty);
        expect(
          outcome.repairStatus,
          AiRepairStatus.failed,
        );
        expect(
          outcome.failureReason,
          'providers_unavailable',
        );
        expect(outcome.inspection.didRetry, isTrue);
        expect(outcome.inspection.didFix, isFalse);
      },
    );

    test(
      'requestId é processado no máximo uma vez',
      () async {
        final inspector = FakeInspector(highInspection);

        final repair = FakeRepairPort(
          TruncationRepairResult.repaired(
            'Resposta reparada.',
          ),
        );

        repair.completer = Completer<TruncationRepairResult>();

        final coordinator = AiTruncationRepairCoordinator(
          inspector: inspector,
          repairPort: repair,
        );

        final first = coordinator.process(
          originalText: 'Dose: 55–',
          requestId: 'request-once',
          mode: AiRequestMode.plantao,
          locale: AiRequestLocale.pt,
        );

        final second = coordinator.process(
          originalText: 'Outro conteúdo',
          requestId: 'request-once',
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.es,
        );

        await Future<void>.delayed(Duration.zero);

        expect(inspector.calls, 1);
        expect(repair.calls, 1);
        expect(
          coordinator.containsRequest(
            'request-once',
          ),
          isTrue,
        );

        repair.completer!.complete(
          TruncationRepairResult.repaired(
            'Resposta reparada.',
          ),
        );

        final firstOutcome = await first;
        final secondOutcome = await second;

        expect(firstOutcome, same(secondOutcome));
        expect(
          firstOutcome.text,
          'Resposta reparada.',
        );

        expect(
          coordinator.release('request-once'),
          isTrue,
        );

        expect(
          coordinator.release('request-once'),
          isFalse,
        );

        expect(coordinator.retainedRequestCount, 0);
      },
    );

    test(
      'requestId vazio é rejeitado antes da inspeção',
      () {
        final inspector = FakeInspector(cleanInspection);

        final repair = FakeRepairPort(
          TruncationRepairResult.clean(''),
        );

        final coordinator = AiTruncationRepairCoordinator(
          inspector: inspector,
          repairPort: repair,
        );

        expect(
          () => coordinator.process(
            originalText: 'Texto.',
            requestId: '   ',
            mode: AiRequestMode.plantao,
            locale: AiRequestLocale.pt,
          ),
          throwsArgumentError,
        );

        expect(inspector.calls, 0);
        expect(repair.calls, 0);
      },
    );
  });
}
