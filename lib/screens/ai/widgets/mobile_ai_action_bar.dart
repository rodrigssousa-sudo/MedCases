import 'package:flutter/material.dart';

class MobileAiActionBar extends StatelessWidget {
  final bool dark;
  final String lang;
  final int historyCount;
  final bool hasMessages;
  final bool hasRealAi;
  final bool keyLoading;
  final bool
      forceDisconnectedLabel; // BUILD 275: show 'Desconectado' for non-admin
  final bool isConnected; // SUPER ORDEM ESTRUTURAL 11: M+ vivo
  final bool isPartner; // BUILD 310: Ambassador golden button
  final String partnerTitle; // BUILD 310: partner badge label
  final VoidCallback onHistory;
  final VoidCallback onClear;
  final VoidCallback onSettings;
  final VoidCallback? onNewChat;
  final VoidCallback? onAmbassador; // BUILD 310

  const MobileAiActionBar({
    super.key,
    required this.dark,
    required this.lang,
    required this.historyCount,
    required this.hasMessages,
    required this.hasRealAi,
    required this.keyLoading,
    required this.onHistory,
    required this.onClear,
    required this.onSettings,
    this.forceDisconnectedLabel = false,
    this.isConnected = false,
    this.isPartner = false,
    this.partnerTitle = '',
    this.onNewChat,
    this.onAmbassador,
  });

  @override
  Widget build(BuildContext context) {
    // ═══════════════════════════════════════════════════════════════════
    // BUILD 331 IA — TOPBAR CORRIGIDA: Stack com ordem Z explícita
    //
    // Fundo: SEMPRE #111622 dark sólido — sem adaptação ao tema do sistema.
    //
    // ORDEM DOS FILHOS DA STACK (Z-order, último = acima):
    //   1. IgnorePointer → RichText bicolor no centro geométrico
    //      Envolvido em IgnorePointer para que toques NÃO sejam absorvidos
    //      pelo texto — passam para widgets abaixo (área vazia do centro).
    //   2. Align(centerLeft) → GestureDetector → botão de conexão IA
    //      Renderizado por último → Z-order acima do título → recebe
    //      todos os eventos de toque na zona esquerda sem interferência.
    //   3. Align(centerRight) → SizedBox(40×40) completamente vazia
    //      Simetria visual: balanceia o peso horizontal da barra.
    //
    // MOTIVO DO DESCARTE DO NavigationToolbar:
    //   NavigationToolbar mede seu 'leading' antes de posicionar o 'middle'.
    //   O Container da pílula "Conectar IA" tem largura intrínseca ~95px;
    //   o toolbar tratou isso como ocupação do terço esquerdo e o title ficou
    //   deslocado / invisível. Stack com IgnorePointer resolve sem ambiguidade.
    // ═══════════════════════════════════════════════════════════════════
    // ═══════════════════════════════════════════════════════════════════
    // TOPBAR GEOMETRY — View.of(context) bypass
    //
    // PROBLEMA RAIZ: MainShell usa MediaQuery.removePadding(removeTop:true)
    // antes do IndexedStack. Qualquer SafeArea(top:true) ou
    // MediaQuery.of(ctx).padding.top dentro das telas recebe 0 — o inset
    // já foi consumido. O bypass correto é ler o padding FÍSICO diretamente
    // da FlutterView, que é imune ao removePadding do MediaQuery.
    //
    // View.of(context).padding.top → padding em logical pixels físicos
    // (já normalizado pelo devicePixelRatio internamente pelo Flutter).
    //
    // ESTRUTURA RESULTANTE:
    //   Container (fundo #111622, altura = topPad + 56)
    //     └── Padding(top: topPad)          ← empurra conteúdo abaixo do notch
    //           └── SizedBox(height: 56)    ← área interativa fixa
    //                 └── Stack (botão esq + título + espaço dir)
    // ═══════════════════════════════════════════════════════════════════
    final double topPad =
        View.of(context).padding.top / View.of(context).devicePixelRatio;

    return Container(
      width: double.infinity,
      height: topPad + 56,
      decoration: BoxDecoration(
        color:
            const Color(0xFF111622), // dark sólido — sangra até o topo físico
        border: const Border(
          bottom: BorderSide(color: Color(0xFF2D3340), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        // Empurra o conteúdo interativo para baixo da Dynamic Island / Notch.
        // Não usa SafeArea aqui — o padding físico real já foi capturado acima.
        padding: EdgeInsets.only(top: topPad),
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              // ── 1. BOTÃO DA ESQUERDA — POSIÇÃO ABSOLUTA, NUNCA SOBREPÕE O TÍTULO ──
              Positioned(
                left:
                    17, // BUILD 339: +5px de respiro em relação à quina física
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onSettings,
                    behavior: HitTestBehavior.opaque,
                    child: isConnected
                        // Conectado: avatar M+ verde pulsante
                        ? const MplusPulse()
                        // Desconectado: pílula ciana com borda e texto branco
                        : Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(7),
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.10),
                              border: Border.all(
                                color: const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.60),
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Conectar IA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              // ── 2. TÍTULO — CENTRO GEOMÉTRICO ABSOLUTO ──────────────────
              Align(
                alignment: Alignment.center,
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'MEDCASES ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: 'IA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFFD4AF37), // DOURADO PREMIUM
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── BUILD 310: AMBASSADOR GOLDEN BUTTON (RIGHT) ─────────────
              // Invisible to non-partners — Apple Safe.
              if (isPartner && onAmbassador != null)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: onAmbassador,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color:
                              const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          border: Border.all(
                            color:
                                const Color(0xFFD4AF37).withValues(alpha: 0.70),
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              partnerTitle.isNotEmpty
                                  ? partnerTitle
                                  : 'Embaixador',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD4AF37),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MplusPulse extends StatefulWidget {
  final double
      opacity; // ignorado internamente — mantido para compatibilidade de chamada
  const MplusPulse({super.key, this.opacity = 1.0});
  @override
  State<MplusPulse> createState() => MplusPulseState();
}

class MplusPulseState extends State<MplusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (!mounted) return;
        if (status == AnimationStatus.completed) _ctrl.reverse();
        if (status == AnimationStatus.dismissed) _ctrl.forward();
      });
    _anim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: const Text(
          'M+',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF10B981), // Verde Clínico — IA conectada
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
