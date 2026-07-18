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

  group('MedBadge', () {
    testWidgets('renders label and optional icon', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedBadge(
            label: 'Premium',
            variant: MedBadgeVariant.premium,
            icon: MedIcons.premium,
          ),
        ),
      );

      expect(find.text('Premium'), findsOneWidget);
      expect(find.byIcon(MedIcons.premium), findsOneWidget);
    });

    testWidgets('supports every official variant', (tester) async {
      for (final variant in MedBadgeVariant.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedBadge(
              key: ValueKey<MedBadgeVariant>(variant),
              label: variant.name,
              variant: variant,
            ),
          ),
        );

        expect(find.text(variant.name), findsOneWidget);
      }
    });

    testWidgets('supports every official size', (tester) async {
      for (final size in MedBadgeSize.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedBadge(
              key: ValueKey<MedBadgeSize>(size),
              label: size.name,
              size: size,
            ),
          ),
        );

        expect(find.text(size.name), findsOneWidget);
      }
    });
  });

  group('MedChip', () {
    testWidgets('executes primary interaction', (tester) async {
      var presses = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedChip(
            label: 'Cardiologia',
            onPressed: () => presses += 1,
          ),
        ),
      );

      await tester.tap(find.text('Cardiologia'));
      await tester.pump();

      expect(presses, 1);
    });

    testWidgets('executes removal interaction', (tester) async {
      var removals = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedChip(
            label: 'Hipertensão',
            variant: MedChipVariant.removable,
            onRemoved: () => removals += 1,
          ),
        ),
      );

      await tester.tap(find.byIcon(MedIcons.close));
      await tester.pump();

      expect(removals, 1);
    });

    testWidgets('does not execute interaction when disabled', (tester) async {
      var presses = 0;

      await tester.pumpWidget(
        buildTestApp(
          MedChip(
            label: 'Desabilitado',
            enabled: false,
            onPressed: () => presses += 1,
          ),
        ),
      );

      await tester.tap(find.text('Desabilitado'));
      await tester.pump();

      expect(presses, 0);
    });

    testWidgets('supports every official variant', (tester) async {
      for (final variant in MedChipVariant.values) {
        await tester.pumpWidget(
          buildTestApp(
            MedChip(
              key: ValueKey<MedChipVariant>(variant),
              label: variant.name,
              variant: variant,
              onRemoved: variant == MedChipVariant.removable ? () {} : null,
            ),
          ),
        );

        expect(find.text(variant.name), findsOneWidget);
      }
    });
  });

  group('MedAvatar', () {
    testWidgets('renders normalized initials', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedAvatar(
            initials: 'Bruno Rodrigues',
          ),
        ),
      );

      expect(find.text('BR'), findsOneWidget);
    });

    testWidgets('limits a single name to two characters', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedAvatar(
            initials: 'Bruno',
          ),
        ),
      );

      expect(find.text('BR'), findsOneWidget);
    });

    testWidgets('renders fallback icon without initials', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const MedAvatar(),
        ),
      );

      expect(find.byIcon(MedIcons.person), findsOneWidget);
    });

    testWidgets('supports every official size', (tester) async {
      const expectedDiameters = <MedAvatarSize, double>{
        MedAvatarSize.small: 32,
        MedAvatarSize.medium: 40,
        MedAvatarSize.large: 56,
        MedAvatarSize.xLarge: 72,
      };

      for (final entry in expectedDiameters.entries) {
        await tester.pumpWidget(
          buildTestApp(
            MedAvatar(
              key: ValueKey<MedAvatarSize>(entry.key),
              initials: 'MC',
              size: entry.key,
            ),
          ),
        );

        final Size avatarSize = tester.getSize(find.byType(CircleAvatar));
        expect(avatarSize.width, entry.value);
        expect(avatarSize.height, entry.value);
      }
    });

    testWidgets('prioritizes image over fallback content', (tester) async {
      const image = AssetImage('assets/nonexistent-test-avatar.png');

      await tester.pumpWidget(
        buildTestApp(
          const MedAvatar(
            imageProvider: image,
            initials: 'MC',
          ),
        ),
      );

      final CircleAvatar avatar = tester.widget<CircleAvatar>(
        find.byType(CircleAvatar),
      );

      expect(avatar.foregroundImage, image);
      expect(avatar.child, isNull);
    });
  });
}
