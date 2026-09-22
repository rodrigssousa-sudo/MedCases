import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:medcases/services/canonical_catalog_cipher.dart';

/// Real AES-256-GCM with an in-memory key vault. Tests crypto/envelope contracts,
/// not a physical Keychain/Keystore implementation.
class CatalogTestCipher implements CanonicalCatalogCipher {
  final keys = <String, SecretKey>{};
  final aes = AesGcm.with256bits();
  @override
  Future<Uint8List> seal(
      String uid, String metadata, Uint8List plaintext) async {
    final key = keys[uid] ??= await aes.newSecretKey();
    final box = await aes.encrypt(plaintext,
        secretKey: key, aad: utf8.encode(metadata));
    return Uint8List.fromList(
        [...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  @override
  Future<Uint8List> open(
      String uid, String metadata, Uint8List ciphertext) async {
    final key = keys[uid];
    if (key == null) throw StateError('MISSING_KEY');
    return Uint8List.fromList(await aes.decrypt(
        SecretBox(ciphertext.sublist(12, ciphertext.length - 16),
            nonce: ciphertext.sublist(0, 12),
            mac: Mac(ciphertext.sublist(ciphertext.length - 16))),
        secretKey: key,
        aad: utf8.encode(metadata)));
  }
}
