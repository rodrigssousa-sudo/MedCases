import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../calculadora_screen.dart';
import 'collapsible_content_blocks.dart';
import 'clinical_markdown_presentation.dart';

import '../../../home_v2/theme/home_v2_palette.dart';

class AiBlockBubble extends StatelessWidget {
  final String block;
  final bool dark;
  final bool isLast;
  final VoidCallback? onCopy;
  final VoidCallback? onTts;
  final bool ttsPlaying;
  final bool ttsReady;
  final String lang; // globalLanguageLock — controla textos da UI
  /// Build 120 — ActionChip: ao clicar, injeta texto no input e dispara _send()
  final void Function(String chipText)? onChipTap;

  const AiBlockBubble({
    super.key,
    required this.block,
    required this.dark,
    this.isLast = false,
    this.onCopy,
    this.onTts,
    this.ttsPlaying = false,
    this.ttsReady = false,
    this.lang = 'pt',
    this.onChipTap,
  });

  // ── ORDEM VISUAL 01: detectores de linha individuais EXTINTOS ───────────
  // _isHardStop / _isH2 / _isSectionHeader / _isWarning / _isReference /
  // _isListItem foram todos removidos. O MarkdownBody único processa o texto
  // completo com softLineBreak:true — sem loop linha-a-linha na UI.

  // ── Build 122: Separa linhas do bloco de referências (📚) ────────────────
  // O bloco termina ao encontrar uma nova seção clínica estruturada.
  (List<String>, List<String>) _splitRefLines(List<String> lines) {
    bool inRef = false;
    final body = <String>[];
    final refs = <String>[];

    bool isReferenceHeader(String value) {
      final normalized = value
          .replaceAll(RegExp(r'^[#*\s]+'), '')
          .replaceAll(':', '')
          .trim()
          .toUpperCase();

      return normalized == '📚 REFERENCIAS' ||
          normalized == '📚 REFERÊNCIAS' ||
          normalized == 'REFERENCIAS' ||
          normalized == 'REFERÊNCIAS';
    }

    bool startsNewSection(String value) {
      if (value.isEmpty) return false;

      return value.startsWith('#') ||
          value.startsWith('🟥') ||
          value.startsWith('⛔') ||
          value.startsWith('📌') ||
          value.startsWith('🎯') ||
          value.startsWith('🚨') ||
          value.startsWith('💊') ||
          value.startsWith('📊') ||
          value.startsWith('⚠️') ||
          value.startsWith('✅') ||
          value.startsWith('🔴') ||
          value.startsWith('🟡') ||
          value.startsWith('🟢');
    }

    for (final line in lines) {
      final trimmed = line.trim();

      if (!inRef) {
        if (isReferenceHeader(trimmed)) {
          inRef = true;
        } else {
          body.add(line);
        }
        continue;
      }

      if (startsNewSection(trimmed) && !isReferenceHeader(trimmed)) {
        inRef = false;
        body.add(line);
        continue;
      }

      refs.add(line);
    }

    return (body, refs);
  }

  @override
  Widget build(BuildContext context) {
    // ── ORDEM VISUAL 01 — MarkdownBody ÚNICO, sem loop linha-a-linha ─────────
    // Toda a lógica de detecção manual de 🟥 / ⛔ / HARD STOP foi extinta.
    // O texto completo flui para um único MarkdownBody com softLineBreak:true.
    // Identidade visual: cor dos emojis nativos do modelo — 100% flat, sem
    // sub-containers, sem Row/Padding segregados por tipo de linha.

    final palette = HomeV2Palette.resolve(dark);
    final kGreen = palette.accent;
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
    final presentationText =
        ClinicalMarkdownPresentation.format(normalizedText);

    final lines = presentationText.split('\n');
    final (bodyLines, refLines) = _splitRefLines(lines);
    final bool hasRefBlock = refLines.isNotEmpty;

    // Reconstrói o corpo normalizado para o MarkdownBody
    final mdText = bodyLines.join('\n').trim();

    // ── MarkdownStyleSheet premium — tipografia clínica flat ─────────────────
    final sheet = MarkdownStyleSheet(
      p: TextStyle(
        color: textColor,
        fontSize: 13.5,
        height: 1.55,
        fontWeight: FontWeight.w400,
      ),
      strong: TextStyle(
        color: palette.textPrimary,
        fontSize: 13.5,
        height: 1.55,
        fontWeight: FontWeight.w700,
      ),
      em: TextStyle(
        color: palette.textPrimary,
        fontSize: 13.5,
        height: 1.55,
        fontStyle: FontStyle.italic,
      ),
      listBullet: TextStyle(
        color: palette.textPrimary,
        fontSize: 13.5,
        height: 1.55,
      ),
      h1: TextStyle(
        color: palette.textPrimary,
        fontSize: 14.2,
        height: 1.3,
        fontWeight: FontWeight.w800,
      ),
      h2: TextStyle(
        color: palette.textPrimary,
        fontSize: 13.9,
        height: 1.35,
        fontWeight: FontWeight.w800,
      ),
      h3: TextStyle(
        color: palette.textPrimary,
        fontSize: 13.6,
        height: 1.4,
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
      blockSpacing: 12,
      listIndent: 20,
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

            // ── Build 120: Bloco de Referências Colapsável ────────────────
            if (hasRefBlock)
              CollapsibleReferencesBlock(
                lines: refLines,
                dark: dark,
                lang: lang,
              ),

            // ── Rodapé: hora + TTS + copiar (apenas última bolha) ────────
            if (isLast) ...[
              const SizedBox(height: 5),
              Row(children: [
                Text(
                  _fakeTime(),
                  style: TextStyle(
                    fontSize: 10,
                    color: palette.textMuted.withValues(alpha: 0.42),
                  ),
                ),
                const Spacer(),
                if (onTts != null && ttsReady) ...[
                  GestureDetector(
                    onTap: onTts,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: ttsPlaying
                            ? palette.accentSoft
                            : Colors.transparent,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          ttsPlaying
                              ? Icons.stop_circle_rounded
                              : Icons.volume_up_rounded,
                          size: 13,
                          color: ttsPlaying
                              ? kGreen
                              : (palette.textSecondary.withValues(alpha: 0.58)),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          ttsPlaying
                              ? (lang == 'es' ? 'Detener' : 'Parar')
                              : (lang == 'es' ? 'Escuchar' : 'Ouvir'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: ttsPlaying
                                ? kGreen
                                : (palette.textSecondary
                                    .withValues(alpha: 0.58)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onCopy != null)
                  GestureDetector(
                    onTap: onCopy,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy_rounded,
                          size: 12,
                          color: palette.textMuted.withValues(alpha: 0.42)),
                      const SizedBox(width: 3),
                      Text(lang == 'es' ? 'Copiar' : 'Copiar',
                          style: TextStyle(
                              fontSize: 10,
                              color:
                                  palette.textMuted.withValues(alpha: 0.42))),
                    ]),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  String _fakeTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
