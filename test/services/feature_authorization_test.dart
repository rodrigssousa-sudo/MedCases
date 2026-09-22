import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/medcases_feature_authorization.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/calculator_mcc1_bridge_service.dart';

void main() {
  final rows = <Map<String, Object?>>[];
  final now = DateTime.utc(2026, 9, 21);
  for (final entrypoint in FeatureEntryPoint.values) {
    for (final state in ['FREE', 'TRIAL_ACTIVE', 'PAID_PREMIUM', 'EXPIRED']) {
      test('${entrypoint.name} $state facade denies before read/action',
          () async {
        final allowed = state == 'TRIAL_ACTIVE' || state == 'PAID_PREMIUM';
        final service = EntitlementService.forTesting(
          uid: () => 'A',
          clock: () => now,
          sessionLoader: (_) async => CalculatorMcc1Session(
            token: 'fixture-verified-session',
            tier: state == 'FREE' ? 'free' : 'premium',
            capabilities: const [],
            expiresAtUtc:
                now.add(Duration(minutes: state == 'EXPIRED' ? -1 : 5)),
            entitlementSource: state,
          ),
        );
        addTearDown(service.dispose);
        final facade = MedCasesFeatureAuthorization(service);
        var reads = 0, actions = 0, routes = 0, paywalls = 0;
        const target =
            FeatureTarget.capability(MedCasesCapability.drugsWeightDose);
        final result = await facade.execute(
          target,
          entrypoint: entrypoint,
          presentPaywall: () async {
            paywalls++;
          },
          action: () async {
            routes++;
            reads++;
            actions++;
            return 'payload';
          },
        );
        expect(result, allowed ? 'payload' : null);
        expect(reads, allowed ? 1 : 0);
        expect(actions, allowed ? 1 : 0);
        expect(routes, allowed ? 1 : 0);
        expect(paywalls, allowed ? 0 : 1);
        expect(facade.allows(target), allowed);
        rows.add({
          'entrypoint': entrypoint.name,
          'state': state,
          'scope':
              'facade callback boundary; not a claim of caller widget coverage',
          'visualLockPolicy': !facade.allows(target),
          'routeCallbacks': routes,
          'actionCallbacks': actions,
          'premiumReadCallbacks': reads,
          'paywalls': paywalls
        });
      });
    }
  }
  test('identity changed during paywall cannot authorize the old request',
      () async {
    var uid = 'A';
    final service = EntitlementService.forTesting(
        uid: () => uid,
        clock: () => now,
        sessionLoader: (_) async => CalculatorMcc1Session(
            token: 'fixture',
            tier: uid == 'A' ? 'free' : 'premium',
            capabilities: const [],
            expiresAtUtc: now.add(const Duration(minutes: 5)),
            entitlementSource: 'fixture'));
    addTearDown(service.dispose);
    var reads = 0;
    final result = await MedCasesFeatureAuthorization(service).execute(
        const FeatureTarget.capability(MedCasesCapability.drugsFullLibrary),
        entrypoint: FeatureEntryPoint.restoredNavigation,
        presentPaywall: () async {
      uid = 'B';
      await service.refreshAuthoritativeTier(force: true);
    }, action: () async {
      reads++;
      return true;
    });
    expect(result, null);
    expect(reads, 0);
  });
  test(
      'search text does not infer canonical identity; exact ID and operation resolve',
      () {
    expect(FeatureTarget.calculator('?q=milrinona').canonicalDrugId, null);
    expect(FeatureTarget.calculator('?drugId=milrinona').canonicalDrugId,
        'milrinona');
    expect(FeatureTarget.calculator('?tab=infusao').capability,
        MedCasesCapability.drugsAdvancedInfusion);
  });
  tearDownAll(() {
    final output = Directory('.dart_tool/final_authorization_graph_closure');
    output.createSync(recursive: true);
    File('${output.path}/entrypoint-cartesian-matrix.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  });
}
