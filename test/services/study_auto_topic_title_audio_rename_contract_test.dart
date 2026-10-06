import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_title_suggestion_service.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('Study auto topic title and audio rename', () {
    test('normalizes Markdown-labelled title output', () {
      expect(
        StudyTitleSuggestionService.normalizeCandidate(
          '**Título:** Equilibrio ácido-base.',
        ),
        'Equilibrio ácido-base',
      );

      expect(
        StudyTitleSuggestionService.normalizeCandidate(
          '__Tema:__ Insuficiência cardíaca',
        ),
        'Insuficiência cardíaca',
      );

      expect(
        StudyTitleSuggestionService.normalizeCandidate('Nuevo estudio'),
        isNull,
      );
    });

    test('topic first and area fallback prompt exists', () {
      final service = read(
        'lib/services/study/study_title_suggestion_service.dart',
      );

      expect(service, contains('tema clínico principal'));
      expect(service, contains('área médica principal'));
      expect(service, contains('maxTokens: 80'));
      expect(service, contains("replaceAll('**', '')"));
      expect(service, contains("replaceAll('__', '')"));
    });

    test('manual study title and manual audio rename win', () {
      final screen = read('lib/screens/study_workspace_screen.dart');

      expect(screen, contains('nextStudy.title == originalStudyTitle'));
      expect(
        screen,
        contains('nextSources[index].title == originalSourceTitle'),
      );
      expect(
          screen, contains('Future<void> _renameSource(StudySource source)'));
      expect(screen, contains('Icons.edit_outlined'));
      expect(screen, contains('controller: _title'));
      expect(screen, contains('_study = _study.copyWith(title: name);'));
    });

    test('imported source naming follows extraction; recorded work stays durable', () {
      final screen = read('lib/screens/study_workspace_screen.dart');
      // The former third call belonged to the route-owned recorder. Recording
      // completion now belongs to RecordedStudyTranscription, independently of
      // this screen; do not require the removed synchronous recording path.
      for (final entry in ['Future<void> _addText()', 'Future<void> _pick(']) {
        final body = screen.substring(screen.indexOf(entry));
        final naming = body.indexOf('await _maybeAutoNameFromSource(source);');
        expect(naming, greaterThan(0));
        expect(body.indexOf('_replace(source);'), lessThan(naming));
        expect(body.indexOf('extractedText: extraction.text'), lessThan(naming));
      }
      expect(screen, contains('RecordedStudyTranscription.start(_study, sourceId, handoff)'));
      expect(screen, contains('final material = reviewed.text.trim();'));
      expect(screen, contains('if (material.isEmpty) return;'));
    });
  });
}
