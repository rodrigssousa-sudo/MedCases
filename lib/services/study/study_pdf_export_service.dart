import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/study_workspace_model.dart';

final class StudyPdfExportService {
  const StudyPdfExportService._();

  static Future<Uint8List> build(Study study, {required bool isEs}) async {
    final document = pw.Document(
      title: study.title,
      author: 'MedCases Pro',
      creator: 'MedCases Study',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 36),
        build: (_) => <pw.Widget>[
          pw.Text(
            study.title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            isEs ? 'MedCases - Area de Estudio' : 'MedCases - Area de Estudos',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            isEs ? 'Fuentes aceptadas' : 'Fontes aceitas',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 7),
          ...study.acceptedSources.map(
            (source) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 7),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _safe(source.title),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (source.refs.isNotEmpty)
                    pw.Text(
                      _safe(
                        source.refs
                            .take(10)
                            .map((ref) => ref.label(isEs: isEs))
                            .join(' | '),
                      ),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            isEs ? 'Productos generados' : 'Produtos gerados',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...study.artifacts.map(
            (artifact) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _safe(artifact.title),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _artifactPlainText(artifact.content),
                    style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
          pw.Divider(),
          pw.Text(
            isEs
                ? 'Material educativo. Revise las fuentes originales.'
                : 'Material educacional. Revise as fontes originais.',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );

    return document.save();
  }

  static Future<void> share(Study study, {required bool isEs}) async {
    final bytes = await build(study, isEs: isEs);
    final safeName = study.title
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    await Printing.sharePdf(
      bytes: bytes,
      filename: safeName.isEmpty ? 'medcases_estudo.pdf' : '$safeName.pdf',
    );
  }

  static String _artifactPlainText(String value) {
    var clean = _safe(value);
    clean = clean
        .replaceAll(RegExp(r'(?m)^\s*#{1,6}\s*'), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'(?m)^\s*[-*+]\s+'), '- ')
        .replaceAll(RegExp(r'(?m)^\s*>\s?'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return clean;
  }

  static String _safe(String value) => value
      .replaceAll('→', '->')
      .replaceAll('•', '-')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('≤', '<=')
      .replaceAll('≥', '>=');
}
