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

    test('automatic naming hooks follow reviewed text', () {
      final screen = read('lib/screens/study_workspace_screen.dart');

      expect(
        'await _maybeAutoNameFromSource(source);'.allMatches(screen).length,
        greaterThanOrEqualTo(3),
      );
      expect(screen, contains('final material = reviewed.text.trim();'));
      expect(screen, contains('if (material.isEmpty) return;'));
    });
  });
}
