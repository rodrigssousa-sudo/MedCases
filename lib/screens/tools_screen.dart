import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  // Biometrics
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _crCtrl = TextEditingController();
  bool _sexFem = false;

  // Hemodynamics
  final _sbpCtrl = TextEditingController();
  final _dbpCtrl = TextEditingController();

  // Electrolytes
  final _naCtrl = TextEditingController();
  final _clCtrl = TextEditingController();
  final _hco3Ctrl = TextEditingController();
  final _glucCtrl = TextEditingController();

  // Infusion
  final _infDrugCtrl = TextEditingController(text: 'Noradrenalina');
  final _infConcCtrl = TextEditingController(text: '4');
  final _infRateCtrl = TextEditingController(text: '10');
  final _infWeightCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [_wCtrl, _hCtrl, _ageCtrl, _crCtrl, _sbpCtrl, _dbpCtrl,
      _naCtrl, _clCtrl, _hco3Ctrl, _glucCtrl,
      _infDrugCtrl, _infConcCtrl, _infRateCtrl, _infWeightCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  String _fmt(double? v) {
    if (v == null || !v.isFinite) return '—';
    if (v.abs() >= 1000) return v.round().toString();
    if (v.abs() >= 100) return v.toStringAsFixed(0);
    return ((v * 10).round() / 10).toStringAsFixed(1).replaceAll('.', ',');
  }

  String? get _bmi {
    final w = _n(_wCtrl), h = _n(_hCtrl);
    if (w == null || h == null || h <= 0) return null;
    return _fmt(w / ((h / 100) * (h / 100)));
  }

  String? get _idealWeight {
    final h = _n(_hCtrl);
    if (h == null || h <= 0) return null;
    final base = _sexFem ? 45.5 : 50.0;
    final iw = base + 0.9 * (h - 152.4);
    return _fmt(iw < 0 ? 0 : iw);
  }

  String? get _clcr {
    final cr = _n(_crCtrl), a = _n(_ageCtrl), w = _n(_wCtrl);
    if (cr == null || a == null || w == null || cr <= 0) return null;
    double v = (140 - a) * w / (72 * cr);
    if (_sexFem) v *= 0.85;
    return _fmt(v);
  }

  String? get _map {
    final s = _n(_sbpCtrl), d = _n(_dbpCtrl);
    if (s == null || d == null) return null;
    return _fmt((s + 2 * d) / 3);
  }

  String? get _pp { // pulse pressure
    final s = _n(_sbpCtrl), d = _n(_dbpCtrl);
    if (s == null || d == null) return null;
    return _fmt(s - d);
  }

  String? get _anionGap {
    final na = _n(_naCtrl), cl = _n(_clCtrl), hco3 = _n(_hco3Ctrl);
    if (na == null || cl == null || hco3 == null) return null;
    return _fmt(na - (cl + hco3));
  }

  String? get _corrNa {
    final na = _n(_naCtrl), g = _n(_glucCtrl);
    if (na == null || g == null) return null;
    return _fmt(na + 1.6 * ((g - 100) / 100));
  }

  String? get _infusionRate {
    final conc = _n(_infConcCtrl); // mg/mL
    final rate = _n(_infRateCtrl); // mL/h
    final weight = _n(_infWeightCtrl);
    if (conc == null || rate == null) return null;
    final mgH = conc * rate;
    final mcgH = mgH * 1000;
    if (weight != null && weight > 0) {
      final mcgKgMin = mcgH / (weight * 60);
      return '${_fmt(mcgKgMin)} mcg/kg/min  •  ${_fmt(mcgH)} mcg/h';
    }
    return '${_fmt(mgH)} mg/h  •  ${_fmt(mcgH)} mcg/h';
  }

  String _bmiLabel(String? bmi) {
    final v = double.tryParse((bmi ?? '').replaceAll(',', '.'));
    if (v == null) return '';
    if (v < 18.5) return '↓ Abaixo do peso';
    if (v < 25) return '✓ Peso normal';
    if (v < 30) return '↑ Sobrepeso';
    if (v < 35) return '↑↑ Obesidade I';
    if (v < 40) return '↑↑↑ Obesidade II';
    return '↑↑↑ Obesidade III';
  }

  String _clcrLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d >= 90) return '✓ Normal (≥90)';
    if (d >= 60) return 'Leve redução (60–89)';
    if (d >= 30) return '⚠ Moderada (30–59)';
    if (d >= 15) return '⛔ Grave (15–29)';
    return '⛔ Falência renal (<15)';
  }

  String _mapLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d < 65) return '⛔ Hipoperfusão (<65)';
    if (d <= 105) return '✓ Adequada (65–105)';
    return '↑ Elevada (>105)';
  }

  String _agLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d < 8) return '↓ Baixo (<8)';
    if (d <= 12) return '✓ Normal (8–12)';
    return '⚠ Aumentado (>12) — acidose de AG elevado';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(children: [
        PremiumCard(child: SectionTitle(eyebrow: 'Clinical Math', title: p.t('tools'), subtitle: p.lang == 'es'
          ? 'Calculadoras clínicas: IMC, ClCr, PAM, electrolitos e infusión.'
          : 'Calculadoras clínicas: IMC, ClCr, PAM, eletrólitos e infusão.', light: true)),

        const SizedBox(height: 16),

        // ── BIOMETRICS ─────────────────────────────────────────────────────
        _SectionCard(
          title: p.lang == 'es' ? 'Biometría & Renal' : 'Biometria & Renal',
          icon: Icons.person_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: p.t('weight') + ' (kg)', ctrl: _wCtrl, onChanged: (_) => setState(() {}), hint: '78')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: p.lang == 'es' ? 'Talla (cm)' : 'Altura (cm)', ctrl: _hCtrl, onChanged: (_) => setState(() {}), hint: '171')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _LabeledInput(label: p.t('age') + (p.lang == 'es' ? ' (años)' : ' (anos)'), ctrl: _ageCtrl, onChanged: (_) => setState(() {}), hint: '68')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: p.t('creatinine') + ' (mg/dL)', ctrl: _crCtrl, onChanged: (_) => setState(() {}), hint: '1,0')),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _sexFem = !_sexFem),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: Colors.white),
                child: Row(children: [
                  Icon(_sexFem ? Icons.female : Icons.male, size: 18, color: _sexFem ? Colors.pink : const Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Text(_sexFem ? (p.lang == 'es' ? 'Femenino' : 'Feminino') : (p.lang == 'es' ? 'Masculino' : 'Masculino'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kDark)),
                  const Spacer(),
                  Text(p.lang == 'es' ? 'Toque para cambiar' : 'Toque para alternar',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ResultTile(label: 'IMC', value: _bmi, unit: 'kg/m²', note: _bmiLabel(_bmi))),
              const SizedBox(width: 8),
              Expanded(child: _ResultTile(label: p.lang == 'es' ? 'Peso Ideal' : 'Peso Ideal', value: _idealWeight, unit: 'kg')),
            ]),
            const SizedBox(height: 8),
            _ResultTile(
              label: p.lang == 'es' ? 'Clearance Creatinina (Cockcroft-Gault)' : 'Clearance de Creatinina (Cockcroft-Gault)',
              value: _clcr,
              unit: 'mL/min',
              note: _clcrLabel(_clcr),
              full: true,
            ),
            const SizedBox(height: 8),
            _InfoNote(text: p.lang == 'es'
              ? 'Fórmula de Cockcroft-Gault. Usar peso real o ideal según contexto clínico.'
              : 'Fórmula de Cockcroft-Gault. Usar peso real ou ideal conforme contexto clínico.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── HEMODYNAMICS ────────────────────────────────────────────────────
        _SectionCard(
          title: p.lang == 'es' ? 'Hemodinámica' : 'Hemodinâmica',
          icon: Icons.favorite_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: 'PAS (mmHg)', ctrl: _sbpCtrl, onChanged: (_) => setState(() {}), hint: '120')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: 'PAD (mmHg)', ctrl: _dbpCtrl, onChanged: (_) => setState(() {}), hint: '80')),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ResultTile(
                label: p.lang == 'es' ? 'PAM' : 'PAM',
                value: _map,
                unit: 'mmHg',
                note: _mapLabel(_map),
              )),
              const SizedBox(width: 8),
              Expanded(child: _ResultTile(
                label: p.lang == 'es' ? 'PP (Pulso)' : 'PP (Pulso)',
                value: _pp,
                unit: 'mmHg',
              )),
            ]),
            const SizedBox(height: 8),
            _InfoNote(text: p.lang == 'es'
              ? 'PAM = (PAS + 2×PAD) / 3. Meta: ≥65 mmHg em choque / sepse.'
              : 'PAM = (PAS + 2×PAD) / 3. Meta: ≥65 mmHg em choque / sepse.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── ELECTROLYTES ───────────────────────────────────────────────────
        _SectionCard(
          title: p.lang == 'es' ? 'Electrolitos & Gasometría' : 'Eletrólitos & Gasometria',
          icon: Icons.science_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: 'Na⁺ (mEq/L)', ctrl: _naCtrl, onChanged: (_) => setState(() {}), hint: '140')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: 'Cl⁻ (mEq/L)', ctrl: _clCtrl, onChanged: (_) => setState(() {}), hint: '104')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _LabeledInput(label: 'HCO₃⁻ (mEq/L)', ctrl: _hco3Ctrl, onChanged: (_) => setState(() {}), hint: '24')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: p.lang == 'es' ? 'Glucosa (mg/dL)' : 'Glicose (mg/dL)', ctrl: _glucCtrl, onChanged: (_) => setState(() {}), hint: '100')),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ResultTile(
                label: p.lang == 'es' ? 'Gap Aniónico' : 'Gap Aniônico',
                value: _anionGap,
                unit: 'mEq/L',
                note: _agLabel(_anionGap),
              )),
              const SizedBox(width: 8),
              Expanded(child: _ResultTile(
                label: 'Na⁺ Corrigido',
                value: _corrNa,
                unit: 'mEq/L',
              )),
            ]),
            const SizedBox(height: 8),
            _InfoNote(text: p.lang == 'es'
              ? 'Gap Aniónico = Na⁺ - (Cl⁻ + HCO₃⁻). Normal: 8–12 mEq/L. Na Corrigido: +1,6 por cada 100 mg/dL de glucosa acima de 100.'
              : 'Gap Aniônico = Na⁺ - (Cl⁻ + HCO₃⁻). Normal: 8–12 mEq/L. Na Corrigido: +1,6 por cada 100 mg/dL de glicose acima de 100.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── INFUSION CALCULATOR ─────────────────────────────────────────────
        _SectionCard(
          title: p.lang == 'es' ? 'Calculadora de Infusión' : 'Calculadora de Infusão',
          icon: Icons.water_drop_rounded,
          child: Column(children: [
            _LabeledInput(label: p.lang == 'es' ? 'Fármaco' : 'Fármaco', ctrl: _infDrugCtrl, onChanged: (_) => setState(() {}), hint: 'Noradrenalina'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _LabeledInput(
                label: p.lang == 'es' ? 'Concentración (mg/mL)' : 'Concentração (mg/mL)',
                ctrl: _infConcCtrl, onChanged: (_) => setState(() {}), hint: '4')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: 'Velocidade (mL/h)', ctrl: _infRateCtrl, onChanged: (_) => setState(() {}), hint: '10')),
            ]),
            const SizedBox(height: 10),
            _LabeledInput(
              label: p.t('weight') + ' (kg) — ' + (p.lang == 'es' ? 'opcional para mcg/kg/min' : 'opcional para mcg/kg/min'),
              ctrl: _infWeightCtrl, onChanged: (_) => setState(() {}), hint: '70'),
            const SizedBox(height: 14),
            if (_infusionRate != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kDark, Color(0xFF123326), kGreen],
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('RESULTADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text(_infDrugCtrl.text.isNotEmpty ? _infDrugCtrl.text : 'Fármaco',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0x99FFFFFF))),
                  const SizedBox(height: 2),
                  Text(_infusionRate!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                ]),
              )
            else
              _InfoNote(text: p.lang == 'es'
                ? 'Ingrese concentración y velocidad para calcular.'
                : 'Informe concentração e velocidade para calcular.'),
            const SizedBox(height: 8),
            _InfoNote(text: p.lang == 'es'
              ? 'Calcular solo con datos de la prescripción verificados. Revisar protocolo institucional antes de infundir.'
              : 'Calcular apenas com dados da prescrição verificados. Revisar protocolo institucional antes de infundir.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── RENAL DOSE GUIDE ───────────────────────────────────────────────
        _SectionCard(
          title: p.lang == 'es' ? 'Guía de Ajuste Renal' : 'Guia de Ajuste Renal',
          icon: Icons.warning_amber_rounded,
          child: Column(children: [
            _RenalGuideRow(clcr: 90, label: '≥ 90 mL/min', status: p.lang == 'es' ? 'Función normal — dosis estándar' : 'Função normal — dose padrão', ok: true),
            _RenalGuideRow(clcr: 60, label: '60–89 mL/min', status: p.lang == 'es' ? 'Reducción leve — vigilar' : 'Redução leve — monitorar'),
            _RenalGuideRow(clcr: 30, label: '30–59 mL/min', status: p.lang == 'es' ? 'Reducción moderada — ajuste frecuente' : 'Redução moderada — ajuste frequente', warn: true),
            _RenalGuideRow(clcr: 15, label: '15–29 mL/min', status: p.lang == 'es' ? 'Reducción grave — ajuste obligatorio' : 'Redução grave — ajuste obrigatório', warn: true),
            _RenalGuideRow(clcr: 0, label: '< 15 mL/min / Diálise', status: p.lang == 'es' ? 'Falla renal — dosis muy reducida o contraindicado' : 'Falência renal — dose muito reduzida ou contraindicado', danger: true),
            const SizedBox(height: 8),
            _InfoNote(text: p.lang == 'es'
              ? 'Los umbrales de ajuste varían por fármaco. Siempre verificar la ficha técnica de cada medicamento.'
              : 'Limiares de ajuste variam por fármaco. Sempre verificar a bula/protocolo de cada medicamento.'),
          ]),
        ),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF07110d)),
            child: Icon(icon, size: 16, color: const Color(0xFFFFE8A6)),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kDark, letterSpacing: -0.3)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  final String hint;
  const _LabeledInput({required this.label, required this.ctrl, required this.onChanged, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF888888))),
      const SizedBox(height: 5),
      MedInput(controller: ctrl, hintText: hint, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: onChanged),
    ]);
  }
}

class _ResultTile extends StatelessWidget {
  final String label;
  final String? value;
  final String? unit;
  final String? note;
  final bool full;
  const _ResultTile({required this.label, this.value, this.unit, this.note, this.full = false});

  @override
  Widget build(BuildContext context) {
    final hasVal = value != null;
    final noteColor = (note ?? '').contains('⛔') ? const Color(0xFFCC2222)
        : (note ?? '').contains('⚠') ? const Color(0xFFB45309)
        : const Color(0xFF065F46);
    return Container(
      width: full ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: hasVal ? const Color(0xFFECFDF5) : const Color(0xFFF8F8F8),
        border: Border.all(color: hasVal ? const Color(0xFFBBF7D0) : kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF666666))),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value ?? '—', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: hasVal ? kDark : const Color(0xFFCCCCCC), letterSpacing: -0.5)),
          if (unit != null && hasVal) ...[
            const SizedBox(width: 3),
            Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(unit!, style: const TextStyle(fontSize: 10, color: Color(0xFF888888)))),
          ],
        ]),
        if (note != null && note!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(note!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: noteColor, height: 1.3)),
        ],
      ]),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFFFFF8E7), border: Border.all(color: const Color(0xFFFFE0A0))),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7A5F00), height: 1.4)),
    );
  }
}

class _RenalGuideRow extends StatelessWidget {
  final int clcr;
  final String label;
  final String status;
  final bool ok;
  final bool warn;
  final bool danger;
  const _RenalGuideRow({required this.clcr, required this.label, required this.status, this.ok = false, this.warn = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final bg = danger ? const Color(0xFFFFF0F0) : warn ? const Color(0xFFFFF8E7) : ok ? const Color(0xFFECFDF5) : const Color(0xFFF8F8F8);
    final border = danger ? const Color(0xFFFFCCCC) : warn ? const Color(0xFFFFE0A0) : ok ? const Color(0xFFBBF7D0) : kBorder;
    final textColor = danger ? const Color(0xFFCC2222) : warn ? const Color(0xFFB45309) : ok ? const Color(0xFF065F46) : kDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: bg, border: Border.all(color: border)),
        child: Row(children: [
          SizedBox(width: 88, child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textColor))),
          const SizedBox(width: 8),
          Expanded(child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor, height: 1.3))),
        ]),
      ),
    );
  }
}
