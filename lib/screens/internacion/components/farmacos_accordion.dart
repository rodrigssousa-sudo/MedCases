// ─────────────────────────────────────────────────────────────────────────────
// FarmacosAccordion — Build 162
//
// Exibe e edita a lista de "Fármacos que el paciente está tomando".
// Suporta:
//   • Preenchimento automático pela IA (via SoapNotifier.applyAiDraft)
//   • Adição manual (campo nome + dosagem + botão +)
//   • Remoção manual (ícone ×)
//   • Edição inline (toque no card abre edição)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
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

class _FarmacosAccordionState extends State<FarmacosAccordion> {
  bool _open = false;

  // Controladores para o formulário de adição
  final _medCtrl  = TextEditingController();
  final _dosCtrl  = TextEditingController();
  final _medFocus = FocusNode();

  bool get isEs => widget.lang == 'es';

  @override
  void dispose() {
    _medCtrl.dispose();
    _dosCtrl.dispose();
    _medFocus.dispose();
    super.dispose();
  }

  void _add() {
    final med = _medCtrl.text.trim();
    if (med.isEmpty) return;
    final dos = _dosCtrl.text.trim();
    final updated = [...widget.farmacos, FarmacoEntry(medicamento: med, dosagem: dos)];
    widget.onChanged(updated);
    _medCtrl.clear();
    _dosCtrl.clear();
    _medFocus.requestFocus();
  }

  void _remove(int idx) {
    final updated = [...widget.farmacos]..removeAt(idx);
    widget.onChanged(updated);
  }

  void _editDosagem(int idx) {
    final entry = widget.farmacos[idx];
    final ctrl = TextEditingController(text: entry.dosagem);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: InternacionTheme(widget.dark).card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          entry.medicamento,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: InternacionTheme(widget.dark).textPrimary,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: InternacionTheme(widget.dark).textPrimary),
          decoration: InputDecoration(
            labelText: isEs ? 'Dosificación' : 'Dosagem',
            labelStyle: TextStyle(color: InternacionTheme(widget.dark).textSecondary),
            hintText: isEs ? 'ej: 500 mg VO 8/8h' : 'ex: 500 mg VO 8/8h',
            hintStyle: TextStyle(color: InternacionTheme(widget.dark).labelColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEs ? 'Cancelar' : 'Cancelar',
                style: TextStyle(color: InternacionTheme(widget.dark).textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final updated = [...widget.farmacos];
              updated[idx] = entry.copyWith(dosagem: ctrl.text.trim());
              widget.onChanged(updated);
              Navigator.pop(context);
            },
            child: Text(isEs ? 'Guardar' : 'Salvar',
                style: TextStyle(color: InternacionTheme(widget.dark).accent)),
          ),
        ],
      ),
    );
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
          // ── Header colapsável ───────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
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
                              ? (isEs ? 'Sin fármacos registrados' : 'Sem fármacos registrados')
                              : '$count ${isEs
                                  ? 'fármaco${count > 1 ? 's' : ''}'
                                  : 'fármaco${count > 1 ? 's' : ''}'}',
                          style: TextStyle(fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (count > 0)
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

          // ── Conteúdo colapsável ─────────────────────────────────────────
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
                        const SizedBox(height: 12),

                        // Lista de fármacos
                        if (widget.farmacos.isEmpty)
                          _emptyHint(theme)
                        else
                          ...widget.farmacos.asMap().entries.map(
                            (e) => _farmCard(e.key, e.value, theme),
                          ),

                        const SizedBox(height: 10),

                        // ── Formulário de adição ──────────────────────────
                        _addForm(theme),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(InternacionTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: theme.labelColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isEs
                  ? 'Sin fármacos. Usa el campo abajo para agregar o deja que la IA detecte automáticamente.'
                  : 'Sem fármacos. Use o campo abaixo para adicionar ou deixe a IA detectar automaticamente.',
              style: TextStyle(fontSize: 11.5, color: theme.labelColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _farmCard(int idx, FarmacoEntry entry, InternacionTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: widget.dark ? const Color(0xFF1A1D24) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border, width: 0.8),
        ),
        child: Row(
          children: [
            // Ícone
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.medication_outlined, size: 14, color: theme.accent),
            ),
            const SizedBox(width: 10),

            // Texto
            Expanded(
              child: GestureDetector(
                onTap: () => _editDosagem(idx),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.medicamento,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                    if (entry.dosagem.isNotEmpty)
                      Text(
                        entry.dosagem,
                        style: TextStyle(fontSize: 11.5, color: theme.textSecondary),
                      )
                    else
                      Text(
                        isEs ? 'Toca para agregar dosificación' : 'Toque para adicionar dosagem',
                        style: TextStyle(fontSize: 11, color: theme.labelColor),
                      ),
                  ],
                ),
              ),
            ),

            // Remover
            GestureDetector(
              onTap: () => _remove(idx),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 16, color: theme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addForm(InternacionTheme theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: widget.dark ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.25),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEs ? 'Agregar fármaco' : 'Adicionar fármaco',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.accent,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          _inputField(
            ctrl: _medCtrl,
            focus: _medFocus,
            hint: isEs ? 'Nombre del fármaco (ej: Amoxicilina)' : 'Nome do fármaco (ex: Amoxicilina)',
            theme: theme,
            onSubmit: (_) => _dosCtrl.selection =
                TextSelection.fromPosition(TextPosition(offset: _dosCtrl.text.length)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _inputField(
                  ctrl: _dosCtrl,
                  hint: isEs ? 'Dosificación (ej: 500 mg VO 8/8h)' : 'Dosagem (ex: 500 mg VO 8/8h)',
                  theme: theme,
                  onSubmit: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: theme.accentGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController ctrl,
    required String hint,
    required InternacionTheme theme,
    FocusNode? focus,
    ValueChanged<String>? onSubmit,
  }) {
    return TextField(
      controller: ctrl,
      focusNode: focus,
      onSubmitted: onSubmit,
      textInputAction: TextInputAction.next,
      style: TextStyle(fontSize: 13, color: theme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: theme.labelColor),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        filled: true,
        fillColor: widget.dark ? const Color(0xFF1A1D24) : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: theme.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: theme.accent, width: 1.2),
        ),
      ),
    );
  }
}
