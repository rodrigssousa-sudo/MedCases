import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final token = 'class $className';
  final start = source.indexOf(token);
  expect(start, greaterThanOrEqualTo(0), reason: className);
  final next = source.indexOf('\nclass ', start + token.length);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  final study =
      File('lib/screens/study_workspace_screen.dart').readAsStringSync();

  group('Study workspace premium visual clean V1-B-R6', () {
    test('uses wider premium canvas and calmer source grid', () {
      final owner = classBlock(study, '_StudyWorkspaceScreenState');

      expect(
        owner,
        contains(
          'padding: EdgeInsets.fromLTRB(\n'
          '          12,\n'
          '          12,\n'
          '          12,',
        ),
      );
      expect(owner, contains('final width = (constraints.maxWidth - 12) / 3;'));
      expect(owner, contains('spacing: 6,'));
      expect(owner, contains('runSpacing: 6,'));
    });

    test('source actions are softer, roomier and rounded', () {
      final source = classBlock(study, '_SourceAction');

      expect(source, contains('BorderRadius.circular(12)'));
      expect(
        source,
        contains(
          'padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9)',
        ),
      );
      expect(source, contains('color: soft'));
      expect(source, contains('width: 0.5'));
    });

    test('mind map premium shell is patched in the State owner', () {
      final mind = classBlock(study, '_MindMapPanelState');

      expect(
        mind,
        contains('padding: const EdgeInsets.fromLTRB(14, 12, 14, 14)'),
      );
      expect(mind, contains('BorderRadius.circular(12)'));
      expect(
        mind,
        contains('widget.border.withValues(alpha: 0.28)'),
      );
    });

    test('result mode rail uses premium rounded geometry', () {
      final bar = classBlock(study, '_StudyResultModeBar');

      expect(bar, contains('height: 40'));
      expect(bar, contains('padding: const EdgeInsets.all(4)'));
      expect(bar, contains('BorderRadius.circular(12)'));
      expect(bar, contains('BorderRadius.circular(9)'));
    });

    test('artifact cards improve reading without touching content', () {
      final card = classBlock(study, '_MarkdownStudyArtifactCard');

      expect(
        card,
        contains('padding: const EdgeInsets.fromLTRB(14, 12, 14, 14)'),
      );
      expect(card, contains('BorderRadius.circular(12)'));
      expect(card, contains('fontSize: 12.2'));
      expect(card, contains('fontSize: 10.8, height: 1.5'));
      expect(card, contains('MarkdownBody('));
      expect(card, contains('data: artifact.content'));
    });

    test('preserves every Study functional family', () {
      for (final token in <String>[
        'StudyImportedAudioPipeline.process(',
        'StudyLargeFileExtractionService.binaryStream(',
        'StudyMultimodalExtractionService.binary(',
        'StudyArtifactGenerator.generate(',
        'StudyPdfExportService.shareSelected(',
        'StudyLibraryService.save(',
        'StudyArtifactType.visualSummary',
        'StudyArtifactType.fullSummary',
        'StudyArtifactType.examSummary',
        'StudyArtifactType.flashcards',
        'StudyArtifactType.questionsAndAnswers',
        'StudyArtifactType.multipleChoice',
        'StudyArtifactType.oralExam',
        'StudyArtifactType.keyPoints',
        'StudyArtifactType.comparisonTable',
      ]) {
        expect(study, contains(token), reason: token);
      }
    });
  });
}
