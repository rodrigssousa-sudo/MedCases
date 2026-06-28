// ── DoseCalculatorWidget — Calculadora de Dosagem Transparente ───────────────
// Task 4: Apple App Store Guideline 1.4.2 — Calculadoras de Dosagem
//
// Conformidade com diretrizes Apple:
//   ✅ Aviso "Exclusivo para Profissionais de Saúde" no topo
//   ✅ Linguagem passiva: "Dose de referência na literatura" (não "dose recomendada")
//   ✅ Fórmula matemática explícita: ex. 70 kg × 15 mg/kg = 1050 mg
//   ✅ Disclaimer de validação clínica obrigatório no rodapé
//   ✅ Não prescreve — apenas referencia a literatura médica
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kGreen     = Color(0xFF075f45);
const _kGreenMid  = Color(0xFF0E7C52);
const _kGreenLight= Color(0xFF13A06A);
const _kAmber     = Color(0xFFF59E0B);
const _kBorder    = Color(0xFFE2E6EA);
const _kTextDark  = Color(0xFF0D2B1E);
const _kTextMid   = Color(0xFF4A6B58);

// ══════════════════════════════════════════════════════════════════════════════
// DoseCalculatorWidget — Widget principal
//
// Uso:
//   DoseCalculatorWidget(
//     drugName: 'Amoxicilina',
//     dosePerKg: 25.0,         // mg/kg
//     unit: 'mg',
//     route: 'VO',
//     interval: 'a cada 8h',
//     minDose: 500,            // mg (opcional)
//     maxDose: 3000,           // mg (opcional)
//     reference: 'Harrison 21ª Ed. · SBIM 2024',
//     isEs: false,             // idioma
//   )
// ══════════════════════════════════════════════════════════════════════════════
class DoseCalculatorWidget extends StatefulWidget {
  final String drugName;
  final double dosePerKg;      // mg/kg (ou UI/kg, mcg/kg, etc.)
  final String unit;           // 'mg', 'mcg', 'UI', etc.
  final String route;          // 'IV', 'VO', 'IM', 'SC', etc.
  final String interval;       // 'a cada 8h', '1×/dia', etc.
  final double? minDose;       // dose mínima em unidade (sem /kg)
  final double? maxDose;       // dose máxima em unidade (sem /kg)
  final String? reference;     // fonte bibliográfica
  final bool isEs;             // idioma

  const DoseCalculatorWidget({
    super.key,
    required this.drugName,
    required this.dosePerKg,
    required this.unit,
    required this.route,
    required this.interval,
    this.minDose,
    this.maxDose,
    this.reference,
    this.isEs = false,
  });

  @override
  State<DoseCalculatorWidget> createState() => _DoseCalculatorWidgetState();
}

class _DoseCalculatorWidgetState extends State<DoseCalculatorWidget> {
  final _weightCtrl = TextEditingController();
  double? _calculatedDose;
  bool _capped = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (weight == null || weight <= 0) {
      setState(() { _calculatedDose = null; _capped = false; });
      return;
    }
    double dose = weight * widget.dosePerKg;
    bool cap = false;
    if (widget.maxDose != null && dose > widget.maxDose!) {
      dose = widget.maxDose!;
      cap = true;
    }
    if (widget.minDose != null && dose < widget.minDose!) {
      dose = widget.minDose!;
    }
    setState(() { _calculatedDose = dose; _capped = cap; });
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isEs   = widget.isEs;
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabeçalho — Aviso "Exclusivo para Profissionais" ─────────────
          _ProfessionalsHeader(isEs: isEs),

          // ── Corpo da calculadora ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nome do fármaco
                Text(
                  widget.drugName,
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: _kTextDark, letterSpacing: -0.3),
                ),
                const SizedBox(height: 2),
                Text(
                  isEs
                      ? '${widget.dosePerKg} ${widget.unit}/kg — ${widget.route} — ${widget.interval}'
                      : '${widget.dosePerKg} ${widget.unit}/kg — ${widget.route} — ${widget.interval}',
                  style: const TextStyle(
                    fontSize: 11, color: _kTextMid,
                    fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),

                // ── Campo de peso ────────────────────────────────────────
                _WeightField(
                  ctrl: _weightCtrl,
                  isEs: isEs,
                  onChanged: (_) => _calculate(),
                ),
                const SizedBox(height: 14),

                // ── Exibição da fórmula explícita (Task 4 — transparência) ──
                if (weight != null && weight > 0) ...[
                  _FormulaDisplay(
                    weight: weight,
                    dosePerKg: widget.dosePerKg,
                    unit: widget.unit,
                    result: _calculatedDose,
                    capped: _capped,
                    maxDose: widget.maxDose,
                    isEs: isEs,
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Resultado ────────────────────────────────────────────
                if (_calculatedDose != null)
                  _DoseResultCard(
                    dose: _calculatedDose!,
                    unit: widget.unit,
                    route: widget.route,
                    interval: widget.interval,
                    capped: _capped,
                    maxDose: widget.maxDose,
                    isEs: isEs,
                    fmt: _fmt,
                  ),

                const SizedBox(height: 14),
              ],
            ),
          ),

          // ── Rodapé — Referência bibliográfica + disclaimer ──────────────
          _ReferenceFooter(
            reference: widget.reference,
            isEs: isEs,
          ),
        ],
      ),
    );
  }
}

// ── Cabeçalho "Exclusivo para Profissionais" ──────────────────────────────────
class _ProfessionalsHeader extends StatelessWidget {
  final bool isEs;
  const _ProfessionalsHeader({required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D3324), Color(0xFF075f45)],
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.12),
          ),
          child: const Icon(Icons.medical_services_rounded,
              size: 14, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEs
                    ? 'EXCLUSIVO PARA PROFESIONALES DE SALUD'
                    : 'EXCLUSIVO PARA PROFISSIONAIS DE SAÚDE',
                style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 0.8),
              ),
              const SizedBox(height: 1),
              Text(
                isEs
                    ? 'Calculadora de referencia bibliográfica — no para automedicación'
                    : 'Calculadora de referência bibliográfica — não para automedicação',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.65),
                  fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Campo de peso ─────────────────────────────────────────────────────────────
class _WeightField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isEs;
  final ValueChanged<String> onChanged;

  const _WeightField({
    required this.ctrl,
    required this.isEs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700, color: _kTextDark),
      decoration: InputDecoration(
        labelText: isEs ? 'Peso del paciente (kg)' : 'Peso do paciente (kg)',
        labelStyle: const TextStyle(
          fontSize: 12, color: _kTextMid, fontWeight: FontWeight.w500),
        prefixIcon: const Icon(Icons.monitor_weight_outlined,
            size: 18, color: _kGreenMid),
        suffixText: 'kg',
        suffixStyle: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _kTextMid),
        filled: true,
        fillColor: const Color(0xFFF8FAF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: _kTextMid.withOpacity(0.18))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kGreen, width: 2)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Exibição da Fórmula (Task 4 — mostrar matemática explícita) ──────────────
class _FormulaDisplay extends StatelessWidget {
  final double weight;
  final double dosePerKg;
  final String unit;
  final double? result;
  final bool capped;
  final double? maxDose;
  final bool isEs;

  const _FormulaDisplay({
    required this.weight,
    required this.dosePerKg,
    required this.unit,
    required this.result,
    required this.capped,
    required this.maxDose,
    required this.isEs,
  });

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final rawDose = weight * dosePerKg;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGreen.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.functions_rounded,
                size: 14, color: _kGreenMid),
            const SizedBox(width: 6),
            Text(
              isEs ? 'Cálculo' : 'Cálculo',
              style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: _kGreenMid, letterSpacing: 0.5),
            ),
          ]),
          const SizedBox(height: 8),

          // ── Fórmula principal: peso × dose/kg = resultado ──────────────
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              _FormulaChip(label: '${_fmt(weight)} kg'),
              const _FormulaOp(op: '×'),
              _FormulaChip(label: '${_fmt(dosePerKg)} $unit/kg'),
              const _FormulaOp(op: '='),
              _FormulaChip(
                label: '${_fmt(rawDose)} $unit',
                highlight: !capped,
              ),
            ],
          ),

          // ── Se limitado pelo teto máximo ───────────────────────────────
          if (capped && maxDose != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.arrow_downward_rounded,
                  size: 13, color: _kAmber),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  isEs
                      ? 'Dosis máxima según literatura: ${_fmt(maxDose!)} $unit'
                      : 'Dose máxima conforme literatura: ${_fmt(maxDose!)} $unit',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kAmber),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _FormulaChip extends StatelessWidget {
  final String label;
  final bool highlight;
  const _FormulaChip({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: highlight
            ? _kGreenLight.withOpacity(0.12)
            : const Color(0xFFF0F4F0),
        border: Border.all(
          color: highlight
              ? _kGreenLight.withOpacity(0.45)
              : _kBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: highlight ? _kGreen : _kTextDark,
        ),
      ),
    );
  }
}

class _FormulaOp extends StatelessWidget {
  final String op;
  const _FormulaOp({required this.op});

  @override
  Widget build(BuildContext context) {
    return Text(op,
      style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w900, color: _kTextMid));
  }
}

// ── Card com resultado da dose (linguagem passiva — Task 4) ───────────────────
class _DoseResultCard extends StatelessWidget {
  final double dose;
  final String unit;
  final String route;
  final String interval;
  final bool capped;
  final double? maxDose;
  final bool isEs;
  final String Function(double) fmt;

  const _DoseResultCard({
    required this.dose,
    required this.unit,
    required this.route,
    required this.interval,
    required this.capped,
    required this.maxDose,
    required this.isEs,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    // ── Linguagem passiva: "Dose de referência na literatura" (não "recomendada")
    final refLabel = isEs
        ? 'Dosis de referencia en la literatura:'
        : 'Dose de referência na literatura:';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A2218), Color(0xFF075f45)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            refLabel,
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.60),
              letterSpacing: 0.3),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt(dose),
                style: const TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w900,
                  color: Colors.white, height: 1.0, letterSpacing: -1),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.70)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$route · $interval',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.60),
              fontWeight: FontWeight.w500),
          ),
          if (capped) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: _kAmber.withOpacity(0.18),
                border: Border.all(color: _kAmber.withOpacity(0.45)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.info_outline_rounded,
                    size: 12, color: _kAmber),
                const SizedBox(width: 5),
                Text(
                  isEs
                      ? 'Limitada al techo máximo de la literatura'
                      : 'Limitada ao teto máximo da literatura',
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kAmber),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Rodapé de Referência Bibliográfica (Task 6 — nível 2) ───────────────────
// Reutilizável como widget standalone em qualquer tela de protocolo/fármaco.
class ReferenceFooterWidget extends StatelessWidget {
  final String? reference;
  final bool isEs;
  final bool compact;

  const ReferenceFooterWidget({
    super.key,
    this.reference,
    this.isEs = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _ReferenceFooter(reference: reference, isEs: isEs, compact: compact);
  }
}

class _ReferenceFooter extends StatelessWidget {
  final String? reference;
  final bool isEs;
  final bool compact;

  const _ReferenceFooter({
    required this.reference,
    required this.isEs,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ref = reference ?? (isEs
        ? 'Harrison 21ª Ed. · Sanford Guide 2025 · PubMed'
        : 'Harrison 21ª Ed. · Sanford Guide 2025 · PubMed');
    final disclaimer = isEs
        ? 'Valide clínicamente con el paciente y los protocolos institucionales.'
        : 'Valide clinicamente com o paciente e protocolos institucionais.';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14, vertical: compact ? 8 : 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F0),
        border: const Border(
            top: BorderSide(color: _kBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.menu_book_rounded, size: 13, color: _kGreenMid),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${isEs ? "Fuente" : "Fonte"}: $ref',
                style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kTextMid),
              ),
            ),
          ]),
          if (!compact) ...[
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 12, color: _kAmber),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  disclaimer,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: _kTextMid,
                    fontWeight: FontWeight.w500,
                    height: 1.4),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
