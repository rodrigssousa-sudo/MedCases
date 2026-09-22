import '../support/catalog_test_cipher.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/monthly_usage_ledger.dart';
import 'package:medcases/services/offline_entitlement_lease.dart';
import 'package:medcases/services/canonical_drug_library.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/calculator_mcc1_bridge_service.dart';
import 'package:medcases/services/free_drug_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'ledger exact minutes, reservations, duplicate completion, cancel, failure, restart, UID and rollover',
      () async {
    String? uid = 'A';
    var now = DateTime.utc(2026, 9, 21);
    var limits = EntitlementLimits.free;
    MonthlyUsageLedger ledger() => MonthlyUsageLedger(
        uid: () => uid,
        now: () => now,
        limits: () => limits,
        preferences: SharedPreferences.getInstance);
    final a = await ledger().begin(
        operationId: '14', kinds: {UsageKind.recording}, maximumMs: 14 * 60000);
    await a.finish(actualMs: 14 * 60000, success: true);
    final b = await ledger().begin(
        operationId: '1', kinds: {UsageKind.recording}, maximumMs: 60000);
    await b.finish(actualMs: 60000, success: true);
    await b.finish(actualMs: 60000, success: true);
    await expectLater(
        ledger().begin(
            operationId: 'over', kinds: {UsageKind.recording}, maximumMs: 1),
        throwsStateError);
    uid = 'B';
    final c = await ledger().begin(
        operationId: 'cancel',
        kinds: {UsageKind.recording},
        maximumMs: 15 * 60000);
    await c.finish(actualMs: 0, success: false);
    final d = await ledger().begin(
        operationId: 'ok', kinds: {UsageKind.recording}, maximumMs: 15 * 60000);
    await d.finish(actualMs: 15 * 60000, success: true);
    uid = null;
    await expectLater(
        ledger().begin(
            operationId: 'logout', kinds: {UsageKind.recording}, maximumMs: 1),
        throwsStateError);
    uid = 'A';
    now = DateTime.utc(2026, 10, 1);
    final e = await ledger().begin(
        operationId: 'newmonth',
        kinds: {UsageKind.recording},
        maximumMs: 60000);
    await e.finish(actualMs: 0, success: false);
    final fail = await ledger().begin(
        operationId: 'failedtranscript',
        kinds: {UsageKind.transcription},
        maximumMs: 30 * 60000);
    await fail.finish(actualMs: 0, success: false);
    final retry = await ledger().begin(
        operationId: 'failedtranscript',
        kinds: {UsageKind.transcription},
        maximumMs: 30 * 60000);
    await fail.finish(actualMs: 0, success: false);
    await retry.finish(actualMs: 30 * 60000, success: true);
    await expectLater(
        ledger().begin(
            operationId: 'trans-over',
            kinds: {UsageKind.transcription},
            maximumMs: 1),
        throwsStateError);
    uid = 'premium';
    limits = EntitlementLimits.premium;
    final paid = await ledger().begin(
        operationId: 'paid',
        kinds: {UsageKind.recording},
        maximumMs: 240 * 60000);
    await paid.finish(actualMs: 240 * 60000, success: true);
    await expectLater(
        ledger().begin(
            operationId: 'overpaid',
            kinds: {UsageKind.recording},
            maximumMs: 1),
        throwsStateError);
    final transcription = await ledger().begin(
        operationId: 'paid-trans',
        kinds: {UsageKind.transcription},
        maximumMs: 90 * 60000);
    await transcription.finish(actualMs: 90 * 60000, success: true);
  });
  test('parallel reservations cannot overspend', () async {
    final ledger = MonthlyUsageLedger(
        uid: () => 'A',
        now: () => DateTime.utc(2026, 9),
        limits: () => EntitlementLimits.free,
        preferences: SharedPreferences.getInstance);
    final results = await Future.wait(List.generate(
        20,
        (i) => ledger
            .begin(
                operationId: '$i',
                kinds: {UsageKind.recording},
                maximumMs: 60000)
            .then((_) => true)
            .catchError((Object _) => false)));
    expect(results.where((x) => x).length, 15);
  });
  test('signed offline trial/paid restart, expiry, corruption, UID and logout',
      () async {
    final algo = Ed25519();
    final key = await algo.newKeyPair();
    final pub = base64.encode((await key.extractPublicKey()).bytes);
    String? uid = 'A';
    var now = DateTime.utc(2026, 9, 21);
    final epoch = now.millisecondsSinceEpoch ~/ 1000;
    final bytes = utf8.encode(jsonEncode({
      'v': 1,
      'aud': 'medcases-offline',
      'sub': 'A',
      'tier': 'premium',
      'iat': epoch,
      'exp': epoch + 300
    }));
    final signature = await algo.sign(bytes, keyPair: key);
    final signed =
        '${base64Url.encode(bytes)}.${base64Url.encode(signature.bytes)}';
    OfflineEntitlementLease store() =>
        OfflineEntitlementLease(publicKey: pub, uid: () => uid, now: () => now);
    await store().save(signed);
    expect((await store().restore())?['tier'], 'premium');
    final sovereign = EntitlementService.forTesting(
        uid: () => uid,
        clock: () => now,
        offlineLease: store(),
        sessionLoader: (_) async => throw StateError('unused'));
    addTearDown(sovereign.dispose);
    expect(await sovereign.restoreOfflineEntitlement(), true);
    expect(sovereign.canUse(MedCasesCapability.drugsFullLibrary), true);
    uid = 'B';
    expect(sovereign.canUse(MedCasesCapability.drugsFullLibrary), false);
    uid = 'A';

    uid = 'B';
    expect(await store().restore(), isNull);
    uid = 'A';
    now = now.add(const Duration(minutes: 5));
    expect(await store().restore(), isNull);
    now = now.subtract(const Duration(minutes: 5));
    await store().save('$signed-corrupt');
    expect(await store().restore(), isNull);
    await store().save(signed);
    await store().clear();
    expect(await store().restore(), isNull);
  });
  test(
      'real canonical inventory full/Free60, exact lookup, cache restart, revocation and access recheck',
      () async {
    final root = Directory(
        '/private/tmp/medcases-calculadora-r1-canonical-20260921/data/drugs');
    final docs = <String, Map<String, Object?>>{};
    for (final f in root
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      final doc =
          Map<String, Object?>.from(jsonDecode(f.readAsStringSync()) as Map);
      docs[doc['id'] as String] = doc;
    }
    var premium = true;
    var offline = false;
    final now = DateTime.now().toUtc();
    final ent = EntitlementService.forTesting(
        uid: () => 'A',
        clock: () => now,
        sessionLoader: (_) async => CalculatorMcc1Session(
            token: 'fixture',
            tier: premium ? 'premium' : 'free',
            capabilities: const [],
            expiresAtUtc: now.add(const Duration(minutes: 5)),
            entitlementSource: 'fixture'));
    addTearDown(ent.dispose);
    await ent.refreshAuthoritativeTier();
    final prefs = await SharedPreferences.getInstance();
    final cipher = CatalogTestCipher();
    CanonicalDrugLibrary repo() => CanonicalDrugLibrary(
        entitlement: ent,
        cipher: cipher,
        preferences: prefs,
        loadIndex: () async {
          if (offline) throw const SocketException('offline');
          return {
            for (final e in docs.entries)
              e.key: {'id': e.key, 'name': e.value['name']}
          };
        },
        loadDocument: (id) async {
          if (offline) throw const SocketException('offline');
          return docs[id];
        });
    final library = repo();
    await library.prepareOffline();
    expect(library.index.length, docs.length);
    expect(library.index.keys.toSet().containsAll(freeDrugCanonicalIds), true);
    final id = docs.keys.firstWhere((id) => !freeDrugCanonicalIds.contains(id));
    final discovery = library.discovery('pt');
    expect(discovery.length, library.index.length);
    expect(discovery.map((d) => d.id).toSet(), library.index.keys.toSet());
    for (final drug in discovery) {
      expect(drug.fixedDose, isNull);
      expect(drug.mgKg, isNull);
      expect(drug.mechanism, isNull);
      expect(drug.interactions, isNull);
    }
    await library.lookup(id);
    offline = true;
    final restarted = repo();
    await restarted.restore();
    expect((await restarted.lookup(id))?['id'], id);
    for (final canonicalId in docs.keys) {
      expect((await restarted.lookup(canonicalId))?['id'], canonicalId);
    }
    premium = false;
    await ent.refreshAuthoritativeTier(force: true);
    expect(restarted.allowed(id), false);
    expect(restarted.index.keys.where(restarted.allowed).toSet(),
        freeDrugCanonicalIds);
    await expectLater(restarted.lookup(id), throwsStateError);
    premium = true;
    await ent.refreshAuthoritativeTier(force: true);
    offline = false;
    docs.remove(id);
    await restarted.refresh();
    offline = true;
    final revoked = repo();
    await revoked.restore();
    expect(revoked.index.containsKey(id), false);
    await expectLater(revoked.lookup(id), throwsStateError);
  });
}
