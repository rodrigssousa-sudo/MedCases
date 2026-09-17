import 'dart:io';

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
  group('Floating footer shrink regression', () {
    test('footer IA shrunk layout scales current SVG and preserves tap actions', () {
      final source = File('lib/main.dart').readAsStringSync();
      final owner = source.indexOf(
        'class _FloatingFooterState extends State<_FloatingFooter> {',
      );
      final navStart = source.indexOf('Widget _buildNavRow() => Row(', owner);
      final navEnd = source.indexOf('Widget _buildAiRow() => Row(', navStart);

      expect(owner, greaterThanOrEqualTo(0));
      expect(navStart, greaterThan(owner));
      expect(navEnd, greaterThan(navStart));

      final footer = source.substring(owner, navEnd);
      final nav = source.substring(navStart, navEnd);
      expect(footer.contains('static const _barHeightShrunk = 38.0;'), isTrue);
      expect(footer.contains(
        'final barHeight = _shrunk ? _barHeightShrunk : _barHeightFull;',
      ), isTrue);
      expect(footer.contains('height: barHeight,'), isTrue);

      // O layout atual usa uma imagem SVG 54x54 em uma caixa de 31.5 px;
      // a coluna inclui legenda 10 px. A FittedBox deve reduzir a coluna
      // no modo de 38 px, sem pressupor a antiga estrutura 26x26.
      const nominalContentHeight = 31.5 + 10.0;
      const shrunkBarHeight = 38.0;
      expect(nominalContentHeight, greaterThan(shrunkBarHeight));
      expect(nav.contains('child: FittedBox('), isTrue);
      expect(nav.contains('fit: BoxFit.scaleDown,'), isTrue);
      expect(nav.contains('child: Column('), isTrue);
      expect(nav.contains('_IaDynamicFloat('), isTrue);
      expect(nav.contains('height: 31.5,'), isTrue);
      expect(nav.contains('child: OverflowBox('), isTrue);
      expect(nav.contains("'assets/icons/home_v2/ic_ia.svg'"), isTrue);
      expect(nav.contains('width: 54,'), isTrue);
      expect(nav.contains('height: 54,'), isTrue);
      expect(nav.contains('opacity: _shrunk ? 0.0 : 1.0,'), isTrue);
      expect(nav.contains("child: Text('IA',"), isTrue);
      expect(nav.contains('onTap: widget.onFabTap,'), isTrue);
      expect(nav.contains('onDoubleTap: widget.onFabDoubleTap,'), isTrue);
    });
  });
}
