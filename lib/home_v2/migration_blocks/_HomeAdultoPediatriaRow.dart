class _HomeAdultoPediatriaRow extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final VoidCallback onTapAdulto;
  final VoidCallback onTapPediatria;

  const _HomeAdultoPediatriaRow({
    required this.dark,
    required this.isEs,
    required this.onTapAdulto,
    required this.onTapPediatria,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // B141: Emerald Green — #059669 → #10b981
      Expanded(child: _AgeCard(
        icon: Icons.person_rounded,
        // chore(home): renomeado ADULTO → PACIENTE (BUILD 238 PARTE 6)
        label: 'PACIENTE',
        subtitle: 'Explorar caso clínico',
        gradientColors: const [Color(0xFF022c22), Color(0xFF059669), Color(0xFF10b981)],
        accentColor: const Color(0xFF6ee7b7),
        dark: dark,
        onTap: onTapAdulto,
      )),
      const SizedBox(width: 4),  // ORDEM 45: mosaico 12→4 gap horizontal
      // B144: Azul Petróleo — dark teal elegante, nunca chega ao ciano
      Expanded(child: _AgeCard(
        icon: Icons.child_care_rounded,
        label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
        subtitle: isEs ? 'Casos clínicos de referencia' : 'Casos clínicos de referência',
        gradientColors: const [Color(0xFF042f2e), Color(0xFF0f766e), Color(0xFF134e4a)],
        accentColor: const Color(0xFFccfbf1),
        dark: dark,
        onTap: onTapPediatria,
      )),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME V2 — CALCULADORA (card full-width premium)
// Build 102: novo acesso direto à CalculadorasShell (ToolsScreen encapsulada)
// ═══════════════════════════════════════════════════════════════════════════════