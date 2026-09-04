import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/design_system/design_system.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      theme: MedTheme.light,
      darkTheme: MedTheme.dark,
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('MedCard', () {
    testWidgets('renders child and handles interaction', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedCard(
            semanticLabel: 'Clinical card',
            onTap: () => taps += 1,
            child: const Text('Clinical content'),
          ),
        ),
      );

      expect(find.text('Clinical content'), findsOneWidget);

      await tester.tap(find.text('Clinical content'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('supports every official variant', (tester) async {
      for (final variant in MedCardVariant.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedCard(
              variant: variant,
              child: Text(variant.name),
            ),
          ),
        );

        expect(find.text(variant.name), findsOneWidget);
      }
    });
  });

  group('MedButton', () {
    testWidgets('executes callback when enabled', (tester) async {
      var presses = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedButton(
            label: 'Continue',
            onPressed: () => presses += 1,
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(presses, 1);
    });

    testWidgets('does not execute callback while loading', (tester) async {
      var presses = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedButton(
            label: 'Continue',
            isLoading: true,
            onPressed: () => presses += 1,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(MedButton));
      await tester.pump();

      expect(presses, 0);
    });

    testWidgets('supports expanded width', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const SizedBox(
            width: 300,
            child: MedButton(
              label: 'Expanded',
              expand: true,
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(MedButton));
      expect(size.width, 300);
    });

    testWidgets('supports every official variant', (tester) async {
      for (final variant in MedButtonVariant.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedButton(
              label: variant.name,
              variant: variant,
              onPressed: () {},
            ),
          ),
        );

        expect(find.text(variant.name), findsOneWidget);
      }
    });
  });

  group('MedIconButton', () {
    testWidgets('executes callback when enabled', (tester) async {
      var presses = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedIconButton(
            icon: MedIcons.add,
            tooltip: 'Add',
            onPressed: () => presses += 1,
          ),
        ),
      );

      await tester.tap(find.byIcon(MedIcons.add));
      await tester.pump();

      expect(presses, 1);
    });

    testWidgets('shows loading state without invoking callback',
        (tester) async {
      var presses = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedIconButton(
            icon: MedIcons.add,
            tooltip: 'Add',
            isLoading: true,
            onPressed: () => presses += 1,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(MedIconButton));
      await tester.pump();

      expect(presses, 0);
    });
  });

  group('MedDivider', () {
    testWidgets('renders horizontal divider by default', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const MedDivider()),
      );

      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('renders vertical divider when requested', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const SizedBox(
            height: 100,
            child: MedDivider(
              orientation: MedDividerOrientation.vertical,
            ),
          ),
        ),
      );

      expect(find.byType(VerticalDivider), findsOneWidget);
    });
  });
}
