final class ClinicalLongFormBackendNoRetentionAttestation {
  ClinicalLongFormBackendNoRetentionAttestation({
    required this.schemaVersion,
    required this.idempotencyKey,
    required this.requestReceivedAtUtc,
    required this.upstreamCompletedAtUtc,
    required this.temporaryAudioDeletedAtUtc,
    required this.temporaryAudioDeleted,
    required this.persistedAudioBytes,
    required this.sensitivePayloadLogged,
    required this.attestationToken,
  }) {
    validate();
  }

  static const String currentSchema =
      'medcases.long_form_backend_no_retention.v1';

  final String schemaVersion;
  final String idempotencyKey;
  final DateTime requestReceivedAtUtc;
  final DateTime upstreamCompletedAtUtc;
  final DateTime temporaryAudioDeletedAtUtc;

  /// Attests MedCases-backend transient-copy cleanup only.
  final bool temporaryAudioDeleted;

  /// Must remain zero for server-side durable persistence.
  final int persistedAudioBytes;

  /// Transcript/audio/grant token must not enter application logs.
  final bool sensitivePayloadLogged;

  /// Opaque server-generated proof material for a future verifier.
  final String attestationToken;

  void validate() {
    if (schemaVersion != currentSchema) {
      throw StateError('Unsupported no-retention attestation schema.');
    }

    if (idempotencyKey.trim().isEmpty || idempotencyKey.length > 240) {
      throw ArgumentError.value(
        idempotencyKey,
        'idempotencyKey',
      );
    }

    if (!temporaryAudioDeleted) {
      throw StateError(
        'MedCases backend temporary audio was not deleted.',
      );
    }

    if (persistedAudioBytes != 0) {
      throw StateError(
        'MedCases backend persisted audio bytes must be zero.',
      );
    }

    if (sensitivePayloadLogged) {
      throw StateError(
        'Sensitive transcription payload logging is forbidden.',
      );
    }

    final received = requestReceivedAtUtc.toUtc();
    final upstream = upstreamCompletedAtUtc.toUtc();
    final deleted = temporaryAudioDeletedAtUtc.toUtc();

    if (upstream.isBefore(received)) {
      throw StateError('Invalid upstream completion timestamp.');
    }

    if (deleted.isBefore(upstream)) {
      throw StateError(
        'Temporary audio deletion must occur after upstream completion.',
      );
    }

    if (attestationToken.trim().length < 16 || attestationToken.length > 512) {
      throw ArgumentError.value(
        '[REDACTED]',
        'attestationToken',
      );
    }
  }

  String get redactedDescription =>
      'ClinicalLongFormBackendNoRetentionAttestation('
      'idempotencyKey: $idempotencyKey, '
      'temporaryAudioDeleted: $temporaryAudioDeleted, '
      'persistedAudioBytes: $persistedAudioBytes, '
      'token: [REDACTED])';
}

abstract interface class ClinicalLongFormBackendNoRetentionAttestationVerifier {
  Future<bool> verify(
    ClinicalLongFormBackendNoRetentionAttestation attestation,
  );
}
