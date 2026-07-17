import 'package:flutter/material.dart';

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
