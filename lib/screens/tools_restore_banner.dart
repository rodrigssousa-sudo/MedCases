// ══════════════════════════════════════════════════════════════════════════════
// tools_restore_banner.dart — BUILD 427-TOOLS-PERSISTENCE
//
// Banner discreto de reconexão de dados das ferramentas de cálculo.
//
// Aparece no topo da tela (abaixo do chip de importação) quando o
// toolsInputCache do AppProvider contém dados de uma sessão anterior.
//
// Design: fundo _kSurface, borda âmbar sutil, ícone 🧪, texto bilíngue,
// dois botões compactos [No, limpiar] e [Sí, rellenar].
//
// Animação: FadeTransition + SlideTransition 280ms ao aparecer.
// Dismissal: desaparece automaticamente após ação do usuário.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta (dark-first, espelhada das tool screens)
// ─────────────────────────────────────────────────────────────────────────────
const _kSurface = Color(0xFF1A1D23);
const _kAmber   = Color(0xFFF59E0B);
const _kCyan    = Color(0xFF00E5FF);
const _kRed     = Color(0xFFEF4444);
const _kTextSub = Color(0xFF8B9BB4);

// ═════════════════════════════════════════════════════════════════════════════
// ToolsRestoreBanner — widget animado de restauração
// ═════════════════════════════════════════════════════════════════════════════
class ToolsRestoreBanner extends StatefulWidget {
  final bool isEs;
  final bool dark;
  final VoidCallback onRestore;
  final VoidCallback onDiscard;

  const ToolsRestoreBanner({
    super.key,
    required this.isEs,
    required this.dark,
    required this.onRestore,
    required this.onDiscard,
  });

  @override
  State<ToolsRestoreBanner> createState() => _ToolsRestoreBannerState();
}

class _ToolsRestoreBannerState extends State<ToolsRestoreBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    // Arranca a animação de entrada imediatamente
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Dispara saída animada antes de invocar o callback
  Future<void> _dismiss(VoidCallback cb) async {
    await _ctrl.reverse();
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final dark  = widget.dark;
    final isEs  = widget.isEs;
    final surf  = dark ? _kSurface : Colors.white;
    final txt   = dark ? Colors.white : const Color(0xFF0F1116);
    final sub   = dark ? _kTextSub   : const Color(0xFF64748B);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _kAmber.withOpacity(dark ? 0.50 : 0.40),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kAmber.withOpacity(dark ? 0.06 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Ícone âmbar ────────────────────────────────────────────
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kAmber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('🧪', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),

                // ── Texto ──────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEs
                            ? '¿Continuar con datos anteriores?'
                            : 'Continuar com dados anteriores?',
                        style: TextStyle(
                          color: txt,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isEs
                            ? 'Hay datos del paciente anterior en memoria.'
                            : 'Há dados do paciente anterior em memória.',
                        style: TextStyle(
                          color: sub,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Botões compactos ───────────────────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // [No]
                    _BannerBtn(
                      label: isEs ? 'No' : 'Não',
                      color: _kRed.withOpacity(0.18),
                      textColor: _kRed,
                      onTap: () => _dismiss(widget.onDiscard),
                    ),
                    const SizedBox(width: 6),
                    // [Sí]
                    _BannerBtn(
                      label: isEs ? 'Sí' : 'Sim',
                      color: _kCyan.withOpacity(0.16),
                      textColor: _kCyan,
                      onTap: () => _dismiss(widget.onRestore),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BannerBtn — botão compacto interno do banner
// ─────────────────────────────────────────────────────────────────────────────
class _BannerBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _BannerBtn({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
