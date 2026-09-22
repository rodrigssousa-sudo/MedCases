import 'package:medcases/models/drug_model.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/drugs_screen.dart';
import 'package:medcases/screens/upgrade_screen.dart';
import 'package:medcases/services/canonical_drug_library.dart';
import 'package:medcases/services/calculator_mcc1_bridge_service.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/free_drug_catalog.dart';
import 'package:medcases/services/medcases_feature_authorization.dart';
import 'package:medcases/widgets/clinical_entrypoints.dart';
import 'canonical_drug_route_integration_test.dart' show ViewPreferences;

typedef Entry = Future<void> Function(BuildContext, String);
void main() {
  final entries = <String, Entry>{
    'HOME_SEARCH': openDrugFromHomeSearch,
    'GLOBAL_SEARCH': openDrugFromGlobalSearch,
    'SHOW_DRUG_DETAIL': (context, id) async {
      showDrugDetailSheet(context, DrugModel(id: id, name: id, group: '',
        className: const {}, category: const {}, route: '', doseType: ''));
    },
    'FAVORITES': openDrugFromFavorite,
    'RECENTS': openDrugFromRecent,
    'DIRECT_NAVIGATOR': openDrugFromDirectNavigator,
    'RESTORED_NAVIGATION': openRestoredDrug,
    'OFFLINE_RESTORED_SCREEN': openOfflineRestoredDrug,
    'DEEPLINK': openCalculatorFromUrl,
    'AI_ACTION': openCalculatorFromAi,
    'STUDY_ACTION': openCalculatorFromStudy,
    'PLANTAO_ACTION': openCalculatorFromPlantao,
    'CALCULATOR_ACTION': openCalculatorAction,
  };
  final rows = <Map<String, Object?>>[];
  final directory = Directory(
      '/private/tmp/medcases-calculadora-r1-canonical-20260921/data/drugs');
  final file = directory.listSync().whereType<File>().firstWhere((f) =>
      f.path.endsWith('.json') &&
      !f.path.endsWith('/index.json') &&
      !freeDrugCanonicalIds
          .contains(f.uri.pathSegments.last.replaceAll('.json', '')));
  final doc =
      Map<String, Object?>.from(jsonDecode(file.readAsStringSync()) as Map);
  final id = doc['id'] as String;
  final now = DateTime.utc(2026, 9, 21);
  for (final entry in entries.entries) {
    for (final state in ['FREE', 'TRIAL', 'PREMIUM', 'EXPIRED']) {
      testWidgets('real entry adapter ${entry.key} $state', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final allowed = state == 'TRIAL' || state == 'PREMIUM';
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
        var reads = 0, construction = 0, webviews = 0;
        final library = CanonicalDrugLibrary(
            entitlement: service,
            preferences: await SharedPreferences.getInstance(),
            loadIndex: () async => {
                  id: {'id': id, 'name': doc['name']}
                },
            loadDocument: (key) async {
              reads++;
              return doc;
            });
        final calculator = [
          'DEEPLINK',
          'AI_ACTION',
          'STUDY_ACTION',
          'PLANTAO_ACTION',
          'CALCULATOR_ACTION'
        ].contains(entry.key);
        await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
            value: preferences,
            child: ClinicalEntryPointScope(
                authorization: MedCasesFeatureAuthorization(service),
                drugPage: (key) {
                  construction++;
                  return DrugsScreen.forTesting(
                      library: library, initialDrugId: key);
                },
                calculatorPage: (url) {
                  construction++;
                  webviews++;
                  return const Scaffold(
                      body: Text('authorized calculator factory'));
                },
                child: MaterialApp(
                    home: Builder(
                        builder: (context) => Scaffold(
                            body: TextButton(
                                onPressed: () => entry.value(
                                    context,
                                    calculator
                                        ? 'https://www.medcasescalcu.com/?tab=infusao'
                                        : id),
                                child: const Text('caller'))))))));
        await tester.tap(find.text('caller'));
        await tester.pumpAndSettle();
        expect(construction, allowed ? greaterThan(0) : equals(0));
        expect(reads, !calculator && allowed ? greaterThan(0) : equals(0));
        expect(webviews, calculator && allowed ? greaterThan(0) : equals(0));
        expect(find.byType(UpgradeScreen),
            allowed ? findsNothing : findsOneWidget);
        expect(preferences.recents.contains(id), !calculator && allowed);
        rows.add({
          'entrypoint': entry.key,
          'state': state,
          'routeConstructions': construction,
          'premiumDocumentReads': reads,
          'premiumWebViewFactoryCalls': webviews,
          'paywallVisible': !allowed,
          'recentAdded': preferences.recents.contains(id),
          'status': 'PASS',
          'calculatorNote': calculator
              ? 'factory spy; no physical PlatformView simulation'
              : null
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        service.dispose();
        preferences.dispose();
      });
    }
  }
  tearDownAll(() {
    final dir =
        Directory('.dart_tool/final_user_reachable_authorization_closure')
          ..createSync(recursive: true);
    File('${dir.path}/entrypoint-runtime-matrix.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  });
}
