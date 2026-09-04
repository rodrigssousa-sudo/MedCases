import '../../../lib/services/study/study_google_ai_server_auth_code_gate_v1.dart';

void expectTrue(bool condition, String label) {
  if (!condition) {
    throw StateError(label);
  }
  print('$label=PASS');
}

void main() {
  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.enabled == false,
    'STUDY_SERVER_AUTH_CODE_GATE_DISABLED',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.serverClientId.isNotEmpty,
    'STUDY_SERVER_CLIENT_ID_PRESENT',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.forceCodeForRefreshTokenWhenEnabled ==
        false,
    'FORCE_CODE_FOR_REFRESH_TOKEN_DEFAULT_FALSE',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.effectiveServerClientId() == null,
    'DISABLED_GATE_EFFECTIVE_SERVER_CLIENT_ID_NULL',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.effectiveForceCodeForRefreshToken() ==
        false,
    'DISABLED_GATE_FORCE_CODE_FALSE',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.mayReadServerAuthCode() == false,
    'DISABLED_GATE_SERVER_AUTH_CODE_READ_FALSE',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.incrementalGeminiScopes.length == 2,
    'INCREMENTAL_SCOPE_PAIR_COUNT_TWO',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.incrementalGeminiScopes[0] ==
        'https://www.googleapis.com/auth/cloud-platform.read-only',
    'PROJECT_DISCOVERY_SCOPE_EXACT',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.incrementalGeminiScopes[1] ==
        'https://www.googleapis.com/auth/generative-language.retriever',
    'GEMINI_SCOPE_EXACT',
  );

  expectTrue(
    !StudyGoogleAiServerAuthCodeGateV1.incrementalGeminiScopes.contains(
      'https://www.googleapis.com/auth/cloud-platform',
    ),
    'BROAD_CLOUD_PLATFORM_WRITE_SCOPE_ABSENT',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.effectiveIncrementalGeminiScopes()
        .isEmpty,
    'DISABLED_GATE_INCREMENTAL_SCOPE_EFFECTIVE_EMPTY',
  );

  expectTrue(
    StudyGoogleAiServerAuthCodeGateV1.mayRequestIncrementalConsent() == false,
    'DISABLED_GATE_INCREMENTAL_CONSENT_FALSE',
  );

  print(
    'RESULT=PASS_STUDY_DISCOVERY_SCOPE_AND_REFRESH_TOKEN_CONSENT_POLICY_CONTRACT',
  );
}
