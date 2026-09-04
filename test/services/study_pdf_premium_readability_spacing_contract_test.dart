import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  group('Study PDF premium readability', () {
    test('body uses larger readable typography and paragraph rhythm', () {
      final pdf = read('lib/services/study/study_pdf_export_service.dart');

      expect(
        pdf,
        contains('MEDCASES_STUDY_PDF_READABILITY_PARAGRAPHS_V2'),
      );
      expect(
        pdf,
        contains('MEDCASES_STUDY_PDF_SEMANTIC_PARAGRAPH_SPLIT_V2'),
      );
      expect(pdf, contains('fontSize: 10.25'));
      expect(pdf, contains('lineSpacing: 3.1'));
      expect(pdf, contains('textAlign: pw.TextAlign.left'));
      expect(pdf, contains('const targetCharacters = 520;'));
      expect(pdf, contains('const maximumCharacters = 680;'));
      expect(pdf, contains('pw.SizedBox(height: 7.5)'));
    });

    test('audio ranges are removed from exported prose', () {
      final pdf = read('lib/services/study/study_pdf_export_service.dart');

      expect(pdf, contains('(?:Audio|Áudio)'));
      expect(pdf, contains(r'\d{1,2}:\d{2}(?::\d{2})?'));
    });

    test('prose Markdown is cleaned while tables remain R7', () {
      final pdf = read('lib/services/study/study_pdf_export_service.dart');

      expect(
        pdf,
        contains('final paragraph = _cleanInlineMarkup(rawParagraph);'),
      );
      expect(pdf, contains(".replaceAll('**', '')"));
      expect(pdf, contains('fontSize: 7.5'));
      expect(pdf, contains('fontSize: 7.3'));
      expect(pdf, contains('_markdownTableWidgets'));
    });

    test('R7 premium architecture remains present', () {
      final pdf = read('lib/services/study/study_pdf_export_service.dart');

      for (final token in <String>[
        'MEDCASES_STUDY_PDF_EDITORIAL_PREMIUM_PRO_V1',
        'MEDCASES_STUDY_PDF_CANONICAL_BRAND_LOCKUP_V2',
        'MEDCASES_STUDY_PDF_STRUCTURED_RAW_SOURCE_V1',
        'DOSSIER DE ESTUDIO',
        '_questionAnswerBlock',
      ]) {
        expect(pdf, contains(token), reason: token);
      }
    });
  });
}
