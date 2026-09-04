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

  group('Study light background white soft card delta V3-B-R4', () {
    test('uses white page and subtle offwhite card surfaces in light', () {
      final owner = classBlock(study, '_StudyWorkspaceScreenState');
      expect(
        owner,
        contains(
          'final page = dark ? const Color(0xFF1A1D23) : Colors.white;',
        ),
      );
      expect(
        owner,
        contains(
          'final surface = dark ? const Color(0xFF252930) '
          ": const Color(0xFFF7F9FB);",
        ),
      );
    });

    test('keeps the current source geometry intact', () {
      final owner = classBlock(study, '_StudyWorkspaceScreenState');
      final source = classBlock(study, '_SourceAction');
      expect(owner, contains('final width = (constraints.maxWidth - 8) / 2;'));
      expect(owner, contains('spacing: 0.7'));
      expect(owner, contains('runSpacing: 0.7'));
      expect(source, contains('height: 90'));
      expect(source, contains('color: dark ? soft : surface'));
    });

    test('primary result surfaces now use subtle surface instead of pure white',
        () {
      final mode = classBlock(study, '_StudyResultModeBar');
      final visual = classBlock(study, '_VisualSummaryPanel');
      final markdown = classBlock(study, '_MarkdownStudyArtifactCard');
      final callout = classBlock(study, '_ResultGenerateCallout');

      expect(mode, contains('color: surface,'));
      expect(visual, contains('color: surface,'));
      expect(markdown, contains('color: surface,'));
      expect(callout, contains('color: surface,'));

      expect(
        markdown,
        contains(
            'final dark = Theme.of(context).brightness == Brightness.dark;'),
      );
      expect(
        callout,
        contains(
            'final dark = Theme.of(context).brightness == Brightness.dark;'),
      );
    });

    test('preserves texts and Study functions', () {
      for (final token in <String>[
        "label: widget.isEs ? 'Grabar clase' : 'Gravar aula'",
        "label: widget.isEs ? 'Audio' : 'Áudio'",
        "label: 'PDF'",
        "label: widget.isEs ? 'Imagen' : 'Imagem'",
        "label: 'Texto'",
        "title: widget.isEs ? 'Generar con IA' : 'Gerar com IA'",
        "widget.isEs ? 'Generar material' : 'Gerar material'",
        'StudyImportedAudioPipeline.process(',
        'StudyArtifactGenerator.generate(',
        'StudyPdfExportService.shareSelected(',
        'onTap: _busy ? null : _recordLecture',
        'onPressed: _busy ? null : _generate',
      ]) {
        expect(study, contains(token), reason: token);
      }
    });
  });
}
