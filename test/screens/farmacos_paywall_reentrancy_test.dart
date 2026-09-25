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

class _Preferences extends ChangeNotifier implements AppProvider {
  @override
  String get lang => 'pt';
  @override
  Set<String> get favDrugs => {};
  void rebuild() => notifyListeners();
  @override
  Future<void> registerRecent(String type, String id, String title) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Observer extends NavigatorObserver {
  int presentations = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute) presentations++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<
      ({
        EntitlementService entitlement,
        _Preferences preferences,
        _Observer observer,
        List<String> reads
      })> mount(WidgetTester tester, {bool premium = false}) async {
    final now = DateTime.utc(2026, 9, 25);
    final entitlement = EntitlementService.forTesting(
      uid: () => 'paywall-test',
      clock: () => now,
      sessionLoader: (_) async => CalculatorMcc1Session(
        token: 'test',
        tier: premium ? 'premium' : 'free',
        capabilities: const [],
        expiresAtUtc: now.add(const Duration(minutes: 5)),
        entitlementSource: premium ? 'PREMIUM' : 'FREE',
      ),
    );
    final preferences = _Preferences();
    final observer = _Observer();
    final reads = <String>[];
    final library = CanonicalDrugLibrary(
      entitlement: entitlement,
      preferences: await SharedPreferences.getInstance(),
      loadIndex: () async => {
        'varfarina': {'id': 'varfarina', 'name': 'Locked test drug'},
        freeDrugCanonicalIds.first: {
          'id': freeDrugCanonicalIds.first,
          'name': 'Free test drug'
        },
      },
      loadDocument: (id) async {
        reads.add(id);
        return {'id': id, 'name': 'Test document'};
      },
    );
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
      value: preferences,
      child: MaterialApp(
          navigatorObservers: [observer],
          home: DrugsScreen.forTesting(library: library)),
    ));
    await tester.pumpAndSettle();
    return (
      entitlement: entitlement,
      preferences: preferences,
      observer: observer,
      reads: reads
    );
  }

  testWidgets('locked drug: first/fast/scroll/rebuild/close/explicit reopen',
      (tester) async {
    final h = await mount(tester);
    final tile = tester
        .widget<ListTile>(find.widgetWithText(ListTile, 'Locked test drug'));
    tile.onTap!(); // first explicit intent enters authorization/presentation
    for (var i = 0; i < 4; i++) {
      tile.onTap!();
    }
    await tester.pumpAndSettle();
    expect(h.observer.presentations, 1,
        reason: 'LOCKED_DRUG_FIRST_TRIGGER=1_PAYWALL');
    expect(find.byType(UpgradeScreen), findsOneWidget);
    expect(h.reads, isEmpty, reason: 'Locked document remains inaccessible');

    for (var i = 0; i < 4; i++) {
      tile.onTap!();
    }
    await tester.pumpAndSettle();
    expect(h.observer.presentations, 1,
        reason: 'MULTIPLE_FAST_TRIGGERS=STILL_1');
    final scroll = find
        .descendant(
            of: find.byType(UpgradeScreen),
            matching: find.byType(SingleChildScrollView))
        .first;
    await tester.drag(scroll, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(h.observer.presentations, 1,
        reason: 'SCROLL_DURING_PAYWALL=STILL_1');

    h.preferences.rebuild();
    await h.entitlement.refreshAuthoritativeTier();
    await tester.pumpAndSettle();
    expect(h.observer.presentations, 1,
        reason: 'REBUILD_DURING_PAYWALL=STILL_1');
    expect(find.byType(UpgradeScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(UpgradeScreen), findsNothing);
    h.preferences.rebuild();
    await tester.drag(find.byType(ListView), const Offset(0, -50));
    await tester.pumpAndSettle();
    expect(h.observer.presentations, 1,
        reason: 'Close/scroll/rebuild is not a new intent');
    await tester.tap(find.text('Locked test drug'));
    await tester.pumpAndSettle();
    expect(h.observer.presentations, 2,
        reason: 'CLOSE_THEN_EXPLICIT_REOPEN=1_NEW_PAYWALL');
    expect(find.byType(UpgradeScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    h.entitlement.dispose();
    h.preferences.dispose();
  });

  for (final premium in [false, true]) {
    testWidgets(
        premium ? 'PREMIUM_USER=0_INCORRECT_PAYWALL' : 'FREE_DRUG=0_PAYWALL',
        (tester) async {
      final h = await mount(tester, premium: premium);
      await tester
          .tap(find.text(premium ? 'Locked test drug' : 'Free test drug'));
      await tester.pumpAndSettle();
      expect(h.observer.presentations, 0);
      expect(find.byType(UpgradeScreen), findsNothing);
      expect(h.reads, [premium ? 'varfarina' : freeDrugCanonicalIds.first]);
      await tester.pumpWidget(const SizedBox());
      h.entitlement.dispose();
      h.preferences.dispose();
    });
  }
}
