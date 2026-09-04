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
  test('live visible sidebar brand green is #009C3B with excluded surfaces preserved', () {
    final source = File('lib/main.dart').readAsStringSync();

    final drawer = classBlock(source, '_AppDrawerState');
    final header = classBlock(source, '_DrawerHeader');
    final premium = classBlock(source, '_DrawerItemPremium');
    final lang = classBlock(source, '_LangBadge');
    final theme = classBlock(source, '_ThemeToggle');
    final onOff = classBlock(source, '_OnOffToggle');
    final quick = classBlock(source, '_DrawerQuickAccess');
    final offline = classBlock(source, '_OfflineDrawerCardState');
    final about = classBlock(source, '_AboutAppSheet');

    expect(
      'iconColor: const Color(0xFF009C3B),'
          .allMatches(drawer)
          .length,
      5,
      reason: 'five directly visible drawer row icons must use the new brand green',
    );

    expect(
      header,
      contains('static const _kGreen = Color(0xFF009C3B);'),
    );
    expect(
      premium,
      contains('const accent = Color(0xFF009C3B);'),
    );
    expect(
      lang,
      contains('const accent = Color(0xFF009C3B);'),
    );
    expect(
      theme,
      contains('const Color(0xFF009C3B)'),
    );
    expect(
      onOff,
      contains('const Color(0xFF009C3B)'),
    );

    // Photo selection/action surfaces were explicitly excluded from this cutover.
    expect(
      drawer,
      contains('activeControlsWidgetColor: const Color(0xFF0D6B57),'),
    );
    expect(
      drawer,
      contains('color: Color(0xFF0D6B57),'),
    );
    expect(
      '0xFF0D6B57'.allMatches(drawer).length,
      2,
      reason: 'only the two excluded photo-action old greens may remain in _AppDrawerState',
    );

    // Dead/commented quick access stays untouched.
    expect(
      quick,
      contains('iconColor: const Color(0xFF0D6B57),'),
    );
    expect(
      quick,
      contains('0xFF1A2E22'),
      reason: 'dark structural divider must remain unchanged',
    );

    // Secondary About surface is outside the direct drawer cutover.
    expect(
      about,
      contains('static const _accent = Color(0xFF0D6B57);'),
    );

    // Offline semantic/status palette remains blue/red/gray.
    expect(offline, contains('0xFF1D4ED8'));
    expect(offline, contains('0xFFB91C1C'));
    expect(offline, isNot(contains('0xFF009C3B')));
  });
}
