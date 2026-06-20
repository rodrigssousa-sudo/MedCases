// ─────────────────────────────────────────────────────────────────────────────
// P — PLAN
// Campo estruturado para plano terapêutico e critérios de alta.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/evolucion_model.dart';
import '../internacion_theme.dart';

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
  }

  @override
  void dispose() {
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
        const SizedBox(height: 16),

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
  final List<String> hints;
  final TextEditingController ctrl;
  final bool dark;

  const _PlanHintRow({required this.hints, required this.ctrl, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: hints.map((h) => GestureDetector(
        onTap: () {
          final cur = ctrl.text;
          final prefix = cur.isEmpty ? '' : '\n';
          ctrl.text = '$cur${prefix}$h: ';
          ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: ctrl.text.length),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6),
              width: 0.8,
            ),
          ),
          child: Text('+ $h', style: TextStyle(
            fontSize: 11,
            color: dark ? Colors.white54 : Colors.black54,
            fontWeight: FontWeight.w500,
          )),
        ),
      )).toList(),
    );
  }
}

// ── Shared subwidgets ─────────────────────────────────────────────────────────
class _PlanLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final InternacionTheme theme;

  const _PlanLabel({required this.label, required this.icon, required this.theme});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: theme.labelColor),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8,
        color: theme.labelColor,
      )),
    ],
  );
}

class _PlanTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool dark;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _PlanTextField({
    required this.controller, required this.hint,
    required this.dark, required this.maxLines, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1D23) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6),
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 2,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 13,
          color: dark ? Colors.white : const Color(0xFF1A1D23),
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 12,
            color: dark ? Colors.white24 : Colors.black26,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
