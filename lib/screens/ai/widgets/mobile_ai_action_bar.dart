import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  // AI-VIS-B.2.6-R1 — projeção visual do modo confirmado.
  final bool modeConfirmed;
  final bool studyMode;
  final VoidCallback? onModeTap;
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
    this.modeConfirmed = false,
    this.studyMode = true,
    this.onModeTap,
    this.onNewChat,
    this.onAmbassador,
  });

  @override
  Widget build(BuildContext context) {
    // ═══════════════════════════════════════════════════════════════════
    // AI-VIS-B.2.4-R2 — topbar da IA espelha o vidro da Home.
    //
    // O inset físico continua sendo lido diretamente da FlutterView.
    // M+, callbacks, conexão e embaixador permanecem proprietários.
    final double topPad =
        View.of(context).padding.top / View.of(context).devicePixelRatio;

    final glassColor = dark
        ? const Color(0xFF252930).withOpacity(0.70)
        : Colors.white.withOpacity(0.70);

    final borderColor =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    final titlePrimaryColor =
        dark ? Colors.white : const Color(0xFF05070A);

    return SizedBox(
      width: double.infinity,
      height: topPad + 48,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              border: Border(
                bottom: BorderSide(
                  color: borderColor,
                  width: 0.7,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: topPad),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
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
                    child: AiConnectionIdentity(
                      isConnected: isConnected,
                    ),
                  ),
                ),
              ),

              // ── 2. TÍTULO — CONTRATO TIPOGRÁFICO DA HOME ─────────────
              Align(
                alignment: Alignment.center,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'MEDCASES ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: titlePrimaryColor,
                        ),
                      ),
                      TextSpan(
                        text: 'IA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: dark
                              ? const Color(0xFF009C3B)
                              : const Color(0xFF009C3B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // O modo confirmado permanece funcional, mas não é
              // projetado visualmente na topbar.

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
          ),
        ),
      ),
    );
}
}
// MEDCASES_AI_CONNECTION_IDENTITY_SUPERBUILD_V1_B_R3
class AiConnectionIdentity extends StatelessWidget {
  final bool isConnected;

  const AiConnectionIdentity({
    super.key,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: isConnected
          ? const SizedBox(
              key: ValueKey<String>('ai-connected'),
              width: 34,
              height: 36,
              child: Align(
                alignment: Alignment.centerLeft,
                child: MplusPulse(),
              ),
            )
          : Transform.translate(
              key: const ValueKey<String>('ai-disconnected'),
              offset: const Offset(0, 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/home_v2/ic_ia_disconnected.svg',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Conectar IA',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEF4444),
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class MplusPulse extends StatefulWidget {
  final double opacity;

  const MplusPulse({
    super.key,
    this.opacity = 1.0,
  });

  @override
  State<MplusPulse> createState() => MplusPulseState();
}

class MplusPulseState extends State<MplusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _lift;
  late final Animation<double> _tilt;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);

    _lift = Tween<double>(
      begin: 0,
      end: -4,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _tilt = Tween<double>(
      begin: -0.5235987755982988,
      end: 0.5235987755982988,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: SvgPicture.asset(
        'assets/icons/home_v2/ic_ia.svg',
        width: 28,
        height: 28,
        fit: BoxFit.contain,
      ),
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 2 + _lift.value),
        child: Transform.rotate(
          angle: _tilt.value,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }
}
