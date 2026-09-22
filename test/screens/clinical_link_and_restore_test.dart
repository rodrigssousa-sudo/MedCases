import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/upgrade_screen.dart';
import 'package:medcases/screens/ai/widgets/action_buttons_row.dart';
import 'package:medcases/screens/ai/widgets/ai_block_bubble.dart';
import 'package:medcases/services/external_tool_link_engine.dart';
import 'package:medcases/services/calculator_mcc1_bridge_service.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/medcases_feature_authorization.dart';
import 'package:medcases/widgets/clinical_entrypoints.dart';
import 'canonical_drug_route_integration_test.dart' show ViewPreferences;

void main() {
  final now = DateTime.utc(2026, 9, 21);
  for (final mode in ['AI', 'STUDY', 'PLANTAO', 'FREE_REFERENCE']) {
    for (final tier in ['FREE', 'TRIAL', 'PREMIUM', 'EXPIRED']) {
      testWidgets('actual $mode link $tier before calculator factory',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final preferences = ViewPreferences();
        var calls = 0;
        final service = EntitlementService.forTesting(
            uid: () => 'A',
            clock: () => now,
            sessionLoader: (_) async => CalculatorMcc1Session(
                token: 'fixture',
                tier: tier == 'FREE' ? 'free' : 'premium',
                capabilities: const [],
                expiresAtUtc:
                    now.add(Duration(minutes: tier == 'EXPIRED' ? -1 : 5)),
                entitlementSource: tier));
        final url =
            'https://www.medcasescalcu.com/?tab=${mode == 'FREE_REFERENCE' ? 'interacoes' : 'infusao'}';
        final Widget child = mode == 'AI' || mode == 'FREE_REFERENCE'
            ? AiBlockBubble(block: '[Abrir ferramenta]($url)', dark: false)
            : ActionButtonsRow(
                lastUserMessage: 'consulta',
                lastAiResponse: '',
                isPlantaoMode: mode == 'PLANTAO',
                lang: 'pt',
                dark: false,
                suppressAiAction: true,
                cachedLink:
                    ExternalToolLink(label: 'Abrir ferramenta', url: url),
                onActionTap: (prompt,
                    {required visibleLabel,
                    required isStudyNext,
                    required continuationType,
                    required requestedSections}) {});
        await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
            value: preferences,
            child: ClinicalEntryPointScope(
                authorization: MedCasesFeatureAuthorization(service),
                drugPage: (_) => const SizedBox(),
                calculatorPage: (_) {
                  calls++;
                  return const Scaffold(body: Text('authorized destination'));
                },
                child: MaterialApp(home: Scaffold(body: child)))));
        await tester.tap(find.text('Abrir ferramenta'));
        await tester.pumpAndSettle();
        final allowed =
            mode == 'FREE_REFERENCE' || tier == 'TRIAL' || tier == 'PREMIUM';
        expect(calls, allowed ? greaterThan(0) : equals(0));
        expect(find.byType(UpgradeScreen),
            allowed ? findsNothing : findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        service.dispose();
        preferences.dispose();
      });
    }
  }
  for (final switchUid in [false, true]) {
    testWidgets(
        'real restore adapter rejects saved Premium intent: switchUid=$switchUid',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = ViewPreferences();
      var uid = 'A', tier = 'premium', calls = 0;
      var clock = now;
      final service = EntitlementService.forTesting(
          uid: () => uid,
          clock: () => clock,
          sessionLoader: (_) async => CalculatorMcc1Session(
              token: 'fixture',
              tier: tier,
              capabilities: const [],
              expiresAtUtc: now.add(const Duration(minutes: 5)),
              entitlementSource: 'fixture'));
      final savedIntent = jsonEncode({'canonicalId': 'milrinona'});
      await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
          value: preferences,
          child: ClinicalEntryPointScope(
              authorization: MedCasesFeatureAuthorization(service),
              drugPage: (_) {
                calls++;
                return const Scaffold(body: Text('authorized drug'));
              },
              calculatorPage: (_) => const SizedBox(),
              child: MaterialApp(
                  home: Builder(
                      builder: (context) => Scaffold(
                          body: TextButton(
                              child: const Text('restore'),
                              onPressed: () => openRestoredDrug(
                                  context,
                                  (jsonDecode(savedIntent)
                                      as Map)['canonicalId'] as String))))))));
      await tester.tap(find.text('restore'));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(0));
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop();
      await tester.pumpAndSettle();
      if (switchUid) {
        uid = 'B';
        tier = 'free';
      } else {
        clock = now.add(const Duration(minutes: 6));
      }
      await service.refreshAuthoritativeTier(force: true);
      final before = calls;
      await tester.tap(find.text('restore'));
      await tester.pumpAndSettle();
      expect(calls, before);
      expect(find.byType(UpgradeScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      service.dispose();
      preferences.dispose();
    });
  }
}
