import '../ai_request_contract.dart';
import '../ai_response_event.dart';
import '../ai_response_pipeline.dart';
import '../ai_response_result.dart';

enum PlantaoBufferedCutoverDisposition {
  bypassed,
  committed,
  fallbackAllowed,
  rejectedAfterStart,
}

final class PlantaoBufferedCutoverDecision {
  final PlantaoBufferedCutoverDisposition disposition;
  final AiResponseResult? result;
  final String reason;
  final int eventCount;
  final int terminalCount;

  const PlantaoBufferedCutoverDecision({
    required this.disposition,
    required this.reason,
    this.result,
    this.eventCount = 0,
    this.terminalCount = 0,
  });

  bool get shouldCommit =>
      disposition == PlantaoBufferedCutoverDisposition.committed;

  bool get mayFallback =>
      disposition ==
          PlantaoBufferedCutoverDisposition.fallbackAllowed ||
      disposition == PlantaoBufferedCutoverDisposition.bypassed;
}

/// Buffers a typed pipeline and exposes only one validated terminal decision.
///
/// It never calls UI callbacks, providers, persistence, Firestore, or the
/// legacy fallback itself.
///
/// Safety rule:
/// - before the first event, failure may fall back to the legacy path;
/// - after any event, failure is rejected and MUST NOT execute a second provider.
final class PlantaoBufferedCutoverController {
  final bool enabled;
  final AiResponsePipeline? pipeline;

  const PlantaoBufferedCutoverController({
    required this.enabled,
    required this.pipeline,
  });

  const PlantaoBufferedCutoverController.disabled()
      : enabled = false,
        pipeline = null;

  Future<PlantaoBufferedCutoverDecision> execute(
    AiRequestContract request, {
    void Function(String accumulatedText)? onProvisionalText,
  }) async {
    final activePipeline = pipeline;
    if (!enabled || activePipeline == null) {
      return const PlantaoBufferedCutoverDecision(
        disposition: PlantaoBufferedCutoverDisposition.bypassed,
        reason: 'feature_flag_closed',
      );
    }

    var eventCount = 0;
    var terminalCount = 0;
    var provisionalEmissionCount = 0;
    var lastProvisionalText = '';
    AiResponseResult? terminalResult;

    try {
      await for (final event in activePipeline.execute(request)) {
        eventCount++;

        if (event.requestId != request.requestId ||
            event.sessionId != request.sessionId) {
          return PlantaoBufferedCutoverDecision(
            disposition:
                PlantaoBufferedCutoverDisposition.rejectedAfterStart,
            reason: 'event_identity_mismatch',
            eventCount: eventCount,
            terminalCount: terminalCount,
          );
        }

        if (terminalCount > 0) {
          return PlantaoBufferedCutoverDecision(
            disposition:
                PlantaoBufferedCutoverDisposition.rejectedAfterStart,
            reason: 'event_after_terminal',
            eventCount: eventCount,
            terminalCount: terminalCount,
          );
        }

        if (event is AiResponseDelta) {
          final provisionalText = event.accumulatedText;
          final provisionalGrowth =
              provisionalText.length - lastProvisionalText.length;
          final shouldEmitProvisional =
              provisionalText.isNotEmpty &&
                  (event.replacesAccumulatedText ||
                      provisionalEmissionCount < 3 ||
                      provisionalGrowth >= 24);

          if (shouldEmitProvisional) {
            lastProvisionalText = provisionalText;
            provisionalEmissionCount++;

            try {
              onProvisionalText?.call(provisionalText);
            } catch (_) {
              // A projeção provisória é somente visual. Uma falha do
              // consumidor nunca altera o terminal, o fallback ou a
              // persistência da transação canônica.
            }
          }
        }

        if (event is AiResponseTerminal) {
          terminalCount++;
          terminalResult = event.result;
        }
      }
    } catch (_) {
      return PlantaoBufferedCutoverDecision(
        disposition: eventCount == 0
            ? PlantaoBufferedCutoverDisposition.fallbackAllowed
            : PlantaoBufferedCutoverDisposition.rejectedAfterStart,
        reason: eventCount == 0
            ? 'pipeline_failed_before_first_event'
            : 'pipeline_failed_after_start',
        eventCount: eventCount,
        terminalCount: terminalCount,
      );
    }

    if (terminalCount != 1 || terminalResult == null) {
      return PlantaoBufferedCutoverDecision(
        disposition: eventCount == 0
            ? PlantaoBufferedCutoverDisposition.fallbackAllowed
            : PlantaoBufferedCutoverDisposition.rejectedAfterStart,
        reason: eventCount == 0
            ? 'pipeline_completed_without_events'
            : 'pipeline_completed_without_single_terminal',
        eventCount: eventCount,
        terminalCount: terminalCount,
      );
    }

    final result = terminalResult;
    final acceptedCause =
        result.terminalCause == AiTerminalCause.completed ||
            result.terminalCause == AiTerminalCause.fallback ||
            (result.terminalCause == AiTerminalCause.partial &&
                result.isPartial);

    final valid =
        result.requestId == request.requestId &&
            result.sessionId == request.sessionId &&
            result.finalText.trim().isNotEmpty &&
            result.displayText == result.finalText &&
            acceptedCause;

    if (!valid) {
      return PlantaoBufferedCutoverDecision(
        disposition:
            PlantaoBufferedCutoverDisposition.rejectedAfterStart,
        reason: 'terminal_invariant_rejected',
        eventCount: eventCount,
        terminalCount: terminalCount,
      );
    }

    return PlantaoBufferedCutoverDecision(
      disposition: PlantaoBufferedCutoverDisposition.committed,
      reason: 'typed_terminal_validated',
      result: result,
      eventCount: eventCount,
      terminalCount: terminalCount,
    );
  }
}
