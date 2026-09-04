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
  test('Home IA send arrow active color is #009C3B only', () {
    final source = File(
      'lib/home_v2/components/chat/inline_chat_view.dart',
    ).readAsStringSync();

    final composer = classBlock(source, '_InlineComposer');

    expect(
      composer,
      contains('Icons.arrow_upward_rounded'),
    );

    expect(
      composer,
      contains('onTap: thinking ? null : onSend,'),
      reason: 'send behavior must remain unchanged',
    );

    expect(
      composer,
      contains(
        'thinking ? palette.textSecondary : const Color(0xFF009C3B),',
      ),
      reason: 'only active send arrow color changes',
    );

    expect(
      composer,
      isNot(
        contains(
          'thinking ? palette.textSecondary : _homeAccent(palette),',
        ),
      ),
    );

    expect(composer, contains('width: 32,'));
    expect(composer, contains('height: 32,'));
    expect(composer, contains('size: 19,'));

    expect(
      composer,
      contains('color: _homeComposerUnifiedFill(palette),'),
      reason: 'composer surface is outside this color change',
    );

    expect(
      source,
      contains("greeting == 'Buenas noches'"),
      reason: 'previously homologated greeting must remain untouched',
    );
  });
}
