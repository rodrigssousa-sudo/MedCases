import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class CollapsibleReferencesBlock extends StatefulWidget {
  final List<String> lines; // linhas de referência (sem o cabeçalho 📚)
  final bool dark;
  final bool showControl;
  final bool? expanded;
  final String lang; // 'es' ou 'pt'
  const CollapsibleReferencesBlock({
    super.key,
    required this.lines,
    required this.dark,
    this.lang = 'pt',
    this.showControl = true,
    this.expanded,
  });

  static bool isReferenceHeading(String line) {
    final label = line
        .replaceAll(RegExp(r'[#*_`]'), '')
        .trim()
        .replaceFirst(RegExp(r'^📚\s*'), '');
    return RegExp(
      r'^(?:refer[eê]ncias?|referencias?|fontes?|fuentes?|sources?|references?)'
      r'(?:\s+(?:bibliogr[aá]ficas?|cient[ií]ficas?|m[eé]dicas?|t[eé]cnicas?|e fontes|y fuentes))?\s*:?$',
      caseSensitive: false,
    ).hasMatch(label);
  }

  /// Display only. The immutable original remains the copy/history source.
  /// URLs, source labels and citation markers are moved, never discarded.
  static (String, List<String>) project(String original,
      {List<String> knownReferences = const []}) {
    final body = <String>[], references = <String>[...knownReferences];
    var inReferences = false, inCode = false;
    final link = RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)');
    final url = RegExp(r'https?://[^\s<>()]+');
    final citations =
        RegExp(r'\[R\d+(?:\s*[,;]\s*R?\d+)*\]', caseSensitive: false);
    for (final line in original.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('```')) inCode = !inCode;
      if (inCode || trimmed.startsWith('```')) {
        body.add(line);
        continue;
      }
      if (isReferenceHeading(trimmed)) {
        inReferences = true;
        continue;
      }
      final nextSection =
          RegExp(r'^#{1,6}\s+|^\*\*[^*]+\*\*\s*:?$').hasMatch(trimmed);
      if (nextSection) inReferences = false;
      if (inReferences) {
        if (trimmed.isNotEmpty) references.add(line);
        continue;
      }
      if (RegExp(
              r'^(?:[-*•]\s*)?(?:fontes?|fuentes?|sources?|refer[eê]ncias?|referencias?)'
              r'(?:\s+(?:t[eé]cnicas?|cient[ií]ficas?|bibliogr[aá]ficas?|m[eé]dicas?))?\s*:\s*\S',
              caseSensitive: false)
          .hasMatch(trimmed.replaceAll('**', ''))) {
        references.add(line);
        continue;
      }
      final unbulleted =
          trimmed.replaceFirst(RegExp(r'^(?:[-*•]|\d+[.)])\s*'), '');
      if ((link.firstMatch(unbulleted)?.group(0) == unbulleted) ||
          (url.firstMatch(unbulleted)?.group(0) == unbulleted)) {
        references.add(line);
        continue;
      }
      var visible = line.replaceAllMapped(link, (match) {
        references.add(match.group(0)!);
        final label = match.group(1)!;
        final sourceLabel = RegExp(
          r'^(?:R\d+|fontes?(?:\s+t[eé]cnicas?)?|fuentes?(?:\s+t[eé]cnicas?)?|sources?|references?|refer[eê]ncias?|[a-z0-9_-]+(?:\.[a-z0-9_-]+)+)$',
          caseSensitive: false,
        ).hasMatch(label.trim());
        return sourceLabel
            ? ''
            : label; // Keep clinically meaningful linked wording.
      });
      visible = visible.replaceAllMapped(url, (match) {
        references.add(match.group(0)!);
        return '';
      });
      visible = visible.replaceAll(RegExp(r'\(\s*\)'), '');
      body.add(visible);
    }
    final labels = RegExp(r'\bR\d+\b', caseSensitive: false)
        .allMatches(references.join(' '))
        .map((m) => m.group(0)!.toUpperCase())
        .toSet();
    final visibleBody =
        body.join('\n').trim().replaceAllMapped(citations, (match) {
      final cited = RegExp(r'R?\d+', caseSensitive: false)
          .allMatches(match.group(0)!)
          .map((m) =>
              'R${m.group(0)!.replaceFirst(RegExp(r'^R', caseSensitive: false), '')}');
      // Only proven source labels are citations. Never hide a clinical code
      // merely because it has the same bracket notation.
      return cited.every(labels.contains) ? '' : match.group(0)!;
    });
    return (visibleBody, references.toSet().toList());
  }

  @override
  State<CollapsibleReferencesBlock> createState() =>
      CollapsibleReferencesBlockState();
}

class CollapsibleReferencesBlockState
    extends State<CollapsibleReferencesBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final isEs = widget.lang == 'es';
    final expanded = widget.expanded ?? _expanded;

    // Build 127 — Flat UI: sem fundo sólido, apenas label sutil flutuando no scaffold
    final labelColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Label localizado
    final chipLabel =
        isEs ? 'Ver Referencias Médicas' : 'Ver Referências Médicas';

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chip colapsável ────────────────────────────────────────────────
          if (widget.showControl)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_outlined, size: 16, color: labelColor),
                    const SizedBox(width: 6),
                    Text(
                      chipLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 16, color: labelColor),
                    ),
                  ],
                ),
              ),
            ),

          // ── Conteúdo expandido: texto simples e compacto ────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, left: 2, right: 4),
                    child: Builder(
                      builder: (context) {
                        final seenSources = <String>{};
                        final references = widget.lines
                            .map((line) => line
                                .trim()
                                .replaceFirst(
                                  RegExp(r'^(?:[-*•]|\d+[.)])\s*'),
                                  '',
                                )
                                .replaceAll(RegExp(r'^[#]+\s*'), '')
                                .trim())
                            .where((line) => line.isNotEmpty)
                            .where((line) {
                          final normalized =
                              line.replaceAll(':', '').trim().toUpperCase();
                          return normalized != 'REFERENCIAS' &&
                              normalized != 'REFERÊNCIAS' &&
                              normalized != '📚 REFERENCIAS' &&
                              normalized != '📚 REFERÊNCIAS';
                        }).where((line) {
                          final url = RegExp(r'https://[^\s<>]+')
                              .firstMatch(line)
                              ?.group(0)
                              ?.replaceFirst(RegExp(r'[)\].,;]+$'), '');
                          return seenSources.add(url ?? line);
                        }).toList();

                        return MarkdownBody(
                          data: references.join('\n\n'),
                          selectable: true,
                          onTapLink: (text, href, title) {
                            final uri = Uri.tryParse(href ?? '');
                            if (uri != null &&
                                uri.scheme == 'https' &&
                                uri.host.isNotEmpty &&
                                uri.userInfo.isEmpty) {
                              launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                  fontSize: 11, color: textColor, height: 1.4)),
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class CollapsibleClinicalReferenceBlock extends StatefulWidget {
  final List<String> lines;
  final bool dark;
  final String lang;

  const CollapsibleClinicalReferenceBlock({
    super.key,
    required this.lines,
    required this.dark,
    this.lang = 'pt',
  });

  @override
  State<CollapsibleClinicalReferenceBlock> createState() =>
      CollapsibleClinicalReferenceBlockState();
}

class CollapsibleClinicalReferenceBlockState
    extends State<CollapsibleClinicalReferenceBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isEs = widget.lang == 'es';
    final labelColor =
        widget.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textColor =
        widget.dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 14,
                  color: labelColor,
                ),
                const SizedBox(width: 6),
                Text(
                  isEs ? 'Referencia clínica' : 'Referência clínica',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 5, bottom: 4, left: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in widget.lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $line',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: textColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// The existing chat action footer, shared by Plantão, Estudo and history.
/// Rendering and callbacks only; no generation, permission or persistence API.
class ClinicalResponseFooter extends StatefulWidget {
  const ClinicalResponseFooter({
    super.key,
    required this.dark,
    this.lang = 'pt',
    this.createdAt,
    this.references = const [],
    this.relatedReferences = const [],
    this.onCopy,
    this.onTts,
    this.ttsReady = false,
    this.ttsPlaying = false,
    this.onToggleFull,
    this.fullExpanded = false,
    this.isDrugSheet = false,
  });
  final bool dark;
  final String lang;
  final DateTime? createdAt;
  final List<String> references, relatedReferences;
  final VoidCallback? onCopy, onTts, onToggleFull;
  final bool ttsReady, ttsPlaying, fullExpanded, isDrugSheet;

  @override
  State<ClinicalResponseFooter> createState() => _ClinicalResponseFooterState();
}

class _ClinicalResponseFooterState extends State<ClinicalResponseFooter> {
  bool referencesExpanded = false;
  static const green = Color(0xFF009C3B);

  @override
  Widget build(BuildContext context) {
    final es = widget.lang.startsWith('es');
    final hasReferences =
        widget.references.isNotEmpty || widget.relatedReferences.isNotEmpty;
    final neutral =
        widget.dark ? const Color(0xFFB5BDC8) : const Color(0xFF526071);
    final localTime = widget.createdAt?.toLocal();
    final time = localTime == null
        ? '—'
        : '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Divider(height: 1, color: neutral.withValues(alpha: .16)),
        LayoutBuilder(builder: (context, constraints) {
          double measure(String value, double size) {
            final painter = TextPainter(
              text: TextSpan(
                  text: value,
                  style:
                      TextStyle(fontSize: size, fontWeight: FontWeight.w500)),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          final labels = [
            if (hasReferences)
              widget.isDrugSheet
                  ? (es ? 'Fuentes' : 'Fontes')
                  : (es ? 'Referencias' : 'Referências'),
            if (widget.onToggleFull != null)
              widget.fullExpanded
                  ? (es
                      ? (widget.isDrugSheet
                          ? 'Ocultar ficha completa'
                          : 'Ocultar respuesta completa')
                      : (widget.isDrugSheet
                          ? 'Recolher ficha completa'
                          : 'Recolher resposta completa'))
                  : (widget.isDrugSheet
                      ? (es ? 'Ver ficha completa' : 'Ver ficha completa')
                      : (es
                          ? 'Ver respuesta completa'
                          : 'Ver resposta completa')),
            if (widget.onTts != null && widget.ttsReady)
              widget.ttsPlaying
                  ? (es ? 'Detener' : 'Parar')
                  : (es ? 'Escuchar' : 'Ouvir'),
            if (widget.onCopy != null) 'Copiar',
          ];
          final timeWidth = measure(time, 11);
          final labelledWidth = timeWidth +
              16 +
              labels.fold<double>(
                  0, (sum, label) => sum + measure(label, 12) + 41);
          final compact = constraints.maxWidth < labelledWidth;
          Widget action(
              {required String id,
              required String label,
              required IconData icon,
              required VoidCallback callback,
              bool active = false}) {
            final color = active ? green : neutral;
            final child = compact
                ? Icon(icon, size: 18, semanticLabel: label)
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 16),
                    const SizedBox(width: 5),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ]);
            return Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: TextButton(
                key: ValueKey(id),
                onPressed: callback,
                style: TextButton.styleFrom(
                    foregroundColor: color,
                    minimumSize: const Size(48, 48),
                    padding:
                        EdgeInsets.symmetric(horizontal: compact ? 8 : 10)),
                child: child,
              ),
            );
          }

          final left = <Widget>[
            Tooltip(
                message: es ? 'Hora del mensaje' : 'Horário da mensagem',
                child: Text(time,
                    key: const ValueKey('clinical_message_time'),
                    style: TextStyle(fontSize: 11, color: neutral))),
            if (hasReferences)
              action(
                  id: 'clinical_references_action',
                  label: widget.isDrugSheet
                      ? (es ? 'Fuentes' : 'Fontes')
                      : (es ? 'Referencias' : 'Referências'),
                  icon: Icons.menu_book_outlined,
                  active: referencesExpanded,
                  callback: () =>
                      setState(() => referencesExpanded = !referencesExpanded)),
            if (widget.onToggleFull != null)
              action(
                  id: 'guardia_full_response_action',
                  label: widget.fullExpanded
                      ? (es
                          ? (widget.isDrugSheet
                              ? 'Ocultar ficha completa'
                              : 'Ocultar respuesta completa')
                          : (widget.isDrugSheet
                              ? 'Recolher ficha completa'
                              : 'Recolher resposta completa'))
                      : (es
                          ? (widget.isDrugSheet
                              ? 'Ver ficha completa'
                              : 'Ver respuesta completa')
                          : (widget.isDrugSheet
                              ? 'Ver ficha completa'
                              : 'Ver resposta completa')),
                  icon: widget.fullExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  active: widget.fullExpanded,
                  callback: widget.onToggleFull!),
          ];
          final right = <Widget>[
            if (widget.onTts != null && widget.ttsReady)
              action(
                  id: 'guardia_tts_action',
                  label: widget.ttsPlaying
                      ? (es ? 'Detener' : 'Parar')
                      : (es ? 'Escuchar' : 'Ouvir'),
                  icon: widget.ttsPlaying
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_outlined,
                  active: widget.ttsPlaying,
                  callback: widget.onTts!),
            if (widget.onCopy != null)
              action(
                  id: 'guardia_copy_action',
                  label: 'Copiar',
                  icon: Icons.copy_outlined,
                  callback: widget.onCopy!),
          ];
          if (constraints.maxWidth < timeWidth + labels.length * 48 + 4) {
            return Wrap(
                spacing: 0,
                runSpacing: 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [...left, ...right]);
          }
          return Row(key: const ValueKey('clinical_footer_row'), children: [
            ...left,
            const Spacer(),
            ...right,
          ]);
        }),
        if (hasReferences)
          CollapsibleReferencesBlock(
              lines: [
                ...widget.references,
                if (widget.relatedReferences.isNotEmpty) ...[
                  '**${es ? 'Referencia clínica' : 'Referência clínica'}**',
                  ...widget.relatedReferences,
                ],
              ],
              dark: widget.dark,
              lang: widget.lang,
              showControl: false,
              expanded: referencesExpanded),
      ]),
    );
  }
}
