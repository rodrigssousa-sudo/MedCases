import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_pdf_export_service.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Unicode theme and premium page-break safeguards remain wired', () {
    final pdf = read('lib/services/study/study_pdf_export_service.dart');

    for (final token in <String>[
      'MEDCASES_STUDY_PDF_UNICODE_THEME_V1',
      'PdfGoogleFonts.openSansRegular()',
      'PdfGoogleFonts.openSansBold()',
      'pw.ThemeData.withFont(',
      'theme: await _unicodeTheme(),',
      'MEDCASES_STUDY_PDF_BREAK_SAFE_TEXT_V1',
      'const hardLimit = 1250;',
      'MEDCASES_STUDY_PDF_EDITORIAL_PREMIUM_PRO_V1',
      'MEDCASES_STUDY_PDF_REPEATING_CANONICAL_LOGO_V1',
      'MEDCASES_STUDY_PDF_FIRST_PAGE_CONTENT_V1',
    ]) {
      expect(pdf, contains(token), reason: token);
    }

    expect(
      'theme: await _unicodeTheme(),'.allMatches(pdf).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('Study PDF catches expose exception metadata without source content',
      () {
    final screen = read('lib/screens/study_workspace_screen.dart');

    expect(
      screen,
      contains('MEDCASES_STUDY_PDF_RUNTIME_DIAGNOSTIC_V1'),
    );
    expect(screen, contains('[StudyPDF][EXPORT_ERROR]'));
    expect(screen, contains('stackTrace: stackTrace'));
  });

  test(
    'realistic long PT/ES Unicode PDF saves across multiple pages',
    () async {
      final now = DateTime.utc(2026, 8, 25);

      final longPt = List<String>.generate(
        90,
        (index) =>
            'Seção ${index + 1}: avaliação, fisiopatologia, diagnóstico, '
            'tratamento, evolução e prognóstico. '
            'Pressão 120/80 mmHg, temperatura 37 °C, saturação 98%, '
            'dose 5 µg/kg/min, variação ±2, relação α/β. '
            'Não omitir negação, indicação, contraindicação ou conclusão.',
      ).join('\n\n');

      final longEs = List<String>.generate(
        90,
        (index) =>
            'Sección ${index + 1}: evaluación, fisiopatología, diagnóstico, '
            'tratamiento, evolución y pronóstico. '
            'Presión 120/80 mmHg, temperatura 37 °C, saturación 98%, '
            'dosis 5 µg/kg/min, variación ±2, relación α/β. '
            'No omitir negación, indicación, contraindicación ni conclusión.',
      ).join('\n\n');

      final visualJson = jsonEncode(<String, Object?>{
        'title': 'Revisão clínica — visão geral',
        'overview': longPt,
        'sections': <Map<String, String>>[
          <String, String>{
            'title': 'Conceitos fundamentais',
            'body': longPt,
          },
          <String, String>{
            'title': 'Revisión en español',
            'body': longEs,
          },
        ],
        'keyPoints': <String>[
          'Atenção à pressão, saturação, função renal e evolução.',
          'Revisar indicação, contraindicação e monitorização.',
        ],
        'takeaway':
            'Síntese final: revisar conteúdo, fontes e contexto educacional.',
      });

      final artifacts = <StudyArtifact>[
        StudyArtifact(
          id: 'visual',
          type: StudyArtifactType.visualSummary,
          title: 'Resumo visual',
          content: visualJson,
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
        StudyArtifact(
          id: 'full',
          type: StudyArtifactType.fullSummary,
          title: 'Resumo completo',
          content: '$longPt\n\n$longEs',
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
        StudyArtifact(
          id: 'qa',
          type: StudyArtifactType.questionsAndAnswers,
          title: 'Perguntas e respostas',
          content: 'Pergunta: Como interpretar?\nResposta: $longPt\n\n$longEs',
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
      ];

      final study = Study(
        id: 'pdf_runtime_long_unicode',
        title: 'Cardiología, nefrologia e revisão clínica',
        locale: 'pt-BR',
        createdAtUtc: now,
        artifacts: artifacts,
      );

      final bytes = await StudyPdfExportService.buildSelected(
        study,
        isEs: false,
        artifactTypes: artifacts.map((item) => item.type).toSet(),
      );

      expect(bytes.length, greaterThan(20000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
