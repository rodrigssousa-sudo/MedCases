import 'entitlement_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/dart.dart';
import 'package:flutter/services.dart';

abstract interface class CanonicalCatalogCipher {
  Future<Uint8List> seal(String uid, String metadata, Uint8List plaintext);
  Future<Uint8List> open(String uid, String metadata, Uint8List ciphertext);
}

/// Reuses the existing native AES-GCM channel and non-exportable platform key.
/// Keys are separated by UID and domain; envelope metadata is authenticated AAD.
class NativeCanonicalCatalogCipher implements CanonicalCatalogCipher {
  const NativeCanonicalCatalogCipher();
  static const _channel = MethodChannel('medcases/audio_at_rest_v2');
  Map<String, Object> _identity(String uid, String metadata) {
    if (!EntitlementService.instance.isPremium ||
        EntitlementService.instance.current.resolvedUid != uid) {
      throw StateError('CACHE_NOT_AUTHORIZED');
    }
    final owner = catalogUidHash(uid);
    return {
      'keyId': 'catalog.${owner.substring(0, 48)}',
      'sessionId': owner,
      'assetKind': 'premiumDrugCatalog',
      'logicalName': catalogUidHash(metadata),
    };
  }

  @override
  Future<Uint8List> seal(
      String uid, String metadata, Uint8List plaintext) async {
    final bytes = await _channel.invokeMethod<Uint8List>(
        'seal', {..._identity(uid, metadata), 'clearText': plaintext});
    _identity(uid, metadata);
    if (bytes == null || bytes.length <= 28)
      throw StateError('CACHE_SEAL_FAILED');
    return bytes;
  }

  @override
  Future<Uint8List> open(
      String uid, String metadata, Uint8List ciphertext) async {
    final bytes = await _channel.invokeMethod<Uint8List>(
        'open', {..._identity(uid, metadata), 'sealedData': ciphertext});
    _identity(uid, metadata);
    if (bytes == null) throw StateError('CACHE_OPEN_FAILED');
    return bytes;
  }
}

String catalogUidHash(String value) => const DartSha256()
    .hashSync(utf8.encode(value))
    .bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();
