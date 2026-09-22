import 'package:medcases/widgets/canonical_drug_document_view.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/drugs_screen.dart';
import 'package:medcases/screens/upgrade_screen.dart';
import 'package:medcases/services/canonical_drug_library.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/calculator_mcc1_bridge_service.dart';
import 'package:medcases/services/free_drug_catalog.dart';

class ViewPreferences extends ChangeNotifier implements AppProvider {
  @override
  String get lang => 'pt';
  @override
  Set<String> get favDrugs => favorites;
  final favorites = <String>{};
  final recents = <String>[];
  @override
  void toggleFavDrug(String id) {
    if (!favorites.remove(id)) favorites.add(id);
    notifyListeners();
  }

  @override
  Future<void> registerRecent(String type, String id, String title) async {
    recents.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final runtimeRows = <Map<String, Object?>>[];
  tearDownAll(() {
    final dir =
        Directory('.dart_tool/final_user_reachable_authorization_closure')
          ..createSync(recursive: true);
    File('${dir.path}/drugs-screen-runtime-matrix.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(runtimeRows));
  });
  final docs = <String, Map<String, Object?>>{};
  for (final f in Directory(
          '/private/tmp/medcases-calculadora-r1-canonical-20260921/data/drugs')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))) {
    final doc =
        Map<String, Object?>.from(jsonDecode(f.readAsStringSync()) as Map);
    docs[doc['id'] as String] = doc;
  }
  final premiumId =
      docs.keys.firstWhere((id) => !freeDrugCanonicalIds.contains(id));
  final freeId = freeDrugCanonicalIds.first;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final state in ['FREE', 'TRIAL', 'PREMIUM', 'EXPIRED']) {
    testWidgets(
        'actual native direct route $state uses canonical owner and sovereign gate',
        (tester) async {
      final now = DateTime.utc(2026, 9, 21);
      final ent = EntitlementService.forTesting(
          uid: () => 'A',
          clock: () => now,
          sessionLoader: (_) async => CalculatorMcc1Session(
              token: 'test',
              tier: state == 'FREE' ? 'free' : 'premium',
              capabilities: const [],
              expiresAtUtc:
                  now.add(Duration(minutes: state == 'EXPIRED' ? -1 : 5)),
              entitlementSource: state));
      final preferences = ViewPreferences();
      final reads = <String>[];
      final library = CanonicalDrugLibrary(
          entitlement: ent,
          preferences: await SharedPreferences.getInstance(),
          loadIndex: () async => {
                for (final id in [freeId, premiumId])
                  id: {'id': id, 'name': docs[id]!['name']}
              },
          loadDocument: (id) async {
            reads.add(id);
            return docs[id];
          });
      await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
          value: preferences,
          child: MaterialApp(
              home: DrugsScreen.forTesting(
                  library: library, initialDrugId: premiumId))));
      await tester.pumpAndSettle();
      final allowed = state == 'TRIAL' || state == 'PREMIUM';
      expect(reads.contains(premiumId), allowed);
      expect(
          find.byType(UpgradeScreen), allowed ? findsNothing : findsOneWidget);
      expect(preferences.recents.contains(premiumId), allowed);
      runtimeRows.add({
        'entrypoint': 'DRUGS_SCREEN',
        'state': state,
        'premiumDocumentReads': reads.where((id) => id == premiumId).length,
        'recentAdded': preferences.recents.contains(premiumId),
        'premiumDocumentViews':
            find.byType(CanonicalDrugDocumentView).evaluate().length,
        'paywallVisible': find.byType(UpgradeScreen).evaluate().isNotEmpty,
        'status': 'PASS'
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      ent.dispose();
      preferences.dispose();
    });
  }
  testWidgets(
      'actual native Free search and favorite do not read a locked drug',
      (tester) async {
    final now = DateTime.utc(2026, 9, 21);
    final ent = EntitlementService.forTesting(
        uid: () => 'A',
        clock: () => now,
        sessionLoader: (_) async => CalculatorMcc1Session(
            token: 'test',
            tier: 'free',
            capabilities: const [],
            expiresAtUtc: now.add(const Duration(minutes: 5)),
            entitlementSource: 'FREE'));
    final preferences = ViewPreferences()..favorites.add(premiumId);
    var reads = 0;
    final library = CanonicalDrugLibrary(
        entitlement: ent,
        preferences: await SharedPreferences.getInstance(),
        loadIndex: () async => {
              for (final id in [freeId, premiumId])
                id: {'id': id, 'name': docs[id]!['name']}
            },
        loadDocument: (id) async {
          reads++;
          return docs[id];
        });
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: preferences,
        child: MaterialApp(home: DrugsScreen.forTesting(library: library))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), premiumId);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.byType(UpgradeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    ent.dispose();
    preferences.dispose();
  });
  testWidgets(
      'fresh Free install discovers exact 60, searches, favorites and reads canonical Free detail without full index',
      (tester) async {
    final now = DateTime.utc(2026, 9, 21);
    final ent = EntitlementService.forTesting(
        uid: () => 'A',
        clock: () => now,
        sessionLoader: (_) async => CalculatorMcc1Session(
            token: 'fixture',
            tier: 'free',
            capabilities: const [],
            expiresAtUtc: now.add(const Duration(minutes: 5)),
            entitlementSource: 'FREE'));
    final preferences = ViewPreferences();
    final reads = <String>[];
    final library = CanonicalDrugLibrary(
        entitlement: ent,
        preferences: await SharedPreferences.getInstance(),
        loadIndex: () async => throw StateError('FULL_INDEX_REQUIRES_PREMIUM'),
        loadDocument: (id) async {
          reads.add(id);
          return docs[id];
        });
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: preferences,
        child: MaterialApp(home: DrugsScreen.forTesting(library: library))));
    await tester.pumpAndSettle();
    expect(library.index.keys.toSet(), freeDrugCanonicalIds);
    expect(library.discovery('pt').length, 60);
    await tester.enterText(find.byType(TextField), freeId);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();
    expect(preferences.favorites, contains(freeId));
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(reads, [freeId]);
    expect(find.byType(UpgradeScreen), findsNothing);
    expect(preferences.recents, contains(freeId));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    ent.dispose();
    preferences.dispose();
  });
  testWidgets(
      'fresh Free direct Premium ID opens paywall before any full-index or document read',
      (tester) async {
    final now = DateTime.utc(2026, 9, 21);
    final preferences = ViewPreferences();
    var reads = 0;
    final ent = EntitlementService.forTesting(
        uid: () => 'A',
        clock: () => now,
        sessionLoader: (_) async => CalculatorMcc1Session(
            token: 'fixture',
            tier: 'free',
            capabilities: const [],
            expiresAtUtc: now.add(const Duration(minutes: 5)),
            entitlementSource: 'FREE'));
    final library = CanonicalDrugLibrary(
        entitlement: ent,
        preferences: await SharedPreferences.getInstance(),
        loadIndex: () async => throw StateError('FULL_INDEX_REQUIRES_PREMIUM'),
        loadDocument: (id) async {
          reads++;
          return docs[id];
        });
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: preferences,
        child: MaterialApp(
            home: DrugsScreen.forTesting(
                library: library, initialDrugId: premiumId))));
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.byType(UpgradeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    ent.dispose();
    preferences.dispose();
  });
  testWidgets(
      'Premium UID switch clears already displayed owner-bound document',
      (tester) async {
    String? uid = 'A';
    final now = DateTime.utc(2026, 9, 21);
    final preferences = ViewPreferences();
    final ent = EntitlementService.forTesting(
        uid: () => uid,
        clock: () => now,
        sessionLoader: (_) async => CalculatorMcc1Session(
            token: 'fixture',
            tier: 'premium',
            capabilities: const [],
            expiresAtUtc: now.add(const Duration(minutes: 5)),
            entitlementSource: 'PREMIUM'));
    final library = CanonicalDrugLibrary(
        entitlement: ent,
        preferences: await SharedPreferences.getInstance(),
        loadIndex: () async => {
              premiumId: {'id': premiumId, 'name': docs[premiumId]!['name']}
            },
        loadDocument: (id) async => docs[id]);
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: preferences,
        child: MaterialApp(
            home: DrugsScreen.forTesting(
                library: library, initialDrugId: premiumId))));
    await tester.pumpAndSettle();
    expect(find.byType(CanonicalDrugDocumentView), findsOneWidget);
    uid = 'B';
    await ent.refreshAuthoritativeTier(force: true);
    await tester.pumpAndSettle();
    expect(find.byType(CanonicalDrugDocumentView), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    ent.dispose();
    preferences.dispose();
  });
}
