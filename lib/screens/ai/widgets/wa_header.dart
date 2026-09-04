// MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_4A_V2_B_R1_AI_WIDGETS
import 'package:flutter/material.dart';

import 'mobile_ai_action_bar.dart';

class WaHeader extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;
  final int historyCount;

  // AI-VIS-B.2.6-R1 — mesmo estado visual da topbar mobile.
  final String lang;
  final bool modeConfirmed;
  final bool studyMode;
  final VoidCallback? onModeTap;
  final bool isConnected; // SUPER ORDEM ESTRUTURAL 11: M+ vivo
  final bool isPartner; // BUILD 310: Ambassador golden button
  final String partnerTitle; // BUILD 310
  final VoidCallback? onAmbassador; // BUILD 310
  const WaHeader({
    super.key,
    required this.onSettings,
    required this.onHistory,
    required this.onNewChat,
    required this.historyCount,
    this.lang = 'es',
    this.modeConfirmed = false,
    this.studyMode = true,
    this.onModeTap,
    this.isConnected = false,
    this.isPartner = false,
    this.partnerTitle = '',
    this.onAmbassador,
  });

  @override
  Widget build(BuildContext context) {
    // MEDCASES_WEB_HOME_AI_TOPBAR_PARITY_V1_B_R1
    // Web desktop: 48px + tipografia canônica da Home + sem back affordance.
    // SUPER ORDEM MASTER 12 M1: BLACK TOPBAR FIXO — mesmo preto absoluto em qualquer modo
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E12),
        border: Border(
            bottom: BorderSide(
          color: Color(0xFF1E2128),
          width: 0.5,
        )),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Linha 1: título central canônico + ações à direita ─────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Duas alas flexíveis de mesmo peso preservam o centro geométrico
                // do título mesmo com M+, histórico, novo chat e menu à direita.
                const Expanded(child: SizedBox.shrink()),
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'MEDCASES ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        TextSpan(
                          text: 'IA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF009C3B),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // ── BUILD 310: AMBASSADOR GOLDEN BUTTON — Apple Safe ─────
                                      if (isPartner && onAmbassador != null) ...[
                                        GestureDetector(
                                          onTap: onAmbassador,
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            height: 28,
                                            padding: const EdgeInsets.symmetric(horizontal: 9),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(7),
                                              color: const Color(0xFFD4AF37).withOpacity(0.13),
                                              border: Border.all(
                                                color: const Color(0xFFD4AF37).withOpacity(0.60),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text('👑', style: TextStyle(fontSize: 11)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  partnerTitle.isNotEmpty
                                                      ? partnerTitle
                                                      : 'Embaixador',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFFD4AF37),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],

                                      // O modo confirmado permanece funcional, mas não é
                                      // projetado visualmente na topbar desktop.

                                      // ── M+ VIVO — status da IA — SUPER ORDEM ESTRUTURAL 11 ────
                                      GestureDetector(
                                        onTap: onSettings,
                                        behavior: HitTestBehavior.opaque,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                          child: isConnected
                                              ? MplusPulse(
                                                  opacity: 1.0) // animação gerenciada internamente
                                              : const Text(
                                                  'Conectar IA',
                                                  style: TextStyle(
                                                    fontSize: 13, // SUPER ORDEM MASTER 12 M2: 12→13
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0D6B57),
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),

                                      // ── Ações direita — M308 M2: botões mais finos/delicados ──
                                      // Botão histórico
                                      GestureDetector(
                                        onTap: onHistory,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                color: Colors.white.withOpacity(0.06),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.08),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Icon(Icons.history_rounded,
                                                  size: 14, color: Colors.white.withOpacity(0.70)),
                                            ),
                                            if (historyCount > 0)
                                              Positioned(
                                                top: -3,
                                                right: -3,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Color(0xFFC5A365),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '$historyCount',
                                                      style: const TextStyle(
                                                        fontSize: 6.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: Color(0xFF1A1D23),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 5),

                                      // ── Botão Novo Chat — ícone minimalista ───────────────────
                                      GestureDetector(
                                        onTap: onNewChat,
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            color: const Color(0xFF0D6B57).withOpacity(0.10),
                                            border: Border.all(
                                              color: const Color(0xFF0D6B57).withOpacity(0.28),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.add_rounded,
                                            size: 15,
                                            color: Color(0xFF0D6B57),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),

                                      // Botão menu
                                      GestureDetector(
                                        onTap: () => Scaffold.of(context).openEndDrawer(),
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            color: Colors.white.withOpacity(0.06),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.08),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Icon(Icons.menu_rounded,
                                              size: 14, color: Colors.white.withOpacity(0.70)),
                                        ),
                                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Linha 2 removida — badge movido para a linha do título
          ],
        ),
      ),
    );
  }
}
