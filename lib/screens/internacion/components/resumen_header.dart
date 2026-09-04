// ─────────────────────────────────────────────────────────────────────────────
// ResumenHeader — card de identificação Paciente / Cama no topo da tela.
// Exibe nome/ID do paciente, cama, diagnóstico e dia de internação.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'internacion_theme.dart';


class ResumenHeader extends StatelessWidget {
  // MEDCASES_PACIENTES_FINAL_SUMMARY_SOURCE_DRIVEN_V2
  // MEDCASES_PACIENTES_PHYSICAL_CARD_V1
  // MEDCASES_PACIENTES_SUMMARY_BORDERLESS_V1
  // MEDCASES_PACIENTES_SUMMARY_EDGE_0_5PX_V1
  // MEDCASES_PACIENTES_HOME_COMPACT_SUMMARY_V1_B_R0
  // MEDCASES_PACIENTES_FINAL_BREATHING_SUMMARY_V1_B_R0
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
    final isEs = lang == 'es';
    final theme = InternacionTheme(dark);
    final surface = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final title = pacienteId.isEmpty
        ? (isEs ? 'Paciente sin identificar' : 'Paciente não identificado')
        : pacienteId;

    final meta = <String>[
      if (cama.trim().isNotEmpty)
        '${isEs ? 'Cama' : 'Leito'} ${cama.trim()}',
      if (diagnostico.trim().isNotEmpty) diagnostico.trim(),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12.5),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: InternacionTheme.accentLight.withOpacity(
                dark ? 0.14 : 0.10,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_outline_rounded,
              size: 19,
              color: InternacionTheme.accentLight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                    height: 1.15,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${isEs ? 'DÍA' : 'DIA'} $diadeInternacion',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: InternacionTheme.accentLight,
            ),
          ),
        ],
      ),
    );
  }
}
