import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String sourceBlock(String source, String start, String end) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: 'start missing: $start');
  expect(b, greaterThan(a), reason: 'end missing: $end');
  return source.substring(a, b);
}

void main() {
  late String auth;
  late String login;
  late String mainSource;
  late String rules;
  late String registration;
  late String profileStream;

  setUpAll(() {
    auth = File('lib/services/auth_service.dart').readAsStringSync();
    login = File('lib/screens/login_screen.dart').readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
    rules = File('firestore.rules').readAsStringSync();
    registration = sourceBlock(
      auth,
      'static Future<AuthResult> register({',
      'static Future<AuthResult> _registerNative({',
    );
    profileStream = sourceBlock(
      auth,
      'static Stream<UserModel?> currentUserStream()',
      'static Future<void> approveUser(',
    );
  });

  group('Mobile signup profile bootstrap race V1-B-R0', () {
    test('publishes native registration before returning its Future', () {
      expect(
        auth,
        contains(
          'MEDCASES_MOBILE_SIGNUP_PROFILE_BOOTSTRAP_RACE_FIX_V1_B_R0',
        ),
      );
      expect(auth, contains('Future<AuthResult>? _nativeRegistrationInFlight'));
      expect(auth, contains('String? _nativeRegistrationEmail'));

      final create = registration.indexOf(
        'final nativeRegistration = _registerNative(',
      );
      final publish = registration.indexOf(
        '_nativeRegistrationInFlight = nativeRegistration;',
      );
      final handoff = registration.indexOf('return nativeRegistration;');
      expect(create, greaterThanOrEqualTo(0));
      expect(publish, greaterThan(create));
      expect(handoff, greaterThan(publish));
      expect(registration, isNot(contains('return _registerNative(')));
    });

    test('awaits signup convergence before listening to the profile snapshot', () {
      expect(profileStream, contains('async*'));
      final barrier = profileStream.indexOf(
        'registrationResult = await nativeRegistration;',
      );
      final liveSnapshot = profileStream.indexOf(
        ".collection('users').doc(uid).snapshots()",
      );
      expect(barrier, greaterThanOrEqualTo(0));
      expect(liveSnapshot, greaterThan(barrier));
      expect(profileStream, contains('yield registeredUser;'));
      expect(
        profileStream,
        isNot(
          contains(
            '.map((doc) => doc.exists ? UserModel.fromDoc(doc) : null)',
          ),
        ),
      );
    });

    test('never reuses a registration result for another identity', () {
      expect(
        profileStream,
        contains('registrationEmail == authenticatedEmail'),
      );
      expect(
        profileStream,
        contains('activeUser == null || activeUser.uid != uid'),
      );
      expect(
        profileStream,
        contains('registeredUser.uid == uid'),
      );
      expect(
        profileStream,
        contains('if (_auth.currentUser?.uid != uid)'),
      );
    });

    test('repairs a missing profile without dropping signup metadata', () {
      expect(profileStream, contains('await ensureUserProfileExists('));
      expect(
        profileStream,
        contains(
          'displayName: bootstrapUser?.displayName ?? activeUser.displayName',
        ),
      );
      expect(profileStream, contains('profession: bootstrapUser?.profession'));
      expect(profileStream, contains('institution: bootstrapUser?.institution'));
      expect(profileStream, contains('referredBy: bootstrapUser?.referredBy'));
      expect(profileStream, contains("platform: 'mobile'"));
      expect(profileStream, contains('yield recoveredUser;'));
    });

    test('keeps one authentication and relies on the guarded handoff', () {
      final signupUi = sourceBlock(
        login,
        'result = await AuthService.register(',
        '} else {\n      result = await AuthService.resetPassword(',
      );
      expect(signupUi, contains('AuthService.saveSession(result.user!)'));
      expect(signupUi, isNot(contains('AuthService.login(')));
      expect(signupUi, isNot(contains('signInWithEmailAndPassword')));
      expect(mainSource, contains('stream: AuthService.authStateChanges'));
      expect(mainSource, contains('stream: AuthService.currentUserStream()'));
    });

    test('Firestore still permits an authenticated owner to create the profile', () {
      final userRules = sourceBlock(
        rules,
        'match /users/{userId} {',
        '// Subcoleções do usuário',
      );
      expect(userRules, contains('allow create: if isAuthed()'));
      expect(userRules, contains('request.auth.uid == userId'));
      expect(userRules, contains('allow get: if isAuthed()'));
    });
  });
}
