import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String readPdfOwner() =>
    File('lib/services/study/study_pdf_export_service.dart').readAsStringSync();

String between(
  String source,
  String start,
  String end,
  String label,
) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: '$label start');
  expect(b, greaterThan(a), reason: '$label end');
  return source.substring(a, b);
}

void main() {
  late String pdf;
  late String paragraph;
  late String bullet;
  late String sectionHeader;
  late String subheading;
  late String table;
  late String qa;
  late String structured;

  setUpAll(() {
    pdf = readPdfOwner();

    paragraph = between(
      pdf,
      'static List<pw.Widget> _premiumParagraphWidgets(String value)',
      'static pw.Widget _premiumBullet',
      '_premiumParagraphWidgets',
    );

    bullet = between(
      pdf,
      'static pw.Widget _premiumBullet(String value, {String? index})',
      'static List<pw.Widget> _structuredArtifactWidgets',
      '_premiumBullet',
    );

    sectionHeader = between(
      pdf,
      'static pw.Widget _artifactSectionHeader({',
      'static pw.Widget _editorialSubheading',
      '_artifactSectionHeader',
    );

    subheading = between(
      pdf,
      'static pw.Widget _editorialSubheading(',
      'static List<pw.Widget> _editorialCallout',
      '_editorialSubheading',
    );

    structured = between(
      pdf,
      'static List<pw.Widget> _structuredArtifactWidgets(',
      'static String _artifactBadge',
      '_structuredArtifactWidgets',
    );

    table = between(
      pdf,
      'static List<pw.Widget> _markdownTableWidgets(List<String> rawLines)',
      'static pw.Widget _questionAnswerBlock',
      '_markdownTableWidgets',
    );

    qa = between(
      pdf,
      'static pw.Widget _questionAnswerBlock(String label, String value)',
      'static String _safe',
      '_questionAnswerBlock',
    );
  });

  test('A4 dossier keeps content-first brand with more editorial margins', () {
    expect(pdf, contains('MEDCASES_STUDY_PDF_READABILITY_14PT_V1'));
    expect(pdf, contains('MEDCASES_STUDY_PDF_BREATHING_SPACING_V1'));
    expect(pdf, contains('pw.EdgeInsets.fromLTRB(48, 38, 48, 46)'));

    expect(pdf, contains('MEDCASES_STUDY_PDF_FIRST_PAGE_CONTENT_V1'));
    expect(pdf, contains('MEDCASES_STUDY_PDF_REPEATING_CANONICAL_LOGO_V1'));
    expect(pdf, contains('MEDCASES_STUDY_PDF_CANONICAL_BRAND_LOCKUP_V2'));
    expect(pdf, contains('pageFormat: PdfPageFormat.a4.landscape'));
  });

  test('main narrative prose is true 14pt with generous leading', () {
    expect(paragraph, contains('fontSize: 14'));
    expect(paragraph, contains('lineSpacing: 4.6'));
    expect(paragraph, contains('pw.SizedBox(height: 10.5)'));

    expect(paragraph, isNot(contains('fontSize: 10.25')));
    expect(paragraph, isNot(contains('lineSpacing: 3.1')));
  });

  test('hierarchy and lists are larger without turning the PDF into cards', () {
    expect(sectionHeader, contains('fontSize: 16'));
    expect(subheading, contains('fontSize: 15'));

    expect(bullet, contains('fontSize: 13'));
    expect(bullet, contains('lineSpacing: 4'));
    expect(bullet, contains('bottom: 7.5'));

    expect(pdf, isNot(contains('LinearGradient(')));
    expect(pdf, isNot(contains('BoxShadow(')));
  });

  test('structured rhythm increases whitespace between semantic blocks', () {
    expect(structured, contains('pw.SizedBox(height: 12)'));
    expect(structured, contains('pw.SizedBox(height: 9)'));
    expect(structured, contains('pw.SizedBox(height: 7)'));
    expect(
      structured,
      contains('pw.EdgeInsets.symmetric(vertical: 6)'),
    );
  });

  test('Q&A is readable and tables remain intentionally compact', () {
    expect(qa, contains('fontSize: 13'));
    expect(qa, contains('lineSpacing: 4'));
    expect(qa, contains('pw.EdgeInsets.fromLTRB(12, 10, 12, 10)'));

    expect(table, contains('fontSize: 9.4'));
    expect(table, contains('fontSize: 9'));
    expect(table, contains('lineSpacing: 2.2'));
  });
}
