import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/design_system/design_system.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      theme: MedTheme.light,
      darkTheme: MedTheme.dark,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            child: child,
          ),
        ),
      ),
    );
  }

  group('MedListTile', () {
    testWidgets('renders complete structure and handles tap', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedListTile(
            title: 'Paciente',
            subtitle: 'Dados clínicos',
            leading: const Icon(MedIcons.person),
            trailing: const Text('Ativo'),
            onTap: () => taps += 1,
          ),
        ),
      );

      expect(find.text('Paciente'), findsOneWidget);
      expect(find.text('Dados clínicos'), findsOneWidget);
      expect(find.text('Ativo'), findsOneWidget);
      expect(find.byIcon(MedIcons.person), findsOneWidget);

      await tester.tap(find.text('Paciente'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('supports every official variant', (tester) async {
      for (final variant in MedListTileVariant.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedListTile(
              key: ValueKey<MedListTileVariant>(variant),
              title: variant.name,
              variant: variant,
            ),
          ),
        );

        expect(find.text(variant.name), findsOneWidget);
      }
    });

    testWidgets('does not invoke callback when disabled', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedListTile(
            title: 'Bloqueado',
            enabled: false,
            onTap: () => taps += 1,
          ),
        ),
      );

      await tester.tap(find.text('Bloqueado'));
      await tester.pump();

      expect(taps, 0);
    });
  });

  group('MedMenuTile', () {
    testWidgets('renders icon, badge and default chevron', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedMenuTile(
            title: 'Farmacologia',
            subtitle: 'Biblioteca de fármacos',
            icon: MedIcons.pharmacology,
            badge: MedBadge(label: 'Novo'),
          ),
        ),
      );

      expect(find.text('Farmacologia'), findsOneWidget);
      expect(find.text('Biblioteca de fármacos'), findsOneWidget);
      expect(find.text('Novo'), findsOneWidget);
      expect(find.byIcon(MedIcons.pharmacology), findsOneWidget);
      expect(find.byIcon(MedIcons.forward), findsOneWidget);
    });

    testWidgets('executes menu interaction', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedMenuTile(
            title: 'Configurações',
            icon: MedIcons.settings,
            onTap: () => taps += 1,
          ),
        ),
      );

      await tester.tap(find.text('Configurações'));
      await tester.pump();

      expect(taps, 1);
    });
  });

  group('MedNavigationTile', () {
    testWidgets('executes navigation interaction', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedNavigationTile(
            label: 'Home',
            icon: MedIcons.home,
            selectedIcon: MedIcons.homeSelected,
            selected: true,
            onTap: () => taps += 1,
          ),
        ),
      );

      expect(find.byIcon(MedIcons.homeSelected), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('supports both official orientations', (tester) async {
      for (final orientation in MedNavigationTileOrientation.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedNavigationTile(
              key: ValueKey<MedNavigationTileOrientation>(orientation),
              label: orientation.name,
              icon: MedIcons.home,
              orientation: orientation,
            ),
          ),
        );

        expect(find.text(orientation.name), findsOneWidget);
      }
    });

    testWidgets('renders optional badge', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedNavigationTile(
            label: 'Alertas',
            icon: MedIcons.warning,
            badgeLabel: '3',
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });
  });

  group('MedToolbar', () {
    testWidgets('renders title, subtitle, leading and actions', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedToolbar(
            title: 'MedCases',
            subtitle: 'Plantão',
            leading: Icon(MedIcons.menu),
            actions: <Widget>[
              Icon(MedIcons.search),
              Icon(MedIcons.settings),
            ],
          ),
        ),
      );

      expect(find.text('MedCases'), findsOneWidget);
      expect(find.text('Plantão'), findsOneWidget);
      expect(find.byIcon(MedIcons.menu), findsOneWidget);
      expect(find.byIcon(MedIcons.search), findsOneWidget);
      expect(find.byIcon(MedIcons.settings), findsOneWidget);
    });

    testWidgets('supports every official variant', (tester) async {
      for (final variant in MedToolbarVariant.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedToolbar(
              key: ValueKey<MedToolbarVariant>(variant),
              title: variant.name,
              variant: variant,
            ),
          ),
        );

        expect(find.text(variant.name), findsOneWidget);
      }
    });

    test('preferred size includes bottom height', () {
      const bottom = PreferredSize(
        preferredSize: Size.fromHeight(24),
        child: SizedBox(height: 24),
      );

      const toolbar = MedToolbar(
        height: 64,
        bottom: bottom,
      );

      expect(toolbar.preferredSize.height, 88);
    });
  });

  group('MedFloatingButton', () {
    testWidgets('executes callback when enabled', (tester) async {
      var presses = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedFloatingButton(
            icon: MedIcons.add,
            tooltip: 'Adicionar',
            onPressed: () => presses += 1,
          ),
        ),
      );

      await tester.tap(find.byIcon(MedIcons.add));
      await tester.pump();

      expect(presses, 1);
    });

    testWidgets('renders extended label', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedFloatingButton(
            icon: MedIcons.add,
            tooltip: 'Nova evolução',
            label: 'Nova evolução',
          ),
        ),
      );

      expect(find.text('Nova evolução'), findsOneWidget);
      expect(find.byIcon(MedIcons.add), findsOneWidget);
    });

    testWidgets('shows loading state without invoking callback',
        (tester) async {
      var presses = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedFloatingButton(
            icon: MedIcons.add,
            tooltip: 'Adicionar',
            isLoading: true,
            onPressed: () => presses += 1,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(MedFloatingButton));
      await tester.pump();

      expect(presses, 0);
    });

    testWidgets('supports every official variant', (tester) async {
      for (final variant in MedFloatingButtonVariant.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedFloatingButton(
              key: ValueKey<MedFloatingButtonVariant>(variant),
              icon: MedIcons.add,
              tooltip: variant.name,
              variant: variant,
              onPressed: () {},
            ),
          ),
        );

        expect(find.byIcon(MedIcons.add), findsOneWidget);
      }
    });
  });
}
