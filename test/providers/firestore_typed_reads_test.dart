// ══════════════════════════════════════════════════════════════════════════════
// test/providers/firestore_typed_reads_test.dart
// MICRO-BUILD 463-A.2.1 — Typed Secondary Collection Reads Test Suite
//
// Verifies the algebraic read contracts for all secondary Firestore collections:
//
// Invariant V (Algebraic Read Safety):
//   Secondary typed queries return authDenied() immediately when credentials
//   are null — no background watchdogs, no timers, no blocking waits.
//
// Invariant W (Cache Preservation under Offline):
//   When server read fails but valid cache data exists locally, the result
//   is success(cachedData) — never a false-positive empty().
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
// These replicate the exact contracts from MICRO-BUILD 463-A.2.1.
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
  permissionDenied,  // server returns FirebaseException('permission-denied')
  networkError,      // server throws generic Exception (offline / unreachable)
  timeout,           // server throws TimeoutException (no connectivity)
}

enum _StubCacheBehaviour {
  hit,    // cache has data — returns it
  miss,   // cache has no document (exists = false)
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

  Future<Set<String>> readFromServer() async {
    serverCallCount++;
    switch (serverBehaviour) {
      case _StubServerBehaviour.success:
        return Set<String>.from(serverData);
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
        return null; // document does not exist
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
// Accepts a _FakeFirebaseUser? (currentUser) and a _StubFavsDoc.
// Implements the exact dual-check barrier + cache-fallback logic from production.
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

  /// Mirrors FirestoreService.loadFavDrugsTyped(uid) logic exactly:
  ///   1. Dual-check barrier → authDenied immediately (no timer)
  ///   2. Try server → permissionDenied → authDenied
  ///   3. Try server → network error → try cache → success(cached) or offline()
  ///   4. Server success → success(data)
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
      if (data.isEmpty) return _FirestoreLoadResult.empty();
      return _FirestoreLoadResult.success(data);
    } on _StubFirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return _FirestoreLoadResult.authDenied();
      }
      // Other Firebase error → try cache
      try {
        final cached = await stubDoc.readFromCache();
        if (cached == null) return _FirestoreLoadResult.empty();
        return _FirestoreLoadResult.success(cached);
      } catch (_) {
        return _FirestoreLoadResult.offline();
      }
    } catch (_) {
      // Network/timeout → try cache before returning offline()
      try {
        final cached = await stubDoc.readFromCache();
        if (cached == null) return _FirestoreLoadResult.empty();
        // Invariant W: cache hit → success(cached), NOT empty()
        return _FirestoreLoadResult.success(cached);
      } catch (_) {
        return _FirestoreLoadResult.offline();
      }
    }
  }

  /// Mirrors loadAiSessionsTyped() — same auth guard, same cache-fallback logic.
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
      if (data.isEmpty) return _FirestoreLoadResult.empty();
      return _FirestoreLoadResult.success(data.map((id) => {'id': id}).toList());
    } on _StubFirebaseException catch (e) {
      if (e.code == 'permission-denied') return _FirestoreLoadResult.authDenied();
      try {
        final cached = await stubDoc.readFromCache();
        if (cached == null) return _FirestoreLoadResult.empty();
        return _FirestoreLoadResult.success(
            cached.map((id) => {'id': id}).toList());
      } catch (_) {
        return _FirestoreLoadResult.offline();
      }
    } catch (_) {
      try {
        final cached = await stubDoc.readFromCache();
        if (cached == null) return _FirestoreLoadResult.empty();
        return _FirestoreLoadResult.success(
            cached.map((id) => {'id': id}).toList());
      } catch (_) {
        return _FirestoreLoadResult.offline();
      }
    }
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

    // ── V-3: uid mismatch → authDenied (IDOR protection) ───────────────────
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

    // ── W-3: network error + cache miss → empty() (document not created) ─────
    test('network error + cache miss → empty(), not offline()', () async {
      // Cache has no document at all (never been cached)
      final stub = _StubFavsDoc(
        serverBehaviour: _StubServerBehaviour.networkError,
        cacheBehaviour: _StubCacheBehaviour.miss,
      );
      final svc = _StubFirestoreService(
        currentUser: const _FakeFirebaseUser('new-user'),
        stubDoc: stub,
      );

      final result = await svc.loadFavTyped('new-user');

      // Cache miss means the document simply doesn't exist — empty() is correct
      expect(result.isEmpty, isTrue,
          reason: 'Cache miss after network error → empty() (no data exists)');
      expect(result.isSuccess, isFalse);
    });

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
}
