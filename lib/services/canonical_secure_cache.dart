import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'canonical_catalog_cipher.dart';

class CanonicalSecureCache {
  CanonicalSecureCache(
      {required this.preferences,
      required this.cipher,
      required this.uid,
      required this.authorized});
  final SharedPreferences preferences;
  final CanonicalCatalogCipher cipher;
  final String? Function() uid;
  final bool Function() authorized;
  String _key(String owner) =>
      'canonical.drug.encrypted.v1.${catalogUidHash(owner)}';
  String _metadata(Map<String, dynamic> e) => jsonEncode({
        'schemaVersion': e['schemaVersion'],
        'uid': e['uid'],
        'generation': e['generation'],
        'createdAt': e['createdAt'],
      });
  Future<void> save(
      Map<String, Map<String, Object?>> documents, int generation) async {
    final owner = uid();
    if (owner == null || !authorized())
      throw StateError('CACHE_NOT_AUTHORIZED');
    final envelope = <String, dynamic>{
      'schemaVersion': 1,
      'uid': owner,
      'generation': generation,
      'createdAt': DateTime.now().toUtc().toIso8601String()
    };
    final sealed = await cipher.seal(owner, _metadata(envelope),
        Uint8List.fromList(utf8.encode(jsonEncode(documents))));
    if (owner != uid() || !authorized())
      throw StateError('CACHE_OWNER_CHANGED');
    envelope.addAll({
      'nonce': base64Encode(sealed.sublist(0, 12)),
      'ciphertext': base64Encode(sealed.sublist(12, sealed.length - 16)),
      'authenticationTag': base64Encode(sealed.sublist(sealed.length - 16))
    });
    if (!await preferences.setString(_key(owner), jsonEncode(envelope)))
      throw StateError('CACHE_WRITE_FAILED');
  }

  Future<Map<String, Map<String, Object?>>> restore() async {
    final owner = uid();
    if (owner == null || !authorized()) return {};
    try {
      final raw = preferences.getString(_key(owner));
      if (raw == null) return {};
      final e = jsonDecode(raw) as Map<String, dynamic>;
      if (e['schemaVersion'] != 1 ||
          e['uid'] != owner ||
          e['generation'] is! int ||
          e['generation'] < 0 ||
          DateTime.tryParse(e['createdAt'] as String) == null) return {};
      final nonce = base64Decode(e['nonce'] as String),
          tag = base64Decode(e['authenticationTag'] as String);
      if (nonce.length != 12 || tag.length != 16) return {};
      final clear = await cipher.open(
          owner,
          _metadata(e),
          Uint8List.fromList(
              [...nonce, ...base64Decode(e['ciphertext'] as String), ...tag]));
      if (owner != uid() || !authorized()) return {};
      final decoded = jsonDecode(utf8.decode(clear)) as Map;
      return {
        for (final entry in decoded.entries)
          entry.key as String: Map<String, Object?>.from(entry.value as Map)
      };
    } catch (_) {
      return {};
    }
  }
}
