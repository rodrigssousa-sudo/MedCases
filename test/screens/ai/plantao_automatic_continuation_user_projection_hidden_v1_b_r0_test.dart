import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantao automatic continuation user projection hidden V1-B-R0', () {
    late String screen;

    setUpAll(() {
      screen = File('lib/screens/ai_screen.dart').readAsStringSync();
    });

    test('automatic Plantao continuation is visually hidden', () {
      expect(
        screen,
        contains('if (!_longResponse && hasAutomaticVisibleProjection)'),
      );
      expect(
        screen,
        contains("'msg_\${msg.id}_plantao_automatic_user_hidden'"),
      );
    });

    test('direct Plantao user question remains visually hidden', () {
      expect(
        screen,
        contains('if (!_longResponse && !hasAutomaticVisibleProjection)'),
      );
      expect(
        screen,
        contains("'msg_\${msg.id}_plantao_direct_user_hidden'"),
      );
    });

    test('questions continuation special projection remains hidden', () {
      expect(
        screen,
        contains('if (!_longResponse && isQuestionsButtonProjection)'),
      );
      expect(
        screen,
        contains("'msg_\${msg.id}_plantao_questions_button_hidden'"),
      );
    });

    test('canonical and display provenance remain intact', () {
      expect(screen, contains("msg.userDisplayText?.trim()"));
      expect(
        RegExp(
          r'UserMessageDisplayPolicy\.visibleText\(\s*msg\.text,\s*\)',
          multiLine: true,
        ).hasMatch(screen),
        isTrue,
      );
      expect(screen, contains('editText: msg.text'));
      expect(screen, contains('onCopy: () => _copyMsg(userVisibleText)'));
    });

    test('Study rendering is not hidden by Plantao projection gates', () {
      expect(
        screen,
        isNot(
          contains('if (_longResponse && hasAutomaticVisibleProjection)'),
        ),
      );
      expect(
        screen,
        isNot(
          contains('if (_longResponse && !hasAutomaticVisibleProjection)'),
        ),
      );
    });
  });
}
