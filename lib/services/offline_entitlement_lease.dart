import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server-signed access evidence, not billing metadata or clinical authority.
class OfflineEntitlementLease {
  OfflineEntitlementLease(
      {required this.publicKey, required this.uid, required this.now});
  final String publicKey;
  final String? Function() uid;
  final DateTime Function() now;
  Future<void> _writes = Future.value();
  int _generation = 0;
  static const maximumLeaseSeconds = 86400;
  static const _key = 'medcases.offline.entitlement.v1';

  Future<Map<String, dynamic>?> verify(String? envelope) async {
    if (envelope == null || publicKey.isEmpty || uid() == null) return null;
    try {
      final parts = envelope.split('.');
      if (parts.length != 2) return null;
      final payload = base64Url.decode(base64Url.normalize(parts[0]));
      final signature = Signature(
          base64Url.decode(base64Url.normalize(parts[1])),
          publicKey: SimplePublicKey(base64.decode(publicKey),
              type: KeyPairType.ed25519));
      if (!await Ed25519().verify(payload, signature: signature)) return null;
      final data = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      final time = now().toUtc().millisecondsSinceEpoch ~/ 1000;
      if (data['v'] != 1 ||
          data['aud'] != 'medcases-offline' ||
          data['sub'] != uid() ||
          !['free', 'premium'].contains(data['tier']) ||
          data['iat'] is! int ||
          data['exp'] is! int ||
          data['iat'] > time ||
          data['exp'] <= time ||
          data['exp'] <= data['iat'] ||
          data['exp'] - data['iat'] > maximumLeaseSeconds) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> restore() async {
    try {
      await _writes;
      final prefs = await SharedPreferences.getInstance();
      return await verify(prefs.getString(_key));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String? envelope) {
    final generation = _generation;
    final owner = uid();
    final operation = _writes.then((_) async {
      if (generation != _generation || owner != uid()) return;
      final data = await verify(envelope);
      if (generation != _generation || owner != uid()) return;
      final prefs = await SharedPreferences.getInstance();
      if (data == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, envelope!);
      }
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> clear() {
    _generation++;
    final operation = _writes.then(
        (_) async => (await SharedPreferences.getInstance()).remove(_key));
    _writes = operation.then<void>((_) {}).catchError((Object _) {});
    return _writes;
  }
}
