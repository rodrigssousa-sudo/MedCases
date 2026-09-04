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

String methodBlock(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) throw StateError('method missing: $signature');
  final brace = source.indexOf('{', start);
  if (brace < 0) throw StateError('brace missing');

  var depth = 0;
  for (var i = brace; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  throw StateError('method end missing');
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();

  group('Global action bar True Liquid Glass V1-B-R0', () {
    test('shared floating footer owns true liquid glass material', () {
      final footer = classBlock(main, '_FloatingFooterState');

      expect(
        footer,
        contains('MEDCASES_GLOBAL_ACTION_BAR_TRUE_LIQUID_GLASS_V1_B_R1'),
      );
      expect(
        footer,
        contains('Color(0xFF161B22).withValues(alpha: 0.58)'),
      );
      expect(
        footer,
        contains('Colors.white.withValues(alpha: 0.56)'),
      );
      expect(
        footer,
        contains('ImageFilter.blur(sigmaX: 16, sigmaY: 16)'),
      );
      expect(footer, contains('gradient: LinearGradient('));
      expect(footer, contains('liquidSpecular'));
      expect(footer, contains('height: 0.8'));
      expect(footer, contains('spreadRadius: -4'));
      expect(footer, contains('blurRadius: 26'));
    });

    test('geometry and interactions remain frozen', () {
      final footer = classBlock(main, '_FloatingFooterState');

      expect(footer, contains('static const _barHeightFull = 50.0;'));
      expect(footer, contains('static const _barHeightShrunk = 38.0;'));
      expect(
        footer,
        contains('EdgeInsets.symmetric(horizontal: 30, vertical: 8)'),
      );
      expect(footer, contains('Radius.circular(32)'));
      expect(footer, contains('AnimatedSlide('));
      expect(footer, contains('AnimatedOpacity('));
      expect(footer, contains('duration: const Duration(milliseconds: 280)'));
      expect(footer, contains('RepaintBoundary('));
      expect(footer, contains('_buildNavRow()'));
      expect(footer, contains('_buildAiRow()'));
      expect(footer, contains('_buildMenuButton()'));
      expect(footer, contains('_LegalGlassShelf('));
    });

    test('glass stays restrained rather than neon/heavy', () {
      final footer = classBlock(main, '_FloatingFooterState');

      expect(
        RegExp(r'ImageFilter\.blur\(sigmaX:\s*16,\s*sigmaY:\s*16\)')
            .allMatches(footer)
            .length,
        1,
      );
      expect(
        footer,
        isNot(contains('_medcasesGreen.withOpacity(0.05)')),
      );
      expect(
        footer,
        isNot(contains('ImageFilter.blur(sigmaX: 24')),
      );
    });

    test('Pediatria horizontal-scroll guard remains intact', () {
      final handler = methodBlock(
        main,
        'void _onScrollNotification(ScrollNotification n)',
      );

      expect(
        handler,
        contains('if (n.metrics.axis != Axis.vertical) return;'),
      );
      expect(handler, contains('n is ScrollUpdateNotification'));
      expect(handler, contains('MainShell.navScrollingDown.value'));
    });

    test('one shared footer still serves mobile MainShell', () {
      expect(main, contains('return _FloatingFooter('));
      expect(main, contains('children: _staticScreens'));
      expect(main, contains('currentTab: _tab'));
      expect(main, contains('onTabChange: (t)'));
    });
  });
}
