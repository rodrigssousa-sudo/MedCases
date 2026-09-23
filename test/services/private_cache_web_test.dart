@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/canonical_catalog_cipher_web.dart';
import 'package:medcases/services/secure_session_store_web.dart';

void main() {
  test(
      'private UID WebCrypto namespace: random nonce, restart, wrong AAD, missing key, logout',
      () async {
    String? uid = 'private-${DateTime.now().microsecondsSinceEpoch}';
    final owner = uid;
    WebCanonicalCatalogCipher cipher() => WebCanonicalCatalogCipher(
        currentUid: () => uid,
        authorized: () => uid != null,
        databaseName: 'medcases.private.keys.v1');
    final clear = Uint8List.fromList(utf8.encode('synthetic private history'));
    final one = await cipher().seal(owner, 'history-v1', clear),
        two = await cipher().seal(owner, 'history-v1', clear);
    expect(one, isNot(two));
    expect(await cipher().open(owner, 'history-v1', one), clear);
    final corrupt = Uint8List.fromList(one);
    corrupt[12] ^= 1;
    await expectLater(
        cipher().open(owner, 'history-v1', corrupt), throwsA(anything));
    await expectLater(
        cipher().open(owner, 'history-v2', one), throwsA(anything));
    uid = 'missing-${DateTime.now().microsecondsSinceEpoch}';
    await expectLater(cipher().open(uid, 'history-v1', one), throwsA(anything));
    await expectLater(
        cipher().open(owner, 'history-v1', one), throwsA(anything));
    uid = null;
    await expectLater(
        cipher().open(owner, 'history-v1', one), throwsA(anything));
  });
  test('browser credential record is tab-session scoped and clearable',
      () async {
    await SecureSessionStore.clear();
    expect(await SecureSessionStore.read(), isNull);
    await SecureSessionStore.write(
        {'uid': 'synthetic', 'refreshToken': 'fixture-only', 'userJson': '{}'});
    expect((await SecureSessionStore.read())?['uid'], 'synthetic');
    await SecureSessionStore.clear();
    expect(await SecureSessionStore.read(), isNull);
  });
}
