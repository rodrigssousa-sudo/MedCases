import 'clinical_long_form_backend_auth_contract.dart';
import 'clinical_long_form_backend_no_retention_attestation.dart';

final class ClinicalLongFormBackendProxyRequest {
  ClinicalLongFormBackendProxyRequest({
    required this.sessionId,
    required this.segmentPath,
    required this.contentLengthBytes,
    required this.contentType,
    required this.idempotencyKey,
    required this.model,
    required this.language,
    required this.prompt,
    required List<String> keywords,
    this.timeout = const Duration(minutes: 2),
  }) : keywords = List<String>.unmodifiable(keywords) {
    validate();
  }

  final String sessionId;

  /// Local source handle. Future transport may stream this file.
  /// This contract does not itself open/read/upload the file.
  final String segmentPath;

  final int contentLengthBytes;
  final String contentType;
  final String idempotencyKey;
  final String model;
  final String language;
  final String prompt;
  final List<String> keywords;
  final Duration timeout;

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }

    if (!segmentPath.toLowerCase().endsWith('.m4a')) {
      throw StateError('Backend proxy contract requires M4A.');
    }

    if (contentLengthBytes < 1 || contentLengthBytes > 25 * 1024 * 1024) {
      throw StateError('Invalid backend proxy audio size.');
    }

    if (contentType != 'audio/mp4') {
      throw StateError('Backend proxy content type must be audio/mp4.');
    }

    if (idempotencyKey.trim().isEmpty || idempotencyKey.length > 240) {
      throw ArgumentError.value(
        idempotencyKey,
        'idempotencyKey',
      );
    }

    if (model != 'gpt-transcribe') {
      throw StateError('Unexpected backend transcription model.');
    }

    if (language != 'pt' && language != 'es') {
      throw StateError('Backend proxy language must be pt or es.');
    }

    if (prompt.length > 4000 || keywords.length > 120) {
      throw StateError('Backend proxy context exceeds contract.');
    }

    if (timeout < const Duration(seconds: 15) ||
        timeout > const Duration(minutes: 5)) {
      throw StateError('Backend proxy timeout outside safe bounds.');
    }
  }
}

final class ClinicalLongFormBackendProxyResponse {
  ClinicalLongFormBackendProxyResponse({
    required this.idempotencyKey,
    required this.transcript,
    required this.resultRef,
    required this.noRetentionAttestation,
  }) {
    validate();
  }

  final String idempotencyKey;
  final String transcript;
  final String resultRef;
  final ClinicalLongFormBackendNoRetentionAttestation noRetentionAttestation;

  void validate() {
    if (idempotencyKey.trim().isEmpty) {
      throw StateError('Backend proxy idempotency key is empty.');
    }
    if (transcript.trim().isEmpty) {
      throw StateError('Backend proxy transcript is empty.');
    }
    if (resultRef.trim().isEmpty || resultRef.length > 240) {
      throw StateError('Backend proxy resultRef is invalid.');
    }

    noRetentionAttestation.validate();

    if (noRetentionAttestation.idempotencyKey != idempotencyKey) {
      throw StateError(
        'No-retention attestation idempotency mismatch.',
      );
    }
  }
}

final class ClinicalLongFormBackendProxyException implements Exception {
  const ClinicalLongFormBackendProxyException(
    this.code, {
    this.retryable = true,
  });

  final String code;
  final bool retryable;

  @override
  String toString() => 'ClinicalLongFormBackendProxyException('
      'code: $code, retryable: $retryable)';
}

abstract interface class ClinicalLongFormBackendProxyTransport {
  Future<ClinicalLongFormBackendProxyResponse> transcribe({
    required ClinicalLongFormBackendProxyRequest request,
    required ClinicalLongFormBackendTranscriptionGrant grant,
  });
}

final class ClinicalLongFormBackendProxyServerPolicy {
  const ClinicalLongFormBackendProxyServerPolicy._();

  static const bool productionTransportImplemented = false;
  static const bool rawAudioDurablePersistenceAllowed = false;
  static const bool sensitivePayloadLoggingAllowed = false;
  static const bool grantLoggingAllowed = false;
  static const bool transcriptLoggingAllowed = false;

  /// Maximum expected MedCases-backend transient-copy lifetime.
  /// This is our server contract, not a third-party retention claim.
  static const Duration maxMedCasesTransientAudioLifetime =
      Duration(minutes: 15);

  static const bool idempotencyRequired = true;
  static const bool noRetentionAttestationRequired = true;
}
