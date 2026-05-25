// protocol_checklist_widget.dart
// Feature 1 — Checklists Interativos de Emergência
//
// Uso:
//   ProtocolChecklistWidget(
//     steps: protocol.getActions(p.lang),
//     isEs: p.lang == 'es',
//   )
//
// • Estado local: quando o médico fechar e reabrir o protocolo, o checklist
//   reinicia do zero (sem persistência proposital — padrão de segurança clínica).
// • Design customizado: sem o Checkbox padrão do Material.
// • Animação suave de check com AnimatedContainer + AnimatedDefaultTextStyle.
// • Progresso visual no topo com barra animada (LinearProgressIndicator custom).
// • Botão de reset discreto quando ao menos 1 item está marcado.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/common_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class ProtocolChecklistWidget extends StatefulWidget {
  final List<String> steps;
  final bool isEs;

  const ProtocolChecklistWidget({
    super.key,
    required this.steps,
    this.isEs = true,
  });

  @override
  State<ProtocolChecklistWidget> createState() =>
      _ProtocolChecklistWidgetState();
}

class _ProtocolChecklistWidgetState extends State<ProtocolChecklistWidget>
    with TickerProviderStateMixin {
  // Estado local puro — sem persistência (reinicia ao fechar o protocolo)
  late List<bool> _checked;

  // Animação de "todas concluídas" (fade-in do banner de sucesso)
  late AnimationController _completionCtrl;
  late Animation<double> _completionFade;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.steps.length, false);

    _completionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _completionFade = CurvedAnimation(
      parent: _completionCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _completionCtrl.dispose();
    super.dispose();
  }

  int get _checkedCount => _checked.where((v) => v).length;
  int get _total => widget.steps.length;
  bool get _allDone => _checkedCount == _total && _total > 0;

  void _toggle(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _checked[index] = !_checked[index];
    });
    // Verifica se completou tudo
    if (_allDone) {
      _completionCtrl.forward();
    } else {
      _completionCtrl.reverse();
    }
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() => _checked = List.filled(widget.steps.length, false));
    _completionCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (widget.steps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho da seção com progresso ───────────────────────────────
        _ChecklistHeader(
          checkedCount: _checkedCount,
          total: _total,
          isEs: widget.isEs,
          colors: c,
          onReset: _checkedCount > 0 ? _reset : null,
        ),
        const SizedBox(height: 10),

        // ── Barra de progresso animada ──────────────────────────────────────
        _ProgressBar(progress: _total > 0 ? _checkedCount / _total : 0.0),
        const SizedBox(height: 12),

        // ── Lista de itens ─────────────────────────────────────────────────
        ...List.generate(widget.steps.length, (i) {
          return _ChecklistItem(
            index: i,
            text: widget.steps[i],
            isChecked: _checked[i],
            onTap: () => _toggle(i),
            colors: c,
          );
        }),

        // ── Banner de conclusão ─────────────────────────────────────────────
        FadeTransition(
          opacity: _completionFade,
          child: _allDone
              ? _CompletionBanner(isEs: widget.isEs, colors: c)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CABEÇALHO COM CONTADOR E BOTÃO RESET
// ─────────────────────────────────────────────────────────────────────────────

class _ChecklistHeader extends StatelessWidget {
  final int checkedCount;
  final int total;
  final bool isEs;
  final AppColors colors;
  final VoidCallback? onReset;

  const _ChecklistHeader({
    required this.checkedCount,
    required this.total,
    required this.isEs,
    required this.colors,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final label = isEs ? 'LISTA DE ACCIONES' : 'LISTA DE AÇÕES';
    final countLabel = '$checkedCount/$total ${isEs ? 'completados' : 'concluídos'}';

    return Row(
      children: [
        // Ícone
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.checklist_rounded,
            size: 16,
            color: colors.green,
          ),
        ),
        const SizedBox(width: 10),

        // Título + contador
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  color: colors.gold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                countLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Botão de reset — só aparece quando há marcações
        AnimatedOpacity(
          opacity: onReset != null ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: GestureDetector(
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.restart_alt_rounded,
                      size: 13, color: colors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    isEs ? 'Reiniciar' : 'Reiniciar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRA DE PROGRESSO ANIMADA
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double progress; // 0.0 a 1.0

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDone = progress >= 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: progress),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (_, value, __) {
          return LinearProgressIndicator(
            value: value,
            minHeight: 5,
            backgroundColor: c.border,
            valueColor: AlwaysStoppedAnimation(
              isDone ? const Color(0xFF22C55E) : c.green,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEM DO CHECKLIST — o coração do widget
// ─────────────────────────────────────────────────────────────────────────────

class _ChecklistItem extends StatelessWidget {
  final int index;
  final String text;
  final bool isChecked;
  final VoidCallback onTap;
  final AppColors colors;

  const _ChecklistItem({
    required this.index,
    required this.text,
    required this.isChecked,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isChecked
                ? colors.green.withValues(alpha: colors.dark ? 0.10 : 0.06)
                : colors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isChecked
                  ? colors.green.withValues(alpha: 0.35)
                  : colors.border,
              width: isChecked ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Número do passo
              SizedBox(
                width: 22,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isChecked
                        ? colors.green.withValues(alpha: 0.6)
                        : colors.textHint,
                    height: 1.5,
                  ),
                ),
              ),

              // Texto do passo
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: isChecked
                        ? colors.textPrimary.withValues(alpha: 0.38)
                        : colors.textPrimary,
                    decoration: isChecked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor:
                        colors.textSecondary.withValues(alpha: 0.5),
                    decorationThickness: 1.5,
                  ),
                  child: Text(text),
                ),
              ),

              const SizedBox(width: 10),

              // Checkbox customizado
              _CustomCheckbox(isChecked: isChecked, colors: colors),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHECKBOX CUSTOMIZADO — elegante, sem o visual Material padrão
// ─────────────────────────────────────────────────────────────────────────────

class _CustomCheckbox extends StatelessWidget {
  final bool isChecked;
  final AppColors colors;

  const _CustomCheckbox({required this.isChecked, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isChecked ? colors.green : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isChecked
              ? colors.green
              : colors.borderStrong,
          width: 1.8,
        ),
        boxShadow: isChecked
            ? [
                BoxShadow(
                  color: colors.green.withValues(alpha: 0.30),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: isChecked
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER DE CONCLUSÃO — aparece com fade quando todos os itens são marcados
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionBanner extends StatelessWidget {
  final bool isEs;
  final AppColors colors;

  const _CompletionBanner({required this.isEs, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            const Text('✅', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEs
                    ? 'Protocolo completado. Continúe con la monitorización del paciente.'
                    : 'Protocolo concluído. Prossiga com a monitorização do paciente.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF16A34A),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
