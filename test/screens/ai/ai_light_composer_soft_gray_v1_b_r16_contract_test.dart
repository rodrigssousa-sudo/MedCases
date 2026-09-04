import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI Light composer soft gray V1-B-R16', () {
    late String prompt;
    late String ai;

    setUpAll(() {
      prompt = File('lib/screens/ai/widgets/prompt_composer.dart')
          .readAsStringSync();
      ai = File('lib/screens/ai_screen.dart').readAsStringSync();
    });

    test('light composer uses soft-gray surface and dark readable text', () {
      expect(prompt, contains('const Color(0xFFF1F5F9)'));
      expect(prompt, contains('const Color(0xFF1F2937)'));
      expect(prompt, contains('const Color(0xFF64748B)'));
      expect(prompt, contains('const Color(0xFF94A3B8)'));
      expect(prompt, isNot(contains('const Color(0xFF59636E)')));
    });

    test('dark composer keeps previous semantic palette owners', () {
      expect(
        prompt,
        contains('dark ? palette.surfaceSoft : const Color(0xFFF1F5F9)'),
      );
      expect(
        prompt,
        contains('dark ? palette.textPrimary : const Color(0xFF1F2937)'),
      );
      expect(
        prompt,
        contains('dark ? palette.textSecondary : const Color(0xFF64748B)'),
      );
      expect(
        prompt,
        contains(
          '? (widget.hasFocus ? palette.borderActive : palette.border)',
        ),
      );
    });

    test('composer geometry and input behavior are unchanged', () {
      expect(prompt, contains('color: composerSurface'));
      expect(prompt, contains('BorderRadius.circular(24)'));
      expect(prompt, contains('minHeight: 50'));
      expect(prompt, contains('minLines: 1'));
      expect(prompt, contains('maxLines: 6'));
      expect(prompt, contains('fillColor: Colors.transparent'));
      expect(prompt, contains('widget.onVoice'));
      expect(prompt, contains('widget.onSend'));
      expect(prompt, contains('widget.onCancel'));
      expect(prompt, contains('final locked = !widget.isConnected;'));
    });

    test('R13 white timeline remains present in AiScreen', () {
      expect(ai, contains('const Color(0xFFFFFFFF)'));
    });
  });
}
