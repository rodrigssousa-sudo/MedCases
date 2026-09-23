import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'canonical_catalog_cipher.dart';

CanonicalCatalogCipher createPrivateDataCipher() => _PrivateDataCipher();

class _PrivateDataCipher implements CanonicalCatalogCipher {
  static const _channel = MethodChannel('medcases/audio_at_rest_v2');
  Map<String, Object> _identity(String uid, String metadata) {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('PRIVATE_CACHE_NOT_OWNED');
    }
    final owner = catalogUidHash(uid);
    return {
      'keyId': 'private.${owner.substring(0, 48)}',
      'sessionId': owner,
      'assetKind': 'privateUserData',
      'logicalName': catalogUidHash(metadata)
    };
  }

  @override
  Future<Uint8List> seal(
      String uid, String metadata, Uint8List plaintext) async {
    final data = await _channel.invokeMethod<Uint8List>(
        'seal', {..._identity(uid, metadata), 'clearText': plaintext});
    _identity(uid, metadata);
    if (data == null) throw StateError('PRIVATE_CACHE_SEAL_FAILED');
    return data;
  }

  @override
  Future<Uint8List> open(
      String uid, String metadata, Uint8List ciphertext) async {
    final data = await _channel.invokeMethod<Uint8List>(
        'open', {..._identity(uid, metadata), 'sealedData': ciphertext});
    _identity(uid, metadata);
    if (data == null) throw StateError('PRIVATE_CACHE_OPEN_FAILED');
    return data;
  }
}
