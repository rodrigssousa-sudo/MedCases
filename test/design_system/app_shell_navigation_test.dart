import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/design_system/design_system.dart';

void main() {
  const destinations = <MedNavigationDestination>[
    MedNavigationDestination(
      label: 'Início',
      icon: MedIcons.home,
      selectedIcon: MedIcons.homeSelected,
    ),
    MedNavigationDestination(
      label: 'IA',
      icon: MedIcons.ai,
      selectedIcon: MedIcons.ai,
      badgeLabel: '2',
    ),
    MedNavigationDestination(
      label: 'Cálculos',
      icon: MedIcons.calculator,
      selectedIcon: MedIcons.calculator,
    ),
  ];

  Future<void> pumpTestApp(
    WidgetTester tester,
    Widget child, {
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: MedTheme.light,
        darkTheme: MedTheme.dark,
        home: child,
      ),
    );
  }) {
    return MaterialApp(
      theme: MedTheme.light,
      darkTheme: MedTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  group('MedNavigationDestination', () {
    test('stores immutable navigation data', () {
      const destination = MedNavigationDestination(
        label: 'Início',
        icon: MedIcons.home,
        selectedIcon: MedIcons.homeSelected,
        badgeLabel: '4',
        semanticLabel: 'Abrir início',
      );

      expect(destination.label, 'Início');
      expect(destination.icon, MedIcons.home);
      expect(destination.selectedIcon, MedIcons.homeSelected);
      expect(destination.badgeLabel, '4');
      expect(destination.semanticLabel, 'Abrir início');
    });
  });

  group('MedBottomNavigation', () {
    testWidgets('renders destinations and handles selection', (tester) async {
      int? selected;

      await pumpTestApp(
        tester,
        Scaffold(
            bottomNavigationBar: MedBottomNavigation(
              destinations: destinations,
              selectedIndex: 0,
              onDestinationSelected: (index) => selected = index,
            ),
          ),
        size: const Size(390, 844),
      );

      expect(find.text('Início'), findsOneWidget);
      expect(find.text('IA'), findsOneWidget);
      expect(find.text('Cálculos'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('IA'));
      await tester.pump();

      expect(selected, 1);
    });
  });

  group('MedSideNavigation', () {
    testWidgets('renders expanded side navigation', (tester) async {
      int? selected;

      await pumpTestApp(
        tester,
        Scaffold(
            body: MedSideNavigation(
              destinations: destinations,
              selectedIndex: 0,
              onDestinationSelected: (index) => selected = index,
              header: const MedSideNavigationHeader(
                title: 'MedCases',
                subtitle: 'Next',
              ),
              footer: const Text('Perfil'),
            ),
          ),
        size: const Size(1440, 900),
      );

      expect(find.text('MedCases'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('Início'), findsOneWidget);

      await tester.tap(find.text('Cálculos'));
      await tester.pump();

      expect(selected, 2);
    });

    testWidgets('supports collapsed side navigation', (tester) async {
      await pumpTestApp(
        tester,
        Scaffold(
            body: MedSideNavigation(
              destinations: destinations,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              expanded: false,
            ),
          ),
        size: const Size(1440, 900),
      );

      final Size size = tester.getSize(find.byType(MedSideNavigation));
      expect(size.width, 88);
    });
  });

  group('MedNavigationDrawer', () {
    testWidgets('renders drawer and selects destination', (tester) async {
      int? selected;

      await pumpTestApp(
        tester,
        Scaffold(
            drawer: MedNavigationDrawer(
              destinations: destinations,
              selectedIndex: 0,
              onDestinationSelected: (index) => selected = index,
              header: const Text('Menu'),
            ),
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Text('Abrir'),
                );
              },
            ),
          ),
        size: const Size(768, 1024),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('IA'), findsOneWidget);

      await tester.tap(find.text('IA'));
      await tester.pumpAndSettle();

      expect(selected, 1);
    });
  });

  group('MedAppShell', () {
    testWidgets('uses bottom navigation on mobile', (tester) async {
      await pumpTestApp(
        tester,
        MedAppShell(
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            toolbar: const MedToolbar(title: 'Mobile'),
            body: const Text('Conteúdo mobile'),
          ),
        size: const Size(390, 844),
      );

      expect(find.byType(MedBottomNavigation), findsOneWidget);
      expect(find.byType(MedSideNavigation), findsNothing);
      expect(find.byType(MedNavigationDrawer), findsNothing);
      expect(find.text('Conteúdo mobile'), findsOneWidget);
    });

    testWidgets('uses drawer navigation on tablet', (tester) async {
      await pumpTestApp(
        tester,
        MedAppShell(
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            toolbar: const MedToolbar(title: 'Tablet'),
            body: const Text('Conteúdo tablet'),
          ),
        size: const Size(768, 1024),
      );

      final Scaffold scaffold = tester.widget<Scaffold>(
        find.byType(Scaffold).first,
      );

      expect(scaffold.drawer, isA<MedNavigationDrawer>());
      expect(find.byType(MedBottomNavigation), findsNothing);
      expect(find.byType(MedSideNavigation), findsNothing);
      expect(find.text('Conteúdo tablet'), findsOneWidget);
    });

    testWidgets('uses side navigation on desktop', (tester) async {
      await pumpTestApp(
        tester,
        MedAppShell(
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            toolbar: const MedToolbar(title: 'Desktop'),
            body: const Text('Conteúdo desktop'),
          ),
        size: const Size(1280, 800),
      );

      expect(find.byType(MedSideNavigation), findsOneWidget);
      expect(find.byType(MedBottomNavigation), findsNothing);
      expect(find.text('Conteúdo desktop'), findsOneWidget);
    });

    testWidgets('supports forced navigation mode', (tester) async {
      await pumpTestApp(
        tester,
        MedAppShell(
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            mode: MedAppShellNavigationMode.side,
            body: const Text('Modo forçado'),
          ),
        size: const Size(390, 844),
      );

      expect(find.byType(MedSideNavigation), findsOneWidget);
      expect(find.byType(MedBottomNavigation), findsNothing);
    });

    testWidgets('propagates destination selection', (tester) async {
      int? selected;

      await pumpTestApp(
        tester,
        MedAppShell(
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: (index) => selected = index,
            body: const Text('Conteúdo'),
          ),
        size: const Size(390, 844),
      );

      await tester.tap(find.text('Cálculos'));
      await tester.pump();

      expect(selected, 2);
    });
  });
}
