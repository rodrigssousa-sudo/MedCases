import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/design_system/design_system.dart';

void main() {
  group('MedCases Next foundation', () {
    test('spacing scale is strictly progressive', () {
      expect(MedSpacing.none, lessThan(MedSpacing.xs));
      expect(MedSpacing.xs, lessThan(MedSpacing.sm));
      expect(MedSpacing.sm, lessThan(MedSpacing.md));
      expect(MedSpacing.md, lessThan(MedSpacing.lg));
      expect(MedSpacing.lg, lessThan(MedSpacing.xl));
      expect(MedSpacing.xl, lessThan(MedSpacing.x2l));
      expect(MedSpacing.x2l, lessThan(MedSpacing.x3l));
      expect(MedSpacing.x3l, lessThan(MedSpacing.x4l));
    });

    test('radius scale is strictly progressive', () {
      expect(MedRadius.noneValue, lessThan(MedRadius.smallValue));
      expect(MedRadius.smallValue, lessThan(MedRadius.mediumValue));
      expect(MedRadius.mediumValue, lessThan(MedRadius.largeValue));
      expect(MedRadius.largeValue, lessThan(MedRadius.xLargeValue));
      expect(MedRadius.xLargeValue, lessThan(MedRadius.pillValue));
    });

    test('breakpoints resolve all official window classes', () {
      expect(MedBreakpoints.resolve(390), MedWindowClass.mobile);
      expect(MedBreakpoints.resolve(768), MedWindowClass.tablet);
      expect(MedBreakpoints.resolve(1280), MedWindowClass.desktop);
      expect(MedBreakpoints.resolve(1600), MedWindowClass.wideDesktop);
    });

    test('breakpoint boundaries have no uncovered interval', () {
      expect(
        MedBreakpoints.resolve(MedBreakpoints.mobileMax),
        MedWindowClass.mobile,
      );
      expect(
        MedBreakpoints.resolve(MedBreakpoints.tabletMin),
        MedWindowClass.tablet,
      );
      expect(
        MedBreakpoints.resolve(MedBreakpoints.desktopMin),
        MedWindowClass.desktop,
      );
      expect(
        MedBreakpoints.resolve(MedBreakpoints.wideDesktopMin),
        MedWindowClass.wideDesktop,
      );
    });

    test('duration scale is strictly progressive', () {
      expect(MedDurations.veryFast, lessThan(MedDurations.fast));
      expect(MedDurations.fast, lessThan(MedDurations.normal));
      expect(MedDurations.normal, lessThan(MedDurations.slow));
      expect(MedDurations.slow, lessThan(MedDurations.verySlow));
    });

    test('typography uses the official font family', () {
      final styles = <TextStyle>[
        MedTypography.displayXL,
        MedTypography.displayLarge,
        MedTypography.displayMedium,
        MedTypography.titleXL,
        MedTypography.titleLarge,
        MedTypography.titleMedium,
        MedTypography.sectionTitle,
        MedTypography.cardTitle,
        MedTypography.bodyLarge,
        MedTypography.bodyMedium,
        MedTypography.bodySmall,
        MedTypography.label,
        MedTypography.caption,
        MedTypography.overline,
        MedTypography.button,
        MedTypography.badge,
        MedTypography.micro,
      ];

      for (final style in styles) {
        expect(style.fontFamily, MedTypography.fontFamily);
        expect(style.fontSize, isNotNull);
        expect(style.fontWeight, isNotNull);
        expect(style.letterSpacing, isNotNull);
        expect(style.height, isNotNull);
      }
    });

    test('neutral semantic colors remain distinct', () {
      expect(MedColors.background, isNot(MedColors.surface));
      expect(MedColors.textPrimary, isNot(MedColors.textSecondary));
      expect(MedColors.success, isNot(MedColors.warning));
      expect(MedColors.warning, isNot(MedColors.error));
      expect(MedColors.information, isNot(MedColors.error));
    });

    test('elevation scale exposes immutable shadow collections', () {
      expect(MedElevation.none, isEmpty);
      expect(MedElevation.small, isNotEmpty);
      expect(MedElevation.medium, isNotEmpty);
      expect(MedElevation.large, isNotEmpty);
      expect(MedElevation.overlay, isNotEmpty);
    });

    test('light and dark themes are independently available', () {
      expect(MedTheme.light.brightness, Brightness.light);
      expect(MedTheme.dark.brightness, Brightness.dark);
      expect(MedTheme.light.useMaterial3, isTrue);
      expect(MedTheme.dark.useMaterial3, isTrue);
      expect(
        MedTheme.light.textTheme.bodyMedium?.fontFamily,
        MedTypography.fontFamily,
      );
      expect(
        MedTheme.dark.textTheme.bodyMedium?.fontFamily,
        MedTypography.fontFamily,
      );
    });

    test('icon scale and base aliases are available', () {
      expect(MedIcons.small, lessThan(MedIcons.medium));
      expect(MedIcons.medium, lessThan(MedIcons.large));
      expect(MedIcons.large, lessThan(MedIcons.xLarge));
      expect(MedIcons.home, isA<IconData>());
      expect(MedIcons.ai, isA<IconData>());
      expect(MedIcons.calculator, isA<IconData>());
      expect(MedIcons.pharmacology, isA<IconData>());
    });
  });
}
