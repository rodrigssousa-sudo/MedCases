// ══════════════════════════════════════════════════════════════════════════════
// test/services/qa_access_gate_test.dart
// MICRO-BUILD 462E-A.3 — QA Access Gate isolation tests
//
// Valida AppProvider.evaluateQaGate() em todos os 3 branches sem dependência
// em singletons Firebase (FirebaseAuth.instance.currentUser).
//
// O getter shouldForceGptFallbackForQa delega para evaluateQaGate() — esta
// cobertura garante que a lógica de autorização é correta para todos os
// cenários mandatados:
//
//   Scenario A: standard user + kForceGptFallbackForQa=true
//               → unauthorized_user → bypass NEGADO
//   Scenario B: authenticated tester UID
//               → authorized_tester → bypass PERMITIDO
//   Scenario C: FirebaseAuth.currentUser == null (local cache UID presente)
//               → firebase_user_null → bypass NEGADO (cache ignorado)
//   Scenario D: isAdmin=true
//               → authorized_tester → bypass PERMITIDO
//   Scenario E: featureEnabled=false (kForceGptFallbackForQa=false)
//               → featureDisabled → bypass NEGADO
// ══════════════════════════════════════════════════════════════════════════════

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart';

void main() {
  // ── Expose the private _QaGateResult values via AppProvider.evaluateQaGate ──
  // evaluateQaGate() is static and returns a value whose .name we inspect,
  // so we don't need to import the private enum directly.

  group('AppProvider.evaluateQaGate — QA access gate logic', () {
    // ── Constants mirrored from AppProvider for test clarity ─────────────────
    const String kAuthorizedUid = 'Wa1AQN8hvCdewLiR2drd01rQo9G3';
    const String kStandardUid   = 'someRandomOtherUser123';

    // ─────────────────────────────────────────────────────────────────────────
    // Scenario A: Standard user authenticated but NOT in allowlist / no role
    // Expected: authorized=false reason=unauthorized_user
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario A — standard user with feature enabled → unauthorized_user', () {
      final result = AppProvider.evaluateQaGate(
        featureEnabled:   true,
        authenticatedUid: kStandardUid,
        isAdminUser:      false,
        isMasterUser:     false,
      );
      expect(result.name, equals('unauthorizedUser'),
          reason: 'Standard uid not in allowlist and no role must yield unauthorizedUser');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Scenario B: Authenticated tester UID in allowlist
    // Expected: authorized=true reason=tester_uid QA_ROUTE_ALLOWED=true
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario B — authorized tester UID → authorizedTester', () {
      final result = AppProvider.evaluateQaGate(
        featureEnabled:   true,
        authenticatedUid: kAuthorizedUid,
        isAdminUser:      false,
        isMasterUser:     false,
      );
      expect(result.name, equals('authorizedTester'),
          reason: 'UID in qaTesterUids allowlist must yield authorizedTester');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Scenario C: FirebaseAuth.currentUser == null (local cache UID irrelevant)
    // Expected: authorized=false reason=firebase_user_null
    // Note: evaluateQaGate receives null authenticatedUid — simulating the
    //       state where FirebaseAuth.instance.currentUser is null regardless
    //       of any locally-cached UID.
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario C — null authenticatedUid (firebase_user_null) → denied', () {
      final result = AppProvider.evaluateQaGate(
        featureEnabled:   true,
        authenticatedUid: null,  // FirebaseAuth.currentUser == null
        isAdminUser:      false,
        isMasterUser:     false,
      );
      expect(result.name, equals('firebaseUserNull'),
          reason: 'Null UID must yield firebaseUserNull regardless of any local cache');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Scenario D: isAdmin=true grants bypass even without explicit UID
    // Expected: authorized=true reason=tester_uid (role path)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario D — isAdmin=true grants bypass → authorizedTester', () {
      final result = AppProvider.evaluateQaGate(
        featureEnabled:   true,
        authenticatedUid: kStandardUid, // not in allowlist
        isAdminUser:      true,         // but isAdmin=true
        isMasterUser:     false,
      );
      expect(result.name, equals('authorizedTester'),
          reason: 'isAdmin=true must grant bypass regardless of UID allowlist');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Scenario E: featureEnabled=false (kForceGptFallbackForQa=false)
    // Expected: featureDisabled — gate inactive, no bypass for anyone
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario E — featureEnabled=false → featureDisabled for all users', () {
      // Even the authorized tester gets denied when feature flag is off
      final resultTester = AppProvider.evaluateQaGate(
        featureEnabled:   false,
        authenticatedUid: kAuthorizedUid,
        isAdminUser:      true,
        isMasterUser:     true,
      );
      expect(resultTester.name, equals('featureDisabled'),
          reason: 'Feature flag=false must short-circuit gate for all users');

      final resultStandard = AppProvider.evaluateQaGate(
        featureEnabled:   false,
        authenticatedUid: kStandardUid,
        isAdminUser:      false,
        isMasterUser:     false,
      );
      expect(resultStandard.name, equals('featureDisabled'),
          reason: 'Feature flag=false must short-circuit gate for standard users too');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Scenario F: isMaster=true grants bypass
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario F — isMaster=true grants bypass → authorizedTester', () {
      final result = AppProvider.evaluateQaGate(
        featureEnabled:   true,
        authenticatedUid: kStandardUid,
        isAdminUser:      false,
        isMasterUser:     true,
      );
      expect(result.name, equals('authorizedTester'),
          reason: 'isMaster=true must grant bypass regardless of UID allowlist');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Scenario G: empty string UID (treated same as null)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario G — empty string uid → firebaseUserNull (not authenticated)', () {
      final result = AppProvider.evaluateQaGate(
        featureEnabled:   true,
        authenticatedUid: '',
        isAdminUser:      false,
        isMasterUser:     false,
      );
      expect(result.name, equals('firebaseUserNull'),
          reason: 'Empty UID must be treated as unauthenticated');
    });
  });
}
