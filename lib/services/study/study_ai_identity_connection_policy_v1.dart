enum MedCasesPrimaryIdentityV1 { google, apple, other }

enum StudyAiConnectionStateV1 {
  notConfigured,
  googleConsentRequired,
  googleLinkRequired,
  ready,
}

enum StudyAiExecutionLaneV1 { personalFree, backendProtected }

class StudyAiIdentitySnapshotV1 {
  const StudyAiIdentitySnapshotV1({
    required this.medCasesIdentity,
    required this.googleProviderLinkedToMedCasesUid,
    required this.googleAiGrantReady,
  });

  final MedCasesPrimaryIdentityV1 medCasesIdentity;

  /// True only when the Google auth provider is linked to the current
  /// MedCases Firebase identity. Linking must preserve the same MedCases UID.
  final bool googleProviderLinkedToMedCasesUid;

  /// Server-side authorization grant is ready for the Study personal route.
  /// This model intentionally carries no access token, refresh token,
  /// auth code, API key, project ID, provider name, or commercial model name.
  final bool googleAiGrantReady;
}

class StudyAiConnectionPlanV1 {
  const StudyAiConnectionPlanV1({
    required this.state,
    required this.reuseCurrentGoogleIdentity,
    required this.linkGoogleToExistingMedCasesUid,
    required this.requestIncrementalGoogleConsent,
    required this.forceGoogleAccountPicker,
    required this.preserveMedCasesUid,
    required this.manualApiKeyRequired,
    required this.separateGeminiLoginRequired,
    required this.serverAuthorizationCodeExchangeRequired,
    required this.rawGoogleCredentialMayPersistOnClient,
  });

  final StudyAiConnectionStateV1 state;

  final bool reuseCurrentGoogleIdentity;

  final bool linkGoogleToExistingMedCasesUid;

  final bool requestIncrementalGoogleConsent;

  /// False for a MedCases Google identity because the current Google identity
  /// should be reused when the platform can safely provide the same account
  /// as a login hint / existing identity.
  ///
  /// True for Apple/other identity on first Google link because an account
  /// must be selected once.
  final bool forceGoogleAccountPicker;

  final bool preserveMedCasesUid;

  final bool manualApiKeyRequired;

  final bool separateGeminiLoginRequired;

  /// Target OAuth architecture: client obtains a short-lived authorization
  /// result and the MedCases backend performs the server-side code exchange.
  final bool serverAuthorizationCodeExchangeRequired;

  /// Raw OAuth credentials must never be persisted by this app policy.
  final bool rawGoogleCredentialMayPersistOnClient;
}

class StudyAiRoutePlanV1 {
  const StudyAiRoutePlanV1({
    required this.executionLane,
    required this.personalFreeAllowed,
    required this.primaryCapabilityAlias,
    required this.fallbackCapabilityAliases,
  });

  final StudyAiExecutionLaneV1 executionLane;

  final bool personalFreeAllowed;

  /// App-facing stable capability alias. No commercial provider/model name.
  final String primaryCapabilityAlias;

  /// Ordered app-facing fallback capability aliases.
  final List<String> fallbackCapabilityAliases;
}

class StudyAiIdentityConnectionPolicyV1 {
  static const String version =
      'medcases_study_ai_identity_connection_policy_v1';

  static const String studyPrimaryAlias = 'study_primary';

  static const String studyFallback1Alias = 'study_fallback_1';

  static const String studyFallback2Alias = 'study_fallback_2';

  static StudyAiConnectionPlanV1 buildConnectionPlan(
    StudyAiIdentitySnapshotV1 snapshot,
  ) {
    if (snapshot.googleAiGrantReady) {
      return const StudyAiConnectionPlanV1(
        state: StudyAiConnectionStateV1.ready,
        reuseCurrentGoogleIdentity: true,
        linkGoogleToExistingMedCasesUid: false,
        requestIncrementalGoogleConsent: false,
        forceGoogleAccountPicker: false,
        preserveMedCasesUid: true,
        manualApiKeyRequired: false,
        separateGeminiLoginRequired: false,
        serverAuthorizationCodeExchangeRequired: true,
        rawGoogleCredentialMayPersistOnClient: false,
      );
    }

    if (snapshot.medCasesIdentity == MedCasesPrimaryIdentityV1.google) {
      return const StudyAiConnectionPlanV1(
        state: StudyAiConnectionStateV1.googleConsentRequired,
        reuseCurrentGoogleIdentity: true,
        linkGoogleToExistingMedCasesUid: false,
        requestIncrementalGoogleConsent: true,
        forceGoogleAccountPicker: false,
        preserveMedCasesUid: true,
        manualApiKeyRequired: false,
        separateGeminiLoginRequired: false,
        serverAuthorizationCodeExchangeRequired: true,
        rawGoogleCredentialMayPersistOnClient: false,
      );
    }

    if (!snapshot.googleProviderLinkedToMedCasesUid) {
      return const StudyAiConnectionPlanV1(
        state: StudyAiConnectionStateV1.googleLinkRequired,
        reuseCurrentGoogleIdentity: false,
        linkGoogleToExistingMedCasesUid: true,
        requestIncrementalGoogleConsent: true,
        forceGoogleAccountPicker: true,
        preserveMedCasesUid: true,
        manualApiKeyRequired: false,
        separateGeminiLoginRequired: false,
        serverAuthorizationCodeExchangeRequired: true,
        rawGoogleCredentialMayPersistOnClient: false,
      );
    }

    return const StudyAiConnectionPlanV1(
      state: StudyAiConnectionStateV1.googleConsentRequired,
      reuseCurrentGoogleIdentity: true,
      linkGoogleToExistingMedCasesUid: false,
      requestIncrementalGoogleConsent: true,
      forceGoogleAccountPicker: false,
      preserveMedCasesUid: true,
      manualApiKeyRequired: false,
      separateGeminiLoginRequired: false,
      serverAuthorizationCodeExchangeRequired: true,
      rawGoogleCredentialMayPersistOnClient: false,
    );
  }

  static StudyAiRoutePlanV1 buildRoutePlan({
    required bool isProtectedClinicalContext,
    required bool googleAiGrantReady,
  }) {
    if (isProtectedClinicalContext) {
      return const StudyAiRoutePlanV1(
        executionLane: StudyAiExecutionLaneV1.backendProtected,
        personalFreeAllowed: false,
        primaryCapabilityAlias: studyFallback1Alias,
        fallbackCapabilityAliases: <String>[studyFallback2Alias],
      );
    }

    if (googleAiGrantReady) {
      return const StudyAiRoutePlanV1(
        executionLane: StudyAiExecutionLaneV1.personalFree,
        personalFreeAllowed: true,
        primaryCapabilityAlias: studyPrimaryAlias,
        fallbackCapabilityAliases: <String>[
          studyFallback1Alias,
          studyFallback2Alias,
        ],
      );
    }

    return const StudyAiRoutePlanV1(
      executionLane: StudyAiExecutionLaneV1.backendProtected,
      personalFreeAllowed: false,
      primaryCapabilityAlias: studyFallback1Alias,
      fallbackCapabilityAliases: <String>[studyFallback2Alias],
    );
  }
}
