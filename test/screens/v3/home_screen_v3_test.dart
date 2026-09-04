import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/v3/home_screen_v3.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    required ValueChanged<int> onTabChange,
    required ValueChanged<int> onSubTabChange,
    required Function(String) openProtocol,
    required VoidCallback onOpenNotes,
    VoidCallback? onCheckUpdate,
    Size size = const Size(430, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreenV3(
            onTabChange: onTabChange,
            onSubTabChange: onSubTabChange,
            openProtocol: openProtocol,
            onOpenNotes: onOpenNotes,
            onCheckUpdate: onCheckUpdate,
          ),
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets('renders the parallel Home V3 contract', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      onTabChange: (_) {},
      onSubTabChange: (_) {},
      openProtocol: (_) {},
      onOpenNotes: () {},
    );

    expect(find.byKey(const Key('home-v3-title')), findsOneWidget);
    expect(find.byKey(const Key('home-v3-ai')), findsOneWidget);
    expect(find.byKey(const Key('home-v3-ai-cta')), findsOneWidget);
    expect(find.text('ABRIR IA'), findsOneWidget);
    expect(find.byKey(const Key('home-v3-calculator')), findsOneWidget);
    expect(find.byKey(const Key('home-v3-drugs')), findsOneWidget);
    expect(find.byKey(const Key('home-v3-navigation-grid')), findsOneWidget);
    expect(find.byKey(const Key('home-v3-notes')), findsOneWidget);
    expect(find.byKey(const Key('home-v3-update')), findsNothing);
  });

  testWidgets('preserves tab and sub-tab callback contracts', (
    WidgetTester tester,
  ) async {
    final List<int> tabs = <int>[];
    final List<int> subTabs = <int>[];

    await pumpHome(
      tester,
      onTabChange: tabs.add,
      onSubTabChange: subTabs.add,
      openProtocol: (_) {},
      onOpenNotes: () {},
    );

    await tester.tap(find.byKey(const Key('home-v3-ai')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-v3-calculator')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-v3-drugs')));
    await tester.pump();

    expect(tabs, <int>[2, 4]);
    expect(subTabs, <int>[0]);
  });

  testWidgets('keeps the explicit AI action inside the existing AI card', (
    WidgetTester tester,
  ) async {
    final List<int> tabs = <int>[];

    await pumpHome(
      tester,
      onTabChange: tabs.add,
      onSubTabChange: (_) {},
      openProtocol: (_) {},
      onOpenNotes: () {},
    );

    expect(find.byKey(const Key('home-v3-ai-cta')), findsOneWidget);
    expect(find.text('ABRIR IA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-v3-ai-cta')));
    await tester.pump();

    expect(tabs, <int>[2]);
  });

  testWidgets('preserves navigation and auxiliary callbacks', (
    WidgetTester tester,
  ) async {
    final List<String> protocols = <String>[];
    int notes = 0;
    int updates = 0;

    await pumpHome(
      tester,
      onTabChange: (_) {},
      onSubTabChange: (_) {},
      openProtocol: protocols.add,
      onOpenNotes: () => notes++,
      onCheckUpdate: () => updates++,
    );

    await tester.tap(find.byKey(const Key('home-v3-patient')));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('home-v3-notes')));
    await tester.tap(find.byKey(const Key('home-v3-notes')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-v3-update')));
    await tester.pump();

    expect(protocols, <String>['adulto']);
    expect(notes, 1);
    expect(updates, 1);
  });

  testWidgets('adapts the navigation grid to a wide viewport', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      size: const Size(1200, 900),
      onTabChange: (_) {},
      onSubTabChange: (_) {},
      openProtocol: (_) {},
      onOpenNotes: () {},
    );

    final GridView grid = tester.widget<GridView>(
      find.byKey(const Key('home-v3-navigation-grid')),
    );
    final SliverGridDelegateWithFixedCrossAxisCount delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate.crossAxisCount, 4);
  });
}
