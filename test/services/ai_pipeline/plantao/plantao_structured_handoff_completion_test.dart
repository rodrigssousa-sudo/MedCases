import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing: $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  group('Phase3K-C5A-R9C structured UI handoff', () {
    test('committed cutover finalizes text before attaching DTO', () {
      final source =
          File('lib/providers/app_provider.dart').readAsStringSync();

      final committed = _between(
        source,
        'case PlantaoBufferedCutoverDisposition.committed:',
        'case PlantaoBufferedCutoverDisposition.rejectedAfterStart:',
      );

      final onDoneIndex = committed.indexOf(
        'onDone(phase3kResult.finalText);',
      );
      final onStructuredIndex = committed.indexOf(
        'onStructuredDone(',
      );

      expect(onDoneIndex, isNonNegative);
      expect(onStructuredIndex, isNonNegative);
      expect(onDoneIndex, lessThan(onStructuredIndex));
      expect(
        RegExp(
          r'onDone\(phase3kResult\.finalText\);',
        ).allMatches(committed),
        hasLength(1),
      );
      expect(
        committed,
        isNot(
          contains(
            '} else {\n            onDone(phase3kResult.finalText);',
          ),
        ),
      );
    });

    test('AiScreen requires onDone state before structured attach', () {
      final source =
          File('lib/screens/ai_screen.dart').readAsStringSync();

      final done = _between(
        source,
        'onDone: (finalText) {',
        'onStructuredDone: (finalText, clinicalOutput) {',
      );
      final structured = _between(
        source,
        'onStructuredDone: (finalText, clinicalOutput) {',
        'onError: (errorMsg) {',
      );

      expect(done, contains('_isStreaming ='));
      expect(done, contains('committedAiMessageId ='));
      expect(done, contains('committedAiMessageText ='));
      expect(structured, contains('final messageId = committedAiMessageId;'));
      expect(
        structured,
        contains('final committedText = committedAiMessageText;'),
      );
      expect(
        structured,
        contains("reason=final_text_not_equivalent"),
      );
    });

    test('legacy core already preserves done then structured order', () {
      final source =
          File('lib/providers/app_provider.dart').readAsStringSync();

      final coreStart = source.indexOf(
        'Future<bool> _sendAiMessageLegacyCore(',
      );
      expect(coreStart, isNonNegative);

      final core = source.substring(coreStart);
      final onDoneIndex = core.indexOf('onDone(guardedText);');
      final onStructuredIndex = core.indexOf(
        'onStructuredDone?.call(guardedText, guardedClinicalOutput);',
      );

      expect(onDoneIndex, isNonNegative);
      expect(onStructuredIndex, isNonNegative);
      expect(onDoneIndex, lessThan(onStructuredIndex));
    });

    test('HARD STOP remains final-only in renderer', () {
      final source = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'if (!isStreaming || rawText.isEmpty) return rawText;',
        ),
      );
      expect(
        source,
        contains(
          'return rawText.substring(0, boundary.start).trimRight();',
        ),
      );
      expect(source, contains("'Red flags/escalamiento'"));
      expect(source, contains("'Red flags/escalonamento'"));
    });
  });
}
