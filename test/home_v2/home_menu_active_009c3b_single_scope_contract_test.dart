import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = RegExp(
    '^class\\s+${RegExp.escape(className)}\\b',
    multiLine: true,
  ).firstMatch(source);

  expect(start, isNotNull, reason: 'class missing: $className');

  final rest = source.substring(start!.end);
  final next = RegExp(
    r'^class\s+[A-Za-z_]\w*\b',
    multiLine: true,
  ).firstMatch(rest);

  final end = next == null ? source.length : start.end + next.start;
  return source.substring(start.start, end);
}

void main() {
  test('Home active and Menu pressed use #009C3B without changing shared IA tokens', () {
    final source = File('lib/main.dart').readAsStringSync();
    final footer = classBlock(source, '_FloatingFooterState');
    final navItem = classBlock(source, '_NavItem');

    expect(
      navItem,
      contains(
        'dark ? const Color(0xFF009C3B) : const Color(0xFF009C3B);',
      ),
      reason: 'active _NavItem color must be new green',
    );

    expect(
      footer,
      contains(
        '? (widget.dark ? const Color(0xFF009C3B) : const Color(0xFF009C3B))',
      ),
      reason: 'Menu pressed icon/label must use new green',
    );

    expect(
      footer,
      contains('static const _medcasesGreen = Color(0xFF0D6B57);'),
      reason: 'shared dark token must remain untouched',
    );
    expect(
      footer,
      contains('static const _menuLightGreen = Color(0xFF0D6B57);'),
      reason: 'shared light token must remain untouched',
    );

    expect(
      RegExp(r'_NavItem\s*\(').allMatches(footer).length,
      2,
      reason: '_NavItem active color is safe only while footer has the two audited calls',
    );
    expect(
      footer,
      contains('isActive: widget.currentTab == 0,'),
      reason: 'normal-row Home is the only active _NavItem call',
    );
    expect(
      footer,
      contains('isActive: false, // nunca ativo quando estamos na aba IA'),
      reason: 'AI-row Home remains permanently inactive',
    );

    expect(
      navItem,
      contains(
        'final inactiveColor = dark ? Colors.white : const Color(0xFF4B5563);',
      ),
      reason: 'inactive state must remain unchanged',
    );

    expect(footer, contains('Icons.menu_rounded'));
    expect(footer, contains("widget.lang == 'es' ? 'Menú' : 'Menu'"));
  });
}
