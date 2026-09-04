class _HomeMiGuardiaSection extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final Function(dynamic) onOpenDrug;
  final Function(String) onOpenCalc;
  final VoidCallback onManageTap;
  // Build 195: passa PacienteSession para pr\u00e9-carregar ao navegar para InternacionScreen
  final void Function(PacienteSession session)? onOpenInternacion;

  const _HomeMiGuardiaSection({
    required this.dark,
    required this.isEs,
    required this.onOpenDrug,
    required this.onOpenCalc,
    required this.onManageTap,
    this.onOpenInternacion,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = dark ? const Color(0xFF252930) : Colors.white;
    // BUILD 437 [PASSO 1]: acento lateral adaptativo.
    // Dark: dourado quente / Light: slate-400 sutil (sem neon amarelo sobre branco)
    final leftAccent = dark ? const Color(0xFFC5A365) : Colors.grey.shade400;
    // BUILD 437 [PASSO 1]: borda do card adaptativa.
    // Dark: branco translúcido / Light: grey.shade300 (borda fina sutil premium)
    final border = dark
        ? Colors.white.withOpacity(0.07)
        : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
        boxShadow: dark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 3, color: leftAccent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: MeuPlantaoDashboard(
                  onOpenDrug:  onOpenDrug,
                  onOpenCalc:  onOpenCalc,
                  onManageTap: onManageTap,
                  onOpenInternacion: onOpenInternacion,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIVISOR DECORATIVO
// ─────────────────────────────────────────────────────────────────────────────