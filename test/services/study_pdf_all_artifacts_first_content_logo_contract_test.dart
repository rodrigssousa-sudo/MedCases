import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_pdf_export_service.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF selector defaults to every available artifact', () {
    final screen = read('lib/screens/study_workspace_screen.dart');

    expect(
      screen,
      contains('MEDCASES_STUDY_PDF_DEFAULT_ALL_AVAILABLE_V1'),
    );
    expect(
      screen,
      contains('_selected = Set<StudyArtifactType>.from(widget.available);'),
    );
    expect(
      screen,
      isNot(contains('final preferred = <StudyArtifactType>{')),
    );
  });

  test('PDF exporter keeps every Study artifact family', () {
    final pdf = read('lib/services/study/study_pdf_export_service.dart');

    for (final token in <String>[
      'case StudyArtifactType.visualSummary:',
      'case StudyArtifactType.fullSummary:',
      'case StudyArtifactType.examSummary:',
      'case StudyArtifactType.mindMap:',
      'case StudyArtifactType.flashcards:',
      'case StudyArtifactType.questionsAndAnswers:',
      'case StudyArtifactType.multipleChoice:',
      'case StudyArtifactType.oralExam:',
      'case StudyArtifactType.keyPoints:',
      'case StudyArtifactType.comparisonTable:',
      '_plainArtifactWidgets(',
      '_structuredArtifactWidgets(',
    ]) {
      expect(pdf, contains(token), reason: token);
    }
  });

  test('first page stays content-first and canonical brand repeats', () {
    final pdf = read('lib/services/study/study_pdf_export_service.dart');

    expect(
      pdf,
      contains('MEDCASES_STUDY_PDF_REPEATING_CANONICAL_LOGO_V1'),
    );
    expect(
      pdf,
      contains('MEDCASES_STUDY_PDF_FIRST_PAGE_CONTENT_V1'),
    );
    expect(
      pdf,
      contains('MEDCASES_STUDY_PDF_EDITORIAL_PREMIUM_PRO_V1'),
    );
    expect(pdf, contains("'M+'"));
    expect(pdf, contains("'MedCases Pro'"));
    expect(pdf, contains('MEDCASES_STUDY_PDF_CANONICAL_BRAND_LOCKUP_V2'));
    expect(pdf, contains("PdfColor.fromHex('#C5A365')"));
    expect(pdf, contains('DOSSIER DE ESTUDIO'));
    expect(
      pdf,
      contains('for (var index = 0; index < artifacts.length; index++)'),
    );
  });

  test('all currently generated Study products build in one PDF', () async {
    final now = DateTime.utc(2026, 8, 25);

    StudyArtifact artifact(
      StudyArtifactType type,
      String title,
      String content,
    ) {
      return StudyArtifact(
        id: 'artifact_${type.name}',
        type: type,
        title: title,
        content: content,
        createdAtUtc: now,
        sourceIds: const <String>[],
      );
    }

    final artifacts = <StudyArtifact>[
      artifact(
        StudyArtifactType.visualSummary,
        'Visual summary',
        jsonEncode(<String, Object?>{
          'title': 'Visual summary',
          'overview': 'Core concept.',
          'sections': <Map<String, String>>[
            <String, String>{
              'title': 'Section',
              'body': 'Section content.',
            },
          ],
          'keyPoints': <String>['Key point.'],
          'takeaway': 'Takeaway.',
        }),
      ),
      artifact(
        StudyArtifactType.fullSummary,
        'Full summary',
        'Continuous academic summary content.',
      ),
      artifact(
        StudyArtifactType.examSummary,
        'Exam summary',
        'Exam review content.',
      ),
      artifact(
        StudyArtifactType.flashcards,
        'Flashcards',
        'Pregunta: Example?\nRespuesta: Example.',
      ),
      artifact(
        StudyArtifactType.questionsAndAnswers,
        'Questions and answers',
        'Pregunta: Question 1\nRespuesta: Answer 1',
      ),
      artifact(
        StudyArtifactType.multipleChoice,
        'Multiple choice',
        'Question\nA) One\nB) Two\nAnswer: A',
      ),
      artifact(
        StudyArtifactType.oralExam,
        'Oral exam',
        'Pregunta: Question\nRespuesta: Model answer',
      ),
      artifact(
        StudyArtifactType.keyPoints,
        'Key points',
        '- First point\n- Second point',
      ),
      artifact(
        StudyArtifactType.comparisonTable,
        'Comparison table',
        '| A | B |\n| --- | --- |\n| One | Two |',
      ),
    ];

    final study = Study(
      id: 'study_pdf_all',
      title: 'Study topic',
      locale: 'pt-BR',
      createdAtUtc: now,
      artifacts: artifacts,
    );

    final selected = artifacts.map((item) => item.type).toSet();

    final bytes = await StudyPdfExportService.buildSelected(
      study,
      isEs: false,
      artifactTypes: selected,
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(selected.length, artifacts.length);
  });
}
