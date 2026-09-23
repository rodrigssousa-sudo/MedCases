import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/models/user_model.dart';
import 'package:medcases/services/firestore_service.dart';
import 'package:medcases/services/private_user_cache.dart';
import 'package:medcases/services/canonical_catalog_cipher.dart';

class RealTestCipher implements CanonicalCatalogCipher {
  final aes = AesGcm.with256bits();
  final keys = <String, SecretKey>{};
  @override
  Future<Uint8List> seal(String uid, String aad, Uint8List data) async {
    final key = keys[uid] ??= await aes.newSecretKey();
    final box = await aes.encrypt(data, secretKey: key, aad: utf8.encode(aad));
    return Uint8List.fromList(
        [...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  @override
  Future<Uint8List> open(String uid, String aad, Uint8List data) async {
    final key = keys[uid];
    if (key == null) throw StateError('MISSING_KEY');
    return Uint8List.fromList(await aes.decrypt(
        SecretBox(data.sublist(12, data.length - 16),
            nonce: data.sublist(0, 12),
            mac: Mac(data.sublist(data.length - 16))),
        secretKey: key,
        aad: utf8.encode(aad)));
  }
}

class DelayedProvider extends AppProvider {
  @override
  bool get hasAuthenticatedAiSession => false;
  @override
  Future<void> loadPublicHistories({bool forceRemote = false}) async {}
  final pending = Completer<FirestoreLoadResult<List<Map<String, dynamic>>>>();
  @override
  Future<FirestoreLoadResult<List<Map<String, dynamic>>>> fetchAiSessions(
          String uid) =>
      pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'authenticated owner migration commits ciphertext before removing legacy; no B access',
      () async {
    SharedPreferences.setMockInitialValues(
        {'A_myHistories': '[{"synthetic":"private A"}]'});
    String? uid = 'A';
    final cipher = RealTestCipher();
    final cache = PrivateUserCache(cipher: cipher, uid: () => uid);
    final prefs = await SharedPreferences.getInstance();
    expect(await cache.read('A', 'myHistories'), '[{"synthetic":"private A"}]');
    expect(prefs.containsKey('A_myHistories'), false);
    final key = prefs.getKeys().single;
    expect(prefs.getString(key), isNot(contains('private A')));
    final first = prefs.getString(key);
    await cache.write('A', 'myHistories', '[{"synthetic":"private A"}]');
    expect(prefs.getString(key), isNot(first));
    uid = 'B';
    await expectLater(cache.read('A', 'myHistories'), throwsStateError);
    expect(await cache.read('B', 'myHistories'), isNull);
    uid = null;
    await expectLater(cache.read('A', 'myHistories'), throwsStateError);
    uid = 'A';
    expect(await cache.read('A', 'myHistories'), contains('private A'));
    final envelope = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    final bytes = base64Decode(envelope['ciphertext'] as String);
    bytes[12] ^= 1;
    envelope['ciphertext'] = base64Encode(bytes);
    await prefs.setString(key, jsonEncode(envelope));
    await expectLater(cache.read('A', 'myHistories'), throwsA(anything));
  });
  test('missing key rejects without destroying encrypted history', () async {
    SharedPreferences.setMockInitialValues({});
    final cipher = RealTestCipher();
    final cache = PrivateUserCache(cipher: cipher, uid: () => 'A');
    await cache.write('A', 'myHistories', 'private');
    cipher.keys.clear();
    await expectLater(cache.read('A', 'myHistories'), throwsStateError);
    expect((await SharedPreferences.getInstance()).getKeys().length, 1);
  });
  test('wrong owner cannot migrate plaintext', () async {
    SharedPreferences.setMockInitialValues({'A_myHistories': 'private'});
    final cache = PrivateUserCache(cipher: RealTestCipher(), uid: () => 'B');
    await expectLater(cache.read('A', 'myHistories'), throwsStateError);
    expect((await SharedPreferences.getInstance()).getString('A_myHistories'),
        'private');
  });
  test(
      'real provider invalidates both original and reused AI loads on logout and switch',
      () async {
    SharedPreferences.setMockInitialValues({});
    final p = DelayedProvider();
    await p
        .setUser(UserModel(
            uid: 'A',
            email: 'synthetic-a@example.invalid',
            displayName: 'fixture',
            createdAt: DateTime.utc(2026)))
        .catchError((_) {});
    final first = p.loadAiSessionsTypedForUi('A'),
        reuse = p.loadAiSessionsTypedForUi('A');
    final initial = p.sessionEpoch;
    p.clearUser();
    expect(p.sessionEpoch, greaterThan(initial));
    final setup = p
        .setUser(UserModel(
            uid: 'B',
            email: 'synthetic@example.invalid',
            displayName: 'fixture',
            createdAt: DateTime.utc(2026)))
        .catchError((_) {});
    p.pending.complete(FirestoreLoadResult.success([
      {'id': 'private A'}
    ]));
    for (final result in await Future.wait([first, reuse])) {
      expect(result.runtimeType.toString(), contains('UiLoadDiscarded'));
      expect((result as dynamic).reason, 'STALE_USER_OPERATION');
    }
    expect(p.currentUser?.uid, 'B');
    expect(p.myHistories, isEmpty);
    await setup;
    p.clearUser();
    p.dispose();
  });
}
