// ─────────────────────────────────────────────────────────────────────────────
// P — PLAN
// Campo estruturado para plano terapêutico e critérios de alta.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';

import '../../../../design_system/foundation/med_typography.dart';
class SoapPlan extends StatefulWidget {
  final PlanData data;
  final ValueChanged<PlanData> onChanged;
  final bool dark;
  final String lang;

  const SoapPlan({
    super.key,
    required this.data,
    required this.onChanged,
    required this.dark,
    required this.lang,
  });

  @override
  State<SoapPlan> createState() => _SoapPlanState();
}

class _SoapPlanState extends State<SoapPlan> {
  late final TextEditingController _planCtrl;
  late final TextEditingController _altaCtrl;

  bool get isEs => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    _planCtrl = TextEditingController(text: widget.data.planTerapeutico)
      ..selection = TextSelection.collapsed(
          offset: widget.data.planTerapeutico.length);
    _altaCtrl = TextEditingController(text: widget.data.criteriosAlta)
      ..selection = TextSelection.collapsed(
          offset: widget.data.criteriosAlta.length);
    // Build 205 FIX: addListener captura mudanças programáticas (.text = valor)
    // que NÃO disparam onChanged do TextField (ex: injeção IA via applyAiDraft).
    _planCtrl.addListener(_onPlanChanged);
    _altaCtrl.addListener(_onAltaChanged);
  }

  void _onPlanChanged() {
    final v = _planCtrl.text;
    if (v != widget.data.planTerapeutico) {
      widget.onChanged(widget.data.copyWith(planTerapeutico: v));
    }
  }

  void _onAltaChanged() {
    final v = _altaCtrl.text;
    if (v != widget.data.criteriosAlta) {
      widget.onChanged(widget.data.copyWith(criteriosAlta: v));
    }
  }

  // Build 205 FIX: sincroniza _planCtrl e _altaCtrl quando widget.data muda
  // externamente. Caso de uso principal: injeção via IA (applyAiDraft) que
  // seta controller.text programaticamente — Flutter não dispara onChanged,
  // então o notifier ficaria desatualizado sem este override.
  @override
  void didUpdateWidget(SoapPlan oldWidget) {
    super.didUpdateWidget(oldWidget);
    final plan    = widget.data.planTerapeutico;
    final oldPlan = oldWidget.data.planTerapeutico;
    if (plan != oldPlan && plan != _planCtrl.text) {
      _planCtrl.text = plan;
      _planCtrl.selection = TextSelection.collapsed(offset: plan.length);
    }
    final alta    = widget.data.criteriosAlta;
    final oldAlta = oldWidget.data.criteriosAlta;
    if (alta != oldAlta && alta != _altaCtrl.text) {
      _altaCtrl.text = alta;
      _altaCtrl.selection = TextSelection.collapsed(offset: alta.length);
    }
  }

  @override
  void dispose() {
    _planCtrl.removeListener(_onPlanChanged);
    _altaCtrl.removeListener(_onAltaChanged);
    _planCtrl.dispose();
    _altaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final theme = InternacionTheme(dark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Plano terapêutico ─────────────────────────────────────────────────
        _PlanLabel(
          label: isEs ? 'PLAN TERAPÉUTICO' : 'PLANO TERAPÊUTICO',
          icon: Icons.assignment_rounded,
          theme: theme,
        ),
        const SizedBox(height: 6),
        _PlanHintRow(
          hints: isEs
              ? ['Continuar', 'Ajustar dosis', 'Suspender', 'Solicitar']
              : ['Continuar', 'Ajustar dose', 'Suspender', 'Solicitar'],
          ctrl: _planCtrl,
          dark: dark,
        ),
        const SizedBox(height: 6),
        _PlanTextField(
          controller: _planCtrl,
          hint: isEs
              ? '1. Continuar AAS + Atorvastatina\n2. Iniciar IECA 5mg/d\n3. Solicitar ecocardiograma…'
              : '1. Manter AAS + Atorvastatina\n2. Iniciar IECA 5mg/d\n3. Solicitar ecocardiograma…',
          dark: dark,
          maxLines: 6,
          onChanged: (v) => widget.onChanged(widget.data.copyWith(planTerapeutico: v)),
        ),
        const SizedBox(height: 8),

        // ── Critérios de alta ─────────────────────────────────────────────────
        _PlanLabel(
          label: isEs ? 'CRITERIOS DE ALTA' : 'CRITÉRIOS DE ALTA',
          icon: Icons.exit_to_app_rounded,
          theme: theme,
        ),
        const SizedBox(height: 6),
        _PlanTextField(
          controller: _altaCtrl,
          hint: isEs
              ? 'Afebril >48h, tolerando VO, PA controlada, sin O₂ suplementario…'
              : 'Afebril >48h, tolerando VO, PA controlada, sem O₂ suplementar…',
          dark: dark,
          maxLines: 3,
          onChanged: (v) => widget.onChanged(widget.data.copyWith(criteriosAlta: v)),
        ),
      ],
    );
  }
}

// ── Chips de atalho para o campo de plano ─────────────────────────────────────
class _PlanHintRow extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_PLAN_ACTIONS_V1
  final List<String> hints;
  final TextEditingController ctrl;
  final bool dark;

  const _PlanHintRow({required this.hints, required this.ctrl, required this.dark});

  @override
  Widget build(BuildContext context) {
    final border = dark ? const Color(0xFF3A4350) : const Color(0xFFD5DCE5);
    final muted = dark ? const Color(0xFFAEB7C4) : const Color(0xFF5F6B7A);
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: hints.map((h) => GestureDetector(
        onTap: () {
          final cur = ctrl.text;
          final prefix = cur.isEmpty ? '' : '\n';
          ctrl.text = '$cur${prefix}$h: ';
          ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border, width: 0.65),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 12.5, color: Color(0xFF0D6B57)),
              const SizedBox(width: 3),
              Text(h, style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w600, color: muted)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ── Shared subwidgets ─────────────────────────────────────────────────────────
class _PlanLabel extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_PLAN_HEADER_V1
  final String label;
  final IconData icon;
  final InternacionTheme theme;

  const _PlanLabel({required this.label, required this.icon, required this.theme});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark ? const Color(0xFF3A424D) : const Color(0xFFD9DEE6);
    return Row(
      children: [
        Icon(icon, size: 13.5, color: theme.labelColor),
        const SizedBox(width: 6),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.76, color: theme.labelColor)),
        const SizedBox(width: 9),
        Expanded(child: Container(height: 0.7, color: line.withOpacity(0.82))),
      ],
    );
  }
}

class _PlanTextField extends StatelessWidget {
  // MEDCASES_SOAP4_TRUE_INNER_PLAN_ORDER_LINE_V1
  final TextEditingController controller;
  final String hint;
  final bool dark;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _PlanTextField({
    required this.controller,
    required this.hint,
    required this.dark,
    required this.maxLines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = dark ? const Color(0xFF3A4350) : const Color(0xFFD5DCE5);
    final text = dark ? const Color(0xFFE8EDF3) : const Color(0xFF1F2937);
    final muted = dark ? const Color(0xFF9AA5B4) : const Color(0xFF667085);
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 1, 0, 2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border, width: 0.7))),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        onChanged: onChanged,
        style: TextStyle(fontSize: 13.4, height: 1.38, fontWeight: FontWeight.w500, color: text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12.4, height: 1.35, fontWeight: FontWeight.w400, color: muted.withOpacity(0.64)),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 1, vertical: 7),
        ),
      ),
    );
  }
}
