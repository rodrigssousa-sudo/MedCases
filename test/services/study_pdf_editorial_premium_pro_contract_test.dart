import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_pdf_export_service.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('premium editorial identity replaces raw text dump surface', () {
    final pdf = read('lib/services/study/study_pdf_export_service.dart');

    for (final token in <String>[
      'MEDCASES_STUDY_PDF_EDITORIAL_PREMIUM_PRO_V1',
      'MEDCASES_STUDY_PDF_CANONICAL_BRAND_LOCKUP_V2',
      'MEDCASES_STUDY_PDF_EDITORIAL_COMPONENTS_V1',
      'DOSSIER DE ESTUDIO',
      'DOSSIÊ DE ESTUDO',
      '_artifactSectionHeader',
      '_editorialSubheading',
      '_premiumBullet',
      '_structuredArtifactWidgets',
      'MEDCASES_STUDY_PDF_STRUCTURED_RAW_SOURCE_V1',
      '_markdownTableWidgets',
      '_questionAnswerBlock',
    ]) {
      expect(pdf, contains(token), reason: token);
    }
    expect(
      pdf,
      isNot(
        contains(
          '_structuredArtifactWidgets(\n        _artifactPlainText(artifact.content)',
        ),
      ),
    );
  });

  test('raw Study markup has safe normalization and real table parsing', () {
    final pdf = read('lib/services/study/study_pdf_export_service.dart');

    expect(pdf, contains('_isMarkdownTableLine'));
    expect(pdf, contains('_isMarkdownTableSeparator'));
    expect(pdf, contains('_tableCells'));
    expect(pdf, contains(r"RegExp(r'<br\s*/?>'"));
    expect(pdf, contains(r".replaceAll(r'$\rightarrow$', ' -> ')"));
    expect(pdf, contains(r".replaceAll(r'\rightarrow', ' -> ')"));
    expect(pdf, contains(".replaceAll('→', ' -> ')"));
    expect(pdf, contains(".replaceAll('α', 'alpha')"));
    expect(pdf, contains(".replaceAll('β', 'beta')"));
    expect(pdf, contains(".replaceAll('Δ', 'Delta')"));
  });

  test('page architecture stays content-first, branded and Unicode', () {
    final pdf = read('lib/services/study/study_pdf_export_service.dart');

    expect(pdf, contains('theme: await _unicodeTheme(),'));
    expect(pdf, contains('PdfGoogleFonts.openSansRegular()'));
    expect(pdf, contains('PdfGoogleFonts.openSansBold()'));
    expect(pdf, contains("'M+'"));
    expect(pdf, contains("'MedCases Pro'"));
    expect(pdf, contains('MEDCASES_STUDY_PDF_CANONICAL_BRAND_LOCKUP_V2'));
    expect(
      pdf,
      contains('Material educativo · Revise las fuentes originales'),
    );
    expect(pdf, contains('context.pageNumber'));
    expect(
      pdf,
      contains('MEDCASES_STUDY_PDF_REPEATING_CANONICAL_LOGO_V1'),
    );
    expect(
      pdf,
      contains('MEDCASES_STUDY_PDF_FIRST_PAGE_CONTENT_V1'),
    );
  });

  test(
    'premium runtime saves long prose, bullets, Q&A and Markdown table',
    () async {
      final now = DateTime.utc(2026, 8, 25);

      final summary = List<String>.generate(
        38,
        (index) => 'La homeostasis ácido-base mantiene el pH cercano a 7.4. '
            'Sección ${index + 1}: evaluación, fisiopatología, diagnóstico '
            'y tratamiento con atención a presión, saturación y evolución.',
      ).join('\n\n');

      const structured = r'''
FISIOLOGÍA Y CONCEPTOS BÁSICOS

Objetivo fisiológico:
Mantener el pH plasmático cercano a 7.4.

- Sistemas buffer: segundos.
- Pulmón: minutos.
- Riñón: horas/días.

Pregunta: ¿Cuál es la fórmula de Winter?
Respuesta: PCO2 esperada = 1.5 × HCO3 + 8 ± 2.

| Parámetro | Normal | Comentario |
| :--- | :--- | :--- |
| pH | 7.35 - 7.45 | Equilibrio ácido-base |
| HCO3 | 22 - 26 mEq/L | Componente metabólico |
| PCO2 | 35 - 45 mmHg | Componente respiratorio |

Depleción de volumen $\rightarrow$ activación del SRAA.
''';

      final artifacts = <StudyArtifact>[
        StudyArtifact(
          id: 'full',
          type: StudyArtifactType.fullSummary,
          title: 'Resumen completo',
          content: summary,
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
        StudyArtifact(
          id: 'key',
          type: StudyArtifactType.keyPoints,
          title: 'Puntos clave',
          content: structured,
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
        StudyArtifact(
          id: 'table',
          type: StudyArtifactType.comparisonTable,
          title: 'Tabla comparativa',
          content: structured,
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
        StudyArtifact(
          id: 'visual',
          type: StudyArtifactType.visualSummary,
          title: 'Resumen visual',
          content: jsonEncode(<String, Object?>{
            'title': 'Ácido-base',
            'overview': 'Visión general clara, breve y clínicamente útil.',
            'sections': <Map<String, String>>[
              <String, String>{
                'title': 'Regulación',
                'body':
                    'Buffer, pulmón y riñón actúan a velocidades distintas.',
              },
            ],
            'keyPoints': <String>[
              'pH 7.35-7.45',
              'HCO3 22-26 mEq/L',
            ],
            'takeaway': 'Interpretar siempre con contexto clínico.',
          }),
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
      ];

      final study = Study(
        id: 'premium_pdf',
        title: 'Equilibrio ácido-base',
        locale: 'es',
        createdAtUtc: now,
        artifacts: artifacts,
      );

      final bytes = await StudyPdfExportService.buildSelected(
        study,
        isEs: true,
        artifactTypes: artifacts.map((item) => item.type).toSet(),
      );

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(
        bytes.length,
        greaterThan(8000),
        reason: 'valid premium PDF payload should remain non-trivial',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
