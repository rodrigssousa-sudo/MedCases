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
  test('AI internal greeting lead uses canonical #009C3B in PT and ES', () {
    final source = File('lib/screens/ai_screen.dart').readAsStringSync();
    final greeting = classBlock(source, '_AiHomeGreeting');

    expect(greeting, contains('text: greetingLead,'));

    expect(
      greeting,
      contains('style: const TextStyle(color: Color(0xFF009C3B)),'),
      reason: 'PT and ES greeting lead must share canonical #009C3B',
    );

    expect(
      greeting,
      isNot(contains("greetingLead.startsWith('Buenas noches')")),
      reason: 'greeting color must not depend on language or greeting text',
    );

    expect(
      greeting,
      contains('text: greetingName,'),
      reason: 'user name rendering must remain present',
    );

    expect(
      greeting,
      contains('style: TextStyle(color: palette.textPrimary),'),
      reason: 'user name color must remain unchanged',
    );

    for (final token in const <String>[
      "period = 'Buena madrugada';",
      "period = 'Buenos días';",
      "period = 'Buenas tardes';",
      "period = 'Buenas noches';",
      "period = 'Boa madrugada';",
      "period = 'Bom dia';",
      "period = 'Boa tarde';",
      "period = 'Boa noite';",
    ]) {
      expect(
        source,
        contains(token),
        reason: 'greeting wording/time contract must remain intact: $token',
      );
    }

    expect(
      source,
      contains("'Describe el caso o la duda clínica.'"),
      reason: 'Spanish subtitle must remain intact',
    );
    expect(
      source,
      contains("'Descreva o caso ou a dúvida clínica.'"),
      reason: 'Portuguese subtitle must remain intact',
    );
  });
}
