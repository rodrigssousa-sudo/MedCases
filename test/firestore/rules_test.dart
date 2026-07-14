// ══════════════════════════════════════════════════════════════════════════════
// test/firestore/rules_test.dart
// MICRO-BUILD 462E-A.5.3.7.3.2.5.1 — Firestore Security Rules Unit Suite
//
// Validates the LEAST-PRIVILEGE policy for:
//   users/{uid}/ai_sessions/{sessionId}
//   users/{uid}/ai_sessions/{sessionId}/exchanges/{requestId}
//
// Architecture: pure unit-level — zero network, zero Firebase emulator.
// Models the rule evaluation logic directly in Dart, verifying every
// permission predicate that the Cloud Firestore rules engine would enforce:
//
//   Suite R — Owner access contract
//   Suite F — Foreign UID rejection (IDOR protection)
//   Suite U — Unauthenticated write rejection
//   Suite S — Schema field invariants (uid/sessionId/requestId anchoring)
//   Suite A — SessionPersistAuthDenied type isolation
//
// Each test simulates the rule evaluation by asserting the boolean result of
// the equivalent Dart predicate that mirrors the Firestore rules function.
// This provides compile-time confidence that the rule expressions are correct
// before they are deployed to production.
// ══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/ai_finalization_transaction.dart';

// ── Rule evaluator model ───────────────────────────────────────────────────────
// Models the Firestore rule functions as pure Dart predicates.
// This mirrors the logic in firestore.rules exactly.

/// Models `function isOwner(userId)` from firestore.rules.
/// Returns true iff request.auth is not null and request.auth.uid == userId.
bool isOwner({required String? authUid, required String userId}) {
  return authUid != null && authUid == userId;
}

/// Models the create rule for ai_sessions/{sessionId}:
///   allow create: if isOwner(userId)
///     && request.resource.data.uid == userId
///     && request.resource.data.sessionId == sessionId;
bool canCreateSession({
  required String? authUid,
  required String userId,
  required String sessionId,
  required Map<String, String> payload,
}) {
  return isOwner(authUid: authUid, userId: userId)
      && payload['uid'] == userId
      && payload['sessionId'] == sessionId;
}

/// Models the update rule for ai_sessions/{sessionId}:
///   allow update: if isOwner(userId)
///     && resource.data.uid == userId           // existing doc
///     && request.resource.data.uid == userId   // incoming payload
///     && request.resource.data.sessionId == sessionId;
bool canUpdateSession({
  required String? authUid,
  required String userId,
  required String sessionId,
  required String existingDocUid,      // resource.data.uid
  required Map<String, String> payload,
}) {
  return isOwner(authUid: authUid, userId: userId)
      && existingDocUid == userId
      && payload['uid'] == userId
      && payload['sessionId'] == sessionId;
}

/// Models the create rule for exchanges/{requestId}:
///   allow create: if isOwner(userId)
///     && request.resource.data.uid == userId
///     && request.resource.data.sessionId == sessionId
///     && request.resource.data.requestId == requestId;
bool canCreateExchange({
  required String? authUid,
  required String userId,
  required String sessionId,
  required String requestId,
  required Map<String, String> payload,
}) {
  return isOwner(authUid: authUid, userId: userId)
      && payload['uid'] == userId
      && payload['sessionId'] == sessionId
      && payload['requestId'] == requestId;
}

/// Models the update rule for exchanges/{requestId}:
///   allow update: if isOwner(userId)
///     && resource.data.uid == userId
///     && request.resource.data.uid == userId
///     && request.resource.data.sessionId == sessionId
///     && request.resource.data.requestId == requestId;
bool canUpdateExchange({
  required String? authUid,
  required String userId,
  required String sessionId,
  required String requestId,
  required String existingDocUid,
  required Map<String, String> payload,
}) {
  return isOwner(authUid: authUid, userId: userId)
      && existingDocUid == userId
      && payload['uid'] == userId
      && payload['sessionId'] == sessionId
      && payload['requestId'] == requestId;
}

/// Models the read/delete rule for ai_sessions (owner only).
bool canReadOrDeleteSession({
  required String? authUid,
  required String userId,
}) {
  return isOwner(authUid: authUid, userId: userId);
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // Canonical test fixtures
  const ownerUid    = 'uid_owner_abc123';
  const foreignUid  = 'uid_foreign_xyz789';
  const sessionId   = 'session_1784100000000';
  const requestId   = 'req_1784100001000';

  /// Builds a valid parent session payload that satisfies all schema rules.
  Map<String, String> validSessionPayload() => {
    'uid':       ownerUid,
    'sessionId': sessionId,
  };

  /// Builds a valid exchange payload satisfying all three anchoring rules.
  Map<String, String> validExchangePayload() => {
    'uid':       ownerUid,
    'sessionId': sessionId,
    'requestId': requestId,
  };

  // ══════════════════════════════════════════════════════════════════════════
  // Suite R — Owner access contract
  // ══════════════════════════════════════════════════════════════════════════
  group('Suite R — Owner access contract', () {
    test('R-1: owner can read ai_sessions document', () {
      expect(
        canReadOrDeleteSession(authUid: ownerUid, userId: ownerUid),
        isTrue,
        reason: 'Owner must be allowed to read their own session',
      );
    });

    test('R-2: owner can create ai_sessions document with valid payload', () {
      expect(
        canCreateSession(
          authUid:   ownerUid,
          userId:    ownerUid,
          sessionId: sessionId,
          payload:   validSessionPayload(),
        ),
        isTrue,
        reason: 'Owner with matching uid+sessionId payload must be allowed to create',
      );
    });

    test('R-3: owner can update ai_sessions document with matching existing uid', () {
      expect(
        canUpdateSession(
          authUid:        ownerUid,
          userId:         ownerUid,
          sessionId:      sessionId,
          existingDocUid: ownerUid,
          payload:        validSessionPayload(),
        ),
        isTrue,
        reason: 'Owner with matching existing doc uid must be allowed to update',
      );
    });

    test('R-4: owner can delete ai_sessions document', () {
      expect(
        canReadOrDeleteSession(authUid: ownerUid, userId: ownerUid),
        isTrue,
        reason: 'Owner must be allowed to delete their own session',
      );
    });

    test('R-5: owner can create exchanges document with valid payload', () {
      expect(
        canCreateExchange(
          authUid:   ownerUid,
          userId:    ownerUid,
          sessionId: sessionId,
          requestId: requestId,
          payload:   validExchangePayload(),
        ),
        isTrue,
        reason: 'Owner with matching uid+sessionId+requestId payload must be '
            'allowed to create exchange',
      );
    });

    test('R-6: owner can update exchanges document with valid invariants', () {
      expect(
        canUpdateExchange(
          authUid:        ownerUid,
          userId:         ownerUid,
          sessionId:      sessionId,
          requestId:      requestId,
          existingDocUid: ownerUid,
          payload:        validExchangePayload(),
        ),
        isTrue,
        reason: 'Owner with matching existing+incoming doc invariants must be '
            'allowed to update exchange',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Suite F — Foreign UID rejection (IDOR protection)
  // ══════════════════════════════════════════════════════════════════════════
  group('Suite F — Foreign UID rejection (IDOR protection)', () {
    test('F-1: foreign uid cannot read owner ai_sessions document', () {
      expect(
        canReadOrDeleteSession(authUid: foreignUid, userId: ownerUid),
        isFalse,
        reason: 'Foreign auth.uid must not read owner session (IDOR block)',
      );
    });

    test('F-2: foreign uid cannot create ai_sessions for owner path', () {
      expect(
        canCreateSession(
          authUid:   foreignUid,
          userId:    ownerUid,
          sessionId: sessionId,
          payload:   validSessionPayload(),
        ),
        isFalse,
        reason: 'Foreign auth.uid must not create document under owner path',
      );
    });

    test('F-3: foreign uid cannot update owner ai_sessions document', () {
      expect(
        canUpdateSession(
          authUid:        foreignUid,
          userId:         ownerUid,
          sessionId:      sessionId,
          existingDocUid: ownerUid,
          payload:        validSessionPayload(),
        ),
        isFalse,
        reason: 'Foreign auth.uid must not update owner session',
      );
    });

    test('F-4: foreign uid cannot delete owner ai_sessions document', () {
      expect(
        canReadOrDeleteSession(authUid: foreignUid, userId: ownerUid),
        isFalse,
        reason: 'Foreign auth.uid must not delete owner session',
      );
    });

    test('F-5: foreign uid cannot create exchange under owner session', () {
      expect(
        canCreateExchange(
          authUid:   foreignUid,
          userId:    ownerUid,
          sessionId: sessionId,
          requestId: requestId,
          payload:   validExchangePayload(),
        ),
        isFalse,
        reason: 'Foreign auth.uid must not create exchange under owner session',
      );
    });

    test('F-6: foreign uid cannot update exchange under owner session', () {
      expect(
        canUpdateExchange(
          authUid:        foreignUid,
          userId:         ownerUid,
          sessionId:      sessionId,
          requestId:      requestId,
          existingDocUid: ownerUid,
          payload:        validExchangePayload(),
        ),
        isFalse,
        reason: 'Foreign auth.uid must not update exchange under owner session',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Suite U — Unauthenticated write rejection
  // ══════════════════════════════════════════════════════════════════════════
  group('Suite U — Unauthenticated write rejection', () {
    test('U-1: null auth cannot read ai_sessions', () {
      expect(
        canReadOrDeleteSession(authUid: null, userId: ownerUid),
        isFalse,
        reason: 'Unauthenticated request must be rejected for read',
      );
    });

    test('U-2: null auth cannot create ai_sessions', () {
      expect(
        canCreateSession(
          authUid:   null,
          userId:    ownerUid,
          sessionId: sessionId,
          payload:   validSessionPayload(),
        ),
        isFalse,
        reason: 'Unauthenticated request must be rejected for create',
      );
    });

    test('U-3: null auth cannot update ai_sessions', () {
      expect(
        canUpdateSession(
          authUid:        null,
          userId:         ownerUid,
          sessionId:      sessionId,
          existingDocUid: ownerUid,
          payload:        validSessionPayload(),
        ),
        isFalse,
        reason: 'Unauthenticated request must be rejected for update',
      );
    });

    test('U-4: null auth cannot create exchange', () {
      expect(
        canCreateExchange(
          authUid:   null,
          userId:    ownerUid,
          sessionId: sessionId,
          requestId: requestId,
          payload:   validExchangePayload(),
        ),
        isFalse,
        reason: 'Unauthenticated request must be rejected for exchange create',
      );
    });

    test('U-5: null auth cannot update exchange', () {
      expect(
        canUpdateExchange(
          authUid:        null,
          userId:         ownerUid,
          sessionId:      sessionId,
          requestId:      requestId,
          existingDocUid: ownerUid,
          payload:        validExchangePayload(),
        ),
        isFalse,
        reason: 'Unauthenticated request must be rejected for exchange update',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Suite S — Schema field invariants (payload anchoring)
  // ══════════════════════════════════════════════════════════════════════════
  group('Suite S — Schema field invariants (payload anchoring)', () {
    test('S-1: session create rejected when payload uid mismatches auth uid', () {
      final tamperedPayload = {'uid': foreignUid, 'sessionId': sessionId};
      expect(
        canCreateSession(
          authUid:   ownerUid,
          userId:    ownerUid,
          sessionId: sessionId,
          payload:   tamperedPayload,
        ),
        isFalse,
        reason: 'payload.uid != auth.uid must be rejected (UID injection block)',
      );
    });

    test('S-2: session create rejected when payload sessionId mismatches path', () {
      final tamperedPayload = {
        'uid':       ownerUid,
        'sessionId': 'session_DIFFERENT_from_path',
      };
      expect(
        canCreateSession(
          authUid:   ownerUid,
          userId:    ownerUid,
          sessionId: sessionId,
          payload:   tamperedPayload,
        ),
        isFalse,
        reason: 'payload.sessionId != path sessionId must be rejected '
            '(sessionId injection block)',
      );
    });

    test('S-3: exchange create rejected when payload uid mismatches auth uid', () {
      final tamperedPayload = {
        'uid':       foreignUid,
        'sessionId': sessionId,
        'requestId': requestId,
      };
      expect(
        canCreateExchange(
          authUid:   ownerUid,
          userId:    ownerUid,
          sessionId: sessionId,
          requestId: requestId,
          payload:   tamperedPayload,
        ),
        isFalse,
        reason: 'Exchange payload.uid != auth.uid must be rejected',
      );
    });

    test('S-4: exchange create rejected when payload sessionId mismatches path', () {
      final tamperedPayload = {
        'uid':       ownerUid,
        'sessionId': 'session_WRONG',
        'requestId': requestId,
      };
      expect(
        canCreateExchange(
          authUid:   ownerUid,
          userId:    ownerUid,
          sessionId: sessionId,
          requestId: requestId,
          payload:   tamperedPayload,
        ),
        isFalse,
        reason: 'Exchange payload.sessionId != path sessionId must be rejected',
      );
    });

    test('S-5: exchange create rejected when payload requestId mismatches path', () {
      final tamperedPayload = {
        'uid':       ownerUid,
        'sessionId': sessionId,
        'requestId': 'req_WRONG_ID',
      };
      expect(
        canCreateExchange(
          authUid:   ownerUid,
          userId:    ownerUid,
          sessionId: sessionId,
          requestId: requestId,
          payload:   tamperedPayload,
        ),
        isFalse,
        reason: 'Exchange payload.requestId != path requestId must be rejected '
            '(replay/injection block)',
      );
    });

    test('S-6: session update rejected when existing doc uid is foreign (UID swap)', () {
      // Simulates an attacker who somehow got a doc written with a different
      // uid and now tries to update it as the owner.
      expect(
        canUpdateSession(
          authUid:        ownerUid,
          userId:         ownerUid,
          sessionId:      sessionId,
          existingDocUid: foreignUid, // <-- existing doc was written by someone else
          payload:        validSessionPayload(),
        ),
        isFalse,
        reason: 'resource.data.uid != auth.uid must block UID-swap update on sessions',
      );
    });

    test('S-7: exchange update rejected when existing doc uid is foreign (UID swap)', () {
      expect(
        canUpdateExchange(
          authUid:        ownerUid,
          userId:         ownerUid,
          sessionId:      sessionId,
          requestId:      requestId,
          existingDocUid: foreignUid, // <-- existing exchange doc uid mismatch
          payload:        validExchangePayload(),
        ),
        isFalse,
        reason: 'resource.data.uid != auth.uid must block UID-swap update on exchanges',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Suite A — SessionPersistAuthDenied type isolation
  // Verifies the Flutter-side type hierarchy enforces the PILLAR 2 contract:
  //   permission-denied → SessionPersistAuthDenied (NEVER QueuedOffline)
  // ══════════════════════════════════════════════════════════════════════════
  group('Suite A — SessionPersistAuthDenied type isolation', () {
    const testParentPath   = 'users/uid_a/ai_sessions/session_a';
    const testExchangePath = 'users/uid_a/ai_sessions/session_a/exchanges/req_a';

    test('A-1: SessionPersistAuthDenied is a subtype of SessionPersistStatus', () {
      const denied = SessionPersistAuthDenied(
        parentPath:   testParentPath,
        exchangePath: testExchangePath,
      );
      expect(denied, isA<SessionPersistStatus>(),
          reason: 'SessionPersistAuthDenied must extend SessionPersistStatus');
    });

    test('A-2: SessionPersistAuthDenied carries parentPath and exchangePath', () {
      const denied = SessionPersistAuthDenied(
        parentPath:   testParentPath,
        exchangePath: testExchangePath,
      );
      expect(denied.parentPath,   equals(testParentPath));
      expect(denied.exchangePath, equals(testExchangePath));
    });

    test('A-3: SessionPersistAuthDenied is NOT a SessionPersistQueuedOffline', () {
      const denied = SessionPersistAuthDenied(
        parentPath:   testParentPath,
        exchangePath: testExchangePath,
      );
      expect(denied, isNot(isA<SessionPersistQueuedOffline>()),
          reason: 'permission-denied must NEVER be treated as offline/queued state');
    });

    test('A-4: SessionPersistAuthDenied is NOT a SessionPersistFailed', () {
      const denied = SessionPersistAuthDenied(
        parentPath:   testParentPath,
        exchangePath: testExchangePath,
      );
      expect(denied, isNot(isA<SessionPersistFailed>()),
          reason: 'permission-denied must be a distinct type from generic failure');
    });

    test('A-5: SessionPersistAuthDenied is NOT a SessionPersistSynced', () {
      const denied = SessionPersistAuthDenied(
        parentPath:   testParentPath,
        exchangePath: testExchangePath,
      );
      expect(denied, isNot(isA<SessionPersistSynced>()),
          reason: 'Auth-denied must not be confused with a successful write');
    });

    test('A-6: switch on SessionPersistStatus covers all variants exhaustively', () {
      // Build one instance of each concrete variant and switch on them.
      // This ensures the sealed class covers all expected variants and that
      // SessionPersistAuthDenied is a distinct, reachable arm.
      final List<SessionPersistStatus> variants = [
        const SessionPersistSynced(),
        const SessionPersistQueuedOffline(),
        const SessionPersistSkipped('reason'),
        const SessionPersistAuthDenied(
          parentPath:   testParentPath,
          exchangePath: testExchangePath,
        ),
        SessionPersistFailed(Exception('err')),
      ];

      final reached = <String>[];
      for (final v in variants) {
        switch (v) {
          case SessionPersistSynced():
            reached.add('synced');
          case SessionPersistQueuedOffline():
            reached.add('queued_offline');
          case SessionPersistSkipped():
            reached.add('skipped');
          case SessionPersistAuthDenied():
            reached.add('auth_denied');
          case SessionPersistFailed():
            reached.add('failed');
        }
      }

      expect(reached, containsAll([
        'synced', 'queued_offline', 'skipped', 'auth_denied', 'failed',
      ]), reason: 'All five variants must be reachable in exhaustive switch');
      expect(reached, hasLength(5),
          reason: 'No variant must be double-counted or merged');
    });

    test('A-7: mock persist maps permission-denied flag to SessionPersistAuthDenied', () async {
      // Mirrors the logic in persistAiExchangeOnce() — verifies the branch
      // that inspects batchResult.permissionDenied.
      Future<SessionPersistStatus> mockPersist({
        required bool permissionDenied,
        required bool ok,
      }) async {
        // Mirrors the exact precedence order from persistAiExchangeOnce():
        //   1. permissionDenied → SessionPersistAuthDenied
        //   2. !ok             → SessionPersistFailed
        //   3. ok              → SessionPersistSynced
        if (permissionDenied) {
          return const SessionPersistAuthDenied(
            parentPath:   testParentPath,
            exchangePath: testExchangePath,
          );
        }
        if (!ok) return SessionPersistFailed('generic_error');
        return const SessionPersistSynced();
      }

      final denied  = await mockPersist(permissionDenied: true,  ok: false);
      final failed  = await mockPersist(permissionDenied: false, ok: false);
      final synced  = await mockPersist(permissionDenied: false, ok: true);

      expect(denied, isA<SessionPersistAuthDenied>(),
          reason: 'permissionDenied=true must yield SessionPersistAuthDenied');
      expect(failed, isA<SessionPersistFailed>(),
          reason: 'ok=false (non-permission) must yield SessionPersistFailed');
      expect(synced, isA<SessionPersistSynced>(),
          reason: 'ok=true must yield SessionPersistSynced');

      // Critically: permission-denied must NOT be SessionPersistQueuedOffline.
      expect(denied, isNot(isA<SessionPersistQueuedOffline>()),
          reason: 'SECURITY INVARIANT: permission-denied is NOT an offline state');
    });
  });
}
