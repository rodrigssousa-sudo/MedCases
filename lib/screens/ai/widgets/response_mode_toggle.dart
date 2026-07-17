import 'package:flutter/material.dart';

class ResponseModeToggle extends StatelessWidget {
  final bool
      value; // Build 152: renamed from longResponse → value (state-binding fix)
  final bool dark;
  final String lang;
  final ValueChanged<bool> onChanged;

  const ResponseModeToggle({
    super.key,
    required this.value,
    required this.dark,
    required this.lang,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEs = lang == 'es';

    // Build 158.2 — Labels texto puro, sem emojis/ícones (visual sóbrio e profissional)
    final labelGuardia = isEs ? 'Guardia' : 'Plantão';
    final labelEstudio = isEs ? 'Estudio' : 'Estudos';

    // Build 158.2 — Pills minimalistas:
    // Ativo: fundo transparente + borda ciano fina e nítida (SEM glow/sombra)
    // Inativo: fundo cinza sólido discreto, sem borda especial
    const neonCyan = Color(0xFF00E5FF);
    final inactiveText =
        dark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.45);
    final inactiveBg = dark ? const Color(0xFF374151) : const Color(0xFFE0E0E0);

    Widget pill({
      required String label,
      required bool isActive,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            // Ativo: transparente + borda ciano sólida e nítida (sem glow)
            // Inativo: cinza sólido sem borda especial
            color: isActive ? Colors.transparent : inactiveBg,
            borderRadius: BorderRadius.circular(24),
            border: isActive
                ? Border.all(color: neonCyan, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
            // Build 158.2: sem boxShadow — eliminado glow neon por completo
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? neonCyan : inactiveText,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
      child: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          // BUILD 283 ORDEM 10.4: Estudos ESQUERDA (gratuito/padrão) | Plantão DIREITA
          children: [
            pill(
              label: labelEstudio,
              isActive: value,
              onTap: () => onChanged(true),
            ),
            const SizedBox(width: 8),
            pill(
              label: labelGuardia,
              isActive: !value,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ),
    );
  }
}
