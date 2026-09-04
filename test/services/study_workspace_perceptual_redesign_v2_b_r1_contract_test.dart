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

  group('Study workspace perceptual redesign V2-B-R1', () {
    test('source grid is visibly two-column', () {
      final owner = classBlock(study, '_StudyWorkspaceScreenState');
      expect(owner, contains('final width = (constraints.maxWidth - 8) / 2;'));
      expect(owner, isNot(contains('/ 3;')));
    });

    test('source actions are large primary tiles', () {
      final source = classBlock(study, '_SourceAction');
      expect(source, contains('height: 82'));
      expect(source, contains('size: 22'));
      expect(source, contains('fontSize: 11.3'));
      expect(source, isNot(contains('size: 16')));
    });

    test('workspace header has editorial hierarchy', () {
      final header = classBlock(study, '_WorkspaceHeader');
      expect(header, contains('fontSize: 20'));
      expect(header, contains('fontSize: 11.5'));
    });

    test('AI composer is vertical and full-width', () {
      final owner = classBlock(study, '_StudyWorkspaceScreenState');
      final ia = owner.indexOf(
        "title: widget.isEs ? 'Generar con IA' : 'Gerar com IA'",
      );
      final results = owner.indexOf('if (_study.artifacts.isNotEmpty)', ia);
      expect(ia, greaterThanOrEqualTo(0));
      expect(results, greaterThan(ia));
      final segment = owner.substring(ia, results);
      expect(segment, contains('Column('));
      expect(
        segment,
        contains('crossAxisAlignment: CrossAxisAlignment.stretch'),
      );
      expect(segment, contains('height: 46'));
      expect(
        segment,
        contains("widget.isEs ? 'Generar material' : 'Gerar material'"),
      );
      expect(segment, isNot(contains('const SizedBox(width: 6)')));
    });

    test('functional Study families remain present', () {
      for (final token in <String>[
        'StudyImportedAudioPipeline.process(',
        'StudyLargeFileExtractionService.binaryStream(',
        'StudyMultimodalExtractionService.binary(',
        'StudyArtifactGenerator.generate(',
        'StudyPdfExportService.shareSelected(',
        'StudyLibraryService.save(',
        'onTap: _busy ? null : _recordLecture',
        'onPressed: _busy ? null : _generate',
        'onPressed: _busy ? null : _exportPdf',
      ]) {
        expect(study, contains(token), reason: token);
      }
    });
  });
}
