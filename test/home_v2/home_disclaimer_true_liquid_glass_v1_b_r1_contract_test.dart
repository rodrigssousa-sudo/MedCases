import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  if (start < 0) throw StateError('class missing: $className');

  final next = RegExp(r'\nclass\s+[A-Za-z0-9_]+')
      .firstMatch(source.substring(start + 1));
  final end = next == null ? source.length : start + 1 + next.start;
  return source.substring(start, end);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();

  group('Home disclaimer True Liquid Glass V1-B-R1', () {
    test('mobile liquid material activates only on Home', () {
      final footer = classBlock(main, '_FloatingFooterState');

      expect(
        footer,
        contains('homeLiquidGlass: widget.currentTab == 0'),
      );
      expect(
        RegExp(r'homeLiquidGlass:\s*widget\.currentTab\s*==\s*0')
            .allMatches(footer)
            .length,
        1,
      );
    });

    test('shared shelf keeps legacy material for non-Home tabs', () {
      final shelf = classBlock(main, '_LegalGlassShelf');

      expect(shelf, contains('final bool homeLiquidGlass;'));
      expect(shelf, contains('this.homeLiquidGlass = false'));
      expect(shelf, contains('if (!homeLiquidGlass)'));
      expect(
        shelf,
        contains('Color(0xFF252930).withOpacity(0.70)'),
      );
      expect(
        shelf,
        contains('Colors.white.withOpacity(0.70)'),
      );
      expect(
        shelf,
        contains('ImageFilter.blur(sigmaX: 14, sigmaY: 14)'),
      );
    });

    test('Home shelf owns True Liquid Glass material', () {
      final shelf = classBlock(main, '_LegalGlassShelf');

      expect(
        shelf,
        contains('MEDCASES_HOME_DISCLAIMER_TRUE_LIQUID_GLASS_V1_B_R1'),
      );
      expect(
        shelf,
        contains('Color(0xFF161B22).withValues(alpha: 0.58)'),
      );
      expect(
        shelf,
        contains('Colors.white.withValues(alpha: 0.56)'),
      );
      expect(
        shelf,
        contains('ImageFilter.blur(sigmaX: 16, sigmaY: 16)'),
      );
      expect(shelf, contains('liquidSpecular'));
      expect(shelf, contains('blurRadius: 14'));
      expect(shelf, contains('spreadRadius: -8'));
      expect(shelf, contains('offset: const Offset(0, -5)'));
      expect(shelf, contains('width: 0.7'));
      expect(shelf, contains('padding: EdgeInsets.only(bottom: safeBottom)'));
    });

    test('disclaimer regulatory copy and typography stay frozen', () {
      final legal = classBlock(main, '_LegalBar');

      expect(
        legal,
        contains('Herramienta educativa de apoyo clínico.'),
      );
      expect(
        legal,
        contains('Ferramenta educacional de apoio clínico.'),
      );
      expect(legal, contains('fontSize: 9.5'));
      expect(legal, contains('height: 1.28'));
      expect(legal, contains('FontWeight.w400'));
      expect(legal, contains('maxLines: 2'));
      expect(legal, contains('TextOverflow.ellipsis'));
      expect(legal, contains('Icons.info_outline_rounded'));
      expect(legal, contains('textAlign: TextAlign.center'));
    });

    test('desktop/tablet enables liquid disclaimer only for Home', () {
      expect(
        main,
        contains('liquidGlass: _tab == 0'),
      );

      final legal = classBlock(main, '_LegalBar');
      expect(legal, contains('final bool liquidGlass;'));
      expect(legal, contains('this.liquidGlass = false'));
      expect(legal, contains('if (!liquidGlass)'));
      expect(
        legal,
        contains('ImageFilter.blur(sigmaX: 16, sigmaY: 16)'),
      );
    });

    test('previous Home and global Liquid Glass owners remain intact', () {
      final topbar = classBlock(main, '_MobileAppBar');
      final footer = classBlock(main, '_FloatingFooterState');

      expect(
        topbar,
        contains('MEDCASES_HOME_TOPBAR_TRUE_LIQUID_GLASS_V1_B_R0'),
      );
      expect(
        footer,
        contains(
          'MEDCASES_GLOBAL_ACTION_BAR_TRUE_LIQUID_GLASS_V1_B_R1',
        ),
      );
    });
  });
}
