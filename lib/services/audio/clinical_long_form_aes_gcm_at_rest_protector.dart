import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'clinical_long_form_at_rest_key_provider.dart';
import 'clinical_long_form_sensitive_at_rest_policy.dart';

final class ClinicalLongFormSensitiveEnvelope {
  ClinicalLongFormSensitiveEnvelope({
    required this.keyId,
    required this.sessionId,
    required this.assetKind,
    required this.logicalName,
    required this.secretBoxBase64,
  }) {
    if (secretBoxBase64.isEmpty) {
      throw StateError('Sensitive envelope payload missing.');
    }
  }

  static const String schemaVersion =
      'medcases.long_form_sensitive_envelope.v1';
  static const String algorithm = 'AES-256-GCM';

  final String keyId;
  final String sessionId;
  final String assetKind;
  final String logicalName;
  final String secretBoxBase64;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'algorithm': algorithm,
        'keyId': keyId,
        'sessionId': sessionId,
        'assetKind': assetKind,
        'logicalName': logicalName,
        'secretBoxBase64': secretBoxBase64,
      };
}

final class ClinicalLongFormAesGcmAtRestProtector {
  ClinicalLongFormAesGcmAtRestProtector({
    required ClinicalLongFormAtRestKeyProvider keyProvider,
  }) : _keyProvider = keyProvider;

  static const bool productionPersistenceIntegrationEnabled = false;
  static const bool plaintextDurableStorageAllowed = false;
  static const bool hardcodedSecretKeyPresent = false;

  final ClinicalLongFormAtRestKeyProvider _keyProvider;
  final AesGcm _algorithm = AesGcm.with256bits();

  Future<ClinicalLongFormSensitiveEnvelope> seal({
    required ClinicalLongFormSensitiveAssetDescriptor descriptor,
    required List<int> clearText,
  }) async {
    final rule = ClinicalLongFormSensitiveAtRestPolicy.ruleFor(descriptor.kind);
    if (!rule.applicationLayerEncryptionRequired) {
      throw StateError('Asset kind is not eligible for durable encryption.');
    }

    final key = await _keyProvider.currentEncryptionKey();
    final box = await _algorithm.encrypt(
      clearText,
      secretKey: key.secretKey,
      aad: _aad(descriptor, key.keyId),
    );

    return ClinicalLongFormSensitiveEnvelope(
      keyId: key.keyId,
      sessionId: descriptor.sessionId,
      assetKind: descriptor.kind.name,
      logicalName: descriptor.logicalName,
      secretBoxBase64: base64Encode(box.concatenation()),
    );
  }

  Future<List<int>> open({
    required ClinicalLongFormSensitiveEnvelope envelope,
    required ClinicalLongFormSensitiveAssetDescriptor descriptor,
  }) async {
    if (envelope.sessionId != descriptor.sessionId ||
        envelope.assetKind != descriptor.kind.name ||
        envelope.logicalName != descriptor.logicalName) {
      throw StateError('Sensitive envelope identity mismatch.');
    }

    final rule = ClinicalLongFormSensitiveAtRestPolicy.ruleFor(descriptor.kind);
    if (!rule.applicationLayerEncryptionRequired) {
      throw StateError('Asset kind is not eligible for durable decryption.');
    }

    final key = await _keyProvider.keyForId(envelope.keyId);
    final box = SecretBox.fromConcatenation(
      base64Decode(envelope.secretBoxBase64),
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
      copy: true,
    );

    return _algorithm.decrypt(
      box,
      secretKey: key,
      aad: _aad(descriptor, envelope.keyId),
    );
  }

  List<int> _aad(
    ClinicalLongFormSensitiveAssetDescriptor descriptor,
    String keyId,
  ) =>
      utf8.encode(<String>[
        ClinicalLongFormSensitiveEnvelope.schemaVersion,
        ClinicalLongFormSensitiveEnvelope.algorithm,
        keyId,
        descriptor.sessionId,
        descriptor.kind.name,
        descriptor.logicalName,
      ].join('\n'));
}
