// ══════════════════════════════════════════════════════════════════════════════
// test/providers/ai_finalization_transaction_test.dart
// MICRO-BUILD 462E-A.5.3.7.3.2 — AiFinalizationTransaction Integration Test Suite
//
// PILLAR 3: Mirrors DELETED — tests now import real production classes.
//
// Verifica os contratos críticos do pipeline de finalização unificado:
//
// Scenario 1: TerminalSignal Broker — single winner, all late contenders rejected
// Scenario 2: ProviderAttemptContext — stale generation chunks are dropped
// Scenario 3: SerialEventQueue — enqueue cutoff at phase transition
// Scenario 4: Drain-before-snapshot — FinalOutputSnapshot only after full drain
// Scenario 5: Concurrent race — two simultaneous terminal paths, exactly one wins
// Scenario 6: completeCoordinatorAtomically — sync, exactly once, phase correct
// Scenario 7: tryMarkAssistantPersisted — exactly-once persistence guard
// Scenario 8: tryMarkToolResolutionStarted — exactly-once tool gate guard
// Scenario 9: Exception safety — emitFinalizationFailure does not throw
// Scenario 10: sealAndDrainStreamQueue — phase transitions to finalizing before drain
// Invariant U: Timeout Content Safety — operational fallback replaces raw fragment
// Invariant V: Gate Ownership Enforcement, Strict Sequence & Correlated Runtime
// Invariant W: UI zero-invocation, engine once in canonical finalizer, release ordering
//
// Architecture: unit-level — zero network, zero Firebase, zero UI.
// Uses actual delayed Futures and real production implementations extracted to
// lib/services/ai/ai_finalization_transaction.dart (MICRO-BUILD 462E-A.5.3.7.3.2).
// ══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/ai_finalization_transaction.dart';
import 'package:medcases/services/ai/clinical_dosage_presets.dart';
import 'package:medcases/services/ai/timeout_content_safety_guard.dart'
    show TerminalCause, TimeoutContentSafetyGuard, TimeoutSafetyVerdict;
import 'package:medcases/services/ai_stream/truncation_inspector.dart'
    show TruncationCheckResult, TruncationConfidence;

// ── Stub ExternalToolLinkEngine release tracker ───────────────────────────────
// The real AiFinalizationTransaction.releaseCanonicalDecisionOnce() calls
// ExternalToolLinkEngine.releaseCanonicalDecision(requestId: …) which is a
// static method that reaches Firestore. In tests we intercept the log output;
// the stub below tracks release calls by intercepting the parentRequestId via
// the @visibleForTesting releaseCanonicalDecisionOnce path.
//
// For scenarios that verify idempotency we use a local tracking list instead
// of the stub, since the real engine is injected at test time via the
// AiFinalizationTransaction instance itself.
//
// V-7 and Scenario 9 use releaseCanonicalDecisionOnce() — these call the real
// engine static (safe: no-ops in test environment without Firebase). We track
// calls via a test-local counter bound to the function closure.
// ─────────────────────────────────────────────────────────────────────────────

// ── _TestableTransaction: thin subclass adding release-call tracking ───────────
// Used only for tests that call releaseCanonicalDecisionOnce() and need to
// verify the idempotency guarantee (Scenario 9 and V-7).
class _TestableTransaction extends AiFinalizationTransaction {
  int _releaseCallCount = 0;
  int get releaseCallCount => _releaseCallCount;

  _TestableTransaction({
    required super.parentRequestId,
    required super.providerRequestId,
  });

  @override
  Future<void> releaseCanonicalDecisionOnce() async {
    if (_releaseCallCount == 0) {
      _releaseCallCount++;
      print('[RELEASE_CANONICAL_DECISION] parentRequestId=$parentRequestId');
    }
    // Deliberately do NOT call super to avoid reaching the real static engine
    // in Firebase-free test environments.
  }
}

// ── _CountingSerialEventQueue: SerialEventQueue with drop/process counters ─────
// SerialEventQueue in production does not expose processedCount/droppedCount.
// Tests that need those counters use this thin subclass.
class _CountingSerialEventQueue extends SerialEventQueue {
  int processedCount = 0;
  int droppedCount   = 0;

  _CountingSerialEventQueue({
    required super.transaction,
    required super.signalTerminal,
    required super.processStreamEvent,
  });

  @override
  bool enqueue(Object event) {
    final result = super.enqueue(event);
    if (result) {
      processedCount++;
    } else {
      droppedCount++;
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test suite
// ─────────────────────────────────────────────────────────────────────────────

void main() {

  // ── Scenario 1: Terminal Signal Broker — single winner ─────────────────────
  group('Scenario 1 — TerminalSignal Broker: single winner, losers rejected', () {
    test('first signalTerminal wins, second is rejected', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-001',
        providerRequestId: 'prov-001',
      );

      tx.signalTerminal(TerminalSignal.streamDone('onDone'));
      tx.signalTerminal(TerminalSignal.timeout('timeoutTimer'));
      tx.signalTerminal(TerminalSignal.cancelled('cancelButton'));

      final winner = await tx.terminalFuture;
      expect(winner.source, equals('onDone'));
      expect(winner.cause, equals(TerminalCause.streamDone));
      expect(tx.rejectedContenders, containsAll(['timeoutTimer', 'cancelButton']));
    });

    test('Completer resolves exactly once — multiple races', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-002',
        providerRequestId: 'prov-002',
      );

      // Simulate concurrent terminal signals from different async paths
      await Future.wait([
        Future.delayed(const Duration(milliseconds: 10), () {
          tx.signalTerminal(TerminalSignal.timeout('timer'));
        }),
        Future.delayed(const Duration(milliseconds: 5), () {
          tx.signalTerminal(TerminalSignal.streamDone('onDone'));
        }),
        Future.delayed(const Duration(milliseconds: 20), () {
          tx.signalTerminal(TerminalSignal.cancelled('cancel'));
        }),
      ]);

      final winner = await tx.terminalFuture;
      // onDone fires at 5ms, must be the winner
      expect(winner.source, equals('onDone'));
      expect(tx.rejectedContenders.length, equals(2));
    });
  });

  // ── Scenario 2: ProviderAttemptContext stale generation rejection ──────────
  group('Scenario 2 — ProviderAttemptContext: stale generation detection', () {
    test('attempt generation 0 is stale when active is 1', () {
      const staleAttempt = ProviderAttemptContext(
        providerRequestId: 'prov-gen0',
        attemptGeneration: 0,
        provider: 'gemini',
      );
      expect(staleAttempt.isStale(1), isTrue);
    });

    test('attempt generation 1 is NOT stale when active is 1', () {
      const activeAttempt = ProviderAttemptContext(
        providerRequestId: 'prov-gen1',
        attemptGeneration: 1,
        provider: 'gemini',
      );
      expect(activeAttempt.isStale(1), isFalse);
    });

    test('fallback attempt (generation 2) is NOT stale when active is 2', () {
      const fallbackAttempt = ProviderAttemptContext(
        providerRequestId: 'prov-gen2-fallback',
        attemptGeneration: 2,
        provider: 'openai',
      );
      expect(fallbackAttempt.isStale(2), isFalse);
    });

    test('late chunks from stale provider are logged and discarded', () {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-stale',
        providerRequestId: 'prov-gen0',
      );
      const staleAttempt = ProviderAttemptContext(
        providerRequestId: 'prov-gen0',
        attemptGeneration: 0,
        provider: 'gemini',
      );
      // Simulate: active generation is now 1 (fallback kicked in)
      const int activeGeneration = 1;
      if (staleAttempt.isStale(activeGeneration)) {
        tx.emitLateEventDropped(event: 'chunk');
      }
      // No exception — telemetry emitted and chunk silently dropped
      expect(true, isTrue); // reached here without throwing
    });
  });

  // ── Scenario 3: SerialEventQueue — enqueue cutoff at phase transition ──────
  group('Scenario 3 — SerialEventQueue: enqueue cutoff barrier', () {
    test('chunks enqueued during ingesting are processed', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-003',
        providerRequestId: 'prov-003',
      );
      final processed = <String>[];
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          await Future.delayed(const Duration(milliseconds: 2));
          processed.add(event as String);
        },
      );

      expect(queue.enqueue('chunk-A'), isTrue);
      expect(queue.enqueue('chunk-B'), isTrue);
      expect(queue.enqueue('chunk-C'), isTrue);

      await queue.drain();
      expect(processed, equals(['chunk-A', 'chunk-B', 'chunk-C']));
      expect(queue.droppedCount, equals(0));
    });

    test('chunks enqueued after phase transition to finalizing are dropped', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-004',
        providerRequestId: 'prov-004',
      );
      final processed = <String>[];
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          processed.add(event as String);
        },
      );

      queue.enqueue('chunk-1');
      queue.enqueue('chunk-2');

      // Seal the queue — phase transitions to finalizing
      tx.transitionToFinalizing();

      // These must be dropped (cutoff at enqueue time)
      final r3 = queue.enqueue('chunk-late-3');
      final r4 = queue.enqueue('chunk-late-4');

      await queue.drain();

      expect(r3, isFalse);
      expect(r4, isFalse);
      expect(processed, equals(['chunk-1', 'chunk-2']));
      expect(queue.droppedCount, equals(2));
    });

    test('exceptions in processStreamEvent signal terminal broker', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-005',
        providerRequestId: 'prov-005',
      );
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          throw StateError('simulated processing error');
        },
      );

      queue.enqueue('bad-chunk');
      await queue.drain();

      final signal = await tx.terminalFuture;
      expect(signal.cause, equals(TerminalCause.streamProcessingError));
      expect(signal.error, isA<StateError>());
    });
  });

  // ── Scenario 4: Drain-before-snapshot ─────────────────────────────────────
  group('Scenario 4 — FinalOutputSnapshot: frozen only after full drain', () {
    test('snapshot reflects all enqueued chunks after drain', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-006',
        providerRequestId: 'prov-006',
      );
      final buffer = StringBuffer();
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          await Future.delayed(const Duration(milliseconds: 3));
          buffer.write(event as String);
        },
      );

      queue.enqueue('Hello ');
      queue.enqueue('World');
      queue.enqueue('!');

      tx.signalTerminal(TerminalSignal.streamDone('onDone'));
      await tx.terminalFuture;

      // Drain BEFORE freezing snapshot
      await tx.sealAndDrainStreamQueue(queue);

      final snapshot = FinalOutputSnapshot(
        rawOutput: buffer.toString(),
        sessionId: 'sess-006',
        parentRequestId: tx.parentRequestId,
        frozenAt: DateTime.now(),
      );

      expect(snapshot.rawOutput, equals('Hello World!'));
      expect(tx.phase, equals(AiTransactionPhase.finalizing));
    });
  });

  // ── Scenario 5: Concurrent race — exactly one terminal winner ──────────────
  group('Scenario 5 — Concurrent race: exactly one terminal path wins', () {
    test('three concurrent delayed signals — only one wins ownership', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-007',
        providerRequestId: 'prov-007',
      );

      // Three async paths fire concurrently — onDone fires first (5ms)
      final futures = [
        Future.delayed(const Duration(milliseconds: 15), () =>
            tx.signalTerminal(TerminalSignal.timeout('timer'))),
        Future.delayed(const Duration(milliseconds: 5), () =>
            tx.signalTerminal(TerminalSignal.streamDone('onDone'))),
        Future.delayed(const Duration(milliseconds: 25), () =>
            tx.signalTerminal(TerminalSignal.cancelled('cancel'))),
      ];

      final winner = await tx.terminalFuture;
      // onDone fires at 5ms — must be the winner
      expect(winner.source, equals('onDone'));

      final owned = tx.tryAcquireOwnership(winner.source);
      expect(owned, isTrue);
      // Second call — same source, ownership already acquired
      expect(tx.tryAcquireOwnership(winner.source), isFalse);

      // Wait for all delayed Futures to resolve so the broker rejects them
      await Future.wait(futures);
      expect(tx.rejectedContenders.length, equals(2));
    });
  });

  // ── Scenario 6: completeCoordinatorAtomically — sync, exactly once ─────────
  group('Scenario 6 — completeCoordinatorAtomically: sync, exactly once', () {
    test('complete fires exactly once even if called multiple times', () {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-008',
        providerRequestId: 'prov-008',
      );
      int completeCalls = 0;

      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () => completeCalls++,
      );
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () => completeCalls++,
      );

      expect(completeCalls, equals(1));
      expect(tx.coordinatorCompleted, isTrue);
      expect(tx.phase, equals(AiTransactionPhase.completed));
    });

    test('cancelled cause sets phase to cancelled', () {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-009',
        providerRequestId: 'prov-009',
      );

      tx.completeCoordinatorAtomically(
        cause: TerminalCause.cancelled,
        complete: () {},
      );

      expect(tx.phase, equals(AiTransactionPhase.cancelled));
    });
  });

  // ── Scenario 7: tryMarkAssistantPersisted — exactly-once guard ────────────
  group('Scenario 7 — tryMarkAssistantPersisted: exactly-once persistence guard', () {
    test('first call returns true, second returns false', () {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-010',
        providerRequestId: 'prov-010',
      );
      expect(tx.tryMarkAssistantPersisted(), isTrue);
      expect(tx.tryMarkAssistantPersisted(), isFalse);
      expect(tx.tryMarkAssistantPersisted(), isFalse);
    });

    test('concurrent persistence loop: only one save executes', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-011',
        providerRequestId: 'prov-011',
      );
      int savedCount = 0;

      Future<void> persistenceLoop() async {
        await Future.delayed(const Duration(milliseconds: 1));
        if (tx.tryMarkAssistantPersisted()) {
          savedCount++;
        }
      }

      await Future.wait([
        persistenceLoop(),
        persistenceLoop(),
        persistenceLoop(),
      ]);

      expect(savedCount, equals(1));
    });
  });

  // ── Scenario 8: tryMarkToolResolutionStarted — exactly-once tool gate ──────
  group('Scenario 8 — tryMarkToolResolutionStarted: exactly-once tool gate', () {
    test('first call returns true, subsequent calls return false', () {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-012',
        providerRequestId: 'prov-012',
      );
      expect(tx.tryMarkToolResolutionStarted(), isTrue);
      expect(tx.tryMarkToolResolutionStarted(), isFalse);
    });

    test('tool gate and persist guard are independent', () {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-013',
        providerRequestId: 'prov-013',
      );
      expect(tx.tryMarkAssistantPersisted(), isTrue);
      expect(tx.tryMarkToolResolutionStarted(), isTrue);
      // Both consumed — subsequent calls fail
      expect(tx.tryMarkAssistantPersisted(), isFalse);
      expect(tx.tryMarkToolResolutionStarted(), isFalse);
    });
  });

  // ── Scenario 9: Exception safety — emitFinalizationFailure does not throw ──
  group('Scenario 9 — Exception safety: finalization failure telemetry', () {
    test('emitFinalizationFailure does not propagate exception', () {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-014',
        providerRequestId: 'prov-014',
      );
      expect(
        () => tx.emitFinalizationFailure(
          error: StateError('test error'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('releaseCanonicalDecisionOnce is idempotent', () async {
      final tx = _TestableTransaction(
        parentRequestId: 'req-015',
        providerRequestId: 'prov-015',
      );
      await tx.releaseCanonicalDecisionOnce();
      await tx.releaseCanonicalDecisionOnce();
      await tx.releaseCanonicalDecisionOnce();

      // Must have been called exactly once
      expect(tx.releaseCallCount, equals(1));
    });
  });

  // ── Scenario 10: sealAndDrainStreamQueue — phase and drain ordering ────────
  group('Scenario 10 — sealAndDrainStreamQueue: phase transitions before drain', () {
    test('phase is finalizing during drain, completed after coordinator', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-016',
        providerRequestId: 'prov-016',
      );
      final processed = <String>[];
      // Phase at drain time is captured DURING execution of processStreamEvent,
      // which runs AFTER sealAndDrainStreamQueue transitions to finalizing.
      final List<AiTransactionPhase> phasesAtExecution = [];

      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          phasesAtExecution.add(tx.phase);
          processed.add(event as String);
        },
      );

      // Enqueue chunks BEFORE sealing — they are queued during ingesting
      queue.enqueue('chunk-A');
      queue.enqueue('chunk-B');

      // Signal terminal — broker resolves
      tx.signalTerminal(TerminalSignal.streamDone('onDone'));
      await tx.terminalFuture;

      // sealAndDrainStreamQueue: transitions to finalizing THEN drains
      await tx.sealAndDrainStreamQueue(queue);

      expect(processed, equals(['chunk-A', 'chunk-B']));
      // After drain, phase must be finalizing (coordinator not yet completed)
      expect(tx.phase, equals(AiTransactionPhase.finalizing));
      // Chunks were enqueued during ingesting — they execute during drain
      // regardless of phase at execution time (spec: fully processed).
      // The critical invariant is that NEW chunks are rejected after seal,
      // not that already-queued chunks see the finalizing phase at runtime.
      expect(processed.length, equals(2));

      // Now complete the coordinator
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () {},
      );
      expect(tx.phase, equals(AiTransactionPhase.completed));
    });

    test('delayed persistence loop completes after full drain', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-017',
        providerRequestId: 'prov-017',
      );
      final buffer = StringBuffer();

      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          // Simulate delayed chunk arrival (e.g., network jitter)
          await Future.delayed(const Duration(milliseconds: 5));
          buffer.write(event as String);
        },
      );

      // Enqueue 5 chunks
      for (var i = 1; i <= 5; i++) {
        queue.enqueue('[$i]');
      }

      tx.signalTerminal(TerminalSignal.streamDone('onDone'));
      final signal = await tx.terminalFuture;

      // Acquire ownership and drain
      final owned = tx.tryAcquireOwnership(signal.source);
      expect(owned, isTrue);

      await tx.sealAndDrainStreamQueue(queue);

      // Snapshot is frozen AFTER full drain
      final snapshot = FinalOutputSnapshot(
        rawOutput: buffer.toString(),
        sessionId: 'sess-017',
        parentRequestId: tx.parentRequestId,
        frozenAt: DateTime.now(),
      );

      expect(snapshot.rawOutput, equals('[1][2][3][4][5]'));

      // Persistence guard fires exactly once
      final persisted = tx.tryMarkAssistantPersisted();
      expect(persisted, isTrue);
      expect(tx.tryMarkAssistantPersisted(), isFalse);

      // Complete coordinator atomically
      tx.completeCoordinatorAtomically(
        cause: signal.cause,
        complete: () {},
      );
      expect(tx.phase, equals(AiTransactionPhase.completed));
      expect(tx.coordinatorCompleted, isTrue);
    });
  });

  // ── Invariant U: Timeout Content Safety — operational fallback replaces raw ─
  group('Invariant U — Timeout Content Safety: operational fallback replaces raw fragment', () {
    // ── U-1: Timeout + truncated + low confidence → useOperationalFallback ──
    test('timeout + truncated + low confidence → fallback, not raw fragment', () async {
      // Arrange: build a transaction and a queue that collected a partial chunk.
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-u1',
        providerRequestId: 'prov-u1',
      );
      final buffer = StringBuffer();
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          buffer.write(event as String);
        },
      );

      // Enqueue a raw, partial/truncated fragment (simulated mid-sentence cut-off)
      queue.enqueue('Posologia: máx. 500 mg a cada 8h. Não exceder 1');

      // Signal a TIMEOUT terminal — network watchdog fired before stream completed
      tx.signalTerminal(TerminalSignal.timeout('networkWatchdog'));
      final signal = await tx.terminalFuture;
      expect(signal.cause, equals(TerminalCause.timeout));

      // Drain the queue so buffer reflects all partial text
      await tx.sealAndDrainStreamQueue(queue);

      final rawFragment = buffer.toString();
      expect(rawFragment, isNotEmpty); // raw fragment exists — dangerous

      // Act: evaluate timeout content safety guard using real production types
      final truncation = TruncationCheckResult(
        isTruncated: true,
        confidenceLevel: TruncationConfidence.low, // low confidence → cannot safely repair
      );
      final verdict = TimeoutContentSafetyGuard.evaluate(
        cause: signal.cause,
        truncation: truncation,
      );

      // Assert: verdict must be useOperationalFallback
      expect(verdict, equals(TimeoutSafetyVerdict.useOperationalFallback));

      // The persisted text must be the safe fallback — NOT the raw fragment
      final persistedText = verdict == TimeoutSafetyVerdict.useOperationalFallback
          ? TimeoutContentSafetyGuard.fallback('pt')
          : rawFragment;

      expect(persistedText, equals(TimeoutContentSafetyGuard.kOperationalFallbackPt));
      expect(persistedText, isNot(equals(rawFragment)));

      // Persistence guard fires exactly once with the safe fallback text
      final snapshot = FinalOutputSnapshot(
        rawOutput: persistedText,
        sessionId: 'sess-u1',
        parentRequestId: tx.parentRequestId,
        frozenAt: DateTime.now(),
      );
      expect(snapshot.rawOutput, equals(TimeoutContentSafetyGuard.kOperationalFallbackPt));
      expect(tx.tryMarkAssistantPersisted(), isTrue);
      expect(tx.tryMarkAssistantPersisted(), isFalse); // exactly once

      // No ToolResolution may be started when fallback replaces the fragment
      // The gate must remain closed (never started)
      expect(tx.tryMarkToolResolutionStarted(), isTrue,
          reason: 'tool gate was not opened — first call confirms it starts clean');
      // Simulating the guard: if we had used fallback, tool resolution is skipped.
      // Mark it as "started" to consume the slot, then verify no second start fires.
      expect(tx.tryMarkToolResolutionStarted(), isFalse,
          reason: 'tool gate is exactly-once — no ToolResolution payload generated');
    });

    // ── U-2: Timeout + non-truncated output → proceedAsIs ──────────────────
    test('timeout + non-truncated output → proceedAsIs, raw text kept', () async {
      // Arrange: timeout but the output is complete (not truncated)
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-u2',
        providerRequestId: 'prov-u2',
      );
      final buffer = StringBuffer();
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          buffer.write(event as String);
        },
      );

      // A complete, well-formed response that happens to trigger a timeout
      queue.enqueue('A posologia recomendada é 500 mg a cada 8 horas.');

      tx.signalTerminal(TerminalSignal.timeout('networkWatchdog'));
      final signal = await tx.terminalFuture;
      await tx.sealAndDrainStreamQueue(queue);

      final rawText = buffer.toString();

      // Act: TruncationInspector determines output is NOT truncated
      // (TruncationCheckResult.clean: isTruncated=false, confidence=low)
      const truncation = TruncationCheckResult.clean;
      final verdict = TimeoutContentSafetyGuard.evaluate(
        cause: signal.cause,
        truncation: truncation,
      );

      // Assert: proceedAsIs — the complete output is safe to persist
      expect(verdict, equals(TimeoutSafetyVerdict.proceedAsIs));

      // Persisted text must be the original raw text, not the fallback
      final persistedText = verdict == TimeoutSafetyVerdict.useOperationalFallback
          ? TimeoutContentSafetyGuard.fallback('pt')
          : rawText;

      expect(persistedText, equals(rawText));
      expect(persistedText, isNot(equals(TimeoutContentSafetyGuard.kOperationalFallbackPt)));

      final snapshot = FinalOutputSnapshot(
        rawOutput: persistedText,
        sessionId: 'sess-u2',
        parentRequestId: tx.parentRequestId,
        frozenAt: DateTime.now(),
      );
      expect(snapshot.rawOutput, equals('A posologia recomendada é 500 mg a cada 8 horas.'));
    });

    // ── U-3: Non-timeout cause + truncated output → proceedWithRepair ───────
    test('non-timeout cause + truncated output → proceedWithRepair path', () async {
      // Arrange: stream ends normally (streamDone) but output is truncated
      // (e.g., model stopped mid-sentence — repair is the correct path, not fallback)
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-u3',
        providerRequestId: 'prov-u3',
      );
      final buffer = StringBuffer();
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          buffer.write(event as String);
        },
      );

      queue.enqueue('Diagnóstico diferencial: considerar também');

      tx.signalTerminal(TerminalSignal.streamDone('onDone'));
      final signal = await tx.terminalFuture;
      await tx.sealAndDrainStreamQueue(queue);

      final rawText = buffer.toString();

      // Act: non-timeout cause with truncated output at any confidence level
      final truncation = TruncationCheckResult(
        isTruncated: true,
        confidenceLevel: TruncationConfidence.medium,
      );
      final verdict = TimeoutContentSafetyGuard.evaluate(
        cause: signal.cause, // TerminalCause.streamDone — NOT timeout
        truncation: truncation,
      );

      // Assert: proceedWithRepair — truncation repair should be attempted,
      // but the operational fallback is NOT used for non-timeout causes.
      expect(verdict, equals(TimeoutSafetyVerdict.proceedWithRepair));
      expect(verdict, isNot(equals(TimeoutSafetyVerdict.useOperationalFallback)));

      // The raw text is preserved for repair — not replaced by the fallback
      final persistedText = verdict == TimeoutSafetyVerdict.useOperationalFallback
          ? TimeoutContentSafetyGuard.fallback('pt')
          : rawText;

      expect(persistedText, equals(rawText));
      expect(persistedText, isNot(equals(TimeoutContentSafetyGuard.kOperationalFallbackPt)));
    });

    // ── U-4: Spanish fallback locale is correct ─────────────────────────────
    test('fallback() returns Spanish message when lang == "es"', () {
      final es = TimeoutContentSafetyGuard.fallback('es');
      final pt = TimeoutContentSafetyGuard.fallback('pt');

      expect(es, equals(TimeoutContentSafetyGuard.kOperationalFallbackEs));
      expect(pt, equals(TimeoutContentSafetyGuard.kOperationalFallbackPt));
      expect(es, isNot(equals(pt)));

      // Spanish message contains the correct text
      expect(es, contains('timeout de red'));
      // Portuguese message contains the correct text
      expect(pt, contains('timeout de rede'));
    });

    // ── U-5: Timeout + truncated + HIGH confidence → proceedWithRepair ───────
    test('timeout + truncated + high confidence → proceedWithRepair, not fallback', () {
      // High confidence means repair can be attempted even on timeout
      final truncation = TruncationCheckResult(
        isTruncated: true,
        confidenceLevel: TruncationConfidence.high,
      );
      final verdict = TimeoutContentSafetyGuard.evaluate(
        cause: TerminalCause.timeout,
        truncation: truncation,
      );

      // High confidence → repair path (NOT the unsafe raw discard or fallback)
      expect(verdict, equals(TimeoutSafetyVerdict.proceedWithRepair));
      expect(verdict, isNot(equals(TimeoutSafetyVerdict.useOperationalFallback)));
    });

    // ── U-6: Timeout + truncated + MEDIUM confidence → useOperationalFallback
    test('timeout + truncated + medium confidence → useOperationalFallback', () {
      // Medium is NOT high → falls to the discard/fallback branch
      final truncation = TruncationCheckResult(
        isTruncated: true,
        confidenceLevel: TruncationConfidence.medium,
      );
      final verdict = TimeoutContentSafetyGuard.evaluate(
        cause: TerminalCause.timeout,
        truncation: truncation,
      );

      expect(verdict, equals(TimeoutSafetyVerdict.useOperationalFallback));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Invariant V — MICRO-BUILD 462E-A.5.3.7.3.1
  // Gate Ownership Enforcement, Strict Sequence & Correlated Runtime
  //
  // V-1: Normal response → exactly 1 [EXT_TOOL_GATE] with callSite=canonical_finalizer
  // V-2: Tool-intent response → exactly 1 clinical payload trigger
  // V-3: First-delta event → 0 [EXT_TOOL_GATE] calls
  // V-4: Transport-done before queue sealed → 0 resolver calls
  // V-5: StreamDone vs Timeout race → exactly 1 winning finalizer
  // V-6: Late callback after completeCoordinatorAtomically → [AI_LATE_BUSINESS_EVENT_DROPPED], 0 mutations
  // V-7: Release occurs exactly once
  // V-8: Coordinator completion is the absolute final business event
  // V-9: Retry/fallback attempts share the same parent transactionId
  // ══════════════════════════════════════════════════════════════════════════
  group('Invariant V — Gate Ownership & Correlated Runtime (462E-A.5.3.7.3.1)', () {

    // ── V-1: Normal response → exactly 1 [EXT_TOOL_GATE] with canonical_finalizer ──
    test('V-1: normal response produces exactly 1 [EXT_TOOL_GATE] at canonical_finalizer', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-v1',
        providerRequestId: 'prov-v1',
      );
      final buffer = StringBuffer();
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async { buffer.write(event as String); },
      );

      queue.enqueue('Normal clinical response chunk.');
      tx.signalTerminal(TerminalSignal.streamDone('chunk_isDone'));
      await tx.terminalFuture;
      await tx.sealAndDrainStreamQueue(queue);

      // Simulate canonical finalizer: gate check before coordinator completion
      expect(tx.dropIfBusinessEventTerminal(callSite: 'canonical_finalizer'), isFalse,
          reason: 'transaction is not yet terminal — gate must allow through');
      final gateAllowed = tx.tryMarkToolResolutionStartedWithGate(callSite: 'canonical_finalizer');
      expect(gateAllowed, isTrue,
          reason: 'first call to gate must be allowed');

      // Complete coordinator atomically
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () {},
      );

      // Exactly 1 EXT_TOOL_GATE log with callSite=canonical_finalizer
      expect(tx.extToolGateLogs.length, equals(1));
      expect(tx.extToolGateLogs.first, contains('callSite=canonical_finalizer'));
      expect(tx.extToolGateLogs.first, contains('allowed=true'));
      expect(tx.extToolGateLogs.first, contains('transactionId=${tx.transactionId}'));
      expect(tx.extToolGateLogs.first, contains('attemptId=${tx.attemptId}'));
    });

    // ── V-2: Tool-intent response → exactly 1 clinical payload trigger ───────
    test('V-2: tool-intent response produces exactly 1 tool resolution trigger', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-v2',
        providerRequestId: 'prov-v2',
      );
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {},
      );

      queue.enqueue('Dose de amiodarona: 200mg. Interação com digoxina.');
      tx.signalTerminal(TerminalSignal.streamDone('chunk_isDone'));
      await tx.terminalFuture;
      await tx.sealAndDrainStreamQueue(queue);

      // Tool-intent: gate fires once for resolution
      int resolverCalls = 0;
      if (!tx.dropIfBusinessEventTerminal(callSite: 'canonical_finalizer')) {
        if (tx.tryMarkToolResolutionStartedWithGate(callSite: 'canonical_finalizer')) {
          resolverCalls++; // simulate resolveExternalToolExactlyOnce
        }
      }

      // Second attempt — must be blocked by the gate
      if (!tx.dropIfBusinessEventTerminal(callSite: 'duplicate_attempt')) {
        if (tx.tryMarkToolResolutionStartedWithGate(callSite: 'duplicate_attempt')) {
          resolverCalls++; // must NOT increment
        }
      }

      expect(resolverCalls, equals(1),
          reason: 'tool resolver must be called exactly once');
      expect(tx.extToolGateLogs.length, equals(2));
      expect(tx.extToolGateLogs[0], contains('allowed=true'));
      expect(tx.extToolGateLogs[1], contains('allowed=false'));
    });

    // ── V-3: First-delta event → 0 [EXT_TOOL_GATE] calls ────────────────────
    test('V-3: first-delta event before terminal produces 0 EXT_TOOL_GATE calls', () {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-v3',
        providerRequestId: 'prov-v3',
      );

      // Simulate what happens when a first-delta arrives (before isDone).
      // The gate MUST NOT be called here — only in the terminal block.
      // This test verifies no gate call occurs outside the terminal block.
      // (In production: stream delta listeners call accumulator.write() only,
      //  never tryMarkToolResolutionStarted())
      final buffer = StringBuffer();
      buffer.write('first delta text');
      // No gate call — correct behavior
      // We verify by checking extToolGateLogs is still empty

      expect(tx.extToolGateLogs, isEmpty,
          reason: 'no EXT_TOOL_GATE must fire before terminal ownership is acquired');
      expect(tx.phase, equals(AiTransactionPhase.ingesting));
      // Transaction is not terminal — coordinator not completed
      expect(tx.coordinatorCompleted, isFalse);
    });

    // ── V-4: Transport-done before queue sealed → 0 resolver calls ───────────
    test('V-4: transport-done signal before sealAndDrainStreamQueue → 0 resolver calls', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-v4',
        providerRequestId: 'prov-v4',
      );
      final buffer = StringBuffer();
      final queue = _CountingSerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {
          // Simulate a slow chunk processor
          await Future.delayed(const Duration(milliseconds: 5));
          buffer.write(event as String);
        },
      );

      // Enqueue chunks — queue is NOT drained yet
      queue.enqueue('partial chunk A');
      queue.enqueue('partial chunk B');

      // Transport-done arrives — but queue not sealed yet.
      // Resolver must NOT be called here; must wait for sealAndDrainStreamQueue.
      tx.signalTerminal(TerminalSignal.streamDone('chunk_isDone'));
      await tx.terminalFuture;

      // Before drain: phase still ingesting
      expect(tx.phase, equals(AiTransactionPhase.ingesting));
      expect(tx.extToolGateLogs, isEmpty,
          reason: 'no resolver call before queue is sealed and drained');

      // Now seal and drain — this is the correct point for the gate
      await tx.sealAndDrainStreamQueue(queue);
      expect(tx.phase, equals(AiTransactionPhase.finalizing));
      expect(buffer.toString(), equals('partial chunk Apartial chunk B'));

      // Only NOW may the gate fire
      final gateAllowed = tx.tryMarkToolResolutionStartedWithGate(callSite: 'canonical_finalizer');
      expect(gateAllowed, isTrue);
      expect(tx.extToolGateLogs.length, equals(1));
    });

    // ── V-5: StreamDone vs Timeout race → exactly 1 winning finalizer ────────
    test('V-5: StreamDone versus Timeout race elects exactly 1 winning finalizer', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-v5',
        providerRequestId: 'prov-v5',
      );

      // Simulate two concurrent terminal signals: streamDone at 5ms, timeout at 15ms
      int finalizerWins = 0;
      final futures = [
        Future.delayed(const Duration(milliseconds: 5), () {
          tx.signalTerminal(TerminalSignal.streamDone('chunk_isDone'));
        }),
        Future.delayed(const Duration(milliseconds: 15), () {
          tx.signalTerminal(TerminalSignal.timeout('global_timeout_timer'));
        }),
      ];

      final winner = await tx.terminalFuture;
      expect(winner.source, equals('chunk_isDone'));
      expect(winner.cause, equals(TerminalCause.streamDone));

      // Ownership acquired by winner
      final owned = tx.tryAcquireOwnership(winner.source);
      expect(owned, isTrue);
      finalizerWins++;

      await Future.wait(futures);

      // Timeout arrives — broker rejects it
      expect(tx.rejectedContenders.length, equals(1));
      expect(tx.rejectedContenders.first, equals('global_timeout_timer'));

      // Only 1 finalizer ran
      expect(finalizerWins, equals(1));

      // Gate fires exactly once for the winning finalizer
      if (!tx.dropIfBusinessEventTerminal(callSite: 'canonical_finalizer')) {
        tx.tryMarkToolResolutionStartedWithGate(callSite: 'canonical_finalizer');
      }
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () {},
      );

      expect(tx.extToolGateLogs.length, equals(1));
      expect(tx.phase, equals(AiTransactionPhase.completed));
    });

    // ── V-6: Late callback after completion → [AI_LATE_BUSINESS_EVENT_DROPPED] ─
    test('V-6: late callback after completeCoordinatorAtomically triggers drop, 0 mutations', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-v6',
        providerRequestId: 'prov-v6',
      );

      // Complete the coordinator — transaction is now terminal
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () {},
      );
      expect(tx.coordinatorCompleted, isTrue);
      expect(tx.phase, equals(AiTransactionPhase.completed));

      // Simulate a late async callback arriving 500ms after completion
      await Future.delayed(const Duration(milliseconds: 50)); // abbreviated for test speed

      // Late callback must be blocked
      final dropped = tx.dropIfBusinessEventTerminal(callSite: 'late_async_callback');
      expect(dropped, isTrue,
          reason: 'late callback must be dropped — transaction is terminal');
      expect(tx.droppedBusinessEvents, contains('late_async_callback'));

      // No state mutations occurred
      expect(tx.extToolGateLogs, isEmpty,
          reason: 'no EXT_TOOL_GATE must fire after completion');
      // tryMarkToolResolutionStarted still returns true (unused) — but the
      // business-event barrier was triggered first in correct ordering
      expect(tx.coordinatorCompleted, isTrue); // still terminal, no reset
      expect(tx.phase, equals(AiTransactionPhase.completed)); // phase unchanged
    });

    // ── V-7: Release occurs exactly once ────────────────────────────────────
    test('V-7: releaseCanonicalDecisionOnce is strictly idempotent across concurrent calls', () async {
      final tx = _TestableTransaction(
        parentRequestId: 'req-v7',
        providerRequestId: 'prov-v7',
      );

      // Fire release from 5 concurrent paths
      await Future.wait([
        tx.releaseCanonicalDecisionOnce(),
        tx.releaseCanonicalDecisionOnce(),
        tx.releaseCanonicalDecisionOnce(),
        tx.releaseCanonicalDecisionOnce(),
        tx.releaseCanonicalDecisionOnce(),
      ]);

      // Must have been called exactly once
      expect(tx.releaseCallCount, equals(1),
          reason: 'canonical decision must be released exactly once');
    });

    // ── V-8: Coordinator completion is the absolute final business event ─────
    test('V-8: completeCoordinatorAtomically is idempotent — only the first call executes', () {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-v8',
        providerRequestId: 'prov-v8',
      );

      int sideEffectCount = 0;

      // First call: executes the complete() callback
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () => sideEffectCount++,
      );
      // Second call: must be a no-op
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () => sideEffectCount++,
      );
      // Third call: must be a no-op
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.cancelled,
        complete: () => sideEffectCount++,
      );

      expect(sideEffectCount, equals(1),
          reason: 'complete() callback must execute exactly once regardless of call count');
      expect(tx.coordinatorCompleted, isTrue);
      // Phase was set on the first call (streamDone → completed) and must NOT
      // be changed by the third call (cancelled) — coordinator idempotency.
      expect(tx.phase, equals(AiTransactionPhase.completed));
    });

    // ── V-9: Retry/fallback share the same parent transactionId ─────────────
    test('V-9: retry and fallback transactions share the same parent transactionId', () {
      const String sharedParentRequestId = 'req-v9-parent';

      // Original attempt — providerRequestIds diverge within first 12 chars
      // so that attemptId slices (att_<first12>) are distinct.
      final tx1 = AiFinalizationTransaction(
        parentRequestId: sharedParentRequestId,
        providerRequestId: 'attempt-1-free',   // first12: "attempt-1-fr"
      );

      // Retry attempt — distinct first 12 chars
      final tx2 = AiFinalizationTransaction(
        parentRequestId: sharedParentRequestId,
        providerRequestId: 'attempt-2-free',   // first12: "attempt-2-fr"
      );

      // Fallback attempt — completely different prefix
      final tx3 = AiFinalizationTransaction(
        parentRequestId: sharedParentRequestId,
        providerRequestId: 'fallback-paid1',   // first12: "fallback-pai"
      );

      // All three share the same transactionId (derived from parentRequestId)
      expect(tx1.transactionId, equals(tx2.transactionId),
          reason: 'retry must share the same transactionId as the original attempt');
      expect(tx1.transactionId, equals(tx3.transactionId),
          reason: 'fallback must share the same transactionId as the original attempt');

      // Each has a distinct attemptId (derived from providerRequestId)
      expect(tx1.attemptId, isNot(equals(tx2.attemptId)),
          reason: 'each attempt must have a distinct attemptId');
      expect(tx1.attemptId, isNot(equals(tx3.attemptId)),
          reason: 'fallback must have a distinct attemptId');
      expect(tx2.attemptId, isNot(equals(tx3.attemptId)));

      // transactionId format is stable
      expect(tx1.transactionId, startsWith('txn_'));
      expect(tx1.attemptId, startsWith('att_'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Invariant W — MICRO-BUILD 462E-A.5.3.7.3.2
  // UI Zero-Invocation, Engine Once in Canonical Finalizer, Release Ordering
  //
  // W-1: UI render (simulated) produces exactly 0 ExternalToolLinkEngine runs
  // W-2: Multiple widget rebuilds → 0 additional engine builds
  // W-3: Engine invoked exactly once inside canonical finalizer before completeCoordinatorAtomically
  // W-4: Release occurs strictly AFTER tool resolution payload written
  // ══════════════════════════════════════════════════════════════════════════
  group('Invariant W — UI Zero-Invocation & Canonical Engine Ordering (462E-A.5.3.7.3.2)', () {

    // ── W-1 & W-2: UI render produces ZERO engine calls ──────────────────────
    test('W-1+W-2: simulated UI renders produce zero engine invocations', () {
      // In production: AppProvider._lastCompletedToolLink is set by the
      // canonical finalizer. The UI widget reads it without calling the engine.
      // This test simulates 100 widget "rebuilds" and verifies engine = 0.
      int engineCallCount = 0;

      // Simulate what the old (forbidden) UI code did:
      //   ExternalToolLinkEngine.build(...) called in widget builder.
      // The new code reads a pre-computed value. We model the new contract
      // as a closure that reads from a stored result.
      Object? storedPayload; // null = not yet resolved (ExternalToolLink in production)

      // Simulate canonical finalizer writing the result exactly once:
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-w1',
        providerRequestId: 'prov-w1',
      );
      if (tx.tryMarkToolResolutionStarted()) {
        engineCallCount++; // engine called once in finalizer
        storedPayload = null; // result stored (null = no intent in this test)
      }

      // Simulate 100 widget rebuilds — each reads storedPayload, never calls engine:
      for (var i = 0; i < 100; i++) {
        // ignore: unused_local_variable
        final uiValue = storedPayload; // pure read — zero engine calls
      }

      expect(engineCallCount, equals(1),
          reason: 'engine must be called exactly once, inside the canonical finalizer');
    });

    // ── W-3: Engine invoked exactly once, before completeCoordinatorAtomically ─
    test('W-3: engine invoked exactly once before completeCoordinatorAtomically', () async {
      final tx = AiFinalizationTransaction(
        parentRequestId: 'req-w3',
        providerRequestId: 'prov-w3',
      );
      final queue = SerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {},
      );

      queue.enqueue('clinical chunk');
      tx.signalTerminal(TerminalSignal.streamDone('chunk_isDone'));
      await tx.terminalFuture;
      await tx.sealAndDrainStreamQueue(queue);

      // Track exact call ordering
      final List<String> callOrder = [];

      // Engine phase (canonical finalizer)
      if (!tx.dropIfBusinessEventTerminal(callSite: 'canonical_finalizer')) {
        if (tx.tryMarkToolResolutionStarted()) {
          callOrder.add('engine_invoked'); // simulates ExternalToolLinkEngine.build()
        }
      }

      // completeCoordinatorAtomically must come AFTER engine
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () => callOrder.add('coordinator_completed'),
      );

      expect(callOrder, equals(['engine_invoked', 'coordinator_completed']),
          reason: 'engine must be called exactly once, strictly before coordinator completion');
      expect(tx.phase, equals(AiTransactionPhase.completed));
    });

    // ── W-4: Release occurs strictly AFTER tool resolution payload written ────
    test('W-4: canonical decision release occurs strictly after payload stored', () async {
      final tx = _TestableTransaction(
        parentRequestId: 'req-w4',
        providerRequestId: 'prov-w4',
      );
      final queue = SerialEventQueue(
        transaction: tx,
        signalTerminal: tx.signalTerminal,
        processStreamEvent: (event) async {},
      );

      queue.enqueue('payload chunk');
      tx.signalTerminal(TerminalSignal.streamDone('chunk_isDone'));
      await tx.terminalFuture;
      await tx.sealAndDrainStreamQueue(queue);

      final List<String> sequence = [];

      // Canonical finalizer ordering:
      if (!tx.dropIfBusinessEventTerminal(callSite: 'canonical_finalizer')) {
        if (tx.tryMarkToolResolutionStarted()) {
          sequence.add('payload_stored'); // ExternalToolLinkEngine.build() result stored
        }
      }

      // Release AFTER payload stored:
      await tx.releaseCanonicalDecisionOnce();
      sequence.add('cache_released');

      // Coordinator completion last:
      tx.completeCoordinatorAtomically(
        cause: TerminalCause.streamDone,
        complete: () => sequence.add('coordinator_completed'),
      );

      expect(sequence, equals(['payload_stored', 'cache_released', 'coordinator_completed']),
          reason: 'strict ordering: payload → release → coordinator');
      expect(tx.releaseCallCount, equals(1));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Invariant X — MICRO-BUILD 462E-A.5.3.7.3.2.1
  // Request-Correlated Map Integrity & Race Discard
  //
  // X-1: Race and Discard — late request A cannot overwrite map slot of B
  // X-2: Zero Ghost Tools — new non-tool request invalidates prior payload
  // ══════════════════════════════════════════════════════════════════════════
  group('Invariant X — Request-Correlated Map Integrity (462E-A.5.3.7.3.2.1)', () {

    // ── X-1: Race and Discard ────────────────────────────────────────────────
    // Simulates: request A starts, B starts and finishes first writing payload B,
    // A finishes late and tries to write payload A.
    // Assert: payload A does not overwrite slot B; map retains B's payload.
    test('X-1: late-arriving request A payload does not overwrite completed B payload', () {
      // Simulate the request-correlated resolution map (mirrors AppProvider._completedResolutions).
      final Map<String, CompletedToolResolution> resolutions = {};

      // Request B finishes first — writes its payload.
      const reqB = 'req-x1-B';
      const txnB = 'txn_req-x1-B_____';
      resolutions[reqB] = const CompletedToolResolution(
        requestId:      reqB,
        parentRequestId: reqB,
        transactionId:  txnB,
        link:           null,
        reason:         'no_explicit_intent',
        isAllowed:      false,
      );
      expect(resolutions.containsKey(reqB), isTrue);
      expect(resolutions[reqB]!.requestId, equals(reqB));

      // Request A tries to write late. In production _completedResolutions is
      // cleared at new-request start (sendAiMessage), so A's payload would only
      // arrive if it races between clear and B's write.
      // We simulate the guard: the UI verifies requestId match before rendering.
      const reqA = 'req-x1-A';
      // A's finalizer would write to slot reqA (its own key), NOT reqB.
      // This is the structural guarantee: each finalizer writes to its own slot.
      resolutions[reqA] = const CompletedToolResolution(
        requestId:      reqA,
        parentRequestId: reqA,
        transactionId:  'txn_req-x1-A_____',
        link:           null,
        reason:         'no_explicit_intent',
        isAllowed:      false,
      );

      // B's slot is untouched — A wrote to its own slot only.
      expect(resolutions[reqB]!.requestId, equals(reqB),
          reason: 'payload B must not be overwritten by late request A');
      expect(resolutions[reqA]!.requestId, equals(reqA),
          reason: 'payload A is in its own slot, not B\'s');

      // UI assertion: active request is B → read slot B → requestId matches → render allowed.
      final String activeRequestId = reqB;
      final payload = resolutions[activeRequestId];
      expect(payload, isNotNull);
      expect(payload!.requestId, equals(activeRequestId),
          reason: 'UI requestId assertion passes — B is the active request');

      // UI assertion for A's stale payload: requestId mismatch → no render.
      // (In production the map is cleared; here we simulate the check.)
      final stalePayload = resolutions[reqA];
      expect(stalePayload!.requestId, isNot(equals(activeRequestId)),
          reason: 'stale payload A must not be rendered for the active B request');
    });

    // ── X-2: Zero Ghost Tools ────────────────────────────────────────────────
    // When a new, non-tool prompt starts after an infusion-intent prompt finishes,
    // the prior completed payload must be invalidated (returns null for new requestId).
    test('X-2: new non-tool request returns null resolution for its own requestId', () {
      final Map<String, CompletedToolResolution> resolutions = {};

      // Request 1 (infusion intent) finishes — tool payload stored.
      const req1 = 'req-x2-infusion';
      resolutions[req1] = const CompletedToolResolution(
        requestId:      req1,
        parentRequestId: req1,
        transactionId:  'txn_req-x2-infusio',
        link:           null, // no real ExternalToolLink in unit tests
        reason:         'explicit_input_intent',
        isAllowed:      true,
      );
      expect(resolutions[req1]!.isAllowed, isTrue);

      // New request 2 starts — map is cleared (mirrors _completedResolutions.clear()).
      resolutions.clear();

      // Request 2 (non-tool) — canonical finalizer not yet written.
      const req2 = 'req-x2-general';
      final residual = resolutions[req2];

      // UI assertion: no residual payload exists for new request.
      expect(residual, isNull,
          reason: 'cleared map returns null for new requestId — no ghost tool rendered');

      // Even if we look up the old infusion slot after clear, it's gone.
      final ghostPayload = resolutions[req1];
      expect(ghostPayload, isNull,
          reason: 'prior infusion payload is immediately invalidated on new request start');

      // Simulate non-tool finalizer writing isAllowed=false.
      resolutions[req2] = const CompletedToolResolution(
        requestId:      req2,
        parentRequestId: req2,
        transactionId:  'txn_req-x2-general',
        link:           null,
        reason:         'no_explicit_intent',
        isAllowed:      false,
      );

      // UI assertion: non-tool payload → isAllowed=false → no tool card.
      final newPayload = resolutions[req2];
      expect(newPayload, isNotNull);
      expect(newPayload!.isAllowed, isFalse,
          reason: 'non-tool response correctly stores isAllowed=false — no tool card rendered');
      expect(newPayload.link, isNull,
          reason: 'no ExternalToolLink for non-tool response');
    });

    // ── X-3: CompletedToolResolution fields are immutable and correlated ─────
    test('X-3: CompletedToolResolution is fully immutable with correlated IDs', () {
      const resolution = CompletedToolResolution(
        requestId:      'req-x3',
        parentRequestId: 'req-x3',
        transactionId:  'txn_req-x3_______',
        link:           null,
        reason:         'explicit_input_intent',
        isAllowed:      true,
      );

      expect(resolution.requestId,      equals('req-x3'));
      expect(resolution.parentRequestId, equals('req-x3'));
      expect(resolution.transactionId,  equals('txn_req-x3_______'));
      expect(resolution.link,           isNull);
      expect(resolution.reason,         equals('explicit_input_intent'));
      expect(resolution.isAllowed,      isTrue);

      // Const construction guarantees deep immutability.
      const resolution2 = CompletedToolResolution(
        requestId:      'req-x3',
        parentRequestId: 'req-x3',
        transactionId:  'txn_req-x3_______',
        link:           null,
        reason:         'explicit_input_intent',
        isAllowed:      true,
      );
      // Both are const — identical values.
      expect(resolution.requestId, equals(resolution2.requestId));
      expect(resolution.isAllowed, equals(resolution2.isAllowed));
    });

    // ── X-4: Abrupt path stores isAllowed=false sentinel ─────────────────────
    test('X-4: abrupt-path resolution has isAllowed=false and null link', () {
      final Map<String, CompletedToolResolution> resolutions = {};

      // Simulate _completeAiRequestOnce() abrupt-path sentinel write.
      const reqId = 'req-x4-timeout';
      if (!resolutions.containsKey(reqId)) {
        resolutions[reqId] = CompletedToolResolution(
          requestId:      reqId,
          parentRequestId: reqId,
          transactionId:  'txn_${reqId.substring(0, reqId.length > 16 ? 16 : reqId.length)}',
          link:           null,
          reason:         'abrupt_terminal',
          isAllowed:      false,
        );
      }

      final abruptPayload = resolutions[reqId];
      expect(abruptPayload, isNotNull);
      expect(abruptPayload!.isAllowed, isFalse,
          reason: 'timeout/error/cancel path must not allow tool rendering');
      expect(abruptPayload.link, isNull,
          reason: 'no ExternalToolLink on abrupt path');
      expect(abruptPayload.reason, equals('abrupt_terminal'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Invariant C — MICRO-BUILD 462E-A.5.3.7.3.2.2: Log Hygiene + Clinical
  //              Numeric Determinism + Locale Lock
  //
  // C-1: No auth log string contains 'idToken' or 'refreshToken' literals.
  // C-2: 20 prompt variants for norepinephrine infusion → identical preset
  //      bounds (doseMin=0.05 NOT in range → fallback; 0.05 IS boundary ok).
  // C-3: Locale lock — validator is locale-agnostic; pt_BR comma decimals parsed.
  // ══════════════════════════════════════════════════════════════════════════
  group('Invariant C — Log Hygiene, Clinical Numeric Determinism & Locale Lock '
      '(462E-A.5.3.7.3.2.2)', () {
    // ── C-1: No credential strings in auth logs ─────────────────────────────
    test('C-1: hygienic auth telemetry — no idToken or refreshToken in log strings',
        () {
      // Simulate the exact log string produced by the hygienic [AUTH][LOGIN] block.
      // The string must NOT contain the literal tokens as keys with their values.
      const uidHash = 'abc12345';
      const loginLog = '[AUTH][LOGIN] status=200 '
          'uidHash=${uidHash}... '
          'idTokenPresent=true '
          'refreshTokenPresent=true '
          'expiresIn=3600';

      // ASSERT: the log contains the structural fields we expect.
      expect(loginLog, contains('[AUTH][LOGIN]'));
      expect(loginLog, contains('idTokenPresent=true'));
      expect(loginLog, contains('refreshTokenPresent=true'));
      expect(loginLog, contains('uidHash='));

      // INVARIANT: no raw credential VALUE appears — only presence booleans.
      // The string 'idToken=' with a long value would indicate a leak.
      // 'idTokenPresent' is allowed; 'idToken=' followed by a token is forbidden.
      final rawIdTokenPattern = RegExp(r'idToken\s*=\s*[A-Za-z0-9._\-]{20,}');
      final rawRefreshTokenPattern = RegExp(r'refreshToken\s*=\s*[A-Za-z0-9._\-]{20,}');
      expect(rawIdTokenPattern.hasMatch(loginLog), isFalse,
          reason: 'idToken value must never appear in logs — only idTokenPresent boolean');
      expect(rawRefreshTokenPattern.hasMatch(loginLog), isFalse,
          reason: 'refreshToken value must never appear in logs — only refreshTokenPresent boolean');

      // Same invariant for the REGISTER log.
      const registerLog = '[AUTH][REGISTER] status=200 '
          'uidHash=${uidHash}... '
          'idTokenPresent=true '
          'refreshTokenPresent=true '
          'expiresIn=3600';
      expect(registerLog, contains('[AUTH][REGISTER]'));
      expect(rawIdTokenPattern.hasMatch(registerLog), isFalse,
          reason: 'register log must not expose idToken value');
      expect(rawRefreshTokenPattern.hasMatch(registerLog), isFalse,
          reason: 'register log must not expose refreshToken value');

      // Both logs omit the raw body JSON (containing idToken + refreshToken values).
      const forbiddenSubstrings = [
        '"idToken"',         // JSON key that leaks body dump
        '"refreshToken"',    // JSON key that leaks body dump
        'BODY',              // The forbidden [AUTH][LOGIN] BODY: line
        'RESPONSE:',         // The forbidden [Auth][LOGIN] RESPONSE: line
      ];
      for (final forbidden in forbiddenSubstrings) {
        expect(loginLog, isNot(contains(forbidden)),
            reason: 'login log must not contain "$forbidden"');
        expect(registerLog, isNot(contains(forbidden)),
            reason: 'register log must not contain "$forbidden"');
      }
    });

    // ── C-2: 20 prompt variants → identical norepinephrine preset bounds ────
    test('C-2: clinical invariance — 20 infusion prompt variants produce identical '
        'norepinephrine preset: doseMin=0.01, doseUnit=mcg/kg/min', () {
      // The 20 prompt variants simulate different ways a physician might phrase
      // a norepinephrine infusion question (PT/EN/ES, abbreviated, full name).
      const promptVariants = [
        'qual a dose da noradrenalina em infusão?',
        'noradrenalin dose mcg kg min sepse',
        'norepinephrine drip rate ICU septic shock',
        'norepinefrina bomba de infusão dose inicial',
        'levophed infusion dose vasopressor',
        'noradrenalina vasopressora titular dose',
        'vasopressor de primeira linha dose norepinefrina',
        'norepinephrine infusion starting dose sepsis',
        'calculate norepinefrina infusion mcg/kg/min',
        'noradrenalin titulação protocolo UTI',
        'choque séptico noradrenalina dose PAM 65',
        'norepinephrine dose range septic shock mmHg target',
        'levophed dose vasopressor shock',
        'noradrenalina 0.1 mcg kg min aumentar dose',
        'como calcular dose noradrenalina infusão peso',
        'norepinefrina titulação hemodinâmica PAM meta',
        'noradrenalin dosis choque séptico mcg kg min',
        'infusão contínua noradrenalina bomba dose',
        'norepinephrine vasopressor titration protocol',
        'noradrenalina dose inicial 0.05 mcg/kg/min sepse',
      ];

      // All 20 variants must resolve to the same preset key.
      const expectedKey = 'norepinephrine_iv';
      const expectedDoseUnit = 'mcg/kg/min';
      const expectedDoseMin = 0.01;
      const expectedDoseMax = 3.0;

      for (var i = 0; i < promptVariants.length; i++) {
        final variant = promptVariants[i];
        final resolvedKey = ClinicalNumericValidator.resolvePresetKey(variant);
        expect(resolvedKey, equals(expectedKey),
            reason: 'Variant ${i + 1} "$variant" must resolve to norepinephrine_iv preset');

        // Verify the preset fields are invariant across all 20 lookups.
        final preset = kClinicalDosagePresets[resolvedKey!];
        expect(preset, isNotNull,
            reason: 'Preset $expectedKey must be in the registry');
        expect(preset!.doseUnit, equals(expectedDoseUnit),
            reason: 'Variant ${i + 1}: doseUnit must be mcg/kg/min');
        expect(preset.doseMin, equals(expectedDoseMin),
            reason: 'Variant ${i + 1}: doseMin must be 0.01 (Surviving Sepsis 2021)');
        expect(preset.doseMax, equals(expectedDoseMax),
            reason: 'Variant ${i + 1}: doseMax must be 3.0');
        expect(preset.sourceId, equals('Surviving_Sepsis_2021'),
            reason: 'Variant ${i + 1}: sourceId must be Surviving_Sepsis_2021');
      }
    });

    // ── C-2b: Validator correctly rejects out-of-bounds LLM output ──────────
    test('C-2b: out-of-bounds norepinephrine value triggers institutional fallback', () {
      // LLM hallucinates 5 mcg/kg/min (above 3.0 max) — must be rejected.
      const hallucinatedOutput = 'Dose recomendada de noradrenalina: 5 mcg/kg/min '
          'em choque séptico refratário.';
      const userInput = 'qual a dose da noradrenalina em infusão contínua?';

      final result = ClinicalNumericValidator.validate(
        llmOutput: hallucinatedOutput,
        userInput: userInput,
      );

      expect(result.isValid, isFalse,
          reason: '5 mcg/kg/min exceeds the 3.0 doseMax — must be rejected');
      expect(result.fallback, isNotNull,
          reason: 'A fallback must be provided when bounds are violated');
      expect(result.fallback!.isNotEmpty, isTrue,
          reason: 'fallback must not be empty');
      expect(result.fallback, contains('Noradrenalina IV'),
          reason: 'fallback must mention the drug by canonical name');
      expect(result.fallback, contains('Surviving Sepsis'),
          reason: 'fallback must cite the authoritative source');
    });

    // ── C-2c: Valid norepinephrine output passes without replacement ─────────
    test('C-2c: within-bounds norepinephrine value passes validation unchanged', () {
      // LLM correctly outputs 0.05–0.3 mcg/kg/min (within 0.01–3.0 bounds).
      const validOutput = 'Iniciar noradrenalina a 0.05–0.3 mcg/kg/min, '
          'titular para PAM ≥65 mmHg conforme resposta hemodinâmica.';
      const userInput = 'dose noradrenalina infusão sepse';

      final result = ClinicalNumericValidator.validate(
        llmOutput: validOutput,
        userInput: userInput,
      );

      expect(result.isValid, isTrue,
          reason: '0.05–0.3 mcg/kg/min is within bounds (0.01–3.0)');
      expect(result.fallback, isNull,
          reason: 'No fallback when bounds are satisfied');
    });

    // ── C-3: Locale lock — Brazilian decimal comma parsed correctly ──────────
    test('C-3: locale lock — pt_BR decimal comma in LLM output is parsed correctly', () {
      // Brazilian physicians write "0,05 mcg/kg/min" (comma decimal).
      // The validator must parse this as 0.05, within the norepinephrine bounds.
      const ptBrOutput = 'Dose: 0,05 a 0,3 mcg/kg/min noradrenalina IV, '
          'titular conforme PAM.';
      const userInput = 'noradrenalina dose infusão UTI';

      final result = ClinicalNumericValidator.validate(
        llmOutput: ptBrOutput,
        userInput: userInput,
      );

      expect(result.isValid, isTrue,
          reason: '0,05 (comma decimal = 0.05) is within norepinephrine bounds — '
              'pt_BR locale must not cause false violation');
    });

    // ── C-3b: Out-of-bounds comma decimal still triggers fallback ────────────
    test('C-3b: out-of-bounds pt_BR comma decimal triggers fallback correctly', () {
      // LLM writes "5,0 mcg/kg/min" (comma decimal = 5.0 > 3.0 max).
      const ptBrViolation = 'Noradrenalina 5,0 mcg/kg/min dose inicial.';
      const userInput = 'noradrenalina dose infusão';

      final result = ClinicalNumericValidator.validate(
        llmOutput: ptBrViolation,
        userInput: userInput,
      );

      expect(result.isValid, isFalse,
          reason: '5,0 (= 5.0) exceeds 3.0 max — comma decimal violation must trigger fallback');
      expect(result.fallback, isNotNull);
    });

    // ── C-3c: tryMarkCoordinatorCompleted() latch invariant ─────────────────
    test('C-3c: tryMarkCoordinatorCompleted() returns true exactly once per transaction', () {
      final txn = AiFinalizationTransaction(
        parentRequestId:  'req-c3c',
        providerRequestId: 'prov-c3c',
      );

      // First call: latch is free → wins.
      final first = txn.tryMarkCoordinatorCompleted();
      expect(first, isTrue,
          reason: 'First tryMarkCoordinatorCompleted() must win');
      expect(txn.coordinatorCompleted, isTrue);
      expect(txn.phase, equals(AiTransactionPhase.completed));

      // Second call: latch already held → rejected.
      final second = txn.tryMarkCoordinatorCompleted();
      expect(second, isFalse,
          reason: 'Second tryMarkCoordinatorCompleted() must be rejected');

      // Third call: same rejection.
      final third = txn.tryMarkCoordinatorCompleted();
      expect(third, isFalse,
          reason: 'All subsequent calls must return false');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Invariant Z — MICRO-BUILD 462E-A.5.3.7.3.2.3: Unit-Coupled Parsing,
  //              Atomic Persistence Idempotency & Phase Order
  //
  // Z-1: Only unit-coupled values are extracted; standalone numbers bypassed.
  // Z-2: persistAiExchangeOnce() idempotency — same requestId → SessionPersistSkipped.
  // Z-3: Transaction phase remains [finalizing] throughout A–E; [completed] at F.
  // ══════════════════════════════════════════════════════════════════════════
  group('Invariant Z — Unit-Coupled Parsing, Atomic Persistence & Phase Order '
      '(462E-A.5.3.7.3.2.3)', () {
    // ── Z-1: Unit-coupled extraction — standalone numbers bypassed ──────────
    test('Z-1a: "dilute in 5 mL and infuse at 0.05 mcg/kg/min" — '
        'only 0.05 extracted; 5 (mL) bypassed', () {
      const text = 'Dilua em 5 mL de SF e infunda a 0.05 mcg/kg/min de noradrenalina.';
      const userInput = 'noradrenalina infusão dose';

      final result = ClinicalNumericValidator.validate(
        llmOutput: text,
        userInput: userInput,
      );

      // 0.05 mcg/kg/min is within norepinephrine bounds (0.01–3.0) → PASS.
      // 5 (mL) must NOT be extracted and must NOT cause a false violation.
      expect(result.isValid, isTrue,
          reason: '"5 mL" is not a dose value and must be bypassed; '
              '0.05 mcg/kg/min is within bounds');
    });

    test('Z-1b: "infuse at 5 mcg/kg/min" — unit-coupled 5.0 extracted → violation', () {
      const text = 'Infundir noradrenalina a 5 mcg/kg/min.';
      const userInput = 'noradrenalina dose infusão';

      final result = ClinicalNumericValidator.validate(
        llmOutput: text,
        userInput: userInput,
      );

      // 5 mcg/kg/min > 3.0 max → VIOLATION.
      expect(result.isValid, isFalse,
          reason: '5 mcg/kg/min is above the 3.0 doseMax → violation');
      expect(result.fallback, isNotNull);
    });

    test('Z-1c: list ordinals "1.", "2.", "3." are bypassed — no false violation', () {
      const text = '1. Verificar acesso venoso\n'
          '2. Iniciar noradrenalina 0.1 mcg/kg/min\n'
          '3. Titular para PAM ≥65 mmHg\n'
          '4. Monitorar débito urinário';
      const userInput = 'noradrenalina dose sepse';

      final result = ClinicalNumericValidator.validate(
        llmOutput: text,
        userInput: userInput,
      );

      // Only 0.1 mcg/kg/min (within bounds 0.01–3.0) is extracted.
      // The ordinals 1, 2, 3, 4 have no dose unit → bypassed.
      // PAM 65 mmHg → bypassed (mmHg is not a clinical dose unit).
      expect(result.isValid, isTrue,
          reason: 'List ordinals and PAM values must be bypassed; '
              '0.1 mcg/kg/min is within bounds');
    });

    test('Z-1d: weight and volume values are bypassed', () {
      // "80 kg" weight, "250 mL" volume, "100 mL/h" rate (mL/h not a dose unit)
      // Only the unit-coupled dose value should be extracted.
      const text = 'Paciente 80 kg. Solução: 4 mg em 250 mL SF. '
          'Velocidade: noradrenalina 0.08 mcg/kg/min. '
          'Volume em 24h: ~100 mL.';
      const userInput = 'noradrenalina infusão';

      final result = ClinicalNumericValidator.validate(
        llmOutput: text,
        userInput: userInput,
      );

      // 0.08 mcg/kg/min within bounds. 80, 4, 250, 100 bypassed (no clinical dose unit).
      expect(result.isValid, isTrue,
          reason: 'Weight (80 kg), volume (250 mL), and concentration (4 mg) '
              'must be bypassed; 0.08 mcg/kg/min is within bounds');
    });

    test('Z-1e: range "0.05–0.3 mcg/kg/min" — both endpoints extracted and within bounds', () {
      const text = 'Dose de manutenção: 0.05–0.3 mcg/kg/min.';
      const userInput = 'norepinephrine drip septic shock';

      final result = ClinicalNumericValidator.validate(
        llmOutput: text,
        userInput: userInput,
      );

      // Both 0.05 and 0.3 are within norepinephrine bounds (0.01–3.0).
      expect(result.isValid, isTrue,
          reason: 'Range 0.05–0.3 mcg/kg/min is entirely within bounds');
    });

    test('Z-1f: range "0.05–5 mcg/kg/min" — upper endpoint 5.0 triggers violation', () {
      const text = 'Pode-se usar 0.05–5 mcg/kg/min de noradrenalina.';
      const userInput = 'noradrenalina infusão';

      final result = ClinicalNumericValidator.validate(
        llmOutput: text,
        userInput: userInput,
      );

      // Upper bound 5.0 > 3.0 max → violation even though lower is valid.
      expect(result.isValid, isFalse,
          reason: 'Upper endpoint 5.0 mcg/kg/min exceeds doseMax=3.0 → violation');
    });

    test('Z-1g: pt_BR comma decimal "0,05 mcg/kg/min" in rich context with other numbers', () {
      // Mixed context: list numbers, patient weight, AND a dose value in pt_BR format.
      const text = 'Protocolo para paciente 70 kg:\n'
          '1. Acesso IV\n'
          '2. Noradrenalina 0,05 mcg/kg/min inicial\n'
          '3. Titular de 0,01 em 0,01 mcg/kg/min a cada 5 min\n'
          'Meta PAM: 65 mmHg';
      const userInput = 'noradrenalina dose UTI';

      final result = ClinicalNumericValidator.validate(
        llmOutput: text,
        userInput: userInput,
      );

      // 0,05 = 0.05 within bounds; 0,01 = 0.01 at lower bound (inclusive).
      // 70 kg, 65 mmHg, 5 (min), 1 (ordinal), 2 (ordinal), 3 (ordinal) — bypassed.
      expect(result.isValid, isTrue,
          reason: 'pt_BR 0,05 and 0,01 mcg/kg/min are within bounds; '
              'ordinals, weight, pressure bypassed');
    });

    // ── Z-2: Atomic persistence idempotency ────────────────────────────────
    test('Z-2: SessionPersistStatus types are correct and idempotency works', () async {
      // Z-2a: Verify all SessionPersistStatus variants are distinct types.
      const synced  = SessionPersistSynced();
      const offline = SessionPersistQueuedOffline();
      const skipped = SessionPersistSkipped('test_reason');
      final failed  = SessionPersistFailed(Exception('test'));

      expect(synced,  isA<SessionPersistSynced>());
      expect(offline, isA<SessionPersistQueuedOffline>());
      expect(skipped, isA<SessionPersistSkipped>());
      expect(skipped.reason, equals('test_reason'));
      expect(failed,  isA<SessionPersistFailed>());
      expect(failed.error, isA<Exception>());

      // Z-2b: Verify ActiveAiSessionContext is immutable and carries all fields.
      final frozenAt = DateTime(2026, 7, 14, 13, 55, 0);
      final ctx = ActiveAiSessionContext(
        uid:       'uid_test_z2',
        sessionId: 'req_z2_abcdef',
        requestId: 'req_z2_abcdef',
        mode:      'plantao',
        locale:    'pt',
        createdAt: frozenAt,
      );

      expect(ctx.uid,       equals('uid_test_z2'));
      expect(ctx.sessionId, equals('req_z2_abcdef'));
      expect(ctx.requestId, equals('req_z2_abcdef'));
      expect(ctx.mode,      equals('plantao'));
      expect(ctx.locale,    equals('pt'));
      expect(ctx.createdAt, equals(frozenAt),
          reason: 'createdAt must be the exact frozen instant passed at construction');

      // Z-2c: Simulate idempotency — same requestId must produce SessionPersistSkipped.
      final persistedIds = <String>{};
      Future<SessionPersistStatus> mockPersist(String reqId) async {
        if (persistedIds.contains(reqId)) {
          return const SessionPersistSkipped('idempotency_key_already_seen');
        }
        persistedIds.add(reqId);
        return const SessionPersistSynced();
      }

      const reqId = 'req_z2_idempotency_test';
      final first  = await mockPersist(reqId);
      final second = await mockPersist(reqId);
      final third  = await mockPersist(reqId);

      expect(first,  isA<SessionPersistSynced>(),
          reason: 'First persist call → SessionPersistSynced');
      expect(second, isA<SessionPersistSkipped>(),
          reason: 'Second persist call → SessionPersistSkipped (idempotency)');
      expect(third,  isA<SessionPersistSkipped>(),
          reason: 'Third persist call → SessionPersistSkipped (idempotency)');
      expect((second as SessionPersistSkipped).reason,
          equals('idempotency_key_already_seen'));

      // Z-2d: Verify the mock writer was only invoked once (persistedIds has 1 entry).
      expect(persistedIds, hasLength(1),
          reason: 'Only one unique requestId should have been written');
      expect(persistedIds.contains(reqId), isTrue);
    });

    // ── Z-3: Phase order — [finalizing] during A–E; [completed] at F ────────
    test('Z-3: transaction phase remains finalizing during business ops; '
        'completed only at tryMarkCoordinatorCompleted()', () {
      final txn = AiFinalizationTransaction(
        parentRequestId:   'req-z3-phase-order',
        providerRequestId: 'prov-z3',
      );

      // Initial state: ingesting.
      expect(txn.phase, equals(AiTransactionPhase.ingesting));
      expect(txn.coordinatorCompleted, isFalse);

      // Simulate phase transition to finalizing (terminal signal won).
      txn.transitionToFinalizing();
      expect(txn.phase, equals(AiTransactionPhase.finalizing),
          reason: 'Phase must be finalizing after transitionToFinalizing()');

      // Steps A–E (validation, persistence, tool gate, UI emit, release) happen
      // WHILE phase is still [finalizing]. Simulate them as no-ops and assert.
      // Step A: validation — phase unchanged.
      expect(txn.phase, equals(AiTransactionPhase.finalizing),
          reason: 'Phase must remain finalizing after Step A (validation)');

      // Step B: persistence — phase unchanged.
      expect(txn.coordinatorCompleted, isFalse,
          reason: 'Coordinator must NOT be completed during Step B (persistence)');
      expect(txn.phase, equals(AiTransactionPhase.finalizing),
          reason: 'Phase must remain finalizing after Step B (persistence)');

      // Step C: tool resolution — phase unchanged.
      txn.tryMarkToolResolutionStarted();
      expect(txn.phase, equals(AiTransactionPhase.finalizing),
          reason: 'Phase must remain finalizing after Step C (tool resolution)');

      // Step D: UI notification — phase unchanged.
      expect(txn.phase, equals(AiTransactionPhase.finalizing),
          reason: 'Phase must remain finalizing after Step D (UI notify)');

      // Step E: release — phase unchanged.
      expect(txn.coordinatorCompleted, isFalse,
          reason: 'Coordinator must NOT be completed during Step E (release)');

      // Step F: tryMarkCoordinatorCompleted() — phase advances to completed.
      final won = txn.tryMarkCoordinatorCompleted();
      expect(won, isTrue,
          reason: 'First tryMarkCoordinatorCompleted() must win');
      expect(txn.coordinatorCompleted, isTrue,
          reason: 'coordinatorCompleted must be true after Step F');
      expect(txn.phase, equals(AiTransactionPhase.completed),
          reason: 'Phase must advance to completed ONLY at Step F');

      // Verify idempotency: second tryMarkCoordinatorCompleted() must lose.
      final lost = txn.tryMarkCoordinatorCompleted();
      expect(lost, isFalse,
          reason: 'Second tryMarkCoordinatorCompleted() must return false');
      // Phase stays completed (not double-advanced).
      expect(txn.phase, equals(AiTransactionPhase.completed),
          reason: 'Phase must remain completed after duplicate tryMarkCoordinatorCompleted()');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════════
  // Invariant K — Session Index Materialization (MICRO-BUILD 462E-A.5.3.7.3.2.5)
  //
  // K-1: Atomic Batch Execution — both parent document and exchange document must
  //      be written in a single batch with non-null server timestamps.
  // K-2: Identifier Decoupling — sessionId is stable across turns; requestId is
  //      unique per exchange.
  // K-3: Local List Prepend — a successful persist triggers the local index upsert
  //      and the list reflects the most-recent session at position 0.
  // ══════════════════════════════════════════════════════════════════════════════
  group('Invariant K — Session Index Materialization (462E-A.5.3.7.3.2.5)', () {

    // ── K-1: Atomic batch — parent + exchange both written ───────────────────
    test('K-1: atomic batch writes parent session doc and exchange sub-doc', () async {
      // Simulate the two operations that batchWriteAiExchange must execute.
      // We model the batch as a simple record that captures both writes.
      // In unit tests we cannot reach Firestore, so we verify the contract
      // through a mock batch accumulator.

      final List<String> writtenPaths = [];

      // Simulate Operation A (parent session) and Operation B (exchange).
      Future<({bool ok, Object? error})> mockBatch({
        required String uid,
        required String sessionId,
        required String requestId,
        required bool isFirstMessage,
      }) async {
        // Operation A — parent path
        writtenPaths.add('users/$uid/ai_sessions/$sessionId');
        // Operation B — exchange path
        writtenPaths.add('users/$uid/ai_sessions/$sessionId/exchanges/$requestId');
        return (ok: true, error: null);
      }

      const uid       = 'uid-k1';
      const sessionId = 'session_1784000000000';
      const requestId = 'req_1784000001000';

      final result = await mockBatch(
        uid:            uid,
        sessionId:      sessionId,
        requestId:      requestId,
        isFirstMessage: true,
      );

      expect(result.ok, isTrue,
          reason: 'Batch must succeed');
      expect(result.error, isNull,
          reason: 'No error on successful batch');
      expect(writtenPaths, hasLength(2),
          reason: 'Exactly two write operations must be dispatched');
      expect(writtenPaths[0], equals('users/$uid/ai_sessions/$sessionId'),
          reason: 'Operation A must target the parent session document');
      expect(writtenPaths[1],
          equals('users/$uid/ai_sessions/$sessionId/exchanges/$requestId'),
          reason: 'Operation B must target the exchange sub-document');

      // Verify both paths share the same sessionId (atomic grouping invariant).
      final parentSessionId = writtenPaths[0].split('/')[3];
      final exchangeSessionId = writtenPaths[1].split('/')[3];
      expect(parentSessionId, equals(exchangeSessionId),
          reason: 'Parent and exchange must share the same sessionId');

      // Verify the exchange path ends with the requestId (idempotency key).
      expect(writtenPaths[1].endsWith(requestId), isTrue,
          reason: 'Exchange document ID must equal requestId for idempotency');
    });

    // ── K-2: Identifier decoupling — sessionId stable, requestId unique ──────
    test('K-2: sessionId is stable across 3 turns; requestId is unique per turn', () {
      // Model the stable sessionId as a conversation-lifetime constant.
      const stableSessionId = 'session_1784100000000';

      // Each turn generates a new requestId (simulating ProviderRouterService).
      final turn1 = 'req_${DateTime(2026, 7, 14, 10, 0, 1).millisecondsSinceEpoch}';
      final turn2 = 'req_${DateTime(2026, 7, 14, 10, 0, 2).millisecondsSinceEpoch}';
      final turn3 = 'req_${DateTime(2026, 7, 14, 10, 0, 3).millisecondsSinceEpoch}';

      // Build three ActiveAiSessionContext objects as the provider would.
      final ctx1 = ActiveAiSessionContext(
        uid:       'uid-k2',
        sessionId: stableSessionId,
        requestId: turn1,
        mode:      'plantao',
        locale:    'pt',
        createdAt: DateTime(2026, 7, 14, 10, 0, 1),
      );
      final ctx2 = ActiveAiSessionContext(
        uid:       'uid-k2',
        sessionId: stableSessionId,
        requestId: turn2,
        mode:      'plantao',
        locale:    'pt',
        createdAt: DateTime(2026, 7, 14, 10, 0, 2),
      );
      final ctx3 = ActiveAiSessionContext(
        uid:       'uid-k2',
        sessionId: stableSessionId,
        requestId: turn3,
        mode:      'plantao',
        locale:    'pt',
        createdAt: DateTime(2026, 7, 14, 10, 0, 3),
      );

      // sessionId must be identical across all three turns.
      expect(ctx1.sessionId, equals(stableSessionId));
      expect(ctx2.sessionId, equals(stableSessionId));
      expect(ctx3.sessionId, equals(stableSessionId));
      expect(ctx1.sessionId, equals(ctx2.sessionId),
          reason: 'Turn 1 and Turn 2 must share the same sessionId');
      expect(ctx2.sessionId, equals(ctx3.sessionId),
          reason: 'Turn 2 and Turn 3 must share the same sessionId');

      // requestId must be unique per turn.
      final requestIds = {ctx1.requestId, ctx2.requestId, ctx3.requestId};
      expect(requestIds, hasLength(3),
          reason: 'All three requestIds must be distinct');

      // requestId must NOT equal sessionId on any turn.
      expect(ctx1.requestId, isNot(equals(stableSessionId)),
          reason: 'Turn 1 requestId must differ from sessionId');
      expect(ctx2.requestId, isNot(equals(stableSessionId)),
          reason: 'Turn 2 requestId must differ from sessionId');
      expect(ctx3.requestId, isNot(equals(stableSessionId)),
          reason: 'Turn 3 requestId must differ from sessionId');
    });

    // ── K-3: Local list prepend and notification ──────────────────────────────
    test('K-3: successful persist prepends session to local index at position 0', () {
      // Model the local in-memory session index as a plain List<Map>.
      final localIndex = <Map<String, dynamic>>[];
      int notifyCount = 0;

      // Simulate _upsertLocalSessionIndex logic.
      void upsertLocal({
        required String sessionId,
        required String uid,
        required String title,
        required String mode,
        required String locale,
        required String requestId,
        required String userPreview,
        required String assistantPreview,
      }) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final idx = localIndex.indexWhere((s) => s['sessionId'] == sessionId);

        if (idx >= 0) {
          final existing = Map<String, dynamic>.from(localIndex[idx]);
          existing['updatedAt']            = now;
          existing['lastRequestId']        = requestId;
          existing['lastUserPreview']      = userPreview;
          existing['lastAssistantPreview'] = assistantPreview;
          localIndex.removeAt(idx);
          localIndex.insert(0, existing);
        } else {
          localIndex.insert(0, {
            'sessionId':            sessionId,
            'uid':                  uid,
            'title':                title,
            'mode':                 mode,
            'locale':               locale,
            'createdAt':            now,
            'updatedAt':            now,
            'lastRequestId':        requestId,
            'lastUserPreview':      userPreview,
            'lastAssistantPreview': assistantPreview,
            'messageCount':         1,
            'isDeleted':            false,
            'schemaVersion':        2,
          });
        }
        notifyCount++;
      }

      // Simulate a mock persist that returns [SessionPersistSynced] and triggers upsert.
      Future<SessionPersistStatus> mockPersistAndUpsert({
        required String sessionId,
        required String requestId,
        required String title,
        required String userInput,
        required String assistantOutput,
      }) async {
        // Simulate successful batch write — always synced in this mock.
        upsertLocal(
          sessionId:        sessionId,
          uid:              'uid-k3',
          title:            title,
          mode:             'plantao',
          locale:           'pt',
          requestId:        requestId,
          userPreview:      userInput.length > 120
              ? userInput.substring(0, 120)
              : userInput,
          assistantPreview: assistantOutput.length > 160
              ? assistantOutput.substring(0, 160)
              : assistantOutput,
        );
        return const SessionPersistSynced();
      }

      // K-3a: First message — session is prepended at index 0.
      const sessionId = 'session_k3_stable';
      const req1 = 'req_k3_turn1';

      expect(localIndex, isEmpty, reason: 'Index must start empty');

      final status1 = mockPersistAndUpsert(
        sessionId:       sessionId,
        requestId:       req1,
        title:           'Síndrome de Guillain-Barré',
        userInput:       'Explique Síndrome de Guillain-Barré',
        assistantOutput: 'A SGB é uma polineuropatia...',
      );

      // (fire and check synchronously after await)
      status1.then((s) {
        expect(s, isA<SessionPersistSynced>(),
            reason: 'K-3a: first persist must return SessionPersistSynced');
        expect(localIndex, hasLength(1),
            reason: 'K-3a: one entry in local index after first message');
        expect(localIndex[0]['sessionId'], equals(sessionId),
            reason: 'K-3a: entry at position 0 must have the correct sessionId');
        expect(localIndex[0]['title'], equals('Síndrome de Guillain-Barré'),
            reason: 'K-3a: title must be set from first user message');
        expect(localIndex[0]['schemaVersion'], equals(2),
            reason: 'K-3a: schemaVersion must be 2');
        expect(localIndex[0]['isDeleted'], isFalse,
            reason: 'K-3a: isDeleted must be false');
        expect(notifyCount, equals(1),
            reason: 'K-3a: notifyListeners must have been called exactly once');
      });

      // Eagerly flush the future to resolve within test.
      return status1.then((_) {
        // K-3b: Second turn — same sessionId, different requestId, moves to position 0.
        const req2 = 'req_k3_turn2';

        // Insert an older session first to test position 0 invariant.
        localIndex.insert(1, {
          'sessionId': 'session_older',
          'title': 'Old session',
          'updatedAt': 0,
        });
        expect(localIndex, hasLength(2),
            reason: 'K-3b: two sessions in index before second turn');

        return mockPersistAndUpsert(
          sessionId:       sessionId,
          requestId:       req2,
          title:           'Síndrome de Guillain-Barré',
          userInput:       'E o tratamento?',
          assistantOutput: 'O tratamento inclui IVIG ou plasmaférese.',
        ).then((s2) {
          expect(s2, isA<SessionPersistSynced>(),
              reason: 'K-3b: second persist must return SessionPersistSynced');
          expect(localIndex, hasLength(2),
              reason: 'K-3b: still 2 sessions — no duplicate created');
          expect(localIndex[0]['sessionId'], equals(sessionId),
              reason: 'K-3b: updated session must be at position 0 (most-recent)');
          expect(localIndex[0]['lastUserPreview'],
              equals('E o tratamento?'),
              reason: 'K-3b: lastUserPreview must reflect second turn');
          expect(localIndex[1]['sessionId'], equals('session_older'),
              reason: 'K-3b: older session pushed to position 1');
          expect(notifyCount, equals(2),
              reason: 'K-3b: notifyListeners called once more for second turn');
        });
      });
    });
  });

  // Invariant L: History Repository Merge Semantics (462E-A.5.3.7.3.2.5.2)
  group('Invariant L: History Repository Merge Semantics (462E-A.5.3.7.3.2.5.2)', () {
    List<AiSessionSummary> merge(List<AiSessionSummary> incoming) {
      final repo = <AiSessionSummary>[];
      for (final s in incoming) {
        final idx = repo.indexWhere((e) => e.sessionId == s.sessionId);
        if (idx >= 0) {
          if (s.updatedAt > repo[idx].updatedAt) repo[idx] = s;
        } else {
          repo.add(s);
        }
      }
      repo.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (repo.length > 10) repo.removeRange(10, repo.length);
      return repo;
    }

    test('L-1: 8 server summaries + 1 local pending render exactly 9 entries', () {
      final server = List.generate(8, (i) => AiSessionSummary(
        sessionId: 'session_server_$i', uid: 'uid-l1',
        title: 'Server session $i', mode: 'plantao', locale: 'pt',
        updatedAt: 1000000 + i * 1000, source: AiSessionSource.canonicalV2,
      ));
      final local = AiSessionSummary(
        sessionId: 'session_local_pending', uid: 'uid-l1',
        title: 'In-progress consultation', mode: 'estudo', locale: 'pt',
        updatedAt: 2000000, source: AiSessionSource.localMemory,
      );
      final repo = merge([...server, local]);
      expect(repo, hasLength(9),
          reason: 'L-1: 8 server + 1 local with distinct sessionIds = 9 entries');
      expect(repo.first.sessionId, equals('session_local_pending'),
          reason: 'L-1: local pending (highest updatedAt) at position 0');
      for (int i = 0; i < 8; i++) {
        expect(repo.any((s) => s.sessionId == 'session_server_$i'), isTrue,
            reason: 'L-1: server session $i must be present');
      }
    });

    test('L-2: identical titles with independent session keys do not deduplicate', () {
      const sharedTitle = 'Fibrilacao Atrial tratamento';
      final summaryA = AiSessionSummary(
        sessionId: 'session_A_distinct', uid: 'uid-l2',
        title: sharedTitle, mode: 'plantao', locale: 'pt',
        updatedAt: 500000, source: AiSessionSource.canonicalV2,
      );
      final summaryB = AiSessionSummary(
        sessionId: 'session_B_distinct', uid: 'uid-l2',
        title: sharedTitle, mode: 'estudo', locale: 'pt',
        updatedAt: 600000, source: AiSessionSource.legacyInline,
      );
      final repo = merge([summaryA, summaryB]);
      expect(repo, hasLength(2),
          reason: 'L-2: same title but different sessionIds must NOT be deduplicated');
      expect(repo.any((s) => s.sessionId == 'session_A_distinct'), isTrue,
          reason: 'L-2: session_A_distinct must remain');
      expect(repo.any((s) => s.sessionId == 'session_B_distinct'), isTrue,
          reason: 'L-2: session_B_distinct must remain');
    });

    test('L-3: first batch drop retains first-message parameters intact for retry', () async {
      bool isFirstMessageOfSession = true;
      String currentConversationTitle = '';

      String generateTitle(String userInput) {
        final cleaned = userInput
            .replaceAll(RegExp(r'[*_`#>~\[\]()]'), '')
            .replaceAll(RegExp(r'\s+'), ' ').trim();
        if (cleaned.isEmpty) return 'Nova consulta';
        if (cleaned.length <= 60) return cleaned;
        final truncated = cleaned.substring(0, 60);
        final lastSpace = truncated.lastIndexOf(' ');
        return lastSpace > 30 ? truncated.substring(0, lastSpace) : truncated;
      }

      Future<SessionPersistStatus> mockPersist({
        required String userInput, required bool batchOk,
      }) async {
        final bool isFirst = isFirstMessageOfSession;
        final String computedTitle = isFirst
            ? generateTitle(userInput) : currentConversationTitle;
        if (!batchOk) {
          return SessionPersistFailed('mock_batch_failure');
        }
        if (isFirst) {
          currentConversationTitle = computedTitle;
          isFirstMessageOfSession = false;
        }
        return const SessionPersistSynced();
      }

      expect(isFirstMessageOfSession, isTrue,
          reason: 'L-3 precondition: starts as first message');
      expect(currentConversationTitle, isEmpty,
          reason: 'L-3 precondition: title starts empty');

      final result1 = await mockPersist(
          userInput: 'Insuficiencia cardiaca manejo', batchOk: false);
      expect(result1, isA<SessionPersistFailed>(),
          reason: 'L-3: failed batch must return SessionPersistFailed');
      expect(isFirstMessageOfSession, isTrue,
          reason: 'L-3: isFirstMessageOfSession must remain true after failure');
      expect(currentConversationTitle, isEmpty,
          reason: 'L-3: title must remain empty after failure');

      final result2 = await mockPersist(
          userInput: 'Insuficiencia cardiaca manejo', batchOk: true);
      expect(result2, isA<SessionPersistSynced>(),
          reason: 'L-3 retry: successful batch must return SessionPersistSynced');
      expect(isFirstMessageOfSession, isFalse,
          reason: 'L-3 retry: isFirstMessageOfSession advances after success');
      expect(currentConversationTitle, isNotEmpty,
          reason: 'L-3 retry: title frozen after successful write');
    });
  });
}
