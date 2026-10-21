import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../calculadora_screen.dart';
import 'collapsible_content_blocks.dart';
import 'clinical_markdown_presentation.dart';

import '../../../home_v2/theme/home_v2_palette.dart';

class AiBlockBubble extends StatelessWidget {
  final DateTime? createdAt;
  final List<String> relatedReferences;
  final String block;
  final bool dark;
  final bool isLast;
  final VoidCallback? onCopy;
  final VoidCallback? onTts;
  final bool ttsPlaying;
  final bool ttsReady;
  final String lang; // globalLanguageLock — controla textos da UI
  final bool studyMode;

  /// Build 120 — ActionChip: ao clicar, injeta texto no input e dispara _send()
  final void Function(String chipText)? onChipTap;

  const AiBlockBubble({
    super.key,
    required this.block,
    this.createdAt,
    this.relatedReferences = const [],
    required this.dark,
    this.isLast = false,
    this.onCopy,
    this.onTts,
    this.ttsPlaying = false,
    this.ttsReady = false,
    this.lang = 'pt',
    this.studyMode = false,
    this.onChipTap,
  });

  // ── ORDEM VISUAL 01: detectores de linha individuais EXTINTOS ───────────
  // _isHardStop / _isH2 / _isSectionHeader / _isWarning / _isReference /
  // _isListItem foram todos removidos. O MarkdownBody único processa o texto
  // completo com softLineBreak:true — sem loop linha-a-linha na UI.

  // ── Build 122: Separa linhas do bloco de referências (📚) ────────────────
  // O bloco termina ao encontrar uma nova seção clínica estruturada.
  (List<String>, List<String>) _splitRefLines(List<String> lines) {
    final projection = CollapsibleReferencesBlock.project(lines.join('\n'));
    return (projection.$1.split('\n'), projection.$2);
  }

  @override
  Widget build(BuildContext context) {
    // ── ORDEM VISUAL 01 — MarkdownBody ÚNICO, sem loop linha-a-linha ─────────
    // Toda a lógica de detecção manual de 🟥 / ⛔ / HARD STOP foi extinta.
    // O texto completo flui para um único MarkdownBody com softLineBreak:true.
    // Identidade visual: cor dos emojis nativos do modelo — 100% flat, sem
    // sub-containers, sem Row/Padding segregados por tipo de linha.

    final palette = HomeV2Palette.resolve(dark);
    final textColor = palette.textPrimary;

    // ── M2: Normalização de soft-line-breaks ─────────────────────────────────
    // Converte cada \n isolado em \n\n para que o MarkdownBody quebre a linha
    // corretamente com softLineBreak:true, preservando parágrafos já duplos.
    // Algoritmo: substitui qualquer \n que NÃO esteja já precedido por \n
    // e NÃO esteja já seguido por \n → insere o segundo \n apenas onde falta.
    final normalizedText = block
        .replaceAll('\r\n', '\n') // normaliza CRLF → LF
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // colapsa 3+ \n → 2
        .replaceAllMapped(
          RegExp(r'(?<!\n)\n(?!\n)'), // \n isolado (não duplo)
          (_) => '\n\n', // → duplo para MD paragraph break
        );

    // R18.6AC-R1B-H4B-R3 — transformação somente visual.
    // Study premium: remove somente o recuo editorial de primeira linha.
    // O caminho não-Study mantém a chamada canônica literal abaixo.
    final presentationText = studyMode
        ? ClinicalMarkdownPresentation.format(
            normalizedText,
            indentParagraphs: false,
          )
        : ClinicalMarkdownPresentation.format(normalizedText);

    final lines = presentationText.split('\n');
    final (bodyLines, refLines) = _splitRefLines(lines);
    final bool hasRefBlock = refLines.isNotEmpty;

    // Reconstrói o corpo normalizado para o MarkdownBody
    final mdText = bodyLines.join('\n').trim();

    // ── MarkdownStyleSheet premium — tipografia clínica flat ─────────────────
    final sheet = MarkdownStyleSheet(
      p: TextStyle(
        color: textColor,
        fontSize: studyMode ? 13.2 : 13.5,
        height: studyMode ? 1.42 : 1.55,
        fontWeight: FontWeight.w400,
      ),
      strong: TextStyle(
        color: palette.textPrimary,
        fontSize: studyMode ? 13.2 : 13.5,
        height: studyMode ? 1.42 : 1.55,
        fontWeight: FontWeight.w700,
      ),
      em: TextStyle(
        color: palette.textPrimary,
        fontSize: studyMode ? 13.2 : 13.5,
        height: studyMode ? 1.42 : 1.55,
        fontStyle: FontStyle.italic,
      ),
      listBullet: TextStyle(
        color: palette.textPrimary,
        fontSize: studyMode ? 13.2 : 13.5,
        height: studyMode ? 1.42 : 1.55,
      ),
      h1: TextStyle(
        color: palette.textPrimary,
        fontSize: 14.2,
        height: 1.3,
        fontWeight: FontWeight.w800,
      ),
      h2: TextStyle(
        color: palette.textPrimary,
        fontSize: studyMode ? 13.7 : 13.9,
        height: studyMode ? 1.30 : 1.35,
        fontWeight: FontWeight.w800,
      ),
      h3: TextStyle(
        color: palette.textPrimary,
        fontSize: studyMode ? 13.4 : 13.6,
        height: studyMode ? 1.32 : 1.4,
        fontWeight: FontWeight.w700,
      ),
      blockquote: TextStyle(
        color: palette.textPrimary.withValues(
          alpha: 0.82,
        ),
        fontSize: 13,
        height: 1.5,
      ),
      blockquotePadding: const EdgeInsets.only(
        left: 10,
      ),
      blockquoteDecoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          left: BorderSide(
            color: palette.accent,
            width: 2,
          ),
        ),
      ),
      code: TextStyle(
        color: palette.textPrimary,
        fontSize: 12.3,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
      codeblockDecoration: BoxDecoration(
        color: palette.surfaceStrong,
        borderRadius: BorderRadius.circular(5),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: palette.divider,
            width: 0.8,
          ),
        ),
      ),
      blockSpacing: studyMode ? 8 : 12,
      listIndent: studyMode ? 16 : 20,
      tableHead: TextStyle(
        color: palette.textPrimary,
        fontSize: 12.3,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      tableBody: TextStyle(
        color: palette.textPrimary,
        fontSize: 12,
        height: 1.4,
      ),
      tablePadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      tableColumnWidth: const FlexColumnWidth(),
      tableBorder: TableBorder.all(
        color: palette.border,
        width: 0.5,
        borderRadius: BorderRadius.circular(6),
      ),
      tableHeadAlign: TextAlign.left,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17.0).copyWith(
        bottom: isLast ? 8 : 4,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // mainAxisSize.min: crescimento ilimitado vertical sem disputar
          // altura máxima com o ListView pai (evita truncação de texto longo).
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── ÚNICO MarkdownBody — processa tudo (🟥 ⛔ ## ### bullets) ──
            if (mdText.isNotEmpty)
              MarkdownBody(
                data: mdText,
                selectable: false,
                softLineBreak: true,
                styleSheet: sheet,
                // BUILD 429-APPLE-COMPLIANCE: intercepta todos os links do chat
                // e abre na WebView interna (CalculadoraScreen) — NUNCA Safari.
                onTapLink: (text, href, title) {
                  if (href != null && href.contains('http')) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CalculadoraScreen(initialUrl: href),
                      ),
                    );
                  }
                },
              ),

            if (!isLast && hasRefBlock)
              CollapsibleReferencesBlock(lines: refLines, dark: dark, lang: lang),
            if (isLast)
              ClinicalResponseFooter(
                  dark: dark,
                  lang: lang,
                  createdAt: createdAt,
                  relatedReferences: relatedReferences,
                  references: hasRefBlock ? refLines : const [],
                  onCopy: onCopy,
                  onTts: onTts,
                  ttsPlaying: ttsPlaying,
                  ttsReady: ttsReady),
          ],
        ),
      ),
    );
  }
}
