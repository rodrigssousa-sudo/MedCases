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
  test('Home IA night greeting has exact #009C3B parity in ES and PT', () {
    final source = File(
      'lib/home_v2/components/chat/inline_chat_view.dart',
    ).readAsStringSync();

    final owner = classBlock(source, '_InlineGreetingLine');

    expect(
      owner,
      contains("return isEs ? 'Buenas noches' : 'Boa noite';"),
      reason: 'ES/PT night copy pair must remain intact',
    );

    expect(
      owner,
      contains(
        "color: greeting == 'Buenas noches' || greeting == 'Boa noite'\n"
        "                  ? const Color(0xFF009C3B)\n"
        "                  : _homeAccent(palette),",
      ),
      reason: 'PT must reuse the exact green already homologated in ES',
    );

    expect(
      RegExp(r'0xFF009C3B').allMatches(owner).length,
      1,
      reason: 'owner must keep a single canonical green literal',
    );

    for (final nonNightGreeting in const <String>[
      "'Buena madrugada'",
      "'Boa madrugada'",
      "'Buen día'",
      "'Bom dia'",
      "'Buenas tardes'",
      "'Boa tarde'",
    ]) {
      expect(
        owner,
        contains(nonNightGreeting),
        reason: 'non-night wording must remain intact: $nonNightGreeting',
      );
    }

    expect(
      owner,
      contains(': _homeAccent(palette),'),
      reason: 'non-night greeting fallback must remain intact',
    );

    expect(
      owner,
      contains("text: ', \$normalizedName',"),
      reason: 'user name/comma span must remain intact',
    );

    expect(
      owner,
      contains('color: palette.textPrimary,'),
      reason: 'user name color must remain intact',
    );
  });
}
