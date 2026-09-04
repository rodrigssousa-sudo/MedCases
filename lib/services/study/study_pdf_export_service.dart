import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/study_workspace_model.dart';
import 'study_visual_result_codec.dart';

final class StudyPdfExportService {
  const StudyPdfExportService._();

  // MEDCASES_STUDY_PDF_UNICODE_THEME_V1
  static pw.ThemeData? _cachedUnicodeTheme;

  static Future<pw.ThemeData> _unicodeTheme() async {
    final cached = _cachedUnicodeTheme;
    if (cached != null) return cached;

    final base = await PdfGoogleFonts.openSansRegular();
    final bold = await PdfGoogleFonts.openSansBold();

    final theme = pw.ThemeData.withFont(
      base: base,
      bold: bold,
      fontFallback: <pw.Font>[base],
    );
    _cachedUnicodeTheme = theme;
    return theme;
  }

  static Future<Uint8List> buildMindMapVisual({
    required String title,
    required String svg,
    required bool isEs,
  }) async {
    final document = pw.Document(
      theme: await _unicodeTheme(),
      title: title,
      author: 'MedCases Pro',
      creator: 'MedCases Study Mind Map',
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 18),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                _medCasesLogo(),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    _safe(title),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  isEs ? 'Mapa mental' : 'Mapa mental',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Expanded(
              child: pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F7F9FA'),
                  border: pw.Border.all(
                    color: PdfColor.fromHex('#D9E1E6'),
                    width: 0.7,
                  ),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.FittedBox(
                  fit: pw.BoxFit.contain,
                  child: pw.SvgImage(svg: svg),
                ),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              isEs
                  ? 'Mapa mental visual generado en MedCases.'
                  : 'Mapa mental visual gerado no MedCases.',
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );

    return document.save();
  }

  static Future<void> shareMindMapVisual({
    required String title,
    required String svg,
    required bool isEs,
  }) async {
    final bytes = await buildMindMapVisual(
      title: title,
      svg: svg,
      isEs: isEs,
    );
    final safeName = title
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    await Printing.sharePdf(
      bytes: bytes,
      filename: safeName.isEmpty
          ? 'medcases_mapa_mental.pdf'
          : '${safeName}_mapa_mental.pdf',
    );
  }

  static Future<Uint8List> build(Study study, {required bool isEs}) {
    return buildSelected(
      study,
      isEs: isEs,
      artifactTypes: study.artifacts.map((item) => item.type).toSet(),
    );
  }

  // MEDCASES_STUDY_PDF_EDITORIAL_PREMIUM_PRO_V1
  static Future<Uint8List> buildSelected(
    Study study, {
    required bool isEs,
    required Set<StudyArtifactType> artifactTypes,
  }) async {
    final artifacts = study.artifacts
        .where(
          (item) =>
              artifactTypes.contains(item.type) &&
              item.type != StudyArtifactType.finalPdf,
        )
        .toList(growable: false);

    if (artifacts.isEmpty) {
      throw StateError('study_pdf_no_selected_artifacts');
    }

    final document = pw.Document(
      theme: await _unicodeTheme(),
    );

    final title = _safe(study.title).trim().isEmpty
        ? (isEs ? 'Material de estudio' : 'Material de estudo')
        : _safe(study.title).trim();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // MEDCASES_STUDY_PDF_READABILITY_14PT_V1
        margin: const pw.EdgeInsets.fromLTRB(48, 38, 48, 46),
        // MEDCASES_STUDY_PDF_REPEATING_CANONICAL_LOGO_V1
        // Legacy semantic marker retained after the premium renderer migration.
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 7),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(
                color: PdfColor.fromHex('#E5E7EB'),
                width: 0.55,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _medCasesLogo(),
              pw.Text(
                isEs
                    ? 'STUDY · MATERIAL DE ESTUDIO'
                    : 'STUDY · MATERIAL DE ESTUDO',
                style: pw.TextStyle(
                  fontSize: 6.9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#64748B'),
                  letterSpacing: 0.65,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(
                color: PdfColor.fromHex('#E5E7EB'),
                width: 0.45,
              ),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  isEs
                      ? 'Material educativo · Revise las fuentes originales'
                      : 'Material educativo · Revise as fontes originais',
                  style: pw.TextStyle(
                    fontSize: 6.6,
                    color: PdfColor.fromHex('#94A3B8'),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                '${context.pageNumber}/${context.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 6.8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#64748B'),
                ),
              ),
            ],
          ),
        ),
        build: (_) => <pw.Widget>[
          // MEDCASES_STUDY_PDF_FIRST_PAGE_CONTENT_V1
          // The first page remains content-first; this masthead is not a cover.
          pw.Container(
            // MEDCASES_STUDY_PDF_BREATHING_SPACING_V1
            padding: const pw.EdgeInsets.fromLTRB(0, 8, 0, 16),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColor.fromHex('#CBD5E1'),
                  width: 0.7,
                ),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  isEs ? 'DOSSIER DE ESTUDIO' : 'DOSSIÊ DE ESTUDO',
                  style: pw.TextStyle(
                    fontSize: 7.2,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#B08C46'),
                    letterSpacing: 0.9,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 21,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#111827'),
                    lineSpacing: 2.2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  isEs
                      ? '${artifacts.length} materiales organizados para lectura y revisión'
                      : '${artifacts.length} materiais organizados para leitura e revisão',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#64748B'),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          for (var index = 0; index < artifacts.length; index++) ...[
            ..._artifactWidgets(
              artifacts[index],
              isEs: isEs,
              ordinal: index + 1,
              total: artifacts.length,
            ),
            if (index < artifacts.length - 1) pw.SizedBox(height: 18),
          ],
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

  // Canonical MedCases PDF brand: M+ dourado + MedCases Pro.
  // Text/vector-only on purpose: deterministic on mobile/web and offline.
  // MEDCASES_STUDY_PDF_CANONICAL_BRAND_LOCKUP_V2
  static pw.Widget _medCasesLogo() {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'M+',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#C5A365'),
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Text(
          'MedCases Pro',
          style: pw.TextStyle(
            fontSize: 8.4,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#1F2937'),
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _artifactWidgets(
    StudyArtifact artifact, {
    required bool isEs,
    required int ordinal,
    required int total,
  }) {
    switch (artifact.type) {
      case StudyArtifactType.visualSummary:
        return _visualSummaryWidgets(
          artifact,
          isEs: isEs,
          ordinal: ordinal,
          total: total,
        );
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
        return _plainArtifactWidgets(
          artifact,
          isEs: isEs,
          ordinal: ordinal,
          total: total,
        );
    }
  }

  static List<pw.Widget> _visualSummaryWidgets(
    StudyArtifact artifact, {
    required bool isEs,
    required int ordinal,
    required int total,
  }) {
    final data = StudyVisualResultCodec.decodeVisualSummary(artifact.content);
    final widgets = <pw.Widget>[
      _artifactSectionHeader(
        title: data.title.isEmpty ? artifact.title : data.title,
        badge: isEs ? 'RESUMEN VISUAL' : 'RESUMO VISUAL',
        ordinal: ordinal,
        total: total,
      ),
    ];

    if (data.overview.trim().isNotEmpty) {
      widgets.addAll(
        _editorialCallout(
          data.overview,
          label: isEs ? 'VISIÓN GENERAL' : 'VISÃO GERAL',
        ),
      );
      widgets.add(pw.SizedBox(height: 8));
    }

    for (final section in data.sections) {
      if (section.title.trim().isNotEmpty) {
        widgets.add(_editorialSubheading(section.title));
        widgets.add(pw.SizedBox(height: 3));
      }
      widgets.addAll(_premiumParagraphWidgets(section.body));
      widgets.add(pw.SizedBox(height: 7));
    }

    if (data.keyPoints.isNotEmpty) {
      widgets.add(
        _editorialSubheading(
          isEs ? 'Ideas clave' : 'Pontos-chave',
          accent: true,
        ),
      );
      widgets.add(pw.SizedBox(height: 4));
      for (final point in data.keyPoints) {
        widgets.add(_premiumBullet(point));
      }
      widgets.add(pw.SizedBox(height: 7));
    }

    if (data.takeaway.trim().isNotEmpty) {
      widgets.addAll(
        _editorialCallout(
          data.takeaway,
          label: isEs ? 'PARA RECORDAR' : 'PARA LEMBRAR',
          gold: true,
        ),
      );
    }

    return widgets;
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

  static List<pw.Widget> _plainArtifactWidgets(
    StudyArtifact artifact, {
    required bool isEs,
    required int ordinal,
    required int total,
  }) {
    return <pw.Widget>[
      _artifactSectionHeader(
        title: artifact.title,
        badge: _artifactBadge(artifact.type, isEs),
        ordinal: ordinal,
        total: total,
      ),
      // MEDCASES_STUDY_PDF_STRUCTURED_RAW_SOURCE_V1
      // Feed raw generated markup to the editorial parser. Stripping Markdown
      // here would destroy tables, bullets and heading structure before render.
      ..._structuredArtifactWidgets(
        artifact.content,
        artifact.type,
        isEs: isEs,
      ),
    ];
  }

  // MEDCASES_STUDY_PDF_BREAK_SAFE_TEXT_V1
  static List<pw.Widget> _breakableTextWidgets(
    String value, {
    required pw.TextStyle style,
  }) {
    final chunks = _splitForPdf(value);
    if (chunks.isEmpty) {
      return const <pw.Widget>[];
    }

    return <pw.Widget>[
      for (var i = 0; i < chunks.length; i++) ...[
        pw.Text(
          chunks[i],
          style: style,
          textAlign: pw.TextAlign.left,
        ),
        if (i < chunks.length - 1) pw.SizedBox(height: 6),
      ],
    ];
  }

  static List<String> _splitForPdf(String value) {
    final normalized = _normalizeStudyMarkup(value).trim();
    if (normalized.isEmpty) return const <String>[];

    const hardLimit = 1250;
    final result = <String>[];

    for (final rawParagraph in normalized.split(RegExp(r'\n{2,}'))) {
      var remaining = rawParagraph.trim();
      if (remaining.isEmpty) continue;

      while (remaining.length > hardLimit) {
        var split = remaining.lastIndexOf(' ', hardLimit);
        if (split < hardLimit ~/ 2) {
          split = hardLimit;
        }
        result.add(remaining.substring(0, split).trim());
        remaining = remaining.substring(split).trimLeft();
      }

      if (remaining.isNotEmpty) {
        result.add(remaining);
      }
    }

    return result;
  }

  static pw.Widget _sectionTitle(String title, String badge) {
    return _artifactSectionHeader(
      title: title,
      badge: badge,
      ordinal: null,
      total: null,
    );
  }

  // MEDCASES_STUDY_PDF_EDITORIAL_COMPONENTS_V1
  static pw.Widget _artifactSectionHeader({
    required String title,
    required String badge,
    required int? ordinal,
    required int? total,
  }) {
    final ordinalLabel = ordinal == null || total == null
        ? ''
        : '${ordinal.toString().padLeft(2, '0')}/${total.toString().padLeft(2, '0')}';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAFC'),
        border: pw.Border(
          left: pw.BorderSide(
            color: PdfColor.fromHex('#C5A365'),
            width: 2.4,
          ),
          top: pw.BorderSide(
            color: PdfColor.fromHex('#E2E8F0'),
            width: 0.45,
          ),
          right: pw.BorderSide(
            color: PdfColor.fromHex('#E2E8F0'),
            width: 0.45,
          ),
          bottom: pw.BorderSide(
            color: PdfColor.fromHex('#E2E8F0'),
            width: 0.45,
          ),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2.5,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F1E9DA'),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              badge.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8.2,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#8B6A2F'),
                letterSpacing: 0.4,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              _cleanInlineMarkup(title),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#111827'),
              ),
            ),
          ),
          if (ordinalLabel.isNotEmpty) ...[
            pw.SizedBox(width: 8),
            pw.Text(
              ordinalLabel,
              style: pw.TextStyle(
                fontSize: 8.4,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#94A3B8'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _editorialSubheading(
    String value, {
    bool accent = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: accent
                ? PdfColor.fromHex('#D7C39B')
                : PdfColor.fromHex('#E2E8F0'),
            width: accent ? 0.9 : 0.55,
          ),
        ),
      ),
      child: pw.Text(
        _cleanInlineMarkup(value),
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: accent
              ? PdfColor.fromHex('#8B6A2F')
              : PdfColor.fromHex('#1F2937'),
        ),
      ),
    );
  }

  static List<pw.Widget> _editorialCallout(
    String value, {
    required String label,
    bool gold = false,
  }) {
    final clean = _normalizeStudyMarkup(value).trim();
    if (clean.isEmpty) return const <pw.Widget>[];

    if (clean.length > 760) {
      return <pw.Widget>[
        _editorialSubheading(label, accent: gold),
        pw.SizedBox(height: 3),
        ..._premiumParagraphWidgets(clean),
      ];
    }

    return <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: pw.BoxDecoration(
          color:
              gold ? PdfColor.fromHex('#FBF8F1') : PdfColor.fromHex('#F5F8F8'),
          border: pw.Border(
            left: pw.BorderSide(
              color: gold
                  ? PdfColor.fromHex('#C5A365')
                  : PdfColor.fromHex('#5F8F88'),
              width: 2.1,
            ),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.4,
                fontWeight: pw.FontWeight.bold,
                color: gold
                    ? PdfColor.fromHex('#8B6A2F')
                    : PdfColor.fromHex('#376D66'),
                letterSpacing: 0.45,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              _cleanInlineMarkup(clean),
              style: pw.TextStyle(
                fontSize: 13.2,
                color: PdfColor.fromHex('#334155'),
                lineSpacing: 4.2,
              ),
              textAlign: pw.TextAlign.left,
            ),
          ],
        ),
      ),
    ];
  }

  // MEDCASES_STUDY_PDF_SEMANTIC_PARAGRAPH_SPLIT_V2
  static List<String> _editorialParagraphChunks(String value) {
    final normalized = _normalizeStudyMarkup(value).trim();
    if (normalized.isEmpty) return const <String>[];

    // MEDCASES_STUDY_PDF_DIDACTIC_PARAGRAPH_RHYTHM_V2
    const targetCharacters = 320;
    const maximumCharacters = 440;
    final result = <String>[];

    for (final rawParagraph in normalized.split(RegExp(r'\n{2,}'))) {
      final paragraph = _cleanInlineMarkup(rawParagraph);
      if (paragraph.isEmpty) continue;

      if (paragraph.length <= maximumCharacters) {
        result.add(paragraph);
        continue;
      }

      final sentences = <String>[];
      var start = 0;

      for (final match in RegExp(r'[.!?](?:\s+|$)').allMatches(paragraph)) {
        final sentence = paragraph.substring(start, match.end).trim();
        if (sentence.isNotEmpty) sentences.add(sentence);
        start = match.end;
      }

      if (start < paragraph.length) {
        final tail = paragraph.substring(start).trim();
        if (tail.isNotEmpty) sentences.add(tail);
      }

      if (sentences.length <= 1) {
        result.addAll(_splitForPdf(paragraph));
        continue;
      }

      var buffer = '';

      for (final sentence in sentences) {
        final candidate = buffer.isEmpty ? sentence : '$buffer $sentence';

        if (buffer.isNotEmpty &&
            candidate.length > targetCharacters &&
            buffer.length >= targetCharacters ~/ 2) {
          result.add(buffer.trim());
          buffer = sentence;
        } else {
          buffer = candidate;
        }
      }

      if (buffer.trim().isNotEmpty) {
        result.add(buffer.trim());
      }
    }

    return result;
  }

  // MEDCASES_STUDY_PDF_READABILITY_PARAGRAPHS_V2
  static List<pw.Widget> _premiumParagraphWidgets(String value) {
    final paragraphs = _editorialParagraphChunks(value);
    if (paragraphs.isEmpty) return const <pw.Widget>[];

    final widgets = <pw.Widget>[];

    for (var i = 0; i < paragraphs.length; i++) {
      widgets.addAll(
        _breakableTextWidgets(
          paragraphs[i],
          style: pw.TextStyle(
            fontSize: 14,
            lineSpacing: 4.6,
            color: PdfColor.fromHex('#273444'),
          ),
        ),
      );

      if (i < paragraphs.length - 1) {
        widgets.add(pw.SizedBox(height: 10.5));
      }
    }

    return widgets;
  }

  static pw.Widget _premiumBullet(String value, {String? index}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: index == null ? 4 : 18,
            margin: const pw.EdgeInsets.only(top: 4, right: 8.5),
            child: index == null
                ? pw.Container(
                    width: 3.2,
                    height: 3.2,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#C5A365'),
                      shape: pw.BoxShape.circle,
                    ),
                  )
                : pw.Text(
                    index,
                    style: pw.TextStyle(
                      fontSize: 8.6,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#8B6A2F'),
                    ),
                  ),
          ),
          pw.Expanded(
            child: pw.Text(
              _cleanInlineMarkup(value),
              style: pw.TextStyle(
                fontSize: 13,
                lineSpacing: 4,
                color: PdfColor.fromHex('#334155'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _structuredArtifactWidgets(
    String raw,
    StudyArtifactType type, {
    required bool isEs,
  }) {
    final source = _normalizeStudyMarkup(raw);
    final lines = source.split('\n');
    final widgets = <pw.Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final joined = paragraph.join(' ').trim();
      paragraph.clear();
      if (joined.isEmpty) return;
      widgets.addAll(_premiumParagraphWidgets(joined));
      widgets.add(pw.SizedBox(height: 12));
    }

    var i = 0;
    var numberedIndex = 0;

    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        flushParagraph();
        i++;
        continue;
      }

      if (line == '---') {
        flushParagraph();
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Divider(
              color: PdfColor.fromHex('#E2E8F0'),
              thickness: 0.55,
            ),
          ),
        );
        i++;
        continue;
      }

      if (_isMarkdownTableLine(line)) {
        flushParagraph();
        final tableLines = <String>[];
        while (i < lines.length && _isMarkdownTableLine(lines[i].trim())) {
          tableLines.add(lines[i].trim());
          i++;
        }
        widgets.addAll(_markdownTableWidgets(tableLines));
        widgets.add(pw.SizedBox(height: 12));
        continue;
      }

      final qa = _questionAnswerParts(line);
      if (qa != null) {
        flushParagraph();
        widgets.add(_questionAnswerBlock(qa.$1, qa.$2));
        widgets.add(pw.SizedBox(height: 9));
        i++;
        continue;
      }

      final bullet = RegExp(r'^(?:[-•*])\s+(.+)$').firstMatch(line);
      if (bullet != null) {
        flushParagraph();
        widgets.add(_premiumBullet(bullet.group(1) ?? ''));
        i++;
        continue;
      }

      final numbered = RegExp(r'^(\d+)[.)]\s+(.+)$').firstMatch(line);
      if (numbered != null && !_looksLikeHeading(line)) {
        flushParagraph();
        numberedIndex++;
        widgets.add(
          _premiumBullet(
            numbered.group(2) ?? '',
            index: '${numbered.group(1) ?? numberedIndex}.',
          ),
        );
        i++;
        continue;
      }

      if (_looksLikeHeading(line)) {
        flushParagraph();
        widgets.add(
          _editorialSubheading(
            _stripHeadingPrefix(line),
            accent: _isMajorHeading(line),
          ),
        );
        widgets.add(pw.SizedBox(height: 7));
        i++;
        continue;
      }

      paragraph.add(line);
      i++;
    }

    flushParagraph();

    while (widgets.isNotEmpty && widgets.last is pw.SizedBox) {
      widgets.removeLast();
    }

    return widgets;
  }

  static String _artifactBadge(StudyArtifactType type, bool isEs) {
    switch (type) {
      case StudyArtifactType.visualSummary:
        return isEs ? 'Resumen visual' : 'Resumo visual';
      case StudyArtifactType.fullSummary:
        return isEs ? 'Resumen completo' : 'Resumo completo';
      case StudyArtifactType.examSummary:
        return isEs ? 'Repaso de examen' : 'Revisão para prova';
      case StudyArtifactType.mindMap:
        return 'Mapa mental';
      case StudyArtifactType.flashcards:
        return 'Flashcards';
      case StudyArtifactType.questionsAndAnswers:
        return isEs ? 'Preguntas y respuestas' : 'Perguntas e respostas';
      case StudyArtifactType.multipleChoice:
        return isEs ? 'Opción múltiple' : 'Múltipla escolha';
      case StudyArtifactType.oralExam:
        return isEs ? 'Examen oral' : 'Prova oral';
      case StudyArtifactType.keyPoints:
        return isEs ? 'Puntos clave' : 'Pontos-chave';
      case StudyArtifactType.comparisonTable:
        return isEs ? 'Tabla comparativa' : 'Tabela comparativa';
      case StudyArtifactType.finalPdf:
        return 'PDF';
    }
  }

  static bool _isMarkdownTableLine(String line) =>
      line.startsWith('|') && line.endsWith('|') && line.length >= 3;

  static bool _isMarkdownTableSeparator(String line) {
    final cells = _tableCells(line);
    if (cells.isEmpty) return false;
    return cells.every(
      (cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell.trim()),
    );
  }

  static List<String> _tableCells(String line) {
    var clean = line.trim();
    if (clean.startsWith('|')) clean = clean.substring(1);
    if (clean.endsWith('|')) clean = clean.substring(0, clean.length - 1);
    return clean
        .split('|')
        .map((cell) => _cleanInlineMarkup(cell.trim()))
        .toList(growable: false);
  }

  // MEDCASES_STUDY_PDF_COMPARISON_TABLE_PREMIUM_V2
  static List<pw.Widget> _markdownTableWidgets(List<String> rawLines) {
    if (rawLines.isEmpty) return const <pw.Widget>[];

    final rows = <List<String>>[];
    for (final line in rawLines) {
      if (_isMarkdownTableSeparator(line)) continue;
      final cells = _tableCells(line);
      if (cells.isNotEmpty) rows.add(cells);
    }

    if (rows.isEmpty) return const <pw.Widget>[];

    final maxColumns = rows
        .map((row) => row.length)
        .fold<int>(0, (max, value) => value > max ? value : max);

    if (maxColumns <= 1 || maxColumns > 6) {
      return _premiumParagraphWidgets(
        rows.map((row) => row.join(' · ')).join('\n\n'),
      );
    }

    final normalizedRows = <List<String>>[
      for (final row in rows)
        <String>[
          ...row,
          for (var i = row.length; i < maxColumns; i++) '',
        ],
    ];

    final header = normalizedRows.first;
    final body = normalizedRows.skip(1).toList(growable: false);

    return <pw.Widget>[
      pw.Table(
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        columnWidths: <int, pw.TableColumnWidth>{
          0: const pw.FlexColumnWidth(1.45),
          for (var columnIndex = 1;
              columnIndex < maxColumns;
              columnIndex++)
            columnIndex: const pw.FlexColumnWidth(1),
        },
        border: pw.TableBorder(
          top: pw.BorderSide(
            color: PdfColor.fromHex('#CBD5E1'),
            width: 0.7,
          ),
          bottom: pw.BorderSide(
            color: PdfColor.fromHex('#CBD5E1'),
            width: 0.7,
          ),
          horizontalInside: pw.BorderSide(
            color: PdfColor.fromHex('#E5E7EB'),
            width: 0.4,
          ),
          verticalInside: pw.BorderSide(
            color: PdfColor.fromHex('#E5E7EB'),
            width: 0.35,
          ),
          left: pw.BorderSide(
            color: PdfColor.fromHex('#E5E7EB'),
            width: 0.4,
          ),
          right: pw.BorderSide(
            color: PdfColor.fromHex('#E5E7EB'),
            width: 0.4,
          ),
        ),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EEF2F6'),
            ),
            children: [
              for (final cell in header)
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 7),
                  child: pw.Text(
                    cell,
                    style: pw.TextStyle(
                      fontSize: 9.4,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1F2937'),
                    ),
                  ),
                ),
            ],
          ),
          for (var rowIndex = 0; rowIndex < body.length; rowIndex++)
            pw.TableRow(
              decoration: rowIndex.isOdd
                  ? pw.BoxDecoration(
                      color: PdfColor.fromHex('#FBFCFD'),
                    )
                  : null,
              children: [
                for (var cellIndex = 0;
                    cellIndex < body[rowIndex].length;
                    cellIndex++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 7),
                    child: pw.Text(
                      body[rowIndex][cellIndex],
                      style: pw.TextStyle(
                        fontSize: 9,
                        lineSpacing: 2.2,
                        fontWeight: cellIndex == 0
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                        color: cellIndex == 0
                            ? PdfColor.fromHex('#1F2937')
                            : PdfColor.fromHex('#334155'),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    ];
  }

  static (String, String)? _questionAnswerParts(String line) {
    final match = RegExp(
      r'^(Pregunta|Pergunta|Question|Respuesta|Resposta|Answer)\s*:\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(line);

    if (match == null) return null;
    return (
      (match.group(1) ?? '').trim(),
      (match.group(2) ?? '').trim(),
    );
  }

  static pw.Widget _questionAnswerBlock(String label, String value) {
    final isQuestion = RegExp(
      r'^(Pregunta|Pergunta|Question)$',
      caseSensitive: false,
    ).hasMatch(label);

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(
        color: isQuestion
            ? PdfColor.fromHex('#F8FAFC')
            : PdfColor.fromHex('#FBF8F1'),
        border: pw.Border(
          left: pw.BorderSide(
            color: isQuestion
                ? PdfColor.fromHex('#64748B')
                : PdfColor.fromHex('#C5A365'),
            width: 1.8,
          ),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 48,
            child: pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8.4,
                fontWeight: pw.FontWeight.bold,
                color: isQuestion
                    ? PdfColor.fromHex('#475569')
                    : PdfColor.fromHex('#8B6A2F'),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _cleanInlineMarkup(value),
              style: pw.TextStyle(
                fontSize: 13,
                lineSpacing: 4,
                color: PdfColor.fromHex('#273444'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _looksLikeHeading(String raw) {
    final line = _stripHeadingPrefix(raw).trim();
    if (line.isEmpty || line.length > 105) return false;

    if (raw.trimLeft().startsWith('#')) return true;

    if (RegExp(r'^\d+[.)]\s+').hasMatch(line) && line.length <= 90) {
      return true;
    }

    if (line.endsWith(':') && line.length <= 72) return true;

    final letters = line.replaceAll(
      RegExp(
        r'[^A-Za-zÁÉÍÓÚÜÑÇÃÕÂÊÔÀÈÌÒÙáéíóúüñçãõâêôàèìòù]',
      ),
      '',
    );
    if (letters.length < 5) return false;

    final uppercase = letters.replaceAll(
      RegExp(r'[^A-ZÁÉÍÓÚÜÑÇÃÕÂÊÔÀÈÌÒÙ]'),
      '',
    );

    return uppercase.length / letters.length >= 0.78;
  }

  static bool _isMajorHeading(String raw) {
    final clean = _stripHeadingPrefix(raw).trim();
    final letters = clean.replaceAll(
      RegExp(
        r'[^A-Za-zÁÉÍÓÚÜÑÇÃÕÂÊÔÀÈÌÒÙáéíóúüñçãõâêôàèìòù]',
      ),
      '',
    );
    if (letters.length < 5) return false;
    final uppercase = letters.replaceAll(
      RegExp(r'[^A-ZÁÉÍÓÚÜÑÇÃÕÂÊÔÀÈÌÒÙ]'),
      '',
    );
    return uppercase.length / letters.length >= 0.78;
  }

  static String _stripHeadingPrefix(String value) {
    return _cleanInlineMarkup(
      value
          .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
          .replaceFirst(RegExp(r'^\d+[.)]\s+'), ''),
    );
  }

  static String _normalizeStudyMarkup(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(
          RegExp(
            r'\[(?:Audio|Áudio)\s*·?\s*\d{1,2}:\d{2}(?::\d{2})?\s*-\s*\d{1,2}:\d{2}(?::\d{2})?\]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' · ')
        .replaceAll(r'$\rightarrow$', ' -> ')
        .replaceAll(r'\rightarrow', ' -> ')
        .replaceAll(r'$\leftarrow$', ' <- ')
        .replaceAll(r'\leftarrow', ' <- ')
        .replaceAll(r'$\pm$', ' ± ')
        .replaceAll(r'\pm', ' ± ')
        .replaceAll('→', ' -> ')
        .replaceAll('←', ' <- ')
        .replaceAll('α', 'alpha')
        .replaceAll('β', 'beta')
        .replaceAll('γ', 'gamma')
        .replaceAll('δ', 'delta')
        .replaceAll('Δ', 'Delta')
        .replaceAll('μ', 'u')
        .replaceAll('µ', 'u')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static String _cleanInlineMarkup(String value) {
    return _normalizeStudyMarkup(value)
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .replaceAll('*', '')
        .replaceAll(RegExp(r'\$(?!\d)'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static String _safe(String value) => value
      .replaceAll('→', '->')
      .replaceAll('•', '-')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('≤', '<=')
      .replaceAll('≥', '>=');
}
