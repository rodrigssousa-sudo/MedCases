import 'dart:async';

import 'ai_request_contract.dart';
import 'ai_response_accumulator.dart';
import 'ai_response_event.dart';
import 'ai_response_pipeline.dart';
import 'ai_response_result.dart';
import 'ai_terminal_coordinator.dart';

const Object _noStructuredOutput = Object();

typedef AiLegacyChunkCallback = void Function(
  String accumulatedText,
);

typedef AiLegacyDoneCallback = void Function(
  String text, [
  Object? structuredOutput,
]);

typedef AiLegacyErrorCallback = void Function(
  String error,
);

typedef AiLegacyCancelCallback = void Function();

typedef AiLegacyCallbackRunner = Future<bool> Function(
  AiRequestContract request, {
  required AiLegacyChunkCallback onChunk,
  required AiLegacyDoneCallback onDone,
  required AiLegacyErrorCallback onError,
});

typedef AiTerminalCoordinatorFactory = AiTerminalCoordinator Function(
  AiRequestContract request,
);

typedef AiResponseAccumulatorFactory = AiResponseAccumulator Function(
  AiRequestContract request,
  int expectedAttempt,
);

class LegacyCallbackAiResponsePipeline implements AiResponsePipeline {
  final AiLegacyCallbackRunner runner;
  final AiLegacyCancelCallback? cancelLegacy;
  final AiTerminalCoordinatorFactory? coordinatorFactory;
  final AiResponseAccumulatorFactory? accumulatorFactory;
  final String? provider;
  final int attempt;

  const LegacyCallbackAiResponsePipeline({
    required this.runner,
    this.cancelLegacy,
    this.coordinatorFactory,
    this.accumulatorFactory,
    this.provider,
    this.attempt = 1,
  }) : assert(attempt > 0);

  @override
  Stream<AiResponseEvent> execute(
    AiRequestContract request,
  ) {
    late final StreamController<AiResponseEvent> controller;

    final coordinator = coordinatorFactory?.call(request) ??
        AiTerminalCoordinator(
          requestId: request.requestId,
          sessionId: request.sessionId,
        );

    final accumulator = accumulatorFactory?.call(
          request,
          attempt,
        ) ??
        AiResponseAccumulator(
          expectedAttempt: attempt,
        );

    var callbackReserved = false;
    var consumerCancelled = false;
    var cancellationForwarded = false;

    var pendingDoneGeneration = 0;
    String? pendingDoneText;

    coordinator.registerCleanup(() {
      pendingDoneGeneration++;
      pendingDoneText = null;
      accumulator.seal();
    });

    bool canAcceptCallback() {
      return !callbackReserved &&
          !coordinator.isCompleted &&
          !consumerCancelled &&
          !controller.isClosed;
    }

    void addEvent(AiResponseEvent event) {
      if (consumerCancelled || controller.isClosed) return;
      controller.add(event);
    }

    void closeController() {
      if (!controller.isClosed) {
        unawaited(controller.close());
      }
    }

    AiTerminalCommitOutcome commitTerminal({
      required AiResponseResult result,
      required String source,
    }) {
      final outcome = coordinator.tryCommit(
        result: result,
        source: source,
      );

      if (outcome != AiTerminalCommitOutcome.accepted) {
        return outcome;
      }

      callbackReserved = true;

      if (!consumerCancelled && !controller.isClosed) {
        controller.add(
          AiResponseTerminal(
            requestId: request.requestId,
            sessionId: request.sessionId,
            result: coordinator.result!,
          ),
        );

        closeController();
      }

      return outcome;
    }

    String resolveFinalText(String text) {
      return text.isNotEmpty ? text : accumulator.text;
    }

    AiResponseResult buildCompletedResult({
      required String text,
      Object? structuredOutput,
    }) {
      final finalText = resolveFinalText(text);

      return AiResponseResult(
        requestId: request.requestId,
        sessionId: request.sessionId,
        finalText: finalText,
        displayText: finalText,
        provider: provider,
        attempt: attempt,
        terminalCause: AiTerminalCause.completed,
        persistenceStatus: AiPersistenceStatus.notAttempted,
        structuredOutput: structuredOutput,
      );
    }

    AiResponseResult buildErrorResult({
      required String errorCode,
      required String errorMessage,
    }) {
      return AiResponseResult(
        requestId: request.requestId,
        sessionId: request.sessionId,
        finalText: accumulator.text,
        displayText: accumulator.text,
        provider: provider,
        attempt: attempt,
        terminalCause: AiTerminalCause.error,
        isPartial: accumulator.isNotEmpty,
        persistenceStatus: AiPersistenceStatus.notAttempted,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
    }

    AiResponseResult buildCancelledResult() {
      return AiResponseResult(
        requestId: request.requestId,
        sessionId: request.sessionId,
        finalText: accumulator.text,
        displayText: accumulator.text,
        provider: provider,
        attempt: attempt,
        terminalCause: AiTerminalCause.cancelled,
        isPartial: accumulator.isNotEmpty,
        persistenceStatus: AiPersistenceStatus.notAttempted,
      );
    }

    void handleDone(
      String text, [
      Object? structuredOutput = _noStructuredOutput,
    ]) {
      final hasStructuredOutput =
          !identical(structuredOutput, _noStructuredOutput);

      if (hasStructuredOutput) {
        if (consumerCancelled || coordinator.isCompleted) {
          return;
        }

        if (callbackReserved) {
          final reservedText = pendingDoneText ?? '';

          final textConflicts = reservedText.isNotEmpty &&
              text.isNotEmpty &&
              reservedText != text;

          if (textConflicts) {
            return;
          }
        } else {
          callbackReserved = true;
          pendingDoneText = text;
        }

        pendingDoneGeneration++;

        commitTerminal(
          result: buildCompletedResult(
            text: text.isNotEmpty ? text : pendingDoneText ?? '',
            structuredOutput: structuredOutput,
          ),
          source: 'legacy_structured_done',
        );

        return;
      }

      if (!canAcceptCallback()) return;

      callbackReserved = true;
      pendingDoneText = text;

      final generation = ++pendingDoneGeneration;

      scheduleMicrotask(() {
        if (consumerCancelled ||
            coordinator.isCompleted ||
            generation != pendingDoneGeneration) {
          return;
        }

        commitTerminal(
          result: buildCompletedResult(
            text: pendingDoneText ?? '',
          ),
          source: 'legacy_done',
        );
      });
    }

    void forwardCancellationOnce() {
      if (cancellationForwarded) return;

      cancellationForwarded = true;

      try {
        cancelLegacy?.call();
      } catch (_) {
        // Cancelamento do consumidor não deve falhar porque
        // o transporte legado lançou durante sua interrupção.
      }
    }

    Future<void> startRunner() async {
      addEvent(
        AiResponseStarted(
          requestId: request.requestId,
          sessionId: request.sessionId,
          provider: provider,
          attempt: attempt,
        ),
      );

      try {
        final accepted = await runner(
          request,
          onChunk: (accumulatedText) {
            if (!canAcceptCallback()) return;

            final update = accumulator.acceptSnapshot(
              accumulatedText,
              attempt: attempt,
            );

            if (!update.accepted) return;

            addEvent(
              AiResponseDelta(
                requestId: request.requestId,
                sessionId: request.sessionId,
                delta: update.delta,
                accumulatedText: update.accumulatedText,
                provider: provider,
                attempt: attempt,
                replacesAccumulatedText: update.replacesAccumulatedText,
              ),
            );
          },
          onDone: handleDone,
          onError: (error) {
            if (!canAcceptCallback()) return;

            callbackReserved = true;

            if (error.trim() == 'PIPELINE_STREAM_CANCELLED') {
              commitTerminal(
                result: buildCancelledResult(),
                source: 'legacy_external_cancel',
              );
              return;
            }

            commitTerminal(
              result: buildErrorResult(
                errorCode: _legacyErrorCode(error),
                errorMessage: error,
              ),
              source: 'legacy_error',
            );
          },
        );

        if (!accepted && canAcceptCallback()) {
          callbackReserved = true;

          commitTerminal(
            result: buildErrorResult(
              errorCode: 'legacy_send_rejected',
              errorMessage: 'O executor legado rejeitou o envio '
                  'sem emitir terminal.',
            ),
            source: 'legacy_rejected',
          );
        }
      } catch (error) {
        if (!canAcceptCallback()) return;

        callbackReserved = true;

        commitTerminal(
          result: buildErrorResult(
            errorCode: 'legacy_runner_exception',
            errorMessage: error.toString(),
          ),
          source: 'legacy_exception',
        );
      }
    }

    controller = StreamController<AiResponseEvent>(
      sync: true,
      onListen: () {
        unawaited(startRunner());
      },
      onCancel: () {
        if (coordinator.isCompleted) return;

        consumerCancelled = true;
        callbackReserved = true;
        pendingDoneGeneration++;

        final outcome = coordinator.tryCommit(
          result: buildCancelledResult(),
          source: 'consumer_cancel',
        );

        if (outcome == AiTerminalCommitOutcome.accepted) {
          forwardCancellationOnce();
        }
      },
    );

    return controller.stream;
  }
}

String _legacyErrorCode(String error) {
  final normalized = error.trim();

  if (normalized == 'AUTH_REQUIRED') {
    return 'AUTH_REQUIRED';
  }

  if (normalized.startsWith('[auth_expired]')) {
    return 'auth_expired';
  }

  return 'legacy_callback_error';
}
