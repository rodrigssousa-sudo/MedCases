import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/study_workspace_model.dart';
import 'study_visual_result_codec.dart';

final class StudyPdfExportService {
  const StudyPdfExportService._();

  static Future<Uint8List> build(Study study, {required bool isEs}) {
    return buildSelected(
      study,
      isEs: isEs,
      artifactTypes: study.artifacts.map((item) => item.type).toSet(),
    );
  }

  static Future<Uint8List> buildSelected(
    Study study, {
    required bool isEs,
    required Set<StudyArtifactType> artifactTypes,
  }) async {
    final artifacts = study.artifacts
        .where((item) => artifactTypes.contains(item.type))
        .toList(growable: false);

    if (artifacts.isEmpty) {
      throw StateError('study_pdf_no_selected_artifacts');
    }

    final document = pw.Document(
      title: study.title,
      author: 'MedCases Pro',
      creator: 'MedCases Study',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 32, 34, 34),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'MEDCASES',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal700,
              ),
            ),
            pw.Text(
              isEs ? 'Material de estudio' : 'Material de estudo',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ),
        build: (_) => <pw.Widget>[
          pw.SizedBox(height: 8),
          pw.Text(
            _safe(study.title),
            style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            isEs
                ? 'Materiales seleccionados para revisión'
                : 'Materiais selecionados para revisão',
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          for (final artifact in artifacts) ...[
            ..._artifactWidgets(artifact),
            pw.SizedBox(height: 15),
          ],
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 5),
          pw.Text(
            isEs
                ? 'Material educativo. Revise las fuentes originales.'
                : 'Material educacional. Revise as fontes originais.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return document.save();
  }

  static Future<void> share(Study study, {required bool isEs}) {
    return shareSelected(
      study,
      isEs: isEs,
      artifactTypes: study.artifacts.map((item) => item.type).toSet(),
    );
  }

  static Future<void> shareSelected(
    Study study, {
    required bool isEs,
    required Set<StudyArtifactType> artifactTypes,
  }) async {
    final bytes = await buildSelected(
      study,
      isEs: isEs,
      artifactTypes: artifactTypes,
    );

    final safeName = study.title
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    await Printing.sharePdf(
      bytes: bytes,
      filename: safeName.isEmpty ? 'medcases_estudo.pdf' : '$safeName.pdf',
    );
  }

  static List<pw.Widget> _artifactWidgets(StudyArtifact artifact) {
    switch (artifact.type) {
      case StudyArtifactType.visualSummary:
        return _visualSummaryWidgets(artifact);
      case StudyArtifactType.mindMap:
        return _mindMapWidgets(artifact);
      case StudyArtifactType.finalPdf:
        return const <pw.Widget>[];
      case StudyArtifactType.fullSummary:
      case StudyArtifactType.examSummary:
      case StudyArtifactType.flashcards:
      case StudyArtifactType.questionsAndAnswers:
      case StudyArtifactType.multipleChoice:
      case StudyArtifactType.oralExam:
      case StudyArtifactType.keyPoints:
      case StudyArtifactType.comparisonTable:
        return _plainArtifactWidgets(artifact);
    }
  }

  static List<pw.Widget> _visualSummaryWidgets(StudyArtifact artifact) {
    final data = StudyVisualResultCodec.decodeVisualSummary(artifact.content);

    return <pw.Widget>[
      _sectionTitle(data.title.isEmpty ? artifact.title : data.title, 'VISUAL'),
      if (data.overview.isNotEmpty) ...[
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(11),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.teal200, width: 0.6),
          ),
          child: pw.Text(
            _safe(data.overview),
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
          ),
        ),
        pw.SizedBox(height: 8),
      ],
      for (final section in data.sections) ...[
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 9),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _safe(section.title),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (section.body.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  _safe(section.body),
                  style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.8),
                ),
              ],
            ],
          ),
        ),
      ],
      if (data.keyPoints.isNotEmpty) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          'PONTOS-CHAVE',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.teal700,
          ),
        ),
        pw.SizedBox(height: 4),
        for (final point in data.keyPoints)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 4,
                  height: 4,
                  margin: const pw.EdgeInsets.only(top: 4, right: 6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.teal700,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    _safe(point),
                    style: const pw.TextStyle(fontSize: 8.8),
                  ),
                ),
              ],
            ),
          ),
      ],
      if (data.takeaway.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.teal400, width: 0.8),
          ),
          child: pw.Text(
            _safe(data.takeaway),
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ];
  }

  static List<pw.Widget> _mindMapWidgets(StudyArtifact artifact) {
    final nodes = StudyVisualResultCodec.decodeMindMap(artifact.content);

    return <pw.Widget>[
      _sectionTitle(artifact.title, 'MAPA'),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(10, 10, 10, 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final node in nodes)
              pw.Container(
                margin: pw.EdgeInsets.fromLTRB(
                  (node.depth * 13).toDouble(),
                  0,
                  0,
                  5,
                ),
                padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 5),
                decoration: pw.BoxDecoration(
                  color: node.depth == 0 ? PdfColors.teal50 : PdfColors.white,
                  border: pw.Border(
                    left: pw.BorderSide(
                      color: node.depth == 0
                          ? PdfColors.teal700
                          : PdfColors.teal300,
                      width: node.depth == 0 ? 2 : 1,
                    ),
                  ),
                ),
                child: pw.Text(
                  _safe(node.text),
                  style: pw.TextStyle(
                    fontSize: node.depth == 0 ? 10 : 8.8,
                    fontWeight: node.depth == 0
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  static List<pw.Widget> _plainArtifactWidgets(StudyArtifact artifact) {
    return <pw.Widget>[
      _sectionTitle(artifact.title, 'TEXTO'),
      pw.Text(
        _artifactPlainText(artifact.content),
        style: const pw.TextStyle(fontSize: 9.2, lineSpacing: 2),
      ),
    ];
  }

  static pw.Widget _sectionTitle(String title, String badge) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 7),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.6),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal50,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              badge,
              style: pw.TextStyle(
                fontSize: 6.8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal700,
              ),
            ),
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(
            child: pw.Text(
              _safe(title),
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static String _artifactPlainText(String value) {
    return _safe(StudyVisualResultCodec.stripMarkdown(value));
  }

  static String _safe(String value) => value
      .replaceAll('→', '->')
      .replaceAll('•', '-')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('≤', '<=')
      .replaceAll('≥', '>=');
}
