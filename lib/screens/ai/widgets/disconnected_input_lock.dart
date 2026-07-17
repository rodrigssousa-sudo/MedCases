import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DisconnectedInputLock — BUILD 277
//
// Replaces the InputBar for non-admin/non-master users when no AI connection
// is active. Shows:
//   • A ghosted, locked text field (AbsorbPointer + opacity 0.28)
//   • "Acesso Restrito à IA" label in muted text
//   • Premium ElevatedButton in MedCases crimson (#AC2A2A) to trigger Google Auth
//
// Design principle: the obstruction is intentional — it communicates clearly
// that connecting is required, without being alarmist (no red banners).
// ─────────────────────────────────────────────────────────────────────────────
class DisconnectedInputLock extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback onConnect;

  const DisconnectedInputLock({
    super.key,
    required this.dark,
    required this.lang,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFF5F5F5);
    final borderColor =
        dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    final labelColor =
        dark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.42);

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Ghosted text field (visual only) ──────────────────────────────
          Opacity(
            opacity: 0.28,
            child: AbsorbPointer(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  color: dark ? const Color(0xFF252930) : Colors.white,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: Text(
                  // ORDEM 47 M1: 🔒 prefix reforça o bloqueio visualmente
                  isEs
                      ? '🔒 Conecta Google para usar la IA...'
                      : '🔒 Conecte o Google para usar a IA...',
                  style: TextStyle(
                    fontSize: 14,
                    color: dark ? Colors.white54 : Colors.black38,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Access restricted label ─────────────────────────────────────
          Text(
            isEs ? 'Acceso Restringido a la IA' : 'Acesso Restrito à IA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: labelColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          // ── Premium connect button ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAC2A2A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              child: Text(
                isEs
                    ? '🔑 Conectar via Google para activar IA'
                    : '🔑 Conectar via Google para ativar IA',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
