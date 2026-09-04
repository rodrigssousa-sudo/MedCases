import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MEDCASES IA Plantão final-text continuity V1-B-R0-R1', () {
    late String source;
    late String onDone;

    setUpAll(() {
      source = File('lib/screens/ai_screen.dart').readAsStringSync();

      final start = source.indexOf('onDone: (finalText) {');
      final end = source.indexOf(
        'onStructuredDone: (finalText, clinicalOutput) {',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      onDone = source.substring(start, end);
    });

    test('captures provisional streaming payload before final replacement', () {
      expect(
        onDone,
        contains('final guardiaProvisionalText ='),
      );
      expect(
        onDone,
        contains('_messages[streamingMsgIdx].text.trim()'),
      );

      final snapshot = onDone.indexOf('final guardiaProvisionalText =');
      final finalFormatting =
          onDone.indexOf('String safeFinalText = _longResponse');
      expect(snapshot, lessThan(finalFormatting));
    });

    test('blocks only catastrophic terminal downgrade', () {
      expect(
        onDone,
        contains('continuityFallbackText.length >= 160'),
      );
      expect(
        onDone,
        contains('fallbackLineCount >= 3'),
      );
      expect(
        onDone,
        contains('candidate.length <= 120'),
      );
      expect(
        onDone,
        contains('candidateLineCount <= 2'),
      );
      expect(
        onDone,
        contains('candidate.length * 3 <'),
      );
      expect(
        onDone,
        contains('continuityFallbackText.length'),
      );
    });

    test('uses richer provider-final or provisional source', () {
      expect(
        onDone,
        contains(
          'providerFinalText.length >= guardiaProvisionalText.length',
        ),
      );
      expect(
        onDone,
        contains('? providerFinalText'),
      );
      expect(
        onDone,
        contains(': guardiaProvisionalText'),
      );
    });

    test('continuity decision happens after existing guards but before commit', () {
      final aesthetic =
          onDone.indexOf('_applyPlantaoAestheticGuard(safeFinalText)');
      final continuity = onDone.indexOf('final bool finalPayloadCollapsed =');
      final dispose = onDone.indexOf(
        '_streamingTextNotifier?.dispose()',
        continuity,
      );
      final commit = onDone.indexOf('text: safeFinalText,', dispose);

      expect(aesthetic, greaterThanOrEqualTo(0));
      expect(continuity, greaterThan(aesthetic));
      expect(dispose, greaterThan(continuity));
      expect(commit, greaterThan(dispose));
    });

    test('normal final path still commits and persists safeFinalText', () {
      expect(
        onDone,
        contains('text: safeFinalText,'),
      );
      expect(
        onDone,
        contains('committedAiMessageText = safeFinalText;'),
      );
      expect(
        onDone,
        contains('_saveCurrentSessionToHistory(p);'),
      );
    });

    test('structured DTO handoff remains outside this guard', () {
      expect(
        source,
        contains('onStructuredDone: (finalText, clinicalOutput) {'),
      );
      expect(
        source,
        contains('StructuredOutputTextEquivalence.matches('),
      );
      expect(
        source,
        contains('clinicalOutput: clinicalOutput,'),
      );
    });
  });
}
