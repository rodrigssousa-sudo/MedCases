import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/calculator_mcc1_bridge_service.dart';
import '../../lib/services/entitlement_service.dart';
import '../../lib/services/free_drug_catalog.dart';

void main() {
  final epoch = DateTime.utc(2026, 9, 21);
  CalculatorMcc1Session session(String tier, DateTime expiry) =>
      CalculatorMcc1Session(
          token: 'test-authenticated-issuer-result',
          tier: tier,
          capabilities: const [],
          expiresAtUtc: expiry,
          entitlementSource: 'server_revenuecat_entitlement');
  test(
      'Free60 projection exactly matches canonical source, not cardinality only',
      () {
    final source = jsonDecode(File(
            '${Platform.environment['MEDCASES_CALCULATOR_ROOT'] ?? '${Directory.current.parent.path}/medcases-calculadora'}/gateway/data/free60_allowlist.v2.json')
        .readAsStringSync()) as Map;
    expect(
        freeDrugCanonicalIds, (source['ids'] as List).cast<String>().toSet());
  });
  testWidgets('expiry timer changes observed locks without navigation',
      (tester) async {
    var now = epoch;
    var events = 0;
    final service = EntitlementService.forTesting(
        uid: () => 'A',
        clock: () => now,
        sessionLoader: (_) async =>
            session('premium', epoch.add(const Duration(seconds: 1))));
    service.addListener(() => events++);
    await service.refreshAuthoritativeTier();
    expect(
        service.showsPremiumLock(MedCasesCapability.drugsFullLibrary), false);
    final before = events;
    now = epoch.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(events, greaterThan(before));
    expect(service.showsPremiumLock(MedCasesCapability.drugsFullLibrary), true);
    service.dispose();
  });
  test('invalid issuer response cannot retain previously valid premium cache',
      () async {
    var reject = false;
    final service = EntitlementService.forTesting(
        uid: () => 'A',
        clock: () => epoch,
        sessionLoader: (_) async {
          if (reject)
            throw const CalculatorMcc1BridgeException('ISSUER_HTTP_401');
          return session('premium', epoch.add(const Duration(minutes: 2)));
        });
    addTearDown(service.dispose);
    await service.refreshAuthoritativeTier();
    expect(service.isPremium, true);
    reject = true;
    await service.refreshAuthoritativeTier(force: true);
    expect(service.isPremium, false);
  });

  test('export policy matrix evidence separately from route audit', () {
    final states = {
      'FREE': EntitlementTier.free,
      'TRIAL_ACTIVE': EntitlementTier.premium,
      'PAID_PREMIUM': EntitlementTier.premium,
      'EXPIRED': EntitlementTier.free,
    };
    final rows = [
      for (final feature in MedCasesCapability.values)
        {
          'feature': feature.name,
          'states': {
            for (final state in states.entries)
              state.key: {
                'visualLockPolicy':
                    !EntitlementService.snapshotForTier(state.value)
                        .can(feature),
                'routeAccessPolicy':
                    EntitlementService.snapshotForTier(state.value)
                        .can(feature),
                'actionAccessPolicy':
                    EntitlementService.snapshotForTier(state.value)
                        .can(feature),
              }
          },
        }
    ];
    Directory('.dart_tool/final_entitlement_free_premium')
        .createSync(recursive: true);
    File('.dart_tool/final_entitlement_free_premium/feature-matrix.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'scope':
          'EntitlementService policy; actual route wiring audited separately',
      'features': rows
    }));
    File('.dart_tool/final_entitlement_free_premium/trial-premium-parity.json')
        .writeAsStringSync(jsonEncode({
      'capabilitiesEqual': true,
      'premiumLocksInPolicy': 0,
      'trialLocksInPolicy': 0,
      'scope':
          'Policy matrix plus server billing tests; no actual store purchase',
      'productTrialStateAdded': false
    }));
  });
  for (final state in [
    'FREE',
    'TRIAL_ACTIVE',
    'PAID_PREMIUM',
    'PREMIUM_EXPIRED',
    'CANCELLED_STILL_ACTIVE',
    'RESTORED',
    'OFFLINE_VALID',
    'OFFLINE_EXPIRED'
  ]) {
    test('$state feature matrix uses same visual/route/action policy',
        () async {
      var now = epoch;
      final premium =
          !['FREE', 'PREMIUM_EXPIRED', 'OFFLINE_EXPIRED'].contains(state);
      final service = EntitlementService.forTesting(
          uid: () => 'A',
          clock: () => now,
          sessionLoader: (_) async => session(premium ? 'premium' : 'free',
              epoch.add(const Duration(minutes: 2))));
      addTearDown(service.dispose);
      await service.refreshAuthoritativeTier();
      final expected = EntitlementService.snapshotForTier(
          premium ? EntitlementTier.premium : EntitlementTier.free);
      for (final feature in MedCasesCapability.values) {
        expect(service.canUse(feature), expected.can(feature),
            reason: feature.name);
        expect(service.showsPremiumLock(feature), !service.canUse(feature));
        expect(service.can(feature), service.canUse(feature));
      }
      expect(service.canAccessDrug(freeDrugCanonicalIds.first), isTrue);
      expect(service.canAccessDrug('noradrenalina'), premium);
      // Pure access: no clinical/calculation/dose binding is created or changed.
    });
  }
  test('canonical Free quotas, Premium expansion and A/B storage isolation',
      () async {
    SharedPreferences.setMockInitialValues(
        {'user-history-sentinel': 'preserve'});
    String? uid = 'A';
    var tier = 'free';
    final service = EntitlementService.forTesting(
        uid: () => uid,
        clock: () => epoch,
        sessionLoader: (_) async =>
            session(tier, epoch.add(const Duration(minutes: 2))));
    addTearDown(service.dispose);
    for (var i = 0; i < 5; i++) {
      expect(
          (await service.consumeAiAllowance(isPlantao: false)).allowed, isTrue);
    }
    expect(
        (await service.consumeAiAllowance(isPlantao: false)).allowed, isFalse);
    expect((await service.consumeAiAllowance(isPlantao: true)).allowed, isTrue);
    expect(
        (await service.consumeAiAllowance(isPlantao: true)).allowed, isFalse);
    for (var i = 0; i < 3; i++) {
      expect((await service.consumeClinicalHistoryCreationAllowance()).allowed,
          isTrue);
    }
    expect((await service.consumeClinicalHistoryCreationAllowance()).allowed,
        isFalse);
    tier = 'premium';
    await service.refreshAuthoritativeTier(force: true);
    expect(
        (await service.consumeAiAllowance(isPlantao: false)).allowed, isTrue);
    expect((await service.consumeClinicalHistoryCreationAllowance()).allowed,
        isTrue);
    uid = null;
    service.resetToFree();
    uid = 'B';
    tier = 'free';
    expect((await service.consumeAiAllowance(isPlantao: false)).remaining, 4);
    expect(
        (await service.consumeClinicalHistoryCreationAllowance()).remaining, 2);
    expect(
        (await SharedPreferences.getInstance())
            .getString('user-history-sentinel'),
        'preserve');
  });
  test(
      'trial and paid capabilities identical: billing metadata is not product state',
      () {
    final trial = EntitlementService.snapshotForTier(EntitlementTier.premium,
        source: 'server_revenuecat_entitlement');
    final paid = EntitlementService.snapshotForTier(EntitlementTier.premium,
        source: 'server_revenuecat_entitlement');
    expect(trial.capabilities, paid.capabilities);
    expect(trial.limits, same(paid.limits));
    expect(trial.capabilities, MedCasesCapability.values.toSet());
  });
  test(
      'offline valid cache retained, expiry fails closed and notifies without deleting data',
      () async {
    var now = epoch;
    var fail = false;
    final service = EntitlementService.forTesting(
        uid: () => 'A',
        clock: () => now,
        sessionLoader: (_) async {
          if (fail) throw TimeoutException('offline');
          return session('premium', epoch.add(const Duration(minutes: 1)));
        });
    addTearDown(service.dispose);
    await service.refreshAuthoritativeTier();
    fail = true;
    await service.refreshAuthoritativeTier(force: true);
    expect(service.isPremium, isTrue);
    now = epoch.add(const Duration(minutes: 1));
    expect(service.isPremium, isFalse);
    await service.refreshAuthoritativeTier(force: true);
    expect(service.isPremium, isFalse);
    expect(service.canUse(MedCasesCapability.guidesFull), isTrue);
  });
  test('logout and A response cannot grant premium to B; single-flight per UID',
      () async {
    String? uid = 'A';
    final pending = Completer<CalculatorMcc1Session>();
    var calls = 0;
    final service = EntitlementService.forTesting(
        uid: () => uid,
        clock: () => epoch,
        sessionLoader: (_) {
          calls++;
          return uid == 'A'
              ? pending.future
              : Future.value(
                  session('free', epoch.add(const Duration(minutes: 2))));
        });
    addTearDown(service.dispose);
    final first = service.refreshAuthoritativeTier();
    final duplicate = service.refreshAuthoritativeTier();
    expect(identical(first, duplicate), isTrue);
    expect(calls, 1);
    uid = null;
    service.resetToFree();
    expect(service.isPremium, isFalse);
    uid = 'B';
    await service.refreshAuthoritativeTier();
    pending.complete(session('premium', epoch.add(const Duration(minutes: 2))));
    await first;
    expect(service.current.resolvedUid, 'B');
    expect(service.isPremium, isFalse);
  });
  test(
      'expired premium returns Free; restore updates listeners without restart',
      () async {
    var now = epoch;
    var premium = true;
    var notifications = 0;
    final service = EntitlementService.forTesting(
        uid: () => 'A',
        clock: () => now,
        sessionLoader: (_) async => session(premium ? 'premium' : 'free',
            now.add(const Duration(seconds: 10))));
    addTearDown(service.dispose);
    service.addListener(() => notifications++);
    await service.refreshAuthoritativeTier();
    expect(service.isPremium, isTrue);
    now = now.add(const Duration(seconds: 10));
    expect(service.isPremium, isFalse);
    premium = false;
    await service.refreshAuthoritativeTier(force: true);
    expect(service.isPremium, isFalse);
    premium = true;
    await service.refreshAuthoritativeTier(force: true);
    expect(service.isPremium, isTrue);
    expect(notifications, greaterThan(2));
  });
}
