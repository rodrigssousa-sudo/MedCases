import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/main.dart').readAsStringSync();
  });

  String slice(String startToken, String endToken) {
    final start = source.indexOf(startToken);
    final end = source.indexOf(endToken, start + startToken.length);
    expect(start, isNonNegative, reason: 'Missing $startToken');
    expect(end, greaterThan(start), reason: 'Missing $endToken');
    return source.substring(start, end);
  }

  double firstNumber(String block, RegExp pattern, String label) {
    final match = pattern.firstMatch(block);
    expect(match, isNotNull, reason: 'Missing metric: $label');
    return double.parse(match!.group(1)!);
  }

  group('Drawer compact R3', () {
    test('R2 marker exists', () {
      expect(
        source,
        contains(
          'MEDCASES_DRAWER_COMPACT_20_PERCENT_VISUAL_DENSITY_V1_B_R3',
        ),
      );
    });

    test('outer drawer contract is a true 20 percent reduction', () {
      final start = source.indexOf('final drawerW');
      final end = source.indexOf(';', start);
      expect(start, isNonNegative);
      expect(end, greaterThan(start));

      final statement = source.substring(start, end + 1);

      final tablet = RegExp(
        r'screenW\.clamp\s*\(\s*0(?:\.0+)?\s*,\s*([0-9.]+)\s*\)',
      ).firstMatch(statement);
      final mobile = RegExp(
        r'\(\s*screenW\s*\*\s*([0-9.]+)\s*\)'
        r'\.clamp\s*\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)',
      ).firstMatch(statement);

      expect(tablet, isNotNull);
      expect(mobile, isNotNull);

      expect(double.parse(tablet!.group(1)!), closeTo(256.0, 0.001));
      expect(double.parse(mobile!.group(1)!), closeTo(0.672, 0.0001));
      expect(double.parse(mobile.group(2)!), closeTo(224.0, 0.001));
      expect(double.parse(mobile.group(3)!), closeTo(256.0, 0.001));
    });

    test('standard row is visually lighter without brittle literal sizing', () {
      final row = slice(
        'class _DrawerRow extends StatelessWidget',
        'class _DrawerLegalRow extends StatelessWidget',
      );

      final slot = firstNumber(
        row,
        RegExp(r'width:\s*([0-9.]+)\s*,\s*child:\s*Icon\(icon', dotAll: true),
        'icon slot',
      );
      final icon = firstNumber(
        row,
        RegExp(r'Icon\(icon,\s*size:\s*([0-9.]+)'),
        'leading icon',
      );
      final title = firstNumber(
        row,
        RegExp(r'fontSize:\s*([0-9.]+)'),
        'title font',
      );
      final chevron = firstNumber(
        row,
        RegExp(r'Icons\.chevron_right_rounded,\s*size:\s*([0-9.]+)',
            dotAll: true),
        'chevron',
      );

      expect(slot, lessThanOrEqualTo(29.0));
      expect(icon, lessThanOrEqualTo(17.0));
      expect(title, lessThanOrEqualTo(12.0));
      expect(chevron, lessThanOrEqualTo(14.5));

      // Touch breathing room intentionally preserved.
      expect(
        row,
        contains(
            'padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9)'),
      );
    });

    test('section hierarchy is lighter', () {
      final section = slice(
        'class _DrawerSectionLabel extends StatelessWidget',
        'class _DrawerBlock extends StatelessWidget',
      );
      final font = firstNumber(
        section,
        RegExp(r'fontSize:\s*([0-9.]+)'),
        'section font',
      );
      expect(font, lessThan(9.5));
    });

    test('theme and offline toggles are visually smaller', () {
      final theme = slice(
        'class _ThemeToggle extends StatelessWidget',
        'class _OnOffToggle extends StatelessWidget',
      );
      final offline = slice(
        'class _OnOffToggle extends StatelessWidget',
        'class _DrawerQuickAccess extends StatelessWidget',
      );

      for (final block in [theme, offline]) {
        expect(block, contains('width: 34'));
        expect(block, contains('height: 19'));
        expect(block, contains('width: 15.5'));
        expect(block, contains('height: 15.5'));
      }
    });

    test('critical routes and account actions remain wired', () {
      expect(source, contains('AuthService.logout()'));
      expect(source, contains('p.toggleDarkMode()'));
      expect(source, contains('_OfflineDrawerCard(p: p, dark: dark)'));
      expect(source, contains('Eliminar Cuenta'));
      expect(source, contains('Cerrar sesión'));
    });
  });
}
