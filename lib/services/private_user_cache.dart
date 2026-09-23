import 'private_session_epoch.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'canonical_catalog_cipher.dart';
import 'private_data_cipher_native.dart'
    if (dart.library.js_interop) 'private_data_cipher_web.dart';

/// Encrypted, UID-bound application cache. Never guesses the owner of a legacy
/// unscoped value. Migration removes plaintext only after durable encryption.
class PrivateUserCache {
  PrivateUserCache(
      {CanonicalCatalogCipher? cipher,
      String? Function()? uid,
      Future<SharedPreferences> Function()? preferences})
      : _cipher = cipher ?? createPrivateDataCipher(),
        _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _preferences = preferences ?? SharedPreferences.getInstance;
  static final instance = PrivateUserCache();
  final CanonicalCatalogCipher _cipher;
  final String? Function() _uid;
  final Future<SharedPreferences> Function() _preferences;
  void _check(String uid) {
    if (uid.isEmpty || _uid() != uid)
      throw StateError('PRIVATE_CACHE_NOT_OWNED');
  }

  String _key(String uid, String domain) =>
      'private.v1.${catalogUidHash(uid)}.$domain';
  String _aad(String uid, String domain) => jsonEncode(
      {'version': 1, 'owner': catalogUidHash(uid), 'domain': domain});
  Future<void> write(String uid, String domain, String value) async {
    final epoch = PrivateSessionEpoch.current;
    _check(uid);
    if (epoch != PrivateSessionEpoch.current)
      throw StateError('STALE_USER_OPERATION');
    final aad = _aad(uid, domain);
    final sealed =
        await _cipher.seal(uid, aad, Uint8List.fromList(utf8.encode(value)));
    _check(uid);
    if (epoch != PrivateSessionEpoch.current)
      throw StateError('STALE_USER_OPERATION');
    final prefs = await _preferences();
    _check(uid);
    if (epoch != PrivateSessionEpoch.current)
      throw StateError('STALE_USER_OPERATION');
    if (!await prefs.setString(
        _key(uid, domain),
        jsonEncode({
          'version': 1,
          'metadata': aad,
          'ciphertext': base64Encode(sealed)
        }))) {
      throw StateError('PRIVATE_CACHE_WRITE_FAILED');
    }
    _check(uid);
    if (epoch != PrivateSessionEpoch.current)
      throw StateError('STALE_USER_OPERATION');
  }

  Future<String?> read(String uid, String domain) async {
    final epoch = PrivateSessionEpoch.current;
    _check(uid);
    if (epoch != PrivateSessionEpoch.current)
      throw StateError('STALE_USER_OPERATION');
    final prefs = await _preferences();
    _check(uid);
    if (epoch != PrivateSessionEpoch.current)
      throw StateError('STALE_USER_OPERATION');
    final stored = prefs.getString(_key(uid, domain));
    if (stored != null) {
      final envelope = jsonDecode(stored) as Map<String, dynamic>;
      final aad = _aad(uid, domain);
      if (envelope['version'] != 1 || envelope['metadata'] != aad) {
        throw StateError('PRIVATE_CACHE_ENVELOPE_INVALID');
      }
      final clear = await _cipher.open(
          uid, aad, base64Decode(envelope['ciphertext'] as String));
      _check(uid);
      if (epoch != PrivateSessionEpoch.current)
        throw StateError('STALE_USER_OPERATION');
      return utf8.decode(clear);
    }
    // Exact UID prefix only; unscoped historical values are not attributable.
    final legacyKey = '${uid}_$domain';
    final old = prefs.get(legacyKey);
    if (old == null) return null;
    final value = old is String ? old : jsonEncode(old);
    await write(uid, domain, value);
    _check(uid);
    if (epoch != PrivateSessionEpoch.current)
      throw StateError('STALE_USER_OPERATION');
    if (!await prefs.remove(legacyKey))
      throw StateError('PRIVATE_CACHE_MIGRATION_FAILED');
    return value;
  }
}
