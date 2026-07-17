import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════
// ActionCardButton — Build 192: componente único para todos os botões de ação
//
// Design system flat premium: Linear / Arc Browser.
// Mesmo raio, altura, padding, tipografia, hover e animação.
// Diferenciação APENAS por cor (azul institucional IA vs verde esmeralda ferramenta).
// ORDEM VISUAL 02: backgrounds ultra-elegantes alpha 0.06/0.12, bordas 1.0px
// translúcidas, sombra mínima blurRadius:4, tap feedback escala 0.97.
// ═════════════════════════════════════════════════════════════════════════════
class ActionCardButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor; // cor de identidade do botão
  final VoidCallback onTap;
  final bool dark;

  const ActionCardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    required this.dark,
  });

  @override
  State<ActionCardButton> createState() => _ActionCardButtonState();
}

class _ActionCardButtonState extends State<ActionCardButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _hovered = false;
  // BUILD 256: flag de debounce interno — bloqueia tap duplo durante a janela
  // de 300ms entre o clique e o _isStreaming=true do provider.
  // Sem esta flag, dois taps rápidos (<300ms de intervalo) podiam disparar dois
  // sendAiMessage() consecutivos antes do guard de streaming ativar.
  bool _tapping = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (_tapping) return; // BUILD 256: bloqueia segundo tap imediato
    _ctrl.forward();
  }

  void _onTapUp(_) {
    if (_tapping) return; // BUILD 256: ignora tap duplicado
    _ctrl.reverse();
    // Marca como processando por 500ms — cobre a janela do debounce (300ms)
    // mais margem de segurança até _isStreaming=true ativar no provider.
    setState(() => _tapping = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _tapping = false);
    });
    widget.onTap();
  }

  void _onTapCancel() {
    _ctrl.reverse();
    if (mounted) setState(() => _tapping = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    // ── ORDEM VISUAL 02: flat premium backgrounds ─────────────────────────────
    // Rest: alpha ultra-elegante 0.06 light / 0.12 dark
    // Hover: slightly elevated 0.11 light / 0.20 dark
    // Tap (_tapping): escurece fundo para feedback imediato
    final bg = widget.dark
        ? accent.withValues(alpha: 0.12)
        : accent.withValues(alpha: 0.06);
    final bgHover = widget.dark
        ? accent.withValues(alpha: 0.20)
        : accent.withValues(alpha: 0.11);
    final bgTap = widget.dark
        ? accent.withValues(alpha: 0.28)
        : accent.withValues(alpha: 0.16);

    // Bordas translúcidas — 1.0px sólida, quase invisível em repouso
    final border = widget.dark
        ? accent.withValues(alpha: 0.30)
        : accent.withValues(alpha: 0.20);
    final borderHover = widget.dark
        ? accent.withValues(alpha: 0.55)
        : accent.withValues(alpha: 0.38);

    // Texto e ícone: accentColor puro (sólido) — sem opacidade fraca
    final textColor = widget.dark ? accent.withValues(alpha: 1.0) : accent;

    // Sombra mínima para descolar do fundo — sem sombra pesada em hover
    final shadow = BoxShadow(
      color: accent.withValues(alpha: widget.dark ? 0.15 : 0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    );

    // Estado de fundo efetivo: tap > hover > rest
    final effectiveBg = _tapping ? bgTap : (_hovered ? bgHover : bg);
    final effectiveBorder = (_hovered && !_tapping) ? borderHover : border;

    return MouseRegion(
      cursor: _tapping ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: effectiveBorder,
                width: 1.0,
              ),
              // Sombra mínima — apenas descola do fundo, sem glow
              boxShadow: [shadow],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 15, color: textColor),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
