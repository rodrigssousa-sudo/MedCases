import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/offline_entitlement_lease.dart';

void main() {
  test(
      'client accepts at most 24h; expired, future, wrong UID, invalid signatures fail closed',
      () async {
    final algorithm = Ed25519();
    final pair = await algorithm.newKeyPair();
    final public = await pair.extractPublicKey();
    final now = DateTime.utc(2026, 9, 21);
    final epoch = now.millisecondsSinceEpoch ~/ 1000;
    final verifier = OfflineEntitlementLease(
        publicKey: base64Encode(public.bytes), uid: () => 'A', now: () => now);
    Future<String> sign(int seconds, {String uid = 'A', int start = 0}) async {
      final payload = utf8.encode(jsonEncode({
        'v': 1,
        'aud': 'medcases-offline',
        'sub': uid,
        'tier': 'premium',
        'iat': epoch + start,
        'exp': epoch + start + seconds
      }));
      final signature = await algorithm.sign(payload, keyPair: pair);
      return '${base64UrlEncode(payload)}.${base64UrlEncode(signature.bytes)}';
    }

    expect(await verifier.verify(await sign(86400)), isNotNull);
    expect(await verifier.verify(await sign(7200)), isNotNull);
    for (final duration in [86401, 0, -1])
      expect(await verifier.verify(await sign(duration)), isNull);
    expect(await verifier.verify(await sign(86400, uid: 'B')), isNull);
    expect(await verifier.verify(await sign(10, start: 1)), isNull);
    expect(await verifier.verify('${await sign(86400)}bad'), isNull);
  });
}
