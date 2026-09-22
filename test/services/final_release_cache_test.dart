import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/canonical_secure_cache.dart';
import 'package:medcases/services/canonical_free_discovery.dart';
import 'package:medcases/services/free_drug_catalog.dart';
import '../support/catalog_test_cipher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Premium restart decrypts; Free, B, expired and logout cannot read',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final cipher = CatalogTestCipher();
    String? uid = 'A';
    var premium = true;
    CanonicalSecureCache cache() => CanonicalSecureCache(
        preferences: prefs,
        cipher: cipher,
        uid: () => uid,
        authorized: () => premium);
    await cache().save({
      'premium_test': {'id': 'premium_test', 'text': 'CONFIDENTIAL_TEST_VALUE'}
    }, 1);
    expect(prefs.getKeys().map(prefs.getString).join(),
        isNot(contains('CONFIDENTIAL_TEST_VALUE')));
    expect((await cache().restore()).keys, ['premium_test']);
    premium = false;
    expect(await cache().restore(), isEmpty);
    premium = true;
    uid = 'B';
    expect(await cache().restore(), isEmpty);
    uid = null;
    expect(await cache().restore(), isEmpty);
    uid = 'A';
    expect((await cache().restore()).keys, ['premium_test']);
    cipher.keys.clear();
    expect(await cache().restore(), isEmpty);
  });
  for (final field in [
    'ciphertext',
    'nonce',
    'authenticationTag',
    'uid',
    'generation',
    'schemaVersion',
    'createdAt'
  ]) {
    test('cache rejects altered $field', () async {
      final prefs = await SharedPreferences.getInstance();
      final cache = CanonicalSecureCache(
          preferences: prefs,
          cipher: CatalogTestCipher(),
          uid: () => 'A',
          authorized: () => true);
      await cache.save({
        'premium_test': {'id': 'premium_test'}
      }, 1);
      final key = prefs.getKeys().single;
      final data = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      if (['ciphertext', 'nonce', 'authenticationTag'].contains(field)) {
        final bytes = base64Decode(data[field] as String);
        bytes[0] ^= 1;
        data[field] = base64Encode(bytes);
      } else {
        data[field] =
            field == 'generation' || field == 'schemaVersion' ? 2 : 'different';
      }
      await prefs.setString(key, jsonEncode(data));
      expect(await cache.restore(), isEmpty);
    });
  }
  test(
      'fresh Free identity index is exact Free60 and contains no clinical fields',
      () {
    expect(canonicalFreeDiscovery.keys.toSet(), freeDrugCanonicalIds);
    expect(canonicalFreeDiscovery.length, 60);
    for (final e in canonicalFreeDiscovery.entries) {
      expect(e.value.keys.toSet(), {'id', 'name'});
      expect(e.value['id'], e.key);
      final names = e.value['name'] as Map;
      expect(names.keys.toSet(), {'pt', 'es'});
      expect(names.values.every((v) => v is String && v.isNotEmpty), true);
    }
  });
}
