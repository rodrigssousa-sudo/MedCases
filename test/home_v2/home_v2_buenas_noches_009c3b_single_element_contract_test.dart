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
  test(
    'Home IA greeting uses canonical #009C3B for every PT/ES daypart',
    () {
      final source = File(
        'lib/home_v2/components/chat/inline_chat_view.dart',
      ).readAsStringSync();

      final owner = classBlock(source, '_InlineGreetingLine');

      for (final greeting in const <String>[
        "'Buena madrugada'",
        "'Boa madrugada'",
        "'Buen día'",
        "'Bom dia'",
        "'Buenas tardes'",
        "'Boa tarde'",
        "'Buenas noches'",
        "'Boa noite'",
      ]) {
        expect(owner, contains(greeting), reason: greeting);
      }

      expect(owner, contains('text: greeting,'));

      expect(
        owner,
        contains('color: const Color(0xFF009C3B),'),
        reason: 'all greeting dayparts must share canonical green',
      );

      expect(
        owner,
        isNot(
          contains(
            "color: greeting == 'Buenas noches' || greeting == 'Boa noite'",
          ),
        ),
        reason: 'night-only green condition must be removed',
      );

      expect(
        RegExp(r'0xFF009C3B').allMatches(owner).length,
        1,
        reason: 'one canonical literal in the greeting owner',
      );

      expect(
        owner,
        contains("text: ', \$normalizedName',"),
        reason: 'name/comma span must stay untouched',
      );

      expect(
        owner,
        contains('color: palette.textPrimary,'),
        reason: 'name/comma color must stay untouched',
      );
    },
  );
}
