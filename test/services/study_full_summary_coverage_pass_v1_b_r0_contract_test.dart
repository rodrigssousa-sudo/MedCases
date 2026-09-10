import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/services/study/study_artifact_generator.dart')
        .readAsStringSync();
  });

  test('full summary has an explicit final coverage pass', () {
    expect(source, contains('_runFullSummaryCoveragePass('));
    expect(source, contains('AUDITORIA FINAL DE COBERTURA'));
    expect(source, contains('AUDITORÍA FINAL DE COBERTURA'));
    expect(source, contains('NÃO invente dados'));
    expect(source, contains('NÃO use preenchimento'));
    expect(source, contains('NO inventes datos'));
    expect(source, contains('NO agregues relleno'));
  });

  test('coverage pass is restricted to sufficiently long full summaries', () {
    expect(
      source,
      contains(
        'type == StudyArtifactType.fullSummary && sourceCharacters >= 18000',
      ),
    );
    expect(source, contains('_fullSummaryMinimumWords(sourceCharacters)'));
  });

  test('adaptive minimum word targets preserve density without filler', () {
    for (final token in <String>[
      'if (sourceCharacters >= 90000) return 4500;',
      'if (sourceCharacters >= 50000) return 3200;',
      'if (sourceCharacters >= 28000) return 2400;',
      'if (sourceCharacters >= 18000) return 1800;',
      'return 1200;',
    ]) {
      expect(source, contains(token), reason: token);
    }
  });

  test('coverage pass is fail-open and never replaces draft with a shorter one',
      () {
    expect(
        source, contains('if (result.isError || result.text.trim().isEmpty)'));
    expect(source, contains('return draft;'));
    expect(source, contains('if (revisedWords < draftWords)'));
  });

  test('second pass remains outside Plantao token clamp', () {
    final start = source.indexOf(
      'static Future<String> _runFullSummaryCoveragePass',
    );
    final end = source.indexOf(
      'static int _fullSummaryMinimumWords',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final pass = source.substring(start, end);
    expect(pass, contains('isPlantaoMode: false'));
    expect(
      pass,
      contains(
        'StudyArtifactType.fullSummary,\n'
        '          sourceCharacters: sourceCharacters,',
      ),
    );
  });
}
