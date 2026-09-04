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
  test('Mobile AI visible MEDCASES IA header uses #009C3B for IA only', () {
    final source = File(
      'lib/screens/ai/widgets/mobile_ai_action_bar.dart',
    ).readAsStringSync();

    final owner = classBlock(source, 'MobileAiActionBar');

    expect(owner, contains("text: 'MEDCASES '"));
    expect(owner, contains("text: 'IA'"));
    expect(owner, contains('AiConnectionIdentity('));

    final iaBlock = RegExp(
      r"TextSpan\(\s*"
      r"text:\s*'IA'\s*,\s*"
      r"style:\s*TextStyle\(\s*"
      r"fontSize:\s*16\s*,\s*"
      r"fontWeight:\s*FontWeight\.w900\s*,\s*"
      r"letterSpacing:\s*1\.2\s*,\s*"
      r"color:\s*dark\s*"
      r"\?\s*const\s+Color\(\s*0xFF009C3B\s*\)\s*"
      r":\s*const\s+Color\(\s*0xFF009C3B\s*\)\s*,\s*"
      r"\)\s*,\s*"
      r"\)",
      multiLine: true,
    );

    expect(
      iaBlock.allMatches(owner).length,
      1,
      reason: 'visible IA token must use #009C3B in dark and light',
    );

    expect(
      owner,
      isNot(contains('0xFF0D6B57')),
      reason: 'old green must be absent from this visible header owner',
    );
  });
}
