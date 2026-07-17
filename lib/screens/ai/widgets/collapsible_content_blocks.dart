import 'package:flutter/material.dart';

import '../../../models/drug_model.dart' show DrugEvidenceModel;
import '../../../widgets/common_widgets.dart'
    show EvidenceBadgesRow, EvidenceCardWidget, PharmacologicalDisclaimer;

class CollapsibleReferencesBlock extends StatefulWidget {
  final List<String> lines; // linhas de referência (sem o cabeçalho 📚)
  final bool dark;
  final String lang; // 'es' ou 'pt'
  const CollapsibleReferencesBlock({
    super.key,
    required this.lines,
    required this.dark,
    this.lang = 'pt',
  });

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
                  const Text('📚', style: TextStyle(fontSize: 13)),
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
                    turns: _expanded ? 0.5 : 0.0,
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
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, left: 2, right: 4),
                    child: Builder(
                      builder: (context) {
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
                            })
                            .toSet()
                            .toList();

                        return Text(
                          references.join('\n'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: textColor,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
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

class CollapsibleEvidenceBlock extends StatefulWidget {
  final DrugEvidenceModel ev;
  final bool dark;
  const CollapsibleEvidenceBlock({
    super.key,
    required this.ev,
    required this.dark,
  });

  @override
  State<CollapsibleEvidenceBlock> createState() =>
      CollapsibleEvidenceBlockState();
}

class CollapsibleEvidenceBlockState extends State<CollapsibleEvidenceBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;

    // Build 127 — Flat UI total: sem fundo sólido, label colorido flutuante no scaffold
    final labelColor = dark ? const Color(0xFF34D399) : const Color(0xFF059669);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Trigger: label flutuante, zero container fill ────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📊',
                    style: TextStyle(
                        fontSize: 12,
                        color: labelColor.withValues(alpha: 0.8))),
                const SizedBox(width: 5),
                Text(
                  'EVIDÊNCIA CIENTÍFICA',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                    letterSpacing: 0.65,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(Icons.expand_more_rounded,
                      size: 14, color: labelColor.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
        ),

        // ── Conteúdo expandido — flat, sem borda ou fundo ────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.only(top: 2, bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EvidenceBadgesRow(ev: widget.ev, compact: true),
                      const SizedBox(height: 6),
                      EvidenceCardWidget(ev: widget.ev),
                      const SizedBox(height: 6),
                      const PharmacologicalDisclaimer(),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
