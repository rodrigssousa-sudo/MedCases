class _HomeBibliotecaHClinicaRow extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final Function(int) onTabChange;

  const _HomeBibliotecaHClinicaRow({
    required this.dark,
    required this.isEs,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // ── BIBLIOTECA — B141: Elegant Gray #475569 → #64748b ───────────────
      Expanded(child: _AgeCard(
        icon: Icons.menu_book_rounded,
        label: 'BIBLIOTECA',
        subtitle: isEs ? 'Referencias clínicas' : 'Referências clínicas',
        gradientColors: const [Color(0xFF1e293b), Color(0xFF475569), Color(0xFF64748b)],
        accentColor: const Color(0xFFe2e8f0),
        dark: dark,
        onTap: () => onTabChange(5),
      )),
      const SizedBox(width: 4),  // ORDEM 45: mosaico 12→4 gap horizontal
      // ── H. CLÍNICA — B141: Orange Vibrant #ea580c → #fb923c ─────────────
      Expanded(child: _AgeCard(
        icon: Icons.assignment_ind_outlined,
        label: 'H. CLÍNICA',
        subtitle: isEs ? 'Historial del paciente' : 'Histórico do paciente',
        gradientColors: const [Color(0xFF431407), Color(0xFFea580c), Color(0xFFfb923c)],
        accentColor: const Color(0xFFfed7aa),
        dark: dark,
        onTap: () => onTabChange(3),
      )),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME V2 — MIGUARDIA SECTION (item 6)
// Wrapper da seção MiGuardia — card limpo com padding interno.
// ═══════════════════════════════════════════════════════════════════════════════