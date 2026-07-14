// ══════════════════════════════════════════════════════════════════════════════
// lib/services/ai/timeout_content_safety_guard.dart
// MICRO-BUILD 462E-A.5.3.7.2.1 — Canonical Timeout Content Safety Guard
//
// Extracted from app_provider.dart (previously at lines 223 and 590) into a
// standalone, production-importable domain module.
//
// Owns:
//   • TerminalCause     — enum of all recognised terminal pipeline signals
//   • TimeoutSafetyVerdict — enum of all possible safety evaluation outcomes
//   • TimeoutContentSafetyGuard — all-static evaluator + fallback provider
//
// CONTRACT:
//   1. runTruncationAndRepair() is evaluated UNCONDITIONALLY for timeout paths.
//   2. If TruncationInspector evaluates the output as truncated AND confidence
//      is NOT high (low confidence of repair), the raw snapshot is DISCARDED
//      and the system-defined operational fallback is persisted instead.
//   3. Under no circumstances may a partial timeout fragment generate an active
//      ToolResolution payload.
//   4. If TruncationInspector confidence is HIGH → repair is attempted normally.
//
// Fallback messages are system-defined and clinically safe.
// They are written to persistent local storage in place of the raw fragment.
//
// Parameter naming: [TimeoutContentSafetyGuard.evaluate] uses `truncation:`
// (canonical, spec-aligned name — replaces legacy `truncResult:` in-provider).
// ══════════════════════════════════════════════════════════════════════════════

import '../ai_stream/truncation_inspector.dart'
    show TruncationCheckResult, TruncationConfidence;

// ── TerminalCause ─────────────────────────────────────────────────────────────
/// All recognised terminal signals that can end an AI pipeline run.
///
/// Each variant corresponds to the source event that caused the pipeline to
/// stop collecting chunks and transition to the finalisation phase.
///
/// Moved here from app_provider.dart in MICRO-BUILD 462E-A.5.3.7.2.1 so that
/// [TimeoutContentSafetyGuard.evaluate] can accept it without a circular import.
enum TerminalCause {
  streamDone,            // onDone fired normally
  chunkIsDone,           // chunk.isDone flag inside the stream
  timeout,               // deadline timer fired
  error,                 // onError fired
  cancelled,             // user or system cancellation
  fallback,              // provider fallback path
  streamProcessingError, // exception inside SerialEventQueue processStreamEvent
}

// ── TimeoutSafetyVerdict ──────────────────────────────────────────────────────
/// Result of [TimeoutContentSafetyGuard.evaluate].
///
/// Returned to the finalization pipeline to determine the disposition of the
/// raw AI output after a terminal signal is received.
enum TimeoutSafetyVerdict {
  /// Output is safe to persist as-is.
  proceedAsIs,

  /// Output is truncated with high confidence — run repair loop.
  proceedWithRepair,

  /// Discard raw fragment — write operational fallback to storage.
  useOperationalFallback,
}

// ── TimeoutContentSafetyGuard ─────────────────────────────────────────────────
/// Canonical, production-importable domain class for timeout content safety.
///
/// All-static, zero-state guard that evaluates whether a timeout-triggered
/// finalization should discard the raw snapshot and substitute the operational
/// fallback, attempt a repair, or proceed normally.
///
/// MICRO-BUILD 462E-A.5.3.7.2 — TimeoutContentSafetyGuard
///
/// Enforces content-safety when finalizeAiRequest() is triggered with
/// [TerminalCause.timeout].
///
/// Import this file in any layer that needs to evaluate [TimeoutSafetyVerdict]:
/// ```dart
/// import 'package:medcases/services/ai/timeout_content_safety_guard.dart';
/// ```
abstract final class TimeoutContentSafetyGuard {
  TimeoutContentSafetyGuard._();

  // ── Clinically-safe fallback messages ────────────────────────────────────

  /// System-defined operational fallback for PT-BR (timeout path).
  static const String kOperationalFallbackPt =
      '[Aviso Operacional] A resposta foi interrompida devido a um timeout de rede. '
      'Para sua segurança e precisão clínica, por favor realize a pergunta novamente.';

  /// System-defined operational fallback for ES (timeout path).
  static const String kOperationalFallbackEs =
      '[Aviso Operacional] La respuesta fue interrumpida debido a un timeout de red. '
      'Para su seguridad y precisión clínica, por favor realice la pregunta nuevamente.';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the language-appropriate operational fallback message.
  ///
  /// [lang] — BCP-47 primary language subtag. `'es'` → Spanish; all other
  /// values (including `'pt'`) → Portuguese fallback.
  static String fallback(String lang) =>
      lang == 'es' ? kOperationalFallbackEs : kOperationalFallbackPt;

  /// Evaluates whether a timeout-triggered finalization should discard the
  /// raw snapshot and substitute the operational fallback.
  ///
  /// **Decision table:**
  ///
  /// | cause      | isTruncated | confidence | verdict               |
  /// |------------|-------------|------------|-----------------------|
  /// | non-timeout| false       | any        | proceedAsIs           |
  /// | non-timeout| true        | any        | proceedWithRepair     |
  /// | timeout    | false       | any        | proceedAsIs           |
  /// | timeout    | true        | high       | proceedWithRepair     |
  /// | timeout    | true        | low/medium | useOperationalFallback|
  ///
  /// Returns [TimeoutSafetyVerdict.useOperationalFallback] when:
  ///   - cause is [TerminalCause.timeout] AND
  ///   - [TruncationCheckResult.isTruncated] is true AND
  ///   - confidence is NOT [TruncationConfidence.high] (cannot be safely repaired).
  ///
  /// Returns [TimeoutSafetyVerdict.proceedWithRepair] when the output is
  /// truncated with HIGH confidence — the repair loop should run normally.
  ///
  /// Returns [TimeoutSafetyVerdict.proceedAsIs] when the output is NOT
  /// truncated — safe to persist.
  static TimeoutSafetyVerdict evaluate({
    required TerminalCause cause,
    required TruncationCheckResult truncation,
  }) {
    if (cause != TerminalCause.timeout) {
      // Non-timeout path: respect the standard truncation pipeline.
      return truncation.isTruncated
          ? TimeoutSafetyVerdict.proceedWithRepair
          : TimeoutSafetyVerdict.proceedAsIs;
    }
    // Timeout path: apply content-safety enforcement.
    if (!truncation.isTruncated) {
      return TimeoutSafetyVerdict.proceedAsIs;
    }
    if (truncation.confidenceLevel == TruncationConfidence.high) {
      // Truncated + high confidence → repair may succeed.
      return TimeoutSafetyVerdict.proceedWithRepair;
    }
    // Truncated + low/medium confidence on timeout → discard raw fragment.
    // ignore: avoid_print
    print('[TIMEOUT_CONTENT_SAFETY] DISCARD_RAW_FRAGMENT '
        'isTruncated=${truncation.isTruncated} '
        'confidence=${truncation.confidenceLevel.name} '
        'reason=low_repair_confidence_on_timeout → operational_fallback');
    return TimeoutSafetyVerdict.useOperationalFallback;
  }
}
