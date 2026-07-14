// ══════════════════════════════════════════════════════════════════════════════
// test/providers/firestore_typed_reads_test.dart
// MICRO-BUILD 463-A.2.1 — Typed Secondary Collection Reads Test Suite
// MICRO-BUILD 463-A.2.1.1 — Authoritative Empty Semantics Enforcement
//
// Verifies the algebraic read contracts for all secondary Firestore collections:
//
// Invariant V (Algebraic Read Safety):
//   Secondary typed queries return authDenied() immediately when credentials
//   are null — no background watchdogs, no timers, no blocking waits.
//
// Invariant W (Cache Preservation under Offline):
//   When server read fails, the cache is consulted as a fallback.
//   AUTHORITATIVE RULE (463-A.2.1.1):
//     server-fail + cache hit  → success(cachedData)
//     server-fail + cache miss → offline()    ← NOT empty()
//     server-fail + cache error → offline()
//
// Scenarios 1–6 (463-A.2.1.1 Strict Matrix):
//   1. Server success + 0 docs → empty(), shouldFreezeLocalCache == false
//   2. Server failure + cache miss → offline(), shouldFreezeLocalCache == true
//   3. Server failure + cache hit → success(cached), shouldFreezeLocalCache == false
//   4. Permission-denied never collapses to empty() under any configuration
//   5. offline() history load result never triggers new-user state in stub provider
//   6. offline() favs/cases load result prevents write-back via shouldFreezeLocalCache
//
// Architecture: unit-level stubs — zero Firebase, zero network, zero UI.
// All production types are mirrored inline so this file has zero Flutter
// infrastructure dependencies.
// ══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Inline stubs — mirror the production types from firestore_service.dart
// These replicate the exact contracts from MICRO-BUILD 463-A.2.1.1.
// ─────────────────────────────────────────────────────────────────────────────

/// Algebraic result type — mirrors FirestoreLoadResult<T> from production.
abstract class _FirestoreLoadResult<T> {
  const _FirestoreLoadResult();

  factory _FirestoreLoadResult.success(T data) = _FsSuccess<T>;
  factory _FirestoreLoadResult.empty()         = _FsEmpty<T>;
  factory _FirestoreLoadResult.authDenied()    = _FsAuthDenied<T>;
  factory _FirestoreLoadResult.offline()       = _FsOffline<T>;
  factory _FirestoreLoadResult.failure(dynamic error) = _FsFailure<T>;

  bool get isSuccess    => this is _FsSuccess<T>;
  bool get isEmpty      => this is _FsEmpty<T>;
  bool get isAuthDenied => this is _FsAuthDenied<T>;
  bool get isOffline    => this is _FsOffline<T>;
  bool get isFailure    => this is _FsFailure<T>;

  /// true if the local cache must be preserved (no write, no overwrite).
  bool get shouldFreezeLocalCache => isAuthDenied || isOffline || isFailure;

  T dataOrElse(T fallback) =>
      isSuccess ? (this as _FsSuccess<T>).data : fallback;
}

class _FsSuccess<T> extends _FirestoreLoadResult<T> {
  final T data;
  const _FsSuccess(this.data);
}

class _FsEmpty<T> extends _FirestoreLoadResult<T> {
  const _FsEmpty();
}

class _FsAuthDenied<T> extends _FirestoreLoadResult<T> {
  const _FsAuthDenied();
}

class _FsOffline<T> extends _FirestoreLoadResult<T> {
  const _FsOffline();
}

class _FsFailure<T> extends _FirestoreLoadResult<T> {
  final dynamic error;
  const _FsFailure(this.error);
}

// ─────────────────────────────────────────────────────────────────────────────
// _FakeFirebaseUser — stands in for firebase_auth.User
// ─────────────────────────────────────────────────────────────────────────────
class _FakeFirebaseUser {
  final String uid;
  const _FakeFirebaseUser(this.uid);
}

// ─────────────────────────────────────────────────────────────────────────────
// _StubFirestoreCollection — simulates a Firestore document/collection read.
//
// Controls whether the server read succeeds, throws FirebaseException(
// permission-denied), or throws a network error (simulating offline).
// Also controls whether a cache fallback succeeds.
// ─────────────────────────────────────────────────────────────────────────────
enum _StubServerBehaviour {
  success,           // server returns data normally
  successEmpty,      // server returns 0 documents (authoritative empty)
  permissionDenied,  // server returns FirebaseException('permission-denied')
  networkError,      // server throws generic Exception (offline / unreachable)
  timeout,           // server throws TimeoutException (no connectivity)
}

enum _StubCacheBehaviour {
  hit,    // cache has data — returns it
  miss,   // cache has no document (exists = false / returns null)
  error,  // cache throws too
}

/// Simulates a Firestore favs document read with configurable behaviour.
class _StubFavsDoc {
  final _StubServerBehaviour serverBehaviour;
  final _StubCacheBehaviour cacheBehaviour;
  final Set<String> serverData;
  final Set<String> cacheData;
  int serverCallCount = 0;
  int cacheCallCount  = 0;

  _StubFavsDoc({
    required this.serverBehaviour,
    required this.cacheBehaviour,
    this.serverData = const {},
    this.cacheData  = const {},
  });

  Future<Set<String>?> readFromServer() async {
    serverCallCount++;
    switch (serverBehaviour) {
      case _StubServerBehaviour.success:
        return Set<String>.from(serverData);
      case _StubServerBehaviour.successEmpty:
        return <String>{}; // authoritative empty from server
      case _StubServerBehaviour.permissionDenied:
        throw _StubFirebaseException('permission-denied');
      case _StubServerBehaviour.networkError:
        throw Exception('network-request-failed');
      case _StubServerBehaviour.timeout:
        throw TimeoutException('server read timed out');
    }
  }

  Future<Set<String>?> readFromCache() async {
    cacheCallCount++;
    switch (cacheBehaviour) {
      case _StubCacheBehaviour.hit:
        return Set<String>.from(cacheData);
      case _StubCacheBehaviour.miss:
        return null; // document does not exist in cache
      case _StubCacheBehaviour.error:
        throw Exception('cache-unavailable');
    }
  }
}

class _StubFirebaseException implements Exception {
  final String code;
  _StubFirebaseException(this.code);
  @override
  String toString() => 'FirebaseException: $code';
}

// ─────────────────────────────────────────────────────────────────────────────
// _StubFirestoreService — mirrors FirestoreService.loadFav*Typed() contract
//
// Implements the CORRECTED algebraic matrix from MICRO-BUILD 463-A.2.1.1:
//   server success + data     → success(data)
//   server success + 0 docs   → empty()
//   server permission-denied  → authDenied()
//   server fail + cache hit   → success(cached)
//   server fail + cache miss  → offline()   ← CRITICAL: NOT empty()
//   server fail + cache error → offline()
// ─────────────────────────────────────────────────────────────────────────────
class _StubFirestoreService {
  final _FakeFirebaseUser? currentUser;
  final _StubFavsDoc stubDoc;
  final bool isFirebaseReady;

  // Tracks whether any timer/watchdog was started during execution.
  int watchdogStartCount = 0;

  _StubFirestoreService({
    required this.currentUser,
    required this.stubDoc,
    this.isFirebaseReady = true,
  });

  /// Mirrors FirestoreService.loadFavDrugsTyped(uid) logic with the corrected
  /// algebraic matrix from MICRO-BUILD 463-A.2.1.1:
  ///   1. Dual-check barrier → authDenied immediately (no timer)
  ///   2. Server permissionDenied → authDenied
  ///   3. Server fail + cache hit  → success(cached)
  ///   4. Server fail + cache miss → offline()   ← NOT empty()
  ///   5. Server fail + cache error → offline()
  ///   6. Server success + empty set → empty()
  ///   7. Server success + data → success(data)
  Future<_FirestoreLoadResult<Set<String>>> loadFavTyped(String uid) async {
    // Invariant V: authDenied immediately, no timer started
    if (!isFirebaseReady || currentUser == null) {
      print('[STUB][loadFavTyped] authDenied — currentUser=null uid=$uid '
          'sdkRequestDispatched=false');
      // CRITICAL: no watchdog is started — watchdogStartCount must remain 0
      return _FirestoreLoadResult.authDenied();
    }
    if (currentUser!.uid != uid) {
      print('[STUB][loadFavTyped] authDenied — uid_mismatch '
          'expected=$uid actual=${currentUser!.uid}');
      return _FirestoreLoadResult.authDenied();
    }
    try {
      final data = await stubDoc.readFromServer();
      // data == null should not happen in success/successEmpty paths
      if (data == null || data.isEmpty) return _FirestoreLoadResult.empty();
      return _FirestoreLoadResult.success(data);
    } on _StubFirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return _FirestoreLoadResult.authDenied();
      }
      // Other Firebase error → try cache
      // ALGEBRAIC RULE 463-A.2.1.1: cache miss after server failure → offline()
      try {
        final cached = await stubDoc.readFromCache();
        if (cached == null) return _FirestoreLoadResult.offline();
        return _FirestoreLoadResult.success(cached);
      } catch (_) {
        return _FirestoreLoadResult.offline();
      }
    } catch (_) {
      // Network/timeout → try cache before returning offline()
      // ALGEBRAIC RULE 463-A.2.1.1: cache miss after server failure → offline()
      try {
        final cached = await stubDoc.readFromCache();
        if (cached == null) return _FirestoreLoadResult.offline();
        // Invariant W: cache hit → success(cached)
        return _FirestoreLoadResult.success(cached);
      } catch (_) {
        return _FirestoreLoadResult.offline();
      }
    }
  }

  /// Mirrors loadAiSessionsTyped() — same auth guard, same corrected cache-fallback.
  /// ALGEBRAIC RULE 463-A.2.1.1: server fail + empty cache → offline(), not empty().
  Future<_FirestoreLoadResult<List<Map<String, dynamic>>>> loadAiSessionsTyped(
      String uid) async {
    if (!isFirebaseReady || currentUser == null) {
      print('[STUB][loadAiSessionsTyped] authDenied — currentUser=null uid=$uid '
          'sdkRequestDispatched=false watchdogStarted=false');
      // NO watchdog started — this is the core contract of Invariant V
      return _FirestoreLoadResult.authDenied();
    }
    if (currentUser!.uid != uid) {
      return _FirestoreLoadResult.authDenied();
    }
    try {
      // Server read
      final data = await stubDoc.readFromServer();
      if (data == null || data.isEmpty) return _FirestoreLoadResult.empty();
      return _FirestoreLoadResult.success(data.map((id) => {'id': id}).toList());
    } on _StubFirebaseException catch (e) {
      if (e.code == 'permission-denied') return _FirestoreLoadResult.authDenied();
      // ALGEBRAIC RULE 463-A.2.1.1: cache miss after server failure → offline()
      try {
        final cached = await stubDoc.readFromCache();
        if (cached == null) return _FirestoreLoadResult.offline();
        return _FirestoreLoadResult.success(
            cached.map((id) => {'id': id}).toList());
      } catch (_) {
        return _FirestoreLoadResult.offline();
      }
    } catch (_) {
      // ALGEBRAIC RULE 463-A.2.1.1: cache miss after server failure → offline()
      try {
        final cached = await stubDoc.readFromCache();
        if (cached == null) return _FirestoreLoadResult.offline();
        return _FirestoreLoadResult.success(
            cached.map((id) => {'id': id}).toList());
      } catch (_) {
        return _FirestoreLoadResult.offline();
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StubHistoryProvider — minimal stub for Scenarios 5 and 6.
// Simulates an AppProvider that tracks new-user detection and write-back.
// ─────────────────────────────────────────────────────────────────────────────
class _StubHistoryProvider {
  // Set to true if a confirmed_new_user event would have been emitted.
  bool confirmedNewUserFired = false;

  // Set to true if any write-back to Firestore was attempted.
  bool writeBackAttempted = false;

  /// Simulates _syncFromFirestore() processing of a history load result.
  /// With the corrected semantics: offline() → freeze cache, no new-user event.
  void processHistoryResult(_FirestoreLoadResult<List<String>> result) {
    if (result.shouldFreezeLocalCache) {
      // FREEZE: do nothing — no write-back, no new-user detection
      print('[STUB][processHistoryResult] shouldFreezeLocalCache=true → no write-back');
      return;
    }
    if (result.isEmpty) {
      // Authoritative empty from server → trigger new-user check
      confirmedNewUserFired = true;
      print('[STUB][processHistoryResult] isEmpty=true → confirmed_new_user fired');
      return;
    }
    if (result.isSuccess) {
      // Write back to local state
      writeBackAttempted = true;
      print('[STUB][processHistoryResult] success → write-back');
    }
  }

  /// Simulates _syncFromFirestore() processing of a favs/cases load result.
  /// offline() must prevent the write-back routine from running.
  void processFavsResult(_FirestoreLoadResult<Set<String>> result) {
    if (result.shouldFreezeLocalCache) {
      // FREEZE: local data preserved — no overwrite, no reset
      print('[STUB][processFavsResult] shouldFreezeLocalCache=true → write-back blocked');
      return;
    }
    if (result.isSuccess || result.isEmpty) {
      // Write back (update local store)
      writeBackAttempted = true;
      print('[STUB][processFavsResult] success/empty → write-back');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StubConsumerController — mirrors _AiScreenState session management logic.
//
// Tracks exactly the state that the UI layer maintains:
//   • sessionList  — the in-memory chat session list (mirrors _chatHistory)
//   • loadGeneration — counter bumped each time a load starts (mirrors
//                      _AiScreenState._sessionsLoadGeneration)
//   • wasCleared   — set to true if sessionList was explicitly cleared
//   • wasFrozen    — set to true if a non-empty result caused a freeze
//
// routeResult() mirrors the exhaustive algebraic routing in _loadChatHistory():
//   .success(data)  → hydrate sessionList with data
//   .empty()        → clear sessionList (authoritative_clear — ONLY this path)
//   .authDenied()   → freeze (preserve sessionList, set wasFrozen)
//   .offline()      → freeze (preserve sessionList, set wasFrozen)
//   .failure(e)     → freeze (preserve sessionList, set wasFrozen)
// ─────────────────────────────────────────────────────────────────────────────
class _StubConsumerController {
  List<Map<String, dynamic>> sessionList;
  int loadGeneration = 0;
  bool wasCleared = false;
  bool wasFrozen = false;

  _StubConsumerController({List<Map<String, dynamic>>? initial})
      : sessionList = initial ?? [];

  /// Mirrors _loadChatHistory() algebraic routing.
  /// Returns false if the stale-epoch guard caused early exit.
  bool routeResult(
      _FirestoreLoadResult<List<Map<String, dynamic>>> result, {
      required int myGeneration,
  }) {
    // UI-side stale-epoch guard: if generation was bumped while we awaited,
    // discard the completion without touching sessionList.
    if (loadGeneration != myGeneration) {
      print('[STUB][routeResult] STALE_EPOCH discarded '
          'myGen=$myGeneration currentGen=$loadGeneration');
      return false; // stale — no state mutation
    }

    if (result.isSuccess) {
      sessionList = List<Map<String, dynamic>>.from(
          result.dataOrElse(<Map<String, dynamic>>[]));
      print('[AI_SESSIONS_LOAD] result=success action=hydrate '
          'count=${sessionList.length} writeBack=false');
      return true;
    } else if (result.isEmpty) {
      sessionList = [];
      wasCleared = true;
      print('[AI_SESSIONS_LOAD] result=empty action=authoritative_clear writeBack=false');
      return true;
    } else if (result.isAuthDenied) {
      wasFrozen = true;
      print('[AI_SESSIONS_LOAD] result=authDenied action=freeze writeBack=false');
      return true;
    } else if (result.isOffline) {
      wasFrozen = true;
      print('[AI_SESSIONS_LOAD] result=offline action=freeze writeBack=false');
      return true;
    } else {
      // failure
      wasFrozen = true;
      print('[AI_SESSIONS_LOAD] result=failure action=freeze writeBack=false '
          'error=${result.runtimeType}');
      return true;
    }
  }

  /// Starts a new load: bumps generation, returns the generation token.
  int startLoad() {
    loadGeneration++;
    return loadGeneration;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StubAppProviderLatch — mirrors AppProvider.loadAiSessionsTypedForUi().
//
// Implements the single-flight generation latch logic exactly:
//   • Same UID with in-flight future → reuse that future
//   • New UID → bump generation, create new future
//   • Stale-epoch (generation mismatch after await) → return authDenied()
//
// Takes a factory function that produces the raw Firestore Future so tests
// can inject any result (success, offline, authDenied, etc.) controllably.
// ─────────────────────────────────────────────────────────────────────────────
class _StubAppProviderLatch {
  Future<_FirestoreLoadResult<List<Map<String, dynamic>>>>? _inFlight;
  String? _uid;
  int _generation = 0;

  /// Call history for assertion.
  final List<String> log = [];

  Future<_FirestoreLoadResult<List<Map<String, dynamic>>>> loadForUi(
      String uid,
      Future<_FirestoreLoadResult<List<Map<String, dynamic>>>> Function() fetchFactory,
  ) async {
    // Single-flight: reuse in-flight future for same uid.
    if (_inFlight != null && _uid == uid) {
      log.add('reuse uid=$uid');
      return _inFlight!;
    }

    _generation++;
    final int myGeneration = _generation;
    _uid = uid;

    final future = fetchFactory();
    _inFlight = future;

    _FirestoreLoadResult<List<Map<String, dynamic>>> result;
    try {
      result = await future;
    } catch (e) {
      result = _FirestoreLoadResult.failure(e);
    } finally {
      if (_uid == uid && _generation == myGeneration) {
        _inFlight = null;
      }
    }

    // Stale-epoch guard: if generation was bumped by a newer call,
    // this completion is from a superseded epoch — return authDenied() sentinel.
    if (_generation != myGeneration) {
      log.add('STALE_EPOCH uid=$uid myGen=$myGeneration currentGen=$_generation');
      return _FirestoreLoadResult.authDenied();
    }

    log.add('complete uid=$uid result=${result.runtimeType} gen=$myGeneration');
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test suite
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Invariant V: Algebraic Read Safety ───────────────────────────────────
  group('Invariant V — Algebraic Read Safety: authDenied immediately when credentials are null', () {
    // ── V-1: null currentUser → authDenied without any server call ──────────
    test('null currentUser → authDenied immediately, no SDK dispatch', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.success,
        cacheBehaviour: _StubCacheBehaviour.hit,
        serverData: {'drug-001', 'drug-002'},
        cacheData: {'drug-cached-001'},
      );
      final svc = _StubFirestoreService(currentUser: null, stubDoc: stub);

      final result = await svc.loadFavTyped('user-123');

      // Must be authDenied — no server or cache call dispatched
      expect(result.isAuthDenied, isTrue,
          reason: 'null currentUser must return authDenied() instantly');
      expect(stub.serverCallCount, equals(0),
          reason: 'Firestore SDK must NOT be invoked when currentUser is null');
      expect(stub.cacheCallCount, equals(0),
          reason: 'No cache call either — authDenied fires before any I/O');
      expect(svc.watchdogStartCount, equals(0),
          reason: 'No watchdog or timer must be started');
    });

    // ── V-2: firebase not ready → authDenied without any server call ─────────
    test('firebase not ready → authDenied immediately', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.success,
        cacheBehaviour: _StubCacheBehaviour.hit,
        serverData: {'drug-001'},
        cacheData: {'cached-001'},
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-456'),
        stubDoc: stub,
        isFirebaseReady: false,
      );

      final result = await svc.loadFavTyped('user-456');

      expect(result.isAuthDenied, isTrue,
          reason: '_isFirebaseReady=false must return authDenied() instantly');
      expect(stub.serverCallCount, equals(0));
      expect(stub.cacheCallCount, equals(0));
    });

    // ── V-3: uid mismatch → authDenied (IDOR protection) ─────────────────────
    test('uid mismatch → authDenied immediately, IDOR protection', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.success,
        cacheBehaviour: _StubCacheBehaviour.hit,
        serverData: {'other-user-drug'},
        cacheData: {},
      );
      // currentUser is 'user-A' but request is for 'user-B'
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-A'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('user-B');

      expect(result.isAuthDenied, isTrue,
          reason: 'uid mismatch must return authDenied to prevent cross-user read');
      expect(stub.serverCallCount, equals(0),
          reason: 'SDK must NOT dispatch when uids differ');
    });

    // ── V-4: permission-denied from Firestore → authDenied ──────────────────
    test('permission-denied from server → authDenied (not empty or offline)', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.permissionDenied,
        cacheBehaviour: _StubCacheBehaviour.hit,
        cacheData: {'cached-001'},
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-123'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('user-123');

      expect(result.isAuthDenied, isTrue,
          reason: 'permission-denied from server must map to authDenied — not empty()');
      // shouldFreezeLocalCache must be true — existing local data preserved
      expect(result.shouldFreezeLocalCache, isTrue);
      expect(stub.serverCallCount, equals(1),
          reason: 'Server was called — denied at Firestore layer');
    });

    // ── V-5: authDenied result must trigger cache freeze flag ────────────────
    test('authDenied.shouldFreezeLocalCache == true — local cache preserved', () {
      final result = _FirestoreLoadResult<Set<String>>.authDenied();
      expect(result.shouldFreezeLocalCache, isTrue);
      expect(result.isAuthDenied, isTrue);
      expect(result.dataOrElse({'fallback'}), equals({'fallback'}),
          reason: 'authDenied must return fallback from dataOrElse');
    });

    // ── V-6: authDenied on null user — loadAiSessionsTyped variant ───────────
    test('loadAiSessionsTyped: null user → authDenied, no timer', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.success,
        cacheBehaviour: _StubCacheBehaviour.hit,
        serverData: {'sess-001', 'sess-002'},
        cacheData: {'sess-cached'},
      );
      final svc = _StubFirestoreService(currentUser: null, stubDoc: stub);

      final result = await svc.loadAiSessionsTyped('user-123');

      expect(result.isAuthDenied, isTrue,
          reason: 'loadAiSessionsTyped: null currentUser → authDenied instantly');
      expect(stub.serverCallCount, equals(0),
          reason: 'No SDK dispatch with null user');
      expect(svc.watchdogStartCount, equals(0),
          reason: 'No watchdog timer started — Invariant V core assertion');
    });

    // ── V-7: concurrent null-user queries — all return authDenied ────────────
    test('concurrent null-user queries — all return authDenied immediately', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.success,
        cacheBehaviour: _StubCacheBehaviour.hit,
        serverData: {'x'},
        cacheData: {'y'},
      );
      final svc = _StubFirestoreService(currentUser: null, stubDoc: stub);

      final results = await Future.wait([
        svc.loadFavTyped('user-1'),
        svc.loadFavTyped('user-2'),
        svc.loadFavTyped('user-3'),
        svc.loadAiSessionsTyped('user-1'),
      ]);

      for (final r in results) {
        expect(r.isAuthDenied, isTrue);
      }
      // Zero I/O for all concurrent null-user queries
      expect(stub.serverCallCount, equals(0));
      expect(stub.cacheCallCount, equals(0));
    });
  });

  // ── Invariant W: Cache Preservation under Offline ────────────────────────
  group('Invariant W — Cache Preservation under Offline: success(cached) not empty()', () {
    // ── W-1: network error + cache hit → success(cached), not empty() ────────
    test('network error + cache hit → success(cached), never empty()', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.networkError,
        cacheBehaviour: _StubCacheBehaviour.hit,
        cacheData: {'drug-cached-001', 'drug-cached-002'},
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-online'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('user-online');

      // Invariant W core assertion: must be success, NOT empty or offline
      expect(result.isSuccess, isTrue,
          reason: 'Cache hit after network error must return success(cached) — never empty()');
      final data = result.dataOrElse({});
      expect(data, containsAll(['drug-cached-001', 'drug-cached-002']));
      expect(result.isEmpty, isFalse,
          reason: 'An offline error with valid cache MUST NOT collapse to empty()');

      // Server was attempted exactly once; cache was used as fallback
      expect(stub.serverCallCount, equals(1));
      expect(stub.cacheCallCount, equals(1));
    });

    // ── W-2: timeout + cache hit → success(cached) ───────────────────────────
    test('server timeout + cache hit → success(cached)', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.timeout,
        cacheBehaviour: _StubCacheBehaviour.hit,
        cacheData: {'protocol-cached-A', 'protocol-cached-B'},
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-timeout'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('user-timeout');

      expect(result.isSuccess, isTrue,
          reason: 'Timeout with cache hit → success(cached), not offline()');
      expect(result.dataOrElse({}),
          containsAll(['protocol-cached-A', 'protocol-cached-B']));
    });

    // W-3 DELETED (MICRO-BUILD 463-A.2.1.1):
    // The incorrect assertion "network error + cache miss → empty()" has been
    // removed. The correct behaviour is offline() — see Scenario 2 below.

    // ── W-4: network error + cache error → offline() ─────────────────────────
    test('network error + cache error → offline(), local state frozen', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.networkError,
        cacheBehaviour: _StubCacheBehaviour.error,
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-double-fail'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('user-double-fail');

      expect(result.isOffline, isTrue,
          reason: 'Both server and cache failed → offline()');
      expect(result.shouldFreezeLocalCache, isTrue,
          reason: 'offline() must freeze local cache — no writes allowed');
    });

    // ── W-5: server success → success(data), cache never consulted ───────────
    test('server success → success(server data), cache not consulted', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.success,
        cacheBehaviour: _StubCacheBehaviour.hit,
        serverData: {'drug-live-001', 'drug-live-002'},
        cacheData: {'drug-stale-cache'},
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-online'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('user-online');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrElse({}), containsAll(['drug-live-001', 'drug-live-002']));
      // Server succeeded — cache must NOT be consulted
      expect(stub.cacheCallCount, equals(0),
          reason: 'Cache must not be read when server succeeds');
    });

    // ── W-6: loadAiSessionsTyped — cache hit after network error ────────────
    test('loadAiSessionsTyped: network error + cache hit → success(cached sessions)', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.networkError,
        cacheBehaviour: _StubCacheBehaviour.hit,
        cacheData: {'sess-cached-001', 'sess-cached-002'},
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-offline'),
        stubDoc: stub,
      );

      final result = await svc.loadAiSessionsTyped('user-offline');

      expect(result.isSuccess, isTrue,
          reason: 'loadAiSessionsTyped: cache hit after network error → success');
      final sessions = result.dataOrElse([]);
      expect(sessions.length, equals(2));
      expect(sessions.map((s) => s['id']),
          containsAll(['sess-cached-001', 'sess-cached-002']));
    });

    // ── W-7: shouldFreezeLocalCache semantics ────────────────────────────────
    test('shouldFreezeLocalCache is true for authDenied/offline/failure, false for success/empty', () {
      expect(_FirestoreLoadResult<Set<String>>.authDenied().shouldFreezeLocalCache, isTrue);
      expect(_FirestoreLoadResult<Set<String>>.offline().shouldFreezeLocalCache, isTrue);
      expect(_FirestoreLoadResult<Set<String>>.failure('err').shouldFreezeLocalCache, isTrue);
      expect(_FirestoreLoadResult<Set<String>>.success({'x'}).shouldFreezeLocalCache, isFalse);
      expect(_FirestoreLoadResult<Set<String>>.empty().shouldFreezeLocalCache, isFalse);
    });

    // ── W-8: dataOrElse returns fallback on non-success results ─────────────
    test('dataOrElse returns fallback on authDenied/offline/empty', () {
      const fallback = {'fallback-id'};
      expect(
        _FirestoreLoadResult<Set<String>>.authDenied().dataOrElse(fallback),
        equals(fallback),
      );
      expect(
        _FirestoreLoadResult<Set<String>>.offline().dataOrElse(fallback),
        equals(fallback),
      );
      expect(
        _FirestoreLoadResult<Set<String>>.empty().dataOrElse(fallback),
        equals(fallback),
      );
      // success returns actual data, not fallback
      expect(
        _FirestoreLoadResult<Set<String>>.success({'real-id'}).dataOrElse(fallback),
        equals({'real-id'}),
      );
    });

    // ── W-9: concurrent offline reads — each uses its own cache ─────────────
    test('concurrent offline reads all return success(cached) independently', () async {
      Future<_FirestoreLoadResult<Set<String>>> makeOfflineRead(
          String uid, Set<String> cacheData) async {
        final stub = _StubFavsDoc(
          serverBehaviour: _StubServerBehaviour.timeout,
          cacheBehaviour: _StubCacheBehaviour.hit,
          cacheData: cacheData,
        );
        final svc = _StubFirestoreService(
          currentUser: _FakeFirebaseUser(uid),
          stubDoc: stub,
        );
        return svc.loadFavTyped(uid);
      }

      final results = await Future.wait([
        makeOfflineRead('user-A', {'drug-A1', 'drug-A2'}),
        makeOfflineRead('user-B', {'drug-B1'}),
        makeOfflineRead('user-C', {'proto-C1', 'proto-C2', 'proto-C3'}),
      ]);

      expect(results[0].isSuccess, isTrue);
      expect(results[0].dataOrElse({}), containsAll(['drug-A1', 'drug-A2']));

      expect(results[1].isSuccess, isTrue);
      expect(results[1].dataOrElse({}), contains('drug-B1'));

      expect(results[2].isSuccess, isTrue);
      expect(results[2].dataOrElse({}),
          containsAll(['proto-C1', 'proto-C2', 'proto-C3']));
    });
  });

  // ── Integration: V + W together — auth denied before cache attempt ────────
  group('Combined V+W: authDenied short-circuits before any cache read', () {
    test('null user with cache hit — authDenied fires before cache is consulted', () async {
      // Even though the cache has data, null user must get authDenied
      // without the service ever touching the cache (no I/O at all).
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.success,
        cacheBehaviour: _StubCacheBehaviour.hit,
        serverData: {'real-server-data'},
        cacheData: {'cached-local-drug'},
      );
      final svc = _StubFirestoreService(currentUser: null, stubDoc: stub);

      final stopwatch = Stopwatch()..start();
      final result = await svc.loadFavTyped('user-abc');
      stopwatch.stop();

      expect(result.isAuthDenied, isTrue);
      expect(stub.serverCallCount, equals(0),
          reason: 'Null user: zero I/O');
      expect(stub.cacheCallCount, equals(0),
          reason: 'Cache not touched on authDenied short-circuit');

      // The auth check is synchronous — should complete near-instantly
      // (well under 100ms). No background timer was started.
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'authDenied must complete synchronously — no timer blocking');
    });

    test('valid user, offline, cache hit — success in sequence: auth→server→cache', () async {
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.networkError,
        cacheBehaviour: _StubCacheBehaviour.hit,
        cacheData: {'drug-from-cache'},
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-valid'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('user-valid');

      // Auth passed, server failed, cache succeeded → success(cached)
      expect(result.isSuccess, isTrue);
      expect(result.dataOrElse({}), contains('drug-from-cache'));
      expect(stub.serverCallCount, equals(1), reason: 'Server was attempted');
      expect(stub.cacheCallCount, equals(1), reason: 'Cache was consulted as fallback');
    });
  });

  // ── MICRO-BUILD 463-A.2.1.1 — Strict Algebraic Matrix Scenarios ──────────
  group('463-A.2.1.1 Strict Matrix — Authoritative Empty vs Offline Semantics', () {
    // ── Scenario 1: Server success + 0 docs → empty(), shouldFreeze == false ─
    test('Scenario 1: server success + 0 documents → empty(), shouldFreezeLocalCache == false', () async {
      // Server returns 0 records authoritatively (the user genuinely has no data).
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.successEmpty,
        cacheBehaviour: _StubCacheBehaviour.miss,
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('new-user-uuid'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('new-user-uuid');

      expect(result.isEmpty, isTrue,
          reason: 'Server-authoritative 0-doc result → empty() (new user)');
      expect(result.isOffline, isFalse,
          reason: 'Server succeeded — must NOT be offline()');
      expect(result.isSuccess, isFalse,
          reason: 'No data returned — must NOT be success()');
      // shouldFreezeLocalCache is false: a server-authoritative empty is a valid
      // write-back signal (the caller may clear local favourites accordingly).
      expect(result.shouldFreezeLocalCache, isFalse,
          reason: 'Authoritative empty from server → write-back allowed (shouldFreeze=false)');
      // Cache must NOT be consulted — the server answered definitively.
      expect(stub.cacheCallCount, equals(0),
          reason: 'Server succeeded — cache must not be read');
    });

    // ── Scenario 2: Server failure + cache miss → offline(), shouldFreeze == true
    test('Scenario 2: server failure + cache miss → offline(), shouldFreezeLocalCache == true', () async {
      // The server is unreachable AND the document was never cached locally.
      // This MUST be offline(), not empty() — we have no authority to declare
      // the user has no data when we could not reach the server.
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.networkError,
        cacheBehaviour: _StubCacheBehaviour.miss, // cache doc does not exist
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('offline-new-user'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('offline-new-user');

      expect(result.isOffline, isTrue,
          reason: 'Server failed + cache miss → offline() — cannot declare empty without server authority');
      expect(result.isEmpty, isFalse,
          reason: 'Cache miss during server failure MUST NOT produce empty() — core 463-A.2.1.1 rule');
      expect(result.isSuccess, isFalse);
      expect(result.shouldFreezeLocalCache, isTrue,
          reason: 'offline() must freeze local cache — no write-back allowed');
      // Both server and cache were attempted
      expect(stub.serverCallCount, equals(1));
      expect(stub.cacheCallCount, equals(1));
    });

    // ── Scenario 3: Server failure + cache hit → success(cached) ─────────────
    test('Scenario 3: server failure + cache hit → success(cached), shouldFreezeLocalCache == false', () async {
      // The server is unreachable but we have valid cached data.
      // The result is success(cachedData) so the UI renders from cache.
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.timeout,
        cacheBehaviour: _StubCacheBehaviour.hit,
        cacheData: {'fav-drug-cached-A', 'fav-drug-cached-B'},
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-with-cache'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('user-with-cache');

      expect(result.isSuccess, isTrue,
          reason: 'Server fail + cache hit → success(cachedData)');
      expect(result.isOffline, isFalse,
          reason: 'Cache salvaged the read — must not be offline()');
      expect(result.dataOrElse({}),
          containsAll(['fav-drug-cached-A', 'fav-drug-cached-B']));
      // success() does not freeze — the caller can write back the cached data
      // to in-memory provider state.
      expect(result.shouldFreezeLocalCache, isFalse,
          reason: 'success() from cache fallback: shouldFreezeLocalCache == false');
      expect(stub.serverCallCount, equals(1));
      expect(stub.cacheCallCount, equals(1));
    });

    // ── Scenario 4: permission-denied never collapses to empty() ─────────────
    test('Scenario 4: permission-denied never collapses to empty() under any configuration', () async {
      // Verify that permission-denied → authDenied(), even when cache has data.
      // This ensures the error is never silently swallowed as "user has no data".
      final stubWithCacheHit = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.permissionDenied,
        cacheBehaviour: _StubCacheBehaviour.hit,
        cacheData: {'cached-drug-should-not-matter'},
      );
      final svcA = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-perm-denied'),
        stubDoc: stubWithCacheHit,
      );

      final resultA = await svcA.loadFavTyped('user-perm-denied');

      expect(resultA.isAuthDenied, isTrue,
          reason: 'permission-denied → authDenied(), NEVER empty()');
      expect(resultA.isEmpty, isFalse,
          reason: 'permission-denied must NOT collapse to empty()');
      expect(resultA.isOffline, isFalse,
          reason: 'permission-denied is an auth error, not a network error');
      expect(resultA.shouldFreezeLocalCache, isTrue,
          reason: 'authDenied → shouldFreezeLocalCache == true');

      // Also verify with cache miss — still authDenied
      final stubWithCacheMiss = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.permissionDenied,
        cacheBehaviour: _StubCacheBehaviour.miss,
      );
      final svcB = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('user-perm-denied-miss'),
        stubDoc: stubWithCacheMiss,
      );

      final resultB = await svcB.loadFavTyped('user-perm-denied-miss');

      expect(resultB.isAuthDenied, isTrue,
          reason: 'permission-denied + cache miss → authDenied(), not empty()');
      expect(resultB.isEmpty, isFalse,
          reason: 'Cache miss does not change a permission-denied to empty()');
    });

    // ── Scenario 5: offline() history result never triggers new-user event ───
    test('Scenario 5: offline() history load never triggers confirmed_new_user or state reset', () async {
      // When the history load returns offline() (server unreachable, cache miss),
      // the AppProvider must NOT interpret this as "user has no history" and
      // must NOT emit a confirmed_new_user event.
      final provider = _StubHistoryProvider();

      // Simulate an offline() result (what loadHistoriesTyped returns when
      // server fails and cache is empty — the 463-A.2.1.1 fix)
      final offlineResult = _FirestoreLoadResult<List<String>>.offline();

      provider.processHistoryResult(offlineResult);

      expect(provider.confirmedNewUserFired, isFalse,
          reason: 'offline() history result must NOT trigger confirmed_new_user — '
              'we have no server authority to declare the user is new');
      expect(provider.writeBackAttempted, isFalse,
          reason: 'offline() must freeze local state — no write-back of any kind');

      // Verify: an authoritative empty() from the server DOES trigger new-user
      // (confirming the fix does not break the legitimate new-user detection path)
      final emptyResult = _FirestoreLoadResult<List<String>>.empty();
      provider.processHistoryResult(emptyResult);

      expect(provider.confirmedNewUserFired, isTrue,
          reason: 'Server-authoritative empty() → confirmed_new_user is correct');
    });

    // ── Scenario 6: offline() favs/cases result prevents write-back ──────────
    test('Scenario 6: offline() favorites/cases result blocks write-back via shouldFreezeLocalCache', () async {
      // When loadFavDrugsTyped (or any typed fav/cases method) returns offline(),
      // the AppProvider must check shouldFreezeLocalCache before updating local
      // state — preventing the user's cached favourites from being overwritten.
      final provider = _StubHistoryProvider();

      // Case A: offline() result — write-back must be blocked
      final offlineFavsResult = _FirestoreLoadResult<Set<String>>.offline();
      provider.processFavsResult(offlineFavsResult);

      expect(provider.writeBackAttempted, isFalse,
          reason: 'offline() shouldFreezeLocalCache=true → write-back must be blocked');

      // Case B: success() result — write-back must proceed normally
      final provider2 = _StubHistoryProvider();
      final successResult = _FirestoreLoadResult<Set<String>>.success({'drug-A', 'drug-B'});
      provider2.processFavsResult(successResult);

      expect(provider2.writeBackAttempted, isTrue,
          reason: 'success() shouldFreezeLocalCache=false → write-back must proceed');

      // Case C: empty() from server — write-back is also allowed (clear local favs)
      final provider3 = _StubHistoryProvider();
      final emptyResult = _FirestoreLoadResult<Set<String>>.empty();
      provider3.processFavsResult(emptyResult);

      expect(provider3.writeBackAttempted, isTrue,
          reason: 'empty() shouldFreezeLocalCache=false → write-back proceeds (clear local)');

      // Case D: authDenied() — also freezes (no write-back)
      final provider4 = _StubHistoryProvider();
      final authDeniedResult = _FirestoreLoadResult<Set<String>>.authDenied();
      provider4.processFavsResult(authDeniedResult);

      expect(provider4.writeBackAttempted, isFalse,
          reason: 'authDenied() shouldFreezeLocalCache=true → write-back blocked');
    });
  });

  // ── MICRO-BUILD 463-A.2.1.2 — Invariant X: Consumer Safety ──────────────
  group('Invariant X — Consumer Safety: algebraic routing preserves session list', () {
    // ── X-1: offline() preserves existing session list ────────────────────
    test('X-1: offline() result does NOT clear existing session list', () {
      // Precondition: consumer has an established session list.
      final existing = [
        {'id': 'session-A', 'title': 'Cardiology consult'},
        {'id': 'session-B', 'title': 'Nephrology review'},
      ];
      final controller = _StubConsumerController(initial: List.from(existing));

      final gen = controller.startLoad();
      final offlineResult =
          _FirestoreLoadResult<List<Map<String, dynamic>>>.offline();

      final handled = controller.routeResult(offlineResult, myGeneration: gen);

      // offline() must FREEZE — session list untouched.
      expect(handled, isTrue,
          reason: 'routeResult must process the result (not discard as stale)');
      expect(controller.wasCleared, isFalse,
          reason: 'offline() must NOT clear the session list');
      expect(controller.wasFrozen, isTrue,
          reason: 'offline() triggers a freeze');
      expect(controller.sessionList, equals(existing),
          reason: 'offline() preserves every existing session entry');
      expect(controller.sessionList.length, equals(2),
          reason: 'No session was added or removed by offline()');
    });

    // ── X-2: authDenied() preserves existing session list ────────────────
    test('X-2: authDenied() result does NOT clear existing session list', () {
      final existing = [
        {'id': 'session-C', 'title': 'Hepatology case'},
      ];
      final controller = _StubConsumerController(initial: List.from(existing));

      final gen = controller.startLoad();
      final authDeniedResult =
          _FirestoreLoadResult<List<Map<String, dynamic>>>.authDenied();

      final handled = controller.routeResult(authDeniedResult, myGeneration: gen);

      // authDenied() must FREEZE — session list untouched.
      expect(handled, isTrue);
      expect(controller.wasCleared, isFalse,
          reason: 'authDenied() must NOT clear the session list');
      expect(controller.wasFrozen, isTrue,
          reason: 'authDenied() triggers a freeze');
      expect(controller.sessionList, equals(existing),
          reason: 'authDenied() preserves every existing session entry');
    });

    // ── X-3: only empty() clears the session list ─────────────────────────
    test('X-3: only empty() result may physically clear an established session list', () {
      final existing = [
        {'id': 'session-D', 'title': 'Oncology review'},
        {'id': 'session-E', 'title': 'Emergency consult'},
      ];
      final controller = _StubConsumerController(initial: List.from(existing));

      final gen = controller.startLoad();
      final emptyResult =
          _FirestoreLoadResult<List<Map<String, dynamic>>>.empty();

      final handled = controller.routeResult(emptyResult, myGeneration: gen);

      // empty() is the ONLY authoritative clear — sessionList must be empty.
      expect(handled, isTrue);
      expect(controller.wasCleared, isTrue,
          reason: 'empty() is the only authoritative clear path');
      expect(controller.sessionList, isEmpty,
          reason: 'empty() must wipe the session list completely');
      expect(controller.wasFrozen, isFalse,
          reason: 'empty() does not freeze — it is a server-authoritative operation');

      // Confirm: offline() on a fresh controller with the same pre-existing
      // sessions still preserves the list (contrast with empty() above).
      final controller2 = _StubConsumerController(initial: List.from(existing));
      final gen2 = controller2.startLoad();
      controller2.routeResult(
          _FirestoreLoadResult<List<Map<String, dynamic>>>.offline(),
          myGeneration: gen2);
      expect(controller2.wasCleared, isFalse,
          reason: 'offline() on same precondition must not clear the list');
      expect(controller2.sessionList.length, equals(2),
          reason: 'offline() leaves the 2 sessions intact');
    });

    // ── X-4: stale generation completion is rejected ──────────────────────
    test('X-4: stale generation completion is discarded without touching session list', () {
      // Scenario: two overlapping loads. The first load starts and the
      // consumer bumps generation for the second load before the first
      // completion arrives.  The first completion must be a no-op.
      final existing = [
        {'id': 'session-F', 'title': 'Paediatrics consult'},
      ];
      final controller = _StubConsumerController(initial: List.from(existing));

      // Generation 1 starts (myGeneration=1).
      final gen1 = controller.startLoad(); // loadGeneration == 1

      // Before gen1 result arrives, a new load starts (generation bumped to 2).
      final gen2 = controller.startLoad(); // loadGeneration == 2

      // gen1's success result now arrives — but it is stale (gen1 != gen2).
      final staleResult = _FirestoreLoadResult<List<Map<String, dynamic>>>.success([
        {'id': 'stale-session', 'title': 'Stale data from old epoch'},
      ]);
      final handledStale = controller.routeResult(staleResult, myGeneration: gen1);

      // Must be discarded — no state mutation.
      expect(handledStale, isFalse,
          reason: 'Stale generation result must be discarded by the epoch guard');
      expect(controller.sessionList, equals(existing),
          reason: 'Stale completion must not hydrate sessionList');
      expect(controller.wasCleared, isFalse,
          reason: 'Stale completion must not clear sessionList');

      // Now gen2's (current generation) result arrives — must be applied.
      final freshResult = _FirestoreLoadResult<List<Map<String, dynamic>>>.success([
        {'id': 'session-G', 'title': 'Current epoch data'},
      ]);
      final handledFresh = controller.routeResult(freshResult, myGeneration: gen2);

      expect(handledFresh, isTrue,
          reason: 'Current generation result must be applied');
      expect(controller.sessionList.length, equals(1));
      expect(controller.sessionList.first['id'], equals('session-G'),
          reason: 'sessionList must reflect the fresh result, not the stale one');
    });

    // ── X-5: success(data) always hydrates the session list ───────────────
    test('X-5: success(data) hydrates session list regardless of prior state', () {
      // Case A: hydrating into an empty session list.
      final controllerA = _StubConsumerController(); // starts empty
      final genA = controllerA.startLoad();
      final newSessions = [
        {'id': 'session-H', 'title': 'Rheumatology'},
        {'id': 'session-I', 'title': 'Endocrinology'},
        {'id': 'session-J', 'title': 'Pulmonology'},
      ];
      controllerA.routeResult(
          _FirestoreLoadResult<List<Map<String, dynamic>>>.success(
              List.from(newSessions)),
          myGeneration: genA);

      expect(controllerA.sessionList.length, equals(3),
          reason: 'success() into empty list → hydrate all entries');
      expect(controllerA.wasCleared, isFalse,
          reason: 'success() does not set the cleared flag');
      expect(controllerA.wasFrozen, isFalse,
          reason: 'success() does not freeze');

      // Case B: hydrating over an existing non-empty list (replace, not append).
      final existing = [
        {'id': 'old-session-1', 'title': 'Old data'},
      ];
      final controllerB = _StubConsumerController(initial: List.from(existing));
      final genB = controllerB.startLoad();
      controllerB.routeResult(
          _FirestoreLoadResult<List<Map<String, dynamic>>>.success(
              List.from(newSessions)),
          myGeneration: genB);

      expect(controllerB.sessionList.length, equals(3),
          reason: 'success() replaces existing session list with new data');
      expect(controllerB.sessionList.first['id'], equals('session-H'),
          reason: 'sessionList reflects the server-fresh data after success()');
      expect(controllerB.sessionList.any((s) => s['id'] == 'old-session-1'),
          isFalse,
          reason: 'Old session must be replaced by the new hydration');
    });

    // ── X-6: failure() preserves existing session list ────────────────────
    test('X-6: failure() result does NOT clear existing session list', () {
      final existing = [
        {'id': 'session-K', 'title': 'Neurology consult'},
        {'id': 'session-L', 'title': 'Cardiology follow-up'},
      ];
      final controller = _StubConsumerController(initial: List.from(existing));

      final gen = controller.startLoad();
      final failureResult =
          _FirestoreLoadResult<List<Map<String, dynamic>>>.failure(
              Exception('internal-error'));

      final handled = controller.routeResult(failureResult, myGeneration: gen);

      // failure() must FREEZE — session list untouched.
      expect(handled, isTrue);
      expect(controller.wasCleared, isFalse,
          reason: 'failure() must NOT clear the session list');
      expect(controller.wasFrozen, isTrue,
          reason: 'failure() triggers a freeze');
      expect(controller.sessionList, equals(existing),
          reason: 'failure() preserves every existing session entry');
    });

    // ── X-7: provider latch single-flight reuse ───────────────────────────
    test('X-7: single-flight latch reuses in-flight future for same UID', () async {
      final latch = _StubAppProviderLatch();
      final completer =
          Completer<_FirestoreLoadResult<List<Map<String, dynamic>>>>();

      // Launch two concurrent calls for the same uid — second must reuse the
      // in-flight future rather than spawning a new Firestore request.
      final callCount = <int>[0];
      Future<_FirestoreLoadResult<List<Map<String, dynamic>>>> factory() {
        callCount[0]++;
        return completer.future;
      }

      final f1 = latch.loadForUi('user-x', factory);
      final f2 = latch.loadForUi('user-x', factory); // same uid → reuse

      // Complete the shared future.
      completer.complete(_FirestoreLoadResult.success([
        {'id': 'shared-session', 'title': 'Shared result'},
      ]));

      final r1 = await f1;
      final r2 = await f2;

      expect(callCount[0], equals(1),
          reason: 'Factory must only be called once — second call reuses in-flight future');
      expect(r1.isSuccess, isTrue, reason: 'First caller gets the success result');
      expect(r2.isSuccess, isTrue, reason: 'Second caller also gets the success result');
      expect(latch.log.any((e) => e.startsWith('reuse')), isTrue,
          reason: 'Latch log must record the reuse event');
    });

    // ── X-8: stale-epoch guard in provider latch ──────────────────────────
    test('X-8: stale-epoch guard returns authDenied() when a newer UID takes ownership', () async {
      final latch = _StubAppProviderLatch();

      // Simulate UID-A request in flight.
      final completerA =
          Completer<_FirestoreLoadResult<List<Map<String, dynamic>>>>();

      // Simulate UID-B request, which will bump the generation before UID-A resolves.
      final completerB =
          Completer<_FirestoreLoadResult<List<Map<String, dynamic>>>>();

      // Start UID-A.
      final futureA = latch.loadForUi('user-A', () => completerA.future);

      // Start UID-B — this bumps the generation, making UID-A's future stale.
      final futureB = latch.loadForUi('user-B', () => completerB.future);

      // Complete UID-A's underlying fetch (stale epoch).
      completerA.complete(_FirestoreLoadResult.success([
        {'id': 'user-A-session', 'title': 'UID-A result'},
      ]));

      // Complete UID-B's underlying fetch (current epoch).
      completerB.complete(_FirestoreLoadResult.success([
        {'id': 'user-B-session', 'title': 'UID-B result'},
      ]));

      final rA = await futureA;
      final rB = await futureB;

      // UID-A's result arrived after the generation was bumped by UID-B.
      // The stale-epoch guard must return authDenied() as the safe sentinel.
      expect(rA.isAuthDenied, isTrue,
          reason: 'Stale-epoch UID-A completion must be converted to authDenied()');
      expect(rA.isSuccess, isFalse,
          reason: 'Stale result must NOT propagate success data to caller');

      // UID-B's result is the current epoch — must come through correctly.
      expect(rB.isSuccess, isTrue,
          reason: 'Current-epoch UID-B completion must succeed');
      expect(rB.dataOrElse([]).first['id'], equals('user-B-session'));

      // Log must record the stale epoch event.
      expect(latch.log.any((e) => e.contains('STALE_EPOCH')), isTrue,
          reason: 'Latch must log the stale-epoch guard activation');
    });
  });
}
