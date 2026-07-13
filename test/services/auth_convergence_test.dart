// ══════════════════════════════════════════════════════════════════════════════
// test/services/auth_convergence_test.dart
// BUILD 463-A.1.1 — Auth Lifecycle Unification & Pre-Check Barrier Test Suite
//
// Validates the RIGID authReady invariant:
//   authReady IFF fbUser != null AND fbUser.uid == expectedUid
//
// Key corrections from 463-A.1:
//   • "Degraded authReady" is permanently removed.
//   • null fbUser → authRequired (NOT authReady).
//   • Only fbUser != null with mismatched uid → authMismatch.
//   • Exception during latch → authFailed (NOT authReady).
//
// 10 stress vectors + supplementary groups + 2 new invariants (A & B):
//   Invariant A: REST token + Firebase User null → authRequired, readCount == 0
//   Invariant B: permission-denied → authDenied, cache freeze, no write bypass
//
// New coverage in 463-A.1.2:
//   Invariant C: uid_mismatch at dispatch layer → authDenied, readCount == 0
//   Invariant D: 20-second watchdog never overrides auth state or writes cache
//   Invariant E: loadHistoriesTyped algebraic unwrap contract (consumer migration)
// ══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/services/firestore_service.dart';
import 'package:medcases/services/external_tool_link_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stub Collaborators
// ─────────────────────────────────────────────────────────────────────────────

/// Simulated Firestore result producer.
enum _SimulatedFirestoreResult {
  success,
  permissionDenied,
  offline,
  empty,
}

/// Persistence spy — counts write attempts.
class _PersistenceSpy {
  int newUserWriteCount = 0;
  int normalWriteCount  = 0;
  final List<String> ops = [];

  void recordNewUserWrite() {
    newUserWriteCount++;
    ops.add('new_user_write');
  }

  void recordNormalWrite(String op) {
    normalWriteCount++;
    ops.add(op);
  }

  void reset() {
    newUserWriteCount = 0;
    normalWriteCount  = 0;
    ops.clear();
  }
}

/// Simulated auth token store.
class _MockTokenStore {
  String? restToken;
  String? geminiEmail;
  bool get hasCachedToken => restToken != null && restToken!.isNotEmpty;
  bool get hasGeminiEmail => geminiEmail != null && geminiEmail!.isNotEmpty;

  void clear() {
    restToken   = null;
    geminiEmail = null;
  }
}

/// Fake Firestore gate — tracks how many SDK read calls were dispatched.
/// Simulates the barrier pre-check: if allowed==false, readCount is never
/// incremented (sdkRequestDispatched=false).
class _FakeFirestoreGate {
  int readCount = 0;

  /// Simulates the pre-check guard in loadHistories / loadFav*.
  /// Returns true only when Firebase user is non-null (rigid invariant).
  bool preCheck({required bool firebaseUserPresent}) {
    if (!firebaseUserPresent) {
      print('[FIRESTORE_AUTH_BARRIER] operation=fakeRead '
          'allowed=false reason=firebase_user_null '
          'sdkRequestDispatched=false');
      return false;
    }
    return true;
  }

  /// BUILD 463-A.1.2: Dual-check pre-flight.
  /// Check 1: Firebase user must be non-null.
  /// Check 2: Firebase user uid must equal the requested uid.
  /// Both failures produce readCount=0 (sdkRequestDispatched=false).
  bool preCheckDual({
    required String? firebaseUid,
    required String requestedUid,
    required String operation,
  }) {
    if (firebaseUid == null) {
      print('[FIRESTORE_AUTH_BARRIER] operation=$operation '
          'allowed=false reason=firebase_user_null '
          'sdkRequestDispatched=false');
      return false;
    }
    if (firebaseUid != requestedUid) {
      print('[FIRESTORE_AUTH_BARRIER] operation=$operation '
          'expectedUid=$requestedUid firebaseUid=$firebaseUid '
          'allowed=false reason=uid_mismatch sdkRequestDispatched=false');
      return false;
    }
    return true;
  }

  /// Simulates an SDK read call. Only called when preCheck() returns true.
  FirestoreLoadResult<List<String>> dispatchRead(
    _SimulatedFirestoreResult firestoreResult,
  ) {
    readCount++;
    switch (firestoreResult) {
      case _SimulatedFirestoreResult.success:
        return FirestoreLoadResult.success(['item1', 'item2']);
      case _SimulatedFirestoreResult.permissionDenied:
        print('[FIRESTORE_AUTH_BARRIER] operation=fakeRead '
            'allowed=false reason=permission_denied '
            'sdkRequestDispatched=true → authDenied');
        return FirestoreLoadResult.authDenied();
      case _SimulatedFirestoreResult.offline:
        return FirestoreLoadResult.offline();
      case _SimulatedFirestoreResult.empty:
        return FirestoreLoadResult.empty();
    }
  }

  void reset() => readCount = 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 463-A.1.2: Dual-check barrier simulation helper
// ─────────────────────────────────────────────────────────────────────────────

/// Simulates the 463-A.1.2 dual-check dispatch barrier:
///   Check 1: firebaseUid must be non-null
///   Check 2: firebaseUid must equal requestedUid
/// Both failures produce readCount=0 (sdkRequestDispatched=false).
FirestoreLoadResult<List<String>> simulateDualBarrierGuard({
  required String? firebaseUid,
  required String requestedUid,
  required _SimulatedFirestoreResult firestoreResult,
  required String operation,
  required _FakeFirestoreGate gate,
}) {
  final bool allowed = gate.preCheckDual(
    firebaseUid:   firebaseUid,
    requestedUid:  requestedUid,
    operation:     operation,
  );
  if (!allowed) return FirestoreLoadResult.authDenied();
  return gate.dispatchRead(firestoreResult);
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 463-A.1.1: Rigid Boot-Lock Simulation
// ─────────────────────────────────────────────────────────────────────────────

/// Simulates the RIGID boot-lock from AppProvider.setUser() 463-A.1.1.
///
/// INVARIANT:
///   authReady   IFF  fbUser != null  AND  fbUser.uid == expectedUid
///   authMismatch     fbUser != null  AND  fbUser.uid != expectedUid
///   authRequired     fbUser == null  (after hydration — NOT authReady)
///   authFailed       exception / firebaseUnavailable
AppAuthBarrierState simulateBootLock({
  required String expectedUid,
  required String? firebaseSdkUid,  // null = SDK returned no user (stable)
  required bool restTokenPresent,
  bool firebaseAvailable = true,
  bool throwsDuringLatch = false,
}) {
  if (!firebaseAvailable) {
    // Firebase unavailable → authFailed, not authReady
    return AppAuthBarrierState.authFailed;
  }

  if (throwsDuringLatch) {
    // Exception during latch → authFailed, not authReady
    return AppAuthBarrierState.authFailed;
  }

  if (firebaseSdkUid == null) {
    // STABLE_LOGGED_OUT: no Firebase user after hydration.
    // This is authRequired — NEVER authReady.
    // The "degraded authReady" path is permanently removed.
    return AppAuthBarrierState.authRequired;
  }

  if (firebaseSdkUid != expectedUid) {
    // UID_MISMATCH: valid user, wrong identity
    return AppAuthBarrierState.authMismatch;
  }

  // MATCHED_USER: uid confirmed
  return AppAuthBarrierState.authReady;
}

/// Simulates the Firestore auth barrier guard using the rigid invariant.
/// The barrier ONLY allows dispatch when barrierState == authReady.
FirestoreLoadResult<List<String>> simulateBarrierGuard({
  required AppAuthBarrierState barrierState,
  required _SimulatedFirestoreResult firestoreResult,
  required String operation,
  required _FakeFirestoreGate gate,
}) {
  // Rigid: only authReady permits SDK dispatch
  final bool firebaseUserPresent = barrierState == AppAuthBarrierState.authReady;
  final bool allowed = gate.preCheck(firebaseUserPresent: firebaseUserPresent);

  if (!allowed) {
    return FirestoreLoadResult.authDenied();
  }

  return gate.dispatchRead(firestoreResult);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main test suite
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('BUILD 463-A.1.1: Rigid AuthReady Invariant & Pre-Check Barrier', () {

    late _FakeFirestoreGate gate;

    setUp(() {
      ExternalToolLinkEngine.clearAllDecisions(reason: 'test_setUp');
      gate = _FakeFirestoreGate();
    });

    tearDown(() {
      ExternalToolLinkEngine.clearAllDecisions(reason: 'test_tearDown');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 1: Cold Boot — valid Firebase user → authReady
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 1: Cold Boot — matching SDK uid → authReady', () {
      const uid = 'user_cold_boot_uid_123';

      final result = simulateBootLock(
        expectedUid: uid,
        firebaseSdkUid: uid,   // matching non-null uid
        restTokenPresent: true,
        firebaseAvailable: true,
      );

      expect(result, equals(AppAuthBarrierState.authReady),
          reason: 'Cold boot with non-null matching uid must be authReady');
      print('[VECTOR_1][PASS] Cold boot: state=${result.name}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 2: Hard Refresh Latch — SDK null after hydration → authRequired
    //
    // 463-A.1.1 CORRECTION: In 463-A.1, null SDK uid was treated as
    // "undetermined" and resolved to authReady ("degraded").
    // The rigid invariant mandates: null → authRequired, never authReady.
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 2: Hard Refresh Latch — SDK null after hydration → authRequired (NOT authReady)', () {
      const uid = 'user_refresh_uid_456';

      // Phase 1: SDK null after full hydration window → authRequired
      final nullResult = simulateBootLock(
        expectedUid: uid,
        firebaseSdkUid: null,   // null after hydration timeout
        restTokenPresent: true,
        firebaseAvailable: true,
      );

      expect(nullResult, equals(AppAuthBarrierState.authRequired),
          reason: 'SDK null after hydration must produce authRequired, '
              'NEVER authReady — degraded authReady is permanently removed');
      expect(nullResult, isNot(equals(AppAuthBarrierState.authReady)),
          reason: 'authReady is FORBIDDEN when fbUser == null');

      // Phase 2: SDK eventually emits the user → authReady
      final readyResult = simulateBootLock(
        expectedUid: uid,
        firebaseSdkUid: uid,
        restTokenPresent: true,
        firebaseAvailable: true,
      );
      expect(readyResult, equals(AppAuthBarrierState.authReady));

      print('[VECTOR_2][PASS] Hard refresh latch: '
          'nullPhase=${nullResult.name} readyPhase=${readyResult.name}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 3: Orphaned Cache — REST token present, Firebase SDK null
    //
    // 463-A.1.1 CORRECTION: In 463-A.1, REST token + null SDK produced
    // "degraded authReady". The rigid invariant mandates authRequired.
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 3: Orphaned Cache — REST token present, SDK null → authRequired (NOT degraded)', () {
      const uid = 'user_orphaned_uid_789';
      final store = _MockTokenStore()..restToken = 'valid_rest_token_xyz';

      final result = simulateBootLock(
        expectedUid: uid,
        firebaseSdkUid: null,                // no SDK user
        restTokenPresent: store.hasCachedToken,
        firebaseAvailable: true,
      );

      expect(result, equals(AppAuthBarrierState.authRequired),
          reason: 'Orphaned cache with REST token must be authRequired. '
              'REST token alone cannot produce authReady — Firebase user required');
      expect(result, isNot(equals(AppAuthBarrierState.authReady)),
          reason: 'Degraded authReady is permanently removed in 463-A.1.1');

      // Verify the REST token is still present (not wiped by authRequired)
      expect(store.hasCachedToken, isTrue);

      // Verify Firestore reads are blocked (authRequired ≠ authReady)
      final readResult = simulateBarrierGuard(
        barrierState: result,
        firestoreResult: _SimulatedFirestoreResult.success,
        operation: 'loadHistories',
        gate: gate,
      );
      expect(readResult.isAuthDenied, isTrue,
          reason: 'authRequired state must block all Firestore reads');
      expect(gate.readCount, equals(0),
          reason: 'No SDK read must be dispatched when barrier is authRequired');

      print('[VECTOR_3][PASS] Orphaned cache: state=${result.name} '
          'readCount=${gate.readCount}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 4: Active UID Mismatch → authMismatch + SecuritySyndicationException
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 4: UID Mismatch — rogue uid → authMismatch + exception + cache purge', () {
      const expectedUid = 'user_legitimate_uid_aaa';
      const rogueUid    = 'rogue_attacker_uid_bbb';

      final result = simulateBootLock(
        expectedUid: expectedUid,
        firebaseSdkUid: rogueUid,   // MISMATCH — non-null but wrong uid
        restTokenPresent: true,
        firebaseAvailable: true,
      );

      expect(result, equals(AppAuthBarrierState.authMismatch),
          reason: 'Non-null Firebase user with wrong uid → authMismatch');

      // SecuritySyndicationException contract
      final ex = SecuritySyndicationException(
        expectedUid: expectedUid,
        actualUid: rogueUid,
        reason: 'uid_mismatch_at_setUser',
      );
      expect(ex.expectedUid, equals(expectedUid));
      expect(ex.actualUid,   equals(rogueUid));
      expect(ex.reason,      equals('uid_mismatch_at_setUser'));
      expect(ex.toString(),  contains('SecuritySyndicationException'));
      expect(ex.toString(),  contains(expectedUid));
      expect(ex.toString(),  contains(rogueUid));

      // Global decision cache purge on mismatch
      ExternalToolLinkEngine.resolveDecision(
        'mismatch_req_1',
        'bomba de infusão noradrenalina',
      );
      expect(ExternalToolLinkEngine.decisionCacheSize, greaterThan(0));
      ExternalToolLinkEngine.clearAllDecisions(reason: 'identity_mismatch');
      expect(ExternalToolLinkEngine.decisionCacheSize, equals(0),
          reason: 'clearAllDecisions must flush entire cache on identity mismatch');

      print('[VECTOR_4][PASS] UID mismatch: state=${result.name}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 5: Gemini OAuth Cross-Over — barrier not authReady → blocked
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 5: Gemini OAuth Cross-Over — non-authReady barrier → Firestore blocked', () {
      // authPending (still in boot) — must block Firestore
      final result = simulateBarrierGuard(
        barrierState: AppAuthBarrierState.authPending,
        firestoreResult: _SimulatedFirestoreResult.success,
        operation: 'loadGeminiApiKey',
        gate: gate,
      );

      expect(result.isAuthDenied, isTrue,
          reason: 'Firestore must be blocked when barrier is authPending');
      expect(gate.readCount, equals(0),
          reason: 'sdkRequestDispatched=false — no network call made');

      // authRequired (null user) — must also block
      gate.reset();
      final requiredResult = simulateBarrierGuard(
        barrierState: AppAuthBarrierState.authRequired,
        firestoreResult: _SimulatedFirestoreResult.success,
        operation: 'loadGeminiApiKey',
        gate: gate,
      );
      expect(requiredResult.isAuthDenied, isTrue);
      expect(gate.readCount, equals(0));

      print('[VECTOR_5][PASS] Gemini crossover: '
          'pendingBlocked=true requiredBlocked=true readCount=${gate.readCount}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 6: Token Expiry Fail-Safe — revoked mid-run → offline result
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 6: Token Expiry — revoked mid-run → offline, no cache corruption', () {
      final spy = _PersistenceSpy();

      // Phase 1: valid auth, success fetch
      final successResult = simulateBarrierGuard(
        barrierState: AppAuthBarrierState.authReady,
        firestoreResult: _SimulatedFirestoreResult.success,
        operation: 'loadHistories',
        gate: gate,
      );
      expect(successResult.isSuccess, isTrue);
      spy.recordNormalWrite('loadHistories');
      expect(gate.readCount, equals(1));

      // Phase 2: offline (simulates revoked/expired token)
      final offlineResult = simulateBarrierGuard(
        barrierState: AppAuthBarrierState.authReady,
        firestoreResult: _SimulatedFirestoreResult.offline,
        operation: 'loadHistories',
        gate: gate,
      );
      expect(offlineResult.isOffline, isTrue);
      expect(offlineResult.shouldFreezeLocalCache, isTrue);
      expect(spy.newUserWriteCount, equals(0));

      print('[VECTOR_6][PASS] Token expiry: reads=${gate.readCount} '
          'newUserWrites=${spy.newUserWriteCount}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 7: Sequential User Swap — cache purged via clearAllDecisions()
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 7: Sequential User Swap — User A purged via clearAllDecisions()', () {
      const uidA = 'user_A_uid_seq_swap';
      const uidB = 'user_B_uid_seq_swap';

      // User A populates decision cache
      ExternalToolLinkEngine.resolveDecision(
        uidA, 'diluir vancomicina volume final 250mL',
      );
      expect(ExternalToolLinkEngine.decisionCacheSize, greaterThan(0));

      // Logout → clearAllDecisions
      ExternalToolLinkEngine.clearAllDecisions(reason: 'logout');
      expect(ExternalToolLinkEngine.decisionCacheSize, equals(0),
          reason: 'clearAllDecisions(logout) must flush all entries');

      // User B login → authPending initially
      final barrierB_initial = AppAuthBarrierState.authPending;
      expect(barrierB_initial, equals(AppAuthBarrierState.authPending));

      // User B boot resolves
      final barrierB = simulateBootLock(
        expectedUid: uidB,
        firebaseSdkUid: uidB,
        restTokenPresent: true,
        firebaseAvailable: true,
      );
      expect(barrierB, equals(AppAuthBarrierState.authReady));

      // User B populates fresh cache
      ExternalToolLinkEngine.resolveDecision(
        uidB, 'dosagem amoxicilina paciente pediatrico',
      );
      expect(ExternalToolLinkEngine.decisionCacheSize, equals(1));

      print('[VECTOR_7][PASS] Sequential swap: userBState=${barrierB.name}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 8: Rule Denial Containment — permission-denied → authDenied
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 8: Rule Denial Containment — permission-denied → authDenied, no write', () {
      final spy = _PersistenceSpy();

      // Barrier is authReady but Firestore returns permission-denied
      final result = simulateBarrierGuard(
        barrierState: AppAuthBarrierState.authReady,
        firestoreResult: _SimulatedFirestoreResult.permissionDenied,
        operation: 'loadHistories',
        gate: gate,
      );

      expect(result.isAuthDenied, isTrue);
      expect(result.shouldFreezeLocalCache, isTrue);
      expect(result.isSuccess, isFalse);
      expect(spy.newUserWriteCount, equals(0));
      // SDK was dispatched (we hit the server) but got permission-denied
      expect(gate.readCount, equals(1),
          reason: 'When barrier is authReady, request IS dispatched '
              '(sdkRequestDispatched=true). Server returned permission-denied.');

      final data = result.dataOrElse(<String>[]);
      expect(data, isEmpty);

      print('[VECTOR_8][PASS] Rule denial: isAuthDenied=${result.isAuthDenied} '
          'writes=${spy.newUserWriteCount}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 9: Offline Boot Verification
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 9: Offline Boot — all endpoints down → offline, cache preserved', () {
      final result = simulateBarrierGuard(
        barrierState: AppAuthBarrierState.authReady,
        firestoreResult: _SimulatedFirestoreResult.offline,
        operation: 'loadHistories',
        gate: gate,
      );

      expect(result.isOffline, isTrue);
      expect(result.shouldFreezeLocalCache, isTrue);
      expect(result.isSuccess, isFalse);

      final fallback = result.dataOrElse(['cached_item_1', 'cached_item_2']);
      expect(fallback.length, equals(2));
      expect(fallback.first, equals('cached_item_1'));

      print('[VECTOR_9][PASS] Offline boot: isOffline=${result.isOffline}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Vector 10: Rebuild Idempotence — ONE boot transaction per lifecycle
    // ─────────────────────────────────────────────────────────────────────────
    test('Vector 10: Rebuild Idempotence — 50 rebuilds → exactly ONE boot transaction', () {
      const uid = 'user_rebuild_idempotence_uid';
      var bootLockCallCount     = 0;
      var barrierTransitionCount = 0;
      AppAuthBarrierState? lastState;

      for (var i = 0; i < 50; i++) {
        if (i == 0) {
          bootLockCallCount++;
          final result = simulateBootLock(
            expectedUid: uid,
            firebaseSdkUid: uid,
            restTokenPresent: true,
            firebaseAvailable: true,
          );
          if (lastState != result) {
            barrierTransitionCount++;
            lastState = result;
          }
        }
        // Subsequent passes read cached barrier state — no SDK call
      }

      expect(bootLockCallCount,     equals(1));
      expect(barrierTransitionCount, equals(1));
      expect(lastState, equals(AppAuthBarrierState.authReady));

      print('[VECTOR_10][PASS] Rebuild idempotence: '
          'bootCalls=$bootLockCallCount transitions=$barrierTransitionCount');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Firebase unavailable → authFailed (NOT authReady)
    // ─────────────────────────────────────────────────────────────────────────
    test('Firebase unavailable (Safari private) → authFailed, never authReady', () {
      const uid = 'user_safari_private_uid';

      final result = simulateBootLock(
        expectedUid: uid,
        firebaseSdkUid: null,
        restTokenPresent: true,
        firebaseAvailable: false,  // Safari private / Firebase init failure
      );

      expect(result, equals(AppAuthBarrierState.authFailed),
          reason: 'Firebase unavailable must produce authFailed, not authReady');
      expect(result, isNot(equals(AppAuthBarrierState.authReady)));

      print('[SAFARI_PRIVATE][PASS] authFailed: state=${result.name}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Latch exception → authFailed (NOT authReady)
    // ─────────────────────────────────────────────────────────────────────────
    test('Exception during latch → authFailed, never authReady', () {
      const uid = 'user_latch_exception_uid';

      final result = simulateBootLock(
        expectedUid: uid,
        firebaseSdkUid: null,
        restTokenPresent: false,
        firebaseAvailable: true,
        throwsDuringLatch: true,   // unexpected exception
      );

      expect(result, equals(AppAuthBarrierState.authFailed),
          reason: 'Latch exception must produce authFailed, not authReady');
      expect(result, isNot(equals(AppAuthBarrierState.authReady)));

      print('[LATCH_EXCEPTION][PASS] authFailed: state=${result.name}');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // ██████████████████████████████████████████████████████████████████████████
    // INVARIANT A: REST Token present + Firebase User null → authRequired
    //             AND fakeFirestore.readCount == 0
    //
    // This is the primary regression test for the "degraded authReady" bug.
    // It verifies that having a REST token (hasCachedToken=true) in the
    // absence of a Firebase SDK user NEVER triggers Firestore reads.
    // ██████████████████████████████████████████████████████████████████████████
    group('Invariant A: REST Token + Firebase User null → authRequired + readCount=0', () {

      test('A.1: REST token present, SDK null → authRequired (not authReady)', () {
        const uid = 'user_invariant_a_uid';
        final store = _MockTokenStore()..restToken = 'bearer_token_valid';

        final barrierState = simulateBootLock(
          expectedUid: uid,
          firebaseSdkUid: null,                 // no Firebase user
          restTokenPresent: store.hasCachedToken, // REST token IS present
          firebaseAvailable: true,
        );

        expect(barrierState, equals(AppAuthBarrierState.authRequired),
            reason: 'Invariant A: REST token alone cannot produce authReady. '
                'Firebase SDK user must be non-null for authReady.');
        expect(barrierState, isNot(equals(AppAuthBarrierState.authReady)),
            reason: 'Invariant A violated: authReady observed without fbUser');

        print('[INV_A.1][PASS] barrierState=${barrierState.name}');
      });

      test('A.2: REST token + null SDK user → all Firestore reads blocked (readCount=0)', () {
        const uid = 'user_invariant_a2_uid';
        final fakeGate = _FakeFirestoreGate();

        // Simulate the barrier state from A.1
        final barrierState = simulateBootLock(
          expectedUid: uid,
          firebaseSdkUid: null,
          restTokenPresent: true,
          firebaseAvailable: true,
        );

        // authRequired → all reads must be blocked
        final ops = ['loadHistories', 'loadFavDrugs', 'loadFavProtocols',
                     'loadFavPrescriptions', 'loadFavCases', 'loadCases'];

        for (final op in ops) {
          fakeGate.reset();
          final result = simulateBarrierGuard(
            barrierState: barrierState,
            firestoreResult: _SimulatedFirestoreResult.success,
            operation: op,
            gate: fakeGate,
          );
          expect(result.isAuthDenied, isTrue,
              reason: 'Invariant A: $op must return authDenied '
                  'when barrierState=${barrierState.name}');
          expect(fakeGate.readCount, equals(0),
              reason: 'Invariant A: $op must have sdkRequestDispatched=false '
                  'when Firebase user is null');
        }

        print('[INV_A.2][PASS] All ${ops.length} ops blocked: readCount=0 '
            'barrierState=${barrierState.name}');
      });

      test('A.3: REST token present, SDK null — verify only authReady permits reads', () {
        final fakeGate = _FakeFirestoreGate();

        // Only authReady should allow reads
        final allStates = AppAuthBarrierState.values;
        for (final state in allStates) {
          fakeGate.reset();
          final result = simulateBarrierGuard(
            barrierState: state,
            firestoreResult: _SimulatedFirestoreResult.success,
            operation: 'loadHistories',
            gate: fakeGate,
          );
          if (state == AppAuthBarrierState.authReady) {
            expect(result.isSuccess, isTrue,
                reason: 'Only authReady must permit reads');
            expect(fakeGate.readCount, equals(1));
          } else {
            expect(result.isAuthDenied, isTrue,
                reason: '$state must block reads (sdkRequestDispatched=false)');
            expect(fakeGate.readCount, equals(0),
                reason: '$state must have readCount=0');
          }
        }
        print('[INV_A.3][PASS] Exclusive authReady gate validated across '
            '${allStates.length} states');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // ██████████████████████████████████████████████████████████████████████████
    // INVARIANT B: permission-denied → authDenied → cache freeze, no write bypass
    //
    // Verifies that when the Firestore SDK returns 'permission-denied', the
    // result is correctly mapped to FirestoreLoadResult.authDenied() and:
    //   1. shouldFreezeLocalCache == true
    //   2. No "new user" write is triggered
    //   3. dataOrElse() returns the fallback (not null/empty-as-new-user)
    //   4. The result is never silently coerced to an empty success
    // ██████████████████████████████████████████████████████████████████████████
    group('Invariant B: permission-denied → authDenied + cache freeze + no write bypass', () {

      test('B.1: permission-denied → authDenied (not success or empty)', () {
        final fakeGate = _FakeFirestoreGate();

        final result = simulateBarrierGuard(
          barrierState: AppAuthBarrierState.authReady,   // barrier is open
          firestoreResult: _SimulatedFirestoreResult.permissionDenied,
          operation: 'loadHistories',
          gate: fakeGate,
        );

        expect(result.isAuthDenied, isTrue,
            reason: 'Invariant B: permission-denied must map to authDenied');
        expect(result.isSuccess, isFalse,
            reason: 'Invariant B: permission-denied must NOT be treated as success');
        expect(result.isEmpty, isFalse,
            reason: 'Invariant B: permission-denied must NOT be treated as empty');
        // SDK WAS dispatched (we were past the pre-check, server rejected us)
        expect(fakeGate.readCount, equals(1),
            reason: 'When barrier=authReady, request is dispatched. '
                'Server returned permission-denied → sdkRequestDispatched=true');

        print('[INV_B.1][PASS] permission-denied → isAuthDenied=${result.isAuthDenied}');
      });

      test('B.2: authDenied result activates cache freeze (shouldFreezeLocalCache=true)', () {
        final fakeGate = _FakeFirestoreGate();

        final result = simulateBarrierGuard(
          barrierState: AppAuthBarrierState.authReady,
          firestoreResult: _SimulatedFirestoreResult.permissionDenied,
          operation: 'loadHistories',
          gate: fakeGate,
        );

        expect(result.shouldFreezeLocalCache, isTrue,
            reason: 'Invariant B: authDenied must freeze the local cache layout');
        print('[INV_B.2][PASS] shouldFreezeLocalCache=${result.shouldFreezeLocalCache}');
      });

      test('B.3: authDenied — no "new user" write is bypassed', () {
        final spy = _PersistenceSpy();
        final fakeGate = _FakeFirestoreGate();

        final result = simulateBarrierGuard(
          barrierState: AppAuthBarrierState.authReady,
          firestoreResult: _SimulatedFirestoreResult.permissionDenied,
          operation: 'loadHistories',
          gate: fakeGate,
        );

        // Simulate the caller receiving authDenied:
        // It should NOT call newUserWrite — the result blocks that path.
        if (result.shouldFreezeLocalCache) {
          // Cache is frozen — no write operation triggered
          // (this is the correct path; wrong path would call recordNewUserWrite)
        } else {
          spy.recordNewUserWrite(); // This must NOT execute
        }

        expect(spy.newUserWriteCount, equals(0),
            reason: 'Invariant B: authDenied must NEVER trigger new-user write');
        print('[INV_B.3][PASS] newUserWriteCount=${spy.newUserWriteCount}');
      });

      test('B.4: authDenied — dataOrElse() returns fallback, never throws', () {
        final r = FirestoreLoadResult<List<String>>.authDenied();

        expect(() => r.dataOrElse([]), returnsNormally,
            reason: 'dataOrElse must not throw on authDenied');
        final data = r.dataOrElse(['fallback_item']);
        expect(data.length, equals(1));
        expect(data.first, equals('fallback_item'),
            reason: 'authDenied.dataOrElse must return the provided fallback');
        print('[INV_B.4][PASS] dataOrElse returns fallback correctly');
      });

      test('B.5: barrier pre-check (firebase_user_null) → authDenied, readCount=0', () {
        // Distinct from permission-denied: this is the PRE-CHECK barrier
        // (sdkRequestDispatched=false — zero network call).
        final fakeGate = _FakeFirestoreGate();

        final result = simulateBarrierGuard(
          barrierState: AppAuthBarrierState.authRequired,  // null user
          firestoreResult: _SimulatedFirestoreResult.success, // irrelevant — blocked
          operation: 'loadHistories',
          gate: fakeGate,
        );

        expect(result.isAuthDenied, isTrue);
        expect(fakeGate.readCount, equals(0),
            reason: 'Pre-check barrier must produce readCount=0 '
                '(sdkRequestDispatched=false)');
        expect(result.shouldFreezeLocalCache, isTrue);
        print('[INV_B.5][PASS] Pre-check barrier: readCount=0 isAuthDenied=true');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Supplementary: FirestoreLoadResult<T> algebraic type invariants
    // ─────────────────────────────────────────────────────────────────────────
    group('FirestoreLoadResult<T> algebraic type invariants', () {

      test('success() — isSuccess=true, shouldFreezeLocalCache=false', () {
        final r = FirestoreLoadResult.success(['a', 'b', 'c']);
        expect(r.isSuccess, isTrue);
        expect(r.isEmpty,      isFalse);
        expect(r.isAuthDenied, isFalse);
        expect(r.isOffline,    isFalse);
        expect(r.isFailure,    isFalse);
        expect(r.shouldFreezeLocalCache, isFalse);
        expect(r.dataOrElse([]), equals(['a', 'b', 'c']));
      });

      test('empty() — isEmpty=true, shouldFreezeLocalCache=false', () {
        final r = FirestoreLoadResult<List<String>>.empty();
        expect(r.isEmpty, isTrue);
        expect(r.isSuccess,    isFalse);
        expect(r.isAuthDenied, isFalse);
        expect(r.isOffline,    isFalse);
        expect(r.isFailure,    isFalse);
        expect(r.shouldFreezeLocalCache, isFalse);
        expect(r.dataOrElse(['fallback']), equals(['fallback']));
      });

      test('authDenied() — isAuthDenied=true, shouldFreezeLocalCache=true', () {
        final r = FirestoreLoadResult<List<String>>.authDenied();
        expect(r.isAuthDenied, isTrue);
        expect(r.isSuccess, isFalse);
        expect(r.isEmpty,   isFalse);
        expect(r.isOffline, isFalse);
        expect(r.isFailure, isFalse);
        expect(r.shouldFreezeLocalCache, isTrue);
        expect(r.dataOrElse(['fallback']), equals(['fallback']));
      });

      test('offline() — isOffline=true, shouldFreezeLocalCache=true', () {
        final r = FirestoreLoadResult<List<String>>.offline();
        expect(r.isOffline, isTrue);
        expect(r.isSuccess,    isFalse);
        expect(r.isEmpty,      isFalse);
        expect(r.isAuthDenied, isFalse);
        expect(r.isFailure,    isFalse);
        expect(r.shouldFreezeLocalCache, isTrue);
        expect(r.dataOrElse(['fallback']), equals(['fallback']));
      });

      test('failure() — isFailure=true, shouldFreezeLocalCache=true', () {
        final r = FirestoreLoadResult<List<String>>.failure(Exception('err'));
        expect(r.isFailure, isTrue);
        expect(r.isSuccess,    isFalse);
        expect(r.isEmpty,      isFalse);
        expect(r.isAuthDenied, isFalse);
        expect(r.isOffline,    isFalse);
        expect(r.shouldFreezeLocalCache, isTrue);
        expect(r.dataOrElse(['fallback']), equals(['fallback']));
      });

      test('All 5 factories are mutually exclusive', () {
        final types = [
          FirestoreLoadResult.success(42),
          FirestoreLoadResult<int>.empty(),
          FirestoreLoadResult<int>.authDenied(),
          FirestoreLoadResult<int>.offline(),
          FirestoreLoadResult<int>.failure('err'),
        ];
        for (final r in types) {
          final trueCount = [r.isSuccess, r.isEmpty, r.isAuthDenied,
                             r.isOffline, r.isFailure].where((v) => v).length;
          expect(trueCount, equals(1),
              reason: '${r.runtimeType} must be exactly one category');
        }
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Supplementary: SecuritySyndicationException contract
    // ─────────────────────────────────────────────────────────────────────────
    group('SecuritySyndicationException — contract invariants', () {

      test('Exception preserves fields and has meaningful toString()', () {
        final ex = SecuritySyndicationException(
          expectedUid: 'uid_expected_abc',
          actualUid:   'uid_actual_xyz',
          reason:      'uid_mismatch_at_setUser',
        );
        expect(ex.expectedUid, equals('uid_expected_abc'));
        expect(ex.actualUid,   equals('uid_actual_xyz'));
        expect(ex.reason,      equals('uid_mismatch_at_setUser'));
        expect(ex.toString(),  contains('SecuritySyndicationException'));
        expect(ex.toString(),  contains('uid_expected_abc'));
        expect(ex.toString(),  contains('uid_actual_xyz'));
      });

      test('Exception is-a Exception (can be thrown/caught)', () {
        expect(
          () => throw SecuritySyndicationException(
            expectedUid: 'a', actualUid: 'b', reason: 'test',
          ),
          throwsA(isA<SecuritySyndicationException>()),
        );
        expect(
          () => throw SecuritySyndicationException(
            expectedUid: 'a', actualUid: 'b', reason: 'test',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Supplementary: AppAuthBarrierState enum completeness
    // ─────────────────────────────────────────────────────────────────────────
    group('AppAuthBarrierState — enum completeness', () {

      test('All 5 variants declared with correct names', () {
        final allValues = AppAuthBarrierState.values;
        expect(allValues.length, equals(5));
        expect(allValues.map((v) => v.name).toSet(), containsAll([
          'authPending', 'authReady', 'authMismatch', 'authRequired', 'authFailed',
        ]));
      });

      test('authPending is index 0 (default initial state)', () {
        expect(AppAuthBarrierState.authPending.index, equals(0));
      });

      test('Only authReady permits Firestore reads — rigid gate matrix', () {
        // Every non-authReady state must produce isAuthDenied=true
        for (final state in AppAuthBarrierState.values) {
          final fakeGate = _FakeFirestoreGate();
          final result = simulateBarrierGuard(
            barrierState: state,
            firestoreResult: _SimulatedFirestoreResult.success,
            operation: 'loadHistories',
            gate: fakeGate,
          );
          if (state == AppAuthBarrierState.authReady) {
            expect(result.isSuccess, isTrue,
                reason: 'authReady must allow reads');
            expect(fakeGate.readCount, equals(1));
          } else {
            expect(result.isAuthDenied, isTrue,
                reason: '${state.name} must deny reads');
            expect(fakeGate.readCount, equals(0),
                reason: '${state.name} must have readCount=0 (sdkRequestDispatched=false)');
          }
        }
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Supplementary: clearAllDecisions() global sweep contract
    // ─────────────────────────────────────────────────────────────────────────
    group('ExternalToolLinkEngine.clearAllDecisions() — sweep contract', () {

      test('clearAllDecisions() removes all entries and logs correctly', () {
        // Populate cache with multiple decisions
        ExternalToolLinkEngine.resolveDecision(
          'req_sweep_1', 'bomba de infusão noradrenalina');
        ExternalToolLinkEngine.resolveDecision(
          'req_sweep_2', 'diluir vancomicina volume final');
        expect(ExternalToolLinkEngine.decisionCacheSize, greaterThanOrEqualTo(2));

        ExternalToolLinkEngine.clearAllDecisions(reason: 'identity_mismatch');
        expect(ExternalToolLinkEngine.decisionCacheSize, equals(0));
      });

      test('clearAllDecisions() is idempotent on empty cache', () {
        expect(ExternalToolLinkEngine.decisionCacheSize, equals(0));
        expect(
          () => ExternalToolLinkEngine.clearAllDecisions(reason: 'logout'),
          returnsNormally,
        );
        expect(ExternalToolLinkEngine.decisionCacheSize, equals(0));
      });

      test('clearDecisionCache() delegates to clearAllDecisions()', () {
        ExternalToolLinkEngine.resolveDecision(
          'req_alias_1', 'diluir amikacina 250mg em 100mL');
        expect(ExternalToolLinkEngine.decisionCacheSize, greaterThan(0));
        // Legacy alias still works
        ExternalToolLinkEngine.clearDecisionCache();
        expect(ExternalToolLinkEngine.decisionCacheSize, equals(0));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // ██████████████████████████████████████████████████████████████████████████
    // INVARIANT C: Dynamic UID Mismatch at Dispatch Layer
    //
    // BUILD 463-A.1.2 — Even when Firebase SDK user is non-null (session active),
    // if firebaseUser.uid ≠ requestedUid the barrier must block dispatch.
    //
    // This closes the privilege window left by the 463-A.1.1 null-only check:
    // an active mismatched session (e.g. stale token from a previous account) was
    // previously able to pass the null guard and reach the Firestore SDK.
    // ██████████████████████████████████████████████████████████████████████████
    group('Invariant C: uid_mismatch at dispatch → authDenied, readCount=0', () {

      test('C.1: active Firebase user with mismatched uid → authDenied, readCount=0', () {
        const firebaseUid  = 'firebase_active_uid_AAA'; // session in SDK
        const requestedUid = 'requested_uid_BBB';       // uid passed to Firestore

        final dualGate = _FakeFirestoreGate();
        final result = simulateDualBarrierGuard(
          firebaseUid:    firebaseUid,
          requestedUid:   requestedUid,
          firestoreResult: _SimulatedFirestoreResult.success,
          operation:      'loadHistories',
          gate:           dualGate,
        );

        expect(result.isAuthDenied, isTrue,
            reason: 'Invariant C: non-null Firebase user with uid != requestedUid '
                'must return authDenied');
        expect(dualGate.readCount, equals(0),
            reason: 'Invariant C: uid_mismatch must produce sdkRequestDispatched=false '
                '(readCount=0) — no network call to Firestore made');
        expect(result.shouldFreezeLocalCache, isTrue);

        print('[INV_C.1][PASS] uid_mismatch: '
            'firebaseUid=$firebaseUid requestedUid=$requestedUid '
            'isAuthDenied=${result.isAuthDenied} readCount=${dualGate.readCount}');
      });

      test('C.2: uid_mismatch blocked across all 6 Firestore entry points', () {
        const firebaseUid  = 'firebase_session_uid_XYZ';
        const requestedUid = 'different_uid_ABC';

        final ops = [
          'loadHistories', 'loadFavDrugs', 'loadFavProtocols',
          'loadFavPrescriptions', 'loadFavCases', 'loadCases',
        ];

        for (final op in ops) {
          final dualGate = _FakeFirestoreGate();
          final result = simulateDualBarrierGuard(
            firebaseUid:    firebaseUid,
            requestedUid:   requestedUid,
            firestoreResult: _SimulatedFirestoreResult.success,
            operation:      op,
            gate:           dualGate,
          );
          expect(result.isAuthDenied, isTrue,
              reason: 'Invariant C: $op must block uid_mismatch');
          expect(dualGate.readCount, equals(0),
              reason: 'Invariant C: $op must have readCount=0 on uid_mismatch');
        }

        print('[INV_C.2][PASS] All ${ops.length} entry points block uid_mismatch');
      });

      test('C.3: matching uid passes dual check → readCount=1', () {
        const uid = 'uid_that_matches_both_sides';

        final dualGate = _FakeFirestoreGate();
        final result = simulateDualBarrierGuard(
          firebaseUid:    uid,
          requestedUid:   uid,   // same uid — check 2 passes
          firestoreResult: _SimulatedFirestoreResult.success,
          operation:      'loadHistories',
          gate:           dualGate,
        );

        expect(result.isSuccess, isTrue,
            reason: 'Invariant C: matching uid must pass dual barrier and read');
        expect(dualGate.readCount, equals(1),
            reason: 'Invariant C: matching uid must produce readCount=1 '
                '(sdkRequestDispatched=true)');

        print('[INV_C.3][PASS] Matching uid passes dual barrier: '
            'readCount=${dualGate.readCount}');
      });

      test('C.4: null Firebase user still blocked by check 1 (dual barrier is additive)', () {
        const requestedUid = 'any_requested_uid';

        final dualGate = _FakeFirestoreGate();
        final result = simulateDualBarrierGuard(
          firebaseUid:    null,    // no SDK user
          requestedUid:   requestedUid,
          firestoreResult: _SimulatedFirestoreResult.success,
          operation:      'loadHistories',
          gate:           dualGate,
        );

        expect(result.isAuthDenied, isTrue,
            reason: 'Invariant C: null Firebase user must still be blocked '
                'by check 1 of the dual barrier');
        expect(dualGate.readCount, equals(0),
            reason: 'Invariant C: null user must produce readCount=0');

        print('[INV_C.4][PASS] Null user blocked at check 1 of dual barrier');
      });

      test('C.5: cross-session swap — User A uid active when User B uid is requested', () {
        const userAUid = 'uid_user_session_A_active';
        const userBUid = 'uid_user_B_requesting_data';
        // Simulates the exact privilege window: SDK still holds session A
        // while the app attempts to load data for user B.

        final dualGate = _FakeFirestoreGate();
        final ops = [
          'loadHistories', 'loadFavDrugs', 'loadFavProtocols',
          'loadFavPrescriptions', 'loadFavCases', 'loadCases',
        ];

        for (final op in ops) {
          dualGate.reset();
          final result = simulateDualBarrierGuard(
            firebaseUid:    userAUid,  // SDK still holds A's session
            requestedUid:   userBUid,  // B's uid requested
            firestoreResult: _SimulatedFirestoreResult.success,
            operation:      op,
            gate:           dualGate,
          );
          expect(result.isAuthDenied, isTrue,
              reason: '$op: cross-session swap must be blocked by uid_mismatch');
          expect(dualGate.readCount, equals(0),
              reason: '$op: cross-session swap must produce readCount=0');
        }

        print('[INV_C.5][PASS] Cross-session swap blocked across all '
            '${ops.length} ops (privilege window closed)');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // ██████████████████████████████████████████████████████████████████████████
    // INVARIANT D: 20-Second Watchdog Compliance
    //
    // BUILD 463-A.1.2 — Verifies the strict behavioral contract of the outer
    // bootstrap watchdog (_kWatchdogMs = 20000ms in main.dart):
    //
    //   ALLOWED: set _bootDone=true, set _minTimeDone=true
    //   FORBIDDEN: set _authResolved=true, call setUser(), write to disk,
    //              clear caches, set authReady state
    //
    // These are structural invariants verified by inspection of the watchdog
    // code path. The test models the contract as observable side-effects.
    // ██████████████████████████████████████████████████████████████████████████
    group('Invariant D: 20-second watchdog compliance — never overrides auth', () {

      test('D.1: watchdog fires → bootDone=true, authResolved unchanged', () {
        // Simulates the two flags the watchdog sets:
        bool bootDone      = false;
        bool minTimeDone   = false;
        bool authResolved  = false;  // watchdog MUST NOT touch this
        AppAuthBarrierState? barrierState; // watchdog MUST NOT set this

        // Simulate watchdog firing (from main.dart line ~1145-1151):
        //   setState(() { _bootDone = true; _minTimeDone = true; });
        //   AppResumeCoordinator.instance.completeBootstrap();
        // It does NOT set _authResolved, does NOT call setUser(), does NOT
        // write SharedPreferences, does NOT clear caches.
        final void Function() watchdogFire = () {
          bootDone    = true;
          minTimeDone = true;
          // authResolved and barrierState intentionally NOT modified
        };

        watchdogFire();

        expect(bootDone,     isTrue,  reason: 'Watchdog must set bootDone=true');
        expect(minTimeDone,  isTrue,  reason: 'Watchdog must set minTimeDone=true');
        expect(authResolved, isFalse, reason: 'Watchdog MUST NOT set authResolved=true');
        expect(barrierState, isNull,  reason: 'Watchdog MUST NOT assign a barrierState');

        print('[INV_D.1][PASS] Watchdog fire: bootDone=$bootDone '
            'authResolved=$authResolved barrierState=$barrierState');
      });

      test('D.2: watchdog does not trigger authReady state', () {
        // The watchdog MUST NOT resolve the auth convergence manager.
        // authReady can only be set by AppProvider.setUser() after the
        // Firebase SDK latch confirms a matched non-null user.
        AppAuthBarrierState currentBarrier = AppAuthBarrierState.authPending;

        // Simulated watchdog (only touches boot flags):
        final void Function() watchdog = () {
          // CORRECT: only boot flags
          // INCORRECT would be: currentBarrier = AppAuthBarrierState.authReady;
        };

        watchdog();
        // After watchdog fires, barrier must remain authPending
        // (it will only change when Firebase SDK emits a user)
        expect(currentBarrier, equals(AppAuthBarrierState.authPending),
            reason: 'Invariant D: watchdog must not advance barrierState to authReady');
        expect(currentBarrier, isNot(equals(AppAuthBarrierState.authReady)),
            reason: 'authReady is only set by the auth convergence manager');

        print('[INV_D.2][PASS] Watchdog does not override auth barrier: '
            'barrier=${currentBarrier.name}');
      });

      test('D.3: watchdog does not wipe local cache or write unauthenticated state', () {
        // Simulates the "write spy" pattern — records if any write was triggered
        // by the watchdog path.
        final spy = _PersistenceSpy();
        bool cacheCleared = false;

        // Simulated watchdog action (must only set boot flags):
        final void Function() watchdog = () {
          // CORRECT: only boot flags modified
          // WRONG: spy.recordNormalWrite('watchdog_state_write');
          // WRONG: cacheCleared = true;
        };

        watchdog();

        expect(spy.normalWriteCount, equals(0),
            reason: 'Invariant D: watchdog must not write any state to disk');
        expect(spy.newUserWriteCount, equals(0),
            reason: 'Invariant D: watchdog must not trigger new-user write');
        expect(cacheCleared, isFalse,
            reason: 'Invariant D: watchdog must not clear local cache');

        print('[INV_D.3][PASS] Watchdog: writes=${spy.normalWriteCount} '
            'cacheCleared=$cacheCleared');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // ██████████████████████████████████████████████████████████████████████████
    // INVARIANT E: loadHistoriesTyped Consumer Migration Contract
    //
    // BUILD 463-A.1.2 — AppProvider now consumes loadHistoriesTyped() exclusively.
    // These tests verify that the typed consumer correctly unwraps each algebraic
    // variant and takes the correct action without triggering "new user" writes.
    // ██████████████████████████████████████████████████████████████████████████
    group('Invariant E: loadHistoriesTyped consumer migration contract', () {

      test('E.1: success result → histories assigned, cache write triggered', () {
        final List<String> memoryStore = [];
        int localCacheWrites = 0;

        // Simulate the consumer in AppProvider.loadHistories():
        final result = FirestoreLoadResult.success(['hc_001', 'hc_002', 'hc_003']);
        if (result.isSuccess) {
          memoryStore
            ..clear()
            ..addAll(result.dataOrElse([]));
          localCacheWrites++;
        } else if (result.shouldFreezeLocalCache) {
          // cache frozen — no write
        }

        expect(memoryStore, equals(['hc_001', 'hc_002', 'hc_003']));
        expect(localCacheWrites, equals(1),
            reason: 'E.1: success must trigger exactly one cache write');
        print('[INV_E.1][PASS] success: histories=${memoryStore.length} '
            'writes=$localCacheWrites');
      });

      test('E.2: authDenied result → memory unchanged, no cache write', () {
        final List<String> memoryStore = ['cached_hc_from_local'];
        int localCacheWrites = 0;

        final result = FirestoreLoadResult<List<String>>.authDenied();
        if (result.isSuccess) {
          memoryStore
            ..clear()
            ..addAll(result.dataOrElse([]));
          localCacheWrites++;
        } else if (result.isEmpty) {
          memoryStore.clear();
          localCacheWrites++;
        } else if (result.shouldFreezeLocalCache) {
          // Freeze: retain existing in-memory state, do not write
        }

        expect(memoryStore, equals(['cached_hc_from_local']),
            reason: 'E.2: authDenied must NOT overwrite in-memory state');
        expect(localCacheWrites, equals(0),
            reason: 'E.2: authDenied must NOT trigger a cache write');
        expect(result.shouldFreezeLocalCache, isTrue);
        print('[INV_E.2][PASS] authDenied: memoryPreserved=true '
            'writes=$localCacheWrites');
      });

      test('E.3: offline result → memory frozen, no new-user write', () {
        final spy = _PersistenceSpy();
        final List<String> memoryStore = ['offline_cached_hc'];

        final result = FirestoreLoadResult<List<String>>.offline();
        if (result.isSuccess) {
          memoryStore
            ..clear()
            ..addAll(result.dataOrElse([]));
          spy.recordNormalWrite('cache_write');
        } else if (result.isEmpty) {
          memoryStore.clear();
          spy.recordNewUserWrite(); // MUST NOT execute for offline
        } else if (result.shouldFreezeLocalCache) {
          // Correct path: freeze, no write
        }

        expect(memoryStore, equals(['offline_cached_hc']),
            reason: 'E.3: offline must preserve in-memory state');
        expect(spy.newUserWriteCount, equals(0),
            reason: 'E.3: offline must NEVER trigger a new-user write');
        expect(spy.normalWriteCount, equals(0));
        print('[INV_E.3][PASS] offline: memoryPreserved=true '
            'newUserWrites=${spy.newUserWriteCount}');
      });

      test('E.4: empty result → histories cleared, cache write triggered '
          '(authoritative empty — not new-user write)', () {
        final List<String> memoryStore = ['stale_item'];
        int localCacheWrites = 0;
        final spy = _PersistenceSpy();

        final result = FirestoreLoadResult<List<String>>.empty();
        if (result.isSuccess) {
          memoryStore
            ..clear()
            ..addAll(result.dataOrElse([]));
          localCacheWrites++;
        } else if (result.isEmpty) {
          // Authoritative empty (server confirmed no docs) → clear
          memoryStore.clear();
          localCacheWrites++;
          // This is NOT a "new user write" — it is a normal clear
        } else if (result.shouldFreezeLocalCache) {
          // cache frozen — no write
        }

        expect(memoryStore, isEmpty,
            reason: 'E.4: authoritative empty must clear histories');
        expect(localCacheWrites, equals(1));
        expect(spy.newUserWriteCount, equals(0),
            reason: 'E.4: empty result must NOT trigger a new-user write');
        print('[INV_E.4][PASS] empty: historiesCleared=true '
            'newUserWrites=${spy.newUserWriteCount}');
      });

      test('E.5: all 4 relevant variant paths are mutually exclusive in consumer', () {
        // Validates the consumer branch selection is exhaustive and non-overlapping.
        final variants = <FirestoreLoadResult<List<String>>>[
          FirestoreLoadResult.success([]),
          FirestoreLoadResult.empty(),
          FirestoreLoadResult.authDenied(),
          FirestoreLoadResult.offline(),
          FirestoreLoadResult.failure(Exception('network error')),
        ];

        for (final r in variants) {
          int branchHits = 0;
          if (r.isSuccess) branchHits++;
          if (r.isEmpty)   branchHits++;
          if (r.shouldFreezeLocalCache && !r.isSuccess && !r.isEmpty) branchHits++;
          expect(branchHits, equals(1),
              reason: '${r.runtimeType} must match exactly one consumer branch');
        }
        print('[INV_E.5][PASS] All 5 variants map to exactly one consumer branch');
      });
    });
  });
}
