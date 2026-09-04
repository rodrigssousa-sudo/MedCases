import 'study_ai_identity_connection_policy_v1.dart';

enum StudyGoogleAiClientActionV1 {
  noAction,
  requestIncrementalConsentForCurrentGoogleIdentity,
  linkGoogleToCurrentMedCasesIdentity,
}

enum StudyGoogleAiLinkFailureV1 {
  none,
  cancelled,
  consentDenied,
  providerAlreadyLinked,
  credentialAlreadyInUse,
  uidChanged,
  missingServerAuthorizationCode,
  unsupportedPlatform,
  technicalFailure,
}

class StudyGoogleAiClientRequestV1 {
  const StudyGoogleAiClientRequestV1({
    required this.action,
    required this.preserveMedCasesUid,
    required this.forceAccountPicker,
    required this.requestIncrementalConsent,
    required this.serverAuthorizationCodeRequired,
  });

  final StudyGoogleAiClientActionV1 action;
  final bool preserveMedCasesUid;
  final bool forceAccountPicker;
  final bool requestIncrementalConsent;
  final bool serverAuthorizationCodeRequired;
}

class StudyGoogleAiLinkResultV1 {
  const StudyGoogleAiLinkResultV1._({
    required this.success,
    required this.failure,
    required this.uidPreserved,
    required this.serverAuthorizationCodePresent,
  });

  const StudyGoogleAiLinkResultV1.success({
    required bool serverAuthorizationCodePresent,
  }) : this._(
         success: true,
         failure: StudyGoogleAiLinkFailureV1.none,
         uidPreserved: true,
         serverAuthorizationCodePresent: serverAuthorizationCodePresent,
       );

  const StudyGoogleAiLinkResultV1.failure(
    StudyGoogleAiLinkFailureV1 failure, {
    required bool uidPreserved,
  }) : this._(
         success: false,
         failure: failure,
         uidPreserved: uidPreserved,
         serverAuthorizationCodePresent: false,
       );

  final bool success;
  final StudyGoogleAiLinkFailureV1 failure;
  final bool uidPreserved;

  /// Boolean only. The authorization code itself is intentionally not modeled
  /// in this persistent result object.
  final bool serverAuthorizationCodePresent;
}

class StudyGoogleAiOAuthLinkAdapterV1 {
  static const String version =
      'medcases_study_google_ai_oauth_link_adapter_v1';

  static StudyGoogleAiClientRequestV1 plan(StudyAiIdentitySnapshotV1 snapshot) {
    final connectionPlan =
        StudyAiIdentityConnectionPolicyV1.buildConnectionPlan(snapshot);

    switch (connectionPlan.state) {
      case StudyAiConnectionStateV1.ready:
        return const StudyGoogleAiClientRequestV1(
          action: StudyGoogleAiClientActionV1.noAction,
          preserveMedCasesUid: true,
          forceAccountPicker: false,
          requestIncrementalConsent: false,
          serverAuthorizationCodeRequired: false,
        );

      case StudyAiConnectionStateV1.googleConsentRequired:
        return const StudyGoogleAiClientRequestV1(
          action: StudyGoogleAiClientActionV1
              .requestIncrementalConsentForCurrentGoogleIdentity,
          preserveMedCasesUid: true,
          forceAccountPicker: false,
          requestIncrementalConsent: true,
          serverAuthorizationCodeRequired: true,
        );

      case StudyAiConnectionStateV1.googleLinkRequired:
        return const StudyGoogleAiClientRequestV1(
          action:
              StudyGoogleAiClientActionV1.linkGoogleToCurrentMedCasesIdentity,
          preserveMedCasesUid: true,
          forceAccountPicker: true,
          requestIncrementalConsent: true,
          serverAuthorizationCodeRequired: true,
        );

      case StudyAiConnectionStateV1.notConfigured:
        return const StudyGoogleAiClientRequestV1(
          action: StudyGoogleAiClientActionV1.noAction,
          preserveMedCasesUid: true,
          forceAccountPicker: false,
          requestIncrementalConsent: false,
          serverAuthorizationCodeRequired: false,
        );
    }
  }

  static StudyGoogleAiLinkResultV1 validatePostLink({
    required String uidBefore,
    required String uidAfter,
    required bool serverAuthorizationCodePresent,
    required bool cancelled,
    required bool consentDenied,
    required bool providerAlreadyLinked,
    required bool credentialAlreadyInUse,
    required bool unsupportedPlatform,
    required bool technicalFailure,
  }) {
    final before = uidBefore.trim();
    final after = uidAfter.trim();

    if (cancelled) {
      return const StudyGoogleAiLinkResultV1.failure(
        StudyGoogleAiLinkFailureV1.cancelled,
        uidPreserved: true,
      );
    }

    if (consentDenied) {
      return const StudyGoogleAiLinkResultV1.failure(
        StudyGoogleAiLinkFailureV1.consentDenied,
        uidPreserved: true,
      );
    }

    if (credentialAlreadyInUse) {
      return const StudyGoogleAiLinkResultV1.failure(
        StudyGoogleAiLinkFailureV1.credentialAlreadyInUse,
        uidPreserved: true,
      );
    }

    if (providerAlreadyLinked) {
      return const StudyGoogleAiLinkResultV1.failure(
        StudyGoogleAiLinkFailureV1.providerAlreadyLinked,
        uidPreserved: true,
      );
    }

    if (unsupportedPlatform) {
      return const StudyGoogleAiLinkResultV1.failure(
        StudyGoogleAiLinkFailureV1.unsupportedPlatform,
        uidPreserved: true,
      );
    }

    if (technicalFailure) {
      return const StudyGoogleAiLinkResultV1.failure(
        StudyGoogleAiLinkFailureV1.technicalFailure,
        uidPreserved: true,
      );
    }

    if (before.isEmpty || after.isEmpty || before != after) {
      return const StudyGoogleAiLinkResultV1.failure(
        StudyGoogleAiLinkFailureV1.uidChanged,
        uidPreserved: false,
      );
    }

    if (!serverAuthorizationCodePresent) {
      return const StudyGoogleAiLinkResultV1.failure(
        StudyGoogleAiLinkFailureV1.missingServerAuthorizationCode,
        uidPreserved: true,
      );
    }

    return const StudyGoogleAiLinkResultV1.success(
      serverAuthorizationCodePresent: true,
    );
  }
}
