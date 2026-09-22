@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/canonical_catalog_cipher_web.dart';

void main() {
  test(
      'real browser IndexedDB non-extractable AES key survives cipher restart; tamper and missing owner key fail',
      () async {
    final uid = 'test-${DateTime.now().microsecondsSinceEpoch}';
    final cipher = WebCanonicalCatalogCipher(
        currentUid: () => uid, authorized: () => true);
    final clear = Uint8List.fromList(utf8.encode('private fixture'));
    final sealed = await cipher.seal(uid, 'metadata', clear);
    expect(
        await WebCanonicalCatalogCipher(
            currentUid: () => uid,
            authorized: () => true).open(uid, 'metadata', sealed),
        clear);
    await expectLater(
        cipher.open('$uid-other', 'metadata', sealed), throwsA(anything));
    await expectLater(
        cipher.open(uid, 'other metadata', sealed), throwsA(anything));
    for (final offset in [0, 12, sealed.length - 1]) {
      final corrupt = Uint8List.fromList(sealed);
      corrupt[offset] ^= 1;
      await expectLater(
          cipher.open(uid, 'metadata', corrupt), throwsA(anything));
    }
  });
}
