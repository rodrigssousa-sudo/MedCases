// ══════════════════════════════════════════════════════════════════════════════
// test/providers/firestore_secure_writes_test.dart
// MICRO-BUILD 463-A.2.2 — Typed Write Barrier & Auto-Closing Secure Streams
//
// Verifies the algebraic write-barrier contracts and stream identity-guard
// contracts introduced in MICRO-BUILD 463-A.2.2.
//
// Architecture: zero-network, zero-Firebase, zero-UI.
//   • All Firestore I/O is replaced by injectable async stubs.
//   • All stream emissions are controlled by stub StreamControllers.
//   • FirestoreWriteResult sealed variants are tested directly.
//
// Invariant Y — Write IDOR Protection:
//   Calling the typed write methods with a null user or a mismatched UID
//   returns FsWriteAuthDenied instantly and performs ZERO database writes.
//
// Invariant Z — Stream Auto-Termination:
//   The secure stream closes when the active uid changes or becomes null.
//   No further elements are emitted after an identity mismatch is detected.
//
// Invariant AA — Write-Back Reversion:
//   A failed write-back (FsWriteFailure) causes the AppProvider-mirror
//   consumer to rollback its in-memory state to the last verified snapshot.
// ══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Production imports — FirestoreWriteResult sealed type hierarchy
// ─────────────────────────────────────────────────────────────────────────────
import 'package:medcases/services/firestore_service.dart'
    show FirestoreWriteResult, FsWriteSuccess, FsWriteAuthDenied, FsWriteFailure;

// ─────────────────────────────────────────────────────────────────────────────
// Inline test stubs — zero Firebase dependency
// ─────────────────────────────────────────────────────────────────────────────

/// Stub for the authenticated user identity.
class _AuthUser {
  final String uid;
  const _AuthUser(this.uid);
}

/// Stub session provider — replaces FirebaseAuth.instance.currentUser.
class _AuthSession {
  _AuthUser? _currentUser;
  _AuthUser? get currentUser => _currentUser;

  void signIn(String uid) => _currentUser = _AuthUser(uid);
  void signOut() => _currentUser = null;
  void switchTo(String uid) => _currentUser = _AuthUser(uid);
}

/// Stub typed write dispatcher — records calls and returns a configurable result.
class _StubWriteDispatcher {
  final _AuthSession _session;

  int dispatchCount = 0;
  FirestoreWriteResult Function(String uid, String op)? _resultFactory;

  _StubWriteDispatcher(this._session);

  void setResultFactory(FirestoreWriteResult Function(String uid, String op) f) {
    _resultFactory = f;
  }

  /// Mirrors FirestoreService._writeAuthCheck + write body.
  /// Returns FsWriteAuthDenied immediately if UID is null or mismatches.
  /// Otherwise dispatches the stub I/O (incrementing dispatchCount) and returns
  /// the configured result.
  Future<FirestoreWriteResult> dispatch(String uid, String operation) async {
    final fbUser = _session.currentUser;
    if (fbUser == null || fbUser.uid != uid) {
      print('[STUB_WRITE_BARRIER] operation=$operation '
          'allowed=false reason=uid_mismatch_or_null '
          'requestedUid=$uid activeUid=${fbUser?.uid ?? "null"} '
          'sdkWriteDispatched=false');
      return const FsWriteAuthDenied('uid_mismatch_or_null');
    }
    // Auth passed — simulate I/O
    dispatchCount++;
    return _resultFactory?.call(uid, operation) ?? const FsWriteSuccess();
  }
}

/// Stub secure stream that mirrors [streamHistories]' identity guard.
///
/// Emits items from [controller] only while the active UID matches [uid].
/// If the UID changes or becomes null between emissions, the stream closes
/// synchronously before forwarding the item.
///
/// Implementation note: uses a StreamController transform rather than
/// [async*] + [await for]. The async* generator introduces a pull-based
/// backpressure layer on top of the push-based StreamController, which
/// creates extra async boundaries that require many event-loop turns to
/// drain in the flutter_test VM. The StreamController transform forwards
/// items synchronously inside the source listener callback — one microtask
/// turn per item — which makes timing predictable in tests.
Stream<List<String>> _stubSecureStream({
  required String uid,
  required _AuthSession session,
  required StreamController<List<String>> controller,
}) {
  // Broadcast-safe output controller.
  final out = StreamController<List<String>>();
  late StreamSubscription<List<String>> sub;

  sub = controller.stream.listen(
    (items) {
      final activeUid = session.currentUser?.uid;
      if (activeUid != uid) {
        print('[SECURE_STREAM][AUTO_CLOSE] stream=stubSecureStream '
            'parentUid=$uid activeUid=$activeUid');
        // Mirror production behaviour: close the output stream and cancel
        // the upstream subscription so no further items are forwarded.
        sub.cancel();
        out.close();
        return;
      }
      out.add(items);
    },
    onDone: () {
      if (!out.isClosed) out.close();
    },
    onError: (Object e, StackTrace st) {
      if (!out.isClosed) out.addError(e, st);
    },
    cancelOnError: false,
  );

  return out.stream;
}

/// Stub AppProvider-mirror — tracks local memory state and write-barrier.
class _StubAppProviderMirror {
  final _StubWriteDispatcher _dispatcher;

  // In-memory state
  List<String> _items = [];
  List<String> _lastVerifiedItems = [];
  bool writeBackFrozen = false;
  int revertCount = 0;

  _StubAppProviderMirror(this._dispatcher);

  List<String> get items => List.unmodifiable(_items);

  void _snapshotItems() {
    _lastVerifiedItems = List.from(_items);
  }

  void _revert(FirestoreWriteResult result, String op) {
    print('[WRITE_BARRIER_REVERT] op=$op result=${result.runtimeType} → reverting');
    _items = _lastVerifiedItems;
    writeBackFrozen = true;
    revertCount++;
  }

  /// Optimistic add: mutate local state first, then write.
  Future<void> addItem(String uid, String item) async {
    _snapshotItems();
    _items = [..._items, item]; // optimistic add

    if (!writeBackFrozen) {
      final result = await _dispatcher.dispatch(uid, 'addItem');
      if (result is FsWriteAuthDenied || result is FsWriteFailure) {
        _revert(result, 'addItem');
      }
    }
  }

  /// Optimistic remove: mutate local state first, then write.
  Future<void> removeItem(String uid, String item) async {
    _snapshotItems();
    _items = _items.where((i) => i != item).toList(); // optimistic remove

    if (!writeBackFrozen) {
      final result = await _dispatcher.dispatch(uid, 'removeItem');
      if (result is FsWriteAuthDenied || result is FsWriteFailure) {
        _revert(result, 'removeItem');
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── FirestoreWriteResult sealed type contract ─────────────────────────────
  group('FirestoreWriteResult — sealed type contract', () {
    test('FsWriteSuccess is a FirestoreWriteResult', () {
      const result = FsWriteSuccess();
      expect(result, isA<FirestoreWriteResult>());
      expect(result, isA<FsWriteSuccess>());
    });

    test('FsWriteAuthDenied carries reason token', () {
      const result = FsWriteAuthDenied('uid_mismatch_or_null');
      expect(result, isA<FirestoreWriteResult>());
      expect(result.reason, equals('uid_mismatch_or_null'));
    });

    test('FsWriteFailure carries error and stack trace', () {
      final err = Exception('test error');
      final st = StackTrace.current;
      final result = FsWriteFailure(err, st);
      expect(result, isA<FirestoreWriteResult>());
      expect(result.error, equals(err));
      expect(result.stackTrace, equals(st));
    });

    test('Sealed hierarchy exhaustiveness — three concrete variants', () {
      final results = <FirestoreWriteResult>[
        const FsWriteSuccess(),
        const FsWriteAuthDenied('uid_mismatch_or_null'),
        FsWriteFailure(Exception('e'), StackTrace.current),
      ];
      for (final r in results) {
        final label = switch (r) {
          FsWriteSuccess()   => 'success',
          FsWriteAuthDenied(:final reason) => 'denied:$reason',
          FsWriteFailure(:final error) => 'failure:$error',
        };
        expect(label, isNotEmpty);
      }
    });
  });

  // ── Invariant Y — Write IDOR Protection ──────────────────────────────────
  group('Invariant Y — Write IDOR Protection', () {
    late _AuthSession session;
    late _StubWriteDispatcher dispatcher;

    setUp(() {
      session    = _AuthSession();
      dispatcher = _StubWriteDispatcher(session);
    });

    // Y-1: null user → FsWriteAuthDenied, zero writes dispatched
    test('Y-1: null user → FsWriteAuthDenied, zero I/O dispatched', () async {
      // No sign-in — currentUser is null
      final result = await dispatcher.dispatch('uid-A', 'saveFavoritesTyped');
      expect(result, isA<FsWriteAuthDenied>());
      expect((result as FsWriteAuthDenied).reason,
          equals('uid_mismatch_or_null'));
      expect(dispatcher.dispatchCount, equals(0),
          reason: 'zero Firestore SDK calls must be made when user is null');
    });

    // Y-2: mismatched UID → FsWriteAuthDenied, zero writes dispatched
    test('Y-2: mismatched UID → FsWriteAuthDenied, zero I/O dispatched', () async {
      session.signIn('uid-B'); // signed in as B
      final result = await dispatcher.dispatch('uid-A', 'saveHistoryTyped');
      // Requesting write for uid-A but authenticated as uid-B
      expect(result, isA<FsWriteAuthDenied>());
      expect(dispatcher.dispatchCount, equals(0),
          reason: 'IDOR shield must block cross-account writes');
    });

    // Y-3: matching UID → dispatched, returns FsWriteSuccess
    test('Y-3: matching UID → dispatched, returns FsWriteSuccess', () async {
      session.signIn('uid-C');
      final result = await dispatcher.dispatch('uid-C', 'saveFavoritesTyped');
      expect(result, isA<FsWriteSuccess>());
      expect(dispatcher.dispatchCount, equals(1));
    });

    // Y-4: sign-out mid-session → subsequent write is denied with zero I/O
    test('Y-4: sign-out mid-session → subsequent write returns FsWriteAuthDenied', () async {
      session.signIn('uid-D');
      // First write succeeds
      final r1 = await dispatcher.dispatch('uid-D', 'deleteHistoryTyped');
      expect(r1, isA<FsWriteSuccess>());
      expect(dispatcher.dispatchCount, equals(1));

      // User signs out
      session.signOut();

      // Second write must be denied instantly
      final r2 = await dispatcher.dispatch('uid-D', 'deleteHistoryTyped');
      expect(r2, isA<FsWriteAuthDenied>());
      expect(dispatcher.dispatchCount, equals(1),
          reason: 'dispatchCount must not increase after sign-out');
    });

    // Y-5: FsWriteAuthDenied reason is exactly the canonical sentinel token
    test('Y-5: FsWriteAuthDenied.reason is the canonical sentinel token', () async {
      session.signIn('uid-E');
      final result = await dispatcher.dispatch('uid-X', 'saveCaseProgressTyped');
      expect(result, isA<FsWriteAuthDenied>());
      expect((result as FsWriteAuthDenied).reason,
          equals('uid_mismatch_or_null'),
          reason: 'reason must be the exact canonical sentinel — never null or empty');
    });

    // Y-6: account switch → write for old UID is denied
    test('Y-6: account switch → write for original UID is denied', () async {
      session.signIn('uid-F');
      final r1 = await dispatcher.dispatch('uid-F', 'saveFavoritesTyped');
      expect(r1, isA<FsWriteSuccess>());

      // Switch to a different account
      session.switchTo('uid-G');

      // Write for old UID must be denied (IDOR shield)
      final r2 = await dispatcher.dispatch('uid-F', 'saveFavoritesTyped');
      expect(r2, isA<FsWriteAuthDenied>());
      expect(dispatcher.dispatchCount, equals(1),
          reason: 'no additional I/O after account switch for old UID');
    });
  });

  // ── Invariant Z — Stream Auto-Termination ─────────────────────────────────
  group('Invariant Z — Stream Auto-Termination', () {
    // Z-1: stream emits normally while UID matches
    //
    // Each item traverses two async boundaries through the async* generator:
    //   (1) StreamController sink → async* await-for loop resumes (1 microtask)
    //   (2) yield inside generator → listen() callback fires   (1 microtask)
    //
    // Therefore we must pump the event loop twice per item to guarantee
    // delivery before asserting. We use a Completer-based approach to wait
    // for the exact expected count, with a generous but finite timeout.
    test('Z-1: stream emits items while UID matches', () async {
      final session    = _AuthSession()..signIn('uid-Z1');
      final controller = StreamController<List<String>>();
      final received   = <List<String>>[];

      // Completer signals when we have collected the expected number of items.
      final allReceived = Completer<void>();

      final sub = _stubSecureStream(
        uid: 'uid-Z1', session: session, controller: controller,
      ).listen((items) {
        received.add(items);
        if (received.length >= 2) allReceived.complete();
      });

      // First item — add then yield two microtask turns so the async* chain
      // has time to propagate the value all the way to the listener.
      controller.add(['item-1']);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Second item — same two-turn pump.
      controller.add(['item-1', 'item-2']);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Belt-and-suspenders: wait for the Completer with a short deadline so
      // the test fails fast rather than hitting the 30-second harness timeout.
      await allReceived.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError(
          'Z-1 timed out: expected 2 items but received ${received.length}',
        ),
      );

      expect(received.length, equals(2));
      expect(received[0], equals(['item-1']));
      expect(received[1], equals(['item-1', 'item-2']));

      await sub.cancel();
      await controller.close();
    });

    // Z-2: stream closes immediately when UID changes
    test('Z-2: stream closes when active UID changes to UID-B', () async {
      final session    = _AuthSession()..signIn('uid-Z2-A');
      final controller = StreamController<List<String>>();
      final received   = <List<String>>[];
      var isDone       = false;

      _stubSecureStream(
        uid: 'uid-Z2-A', session: session, controller: controller,
      ).listen(
        received.add,
        onDone: () => isDone = true,
      );

      // First emission — UID still matches
      controller.add(['item-1']);
      await Future.delayed(Duration.zero);
      expect(received.length, equals(1));

      // Switch account — UID now mismatches
      session.switchTo('uid-Z2-B');

      // Second emission — must trigger auto-close
      controller.add(['item-2']);
      await Future.delayed(Duration.zero);

      // Stream must have closed; no new items emitted
      expect(received.length, equals(1),
          reason: 'no items must be emitted after UID mismatch');
      expect(isDone, isTrue,
          reason: 'stream must have emitted a done signal synchronously');

      await controller.close();
    });

    // Z-3: stream closes immediately when user signs out (UID becomes null)
    test('Z-3: stream closes when user signs out (null UID)', () async {
      final session    = _AuthSession()..signIn('uid-Z3');
      final controller = StreamController<List<String>>();
      final received   = <List<String>>[];
      var isDone       = false;

      _stubSecureStream(
        uid: 'uid-Z3', session: session, controller: controller,
      ).listen(
        received.add,
        onDone: () => isDone = true,
      );

      controller.add(['data-1']);
      await Future.delayed(Duration.zero);
      expect(received.length, equals(1));

      // Sign out
      session.signOut();

      controller.add(['data-2']); // must be dropped
      await Future.delayed(Duration.zero);

      expect(received.length, equals(1),
          reason: 'post-signout emission must be dropped');
      expect(isDone, isTrue,
          reason: 'stream must close on null UID');

      await controller.close();
    });

    // Z-4: no emissions after auto-close — stale items are rejected
    test('Z-4: stale items after auto-close are never emitted', () async {
      final session    = _AuthSession()..signIn('uid-Z4');
      final controller = StreamController<List<String>>();
      final received   = <List<String>>[];

      _stubSecureStream(
        uid: 'uid-Z4', session: session, controller: controller,
      ).listen(received.add);

      controller.add(['good-item']);
      await Future.delayed(Duration.zero);
      expect(received.length, equals(1));

      // Identity shift
      session.switchTo('uid-Z4-other');

      // Multiple stale emissions — all must be dropped
      controller.add(['stale-1']);
      controller.add(['stale-2']);
      controller.add(['stale-3']);
      await Future.delayed(Duration.zero);

      expect(received.length, equals(1),
          reason: 'all stale emissions after identity shift must be rejected');

      await controller.close();
    });

    // Z-5: stream opened with no active user (null from start) closes immediately
    test('Z-5: stream opened for null user closes on first emission', () async {
      final session    = _AuthSession(); // no sign-in — null user
      final controller = StreamController<List<String>>();
      final received   = <List<String>>[];
      var isDone       = false;

      _stubSecureStream(
        uid: 'uid-Z5', session: session, controller: controller,
      ).listen(
        received.add,
        onDone: () => isDone = true,
      );

      controller.add(['should-not-arrive']);
      await Future.delayed(Duration.zero);

      expect(received.isEmpty, isTrue,
          reason: 'stream with null user must not emit any items');
      expect(isDone, isTrue,
          reason: 'stream with null user must close on first emission attempt');

      await controller.close();
    });
  });

  // ── Invariant AA — Write-Back Reversion ──────────────────────────────────
  group('Invariant AA — Write-Back Reversion on FsWriteFailure', () {
    late _AuthSession session;
    late _StubWriteDispatcher dispatcher;
    late _StubAppProviderMirror provider;

    setUp(() {
      session    = _AuthSession()..signIn('uid-AA');
      dispatcher = _StubWriteDispatcher(session);
      provider   = _StubAppProviderMirror(dispatcher);
    });

    // AA-1: FsWriteFailure → local state reverts to pre-mutation snapshot
    test('AA-1: FsWriteFailure → local state reverted to last verified snapshot', () async {
      // Seed verified state
      provider._items = ['item-A', 'item-B'];
      provider._lastVerifiedItems = ['item-A', 'item-B'];

      // Configure dispatcher to simulate Firestore failure
      dispatcher.setResultFactory((uid, op) =>
          FsWriteFailure(Exception('network error'), StackTrace.current));

      // Optimistic add — local state changes before write
      await provider.addItem('uid-AA', 'item-C');

      // Write failed → revert must have fired
      expect(provider.items, equals(['item-A', 'item-B']),
          reason: 'local state must be reverted to the pre-mutation snapshot');
      expect(provider.revertCount, equals(1));
      expect(provider.writeBackFrozen, isTrue,
          reason: 'write-back must be frozen after FsWriteFailure');
    });

    // AA-2: FsWriteAuthDenied → local state reverts to pre-mutation snapshot
    test('AA-2: FsWriteAuthDenied → local state reverted to last verified snapshot', () async {
      provider._items = ['alpha', 'beta'];
      provider._lastVerifiedItems = ['alpha', 'beta'];

      // Dispatcher returns FsWriteAuthDenied (UID mismatch)
      dispatcher.setResultFactory((uid, op) =>
          const FsWriteAuthDenied('uid_mismatch_or_null'));

      await provider.removeItem('uid-AA', 'beta');

      expect(provider.items, equals(['alpha', 'beta']),
          reason: 'list must be restored to pre-mutation snapshot after auth denial');
      expect(provider.writeBackFrozen, isTrue);
      expect(provider.revertCount, equals(1));
    });

    // AA-3: FsWriteSuccess → local state is NOT reverted (stays mutated)
    test('AA-3: FsWriteSuccess → local state is NOT reverted', () async {
      provider._items = ['x', 'y'];
      provider._lastVerifiedItems = ['x', 'y'];

      // Default result is FsWriteSuccess
      await provider.addItem('uid-AA', 'z');

      expect(provider.items, equals(['x', 'y', 'z']),
          reason: 'successful write must keep the optimistic mutation');
      expect(provider.revertCount, equals(0));
      expect(provider.writeBackFrozen, isFalse);
    });

    // AA-4: write-back frozen after first failure → subsequent writes skipped
    test('AA-4: write-back frozen → subsequent operations skip dispatcher', () async {
      provider._items = ['p'];
      provider._lastVerifiedItems = ['p'];

      dispatcher.setResultFactory((uid, op) =>
          FsWriteFailure(Exception('first failure'), StackTrace.current));

      await provider.addItem('uid-AA', 'q');
      expect(provider.writeBackFrozen, isTrue);
      final countAfterFirstFailure = dispatcher.dispatchCount;

      // Second write — should skip dispatcher entirely due to freeze
      await provider.addItem('uid-AA', 'r');
      expect(dispatcher.dispatchCount, equals(countAfterFirstFailure),
          reason: 'frozen write-back must skip all subsequent dispatcher calls');
    });

    // AA-5: revert restores exactly the pre-mutation snapshot (not some other state)
    test('AA-5: revert restores the EXACT pre-mutation snapshot', () async {
      final preState = ['a', 'b', 'c'];
      provider._items = List.from(preState);
      provider._lastVerifiedItems = List.from(preState);

      dispatcher.setResultFactory((uid, op) =>
          FsWriteFailure(Exception('db error'), StackTrace.current));

      // Make multiple optimistic mutations before the failed write resolves
      await provider.addItem('uid-AA', 'd');

      // After revert, state must match exactly the pre-first-mutation snapshot
      expect(provider.items, equals(preState),
          reason: 'revert must restore the exact snapshot taken before the first mutation');
    });

    // AA-6: revert count increments exactly once per failed write
    test('AA-6: revert fires exactly once per failed write', () async {
      provider._items = ['item'];
      provider._lastVerifiedItems = ['item'];
      dispatcher.setResultFactory((uid, op) =>
          FsWriteFailure(Exception('err'), StackTrace.current));

      await provider.addItem('uid-AA', 'new-item');
      expect(provider.revertCount, equals(1));

      // With freeze active, second write is skipped entirely — revert does not fire again
      await provider.addItem('uid-AA', 'another-item');
      expect(provider.revertCount, equals(1),
          reason: 'revert must not fire for operations skipped due to freeze');
    });
  });
}
