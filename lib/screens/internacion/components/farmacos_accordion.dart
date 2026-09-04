// ─────────────────────────────────────────────────────────────────────────────
// FarmacosAccordion — Build 164 — Motor DDI Integrado
//
// Build 162.1: Chips Dinâmicos (FadeTransition + ScaleTransition)
// Build 164:   Motor DDI reativo
//   • DrugInteractionService.check() disparado a cada mudança na lista
//   • Banner dinâmico de alerta no topo dos chips (cor por gravidade)
//   • Chips envolvidos em colisão recebem ícone ⚠️ como prefixo
//   • Header do acordeão exibe badge vermelho com o número de alertas
//
// UX:
//   • Fundo soft red #FEE2E2 / border #FCA5A5 / text dark red #991B1B (contraindicada)
//   • Fundo amber #FEF3C7 para alta · #FEF9C3 para moderada · #DBEAFE para leve
//   • Chips flagados: ícone Icons.warning_amber_rounded antes do nome
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/evolucion_model.dart';
import 'internacion_theme.dart';
import '../services/drug_interaction_service.dart';

import '../../../design_system/foundation/med_typography.dart';
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
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();

  // Animações de entrada dos chips (uma por índice)
  final Map<int, AnimationController> _chipAnims = {};

  // ── DDI ─────────────────────────────────────────────────────────────────
  List<DdiAlert> _alerts = [];
  Set<String> _flagged = {};

  bool get isEs => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    // Inicia o serviço DDI (idempotente)
    DrugInteractionService.instance.init().then((_) {
      if (mounted) _runDdiCheck();
    });
  }

  @override
  void didUpdateWidget(FarmacosAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reanalisa sempre que a lista de fármacos muda
    if (oldWidget.farmacos != widget.farmacos) {
      _runDdiCheck();
    }
  }

  void _runDdiCheck() {
    if (!DrugInteractionService.instance.isLoaded) return;
    final labels = widget.farmacos.map((f) => f.medicamento).toList();
    final alerts = DrugInteractionService.instance.check(labels);
    final flagged = DrugInteractionService.instance.flaggedDrugs(alerts);
    if (mounted) {
      setState(() {
        _alerts = alerts;
        _flagged = flagged;
      });
    }
  }

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
  FarmacoEntry? _parseInput(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
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
    final segments =
        raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
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

  // ── Edição rápida via dialog ──────────────────────────────────────────────
  void _editChip(int idx) {
    final entry = widget.farmacos[idx];
    final medCtrl = TextEditingController(text: entry.medicamento);
    final dosCtrl = TextEditingController(text: entry.dosagem);
    final theme = InternacionTheme(widget.dark);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            Icon(Icons.medication_rounded, size: 18, color: theme.pharmaAccent),
            const SizedBox(width: 8),
            Text(
              isEs ? 'Editar fármaco' : 'Editar fármaco',
              style: TextStyle(
                fontSize: MedTypography.clinicalBodySize,
                fontWeight: FontWeight.w700,
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
                theme: theme),
            const SizedBox(height: 10),
            _dialogField(
                ctrl: dosCtrl,
                label: isEs ? 'Dosificación' : 'Dosagem',
                hint: '1.5g IV 6/6h',
                theme: theme),
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
              updated[idx] =
                  FarmacoEntry(medicamento: med, dosagem: dosCtrl.text.trim());
              widget.onChanged(updated);
              Navigator.pop(context);
            },
            child: Text(isEs ? 'Guardar' : 'Salvar',
                style: TextStyle(
                    color: theme.pharmaAccent, fontWeight: FontWeight.w700)),
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
      style: TextStyle(fontSize: MedTypography.sectionLabelSize, color: theme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary, fontSize: MedTypography.sectionLabelSize),
        hintText: hint,
        hintStyle: TextStyle(color: theme.labelColor, fontSize: MedTypography.sectionLabelSize),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor:
            widget.dark ? const Color(0xFF1F232A) : const Color(0xFFFFFFFF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.border, width: 0.7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.pharmaAccent, width: 1.0),
        ),
      ),
    );
  }

  // ── Label do chip ─────────────────────────────────────────────────────────
  String _chipLabel(FarmacoEntry e) {
    if (e.dosagem.isEmpty) return e.medicamento;
    return '${e.medicamento} · ${e.dosagem}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = InternacionTheme(widget.dark);
    final count = widget.farmacos.length;
    final hasAlert = _alerts.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12.5, 12, 12.5),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      hasAlert
                          ? Icons.warning_amber_rounded
                          : Icons.medication_rounded,
                      size: 18,
                      color: hasAlert ? const Color(0xFF991B1B) : theme.pharmaAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEs ? 'Fármacos' : 'Fármacos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: hasAlert
                              ? const Color(0xFF991B1B)
                              : theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasAlert
                            ? (isEs
                                ? '${_alerts.length} interacción${_alerts.length > 1 ? 'es' : ''} detectada${_alerts.length > 1 ? 's' : ''}'
                                : '${_alerts.length} interação${_alerts.length > 1 ? 'ões' : ''} detectada${_alerts.length > 1 ? 's' : ''}')
                            : (count == 0
                                ? (isEs ? 'Medicación activa' : 'Medicação ativa')
                                : '$count fármaco${count > 1 ? 's' : ''} activo${count > 1 ? 's' : ''}'),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasAlert
                              ? const Color(0xFFB91C1C)
                              : theme.textSecondary,
                          fontWeight:
                              hasAlert ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasAlert) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFCA5A5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 11,
                          color: Color(0xFF991B1B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${_alerts.length}',
                          style: const TextStyle(
                            fontSize: MedTypography.microTextSize,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ] else if (count > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          theme.pharmaAccent.withOpacity(widget.dark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: MedTypography.sectionLabelSize,
                        fontWeight: FontWeight.w700,
                        color: theme.pharmaAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                AnimatedRotation(
                  turns: _open ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(
                        color: theme.divider,
                        height: 1,
                        thickness: 0.7,
                      ),
                      const SizedBox(height: 8),
                      if (_alerts.isNotEmpty) ...[
                        _DdiBanner(
                          alerts: _alerts,
                          lang: widget.lang,
                          dark: widget.dark,
                        ),
                        const SizedBox(height: 8),
                      ],
                      // MEDICAL_REFINEMENT_V1_ACTIVE_MEDICATION
                        Row(
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 13,
                              color: theme.pharmaAccent.withOpacity(0.90),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isEs ? 'MEDICACIÓN ACTIVA' : 'MEDICAÇÃO ATIVA',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.80,
                                color: theme.pharmaAccent.withOpacity(0.90),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        _ChipsWithInput(
                        farmacos: widget.farmacos,
                        flagged: _flagged,
                        dark: widget.dark,
                        lang: widget.lang,
                        theme: theme,
                        inputCtrl: _inputCtrl,
                        inputFocus: _inputFocus,
                        animFor: _animFor,
                        onRemove: _remove,
                        onEdit: _editChip,
                        onCommit: _commitInput,
                        chipLabel: _chipLabel,
                        vsync: this,
                      ),
                      const SizedBox(height: 6),
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
                ? 'Enter para agregar · toca para editar · × para eliminar'
                : 'Enter para adicionar · toque para editar · × para remover',
            style:
                TextStyle(fontSize: MedTypography.auxiliarySize, color: theme.labelColor, height: 1.3),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _DdiBanner — Build 164 — Banner de alerta de interação
// ═════════════════════════════════════════════════════════════════════════════
class _DdiBanner extends StatelessWidget {
  final List<DdiAlert> alerts;
  final String lang;
  final bool dark;

  const _DdiBanner({
    required this.alerts,
    required this.lang,
    required this.dark,
  });

  bool get isEs => lang == 'es';

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    // Mostra até 3 alertas; o mais grave primeiro (já vem ordenado)
    final shown = alerts.take(3).toList();

    return Column(
      children: shown.map((alert) {
        final colors = alert.uiColors; // [bg, border, text]
        final bg = _hexColor(colors[0]);
        final border = _hexColor(colors[1]);
        final text = _hexColor(colors[2]);
        final descr = isEs ? alert.descricaoEs : alert.descricaoPt;
        final conduta = isEs ? alert.condutaEs : alert.condutaPt;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: 0.7),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Row(
                  children: [
                    Text(
                      alert.emoji,
                      style: const TextStyle(fontSize: MedTypography.internalTitleSize),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isEs ? alert.titleEs() : alert.titlePt(),
                        style: TextStyle(
                          fontSize: MedTypography.sectionLabelSize,
                          fontWeight: FontWeight.w800,
                          color: text,
                          height: 1.2,
                        ),
                      ),
                    ),
                    // Score badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: border.withOpacity(0.40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Score ${alert.scoreClinico}/5',
                        style: TextStyle(
                          fontSize: MedTypography.microTextSize,
                          fontWeight: FontWeight.w700,
                          color: text,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Par de drogas
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: MedTypography.sectionLabelSize, color: text, height: 1.3),
                    children: [
                      TextSpan(
                        text: alert.drugA,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' + '),
                      TextSpan(
                        text: alert.drugB,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),

                if (descr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    descr,
                    style: TextStyle(
                      fontSize: MedTypography.microTextSize,
                      color: text.withOpacity(0.87),
                      height: 1.4,
                    ),
                  ),
                ],

                if (conduta.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: border.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${isEs ? 'Conducta' : 'Conduta'}: $conduta',
                      style: TextStyle(
                        fontSize: MedTypography.microTextSize,
                        color: text,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ChipsWithInput — Wrap de chips + TextField integrado no último espaço
// ═════════════════════════════════════════════════════════════════════════════
class _ChipsWithInput extends StatelessWidget {
  final List<FarmacoEntry> farmacos;
  final Set<String> flagged; // Build 164: chips com alerta DDI
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
    required this.flagged,
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
                entry: e.value,
                idx: e.key,
                label: chipLabel(e.value),
                isFlagged: flagged.contains(e.value.medicamento), // Build 164
                dark: dark,
                theme: theme,
                animCtrl: animFor(e.key),
                onTap: () => onEdit(e.key),
                onRemove: () => onRemove(e.key),
              ),
            ),

        // Campo de entrada inline
        _InlineInput(
          ctrl: inputCtrl,
          focus: inputFocus,
          dark: dark,
          theme: theme,
          hint: isEs ? 'Ampicilina 1.5g IV…' : 'Ampicilina 1.5g IV…',
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
  final bool isFlagged;
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
    required this.isFlagged,
    required this.dark,
    required this.theme,
    required this.animCtrl,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final medicine = entry.medicamento.trim().isNotEmpty
        ? entry.medicamento.trim()
        : label;
    final dose = entry.dosagem.trim();

    final bg = isFlagged
        ? (dark
            ? const Color(0xFF4A2025).withOpacity(0.72)
            : const Color(0xFFFFF1F2))
        : (dark
            ? const Color(0xFF182820).withOpacity(0.82)
            : const Color(0xFFF1F8F5));

    final border = isFlagged
        ? (dark
            ? const Color(0xFFFB7185).withOpacity(0.46)
            : const Color(0xFFFDA4AF))
        : theme.pharmaAccent.withOpacity(dark ? 0.42 : 0.30);

    final primary = isFlagged
        ? (dark ? const Color(0xFFFFB4BE) : const Color(0xFF9F1239))
        : (dark ? const Color(0xFFE7FFF5) : const Color(0xFF14532D));

    final secondary = isFlagged
        ? primary.withOpacity(0.84)
        : (dark
            ? theme.pharmaAccent.withOpacity(0.92)
            : const Color(0xFF047857));

    return FadeTransition(
      opacity: CurvedAnimation(parent: animCtrl, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.82, end: 1.0).animate(
          CurvedAnimation(parent: animCtrl, curve: Curves.easeOutBack),
        ),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.fromLTRB(8, 5, 5, 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: 0.65),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFlagged
                      ? Icons.warning_amber_rounded
                      : Icons.medication_outlined,
                  size: 13,
                  color: secondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    medicine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                      color: primary,
                    ),
                  ),
                ),
                if (dose.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: secondary.withOpacity(dark ? 0.12 : 0.09),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      dose,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: secondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: secondary.withOpacity(0.82),
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
      width: 260,
      height: 38,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            final k = event.logicalKey;
            if (k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter ||
                k == LogicalKeyboardKey.add) {
              widget.onCommit();
            }
          }
        },
        child: TextField(
          controller: widget.ctrl,
          focusNode: widget.focus,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: widget.theme.textPrimary,
          ),
          onChanged: (v) {
            if (v.endsWith('+') || v.endsWith(',')) {
              widget.onCommit();
            }
          },
          onSubmitted: (_) => widget.onCommit(),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.add_rounded,
              size: 16,
              color: widget.theme.pharmaAccent.withOpacity(0.88),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: widget.theme.labelColor,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 8,
            ),
            filled: false,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: widget.theme.border.withOpacity(0.84),
                width: 0.7,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: widget.theme.pharmaAccent,
                width: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
