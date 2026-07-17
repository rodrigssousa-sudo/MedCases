import 'package:flutter/material.dart';

import 'mobile_ai_action_bar.dart';

class WaHeader extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;
  final int historyCount;
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
    this.isConnected = false,
    this.isPartner = false,
    this.partnerTitle = '',
    this.onAmbassador,
  });

  @override
  Widget build(BuildContext context) {
    // SUPER ORDEM MASTER 12 M1: BLACK TOPBAR FIXO — mesmo preto absoluto em qualquer modo
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E12),
        border: Border(
            bottom: BorderSide(
          color: Color(0xFF1E2128),
          width: 0.5,
        )),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            4, 8, 10, 8), // SUPER ORDEM MASTER 308 M2: 52px (+5px)
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Linha 1: seta voltar + título + ações ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back arrow — consistência com todas as telas secundárias
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.maybePop(context),
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),

                // Título bicolor MEDCASES (branco) + IA (ouro) + subtítulo split
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'MEDCASES',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            TextSpan(
                              text: ' IA',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD4AF37),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // SUPER ORDEM ESTRUTURAL 11: subtítulo MEDCASES PRO
                      // destruído — substituído pelo M+ vivo como leading direito.
                    ],
                  ),
                ),

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
                              color: Color(0xFF00E5FF),
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
                      color: const Color(0xFF00E5FF).withOpacity(0.10),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withOpacity(0.28),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 15,
                      color: Color(0xFF00E5FF),
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

            // Linha 2 removida — badge movido para a linha do título
          ],
        ),
      ),
    );
  }
}
