// ─────────────────────────────────────────────────────────────────────────────
// HistorialSection — linha do tempo de evoluções anteriores.
// Se lista vazia → SizedBox.shrink() (zero espaço, sem padding fantasma).
// Se há evoluções → timeline compacta com estado clínico + data.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../models/evolucion_model.dart';
import '../components/internacion_theme.dart';

class HistorialSection extends StatelessWidget {
  final List<EvolucionModel> evoluciones;
  final bool dark;
  final String lang;
  final ValueChanged<EvolucionModel>? onTap;

  const HistorialSection({
    super.key,
    required this.evoluciones,
    required this.dark,
    required this.lang,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ── LÓGICA SÊNIOR: lista vazia → zero px, sem padding fantasma ─────────
    if (evoluciones.isEmpty) return const SizedBox.shrink();

    final theme = InternacionTheme(dark);
    final isEs  = lang == 'es';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.history_rounded, size: 15, color: theme.labelColor),
            const SizedBox(width: 6),
            Text(
              isEs ? 'HISTORIAL DE EVOLUCIONES' : 'HISTÓRICO DE EVOLUÇÕES',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8,
                color: theme.labelColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: InternacionTheme.cyan.withOpacity(dark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${evoluciones.length}',
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: InternacionTheme.cyan,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Timeline ──────────────────────────────────────────────────────
        ...evoluciones.reversed.toList().asMap().entries.map((e) {
          final idx = e.key;
          final ev  = e.value;
          final isLast = idx == evoluciones.length - 1;
          final estadoColor = ev.evaluacion.estado != null
              ? Color(ev.evaluacion.estado!.colorValue)
              : theme.textSecondary;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Linha do tempo ───────────────────────────────────────
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: estadoColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: dark
                                ? const Color(0xFF161920)
                                : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            color: theme.border,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Card de evolução ─────────────────────────────────────
                Expanded(
                  child: GestureDetector(
                    onTap: onTap != null ? () => onTap!(ev) : null,
                    child: Container(
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.border, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ev.fechaFormatada,
                                  style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: theme.textPrimary,
                                  ),
                                ),
                                if (ev.evaluacion.estado != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    ev.evaluacion.estado!.label(lang),
                                    style: TextStyle(
                                      fontSize: 10.5, color: estadoColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (ev.evaluacion.problemasActivos.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    ev.evaluacion.problemasActivos.take(2).join(' · '),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (onTap != null)
                            Icon(Icons.chevron_right_rounded,
                                size: 16, color: theme.labelColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
