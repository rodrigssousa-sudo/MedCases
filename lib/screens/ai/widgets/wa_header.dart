import 'dart:ui' show ImageFilter;

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
    // MEDCASES_WEB_CANONICAL_TOPBAR_REAL_MENU_V1_B_R15
    // Mesmo contrato visual da topbar mobile; hamburger pertence ao MainShell.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF05070A);
    final secondary = dark ? Colors.white70 : const Color(0xFF59636E);
    final glass = dark
        ? const Color(0xFF252930).withOpacity(0.70)
        : Colors.white.withOpacity(0.70);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: glass,
            border: Border(bottom: BorderSide(color: divider, width: 0.7)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'MEDCASES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: foreground,
                        ),
                      ),
                      const TextSpan(
                        text: ' IA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: IconButton(
                    tooltip: lang == 'es' ? 'Volver' : 'Voltar',
                    onPressed: () => Navigator.maybePop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: foreground,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPartner && onAmbassador != null) ...[
                        _R14HeaderButton(
                          tooltip: partnerTitle.isEmpty
                              ? 'Ambassador'
                              : partnerTitle,
                          onTap: onAmbassador!,
                          child: const Text(
                            '♛',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFFD4AF37),
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                      ],
                      if (modeConfirmed && onModeTap != null) ...[
                        _R14HeaderButton(
                          tooltip: studyMode
                              ? (lang == 'es' ? 'Estudio' : 'Estudo')
                              : (lang == 'es' ? 'Guardia' : 'Plantão'),
                          onTap: onModeTap!,
                          child: Icon(
                            studyMode
                                ? Icons.school_outlined
                                : Icons.emergency_outlined,
                            size: 16,
                            color: secondary,
                          ),
                        ),
                        const SizedBox(width: 3),
                      ],
                      _R14HeaderButton(
                        tooltip: 'M+',
                        onTap: onSettings,
                        child: Text(
                          'M+',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isConnected
                                ? const Color(0xFF10B981)
                                : secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _R14HeaderButton(
                            tooltip: lang == 'es' ? 'Historial' : 'Histórico',
                            onTap: onHistory,
                            child: Icon(
                              Icons.history_rounded,
                              size: 17,
                              color: secondary,
                            ),
                          ),
                          if (historyCount > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 12,
                                  minHeight: 12,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD4AF37),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  historyCount > 9 ? '9+' : '$historyCount',
                                  style: const TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0C0E12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 3),
                      _R14HeaderButton(
                        tooltip: lang == 'es' ? 'Nuevo chat' : 'Novo chat',
                        onTap: onNewChat,
                        child: const Icon(
                          Icons.add_rounded,
                          size: 19,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 3),
                      _R14HeaderButton(
                        tooltip: lang == 'es' ? 'Menú' : 'Menu',
                        onTap: () => Scaffold.maybeOf(context)?.openEndDrawer(),
                        child: Icon(
                          Icons.menu_rounded,
                          size: 18,
                          color: secondary,
                        ),
                      ),
                    ],
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

class _R14HeaderButton extends StatelessWidget {
  const _R14HeaderButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 30, height: 30, child: Center(child: child)),
      ),
    ),
  );
}
