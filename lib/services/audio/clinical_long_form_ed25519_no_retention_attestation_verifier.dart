import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'clinical_long_form_backend_no_retention_attestation.dart';
import 'clinical_long_form_no_retention_attestation_canonical_payload.dart';

final class ClinicalLongFormEd25519NoRetentionAttestationVerifier
    implements ClinicalLongFormBackendNoRetentionAttestationVerifier {
  ClinicalLongFormEd25519NoRetentionAttestationVerifier({
    required Map<String, List<int>> trustedPublicKeysById,
  }) : _trustedPublicKeysById = _buildTrustedKeys(trustedPublicKeysById) {
    if (_trustedPublicKeysById.isEmpty) {
      throw ArgumentError.value(
        trustedPublicKeysById,
        'trustedPublicKeysById',
        'At least one trusted Ed25519 public key is required.',
      );
    }
  }

  static const bool productionCutoverEnabled = false;
  static const bool privateSigningKeyPresentInFlutter = false;
  static const bool publicKeyVerificationOnly = true;
  static const String tokenAlgorithm = 'ed25519';

  final Map<String, SimplePublicKey> _trustedPublicKeysById;
  final Ed25519 _algorithm = Ed25519();

  int get trustedKeyCount => _trustedPublicKeysById.length;

  @override
  Future<bool> verify(
    ClinicalLongFormBackendNoRetentionAttestation attestation,
  ) async {
    try {
      attestation.validate();

      final parts = attestation.attestationToken.split('.');
      if (parts.length != 3 || parts[0] != tokenAlgorithm) {
        return false;
      }

      final keyId = parts[1];
      if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(keyId)) {
        return false;
      }

      final publicKey = _trustedPublicKeysById[keyId];
      if (publicKey == null) {
        return false;
      }

      final signatureBytes = base64Url.decode(_withBase64Padding(parts[2]));

      if (signatureBytes.length != 64) {
        return false;
      }

      final payload =
          ClinicalLongFormNoRetentionAttestationCanonicalPayload.encode(
        attestation: attestation,
        keyId: keyId,
      );

      return _algorithm.verify(
        payload,
        signature: Signature(
          signatureBytes,
          publicKey: publicKey,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static Map<String, SimplePublicKey> _buildTrustedKeys(
    Map<String, List<int>> input,
  ) {
    final result = <String, SimplePublicKey>{};

    for (final entry in input.entries) {
      final keyId = entry.key.trim();

      if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(keyId)) {
        throw ArgumentError.value(entry.key, 'keyId');
      }

      final bytes = List<int>.unmodifiable(entry.value);
      if (bytes.length != 32) {
        throw ArgumentError.value(
          bytes.length,
          'publicKeyBytes.length',
          'Ed25519 public key must be 32 bytes.',
        );
      }

      result[keyId] = SimplePublicKey(
        bytes,
        type: KeyPairType.ed25519,
      );
    }

    return Map<String, SimplePublicKey>.unmodifiable(result);
  }

  static String _withBase64Padding(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) {
      return value;
    }
    return '$value${'=' * (4 - remainder)}';
  }
}
