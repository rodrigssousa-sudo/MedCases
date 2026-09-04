final class ClinicalLongFormBackendTranscriptionGrant {
  ClinicalLongFormBackendTranscriptionGrant({
    required this.sessionId,
    required this.scope,
    required this.accessToken,
    required this.issuedAtUtc,
    required this.expiresAtUtc,
  }) {
    _validateStaticFields();
  }

  static const String requiredScope = 'long_form_audio_transcription';

  final String sessionId;
  final String scope;

  /// Opaque MedCases-backend token.
  ///
  /// This is NOT an OpenAI API key and intentionally has no JSON/serialization
  /// method. It must live in memory only.
  final String accessToken;

  final DateTime issuedAtUtc;
  final DateTime expiresAtUtc;

  void validateAt(DateTime nowUtc) {
    _validateStaticFields();

    final now = nowUtc.toUtc();

    if (!expiresAtUtc.toUtc().isAfter(now)) {
      throw StateError('Backend transcription grant expired.');
    }

    if (!expiresAtUtc.toUtc().isAfter(issuedAtUtc.toUtc())) {
      throw StateError('Backend transcription grant has invalid lifetime.');
    }
  }

  String get redactedDescription => 'ClinicalLongFormBackendTranscriptionGrant('
      'sessionId: $sessionId, scope: $scope, token: [REDACTED])';

  void _validateStaticFields() {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }

    if (scope != requiredScope) {
      throw ArgumentError.value(scope, 'scope');
    }

    if (accessToken.trim().length < 16) {
      throw ArgumentError.value(
        '[REDACTED]',
        'accessToken',
        'Backend grant token is invalid.',
      );
    }
  }
}

abstract interface class ClinicalLongFormBackendGrantProvider {
  Future<ClinicalLongFormBackendTranscriptionGrant> acquireTranscriptionGrant({
    required String sessionId,
    required String deduplicationKey,
  });
}

abstract interface class ClinicalLongFormBackendSessionAccessTokenProvider {
  Future<String> acquireSessionAccessToken();
}

final class ClinicalLongFormBackendGrantProviderException implements Exception {
  const ClinicalLongFormBackendGrantProviderException(
    this.code, {
    this.retryable = true,
  });

  final String code;
  final bool retryable;

  @override
  String toString() => 'ClinicalLongFormBackendGrantProviderException('
      'code: $code, retryable: $retryable)';
}

final class ClinicalLongFormBackendAuthPolicy {
  const ClinicalLongFormBackendAuthPolicy._();

  static const bool persistentGrantStorageAllowed = false;
  static const bool openAiApiKeyInFlutterAllowed = false;
  static const bool directOpenAiAuthenticationAllowed = false;
  static const bool backendMediatedAuthenticationRequired = true;
}
