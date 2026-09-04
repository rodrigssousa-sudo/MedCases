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

  group('Study light surface hierarchy white foreground V3-B-R1', () {
    test('keeps the existing light background untouched', () {
      expect(
        study,
        contains(
          'final page = dark ? const Color(0xFF1A1D23) '
          ': const Color(0xFFECF1F3);',
        ),
      );
    });

    test('source grid uses a minimal 0.7px separation', () {
      final owner = classBlock(study, '_StudyWorkspaceScreenState');
      expect(owner, contains('spacing: 0.7'));
      expect(owner, contains('runSpacing: 0.7'));
      expect(owner, contains('final width = (constraints.maxWidth - 8) / 2;'));
    });

    test('source cards are larger white foreground blocks in light mode', () {
      final source = classBlock(study, '_SourceAction');
      expect(source, contains('height: 90'));
      expect(
        source,
        contains(
          'final dark = Theme.of(context).brightness == Brightness.dark;',
        ),
      );
      expect(source, contains('color: dark ? soft : surface'));
      expect(source, contains(': null'));
    });

    test('primary result surfaces remove visible borders in light mode', () {
      final mode = classBlock(study, '_StudyResultModeBar');
      final visual = classBlock(study, '_VisualSummaryPanel');
      final markdown = classBlock(study, '_MarkdownStudyArtifactCard');
      final callout = classBlock(study, '_ResultGenerateCallout');

      expect(mode, contains('color: dark ? surface : Colors.white'));
      expect(visual, contains('color: dark ? surface : Colors.white'));
      expect(markdown, contains('color: dark ? surface : Colors.white'));
      expect(callout, contains('color: dark ? surface : Colors.white'));

      expect(mode, contains(': null'));
      expect(visual, contains(': null'));
      expect(markdown, contains(': null'));
      expect(callout, contains(': null'));
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
