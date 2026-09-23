import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/private_user_cache.dart';
import 'package:medcases/services/plantao_knowledge/private_knowledge_snapshot_store.dart';
import '../support/catalog_test_cipher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'snapshot adapter encrypts payload, persists restart, enforces UID and monotonic revocations',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var uid = 'A';
    final cipher = CatalogTestCipher();
    final cache = PrivateUserCache(
        cipher: cipher, uid: () => uid, preferences: () async => prefs);
    final store = PrivateKnowledgeSnapshotStore('A', cache: cache);
    Map<String, dynamic> snapshot(int seq, {bool revoked = false}) => {
          'manifest': {'sequence': seq},
          'items': {
            'therapeuticProtocols': {
              'TEST': {
                'canonicalId': 'TEST',
                'publicationStatus': revoked ? 'REVOKED' : 'PRODUCTION',
                'payload': {'text': 'PRIVATE_TEST_ONLY'}
              }
            }
          }
        };
    await store.activate(snapshot(1));
    expect(prefs.getKeys().map(prefs.getString).join(),
        isNot(contains('PRIVATE_TEST_ONLY')));
    expect(
        (await PrivateKnowledgeSnapshotStore('A', cache: cache)
            .read())!['manifest']['sequence'],
        1);
    await store.activate(snapshot(2, revoked: true));
    expect((await store.read())!['revocationFloor'],
        ['therapeuticProtocols/TEST']);
    await expectLater(store.activate(snapshot(1)), throwsA(anything));
    uid = 'B';
    await expectLater(store.read(), throwsStateError);
    uid = 'A';
    final journal =
        jsonDecode((await cache.read('A', 'clinical_knowledge_snapshot_v1'))!)
            as Map<String, dynamic>;
    journal['active']['hash'] = 'BAD_HASH';
    await cache.write(
        'A', 'clinical_knowledge_snapshot_v1', jsonEncode(journal));
    final recovered = (await store.read())!;
    expect(recovered['recoveredPrevious'], isTrue);
    expect(recovered['sequenceFloor'], 2);
    expect(recovered['revocationFloor'], ['therapeuticProtocols/TEST']);
    expect(recovered['manifest']['sequence'], 1);
  });
}
