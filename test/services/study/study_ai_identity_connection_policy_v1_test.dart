import '../../../lib/services/study/study_ai_identity_connection_policy_v1.dart';

void _expect(bool condition, String label) {
  if (!condition) {
    throw StateError(label);
  }
  print('$label=PASS');
}

void main() {
  const googleUser = StudyAiIdentitySnapshotV1(
    medCasesIdentity: MedCasesPrimaryIdentityV1.google,
    googleProviderLinkedToMedCasesUid: true,
    googleAiGrantReady: false,
  );

  final googlePlan = StudyAiIdentityConnectionPolicyV1.buildConnectionPlan(
    googleUser,
  );

  _expect(
    googlePlan.state == StudyAiConnectionStateV1.googleConsentRequired,
    'GOOGLE_MEDCASES_LOGIN_INCREMENTAL_CONSENT',
  );

  _expect(
    googlePlan.reuseCurrentGoogleIdentity,
    'GOOGLE_MEDCASES_IDENTITY_REUSED',
  );

  _expect(
    !googlePlan.forceGoogleAccountPicker,
    'GOOGLE_SECOND_ACCOUNT_PICKER_NOT_FORCED',
  );

  _expect(
    !googlePlan.linkGoogleToExistingMedCasesUid,
    'GOOGLE_MEDCASES_LOGIN_NO_PROVIDER_RELINK',
  );

  _expect(
    !googlePlan.manualApiKeyRequired,
    'GOOGLE_MANUAL_API_KEY_NOT_REQUIRED',
  );

  _expect(
    !googlePlan.separateGeminiLoginRequired,
    'GOOGLE_SEPARATE_GEMINI_LOGIN_NOT_REQUIRED',
  );

  const appleUser = StudyAiIdentitySnapshotV1(
    medCasesIdentity: MedCasesPrimaryIdentityV1.apple,
    googleProviderLinkedToMedCasesUid: false,
    googleAiGrantReady: false,
  );

  final applePlan = StudyAiIdentityConnectionPolicyV1.buildConnectionPlan(
    appleUser,
  );

  _expect(
    applePlan.state == StudyAiConnectionStateV1.googleLinkRequired,
    'APPLE_FIRST_STUDY_GOOGLE_LINK_REQUIRED',
  );

  _expect(
    applePlan.linkGoogleToExistingMedCasesUid,
    'APPLE_GOOGLE_LINKS_TO_EXISTING_MEDCASES_UID',
  );

  _expect(applePlan.preserveMedCasesUid, 'APPLE_MEDCASES_UID_PRESERVED');

  _expect(
    applePlan.forceGoogleAccountPicker,
    'APPLE_FIRST_LINK_ACCOUNT_PICKER_ALLOWED',
  );

  _expect(
    applePlan.requestIncrementalGoogleConsent,
    'APPLE_GOOGLE_INCREMENTAL_CONSENT',
  );

  _expect(!applePlan.manualApiKeyRequired, 'APPLE_MANUAL_API_KEY_NOT_REQUIRED');

  _expect(
    !applePlan.separateGeminiLoginRequired,
    'APPLE_SEPARATE_GEMINI_LOGIN_NOT_REQUIRED',
  );

  const readyAppleLinked = StudyAiIdentitySnapshotV1(
    medCasesIdentity: MedCasesPrimaryIdentityV1.apple,
    googleProviderLinkedToMedCasesUid: true,
    googleAiGrantReady: true,
  );

  final readyPlan = StudyAiIdentityConnectionPolicyV1.buildConnectionPlan(
    readyAppleLinked,
  );

  _expect(
    readyPlan.state == StudyAiConnectionStateV1.ready,
    'LINKED_APPLE_SUBSEQUENT_STUDY_ZERO_SETUP',
  );

  _expect(
    !readyPlan.requestIncrementalGoogleConsent,
    'LINKED_APPLE_NO_REPEAT_CONSENT',
  );

  _expect(
    readyPlan.serverAuthorizationCodeExchangeRequired,
    'SERVER_AUTH_CODE_EXCHANGE_REQUIRED',
  );

  _expect(
    !readyPlan.rawGoogleCredentialMayPersistOnClient,
    'RAW_GOOGLE_CREDENTIAL_CLIENT_PERSISTENCE_FORBIDDEN',
  );

  final normalStudy = StudyAiIdentityConnectionPolicyV1.buildRoutePlan(
    isProtectedClinicalContext: false,
    googleAiGrantReady: true,
  );

  _expect(
    normalStudy.personalFreeAllowed,
    'EDUCATIONAL_STUDY_PERSONAL_FREE_ALLOWED',
  );

  _expect(
    normalStudy.primaryCapabilityAlias == 'study_primary',
    'STUDY_PRIMARY_ALIAS',
  );

  _expect(
    normalStudy.fallbackCapabilityAliases.length == 2 &&
        normalStudy.fallbackCapabilityAliases[0] == 'study_fallback_1' &&
        normalStudy.fallbackCapabilityAliases[1] == 'study_fallback_2',
    'STUDY_ORDERED_BACKEND_FALLBACK_ALIASES',
  );

  final protectedStudy = StudyAiIdentityConnectionPolicyV1.buildRoutePlan(
    isProtectedClinicalContext: true,
    googleAiGrantReady: true,
  );

  _expect(
    !protectedStudy.personalFreeAllowed,
    'PROTECTED_CONTEXT_PERSONAL_FREE_FORBIDDEN',
  );

  _expect(
    protectedStudy.executionLane == StudyAiExecutionLaneV1.backendProtected,
    'PROTECTED_CONTEXT_BACKEND_BYPASS',
  );

  _expect(
    protectedStudy.primaryCapabilityAlias == 'study_fallback_1',
    'PROTECTED_CONTEXT_BACKEND_PRIMARY_ALIAS',
  );

  final noGrant = StudyAiIdentityConnectionPolicyV1.buildRoutePlan(
    isProtectedClinicalContext: false,
    googleAiGrantReady: false,
  );

  _expect(!noGrant.personalFreeAllowed, 'NO_GOOGLE_AI_GRANT_FAILS_CLOSED');

  _expect(
    noGrant.primaryCapabilityAlias == 'study_fallback_1',
    'NO_GRANT_BACKEND_FALLBACK_1',
  );

  print(
    'STUDY_AI_IDENTITY_CONNECTION_POLICY_VERSION='
    '${StudyAiIdentityConnectionPolicyV1.version}',
  );

  print(
    'RESULT=PASS_STUDY_GOOGLE_LOGIN_REUSE_APPLE_LINK_'
    'MINCLICK_IDENTITY_FOUNDATION_CONTRACT',
  );
}
