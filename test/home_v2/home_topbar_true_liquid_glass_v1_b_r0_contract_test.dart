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

  group('Home topbar True Liquid Glass V1-B-R0', () {
    test('Home-only callsite remains exclusive', () {
      expect(main, contains('final isHome = _tab == 0;'));
      expect(
        RegExp(r'appBar:\s*isHome\s*\?\s*PreferredSize\(', dotAll: true)
            .hasMatch(main),
        isTrue,
      );
      expect(main, contains('isHome: true,'));

      final tokenCount = RegExp(r'_MobileAppBar\(').allMatches(main).length;
      expect(tokenCount, 2); // constructor + one productive call
    });

    test('Home topbar owns Liquid Glass material', () {
      final bar = classBlock(main, '_MobileAppBar');

      expect(
        bar,
        contains('MEDCASES_HOME_TOPBAR_TRUE_LIQUID_GLASS_V1_B_R0'),
      );
      expect(
        bar,
        contains('Color(0xFF161B22).withValues(alpha: 0.58)'),
      );
      expect(
        bar,
        contains('Colors.white.withValues(alpha: 0.56)'),
      );
      expect(
        bar,
        contains('ImageFilter.blur(sigmaX: 16, sigmaY: 16)'),
      );
      expect(bar, contains('gradient: LinearGradient('));
      expect(bar, contains('liquidSpecular'));
      expect(bar, contains('blurRadius: 14'));
      expect(bar, contains('spreadRadius: -8'));
    });

    test('canonical Home geometry stays frozen', () {
      final bar = classBlock(main, '_MobileAppBar');

      expect(bar, contains('SafeArea('));
      expect(bar, contains('bottom: false'));
      expect(bar, contains('height: 48'));
      expect(
        bar,
        contains('EdgeInsets.symmetric(horizontal: 12)'),
      );
      expect(bar, contains('alignment: Alignment.center'));
      expect(bar, contains('fontSize: 16'));
      expect(bar, contains('FontWeight.w900'));
      expect(bar, contains('letterSpacing: 1.2'));
      expect(bar, contains('width: 0.7'));
    });

    test('global action-bar Liquid Glass remains untouched', () {
      final footer = classBlock(main, '_FloatingFooterState');

      expect(
        footer,
        contains(
          'MEDCASES_GLOBAL_ACTION_BAR_TRUE_LIQUID_GLASS_V1_B_R1',
        ),
      );
      expect(
        footer,
        contains('ImageFilter.blur(sigmaX: 16, sigmaY: 16)'),
      );
      expect(footer, contains('static const _barHeightFull = 50.0;'));
      expect(footer, contains('static const _barHeightShrunk = 38.0;'));
    });

    test('internal topbars are not the patched owner', () {
      final bar = classBlock(main, '_MobileAppBar');
      expect(bar, isNot(contains('_ToolsTopBar')));
      expect(bar, isNot(contains('_NotesAudioWorkspace')));
    });
  });
}
