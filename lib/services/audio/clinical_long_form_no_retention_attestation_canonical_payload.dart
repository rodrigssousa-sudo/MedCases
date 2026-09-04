import 'dart:convert';

import 'clinical_long_form_backend_no_retention_attestation.dart';

final class ClinicalLongFormNoRetentionAttestationCanonicalPayload {
  const ClinicalLongFormNoRetentionAttestationCanonicalPayload._();

  static const String domain =
      'medcases.long_form_backend_no_retention.ed25519.v1';

  static List<int> encode({
    required ClinicalLongFormBackendNoRetentionAttestation attestation,
    required String keyId,
  }) {
    attestation.validate();

    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(keyId)) {
      throw ArgumentError.value(keyId, 'keyId');
    }

    final canonical = <String>[
      domain,
      keyId,
      attestation.schemaVersion,
      attestation.idempotencyKey,
      attestation.requestReceivedAtUtc.toUtc().toIso8601String(),
      attestation.upstreamCompletedAtUtc.toUtc().toIso8601String(),
      attestation.temporaryAudioDeletedAtUtc.toUtc().toIso8601String(),
      attestation.temporaryAudioDeleted ? '1' : '0',
      attestation.persistedAudioBytes.toString(),
      attestation.sensitivePayloadLogged ? '1' : '0',
    ].join('\n');

    return utf8.encode(canonical);
  }
}
