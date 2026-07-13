// ═══════════════════════════════════════════════════════════════════════════════
// lib/services/firebase_auth_adapter.dart
// MICRO-BUILD 463-A.2 — Firebase SDK Native Session Establishment
//
// PURPOSE:
//   Provides a hard-typed abstraction boundary between the application's auth
//   lifecycle (AppProvider, convergence manager) and the Firebase SDK runtime.
//
//   Key invariants this interface enforces:
//   1. HARD VALIDATION: Callers can inject a LiveFirebaseAuthAdapter (prod) or a
//      SimulatedFirebaseAuthAdapter (test) — prevents simulation-only passes.
//   2. TOKEN SEPARATION: currentUid reflects ONLY the Firebase SDK session.
//      REST identity-toolkit credentials (AuthService._cachedIdToken) are NOT
//      surfaced through this interface — they belong to AuthService.hasCachedToken.
//   3. CUSTOM TOKEN GATE: signInWithCustomToken() is present but MUST only receive
//      a backend-issued Firebase Custom Token. Injecting raw Google Access Tokens,
//      Gemini OAuth hashes, or REST identity-toolkit JWTs here is FORBIDDEN.
//
// ISOLATION CONTRACT:
//   • Does NOT touch AI/LLM prompts, provider routers, or clinical layouts.
//   • Does NOT replace AuthService — it wraps the SDK surface for the convergence
//     manager only.
//   • GeminiService.signIn/signOut are NOT Firebase Auth sessions and must NOT
//     flow through this adapter.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';

/// Abstract interface for Firebase SDK auth operations.
///
/// Implement [LiveFirebaseAuthAdapter] for production use and
/// [SimulatedFirebaseAuthAdapter] for test/stub environments.
abstract interface class FirebaseAuthAdapter {
  /// The UID of the currently authenticated Firebase SDK user, or null if
  /// no session is active. This reflects ONLY the SDK session — never a
  /// REST token or Gemini OAuth credential.
  String? get currentUid;

  /// Stream of Firebase SDK auth state changes.
  /// Emits null on sign-out; emits the UID string on sign-in.
  Stream<String?> authStateChanges();

  /// Sign in via email/password through the Firebase SDK.
  ///
  /// This is the native/SDK path (iOS, Android, and Web with SDK).
  /// On Web, if the REST identity-toolkit path was used for login, the SDK
  /// session is established separately — do not conflate them.
  ///
  /// Emits [AUTH_SDK_ESTABLISH][START] method=email_password telemetry before
  /// calling the SDK. Callers must call [forceTokenRefresh] after success.
  Future<void> signInWithEmailAndPassword(String email, String password);

  /// Sign in via an [AuthCredential] (e.g. GoogleAuthProvider credential).
  ///
  /// Only pass credentials obtained from official Firebase Auth providers.
  /// A Gemini OAuth `accessToken` is NOT a valid [AuthCredential] for this
  /// method — it must first be wrapped with `GoogleAuthProvider.credential()`.
  Future<void> signInWithCredential(AuthCredential credential);

  /// Sign in via a backend-issued Firebase Custom Token.
  ///
  /// STRICT PROHIBITION: Do NOT pass raw Google Access Tokens, Gemini OAuth
  /// hashes, or REST identity-toolkit idTokens to this method. Only tokens
  /// issued by Firebase Admin SDK (or equivalent) via `createCustomToken()`
  /// are valid. Violating this produces an `invalid-custom-token` error.
  Future<void> signInWithCustomToken(String customToken);

  /// Signs out the current Firebase SDK session.
  Future<void> signOut();

  /// Forces a server-side ID token refresh via `user.getIdToken(forceRefresh: true)`.
  ///
  /// Must be called after any successful sign-in to "warm" the session and
  /// ensure Firestore Rules receive a fresh JWT on the next request.
  ///
  /// Returns the refreshed ID token, or null if no user is signed in.
  Future<String?> forceTokenRefresh();
}

// ─────────────────────────────────────────────────────────────────────────────
// Production implementation — wraps FirebaseAuth.instance
// ─────────────────────────────────────────────────────────────────────────────

/// Production implementation of [FirebaseAuthAdapter] backed by
/// `FirebaseAuth.instance`. Used in all non-test code paths.
class LiveFirebaseAuthAdapter implements FirebaseAuthAdapter {
  const LiveFirebaseAuthAdapter();

  @override
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Stream<String?> authStateChanges() =>
      FirebaseAuth.instance.authStateChanges().map((u) => u?.uid);

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signInWithCredential(AuthCredential credential) async {
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Future<void> signInWithCustomToken(String customToken) async {
    await FirebaseAuth.instance.signInWithCustomToken(customToken);
  }

  @override
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Future<String?> forceTokenRefresh() async {
    return FirebaseAuth.instance.currentUser?.getIdToken(true);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simulation implementation — for test suites and integration stubs
// ─────────────────────────────────────────────────────────────────────────────

/// Simulated / stub implementation of [FirebaseAuthAdapter] for test suites.
///
/// State is fully in-memory. Does NOT make any network calls.
/// Auth state transitions are driven directly by test code.
class SimulatedFirebaseAuthAdapter implements FirebaseAuthAdapter {
  String? _currentUid;
  final List<String?> _stateHistory = [];

  @override
  String? get currentUid => _currentUid;

  @override
  Stream<String?> authStateChanges() => Stream.value(_currentUid);

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    // Simulated: derive a deterministic uid from the email (test only).
    _currentUid = 'simulated_uid_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
    _stateHistory.add(_currentUid);
  }

  @override
  Future<void> signInWithCredential(AuthCredential credential) async {
    _currentUid = 'simulated_credential_uid';
    _stateHistory.add(_currentUid);
  }

  @override
  Future<void> signInWithCustomToken(String customToken) async {
    // Validate: only accept tokens starting with the test prefix.
    // In production this is enforced by Firebase Admin SDK token signature.
    if (!customToken.startsWith('firebase_custom_token_')) {
      throw Exception('[SimulatedAdapter] INVALID_CUSTOM_TOKEN: '
          'Only firebase_custom_token_* prefixed tokens are accepted in simulation. '
          'Do NOT pass raw Google Access Tokens or Gemini OAuth hashes here.');
    }
    _currentUid = 'simulated_custom_uid_${customToken.substring(22)}';
    _stateHistory.add(_currentUid);
  }

  @override
  Future<void> signOut() async {
    _currentUid = null;
    _stateHistory.add(null);
  }

  @override
  Future<String?> forceTokenRefresh() async {
    if (_currentUid == null) return null;
    // Simulated token — does not contact the network.
    return 'simulated_id_token_for_$_currentUid';
  }

  // Test-only helpers
  void simulateExternalSignIn(String uid) {
    _currentUid = uid;
    _stateHistory.add(uid);
  }

  void simulateExternalSignOut() {
    _currentUid = null;
    _stateHistory.add(null);
  }

  List<String?> get stateHistory => List.unmodifiable(_stateHistory);

  void reset() {
    _currentUid = null;
    _stateHistory.clear();
  }
}
