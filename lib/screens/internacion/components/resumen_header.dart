// ─────────────────────────────────────────────────────────────────────────────
// ResumenHeader — card de identificação Paciente / Cama no topo da tela.
// Exibe nome/ID do paciente, cama, diagnóstico e dia de internação.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'internacion_theme.dart';

class ResumenHeader extends StatelessWidget {
  final String pacienteId;
  final String cama;
  final String diagnostico;
  final int diadeInternacion;
  final bool dark;
  final String lang;

  const ResumenHeader({
    super.key,
    required this.pacienteId,
    required this.cama,
    required this.diagnostico,
    required this.diadeInternacion,
    required this.dark,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(dark);
    final isEs  = lang == 'es';

    final diaLabel = isEs
        ? (diadeInternacion == 1 ? '1er día' : '${diadeInternacion}º día')
        : ('${diadeInternacion}º dia');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border, width: 0.8),
        boxShadow: [theme.softShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Avatar do paciente ───────────────────────────────────────────
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: InternacionTheme.cyan.withValues(alpha: dark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: InternacionTheme.cyan.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: const Center(
              child: Icon(Icons.person_outline_rounded,
                  size: 24, color: InternacionTheme.cyan),
            ),
          ),
          const SizedBox(width: 12),

          // ── Info do paciente ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome / ID
                Text(
                  pacienteId.isEmpty
                      ? (isEs ? 'Paciente sin identificar' : 'Paciente não identificado')
                      : pacienteId,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Diagnóstico
                if (diagnostico.isNotEmpty) ...[
                  Text(
                    diagnostico,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                ],
                // Cama + Dia
                Row(
                  children: [
                    if (cama.isNotEmpty) ...[
                      Icon(Icons.bed_rounded, size: 12, color: theme.labelColor),
                      const SizedBox(width: 3),
                      Text(
                        '${isEs ? 'Cama' : 'Leito'} $cama',
                        style: TextStyle(fontSize: 11, color: theme.labelColor),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Icon(Icons.calendar_today_rounded,
                        size: 11, color: InternacionTheme.cyan.withValues(alpha: 0.70)),
                    const SizedBox(width: 3),
                    Text(
                      diaLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: InternacionTheme.cyan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Dia badge ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: InternacionTheme.cyan.withValues(alpha: dark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${isEs ? 'DÍA' : 'DIA'}',
                  style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: InternacionTheme.cyan.withValues(alpha: 0.70),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$diadeInternacion',
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: InternacionTheme.cyan,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
