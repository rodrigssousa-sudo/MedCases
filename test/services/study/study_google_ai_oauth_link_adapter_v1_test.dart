import '../../../lib/services/study/study_ai_identity_connection_policy_v1.dart';
import '../../../lib/services/study/study_google_ai_oauth_link_adapter_v1.dart';

void expectTrue(bool condition, String label) {
  if (!condition) {
    throw StateError(label);
  }
  print('$label=PASS');
}

void main() {
  const googleSnapshot = StudyAiIdentitySnapshotV1(
    medCasesIdentity: MedCasesPrimaryIdentityV1.google,
    googleProviderLinkedToMedCasesUid: true,
    googleAiGrantReady: false,
  );

  final google = StudyGoogleAiOAuthLinkAdapterV1.plan(googleSnapshot);

  expectTrue(
    google.action ==
        StudyGoogleAiClientActionV1
            .requestIncrementalConsentForCurrentGoogleIdentity,
    'GOOGLE_REUSES_CURRENT_IDENTITY_FOR_INCREMENTAL_CONSENT',
  );

  expectTrue(!google.forceAccountPicker, 'GOOGLE_ACCOUNT_PICKER_NOT_FORCED');

  expectTrue(
    google.serverAuthorizationCodeRequired,
    'GOOGLE_SERVER_AUTH_CODE_REQUIRED',
  );

  const appleSnapshot = StudyAiIdentitySnapshotV1(
    medCasesIdentity: MedCasesPrimaryIdentityV1.apple,
    googleProviderLinkedToMedCasesUid: false,
    googleAiGrantReady: false,
  );

  final apple = StudyGoogleAiOAuthLinkAdapterV1.plan(appleSnapshot);

  expectTrue(
    apple.action ==
        StudyGoogleAiClientActionV1.linkGoogleToCurrentMedCasesIdentity,
    'APPLE_LINKS_GOOGLE_TO_CURRENT_MEDCASES_IDENTITY',
  );

  expectTrue(
    apple.forceAccountPicker,
    'APPLE_FIRST_LINK_ACCOUNT_PICKER_ALLOWED',
  );

  expectTrue(apple.preserveMedCasesUid, 'APPLE_LINK_MUST_PRESERVE_UID');

  final ok = StudyGoogleAiOAuthLinkAdapterV1.validatePostLink(
    uidBefore: 'uid-1',
    uidAfter: 'uid-1',
    serverAuthorizationCodePresent: true,
    cancelled: false,
    consentDenied: false,
    providerAlreadyLinked: false,
    credentialAlreadyInUse: false,
    unsupportedPlatform: false,
    technicalFailure: false,
  );

  expectTrue(ok.success, 'LINK_RESULT_SUCCESS');
  expectTrue(ok.uidPreserved, 'LINK_RESULT_UID_PRESERVED');
  expectTrue(
    ok.serverAuthorizationCodePresent,
    'LINK_RESULT_AUTH_CODE_PRESENCE_ONLY',
  );

  final collision = StudyGoogleAiOAuthLinkAdapterV1.validatePostLink(
    uidBefore: 'uid-apple',
    uidAfter: 'uid-apple',
    serverAuthorizationCodePresent: false,
    cancelled: false,
    consentDenied: false,
    providerAlreadyLinked: false,
    credentialAlreadyInUse: true,
    unsupportedPlatform: false,
    technicalFailure: false,
  );

  expectTrue(
    !collision.success &&
        collision.failure == StudyGoogleAiLinkFailureV1.credentialAlreadyInUse,
    'APPLE_GOOGLE_EXISTING_ACCOUNT_COLLISION_FAILS_CLOSED',
  );

  final changedUid = StudyGoogleAiOAuthLinkAdapterV1.validatePostLink(
    uidBefore: 'uid-before',
    uidAfter: 'uid-after',
    serverAuthorizationCodePresent: true,
    cancelled: false,
    consentDenied: false,
    providerAlreadyLinked: false,
    credentialAlreadyInUse: false,
    unsupportedPlatform: false,
    technicalFailure: false,
  );

  expectTrue(
    !changedUid.success &&
        changedUid.failure == StudyGoogleAiLinkFailureV1.uidChanged &&
        !changedUid.uidPreserved,
    'UID_CHANGE_FAILS_CLOSED',
  );

  final noCode = StudyGoogleAiOAuthLinkAdapterV1.validatePostLink(
    uidBefore: 'uid-1',
    uidAfter: 'uid-1',
    serverAuthorizationCodePresent: false,
    cancelled: false,
    consentDenied: false,
    providerAlreadyLinked: false,
    credentialAlreadyInUse: false,
    unsupportedPlatform: false,
    technicalFailure: false,
  );

  expectTrue(
    !noCode.success &&
        noCode.failure ==
            StudyGoogleAiLinkFailureV1.missingServerAuthorizationCode,
    'MISSING_SERVER_AUTH_CODE_FAILS_CLOSED',
  );

  print(
    'STUDY_GOOGLE_AI_OAUTH_LINK_ADAPTER_VERSION='
    '${StudyGoogleAiOAuthLinkAdapterV1.version}',
  );

  print(
    'RESULT=PASS_STUDY_GOOGLE_REUSE_APPLE_LINK_'
    'CLIENT_INERT_ADAPTER_CONTRACT',
  );
}
