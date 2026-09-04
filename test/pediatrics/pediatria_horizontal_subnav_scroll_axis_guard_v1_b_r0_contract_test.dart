import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String methodBlock(String source, String signature) {
  final start = source.indexOf(signature);
  if (start < 0) {
    throw StateError('start missing: $signature');
  }

  final brace = source.indexOf('{', start);
  if (brace < 0) {
    throw StateError('opening brace missing: $signature');
  }

  var depth = 0;
  for (var i = brace; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(start, i + 1);
      }
    }
  }

  throw StateError('end missing: $signature');
}

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  if (start < 0) {
    throw StateError('class missing: $className');
  }

  final next = RegExp(r'\nclass\s+[A-Za-z0-9_]+')
      .firstMatch(source.substring(start + 1));
  final end = next == null ? source.length : start + 1 + next.start;
  return source.substring(start, end);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final tools = File('lib/screens/tools_screen.dart').readAsStringSync();

  group('Pediatria horizontal subnav scroll axis guard V1-B-R0', () {
    test('global footer scroll engine accepts vertical notifications only', () {
      final handler = methodBlock(
        main,
        'void _onScrollNotification(ScrollNotification n)',
      );

      expect(
        handler,
        contains(
          'PEDIATRIA_HORIZONTAL_SUBNAV_SCROLL_AXIS_GUARD_V1_B_R0',
        ),
      );
      expect(
        handler,
        contains('if (n.metrics.axis != Axis.vertical) return;'),
      );

      expect(handler, contains('n is ScrollUpdateNotification'));
      expect(handler, contains('n.scrollDelta'));
      expect(handler, contains('MainShell.navScrollingDown.value'));
      expect(handler, contains('n is ScrollEndNotification'));
    });

    test('scroll handler cannot navigate or close Pediatria', () {
      final handler = methodBlock(
        main,
        'void _onScrollNotification(ScrollNotification n)',
      );

      for (final forbidden in <String>[
        '_tab =',
        '_onTabChange(',
        'pendingTab.value',
        '_closePediatrics',
        'Navigator.',
        'Navigator.of',
      ]) {
        expect(
          handler,
          isNot(contains(forbidden)),
          reason: 'scroll handler must not navigate via $forbidden',
        );
      }
    });

    test('Pediatria keeps canonical V2 horizontal subnav unchanged', () {
      final nav = classBlock(tools, '_PediatTabRow');

      expect(nav, contains('height: 40'));
      expect(nav, contains('scrollDirection: Axis.horizontal'));
      expect(nav, contains('BoxConstraints(minWidth: 112)'));
      expect(nav, contains('FontWeight.w700'));
      expect(nav, contains('bottom: 9'));
      expect(nav, contains('Color(0xFF10B981)'));
      expect(nav, contains('onTap: () => onSelect(i)'));

      expect(nav, isNot(contains('onHorizontalDrag')));
      expect(nav, isNot(contains('onPan')));
    });

    test('MainShell listener still wraps the mobile IndexedStack', () {
      expect(main, contains('NotificationListener<ScrollNotification>('));
      expect(main, contains('_onScrollNotification(n);'));
      expect(main, contains('child: IndexedStack('));
      expect(main, contains('children: _staticScreens'));
    });
  });
}
