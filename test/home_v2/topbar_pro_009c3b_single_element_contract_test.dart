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
  test('Topbar IA and PRO use #009C3B in dark and light', () {
    final source = File('lib/main.dart').readAsStringSync();
    final owner = classBlock(source, '_MobileAppBar');

    expect(
      owner,
      contains("text: currentTab == _kAiTab ? 'IA' : 'PRO'"),
    );

    final branch = RegExp(
      r'color\s*:\s*currentTab\s*==\s*_kAiTab\s*'
      r'\?\s*\(\s*dark\s*'
      r'\?\s*const\s+Color\(\s*0xFF009C3B\s*\)\s*'
      r':\s*const\s+Color\(\s*0xFF009C3B\s*\)\s*'
      r'\)\s*'
      r':\s*\(\s*dark\s*'
      r'\?\s*const\s+Color\(\s*0xFF009C3B\s*\)\s*'
      r':\s*const\s+Color\(\s*0xFF009C3B\s*\)\s*'
      r'\)\s*,',
      multiLine: true,
    );

    expect(
      branch.allMatches(owner).length,
      1,
      reason: 'IA and PRO must both use #009C3B in dark/light branches',
    );

    expect(
      RegExp(r'0xFF009C3B').allMatches(owner).length,
      4,
      reason: 'IA dark/light + PRO dark/light must use #009C3B',
    );

    expect(
      owner,
      isNot(contains('0xFF0D6B57')),
      reason: 'old topbar IA green must be absent from _MobileAppBar',
    );

    expect(owner, contains("text: 'MEDCASES '"));
    expect(
      owner,
      contains('// (sem botões — topbar só título)'),
      reason: 'current _MobileAppBar structure must remain unchanged',
    );
  });
}
