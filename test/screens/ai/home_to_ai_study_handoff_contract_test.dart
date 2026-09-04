import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String region(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start);

  expect(start, greaterThanOrEqualTo(0), reason: startMarker);
  expect(end, greaterThan(start), reason: endMarker);

  return source.substring(start, end);
}

void main() {
  late String home;
  late String ai;

  setUpAll(() {
    home = File('lib/screens/home_screen.dart').readAsStringSync();
    ai = File('lib/screens/ai_screen.dart').readAsStringSync();
  });

  group('Home → IA Study handoff contract', () {
    test('NEXT_ACTION metadata is removed from Home visible text', () {
      final matches = RegExp(
        r'NEXT_ACTION_\(\?:LABEL\|PROMPT\)',
      ).allMatches(home);

      expect(matches.length, greaterThanOrEqualTo(2));
      expect(
        home,
        contains(
          r"r'^\s*\[NEXT_ACTION_(?:LABEL|PROMPT):[^\n]*(?:\]\s*)?$'",
        ),
      );
    });

    test('pendingHistory enters IA directly in confirmed Study mode', () {
      final block = region(
        ai,
        'void _onPendingHistory()',
        '// ── ORDEM 53 M2:',
      );

      for (final token in const [
        '_longResponse = true;',
        '_modeConfirmed = true;',
        '_modeReselectionPending = false;',
        '_restoredModeSelectionPending = false;',
      ]) {
        expect(block, contains(token), reason: token);
      }

      for (final forbidden in const [
        '_commitResponseMode(',
        'clearAiHistory()',
        '_startNewChat(',
      ]) {
        expect(block, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('handoff rebuilds canonical provider context with assistant role', () {
      final block = region(
        ai,
        'void _onPendingHistory()',
        '// ── ORDEM 53 M2:',
      );

      expect(block, contains('p.rebuildAiHistoryFromMessages('));
      expect(block, contains("message['role'] == 'user'"));
      expect(block, contains("message['role'] == 'ai'"));
      expect(
        block,
        contains("message['role'] == 'ai' ? 'assistant' : 'user'"),
      );
      expect(block, contains("'content': message['text'] ?? ''"));
    });

    test('IA response identity mirrors Home lifecycle and accent', () {
      final header = region(
        ai,
        'class _AiResponseIdentityHeader extends StatelessWidget',
        'class _AiHomeGreeting extends StatelessWidget',
      );

      for (final token in const [
        'required this.isStreaming',
        "isEs ? 'GENERANDO RESPUESTA' : 'GERANDO RESPOSTA'",
        "isEs ? 'RESPUESTA COMPLETADA' : 'RESPOSTA CONCLUÍDA'",
        'Icons.psychology_alt_rounded',
        'final accent = palette.accent;',
        'color: accent',
        'fontSize: 10.2',
        'fontWeight: FontWeight.w800',
        'letterSpacing: 1.2',
      ]) {
        expect(header, contains(token), reason: token);
      }
    });
  });
}
