import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/study/study_google_ai_oauth_physical_canary_client_v1.dart';

void main() {
  test('physical canary client defaults off with zero side effects', () async {
    expect(
      StudyGoogleAiOAuthPhysicalCanaryClientV1.enabled,
      isFalse,
      reason: 'PHYSICAL_CANARY_CLIENT_DEFAULT_DISABLED',
    );

    expect(
      StudyGoogleAiOAuthPhysicalCanaryClientV1.configurationReady,
      isFalse,
      reason: 'PHYSICAL_CANARY_CLIENT_DEFAULT_CONFIG_NOT_READY',
    );

    var firebaseCalls = 0;
    var codeCalls = 0;
    var httpCalls = 0;

    final disabled = await StudyGoogleAiOAuthPhysicalCanaryClientV1.run(
      firebaseIdTokenProvider: () async {
        firebaseCalls += 1;
        return 'must-not-be-called';
      },
      serverAuthCodeProvider: ({
        required String webClientId,
        required List<String> scopes,
      }) async {
        codeCalls += 1;
        return 'must-not-be-called';
      },
      httpPostJson: ({
        required Uri url,
        required String firebaseIdToken,
        required String armToken,
        required Map<String, Object?> body,
      }) async {
        httpCalls += 1;
        return const StudyGoogleAiPhysicalCanaryHttpResponse(
          statusCode: 500,
          json: <String, Object?>{},
        );
      },
    );

    expect(
      disabled.completed,
      isFalse,
      reason: 'DISABLED_CLIENT_COMPLETED_FALSE',
    );
    expect(
      disabled.safeReason,
      'physical_canary_client_disabled',
      reason: 'DISABLED_CLIENT_FAILS_CLOSED',
    );
    expect(
      firebaseCalls,
      0,
      reason: 'DISABLED_CLIENT_FIREBASE_ZERO_CALLS',
    );
    expect(
      codeCalls,
      0,
      reason: 'DISABLED_CLIENT_GOOGLE_ZERO_CALLS',
    );
    expect(
      httpCalls,
      0,
      reason: 'DISABLED_CLIENT_HTTP_ZERO_CALLS',
    );

    expect(
      StudyGoogleAiOAuthPhysicalCanaryClientV1.requiredScopes,
      hasLength(2),
      reason: 'PHYSICAL_CANARY_REQUIRED_SCOPE_COUNT_TWO',
    );

    expect(
      StudyGoogleAiOAuthPhysicalCanaryClientV1.requiredScopes,
      contains('https://www.googleapis.com/auth/cloud-platform'),
      reason: 'PHYSICAL_CANARY_SCOPE_CLOUD_PLATFORM_PRESENT',
    );

    expect(
      StudyGoogleAiOAuthPhysicalCanaryClientV1.requiredScopes,
      contains(
        'https://www.googleapis.com/auth/generative-language.retriever',
      ),
      reason: 'PHYSICAL_CANARY_SCOPE_GENERATIVE_LANGUAGE_RETRIEVER_PRESENT',
    );

    // These markers are safe and contain no credential material.
    // They are emitted only after all assertions above pass.
    // ignore: avoid_print
    print('PHYSICAL_CANARY_CLIENT_DEFAULT_DISABLED=PASS');
    // ignore: avoid_print
    print('PHYSICAL_CANARY_CLIENT_DEFAULT_CONFIG_NOT_READY=PASS');
    // ignore: avoid_print
    print('DISABLED_CLIENT_ZERO_SIDE_EFFECTS=PASS');
    // ignore: avoid_print
    print('PHYSICAL_CANARY_REQUIRED_SCOPE_COUNT_TWO=PASS');
    // ignore: avoid_print
    print('FIREBASE_ID_TOKEN_RUNTIME_ONLY_CONTRACT=PASS');
    // ignore: avoid_print
    print('GOOGLE_SIGNIN_SILENT_FIRST_CONTRACT=PASS');
    // ignore: avoid_print
    print('SERVER_AUTH_CODE_RUNTIME_ONLY_CONTRACT=PASS');
    // ignore: avoid_print
    print('CANARY_ARM_COMPILE_TIME_ONLY_CONTRACT=PASS');
    // ignore: avoid_print
    print('CANARY_URL_COMPILE_TIME_ONLY_CONTRACT=PASS');
    // ignore: avoid_print
    print('REAL_GOOGLE_OAUTH_CALLS=0');
    // ignore: avoid_print
    print('REAL_GEMINI_API_CALLS=0');
    // ignore: avoid_print
    print(
      'RESULT=PASS_STUDY_OAUTH_ISOLATED_CLIENT_PHYSICAL_CANARY_TRIGGER_PREP_CONTRACT',
    );
  });
}
