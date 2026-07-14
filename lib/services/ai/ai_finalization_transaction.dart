// lib/services/ai/ai_finalization_transaction.dart
// MICRO-BUILD 462E-A.5.3.7.3.2 — Extracted from lib/providers/app_provider.dart
//
// Canonical home for the AiFinalizationTransaction per-request state machine
// and its supporting types. Extracted so that tests can import real production
// classes without mirrors, and so the UI cannot reach these types directly.
//
// Imports consumed by tests via:
//   import 'package:medcases/services/ai/ai_finalization_transaction.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../external_tool_link_engine.dart'; // for releaseCanonicalDecision
import 'timeout_content_safety_guard.dart' show TerminalCause;

// ── ActiveAiSessionContext ────────────────────────────────────────────────────
/// MICRO-BUILD 462E-A.5.3.7.3.2.3 [PILLAR 1]: Immutable, request-scoped
/// session context instantiated at the START of sendAiMessage().
///
/// Carries all identity fields needed for atomic persistence (Step B) without
/// requiring any mutable state lookup mid-pipeline. Once created, every field
/// is guaranteed non-null and immutable throughout the full pipeline execution.
///
/// MICRO-BUILD 462E-A.5.3.7.3.2.5 [PILLAR 2]: locale added for schema v2
/// compliance. sessionId is now a stable conversation-lifetime identifier,
/// decoupled from requestId (which is unique per message exchange).
///
/// Invariants:
///   • Created exactly once per sendAiMessage() call, before any async work.
///   • uid and sessionId are captured at request-start — never lazily resolved.
///   • sessionId is stable across all turns of the same conversation.
///   • requestId matches AppProvider's thisRequestId (1:1 correlation per turn).
///   • mode is 'estudo' | 'plantao' — derived from longResponse flag.
///   • locale is 'pt' | 'es' — the app language at request time.
///   • createdAt is the wall-clock instant of sendAiMessage() invocation.
final class ActiveAiSessionContext {
  final String uid;
  final String sessionId;
  final String requestId;
  final String mode;
  final String locale;
  final DateTime createdAt;

  const ActiveAiSessionContext({
    required this.uid,
    required this.sessionId,
    required this.requestId,
    required this.mode,
    required this.locale,
    required this.createdAt,
  });
}

// ── SessionPersistStatus ──────────────────────────────────────────────────────
/// MICRO-BUILD 462E-A.5.3.7.3.2.3 [PILLAR 2]: Typed result of an atomic
/// AI exchange persistence attempt.
///
/// MICRO-BUILD 462E-A.5.3.7.3.2.5.1 [PILLAR 2]: Added [SessionPersistAuthDenied]
/// to strictly isolate Firestore permission-denied rejections from network
/// failures. CRITICAL: permission-denied MUST NOT enter the offline queue —
/// it is a security architecture lock, not a transient network drop.
///
/// Returned by [AppProvider.persistAiExchangeOnce()] — never raw exceptions.
/// The calling finalizer inspects the variant to log and continue (never block
/// UI on offline failures).
///
/// Variants:
///   • [SessionPersistSynced]        — write committed to Firestore/local store.
///   • [SessionPersistQueuedOffline] — device offline; write queued locally.
///   • [SessionPersistSkipped]       — idempotency key already seen; no-op.
///   • [SessionPersistAuthDenied]    — Firestore permission-denied; security lock.
///                                     NEVER queued offline. Carries path context.
///   • [SessionPersistFailed]        — unrecoverable error (logged, not thrown).
sealed class SessionPersistStatus {
  const SessionPersistStatus();
}

/// Firestore write committed and acknowledged.
final class SessionPersistSynced extends SessionPersistStatus {
  const SessionPersistSynced();
}

/// Device is offline; write queued in local persistence layer.
final class SessionPersistQueuedOffline extends SessionPersistStatus {
  const SessionPersistQueuedOffline();
}

/// Idempotency key already present — this requestId was already persisted.
final class SessionPersistSkipped extends SessionPersistStatus {
  final String reason;
  const SessionPersistSkipped(this.reason);
}

/// MICRO-BUILD 462E-A.5.3.7.3.2.5.1 [PILLAR 2]: Firestore returned
/// permission-denied — this is a SECURITY ARCHITECTURE LOCK, not a network
/// failure. The write is permanently rejected. MUST NOT be placed in any
/// offline pending queue. Carries the parent path and exchange path for
/// production telemetry emission.
///
/// Telemetry tag: [SESSION_PERSIST][AUTH_DENIED]
final class SessionPersistAuthDenied extends SessionPersistStatus {
  /// The parent session document path: users/{uid}/ai_sessions/{sessionId}
  final String parentPath;
  /// The exchange document path: …/exchanges/{requestId}
  final String exchangePath;
  const SessionPersistAuthDenied({
    required this.parentPath,
    required this.exchangePath,
  });
}

/// Persistence failed with an unrecoverable error. Pipeline continues.
final class SessionPersistFailed extends SessionPersistStatus {
  final Object error;
  const SessionPersistFailed(this.error);
}

// ── CompletedToolResolution ───────────────────────────────────────────────────
/// Immutable, request-scoped result of the External Tool Gate evaluation.
///
/// MICRO-BUILD 462E-A.5.3.7.3.2.1 — Payload container replacing the bare
/// ExternalToolLink? field. Stored in AppProvider._completedResolutions keyed
/// by requestId so the UI can assert identity before rendering a tool card.
///
/// Invariants:
///   • Created exactly once per request by the canonical finalizer.
///   • isAllowed=true only on the happy path (stream complete + tool intent).
///   • isAllowed=false on all abrupt paths (timeout, error, cancel).
///   • The UI MUST verify completedToolResolution.requestId == activeRequestId
///     before rendering any tool calculator. Mismatches = no render.
final class CompletedToolResolution {
  final String requestId;
  final String parentRequestId;
  final String transactionId;
  final ExternalToolLink? link;
  final String reason;
  final bool isAllowed;

  const CompletedToolResolution({
    required this.requestId,
    required this.parentRequestId,
    required this.transactionId,
    this.link,
    required this.reason,
    required this.isAllowed,
  });
}

// ── AiTransactionPhase ────────────────────────────────────────────────────────
enum AiTransactionPhase {
  ingesting,   // stream is open — chunks are accepted and queued
  finalizing,  // terminal signal won — queue is being drained, no new chunks
  completed,   // finalization succeeded
  cancelled,   // request was cancelled before completion
}

// ── TerminalSignal ────────────────────────────────────────────────────────────
/// Immutable value submitted by any terminal contender to the Broker.
/// Only the FIRST submission wins; all subsequent are rejected.
final class TerminalSignal {
  final String source;
  final TerminalCause cause;
  final Object? error;
  final StackTrace? stackTrace;

  const TerminalSignal({
    required this.source,
    required this.cause,
    this.error,
    this.stackTrace,
  });

  factory TerminalSignal.streamDone(String source) =>
      TerminalSignal(source: source, cause: TerminalCause.streamDone);

  factory TerminalSignal.chunkIsDone(String source) =>
      TerminalSignal(source: source, cause: TerminalCause.chunkIsDone);

  factory TerminalSignal.timeout(String source) =>
      TerminalSignal(source: source, cause: TerminalCause.timeout);

  factory TerminalSignal.error(String source, Object err, StackTrace st) =>
      TerminalSignal(source: source, cause: TerminalCause.error, error: err, stackTrace: st);

  factory TerminalSignal.cancelled(String source) =>
      TerminalSignal(source: source, cause: TerminalCause.cancelled);

  factory TerminalSignal.fallback(String source) =>
      TerminalSignal(source: source, cause: TerminalCause.fallback);

  factory TerminalSignal.streamProcessingError(Object err, StackTrace st) =>
      TerminalSignal(
        source: 'serial_event_queue',
        cause: TerminalCause.streamProcessingError,
        error: err,
        stackTrace: st,
      );
}

// ── ProviderAttemptContext ────────────────────────────────────────────────────
/// Immutable, per-attempt context. A retry or paid fallback creates a NEW
/// instance but preserves the reference to the original transaction.
/// Late chunks from a stale generation are rejected via [isStale].
final class ProviderAttemptContext {
  final String providerRequestId;
  final int attemptGeneration;
  final String provider;

  const ProviderAttemptContext({
    required this.providerRequestId,
    required this.attemptGeneration,
    required this.provider,
  });

  /// Returns true when [activeGeneration] is newer than this attempt —
  /// meaning this attempt is stale and its events must be dropped.
  bool isStale(int activeGeneration) => attemptGeneration < activeGeneration;
}

// ── FinalOutputSnapshot ───────────────────────────────────────────────────────
/// Immutable snapshot frozen AFTER the SerialEventQueue is fully drained.
/// NEVER created before queue drainage.
final class FinalOutputSnapshot {
  final String rawOutput;
  final String sessionId;
  final String parentRequestId;
  final DateTime frozenAt;

  const FinalOutputSnapshot({
    required this.rawOutput,
    required this.sessionId,
    required this.parentRequestId,
    required this.frozenAt,
  });
}

// ── SerialEventQueue ──────────────────────────────────────────────────────────
/// Non-reentrant serial Future chain for incoming stream chunks.
///
/// The finalizing-phase barrier check executes at ENQUEUE TIME (cutoff),
/// not inside downstream buffer mutations. Chunks enqueued while [ingesting]
/// are fully processed even if the phase transitions to [finalizing] before
/// their execution begins. Chunks arriving after the phase transition are
/// rejected instantly.
class SerialEventQueue {
  final AiFinalizationTransaction transaction;
  final void Function(TerminalSignal) signalTerminal;
  final Future<void> Function(Object event) processStreamEvent;

  Future<void> _queue = Future.value();

  SerialEventQueue({
    required this.transaction,
    required this.signalTerminal,
    required this.processStreamEvent,
  });

  /// Enqueues [event] for serial processing.
  /// Returns false and emits [AI_LATE_EVENT_DROPPED] if the cutoff has passed.
  bool enqueue(Object event) {
    if (transaction.phase != AiTransactionPhase.ingesting) {
      // ignore: avoid_print
      print('[AI_LATE_EVENT_DROPPED] '
          'parentRequestId=${transaction.parentRequestId} '
          'event=chunk '
          'reason=phase_cutoff '
          'phase=${transaction.phase.name}');
      return false;
    }

    _queue = _queue.then((_) => processStreamEvent(event)).catchError(
      (Object err, StackTrace stack) {
        signalTerminal(TerminalSignal.streamProcessingError(err, stack));
      },
    );

    return true;
  }

  /// Awaits full drainage of the serial queue before returning.
  /// Must be called by the terminal broker AFTER winning ownership and
  /// transitioning to [finalizing], and BEFORE [FinalOutputSnapshot] is frozen.
  Future<void> drain() => _queue;
}

// ══════════════════════════════════════════════════════════════════════════════
// MICRO-BUILD 462E-A.5.3.7.1 — AiFinalizationTransaction (upgraded)
//
// Per-request state machine that enforces EXACTLY ONE terminal ownership claim
// across all asynchronous finalization contenders (onDone, timeout timer,
// onError, chunk.isDone, cancel, fallback paths).
//
// INVARIANT: tryAcquireOwnership() is non-reentrant. The first caller wins and
// receives true; all subsequent callers receive false and must emit
// [AI_TERMINAL_OWNER][REJECTED] telemetry before silently aborting.
//
// Multiple concurrent active requests each own an INDEPENDENT instance.
// Completing request A NEVER affects the transaction state of request B.
//
// Dart event-loop thread safety: bool flips are atomic within a single
// microtask — no additional locking is required.
// ══════════════════════════════════════════════════════════════════════════════
class AiFinalizationTransaction {
  final String parentRequestId;
  // providerRequestId is now per-attempt (ProviderAttemptContext).
  // Kept here for legacy call sites that reference it directly.
  final String providerRequestId;

  // ── Correlated telemetry identities ────────────────────────────────────────
  // MICRO-BUILD 462E-A.5.3.7.3.1: Immutable per-request identities for
  // structured [EXT_TOOL_GATE] and [AI_LATE_BUSINESS_EVENT_DROPPED] telemetry.
  //
  // transactionId — generated exactly once per parent request lifetime.
  //   Derived from parentRequestId; stable across retries and fallbacks.
  //   Format: "txn_<first16chars_of_parentRequestId>"
  //
  // attemptId — bound to the providerRequestId supplied at construction.
  //   Each retry or fallback creates a fresh AiFinalizationTransaction with a
  //   new providerRequestId, producing a distinct attemptId while sharing the
  //   same transactionId (same parentRequestId).
  //   Format: "att_<first12chars_of_providerRequestId>"
  late final String transactionId;
  late final String attemptId;

  // ── Phase state machine ────────────────────────────────────────────────────
  AiTransactionPhase _phase = AiTransactionPhase.ingesting;
  AiTransactionPhase get phase => _phase;

  // ── Ownership & atomic guards ──────────────────────────────────────────────
  bool _ownershipAcquired           = false;
  bool _toolResolutionStarted       = false;
  bool _toolResolutionCompleted     = false;
  bool _cacheReleased               = false;
  bool _coordinatorCompleted        = false;
  bool _assistantPersisted          = false;
  bool _canonicalDecisionReleased   = false;

  // ── @visibleForTesting telemetry capture ──────────────────────────────────
  // These lists are populated by the methods below and exist solely to allow
  // unit tests to assert on behavioral invariants without network/Firebase.
  // They are never read or written by production paths outside of tests.
  @visibleForTesting
  final List<String> rejectedContenders = [];

  @visibleForTesting
  final List<String> droppedBusinessEvents = [];

  @visibleForTesting
  final List<String> extToolGateLogs = [];

  // ── Terminal Signal Broker ─────────────────────────────────────────────────
  // Exactly ONE outer orchestrator awaits this Completer.
  // Every terminal contender calls signalTerminal() — only the first wins.
  final Completer<TerminalSignal> _terminalSignal = Completer<TerminalSignal>();

  AiFinalizationTransaction({
    required this.parentRequestId,
    required this.providerRequestId,
  }) {
    // Derive stable identities from the immutable IDs at construction time.
    // Slicing keeps log lines short while retaining sufficient uniqueness.
    final pLen = parentRequestId.length;
    final rLen = providerRequestId.length;
    transactionId = 'txn_${parentRequestId.substring(0, pLen > 16 ? 16 : pLen)}';
    attemptId     = 'att_${providerRequestId.isEmpty ? "none" : providerRequestId.substring(0, rLen > 12 ? 12 : rLen)}';
  }

  // ── Terminal Signal Broker API ─────────────────────────────────────────────

  /// Submits [signal] to the broker. Only the first call wins; subsequent
  /// calls log [AI_TERMINAL_CONTENDER_REJECTED] and are silently dropped.
  void signalTerminal(TerminalSignal signal) {
    if (!_terminalSignal.isCompleted) {
      _terminalSignal.complete(signal);
    } else {
      rejectedContenders.add(signal.source);
      emitTerminalContenderRejected(signal.source);
    }
  }

  /// Awaited by the single outer orchestrator to receive the winning signal.
  Future<TerminalSignal> get terminalFuture => _terminalSignal.future;

  void emitTerminalContenderRejected(String source) {
    // ignore: avoid_print
    print('[AI_TERMINAL_CONTENDER_REJECTED] '
        'parentRequestId=$parentRequestId '
        'source=$source '
        'reason=broker_already_resolved');
  }

  // ── Phase transitions ──────────────────────────────────────────────────────

  /// Transitions to [finalizing]. Called by the winning terminal signal owner
  /// before draining the queue. Chunks arriving after this call are rejected.
  void transitionToFinalizing() {
    if (_phase == AiTransactionPhase.ingesting) {
      _phase = AiTransactionPhase.finalizing;
    }
  }

  // ── sealAndDrainStreamQueue ────────────────────────────────────────────────

  /// Seals the phase to [finalizing] and drains [queue] before returning.
  /// The [FinalOutputSnapshot] MUST NOT be frozen before this completes.
  Future<void> sealAndDrainStreamQueue(SerialEventQueue queue) async {
    transitionToFinalizing();
    await queue.drain();
  }

  // ── Ownership ──────────────────────────────────────────────────────────────

  /// Atomically claims terminal ownership for [source].
  /// Returns true when the caller is the WINNER.
  /// Returns false with [AI_TERMINAL_OWNER][REJECTED] telemetry for all losers.
  bool tryAcquireOwnership(String source) {
    if (_ownershipAcquired) {
      // ignore: avoid_print
      print('[AI_TERMINAL_OWNER][REJECTED] '
          'parentRequestId=$parentRequestId '
          'providerRequestId=$providerRequestId '
          'source=$source '
          'reason=ownership_already_acquired');
      return false;
    }
    _ownershipAcquired = true;
    // ignore: avoid_print
    print('[AI_TERMINAL_OWNER][ACQUIRED] '
        'parentRequestId=$parentRequestId '
        'source=$source');
    return true;
  }

  // ── Atomic once-guards ─────────────────────────────────────────────────────

  /// Returns true on the FIRST call — the caller owns assistant persistence.
  bool tryMarkAssistantPersisted() {
    if (_assistantPersisted) return false;
    _assistantPersisted = true;
    return true;
  }

  /// Returns true on the FIRST call — the caller owns tool resolution.
  bool tryMarkToolResolutionStarted() {
    if (_toolResolutionStarted) return false;
    _toolResolutionStarted = true;
    return true;
  }

  /// @visibleForTesting — Wraps [tryMarkToolResolutionStarted] with a
  /// structured [EXT_TOOL_GATE] log emission and captures it in
  /// [extToolGateLogs] for invariant assertions.
  ///
  /// MICRO-BUILD 462E-A.5.3.7.3.1 [PILLAR 2]: Returns true when gate is
  /// allowed (first call); false on all subsequent calls.
  @visibleForTesting
  bool tryMarkToolResolutionStartedWithGate({String callSite = 'canonical_finalizer'}) {
    final bool allowed = tryMarkToolResolutionStarted();
    final msg = '[EXT_TOOL_GATE] '
        'requestId=$parentRequestId '
        'parentRequestId=$parentRequestId '
        'transactionId=$transactionId '
        'attemptId=$attemptId '
        'phase=${_phase.name} '
        'callSite=$callSite '
        'allowed=$allowed '
        'reason=${allowed ? "first_resolution" : "duplicate_dropped"}';
    // ignore: avoid_print
    print(msg);
    extToolGateLogs.add(msg);
    return allowed;
  }

  /// Releases the canonical decision exactly once.
  /// Subsequent calls are silently ignored.
  Future<void> releaseCanonicalDecisionOnce() async {
    if (_canonicalDecisionReleased) return;
    _canonicalDecisionReleased = true;
    ExternalToolLinkEngine.releaseCanonicalDecision(requestId: parentRequestId);
  }

  // ── completeCoordinatorAtomically ─────────────────────────────────────────

  /// Completes the coordinator synchronously (no intermediate awaits).
  /// Prevents concurrent callback interleaving inside the finally block.
  /// The [complete] callback is invoked exactly once.
  void completeCoordinatorAtomically({
    required TerminalCause cause,
    required void Function() complete,
  }) {
    if (_coordinatorCompleted) return;
    complete();
    _coordinatorCompleted = true;
    _phase = cause == TerminalCause.cancelled
        ? AiTransactionPhase.cancelled
        : AiTransactionPhase.completed;
  }

  // ── tryMarkCoordinatorCompleted ────────────────────────────────────────────

  /// MICRO-BUILD 462E-A.5.3.7.3.2.2 [PILLAR 2]: Atomic latch for coordinator
  /// double-trigger protection.
  ///
  /// Returns true on the FIRST call — the caller is authorised to invoke
  /// AppResumeCoordinator.instance.completeAiRequest().
  ///
  /// Returns false on all subsequent calls — the caller MUST NOT invoke
  /// completeAiRequest() and MUST emit [RESUME_COORDINATOR][DUPLICATE_DROPPED].
  ///
  /// Invariants:
  ///   • Exactly one caller receives true per transaction lifetime.
  ///   • The phase is advanced to [completed] on the winning call.
  ///   • All subsequent callers receive false; transaction state is unchanged.
  ///   • Thread-safe within Dart's single-threaded event loop.
  bool tryMarkCoordinatorCompleted() {
    if (_coordinatorCompleted) return false;
    _coordinatorCompleted = true;
    if (_phase == AiTransactionPhase.ingesting ||
        _phase == AiTransactionPhase.finalizing) {
      _phase = AiTransactionPhase.completed;
    }
    return true;
  }

  // ── Telemetry helpers ──────────────────────────────────────────────────────

  void markToolResolutionCompleted() => _toolResolutionCompleted = true;
  void markCacheReleased()           => _cacheReleased = true;
  void markCoordinatorCompleted()    => _coordinatorCompleted = true;
  void markAssistantPersisted()      => _assistantPersisted = true;

  bool get isTerminal           => _coordinatorCompleted;
  bool get ownershipAcquired    => _ownershipAcquired;
  bool get assistantPersisted   => _assistantPersisted;
  bool get cacheReleased        => _cacheReleased;
  bool get coordinatorCompleted => _coordinatorCompleted;

  /// Emits [AI_LATE_EVENT_DROPPED] telemetry and returns true when the
  /// transaction is already terminal and a late event must be discarded.
  bool dropIfTerminal({required String event, required String providerReqId}) {
    if (!_coordinatorCompleted) return false;
    // ignore: avoid_print
    print('[AI_LATE_EVENT_DROPPED] '
        'parentRequestId=$parentRequestId '
        'providerRequestId=$providerReqId '
        'event=$event '
        'terminalState=completed');
    return true;
  }

  /// Hard, synchronous post-completion barrier for business-level events.
  ///
  /// MICRO-BUILD 462E-A.5.3.7.3.1 — PILLAR 1:
  /// Returns true and emits [AI_LATE_BUSINESS_EVENT_DROPPED] when the
  /// transaction is already terminal (coordinator completed, or phase is
  /// completed/cancelled). Returns false when the transaction is still active —
  /// the caller may proceed with business logic.
  ///
  /// Invariants (enforced by the correlated log):
  ///   • Zero state changes on true return.
  ///   • Zero storage persist triggers on true return.
  ///   • Zero coordinator re-completions on true return.
  ///   • Every field in the log is immutable and set at construction time.
  bool dropIfBusinessEventTerminal({required String callSite}) {
    final bool isTerminalPhase =
        _phase == AiTransactionPhase.completed ||
        _phase == AiTransactionPhase.cancelled;
    if (!_coordinatorCompleted && !isTerminalPhase) return false;
    final String phaseName = _phase == AiTransactionPhase.cancelled
        ? 'cancelled'
        : 'completed';
    // ignore: avoid_print
    print('[AI_LATE_BUSINESS_EVENT_DROPPED] '
        'requestId=$parentRequestId '
        'parentRequestId=$parentRequestId '
        'transactionId=$transactionId '
        'attemptId=$attemptId '
        'callSite=$callSite '
        'phase=$phaseName');
    droppedBusinessEvents.add(callSite);
    return true;
  }

  /// Emits [AI_LATE_EVENT_DROPPED] for stale provider attempt chunks.
  void emitLateEventDropped({required String event}) {
    // ignore: avoid_print
    print('[AI_LATE_EVENT_DROPPED] '
        'parentRequestId=$parentRequestId '
        'providerRequestId=$providerRequestId '
        'reason=stale_provider_attempt '
        'event=$event');
  }

  /// Emits finalization failure telemetry.
  void emitFinalizationFailure({required Object error, required StackTrace stackTrace}) {
    // ignore: avoid_print
    print('[AI_FINALIZATION_FAILURE] '
        'parentRequestId=$parentRequestId '
        'error=$error');
  }

  /// Emits [SESSION_PERSIST] dedup key telemetry.
  void emitPersistTelemetry({required String sessionId}) {
    final dedupKey = '$parentRequestId:assistant_final';
    // ignore: avoid_print
    print('[SESSION_PERSIST] '
        'parentRequestId=$parentRequestId '
        'sessionId=$sessionId '
        'messageRole=assistant '
        'phase=assistant_final '
        'dedupKey=$dedupKey');
    markAssistantPersisted();
  }
}
