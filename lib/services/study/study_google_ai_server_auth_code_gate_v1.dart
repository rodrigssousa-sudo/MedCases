class StudyGoogleAiServerAuthCodeGateV1 {
  const StudyGoogleAiServerAuthCodeGateV1._();

  static const String version =
      'medcases_study_google_ai_server_auth_code_gate_v1';

  /// Hard-disabled until the Study personal Gemini OAuth path is physically
  /// validated. With this false, current GoogleSignIn behavior remains intact.
  static const bool enabled = false;

  /// OAuth client IDs are public identifiers, not secrets.
  /// This is the single surviving Web application OAuth client recovered from
  /// the remote Firebase Android SDK configuration.
  static const String serverClientId =
      '1076800980330-b76rnfcat7gtjbe09rmicc5534egfe7e.apps.googleusercontent.com';

  static const bool forceCodeForRefreshTokenWhenEnabled = false;

  /// Official Gemini API OAuth scope. It is not requested while [enabled]
  /// remains false.
  static const List<String> incrementalGeminiScopes = <String>[
    'https://www.googleapis.com/auth/cloud-platform.read-only',
    'https://www.googleapis.com/auth/generative-language.retriever',
  ];

  static List<String> effectiveIncrementalGeminiScopes() {
    return enabled ? incrementalGeminiScopes : const <String>[];
  }

  static bool mayRequestIncrementalConsent() {
    return enabled;
  }

  static String? effectiveServerClientId() {
    return enabled ? serverClientId : null;
  }

  static bool effectiveForceCodeForRefreshToken() {
    return enabled && forceCodeForRefreshTokenWhenEnabled;
  }

  static bool mayReadServerAuthCode() {
    return enabled;
  }
}
