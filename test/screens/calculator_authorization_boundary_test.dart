import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/calculadora_screen.dart';
import 'package:medcases/screens/upgrade_screen.dart';
import 'package:medcases/services/medcases_feature_authorization.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/calculator_mcc1_bridge_service.dart';
import 'package:medcases/widgets/authorized_feature_navigation.dart';
import 'canonical_drug_route_integration_test.dart' show ViewPreferences;

void main() {
  for (final state in ['FREE', 'TRIAL_ACTIVE', 'PAID_PREMIUM', 'EXPIRED']) {
    testWidgets('real shared Navigator facade $state gates before builder/read',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.utc(2026, 9, 21);
      final allowed = state == 'TRIAL_ACTIVE' || state == 'PAID_PREMIUM';
      final service = EntitlementService.forTesting(
          uid: () => 'A',
          clock: () => now,
          sessionLoader: (_) async => CalculatorMcc1Session(
              token: 'fixture',
              tier: state == 'FREE' ? 'free' : 'premium',
              capabilities: const [],
              expiresAtUtc:
                  now.add(Duration(minutes: state == 'EXPIRED' ? -1 : 5)),
              entitlementSource: state));
      final preferences = ViewPreferences();
      var reads = 0;
      await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
          value: preferences,
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => navigateAuthorizedFeature(context,
                                  target: const FeatureTarget.capability(
                                      MedCasesCapability.drugsWeightDose),
                                  entrypoint: FeatureEntryPoint.directNavigator,
                                  lang: 'pt',
                                  authorization:
                                      MedCasesFeatureAuthorization(service),
                                  builder: (_) {
                                reads++;
                                return const Scaffold(
                                    body: Text('protected destination'));
                              }),
                          child: const Text('direct call')))))));
      await tester.tap(find.text('direct call'));
      await tester.pumpAndSettle();
      expect(reads, allowed ? greaterThan(0) : equals(0));
      expect(find.text('protected destination'),
          allowed ? findsOneWidget : findsNothing);
      expect(
          find.byType(UpgradeScreen), allowed ? findsNothing : findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      service.dispose();
      preferences.dispose();
    });
  }

  for (final expired in [false, true]) {
    testWidgets(
        'direct calculator construction denies before WebView: expired=$expired',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.utc(2026, 9, 21);
      final service = EntitlementService.forTesting(
          uid: () => 'A',
          clock: () => now,
          sessionLoader: (_) async => CalculatorMcc1Session(
              token: 'fixture',
              tier: expired ? 'premium' : 'free',
              capabilities: const [],
              expiresAtUtc: now.add(Duration(minutes: expired ? -1 : 5)),
              entitlementSource: 'fixture'));
      final preferences = ViewPreferences();
      await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
          value: preferences,
          child: MaterialApp(
              home: CalculadoraScreen.forAuthorizationTest(
                  initialUrl: 'https://www.medcasescalcu.com/?tab=infusao',
                  authorization: MedCasesFeatureAuthorization(service)))));
      await tester.pumpAndSettle();
      expect(find.byType(UpgradeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      // No platform implementation is installed. Creating a native controller
      // would fail this test; the authorization shell never constructs it.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      service.dispose();
      preferences.dispose();
    });
  }
}
