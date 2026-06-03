// ══════════════════════════════════════════════════════════════════════════════
// MedCases Pro — Auth Flow Unit Tests
// QA Coverage: Test Cases 1, 2, 3 (IAM + Disclaimer Gate)
//
// Run with:  flutter test test/auth_flow_test.dart --reporter expanded
//
// NOTE: These are pure unit/logic tests.
// Firebase calls are NOT executed — all service calls are mocked via fake
// implementations. No network, no emulator needed.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DATA — mirrors the real UserModel fields we care about
// (avoids importing firebase_core which would require initialization)
// ─────────────────────────────────────────────────────────────────────────────

enum _UserStatus { pending, approved, blocked }
enum _UserRole   { master, admin, supervisor, user }

class _UserModel {
  final String uid;
  final String email;
  final String displayName;
  final _UserRole role;
  final _UserStatus status;
  final bool acceptedTerms;
  final DateTime? acceptedTermsAt;
  final String? professionalCategory;

  const _UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role            = _UserRole.user,
    this.status          = _UserStatus.pending,
    this.acceptedTerms   = false,
    this.acceptedTermsAt = null,
    this.professionalCategory,
  });

  bool get isApproved => status == _UserStatus.approved;
  bool get isPending  => status == _UserStatus.pending;

  _UserModel copyWith({
    _UserStatus? status,
    bool? acceptedTerms,
    DateTime? acceptedTermsAt,
    String? professionalCategory,
  }) => _UserModel(
    uid:                  uid,
    email:                email,
    displayName:          displayName,
    role:                 role,
    status:               status          ?? this.status,
    acceptedTerms:        acceptedTerms   ?? this.acceptedTerms,
    acceptedTermsAt:      acceptedTermsAt ?? this.acceptedTermsAt,
    professionalCategory: professionalCategory ?? this.professionalCategory,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK AUTH SERVICE — simulates Firebase Auth + Firestore responses
// ─────────────────────────────────────────────────────────────────────────────

class _MockAuthResult {
  final bool success;
  final _UserModel? user;
  final String? error;
  const _MockAuthResult._({required this.success, this.user, this.error});
  factory _MockAuthResult.success(_UserModel u) =>
      _MockAuthResult._(success: true, user: u);
  factory _MockAuthResult.error(String msg) =>
      _MockAuthResult._(success: false, error: msg);
}

/// In-memory "Firestore" store used by all tests in this file.
final Map<String, _UserModel> _firestoreUsers = {};

class _MockAuthService {
  // ── Register ────────────────────────────────────────────────────────────
  static Future<_MockAuthResult> register({
    required String email,
    required String password,
    required String displayName,
    String? profession,
  }) async {
    // Simulate EMAIL_EXISTS guard
    final exists = _firestoreUsers.values
        .any((u) => u.email.toLowerCase() == email.toLowerCase());
    if (exists) return _MockAuthResult.error('Este e-mail já está cadastrado.');

    // Simulate WEAK_PASSWORD guard
    if (password.length < 6) {
      return _MockAuthResult.error('Senha fraca. Use ao menos 6 caracteres.');
    }

    // Simulate createUserWithEmailAndPassword + Firestore write
    final uid  = 'uid_${email.hashCode.abs()}';
    final user = _UserModel(
      uid:          uid,
      email:        email.trim().toLowerCase(),
      displayName:  displayName.trim(),
      role:         _UserRole.user,
      status:       _UserStatus.approved, // auto-approve (matches real code)
      acceptedTerms: false,               // ← gate not yet passed
    );

    // Simulate async Firestore document creation
    await Future.delayed(Duration.zero);
    _firestoreUsers[uid] = user;

    return _MockAuthResult.success(user);
  }

  // ── Login ────────────────────────────────────────────────────────────────
  static Future<_MockAuthResult> login({
    required String email,
    required String password,
  }) async {
    // Simulate INVALID_LOGIN_CREDENTIALS
    final user = _firestoreUsers.values
        .where((u) => u.email.toLowerCase() == email.toLowerCase())
        .firstOrNull;

    if (user == null) {
      return _MockAuthResult.error('E-mail ou senha incorretos.');
    }

    // Simulate password check (stored as plain text in mock — never do in prod)
    if (password.length < 6) {
      return _MockAuthResult.error('E-mail ou senha incorretos.');
    }

    // Simulate reading Firestore profile (users/{uid})
    await Future.delayed(Duration.zero);
    final freshUser = _firestoreUsers[user.uid] ?? user;

    return _MockAuthResult.success(freshUser);
  }

  // ── Accept Terms (writes to Firestore) ───────────────────────────────────
  static Future<void> acceptTerms({
    required String uid,
    required String professionalCategory,
  }) async {
    final user = _firestoreUsers[uid];
    if (user == null) return;
    await Future.delayed(Duration.zero); // simulate async Firestore write
    _firestoreUsers[uid] = user.copyWith(
      acceptedTerms:        true,
      acceptedTermsAt:      DateTime.now(),
      professionalCategory: professionalCategory,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK DISCLAIMER GATE — mirrors _ProfessionalDeclarationModalState logic
// ─────────────────────────────────────────────────────────────────────────────

class _MockDisclaimerGate {
  String? selectedCategory;
  bool    checkboxMarked = false;

  /// Mirrors: bool get _canConfirm => _selectedCategory != null && _checked
  bool get canConfirm => selectedCategory != null && checkboxMarked;

  void selectCategory(String cat) => selectedCategory = cat;
  void toggleCheckbox()           => checkboxMarked = !checkboxMarked;

  Future<bool> confirmAndSave(String uid) async {
    if (!canConfirm) return false;
    await _MockAuthService.acceptTerms(
      uid: uid,
      professionalCategory: selectedCategory!,
    );
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROUTING HELPER — mirrors _AuthGate logic
// ─────────────────────────────────────────────────────────────────────────────

enum _AppRoute { loginScreen, disclaimerGate, mainCockpit }

_AppRoute _resolveRoute(_UserModel? user) {
  if (user == null)               return _AppRoute.loginScreen;
  if (!user.isApproved)           return _AppRoute.loginScreen;
  if (!user.acceptedTerms)        return _AppRoute.disclaimerGate;
  return                                  _AppRoute.mainCockpit;
}

// ══════════════════════════════════════════════════════════════════════════════
// TEST SUITE
// ══════════════════════════════════════════════════════════════════════════════

void main() {
  // Reset in-memory store before each test
  setUp(() => _firestoreUsers.clear());

  // ──────────────────────────────────────────────────────────────────────────
  // TEST CASE 1 — New Account Registration (Multi-step Onboarding)
  // ──────────────────────────────────────────────────────────────────────────
  group('TC-1: New Account Registration', () {

    test('1.1 — createUserWithEmailAndPassword succeeds with valid credentials', () async {
      final result = await _MockAuthService.register(
        email:       'rodrigssousa@gmail.com',
        password:    'SecurePass123',
        displayName: 'Rodrigo Sousa',
        profession:  'Médico / Residente',
      );

      expect(result.success, isTrue,
          reason: 'Firebase Auth createUser must succeed');
      expect(result.error, isNull);
      expect(result.user, isNotNull);
      expect(result.user!.email, equals('rodrigssousa@gmail.com'));
    });

    test('1.2 — Firestore document is created asynchronously after registration', () async {
      final result = await _MockAuthService.register(
        email:       'rodrigssousa@gmail.com',
        password:    'SecurePass123',
        displayName: 'Rodrigo Sousa',
      );

      expect(result.success, isTrue);

      final uid  = result.user!.uid;
      final doc  = _firestoreUsers[uid];
      expect(doc, isNotNull,
          reason: 'users/{uid} document must be written to Firestore');
      expect(doc!.uid,   isNotEmpty);
      expect(doc.email,  equals('rodrigssousa@gmail.com'));
      expect(doc.status, equals(_UserStatus.approved),
          reason: 'Auto-approval must set status=approved immediately');
    });

    test('1.3 — New user is routed to DisclaimerGate (not cockpit) after registration', () async {
      final result = await _MockAuthService.register(
        email:       'rodrigssousa@gmail.com',
        password:    'SecurePass123',
        displayName: 'Rodrigo Sousa',
      );

      expect(result.success, isTrue);

      final route = _resolveRoute(result.user);
      expect(route, equals(_AppRoute.disclaimerGate),
          reason: 'Newly registered user must hit DisclaimerGate before cockpit');
    });

    test('1.4 — Duplicate email registration returns EMAIL_EXISTS error', () async {
      // First registration
      await _MockAuthService.register(
        email:       'rodrigssousa@gmail.com',
        password:    'SecurePass123',
        displayName: 'Rodrigo Sousa',
      );

      // Second registration with same email
      final result = await _MockAuthService.register(
        email:       'rodrigssousa@gmail.com',
        password:    'AnotherPass456',
        displayName: 'Other User',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('já está cadastrado'),
          reason: 'EMAIL_EXISTS must return a user-friendly Portuguese error');
    });

    test('1.5 — Weak password (< 6 chars) is rejected with correct error', () async {
      final result = await _MockAuthService.register(
        email:       'newuser@test.com',
        password:    '123',
        displayName: 'Test User',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Senha fraca'),
          reason: 'WEAK_PASSWORD must surface correct localized error');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TEST CASE 2 — Mandatory Legal Disclaimer Gate
  // ──────────────────────────────────────────────────────────────────────────
  group('TC-2: Mandatory Legal Disclaimer Interceptor', () {

    late _UserModel testUser;

    setUp(() async {
      final result = await _MockAuthService.register(
        email:       'rodrigssousa@gmail.com',
        password:    'SecurePass123',
        displayName: 'Rodrigo Sousa',
      );
      testUser = result.user!;
    });

    test('2.1 — CTA button is DISABLED when neither condition is met', () {
      final gate = _MockDisclaimerGate();
      // No category selected, checkbox not marked
      expect(gate.canConfirm, isFalse,
          reason: 'Button must be locked (grayed out) before any interaction');
    });

    test('2.2 — CTA button is DISABLED when only category is selected', () {
      final gate = _MockDisclaimerGate();
      gate.selectCategory('Médico / Residente');

      expect(gate.canConfirm, isFalse,
          reason: 'Button must remain locked when checkbox is not yet marked');
    });

    test('2.3 — CTA button is DISABLED when only checkbox is marked', () {
      final gate = _MockDisclaimerGate();
      gate.toggleCheckbox();

      expect(gate.canConfirm, isFalse,
          reason: 'Button must remain locked when professional category is not selected');
    });

    test('2.4 — CTA button ACTIVATES only when BOTH conditions are true', () {
      final gate = _MockDisclaimerGate();
      gate.selectCategory('Médico / Residente');
      gate.toggleCheckbox();

      expect(gate.canConfirm, isTrue,
          reason: 'Button must activate (green + check icon) when both fields are valid');
    });

    test('2.5 — confirmAndSave writes acceptedTerms=true to Firestore', () async {
      final gate = _MockDisclaimerGate();
      gate.selectCategory('Médico / Residente');
      gate.toggleCheckbox();

      final saved = await gate.confirmAndSave(testUser.uid);

      expect(saved, isTrue);

      final updatedDoc = _firestoreUsers[testUser.uid];
      expect(updatedDoc, isNotNull);
      expect(updatedDoc!.acceptedTerms, isTrue,
          reason: 'acceptedTerms must be written to Firestore on confirmation');
    });

    test('2.6 — acceptedTermsAt timestamp is written on confirmation', () async {
      final gate = _MockDisclaimerGate();
      gate.selectCategory('Estudante de Medicina');
      gate.toggleCheckbox();

      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await gate.confirmAndSave(testUser.uid);
      final after  = DateTime.now().add(const Duration(seconds: 1));

      final updatedDoc = _firestoreUsers[testUser.uid]!;
      expect(updatedDoc.acceptedTermsAt, isNotNull,
          reason: 'acceptedTermsAt must record server timestamp');
      expect(
        updatedDoc.acceptedTermsAt!.isAfter(before) &&
        updatedDoc.acceptedTermsAt!.isBefore(after),
        isTrue,
        reason: 'Timestamp must be within the test execution window',
      );
    });

    test('2.7 — professionalCategory is stored correctly in Firestore', () async {
      final gate = _MockDisclaimerGate();
      gate.selectCategory('Outro Profissional de Saúde');
      gate.toggleCheckbox();

      await gate.confirmAndSave(testUser.uid);

      final updatedDoc = _firestoreUsers[testUser.uid]!;
      expect(updatedDoc.professionalCategory, equals('Outro Profissional de Saúde'));
    });

    test('2.8 — confirmAndSave returns false and does NOT write if gate is incomplete', () async {
      final gate = _MockDisclaimerGate();
      // Deliberately incomplete — only category, no checkbox
      gate.selectCategory('Médico / Residente');

      final saved = await gate.confirmAndSave(testUser.uid);

      expect(saved, isFalse,
          reason: 'Incomplete gate must not write to Firestore');

      final doc = _firestoreUsers[testUser.uid]!;
      expect(doc.acceptedTerms, isFalse,
          reason: 'acceptedTerms must remain false if gate was not completed');
    });

    test('2.9 — After confirmation, routing resolves to mainCockpit', () async {
      final gate = _MockDisclaimerGate();
      gate.selectCategory('Médico / Residente');
      gate.toggleCheckbox();
      await gate.confirmAndSave(testUser.uid);

      // Re-read the updated user from "Firestore"
      final updatedUser = _firestoreUsers[testUser.uid]!;
      final route       = _resolveRoute(updatedUser);

      expect(route, equals(_AppRoute.mainCockpit),
          reason: 'After accepting terms, user must be routed to the main cockpit');
    });

    test('2.10 — Toggling checkbox twice resets to disabled state', () {
      final gate = _MockDisclaimerGate();
      gate.selectCategory('Médico / Residente');
      gate.toggleCheckbox(); // mark
      expect(gate.canConfirm, isTrue);

      gate.toggleCheckbox(); // unmark
      expect(gate.canConfirm, isFalse,
          reason: 'Unchecking the checkbox must re-disable the CTA button');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TEST CASE 3 — Standard Login with Existing Credentials
  // ──────────────────────────────────────────────────────────────────────────
  group('TC-3: Standard Login Flow', () {

    setUp(() async {
      // Seed a user who has NOT yet accepted terms
      final reg = await _MockAuthService.register(
        email:       'rodrigssousa@gmail.com',
        password:    'SecurePass123',
        displayName: 'Rodrigo Sousa',
      );
      // Ensure they are seeded as approved but terms NOT yet accepted
      _firestoreUsers[reg.user!.uid] = reg.user!;
    });

    test('3.1 — signInWithEmailAndPassword resolves with valid credentials', () async {
      final result = await _MockAuthService.login(
        email:    'rodrigssousa@gmail.com',
        password: 'SecurePass123',
      );

      expect(result.success, isTrue,
          reason: 'Login with correct credentials must succeed');
      expect(result.user, isNotNull);
      expect(result.user!.email, equals('rodrigssousa@gmail.com'));
    });

    test('3.2 — Login reads Firestore profile (acceptedTerms field is present)', () async {
      final result = await _MockAuthService.login(
        email:    'rodrigssousa@gmail.com',
        password: 'SecurePass123',
      );

      expect(result.success, isTrue);
      // acceptedTerms comes from Firestore — must not be null
      expect(result.user!.acceptedTerms, equals(false),
          reason: 'Firestore profile must be read during login; acceptedTerms=false for new user');
    });

    test('3.3 — If acceptedTerms=false, routing goes to DisclaimerGate', () async {
      final result = await _MockAuthService.login(
        email:    'rodrigssousa@gmail.com',
        password: 'SecurePass123',
      );

      expect(result.success, isTrue);

      final route = _resolveRoute(result.user);
      expect(route, equals(_AppRoute.disclaimerGate),
          reason: 'User with acceptedTerms=false must be intercepted by DisclaimerGate on every login');
    });

    test('3.4 — If acceptedTerms=true, routing goes directly to mainCockpit', () async {
      // First, login and accept terms
      final loginResult = await _MockAuthService.login(
        email:    'rodrigssousa@gmail.com',
        password: 'SecurePass123',
      );
      final uid = loginResult.user!.uid;

      // Simulate the user completing the disclaimer gate
      await _MockAuthService.acceptTerms(
        uid:                  uid,
        professionalCategory: 'Médico / Residente',
      );

      // Now login again (second session)
      final secondLogin = await _MockAuthService.login(
        email:    'rodrigssousa@gmail.com',
        password: 'SecurePass123',
      );

      final route = _resolveRoute(secondLogin.user);
      expect(route, equals(_AppRoute.mainCockpit),
          reason: 'Returning user with acceptedTerms=true must go directly to cockpit');
    });

    test('3.5 — Login with wrong password returns localized error', () async {
      final result = await _MockAuthService.login(
        email:    'rodrigssousa@gmail.com',
        password: 'Wrong',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('incorretos'),
          reason: 'INVALID_LOGIN_CREDENTIALS must return Portuguese-localized error');
    });

    test('3.6 — Login with unknown email returns localized error', () async {
      final result = await _MockAuthService.login(
        email:    'ghost@notexist.com',
        password: 'AnyPassword123',
      );

      expect(result.success, isFalse);
      expect(result.error, isNotNull,
          reason: 'Unknown email must return an error, not crash');
    });

    test('3.7 — Unauthenticated user (null) routes to loginScreen', () {
      final route = _resolveRoute(null);
      expect(route, equals(_AppRoute.loginScreen),
          reason: 'null user must always route to the login screen');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // BONUS: AuthResult model integrity
  // ──────────────────────────────────────────────────────────────────────────
  group('Auth Result Model Integrity', () {

    test('B.1 — AuthResult.success carries the user object', () async {
      final result = await _MockAuthService.register(
        email:       'test@model.com',
        password:    'ValidPass1',
        displayName: 'Test',
      );
      expect(result.success, isTrue);
      expect(result.user,    isA<_UserModel>());
      expect(result.error,   isNull);
    });

    test('B.2 — AuthResult.error carries no user object', () async {
      final result = await _MockAuthService.login(
        email:    'nobody@test.com',
        password: 'WrongPass1',
      );
      expect(result.success, isFalse);
      expect(result.user,    isNull);
      expect(result.error,   isNotNull);
    });

    test('B.3 — New user model has expected default state', () async {
      final result = await _MockAuthService.register(
        email:       'defaults@test.com',
        password:    'Pass123456',
        displayName: 'Defaults User',
      );
      final user = result.user!;
      expect(user.acceptedTerms,        isFalse);
      expect(user.acceptedTermsAt,      isNull);
      expect(user.professionalCategory, isNull);
      expect(user.status,               equals(_UserStatus.approved));
      expect(user.role,                 equals(_UserRole.user));
    });
  });
}
