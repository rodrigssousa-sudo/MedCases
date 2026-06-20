// ─────────────────────────────────────────────────────────────────────────────
// FarmacosAccordion — Build 162.1 — Chips Dinâmicos Premium
//
// UX de chips para "Fármacos que el paciente está tomando":
//
//   CHIPS DINÂMICOS (IA ou manual):
//     • Cada fármaco = chip clicável com [Medicamento · Dosagem] + botão ✕
//     • Chips renderizados via Wrap — fluem naturalmente em múltiplas linhas
//     • Animação de entrada: FadeTransition + SizeTransition por chip
//
//   ENTRADA MANUAL — Single Smart TextField:
//     • Um único campo de texto no final dos chips
//     • Dispara criação de chip ao pressionar:
//         Enter  →  adiciona chip (medicamento completo sem dosagem)
//         +      →  mesmo que Enter
//         ,      →  vírgula como separador rápido de lista
//     • Texto aceito: "Ampicilina 1.5g IV" → chip [Ampicilina 1.5g IV ✕]
//     • Toque num chip existente → abre diálogo de edição rápida da dosagem
//
//   IA (via SoapNotifier.applyAiDraft):
//     • FarmacoEntry(medicamento, dosagem) renderizado como chip
//     • Chip label = "Medicamento · Dosagem" (ou só medicamento se sem dosagem)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/evolucion_model.dart';
import 'internacion_theme.dart';

class FarmacosAccordion extends StatefulWidget {
  final List<FarmacoEntry> farmacos;
  final bool dark;
  final String lang;
  final ValueChanged<List<FarmacoEntry>> onChanged;

  const FarmacosAccordion({
    super.key,
    required this.farmacos,
    required this.dark,
    required this.lang,
    required this.onChanged,
  });

  @override
  State<FarmacosAccordion> createState() => _FarmacosAccordionState();
}

class _FarmacosAccordionState extends State<FarmacosAccordion>
    with TickerProviderStateMixin {
  bool _open = false;

  // Campo de entrada rápida (único)
  final _inputCtrl  = TextEditingController();
  final _inputFocus = FocusNode();

  // Animações de entrada dos chips (uma por índice)
  final Map<int, AnimationController> _chipAnims = {};

  bool get isEs => widget.lang == 'es';

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    for (final c in _chipAnims.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Cria AnimationController para novo chip ─────────────────────────────
  AnimationController _animFor(int idx) {
    if (!_chipAnims.containsKey(idx)) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..forward();
      _chipAnims[idx] = ctrl;
    }
    return _chipAnims[idx]!;
  }

  // ── Parse do texto digitado — produz FarmacoEntry ────────────────────────
  // Aceita: "Ampicilina 1.5g IV", "Furosemida 40mg EV"
  // O texto inteiro vira `medicamento`; se quiser separar "Nome — dosagem"
  // usa " — " ou " - " como separador.
  FarmacoEntry? _parseInput(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    // Separador explícito " — " ou " - "
    for (final sep in [' — ', ' - ', '—', '–']) {
      final parts = text.split(sep);
      if (parts.length >= 2) {
        final med = parts[0].trim();
        final dos = parts.sublist(1).join(' ').trim();
        if (med.isNotEmpty) return FarmacoEntry(medicamento: med, dosagem: dos);
      }
    }
    return FarmacoEntry(medicamento: text, dosagem: '');
  }

  // ── Dispara adição (Enter / + / ,) ───────────────────────────────────────
  void _commitInput() {
    final raw = _inputCtrl.text;
    // Divide por vírgula se houver múltiplos
    final segments = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    if (segments.isEmpty) return;

    final List<FarmacoEntry> added = [];
    for (final seg in segments) {
      final entry = _parseInput(seg);
      if (entry != null) added.add(entry);
    }
    if (added.isEmpty) return;

    final updated = [...widget.farmacos, ...added];
    widget.onChanged(updated);
    _inputCtrl.clear();
    _inputFocus.requestFocus();
  }

  // ── Remove chip por índice ────────────────────────────────────────────────
  void _remove(int idx) {
    final ctrl = _chipAnims.remove(idx);
    ctrl?.dispose();
    // Recalcula índices das animações restantes
    final newAnims = <int, AnimationController>{};
    _chipAnims.forEach((k, v) {
      newAnims[k < idx ? k : k - 1] = v;
    });
    _chipAnims
      ..clear()
      ..addAll(newAnims);

    final updated = [...widget.farmacos]..removeAt(idx);
    widget.onChanged(updated);
  }

  // ── Edição rápida de dosagem via dialog ──────────────────────────────────
  void _editChip(int idx) {
    final entry = widget.farmacos[idx];
    final medCtrl = TextEditingController(text: entry.medicamento);
    final dosCtrl = TextEditingController(text: entry.dosagem);
    final theme   = InternacionTheme(widget.dark);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.medication_rounded, size: 18, color: theme.accent),
            const SizedBox(width: 8),
            Text(
              isEs ? 'Editar fármaco' : 'Editar fármaco',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(
              ctrl: medCtrl,
              label: isEs ? 'Fármaco' : 'Fármaco',
              hint: 'Ampicilina',
              theme: theme,
            ),
            const SizedBox(height: 10),
            _dialogField(
              ctrl: dosCtrl,
              label: isEs ? 'Dosificación' : 'Dosagem',
              hint: isEs ? '1.5g IV 6/6h' : '1.5g IV 6/6h',
              theme: theme,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEs ? 'Cancelar' : 'Cancelar',
                style: TextStyle(color: theme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final med = medCtrl.text.trim();
              if (med.isEmpty) {
                Navigator.pop(context);
                return;
              }
              final updated = [...widget.farmacos];
              updated[idx] = FarmacoEntry(
                medicamento: med,
                dosagem:     dosCtrl.text.trim(),
              );
              widget.onChanged(updated);
              Navigator.pop(context);
            },
            child: Text(isEs ? 'Guardar' : 'Salvar',
                style: TextStyle(
                  color: theme.accent,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required InternacionTheme theme,
  }) {
    return TextField(
      controller: ctrl,
      autofocus: label.contains('arm'),
      style: TextStyle(fontSize: 13, color: theme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: theme.labelColor, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: widget.dark ? const Color(0xFF151820) : const Color(0xFFF9FAFB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: theme.border, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: theme.accent, width: 1.3),
        ),
      ),
    );
  }

  // ── Constrói label do chip ────────────────────────────────────────────────
  String _chipLabel(FarmacoEntry e) {
    if (e.dosagem.isEmpty) return e.medicamento;
    return '${e.medicamento} · ${e.dosagem}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(widget.dark);
    final count = widget.farmacos.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _open
              ? theme.accent.withValues(alpha: 0.45)
              : theme.border,
          width: _open ? 1.2 : 0.8,
        ),
        boxShadow: [theme.softShadow],
      ),
      child: Column(
        children: [

          // ── Header colapsável ─────────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Ícone
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: widget.dark ? 0.15 : 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.medication_rounded,
                        size: 18, color: theme.accent),
                  ),
                  const SizedBox(width: 10),

                  // Título + subtítulo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs
                              ? 'Fármacos que el paciente está tomando'
                              : 'Fármacos que o paciente está tomando',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          count == 0
                              ? (isEs
                                  ? 'Sin fármacos — agrega o deja a la IA'
                                  : 'Sem fármacos — adicione ou deixe a IA')
                              : '$count ${isEs
                                  ? 'fármaco${count > 1 ? 's' : ''} registrado${count > 1 ? 's' : ''}'
                                  : 'fármaco${count > 1 ? 's' : ''} registrado${count > 1 ? 's' : ''}'}',
                          style: TextStyle(fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Badge de contagem
                  if (count > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: widget.dark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: theme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Seta
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo colapsável ───────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: theme.divider, height: 1, thickness: 0.8),
                        const SizedBox(height: 14),

                        // ── WRAP DE CHIPS + campo de entrada inline ──────────
                        _ChipsWithInput(
                          farmacos:   widget.farmacos,
                          dark:       widget.dark,
                          lang:       widget.lang,
                          theme:      theme,
                          inputCtrl:  _inputCtrl,
                          inputFocus: _inputFocus,
                          animFor:    _animFor,
                          onRemove:   _remove,
                          onEdit:     _editChip,
                          onCommit:   _commitInput,
                          chipLabel:  _chipLabel,
                          vsync:      this,
                        ),

                        const SizedBox(height: 10),

                        // ── Instrução de uso ─────────────────────────────────
                        _hint(theme),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _hint(InternacionTheme theme) {
    return Row(
      children: [
        Icon(Icons.keyboard_rounded, size: 12, color: theme.labelColor),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            isEs
                ? 'Enter, + o coma  para agregar · Toca un chip para editarlo · ✕ para eliminar'
                : 'Enter, + ou vírgula para adicionar · Toque num chip para editar · ✕ para remover',
            style: TextStyle(
              fontSize: 10.5,
              color: theme.labelColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ChipsWithInput — Wrap de chips + TextField integrado no último espaço
// ═════════════════════════════════════════════════════════════════════════════
class _ChipsWithInput extends StatelessWidget {
  final List<FarmacoEntry> farmacos;
  final bool dark;
  final String lang;
  final InternacionTheme theme;
  final TextEditingController inputCtrl;
  final FocusNode inputFocus;
  final AnimationController Function(int) animFor;
  final void Function(int) onRemove;
  final void Function(int) onEdit;
  final VoidCallback onCommit;
  final String Function(FarmacoEntry) chipLabel;
  final TickerProvider vsync;

  const _ChipsWithInput({
    required this.farmacos,
    required this.dark,
    required this.lang,
    required this.theme,
    required this.inputCtrl,
    required this.inputFocus,
    required this.animFor,
    required this.onRemove,
    required this.onEdit,
    required this.onCommit,
    required this.chipLabel,
    required this.vsync,
  });

  bool get isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Chips existentes
        ...farmacos.asMap().entries.map(
          (e) => _AnimatedChip(
            key: ValueKey('fc_${e.key}_${e.value.medicamento}'),
            entry:   e.value,
            idx:     e.key,
            label:   chipLabel(e.value),
            dark:    dark,
            theme:   theme,
            animCtrl: animFor(e.key),
            onTap:   () => onEdit(e.key),
            onRemove: () => onRemove(e.key),
          ),
        ),

        // Campo de entrada inline (último elemento do Wrap)
        _InlineInput(
          ctrl:    inputCtrl,
          focus:   inputFocus,
          dark:    dark,
          theme:   theme,
          hint:    isEs
              ? 'Ampicilina 1.5g IV…'
              : 'Ampicilina 1.5g IV…',
          onCommit: onCommit,
        ),
      ],
    );
  }
}

// ── Chip animado com remoção ✕ ─────────────────────────────────────────────────
class _AnimatedChip extends StatelessWidget {
  final FarmacoEntry entry;
  final int idx;
  final String label;
  final bool dark;
  final InternacionTheme theme;
  final AnimationController animCtrl;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _AnimatedChip({
    super.key,
    required this.entry,
    required this.idx,
    required this.label,
    required this.dark,
    required this.theme,
    required this.animCtrl,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animCtrl, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.75, end: 1.0).animate(
          CurvedAnimation(parent: animCtrl, curve: Curves.easeOutBack),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
            decoration: BoxDecoration(
              color: dark
                  ? theme.accent.withValues(alpha: 0.13)
                  : theme.accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.accent.withValues(alpha: dark ? 0.35 : 0.28),
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone micro
                Icon(Icons.medication_outlined,
                    size: 12, color: theme.accent.withValues(alpha: 0.80)),
                const SizedBox(width: 5),

                // Label: Medicamento · Dosagem
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: dark
                          ? theme.accent.withValues(alpha: 0.95)
                          : theme.accent,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),

                // Botão ✕
                GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: dark ? 0.20 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 11,
                      color: theme.accent.withValues(alpha: 0.85),
                    ),
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

// ── Campo de entrada inline — integrado no Wrap ────────────────────────────────
class _InlineInput extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool dark;
  final InternacionTheme theme;
  final String hint;
  final VoidCallback onCommit;

  const _InlineInput({
    required this.ctrl,
    required this.focus,
    required this.dark,
    required this.theme,
    required this.hint,
    required this.onCommit,
  });

  @override
  State<_InlineInput> createState() => _InlineInputState();
}

class _InlineInputState extends State<_InlineInput> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 36,
      child: KeyboardListener(
        focusNode: FocusNode(),
        // Captura + e , via KeyboardListener para triggear commit imediato
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            final logical = event.logicalKey;
            if (logical == LogicalKeyboardKey.equal ||
                logical == LogicalKeyboardKey.numpadAdd ||
                logical == LogicalKeyboardKey.comma) {
              // Remove o caractere ativador e faz commit
              final text = widget.ctrl.text;
              final trimmed = text
                  .replaceAll(',', '')
                  .replaceAll('+', '')
                  .trim();
              widget.ctrl.text = trimmed;
              widget.onCommit();
            }
          }
        },
        child: TextField(
          controller: widget.ctrl,
          focusNode: widget.focus,
          textInputAction: TextInputAction.done,
          style: TextStyle(
            fontSize: 12.5,
            color: widget.theme.textPrimary,
          ),
          onSubmitted: (_) => widget.onCommit(),
          // Detecta vírgula ou + via onChanged como fallback para mobile
          onChanged: (val) {
            if (val.endsWith(',') || val.endsWith('+')) {
              final cleaned = val
                  .substring(0, val.length - 1)
                  .trim();
              widget.ctrl.value = TextEditingValue(
                text: cleaned,
                selection: TextSelection.collapsed(offset: cleaned.length),
              );
              if (cleaned.isNotEmpty) widget.onCommit();
            }
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 12,
              color: widget.theme.labelColor,
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            filled: true,
            fillColor: widget.dark
                ? const Color(0xFF1A1D24)
                : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                  color: widget.theme.border, width: 0.9),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                  color: widget.theme.accent, width: 1.3),
            ),
            suffixIcon: GestureDetector(
              onTap: widget.onCommit,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: widget.theme.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
