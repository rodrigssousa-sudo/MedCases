import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

// ──────────────────────────────────────────────────────────────────
// COLOR CONSTANTS
// ──────────────────────────────────────────────────────────────────
const kToolDark   = Color(0xFF07110d);
const kToolGreen  = Color(0xFF16A34A);
const kToolBorder = Color(0xFFE5E7EB);
const kToolGold   = Color(0xFFFFE8A6);

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    return Column(children: [
      // ── Header ──────────────────────────────────────────────────
      Container(
        color: kToolDark,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1)),
                child: const Icon(Icons.calculate_rounded, color: kToolGold, size: 20),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEs ? 'Herramientas Clínicas' : 'Ferramentas Clínicas',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                Text(isEs ? 'Calculadoras con base científica' : 'Calculadoras com base científica',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: kToolGold,
            indicatorWeight: 3,
            labelColor: kToolGold,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: isEs ? 'BIOMETRÍA' : 'BIOMETRIA'),
              Tab(text: isEs ? 'SCORES' : 'SCORES'),
              Tab(text: isEs ? 'CARDIO' : 'CARDIO'),
              Tab(text: isEs ? 'ELECTROLITOS' : 'ELETRÓLITOS'),
              Tab(text: isEs ? 'INFUSIÓN' : 'INFUSÃO'),
              Tab(text: isEs ? 'REFERENCIA' : 'REFERÊNCIA'),
              Tab(text: isEs ? 'PRESCRIPCIONES' : 'PRESCRIÇÕES'),
            ],
          ),
        ]),
      ),

      // ── Content ─────────────────────────────────────────────────
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _BiometricsTab(),
            _ScoresTab(),
            _CardioTab(),
            _ElectrolytesTab(),
            _InfusionTab(),
            _ReferenceTab(),
            _PrescriptionsTab(),
          ],
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 1 — BIOMETRIA
// ══════════════════════════════════════════════════════════════════
class _BiometricsTab extends StatefulWidget {
  @override
  State<_BiometricsTab> createState() => _BiometricsTabState();
}

class _BiometricsTabState extends State<_BiometricsTab> {
  final _wCtrl   = TextEditingController();
  final _hCtrl   = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _crCtrl  = TextEditingController();
  bool _sexFem = false;

  @override
  void dispose() {
    _wCtrl.dispose(); _hCtrl.dispose(); _ageCtrl.dispose(); _crCtrl.dispose();
    super.dispose();
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
  String _fmt(double? v) {
    if (v == null || !v.isFinite) return '—';
    if (v.abs() >= 1000) return v.round().toString();
    if (v.abs() >= 100)  return v.toStringAsFixed(0);
    return ((v * 10).round() / 10).toStringAsFixed(1).replaceAll('.', ',');
  }

  double? get _bmiVal {
    final w = _n(_wCtrl), h = _n(_hCtrl);
    if (w == null || h == null || h <= 0) return null;
    return w / ((h / 100) * (h / 100));
  }

  String? get _idealWeight {
    final h = _n(_hCtrl);
    if (h == null || h <= 0) return null;
    final iw = (_sexFem ? 45.5 : 50.0) + 0.9 * (h - 152.4);
    return _fmt(iw < 0 ? 0 : iw);
  }

  String? get _adjustedWeight {
    final w = _n(_wCtrl), h = _n(_hCtrl);
    if (w == null || h == null || h <= 0) return null;
    final iw = (_sexFem ? 45.5 : 50.0) + 0.9 * (h - 152.4);
    final adj = iw + 0.4 * (w - iw);
    return _fmt(adj < 0 ? 0 : adj);
  }

  String? get _clcr {
    final cr = _n(_crCtrl), a = _n(_ageCtrl), w = _n(_wCtrl);
    if (cr == null || a == null || w == null || cr <= 0) return null;
    double v = (140 - a) * w / (72 * cr);
    if (_sexFem) v *= 0.85;
    return _fmt(v);
  }

  String? get _ckdEpi {
    final cr = _n(_crCtrl), a = _n(_ageCtrl);
    if (cr == null || a == null || cr <= 0) return null;
    final kappa = _sexFem ? 0.7 : 0.9;
    final alpha = _sexFem ? -0.241 : -0.302;
    final ratio  = cr / kappa;
    double gfr = 142 * _pow(ratio < 1 ? ratio : 1, alpha)
                     * _pow(ratio > 1 ? ratio : 1, -1.200)
                     * _pow(0.9938, a);
    if (_sexFem) gfr *= 1.012;
    return _fmt(gfr);
  }

  String _bmiLabel(double? v) {
    if (v == null) return '';
    if (v < 16) return '⛔ Desnutrição grave (<16)';
    if (v < 18.5) return '↓ Abaixo do peso';
    if (v < 25)   return '✓ Peso normal';
    if (v < 30)   return '↑ Sobrepeso';
    if (v < 35)   return '↑↑ Obesidade I';
    if (v < 40)   return '↑↑↑ Obesidade II';
    return '⛔ Obesidade III (Mórbida)';
  }

  String _clcrLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d >= 90) return '✓ Normal (≥90)';
    if (d >= 60) return 'Leve (60–89)';
    if (d >= 30) return '⚠ Moderada (30–59)';
    if (d >= 15) return '⛔ Grave (15–29)';
    return '⛔ Falência (<15)';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        _SectionCard(
          title: isEs ? 'Antropometría' : 'Antropometria',
          icon: Icons.person_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: isEs ? 'Peso (kg)' : 'Peso (kg)', ctrl: _wCtrl, onChanged: (_) => setState(() {}), hint: '78')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: isEs ? 'Talla (cm)' : 'Altura (cm)', ctrl: _hCtrl, onChanged: (_) => setState(() {}), hint: '171')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _LabeledInput(label: isEs ? 'Edad (años)' : 'Idade (anos)', ctrl: _ageCtrl, onChanged: (_) => setState(() {}), hint: '60')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: isEs ? 'Creatinina (mg/dL)' : 'Creatinina (mg/dL)', ctrl: _crCtrl, onChanged: (_) => setState(() {}), hint: '1,0')),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _sexFem = !_sexFem),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(border: Border.all(color: kToolBorder)),
                child: Row(children: [
                  Icon(_sexFem ? Icons.female : Icons.male, size: 18, color: _sexFem ? Colors.pink : const Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Text(_sexFem ? (isEs ? 'Femenino' : 'Feminino') : (isEs ? 'Masculino' : 'Masculino'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kToolDark)),
                  const Spacer(),
                  Text(isEs ? 'Toque para cambiar' : 'Toque para alternar',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ResultTile(label: 'IMC', value: _fmt(_bmiVal), unit: 'kg/m²', note: _bmiLabel(_bmiVal))),
              const SizedBox(width: 8),
              Expanded(child: _ResultTile(label: isEs ? 'Peso Ideal' : 'Peso Ideal', value: _idealWeight, unit: 'kg')),
            ]),
            const SizedBox(height: 8),
            _ResultTile(label: isEs ? 'Peso Ajustado (obesos)' : 'Peso Ajustado (obesos)', value: _adjustedWeight, unit: 'kg', full: true,
              note: isEs ? 'Usar en obesos (IMC>30) para dosis de fármacos' : 'Usar em obesos (IMC>30) para dose de fármacos'),
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: isEs ? 'Función Renal' : 'Função Renal',
          icon: Icons.water_rounded,
          child: Column(children: [
            _ResultTile(
              label: isEs ? 'ClCr — Cockcroft-Gault' : 'ClCr — Cockcroft-Gault',
              value: _clcr, unit: 'mL/min', note: _clcrLabel(_clcr), full: true),
            const SizedBox(height: 8),
            _ResultTile(
              label: isEs ? 'TFG — CKD-EPI 2021' : 'TFG — CKD-EPI 2021',
              value: _ckdEpi, unit: 'mL/min/1,73m²', note: _clcrLabel(_ckdEpi), full: true),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'Cockcroft-Gault: usar para ajuste de fármacos. CKD-EPI: estadificación de ERC (KDIGO).'
              : 'Cockcroft-Gault: usar para ajuste de fármacos. CKD-EPI: estadiamento de DRC (KDIGO).'),
            const SizedBox(height: 8),
            _RenalGuideRow(label: '≥ 90', status: isEs ? 'G1 — Función normal' : 'G1 — Função normal', ok: true),
            _RenalGuideRow(label: '60–89', status: isEs ? 'G2 — Leve. Vigilar' : 'G2 — Leve. Monitorar'),
            _RenalGuideRow(label: '30–59', status: isEs ? 'G3 — Moderada. Ajuste frecuente' : 'G3 — Moderada. Ajuste frequente', warn: true),
            _RenalGuideRow(label: '15–29', status: isEs ? 'G4 — Grave. Ajuste obligatorio' : 'G4 — Grave. Ajuste obrigatório', warn: true),
            _RenalGuideRow(label: '<15', status: isEs ? 'G5 — Falla. Dosis muy reducida' : 'G5 — Falência. Dose muito reduzida', danger: true),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 2 — SCORES CLÍNICOS
// ══════════════════════════════════════════════════════════════════
class _ScoresTab extends StatefulWidget {
  @override
  State<_ScoresTab> createState() => _ScoresTabState();
}

class _ScoresTabState extends State<_ScoresTab> {
  // ── Glasgow ──────────────────────────────────────────
  int _glasEye    = 4;
  int _glasVerbal = 5;
  int _glasMotor  = 6;

  // ── SOFA ────────────────────────────────────────────
  int _sofaResp  = 0; // PaO2/FiO2
  int _sofaCoag  = 0; // Platelets
  int _sofaLiver = 0; // Bilirubin
  int _sofaCardio= 0; // MAP / vasopressors
  int _sofaNeuro = 0; // GCS
  int _sofaRenal = 0; // Creatinine / urine

  // ── CHA2DS2-VASc ────────────────────────────────────
  bool _cha_ic       = false;
  bool _cha_has      = false;
  bool _cha_age75    = false;
  bool _cha_dm       = false;
  bool _cha_stroke   = false;
  bool _cha_vasc     = false;
  bool _cha_age65_74 = false;
  bool _cha_female   = false;

  // ── Wells TVP ───────────────────────────────────────
  bool _wt_active_cancer     = false;
  bool _wt_paralysis         = false;
  bool _wt_recent_immob      = false;
  bool _wt_localized_tender  = false;
  bool _wt_entire_leg_swol   = false;
  bool _wt_calf_swol3cm      = false;
  bool _wt_pitting_edema     = false;
  bool _wt_collateral_veins  = false;
  bool _wt_previous_dvt      = false;
  bool _wt_alt_dx_likely     = false;

  // ── Wells TEP ───────────────────────────────────────
  bool _wp_dvt_signs  = false;
  bool _wp_no_alt_dx  = false;
  bool _wp_hr100      = false;
  bool _wp_immob      = false;
  bool _wp_prev_dvt   = false;
  bool _wp_hemoptysis = false;
  bool _wp_malignancy = false;

  // ── CURB-65 ─────────────────────────────────────────
  bool _curb_confusion = false;
  bool _curb_ureia     = false;
  bool _curb_rr        = false;
  bool _curb_bp        = false;
  bool _curb_age65     = false;

  // ── NEWS2 ────────────────────────────────────────────
  int _news_rr     = 0; // 0–3
  int _news_spo2   = 0; // 0–3
  // _news_spo2b reservado para escala B DPOC
  bool _news_supo2 = false; // O2 suplementar
  int _news_sbp    = 0; // 0–3
  int _news_hr     = 0; // 0–3
  int _news_neuro  = 0; // 0–3 (AVPU)
  int _news_temp   = 0; // 0–3

  // ── Child-Pugh ──────────────────────────────────────
  int _cp_bili    = 1; // 1–3
  int _cp_alb     = 1; // 1–3
  int _cp_pt      = 1; // 1–3 (INR)
  int _cp_ascite  = 1; // 1–3
  int _cp_encef   = 1; // 1–3

  // ── PSI/PORT ────────────────────────────────────────
  // Demographics
  bool _psi_nursing  = false; // nursing home
  bool _psi_neoplasm = false;
  bool _psi_liver    = false;
  bool _psi_chf      = false;
  bool _psi_cva      = false;
  bool _psi_renal    = false;
  // Exam
  bool _psi_alt_ms   = false;
  bool _psi_rr30     = false;
  bool _psi_sbp90    = false;
  bool _psi_temp     = false; // <35 or ≥40
  bool _psi_hr125    = false;
  // Labs/x-ray
  bool _psi_ph735    = false;
  bool _psi_bun30    = false;
  bool _psi_na130    = false;
  bool _psi_gluc250  = false;
  bool _psi_hct30    = false;
  bool _psi_po2_60   = false;
  bool _psi_eff      = false; // pleural effusion
  final _psiAgeCtrl  = TextEditingController();

  @override
  void dispose() {
    _psiAgeCtrl.dispose();
    super.dispose();
  }

  int get _glasGCS => _glasEye + _glasVerbal + _glasMotor;
  int get _sofaTotal => _sofaResp + _sofaCoag + _sofaLiver + _sofaCardio + _sofaNeuro + _sofaRenal;

  int get _chaScore {
    int s = 0;
    if (_cha_ic)       s += 1;
    if (_cha_has)      s += 1;
    if (_cha_age75)    s += 2;
    if (_cha_dm)       s += 1;
    if (_cha_stroke)   s += 2;
    if (_cha_vasc)     s += 1;
    if (_cha_age65_74) s += 1;
    if (_cha_female)   s += 1;
    return s;
  }

  double get _wtScore {
    double s = 0;
    if (_wt_active_cancer)    s += 1;
    if (_wt_paralysis)        s += 1;
    if (_wt_recent_immob)     s += 1;
    if (_wt_localized_tender) s += 1;
    if (_wt_entire_leg_swol)  s += 1;
    if (_wt_calf_swol3cm)     s += 1;
    if (_wt_pitting_edema)    s += 1;
    if (_wt_collateral_veins) s += 1;
    if (_wt_previous_dvt)     s += 1;
    if (_wt_alt_dx_likely)    s -= 2;
    return s;
  }

  double get _wpScore {
    double s = 0;
    if (_wp_dvt_signs)  s += 3;
    if (_wp_no_alt_dx)  s += 3;
    if (_wp_hr100)      s += 1.5;
    if (_wp_immob)      s += 1.5;
    if (_wp_prev_dvt)   s += 1.5;
    if (_wp_hemoptysis) s += 1;
    if (_wp_malignancy) s += 1;
    return s;
  }

  String _glasLabel(int g) {
    if (g >= 14) return '✓ Leve (14–15)';
    if (g >= 9)  return '⚠ Moderado (9–13)';
    return '⛔ Grave (≤8) — considerar IOT';
  }

  String _sofaLabel(int s) {
    if (s == 0) return '✓ Mortalidade ~0%';
    if (s <= 6) return '⚠ Mortalidade ~2–4%';
    if (s <= 9) return '⚠ Mortalidade ~20%';
    if (s <= 12) return '⛔ Mortalidade ~40%';
    return '⛔ Mortalidade >80%';
  }

  // ── CURB-65 getters ─────────────────────────────────
  int get _curbScore {
    int s = 0;
    if (_curb_confusion) s++;
    if (_curb_ureia)     s++;
    if (_curb_rr)        s++;
    if (_curb_bp)        s++;
    if (_curb_age65)     s++;
    return s;
  }
  String _curbLabel(int s) {
    if (s <= 1) return '✓ Leve — tratamento ambulatorial';
    if (s == 2) return '⚠ Moderado — considerar internação curta';
    return '⛔ Grave (≥3) — internação + avaliar UTI';
  }
  String _curbMort(int s) {
    const m = ['~0,6%', '~2,7%', '~6,8%', '~14%', '~27,8%', '≥27,8%'];
    return m[s.clamp(0, m.length - 1)];
  }

  // ── NEWS2 getters ────────────────────────────────────
  int get _newsTotal => _news_rr + _news_spo2 + (_news_supo2 ? 2 : 0) + _news_sbp + _news_hr + _news_neuro + _news_temp;
  String _newsLabel(int s) {
    if (s == 0) return '✓ Risco mínimo — reavaliação de rotina';
    if (s <= 4) return '⚠ Risco baixo — reavaliar em 4–6h';
    if (s <= 6) return '⛔ Risco médio — médico urgente + monitorização contínua';
    return '⛔⛔ Risco alto (≥7) — UTI ou semi-intensivo imediato';
  }

  // ── Child-Pugh getters ──────────────────────────────
  int get _cpTotal => _cp_bili + _cp_alb + _cp_pt + _cp_ascite + _cp_encef;
  String _cpClass(int s) {
    if (s <= 6) return 'Classe A (5–6 pts) — sobrevida 1 ano ~100%';
    if (s <= 9) return 'Classe B (7–9 pts) — sobrevida 1 ano ~80%';
    return 'Classe C (10–15 pts) — sobrevida 1 ano ~45%';
  }

  // ── PSI/PORT getters ─────────────────────────────────
  int get _psiScore {
    final age = int.tryParse(_psiAgeCtrl.text) ?? 0;
    int s = age;
    if (_psi_nursing)  s += 10;
    if (_psi_neoplasm) s += 30;
    if (_psi_liver)    s += 20;
    if (_psi_chf)      s += 10;
    if (_psi_cva)      s += 10;
    if (_psi_renal)    s += 10;
    if (_psi_alt_ms)   s += 20;
    if (_psi_rr30)     s += 20;
    if (_psi_sbp90)    s += 20;
    if (_psi_temp)     s += 15;
    if (_psi_hr125)    s += 10;
    if (_psi_ph735)    s += 30;
    if (_psi_bun30)    s += 20;
    if (_psi_na130)    s += 20;
    if (_psi_gluc250)  s += 10;
    if (_psi_hct30)    s += 10;
    if (_psi_po2_60)   s += 10;
    if (_psi_eff)      s += 10;
    return s;
  }
  String _psiClass(int s) {
    if (s <= 50)  return 'Classe I–II (≤50) — ambulatorial (mort. <1%)';
    if (s <= 70)  return 'Classe III (51–70) — ambulatorial curto (mort. ~2%)';
    if (s <= 90)  return 'Classe IV (71–90) — internação (mort. ~8%)';
    if (s <= 130) return 'Classe V (91–130) — internação (mort. ~30%)';
    return 'Classe V (>130) — UTI imperativa (mort. >30%)';
  }

  String _chaRisk(int s) {
    if (s == 0) return '✓ Baixo risco — sem anticoagulação';
    if (s == 1) return '⚠ Risco intermediário — individualizar';
    return '⛔ Alto risco — anticoagulação indicada';
  }

  String _chaStroke(int s) {
    const rates = [0.0, 1.3, 2.2, 3.2, 4.0, 6.7, 9.8, 9.6, 6.7, 15.2];
    if (s < 0) return '—';
    final idx = s.clamp(0, rates.length - 1);
    return '${rates[idx]}%/ano';
  }

  String _wtLabel(double s) {
    if (s <= 0) return '✓ Baixa probabilidade';
    if (s <= 2) return '⚠ Probabilidade moderada';
    return '⛔ Alta probabilidade de TVP';
  }

  String _wpLabel(double s) {
    if (s < 2)  return '✓ TEP improvável (<2)';
    if (s <= 6) return '⚠ TEP moderado (2–6)';
    return '⛔ TEP provável (>6)';
  }

  Widget _scoreRow(String label, bool value, VoidCallback onTap, {double points = 1}) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: value ? const Color(0xFFECFDF5) : const Color(0xFFF8F8F8),
        border: Border.all(color: value ? const Color(0xFFBBF7D0) : kToolBorder),
      ),
      child: Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: value ? kToolGreen : Colors.white,
            border: Border.all(color: value ? kToolGreen : const Color(0xFFCCCCCC), width: 2)),
          child: value ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: value ? kToolDark : const Color(0xFF555555)))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
            color: value ? kToolGreen.withValues(alpha: 0.15) : const Color(0xFFEEEEEE)),
          child: Text(points == points.roundToDouble() ? '+${points.toInt()}' : '${points > 0 ? "+" : ""}$points',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
              color: value ? kToolGreen : const Color(0xFF888888))),
        ),
      ]),
    ),
  );

  Widget _glasRow(String label, int value, int max, VoidCallback onDec, VoidCallback onInc) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kToolDark))),
      IconButton(icon: const Icon(Icons.remove_circle_outline), iconSize: 22, color: kToolGreen, onPressed: value > 1 ? onDec : null),
      Container(
        width: 36, alignment: Alignment.center,
        child: Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kToolDark)),
      ),
      IconButton(icon: const Icon(Icons.add_circle_outline), iconSize: 22, color: kToolGreen, onPressed: value < max ? onInc : null),
      SizedBox(width: 30, child: Text('/$max', style: const TextStyle(fontSize: 11, color: Color(0xFF888888)))),
    ]),
  );

  Widget _sofaDropRow(String label, int value, List<String> options, ValueChanged<int?> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kToolDark))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: kToolBorder)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            isDense: true,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kToolDark),
            onChanged: onChanged,
            items: List.generate(options.length, (i) => DropdownMenuItem(value: i, child: Text(options[i]))),
          ),
        ),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [

        // ── Glasgow ─────────────────────────────────────────────────
        _SectionCard(
          title: isEs ? 'Escala de Glasgow (GCS)' : 'Escala de Glasgow (GCS)',
          icon: Icons.psychology_rounded,
          badge: '$_glasGCS',
          badgeColor: _glasGCS >= 14 ? kToolGreen : _glasGCS >= 9 ? const Color(0xFFB45309) : const Color(0xFFCC2222),
          child: Column(children: [
            _glasRow(isEs ? 'Abertura Ocular (O)' : 'Abertura Ocular (O)', _glasEye, 4,
              () => setState(() => _glasEye--), () => setState(() => _glasEye++)),
            _glasRow(isEs ? 'Respuesta Verbal (V)' : 'Resposta Verbal (V)', _glasVerbal, 5,
              () => setState(() => _glasVerbal--), () => setState(() => _glasVerbal++)),
            _glasRow(isEs ? 'Respuesta Motora (M)' : 'Resposta Motora (M)', _glasMotor, 6,
              () => setState(() => _glasMotor--), () => setState(() => _glasMotor++)),
            const Divider(),
            _ResultTile(label: 'GCS Total', value: '$_glasGCS', unit: '/15', note: _glasLabel(_glasGCS), full: true),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'O: 1=Ninguna 2=Dolor 3=Voz 4=Espontánea | V: 1=Ninguna 2=Sonidos 3=Palabras 4=Confuso 5=Orientado | M: 1=Ninguna 2=Extensión 3=Flexión 4=Retirada 5=Localiza 6=Obedece'
              : 'O: 1=Nenhuma 2=Dor 3=Voz 4=Espontânea | V: 1=Nenhuma 2=Sons 3=Palavras 4=Confuso 5=Orientado | M: 1=Nenhuma 2=Extensão 3=Flexão 4=Retirada 5=Localiza 6=Obedece'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── SOFA ─────────────────────────────────────────────────────
        _SectionCard(
          title: 'Score SOFA (Sepse)',
          icon: Icons.monitor_heart_rounded,
          badge: '$_sofaTotal',
          badgeColor: _sofaTotal <= 6 ? kToolGreen : _sofaTotal <= 9 ? const Color(0xFFB45309) : const Color(0xFFCC2222),
          child: Column(children: [
            _sofaDropRow(
              isEs ? 'Respiratorio (PaO2/FiO2)' : 'Respiratório (PaO2/FiO2)',
              _sofaResp,
              isEs ? ['≥400 (0)', '<400 (1)', '<300 (2)', '<200+VPP (3)', '<100+VPP (4)']
                   : ['≥400 (0)', '<400 (1)', '<300 (2)', '<200+VPP (3)', '<100+VPP (4)'],
              (v) => setState(() => _sofaResp = v ?? 0)),
            _sofaDropRow(
              isEs ? 'Coagulación (Plaquetas)' : 'Coagulação (Plaquetas)',
              _sofaCoag,
              ['≥150k (0)', '<150k (1)', '<100k (2)', '<50k (3)', '<20k (4)'],
              (v) => setState(() => _sofaCoag = v ?? 0)),
            _sofaDropRow(
              isEs ? 'Hepático (Bilirrubina)' : 'Hepático (Bilirrubina)',
              _sofaLiver,
              ['<1,2 (0)', '1,2–1,9 (1)', '2,0–5,9 (2)', '6,0–11,9 (3)', '≥12,0 (4)'],
              (v) => setState(() => _sofaLiver = v ?? 0)),
            _sofaDropRow(
              isEs ? 'Cardiovascular (PAM/Vaso)' : 'Cardiovascular (PAM/Vaso)',
              _sofaCardio,
              isEs ? ['PAM≥70(0)', 'PAM<70(1)', 'Dopa≤5(2)', 'Dopa>5/NA≤0,1(3)', 'Dopa>15/NA>0,1(4)']
                   : ['PAM≥70(0)', 'PAM<70(1)', 'Dopa≤5(2)', 'Dopa>5/NA≤0,1(3)', 'Dopa>15/NA>0,1(4)'],
              (v) => setState(() => _sofaCardio = v ?? 0)),
            _sofaDropRow(
              isEs ? 'Neurológico (GCS)' : 'Neurológico (GCS)',
              _sofaNeuro,
              ['15 (0)', '13–14 (1)', '10–12 (2)', '6–9 (3)', '<6 (4)'],
              (v) => setState(() => _sofaNeuro = v ?? 0)),
            _sofaDropRow(
              isEs ? 'Renal (Creatinina/Diuresis)' : 'Renal (Creatinina/Diurese)',
              _sofaRenal,
              ['<1,2 (0)', '1,2–1,9 (1)', '2,0–3,4 (2)', '3,5–4,9/<500mL(3)', '>5/>200mL(4)'],
              (v) => setState(() => _sofaRenal = v ?? 0)),
            const Divider(),
            _ResultTile(label: 'SOFA Total', value: '$_sofaTotal', unit: '/24', note: _sofaLabel(_sofaTotal), full: true),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'SOFA ≥2: disfunción orgánica = SEPSIS. Aumento ≥2 puntos = mayor mortalidad.'
              : 'SOFA ≥2: disfunção orgânica = SEPSE. Aumento ≥2 pontos = maior mortalidade.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── CHA2DS2-VASc ──────────────────────────────────────────────
        _SectionCard(
          title: 'CHA₂DS₂-VASc (FA)',
          icon: Icons.favorite_rounded,
          badge: '$_chaScore',
          badgeColor: _chaScore == 0 ? kToolGreen : _chaScore == 1 ? const Color(0xFFB45309) : const Color(0xFFCC2222),
          child: Column(children: [
            _scoreRow(isEs ? 'IC / FE reduzida (C)' : 'IC / FE reduzida (C)', _cha_ic,   () => setState(() => _cha_ic = !_cha_ic)),
            _scoreRow(isEs ? 'Hipertensión (H)' : 'Hipertensão (H)', _cha_has,  () => setState(() => _cha_has = !_cha_has)),
            _scoreRow(isEs ? 'Edad ≥75 años (A₂)' : 'Idade ≥75 anos (A₂)', _cha_age75, () => setState(() => _cha_age75 = !_cha_age75), points: 2),
            _scoreRow(isEs ? 'Diabetes mellitus (D)' : 'Diabetes mellitus (D)', _cha_dm, () => setState(() => _cha_dm = !_cha_dm)),
            _scoreRow(isEs ? 'AVC/AIT/Tromboembolismo (S₂)' : 'AVC/AIT/Tromboembolismo (S₂)', _cha_stroke, () => setState(() => _cha_stroke = !_cha_stroke), points: 2),
            _scoreRow(isEs ? 'Enfermedad Vascular (V)' : 'Doença Vascular (V)', _cha_vasc, () => setState(() => _cha_vasc = !_cha_vasc)),
            _scoreRow(isEs ? 'Edad 65–74 años (A)' : 'Idade 65–74 anos (A)', _cha_age65_74, () => setState(() => _cha_age65_74 = !_cha_age65_74)),
            _scoreRow(isEs ? 'Sexo femenino (Sc)' : 'Sexo feminino (Sc)', _cha_female, () => setState(() => _cha_female = !_cha_female)),
            const Divider(),
            Row(children: [
              Expanded(child: _ResultTile(label: isEs ? 'Puntuación' : 'Pontuação', value: '$_chaScore', unit: '/9')),
              const SizedBox(width: 8),
              Expanded(child: _ResultTile(label: isEs ? 'AVC/año' : 'AVC/ano', value: _chaStroke(_chaScore), unit: '')),
            ]),
            const SizedBox(height: 8),
            _InfoNote(text: _chaRisk(_chaScore)),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Wells TVP ─────────────────────────────────────────────────
        _SectionCard(
          title: isEs ? 'Wells — TVP (Trombosis Venosa)' : 'Wells — TVP (Trombose Venosa)',
          icon: Icons.airline_seat_flat_angled_rounded,
          badge: _wtScore.toStringAsFixed(0),
          badgeColor: _wtScore <= 0 ? kToolGreen : _wtScore <= 2 ? const Color(0xFFB45309) : const Color(0xFFCC2222),
          child: Column(children: [
            _scoreRow(isEs ? 'Cáncer activo (trat. <6m)' : 'Câncer ativo (trat. <6m)', _wt_active_cancer, () => setState(() => _wt_active_cancer = !_wt_active_cancer)),
            _scoreRow(isEs ? 'Parálisis/paresia MMII' : 'Paralisia/paresia MMII', _wt_paralysis, () => setState(() => _wt_paralysis = !_wt_paralysis)),
            _scoreRow(isEs ? 'Inmovilización >3 días / cirugía <12 semanas' : 'Imobilização >3 dias / cirurgia <12 semanas', _wt_recent_immob, () => setState(() => _wt_recent_immob = !_wt_recent_immob)),
            _scoreRow(isEs ? 'Dolor a la palpación venosa' : 'Dor à palpação venosa', _wt_localized_tender, () => setState(() => _wt_localized_tender = !_wt_localized_tender)),
            _scoreRow(isEs ? 'Edema de toda la pierna' : 'Edema de toda a perna', _wt_entire_leg_swol, () => setState(() => _wt_entire_leg_swol = !_wt_entire_leg_swol)),
            _scoreRow(isEs ? 'Pantorrilla ≥3 cm mayor que contralateral' : 'Panturrilha ≥3 cm maior que contralateral', _wt_calf_swol3cm, () => setState(() => _wt_calf_swol3cm = !_wt_calf_swol3cm)),
            _scoreRow(isEs ? 'Edema con fóvea en pierna sintomática' : 'Edema com cacifo na perna sintomática', _wt_pitting_edema, () => setState(() => _wt_pitting_edema = !_wt_pitting_edema)),
            _scoreRow(isEs ? 'Venas superficiales colaterales' : 'Veias superficiais colaterais', _wt_collateral_veins, () => setState(() => _wt_collateral_veins = !_wt_collateral_veins)),
            _scoreRow(isEs ? 'TVP previa documentada' : 'TVP prévia documentada', _wt_previous_dvt, () => setState(() => _wt_previous_dvt = !_wt_previous_dvt)),
            _scoreRow(isEs ? 'Diagnóstico alternativo más probable (−2)' : 'Diagnóstico alternativo mais provável (−2)', _wt_alt_dx_likely, () => setState(() => _wt_alt_dx_likely = !_wt_alt_dx_likely), points: -2),
            const Divider(),
            _ResultTile(label: isEs ? 'Score Wells TVP' : 'Score Wells TVP',
              value: _wtScore.toStringAsFixed(0), unit: 'pts', note: _wtLabel(_wtScore), full: true),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? '≤0: Baja → D-dímero. 1–2: Moderada → D-dímero o eco-Doppler. ≥3: Alta → Eco-Doppler direto.'
              : '≤0: Baixa → D-dímero. 1–2: Moderada → D-dímero ou eco-Doppler. ≥3: Alta → Eco-Doppler direto.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Wells TEP ─────────────────────────────────────────────────
        _SectionCard(
          title: isEs ? 'Wells — TEP (Tromboembolismo Pulmonar)' : 'Wells — TEP (Tromboembolismo Pulmonar)',
          icon: Icons.air_rounded,
          badge: _wpScore.toStringAsFixed(1),
          badgeColor: _wpScore < 2 ? kToolGreen : _wpScore <= 6 ? const Color(0xFFB45309) : const Color(0xFFCC2222),
          child: Column(children: [
            _scoreRow(isEs ? 'Signos/síntomas de TVP (+3)' : 'Sinais/sintomas de TVP (+3)', _wp_dvt_signs, () => setState(() => _wp_dvt_signs = !_wp_dvt_signs), points: 3),
            _scoreRow(isEs ? 'TEP el diagnóstico más probable (+3)' : 'TEP o diagnóstico mais provável (+3)', _wp_no_alt_dx, () => setState(() => _wp_no_alt_dx = !_wp_no_alt_dx), points: 3),
            _scoreRow(isEs ? 'FC > 100 bpm (+1,5)' : 'FC > 100 bpm (+1,5)', _wp_hr100, () => setState(() => _wp_hr100 = !_wp_hr100), points: 1.5),
            _scoreRow(isEs ? 'Inmovilización ≥3 días / cirugía <4 semanas (+1,5)' : 'Imobilização ≥3 dias / cirurgia <4 semanas (+1,5)', _wp_immob, () => setState(() => _wp_immob = !_wp_immob), points: 1.5),
            _scoreRow(isEs ? 'TVP/TEP previo (+1,5)' : 'TVP/TEP prévio (+1,5)', _wp_prev_dvt, () => setState(() => _wp_prev_dvt = !_wp_prev_dvt), points: 1.5),
            _scoreRow(isEs ? 'Hemoptisis (+1)' : 'Hemoptise (+1)', _wp_hemoptysis, () => setState(() => _wp_hemoptysis = !_wp_hemoptysis)),
            _scoreRow(isEs ? 'Malignidad activa (+1)' : 'Malignidade ativa (+1)', _wp_malignancy, () => setState(() => _wp_malignancy = !_wp_malignancy)),
            const Divider(),
            _ResultTile(label: isEs ? 'Score Wells TEP' : 'Score Wells TEP',
              value: _wpScore.toStringAsFixed(1), unit: 'pts', note: _wpLabel(_wpScore), full: true),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? '<2: TEP improbable → D-dímero. 2–6: Moderado. >6: TEP probable → AngioTC de tórax direto.'
              : '<2: TEP improvável → D-dímero. 2–6: Moderado. >6: TEP provável → AngioTC de tórax direto.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── CURB-65 ───────────────────────────────────────────────────
        _SectionCard(
          title: 'CURB-65 (PAC)',
          icon: Icons.masks_rounded,
          badge: '$_curbScore',
          badgeColor: _curbScore <= 1 ? kToolGreen : _curbScore == 2 ? const Color(0xFFB45309) : const Color(0xFFCC2222),
          child: Column(children: [
            _scoreRow(isEs ? 'Confusión (nueva)' : 'Confusão (nova)', _curb_confusion, () => setState(() => _curb_confusion = !_curb_confusion)),
            _scoreRow(isEs ? 'Urea >50 mg/dL' : 'Ureia >50 mg/dL', _curb_ureia, () => setState(() => _curb_ureia = !_curb_ureia)),
            _scoreRow(isEs ? 'FR ≥30/min' : 'FR ≥30 irpm', _curb_rr, () => setState(() => _curb_rr = !_curb_rr)),
            _scoreRow(isEs ? 'PAS <90 o PAD ≤60 mmHg' : 'PAS <90 ou PAD ≤60 mmHg', _curb_bp, () => setState(() => _curb_bp = !_curb_bp)),
            _scoreRow(isEs ? 'Edad ≥65 años' : 'Idade ≥65 anos', _curb_age65, () => setState(() => _curb_age65 = !_curb_age65)),
            const Divider(),
            Row(children: [
              Expanded(child: _ResultTile(label: 'CURB-65', value: '$_curbScore', unit: '/5')),
              const SizedBox(width: 8),
              Expanded(child: _ResultTile(label: isEs ? 'Mortalidad' : 'Mortalidade', value: _curbMort(_curbScore), unit: '')),
            ]),
            const SizedBox(height: 8),
            _InfoNote(text: _curbLabel(_curbScore)),
          ]),
        ),

        const SizedBox(height: 12),

        // ── NEWS2 ─────────────────────────────────────────────────────
        _SectionCard(
          title: 'NEWS2 (Alerta Precoce)',
          icon: Icons.monitor_heart_outlined,
          badge: '$_newsTotal',
          badgeColor: _newsTotal == 0 ? kToolGreen : _newsTotal <= 4 ? const Color(0xFFB45309) : const Color(0xFFCC2222),
          child: Column(children: [
            // FR
            _sofaDropRow(
              isEs ? 'FR (irpm)' : 'FR (irpm)', _news_rr,
              ['≤8 (+3)', '9–11 (+1)', '12–20 (0)', '21–24 (+2)', '≥25 (+3)'],
              (v) => setState(() => _news_rr = v ?? 0)),
            // SpO2 escala A
            _sofaDropRow(
              isEs ? 'SpO₂ % (Esc. A)' : 'SpO₂ % (Esc. A)', _news_spo2,
              ['≤91 (+3)', '92–93 (+2)', '94–95 (+1)', '≥96 (0)'],
              (v) => setState(() => _news_spo2 = v ?? 0)),
            // O2 suplementar
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: Text(isEs ? 'O₂ suplementario (+2)' : 'O₂ suplementar (+2)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kToolDark))),
                Switch(
                  value: _news_supo2,
                  activeThumbColor: kToolGreen,
                  onChanged: (v) => setState(() => _news_supo2 = v),
                ),
              ]),
            ),
            // PA sistólica
            _sofaDropRow(
              isEs ? 'PAS (mmHg)' : 'PAS (mmHg)', _news_sbp,
              ['≤90 (+3)', '91–100 (+2)', '101–110 (+1)', '111–219 (0)', '≥220 (+3)'],
              (v) => setState(() => _news_sbp = v ?? 0)),
            // FC
            _sofaDropRow(
              isEs ? 'FC (bpm)' : 'FC (bpm)', _news_hr,
              ['≤40 (+3)', '41–50 (+1)', '51–90 (0)', '91–110 (+1)', '111–130 (+2)', '≥131 (+3)'],
              (v) => setState(() => _news_hr = v ?? 0)),
            // Nível consciência AVPU
            _sofaDropRow(
              isEs ? 'Conciencia (AVPU)' : 'Consciência (AVPU)', _news_neuro,
              isEs ? ['Alerta (0)', 'Voz/Confuso (+3)', 'Dolor (+3)', 'Inconsciente (+3)']
                   : ['Alerta (0)', 'Voz/Confuso (+3)', 'Dor (+3)', 'Inconsciente (+3)'],
              (v) => setState(() => _news_neuro = v != null && v > 0 ? 3 : 0)),
            // Temperatura
            _sofaDropRow(
              isEs ? 'Temperatura °C' : 'Temperatura °C', _news_temp,
              ['≤35,0 (+3)', '35,1–36,0 (+1)', '36,1–38,0 (0)', '38,1–39,0 (+1)', '≥39,1 (+2)'],
              (v) => setState(() => _news_temp = v ?? 0)),
            const Divider(),
            _ResultTile(label: 'NEWS2 Total', value: '$_newsTotal', unit: 'pts', note: _newsLabel(_newsTotal), full: true),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'Desarrollado por la Royal College of Physicians (RCP) 2017. Score ≥7 = activar respuesta crítica inmediata.'
              : 'Royal College of Physicians 2017. Score ≥7 = acionar resposta de emergência imediata.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Child-Pugh ────────────────────────────────────────────────
        _SectionCard(
          title: isEs ? 'Child-Pugh (Hepatopatía Crónica)' : 'Child-Pugh (Hepatopatia Crônica)',
          icon: Icons.local_hospital_rounded,
          badge: '$_cpTotal',
          badgeColor: _cpTotal <= 6 ? kToolGreen : _cpTotal <= 9 ? const Color(0xFFB45309) : const Color(0xFFCC2222),
          child: Column(children: [
            _sofaDropRow(
              isEs ? 'Bilirrubina total' : 'Bilirrubina total', _cp_bili - 1,
              isEs ? ['<2 mg/dL (1)', '2–3 mg/dL (2)', '>3 mg/dL (3)']
                   : ['<2 mg/dL (1)', '2–3 mg/dL (2)', '>3 mg/dL (3)'],
              (v) => setState(() => _cp_bili = (v ?? 0) + 1)),
            _sofaDropRow(
              isEs ? 'Albúmina sérica' : 'Albumina sérica', _cp_alb - 1,
              ['>3,5 g/dL (1)', '2,8–3,5 g/dL (2)', '<2,8 g/dL (3)'],
              (v) => setState(() => _cp_alb = (v ?? 0) + 1)),
            _sofaDropRow(
              'TP / INR', _cp_pt - 1,
              isEs ? ['<4 s / <1,7 (1)', '4–6 s / 1,7–2,3 (2)', '>6 s / >2,3 (3)']
                   : ['<4 s / <1,7 (1)', '4–6 s / 1,7–2,3 (2)', '>6 s / >2,3 (3)'],
              (v) => setState(() => _cp_pt = (v ?? 0) + 1)),
            _sofaDropRow(
              isEs ? 'Ascitis' : 'Ascite', _cp_ascite - 1,
              isEs ? ['Ausente (1)', 'Leve (2)', 'Tensa/refractaria (3)']
                   : ['Ausente (1)', 'Leve (2)', 'Tensa/refratária (3)'],
              (v) => setState(() => _cp_ascite = (v ?? 0) + 1)),
            _sofaDropRow(
              isEs ? 'Encefalopatía' : 'Encefalopatia', _cp_encef - 1,
              isEs ? ['Ninguna — Grado 0 (1)', 'Grado I–II (2)', 'Grado III–IV (3)']
                   : ['Nenhuma — Grau 0 (1)', 'Grau I–II (2)', 'Grau III–IV (3)'],
              (v) => setState(() => _cp_encef = (v ?? 0) + 1)),
            const Divider(),
            _ResultTile(label: 'Child-Pugh', value: '$_cpTotal', unit: 'pts', note: _cpClass(_cpTotal), full: true),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'A (<6): cirrosis compensada. B (7–9): disfunción hepática significativa. C (≥10): descompensada — lista de trasplante.'
              : 'A (≤6): cirrose compensada. B (7–9): disfunção hepática significativa. C (≥10): descompensada — avaliar transplante.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── PSI/PORT ──────────────────────────────────────────────────
        _SectionCard(
          title: isEs ? 'PSI/PORT (Neumonía — Gravedad)' : 'PSI/PORT (PAC — Gravidade)',
          icon: Icons.air_outlined,
          badge: '$_psiScore',
          badgeColor: _psiScore <= 70 ? kToolGreen : _psiScore <= 90 ? const Color(0xFFB45309) : const Color(0xFFCC2222),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Idade
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: Text(isEs ? 'Edad (años) — pontuação direta' : 'Idade (anos) — pontuação direta',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kToolDark))),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _psiAgeCtrl,
                    keyboardType: TextInputType.number,
                    spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                    autocorrect: false,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kToolDark),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      hintText: '65',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kToolBorder)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
            ),
            const Text('COMORBIDADES (+pts)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF888888))),
            const SizedBox(height: 6),
            _scoreRow(isEs ? 'Neoplasia activa (+30)' : 'Neoplasia ativa (+30)', _psi_neoplasm, () => setState(() => _psi_neoplasm = !_psi_neoplasm), points: 30),
            _scoreRow(isEs ? 'Hepatopatía crónica (+20)' : 'Hepatopatia crônica (+20)', _psi_liver, () => setState(() => _psi_liver = !_psi_liver), points: 20),
            _scoreRow(isEs ? 'ICC / cardiopatía (+10)' : 'ICC / cardiopatia (+10)', _psi_chf, () => setState(() => _psi_chf = !_psi_chf), points: 10),
            _scoreRow(isEs ? 'AVC / secuelas (+10)' : 'AVC / sequela (+10)', _psi_cva, () => setState(() => _psi_cva = !_psi_cva), points: 10),
            _scoreRow(isEs ? 'ERC (+10)' : 'DRC (+10)', _psi_renal, () => setState(() => _psi_renal = !_psi_renal), points: 10),
            _scoreRow(isEs ? 'Internado en residencia (+10)' : 'Institucionalizado (+10)', _psi_nursing, () => setState(() => _psi_nursing = !_psi_nursing), points: 10),
            const SizedBox(height: 8),
            const Text('EXAME FÍSICO / CLÍNICA (+pts)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF888888))),
            const SizedBox(height: 6),
            _scoreRow(isEs ? 'Confusión/alteración mental (+20)' : 'Confusão / alt. mental (+20)', _psi_alt_ms, () => setState(() => _psi_alt_ms = !_psi_alt_ms), points: 20),
            _scoreRow(isEs ? 'FR ≥30/min (+20)' : 'FR ≥30 irpm (+20)', _psi_rr30, () => setState(() => _psi_rr30 = !_psi_rr30), points: 20),
            _scoreRow(isEs ? 'PAS <90 mmHg (+20)' : 'PAS <90 mmHg (+20)', _psi_sbp90, () => setState(() => _psi_sbp90 = !_psi_sbp90), points: 20),
            _scoreRow(isEs ? 'Tª <35 o ≥40°C (+15)' : 'T° <35 ou ≥40°C (+15)', _psi_temp, () => setState(() => _psi_temp = !_psi_temp), points: 15),
            _scoreRow(isEs ? 'FC ≥125 bpm (+10)' : 'FC ≥125 bpm (+10)', _psi_hr125, () => setState(() => _psi_hr125 = !_psi_hr125), points: 10),
            const SizedBox(height: 8),
            const Text('LABS / IMAGEM (+pts)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF888888))),
            const SizedBox(height: 6),
            _scoreRow(isEs ? 'pH arterial <7,35 (+30)' : 'pH arterial <7,35 (+30)', _psi_ph735, () => setState(() => _psi_ph735 = !_psi_ph735), points: 30),
            _scoreRow(isEs ? 'BUN >30 mg/dL (+20)' : 'Ureia >30 mg/dL (+20)', _psi_bun30, () => setState(() => _psi_bun30 = !_psi_bun30), points: 20),
            _scoreRow(isEs ? 'Na <130 mEq/L (+20)' : 'Na <130 mEq/L (+20)', _psi_na130, () => setState(() => _psi_na130 = !_psi_na130), points: 20),
            _scoreRow(isEs ? 'Glucosa ≥250 mg/dL (+10)' : 'Glicose ≥250 mg/dL (+10)', _psi_gluc250, () => setState(() => _psi_gluc250 = !_psi_gluc250), points: 10),
            _scoreRow(isEs ? 'Hto <30% (+10)' : 'Ht <30% (+10)', _psi_hct30, () => setState(() => _psi_hct30 = !_psi_hct30), points: 10),
            _scoreRow(isEs ? 'PaO₂ <60 mmHg (+10)' : 'PaO₂ <60 mmHg (+10)', _psi_po2_60, () => setState(() => _psi_po2_60 = !_psi_po2_60), points: 10),
            _scoreRow(isEs ? 'Derrame pleural (+10)' : 'Derrame pleural (+10)', _psi_eff, () => setState(() => _psi_eff = !_psi_eff), points: 10),
            const Divider(),
            _ResultTile(label: 'PSI/PORT', value: '$_psiScore', unit: 'pts', note: _psiClass(_psiScore), full: true),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'Fine MJ, NEJM 1997. Clases I–II: ambulatorio. III: observación. IV–V: hospitalización. CURB-65 para comparar.'
              : 'Fine MJ, NEJM 1997. Classes I–II: ambulatorial. III: observação. IV–V: internação. Comparar com CURB-65.'),
          ]),
        ),

      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 3 — CARDIO
// ══════════════════════════════════════════════════════════════════
class _CardioTab extends StatefulWidget {
  @override
  State<_CardioTab> createState() => _CardioTabState();
}

class _CardioTabState extends State<_CardioTab> {
  final _sbpCtrl = TextEditingController();
  final _dbpCtrl = TextEditingController();
  final _hrCtrl  = TextEditingController();
  final _svCtrl  = TextEditingController();

  // QTc
  final _qtCtrl  = TextEditingController();
  final _rrCtrl  = TextEditingController();

  @override
  void dispose() {
    _sbpCtrl.dispose(); _dbpCtrl.dispose(); _hrCtrl.dispose();
    _svCtrl.dispose(); _qtCtrl.dispose(); _rrCtrl.dispose();
    super.dispose();
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
  String _fmt(double? v, {int dec = 1}) {
    if (v == null || !v.isFinite) return '—';
    return v.toStringAsFixed(dec).replaceAll('.', ',');
  }

  String? get _map {
    final s = _n(_sbpCtrl), d = _n(_dbpCtrl);
    if (s == null || d == null) return null;
    return _fmt((s + 2 * d) / 3);
  }

  String? get _pp {
    final s = _n(_sbpCtrl), d = _n(_dbpCtrl);
    if (s == null || d == null) return null;
    return _fmt(s - d);
  }

  String? get _co {
    final hr = _n(_hrCtrl), sv = _n(_svCtrl);
    if (hr == null || sv == null) return null;
    return _fmt(hr * sv / 1000, dec: 2);
  }

  String? get _qtcBazett {
    final qt = _n(_qtCtrl), rr = _n(_rrCtrl);
    if (qt == null || rr == null || rr <= 0) return null;
    return _fmt(qt / (rr / 1000).sqrt);
  }

  String _mapLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d < 60)  return '⛔ Crítico (<60) — risco de isquemia';
    if (d < 65)  return '⛔ Hipoperfusão (<65)';
    if (d <= 105) return '✓ Adequada (65–105)';
    return '↑ Elevada (>105)';
  }

  String _qtcLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d < 440) return '✓ Normal (<440 ms)';
    if (d < 500) return '⚠ Limítrofe (440–499 ms) — monitorar';
    return '⛔ Prolongado (≥500 ms) — risco torsades';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [

        _SectionCard(
          title: isEs ? 'Hemodinámica' : 'Hemodinâmica',
          icon: Icons.monitor_heart_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: 'PAS (mmHg)', ctrl: _sbpCtrl, onChanged: (_) => setState(() {}), hint: '120')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: 'PAD (mmHg)', ctrl: _dbpCtrl, onChanged: (_) => setState(() {}), hint: '80')),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ResultTile(label: 'PAM', value: _map, unit: 'mmHg', note: _mapLabel(_map))),
              const SizedBox(width: 8),
              Expanded(child: _ResultTile(label: isEs ? 'PP (Pulso)' : 'PP (Pulso)', value: _pp, unit: 'mmHg')),
            ]),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'PAM = (PAS + 2×PAD)/3. Meta sepsis: ≥65 mmHg. PP estrecho (<25): choque. PP amplio (>60): insuficiencia aórtica.'
              : 'PAM = (PAS + 2×PAD)/3. Meta sepse: ≥65 mmHg. PP estreito (<25): choque. PP amplo (>60): insuficiência aórtica.'),
          ]),
        ),

        const SizedBox(height: 12),

        _SectionCard(
          title: isEs ? 'Gasto Cardíaco' : 'Débito Cardíaco',
          icon: Icons.speed_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: isEs ? 'FC (bpm)' : 'FC (bpm)', ctrl: _hrCtrl, onChanged: (_) => setState(() {}), hint: '80')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: isEs ? 'Vol Sistólico (mL)' : 'Vol Sistólico (mL)', ctrl: _svCtrl, onChanged: (_) => setState(() {}), hint: '70')),
            ]),
            const SizedBox(height: 14),
            _ResultTile(label: isEs ? 'Débito Cardíaco (DC = FC × VS)' : 'Débito Cardíaco (DC = FC × VS)',
              value: _co, unit: 'L/min', full: true,
              note: isEs ? 'Normal: 4–8 L/min. Baixo: <4 L/min (choque de baixo débito)' : 'Normal: 4–8 L/min. Baixo: <4 L/min (choque de baixo débito)'),
          ]),
        ),

        const SizedBox(height: 12),

        _SectionCard(
          title: isEs ? 'Intervalo QTc (Bazett)' : 'Intervalo QTc (Bazett)',
          icon: Icons.show_chart_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: isEs ? 'QT medido (ms)' : 'QT medido (ms)', ctrl: _qtCtrl, onChanged: (_) => setState(() {}), hint: '400')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: isEs ? 'Intervalo RR (ms)' : 'Intervalo RR (ms)', ctrl: _rrCtrl, onChanged: (_) => setState(() {}), hint: '800')),
            ]),
            const SizedBox(height: 14),
            _ResultTile(label: 'QTc — Bazett', value: _qtcBazett, unit: 'ms', note: _qtcLabel(_qtcBazett), full: true),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'QTc = QT / √(RR em segundos). Normal H: <440 ms | M: <460 ms. ≥500 ms: risco de torsades de pointes — revisar fármacos prolongadores.'
              : 'QTc = QT / √(RR em segundos). Normal H: <440 ms | M: <460 ms. ≥500 ms: risco de torsades de pointes — revisar fármacos prolongadores.'),
          ]),
        ),

        const SizedBox(height: 12),

        _SectionCard(
          title: isEs ? 'Conversión de Presión' : 'Conversão de Pressão',
          icon: Icons.swap_horiz_rounded,
          child: Column(children: [
            _PressureConvWidget(),
          ]),
        ),

      ]),
    );
  }
}

class _PressureConvWidget extends StatefulWidget {
  @override
  State<_PressureConvWidget> createState() => _PressureConvWidgetState();
}

class _PressureConvWidgetState extends State<_PressureConvWidget> {
  final _ctrl = TextEditingController();
  String _from = 'mmHg';

  final _units = {'mmHg': 1.0, 'cmH2O': 0.7355, 'kPa': 7.5006, 'mbar': 0.7501};

  Map<String, String> get _results {
    final val = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (val == null) return {};
    final baseInMmhg = val / (_units[_from] ?? 1.0);
    return _units.map((k, f) => MapEntry(k, (baseInMmhg * f).toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _LabeledInput(label: 'Valor', ctrl: _ctrl, onChanged: (_) => setState(() {}), hint: '120')),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('UNIDADE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF888888))),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: kToolBorder)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _from,
                isDense: true,
                onChanged: (v) => setState(() => _from = v!),
                items: _units.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
              ),
            ),
          ),
        ]),
      ]),
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 12),
        ..._results.entries.where((e) => e.key != _from).map((e) =>
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 70, child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kToolDark))),
              const SizedBox(width: 8),
              Text(e.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kToolGreen)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 4 — ELETRÓLITOS
// ══════════════════════════════════════════════════════════════════
class _ElectrolytesTab extends StatefulWidget {
  @override
  State<_ElectrolytesTab> createState() => _ElectrolytesTabState();
}

class _ElectrolytesTabState extends State<_ElectrolytesTab> {
  final _naCtrl   = TextEditingController();
  final _clCtrl   = TextEditingController();
  final _hco3Ctrl = TextEditingController();
  final _glucCtrl = TextEditingController();
  final _albumCtrl= TextEditingController();
  final _caCtrl   = TextEditingController();
  final _bunCtrl  = TextEditingController();
  final _phCtrl   = TextEditingController();
  final _pco2Ctrl = TextEditingController();
  final _beCtrl   = TextEditingController();
  final _wCtrl    = TextEditingController();

  @override
  void dispose() {
    for (final c in [_naCtrl, _clCtrl, _hco3Ctrl, _glucCtrl, _albumCtrl, _caCtrl, _bunCtrl, _phCtrl, _pco2Ctrl, _beCtrl, _wCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
  String _fmt(double? v, {int dec = 1}) {
    if (v == null || !v.isFinite) return '—';
    return v.toStringAsFixed(dec).replaceAll('.', ',');
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

  String? get _corrCa {
    final ca = _n(_caCtrl), alb = _n(_albumCtrl);
    if (ca == null || alb == null) return null;
    return _fmt(ca + 0.8 * (4.0 - alb), dec: 2);
  }

  String? get _osmolarity {
    final na = _n(_naCtrl), g = _n(_glucCtrl);
    if (na == null || g == null) return null;
    final bun = _n(_bunCtrl) ?? 0.0; // campo BUN real; omitido → 0
    return _fmt(2 * na + g / 18 + bun / 2.8, dec: 0);
  }

  String? get _bicarbonateDef {
    final w = _n(_wCtrl), hco3 = _n(_hco3Ctrl);
    if (w == null || hco3 == null) return null;
    final def = w * 0.3 * (24 - hco3);
    return _fmt(def < 0 ? 0 : def, dec: 0);
  }

  String _gasInterpret() {
    final ph  = _n(_phCtrl);
    final pco2= _n(_pco2Ctrl);
    final hco3= _n(_hco3Ctrl);
    final be  = _n(_beCtrl);
    if (ph == null || pco2 == null || hco3 == null) return '—';

    String primary = '';
    String comp = '';

    if (ph < 7.35) {
      if (pco2 > 45) {
        primary = 'Acidose Respiratória';
        final exp = hco3 > 24 ? 'com compensação metabólica' : '';
        comp = exp;
      } else {
        primary = 'Acidose Metabólica';
        final expPco2 = 1.5 * hco3 + 8;
        comp = pco2 < expPco2 - 2 ? 'com compensação respiratória (hiperventilação)'
             : pco2 > expPco2 + 2 ? 'com distúrbio respiratório adicional'
             : 'compensação adequada';
      }
    } else if (ph > 7.45) {
      if (pco2 < 35) {
        primary = 'Alcalose Respiratória';
        comp = hco3 < 24 ? 'com compensação metabólica' : '';
      } else {
        primary = 'Alcalose Metabólica';
        final expPco2 = 0.7 * hco3 + 21;
        comp = pco2 > expPco2 + 2 ? 'com compensação respiratória' : '';
      }
    } else {
      primary = '✓ pH Normal (7,35–7,45)';
    }

    if (be != null) {
      if (be < -3) comp += ' | BE: ⛔ déficit de base (${_fmt(be)})';
      if (be > 3)  comp += ' | BE: ↑ excesso de base (${_fmt(be)})';
    }

    return '$primary${comp.isNotEmpty ? "\n$comp" : ""}';
  }

  String _agLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d < 8)  return '↓ Baixo (<8)';
    if (d <= 12) return '✓ Normal (8–12)';
    if (d <= 20) return '⚠ Aumentado (12–20)';
    return '⛔ Muito elevado (>20) — acidose de AG alto';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [

        _SectionCard(
          title: isEs ? 'Electrolitos' : 'Eletrólitos',
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
              Expanded(child: _LabeledInput(label: isEs ? 'Glucosa (mg/dL)' : 'Glicose (mg/dL)', ctrl: _glucCtrl, onChanged: (_) => setState(() {}), hint: '100')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _LabeledInput(label: isEs ? 'Ca²⁺ total (mg/dL)' : 'Ca²⁺ total (mg/dL)', ctrl: _caCtrl, onChanged: (_) => setState(() {}), hint: '9,5')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: isEs ? 'Albúmina (g/dL)' : 'Albumina (g/dL)', ctrl: _albumCtrl, onChanged: (_) => setState(() {}), hint: '4,0')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _LabeledInput(label: isEs ? 'BUN (mg/dL)' : 'BUN/Ureia (mg/dL)', ctrl: _bunCtrl, onChanged: (_) => setState(() {}), hint: '14')),
              const SizedBox(width: 10),
              Expanded(child: SizedBox()), // espaço reservado para simetria
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _ResultTile(label: isEs ? 'Gap Aniónico' : 'Gap Aniônico', value: _anionGap, unit: 'mEq/L', note: _agLabel(_anionGap))),
              const SizedBox(width: 8),
              Expanded(child: _ResultTile(label: 'Na⁺ Corrigido', value: _corrNa, unit: 'mEq/L')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _ResultTile(label: isEs ? 'Ca²⁺ Corregido' : 'Ca²⁺ Corrigido', value: _corrCa, unit: 'mg/dL',
                note: double.tryParse((_corrCa ?? '').replaceAll(',', '.')) != null
                  ? (double.parse(_corrCa!.replaceAll(',', '.')) < 8.5 ? '⛔ Hipocalcemia' : double.parse(_corrCa!.replaceAll(',', '.')) > 10.5 ? '↑ Hipercalcemia' : '✓ Normal') : '')),
              const SizedBox(width: 8),
              Expanded(child: _ResultTile(label: isEs ? 'Osmolaridad calc.' : 'Osmolaridade calc.', value: _osmolarity, unit: 'mOsm/kg')),
            ]),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'Gap Aniônico = Na - (Cl + HCO₃). Ca corregido = Ca + 0,8×(4 - Alb). Osmolaridad = 2×Na + Gluc/18 + BUN/2,8.'
              : 'Gap Aniônico = Na − (Cl + HCO₃). Ca corrigido = Ca + 0,8×(4 − Alb). Osmolaridade = 2×Na + Gluc/18 + BUN/2,8.'),
          ]),
        ),

        const SizedBox(height: 12),

        _SectionCard(
          title: isEs ? 'Gasometría Arterial' : 'Gasometria Arterial',
          icon: Icons.air_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: 'pH', ctrl: _phCtrl, onChanged: (_) => setState(() {}), hint: '7,40')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: 'pCO₂ (mmHg)', ctrl: _pco2Ctrl, onChanged: (_) => setState(() {}), hint: '40')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _LabeledInput(label: 'HCO₃⁻ (mEq/L)', ctrl: _hco3Ctrl, onChanged: (_) => setState(() {}), hint: '24')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: 'BE (mEq/L)', ctrl: _beCtrl, onChanged: (_) => setState(() {}), hint: '0')),
            ]),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF07110d),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('INTERPRETAÇÃO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(_gasInterpret(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, height: 1.5)),
              ]),
            ),
            const SizedBox(height: 10),
            _InfoNote(text: isEs
              ? 'pH: 7,35–7,45 | pCO₂: 35–45 mmHg | HCO₃: 22–26 mEq/L | BE: -2 a +2 mEq/L.'
              : 'pH: 7,35–7,45 | pCO₂: 35–45 mmHg | HCO₃: 22–26 mEq/L | BE: −2 a +2 mEq/L.'),
          ]),
        ),

        const SizedBox(height: 12),

        _SectionCard(
          title: isEs ? 'Déficit de Bicarbonato' : 'Déficit de Bicarbonato',
          icon: Icons.calculate_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: isEs ? 'Peso (kg)' : 'Peso (kg)', ctrl: _wCtrl, onChanged: (_) => setState(() {}), hint: '70')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: 'HCO₃⁻ atual (mEq/L)', ctrl: _hco3Ctrl, onChanged: (_) => setState(() {}), hint: '18')),
            ]),
            const SizedBox(height: 14),
            _ResultTile(label: isEs ? 'Déficit de HCO₃⁻ (meta: 24)' : 'Déficit de HCO₃⁻ (meta: 24)',
              value: _bicarbonateDef, unit: 'mEq', full: true,
              note: isEs ? 'Fórmula: Peso × 0,3 × (24 − HCO₃). Repor 50% do déficit inicialmente.' : 'Fórmula: Peso × 0,3 × (24 − HCO₃). Repor 50% do déficit inicialmente.'),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 5 — INFUSÃO
// ══════════════════════════════════════════════════════════════════
class _InfusionTab extends StatefulWidget {
  @override
  State<_InfusionTab> createState() => _InfusionTabState();
}

class _InfusionTabState extends State<_InfusionTab> {
  final _infDrugCtrl  = TextEditingController(text: 'Noradrenalina');
  final _infConcCtrl  = TextEditingController(text: '4');
  final _infRateCtrl  = TextEditingController(text: '10');
  final _infWeightCtrl= TextEditingController();
  final _doseCtrl     = TextEditingController();
  final _concCalcCtrl = TextEditingController();
  final _weightCalcCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [_infDrugCtrl, _infConcCtrl, _infRateCtrl, _infWeightCtrl, _doseCtrl, _concCalcCtrl, _weightCalcCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
  String _fmt(double? v, {int dec = 2}) {
    if (v == null || !v.isFinite) return '—';
    return v.toStringAsFixed(dec).replaceAll('.', ',');
  }

  String? get _infusionRate {
    final conc = _n(_infConcCtrl);
    final rate = _n(_infRateCtrl);
    final weight = _n(_infWeightCtrl);
    if (conc == null || rate == null) return null;
    final mgH = conc * rate;
    final mcgH = mgH * 1000;
    if (weight != null && weight > 0) {
      final mcgKgMin = mcgH / (weight * 60);
      return '${_fmt(mcgKgMin, dec: 3)} mcg/kg/min\n${_fmt(mcgH, dec: 0)} mcg/h';
    }
    return '${_fmt(mgH, dec: 2)} mg/h\n${_fmt(mcgH, dec: 0)} mcg/h';
  }

  String? get _doseToRate {
    final dose = _n(_doseCtrl);
    final conc = _n(_concCalcCtrl);
    final weight = _n(_weightCalcCtrl);
    if (dose == null || conc == null || weight == null) return null;
    final rateML = (dose * weight * 60) / (conc * 1000);
    return '${_fmt(rateML, dec: 2)} mL/h';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [

        _SectionCard(
          title: isEs ? 'Velocidad → Dosis' : 'Velocidade → Dose',
          icon: Icons.water_drop_rounded,
          child: Column(children: [
            _LabeledInput(label: isEs ? 'Fármaco' : 'Fármaco', ctrl: _infDrugCtrl, onChanged: (_) => setState(() {}), hint: 'Noradrenalina'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _LabeledInput(label: isEs ? 'Concentración (mg/mL)' : 'Concentração (mg/mL)', ctrl: _infConcCtrl, onChanged: (_) => setState(() {}), hint: '4')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: isEs ? 'Velocidad (mL/h)' : 'Velocidade (mL/h)', ctrl: _infRateCtrl, onChanged: (_) => setState(() {}), hint: '10')),
            ]),
            const SizedBox(height: 10),
            _LabeledInput(
              label: isEs ? 'Peso (kg) — opcional para mcg/kg/min' : 'Peso (kg) — opcional para mcg/kg/min',
              ctrl: _infWeightCtrl, onChanged: (_) => setState(() {}), hint: '70'),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [kToolDark, Color(0xFF123326), kToolGreen]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('RESULTADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 2)),
                const SizedBox(height: 6),
                Text(_infDrugCtrl.text.isNotEmpty ? _infDrugCtrl.text : 'Fármaco',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0x99FFFFFF))),
                const SizedBox(height: 4),
                Text(_infusionRate ?? (isEs ? 'Ingrese concentración y velocidad' : 'Informe concentração e velocidade'),
                  style: TextStyle(fontSize: _infusionRate != null ? 20 : 13,
                    fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'Verificar prescripción antes de administrar. Revisar protocolo institucional.'
              : 'Verificar prescrição antes de administrar. Revisar protocolo institucional.'),
          ]),
        ),

        const SizedBox(height: 12),

        _SectionCard(
          title: isEs ? 'Dosis → Velocidad (mcg/kg/min)' : 'Dose → Velocidade (mcg/kg/min)',
          icon: Icons.swap_vert_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(child: _LabeledInput(label: isEs ? 'Dosis (mcg/kg/min)' : 'Dose (mcg/kg/min)', ctrl: _doseCtrl, onChanged: (_) => setState(() {}), hint: '0,1')),
              const SizedBox(width: 10),
              Expanded(child: _LabeledInput(label: isEs ? 'Concentración (mg/mL)' : 'Concentração (mg/mL)', ctrl: _concCalcCtrl, onChanged: (_) => setState(() {}), hint: '4')),
            ]),
            const SizedBox(height: 10),
            _LabeledInput(label: isEs ? 'Peso do paciente (kg)' : 'Peso do paciente (kg)', ctrl: _weightCalcCtrl, onChanged: (_) => setState(() {}), hint: '70'),
            const SizedBox(height: 14),
            _ResultTile(label: isEs ? 'Velocidad de Infusión' : 'Velocidade de Infusão',
              value: _doseToRate, unit: '', full: true,
              note: isEs ? 'Fórmula: Dosis × Peso × 60 / (Conc × 1000)' : 'Fórmula: Dose × Peso × 60 / (Conc × 1000)'),
          ]),
        ),

        const SizedBox(height: 12),

        _SectionCard(
          title: isEs ? 'Referencia de Vasopresores' : 'Referência de Vasopressores',
          icon: Icons.speed_rounded,
          child: Column(children: [
            _VasoRefRow(drug: 'Noradrenalina', dose: '0,05–1 µg/kg/min', note: isEs ? '1ª línea sepsis (AHA/SCCM)' : '1ª linha sepse (AHA/SCCM)'),
            _VasoRefRow(drug: 'Dobutamina', dose: '2,5–20 µg/kg/min', note: isEs ? 'Inotrópico IC bajo débito' : 'Inotrópico IC baixo débito'),
            _VasoRefRow(drug: 'Adrenalina', dose: '0,01–0,5 µg/kg/min', note: isEs ? 'Choque refractario / anafilaxia / PCR' : 'Choque refratário / anafilaxia / PCR'),
            _VasoRefRow(drug: 'Vasopressina', dose: '0,03–0,04 UI/min', note: isEs ? 'Adyuvante (dosis fija)' : 'Adjuvante (dose fixa)'),
            _VasoRefRow(drug: 'Dopamina', dose: '2–20 µg/kg/min', note: isEs ? 'Alternativa (más arritmias)' : 'Alternativa (mais arritmias)'),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'Preferir acesso venoso central para vasopresores. Titular conforme PAM objetivo ≥65 mmHg.'
              : 'Preferir acesso venoso central para vasopressores. Titular conforme PAM alvo ≥65 mmHg.'),
          ]),
        ),

      ]),
    );
  }
}

class _VasoRefRow extends StatelessWidget {
  final String drug, dose, note;
  const _VasoRefRow({required this.drug, required this.dose, required this.note});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kToolBorder))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(drug, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kToolDark)),
          Text(note, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: kToolGreen.withValues(alpha: 0.12)),
          child: Text(dose, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kToolGreen)),
        ),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
//  TAB 6 — REFERÊNCIA RÁPIDA
// ══════════════════════════════════════════════════════════════════
class _ReferenceTab extends StatefulWidget {
  @override
  State<_ReferenceTab> createState() => _ReferenceTabState();
}

class _ReferenceTabState extends State<_ReferenceTab> {
  int _section = 0;

  static const _sections = ['LABS', 'ECG', 'ANTÍDOTOS', 'ACESSO', 'GASOMETRIA'];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    return Column(children: [
      // ── Sub-menu ──────────────────────────────────────────────
      Container(
        color: const Color(0xFF0A1A10),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_sections.length, (i) {
              final active = _section == i;
              return GestureDetector(
                onTap: () => setState(() => _section = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active ? const Color(0xFFC5A365) : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: active ? const Color(0xFFC5A365) : Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(_sections[i],
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                      color: active ? const Color(0xFF07110d) : Colors.white60, letterSpacing: 0.5)),
                ),
              );
            }),
          ),
        ),
      ),
      // ── Content ───────────────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: _buildSection(isEs),
        ),
      ),
    ]);
  }

  Widget _buildSection(bool isEs) {
    switch (_section) {
      case 0: return _buildLabs(isEs);
      case 1: return _buildECG(isEs);
      case 2: return _buildAntidotes(isEs);
      case 3: return _buildAccess(isEs);
      case 4: return _buildGasometry(isEs);
      default: return const SizedBox();
    }
  }

  // ── LABS ─────────────────────────────────────────────────────────
  Widget _buildLabs(bool isEs) {
    final groups = [
      {
        'title': isEs ? 'Hemograma' : 'Hemograma',
        'icon': Icons.bloodtype_rounded,
        'items': [
          ['Hemoglobina', 'H: 13,5–17,5 g/dL', 'M: 12,0–15,5 g/dL'],
          ['Hematócrito', 'H: 41–53%', 'M: 36–46%'],
          ['Leucócitos', '4.000–11.000/mm³', isEs ? 'Neutrófilos >1500 = OK' : 'Neutrófilos >1500 = OK'],
          ['Neutrófilos', '1500–7700/mm³', '>70% = sepse?'],
          ['Linfócitos', '1000–4800/mm³', '<1000 = linfopenia'],
          ['Plaquetas', '150.000–400.000/mm³', isEs ? '<50k = riesgo sangrado' : '<50k = risco sangrado'],
          ['VCM', '80–100 fL', '<80=microcítica; >100=macrocítica'],
          ['RDW', '<14,5%', isEs ? '>14,5%: anemia mista/carencial' : '>14,5%: anemia mista/carencial'],
        ],
      },
      {
        'title': isEs ? 'Bioquímica' : 'Bioquímica',
        'icon': Icons.science_rounded,
        'items': [
          ['Glicemia jejum', '70–99 mg/dL', isEs ? '<70 hipoglucemia; >126 DM' : '<70 hipoglicemia; >126 DM'],
          ['Ureia', '15–45 mg/dL', '>45 = azotemia'],
          ['Creatinina', 'H: 0,7–1,2  M: 0,5–1,0 mg/dL', isEs ? 'Ajustar si ↑ agudo' : 'Ajustar se ↑ agudo'],
          ['Sódio (Na+)', '135–145 mEq/L', '<135 hipo; >145 hiper'],
          ['Potássio (K+)', '3,5–5,0 mEq/L', '<3,5 hipo; >5,5 = EMERGÊNCIA'],
          ['Cloro (Cl-)', '98–106 mEq/L', ''],
          ['Cálcio total', '8,5–10,5 mg/dL', '<7 = crise hipocalcêmica'],
          ['Cálcio ionizado', '1,1–1,35 mmol/L', '<0,9 = hipocalcemia'],
          ['Magnésio', '1,7–2,2 mg/dL', '<1,5 arritmias/convulsão'],
          ['Fósforo', '2,5–4,5 mg/dL', ''],
          ['Proteínas totais', '6,4–8,3 g/dL', 'Albumina: 3,5–5,0 g/dL'],
          ['Bilirrubina total', '<1,2 mg/dL', '>5 = icterícia clínica'],
          ['TGO (AST)', '<40 U/L', '>3× LSN = hepatocelular'],
          ['TGP (ALT)', '<41 U/L', '>10× LSN = hepatite aguda'],
          ['Gama-GT', '<50 U/L', 'Álcool/obstrução'],
          ['Fosfatase alcalina', '44–147 U/L', 'Colestase/óssea'],
          ['Amilase', '<100 U/L', '>3× = pancreatite'],
          ['Lipase', '<160 U/L', '>3× = pancreatite (mais específico)'],
          ['PCR', '<0,5 mg/dL', '>10 = inflamação significativa'],
          ['Procalcitonina', '<0,1 ng/mL', '>0,5 considerar ATB; >2 bacteremia'],
          ['Lactato', '<2,0 mmol/L', '>2 = hipoperfusão; >4 = crítico'],
          ['BNP/NT-proBNP', '<100 pg/mL / <300 pg/mL', 'IC: >400 / >900'],
          ['Troponina I/T', '<0,04 ng/mL (varia)', 'SCA: ↑ + clínica'],
          ['D-Dímero', '<500 ng/mL', '>500 = rastreio TEP/TVP'],
          ['INR/TP', '0,8–1,2 / 11–14s', '>1,5 = coagulopatia'],
          ['TTPa', '25–35s', '>70s = monitoração heparina'],
          ['TSH', '0,3–4,5 mUI/L', '<0,1 hiper; >10 hipotireoidismo'],
          ['T4 livre', '0,8–1,8 ng/dL', ''],
          ['HbA1c', '<5,7% normal', '≥6,5% = DM'],
        ],
      },
      {
        'title': isEs ? 'Urinálisis' : 'Urinálise',
        'icon': Icons.water_drop_rounded,
        'items': [
          ['Leucócitos', '<5/campo', isEs ? '>5 = piuria (ITU)' : '>5 = piúria (ITU)'],
          ['Hemácias', '<2/campo', '>5 = hematúria'],
          ['Proteína', 'Traços ou neg.', '>300 mg/24h = proteinúria'],
          ['Glicose', 'Negativo', isEs ? 'Positivo = hiperglucemia o SGLT2' : 'Positivo = hiperglicemia ou SGLT2'],
          ['Nitrito', 'Negativo', 'Positivo = gram-negativos (ITU)'],
          ['Densidade', '1,001–1,035', '<1,005 = hiposstenúria; >1,030 = desidratação'],
        ],
      },
    ];

    return Column(children: groups.map((g) {
      final items = g['items'] as List<List<String>>;
      return _SectionCard(
        title: g['title'] as String,
        icon: g['icon'] as IconData,
        child: Column(
          children: items.map((row) => _LabRow(
            name: row[0],
            ref: row[1],
            note: row.length > 2 ? row[2] : '',
          )).toList(),
        ),
      );
    }).toList());
  }

  // ── ECG ──────────────────────────────────────────────────────────
  Widget _buildECG(bool isEs) {
    return Column(children: [
      _SectionCard(
        title: isEs ? 'Intervalos Normales' : 'Intervalos Normais',
        icon: Icons.monitor_heart_rounded,
        child: Column(children: [
          _LabRow(name: 'FC', ref: '60–100 bpm', note: isEs ? '<60 bradicardia; >100 taquicardia' : '<60 bradicardia; >100 taquicardia'),
          _LabRow(name: 'PR', ref: '120–200 ms', note: isEs ? '>200 ms = BAV 1°' : '>200 ms = BAV 1°'),
          _LabRow(name: 'QRS', ref: '<120 ms', note: isEs ? '>120 ms = bloqueio de ramo' : '>120 ms = bloqueio de ramo'),
          _LabRow(name: 'QTc', ref: 'H <440 ms  M <460 ms', note: isEs ? '>500 ms = risco Torsades' : '>500 ms = risco Torsades'),
          _LabRow(name: 'Eixo', ref: '-30° a +90°', note: isEs ? 'Desvio E: HVE/BCRE; D: TEP/BCRD' : 'Desvio E: HVE/BCRE; D: TEP/BCRD'),
        ]),
      ),
      _SectionCard(
        title: isEs ? 'Patrones ECG Urgentes' : 'Padrões ECG de Urgência',
        icon: Icons.warning_rounded,
        child: Column(children: [
          _EcgPattern(
            pattern: 'IAMCSST',
            desc: isEs
              ? 'Supra ST ≥1mm em ≥2 derivações contíguas (≥2mm em V1–V4). Novo BCRE. Reperfusão emergente.'
              : 'Supra ST ≥1mm em ≥2 derivações contíguas (≥2mm em V1–V4). Novo BCRE. Reperfusão emergente.',
            color: const Color(0xFFCC2222),
          ),
          _EcgPattern(
            pattern: isEs ? 'Torsades de Pointes' : 'Torsades de Pointes',
            desc: isEs
              ? 'TV polimórfica, QTc prolongado. Causa: hipocalemia, hipoMg, QT-prolongadores. Tto: MgSO4 2g IV.'
              : 'TV polimórfica, QTc prolongado. Causa: hipocalemia, hipoMg, drogas. Tto: MgSO4 2g IV.',
            color: const Color(0xFFCC2222),
          ),
          _EcgPattern(
            pattern: 'Hiperpotassemia',
            desc: isEs
              ? 'Progressão: ondas T picudas → PR largo → QRS ancho → sinusoidal → FV. Gluconato Ca2+ urgente.'
              : 'Progressão: T apiculadas → PR longo → QRS largo → padrão sinusoidal → FV. Gluconato Ca2+ urgente.',
            color: const Color(0xFFCC2222),
          ),
          _EcgPattern(
            pattern: isEs ? 'Fibrilação Atrial' : 'Fibrilação Atrial',
            desc: isEs
              ? 'Ritmo irregularmente irregular, sem ondas P. CHADS2-VASc para anticoagulação. FC alvo <110 bpm.'
              : 'Ritmo irregularmente irregular, sem ondas P. CHA2DS2-VASc para anticoagulação. FC alvo <110 bpm.',
            color: const Color(0xFFB45309),
          ),
          _EcgPattern(
            pattern: isEs ? 'TEP (patrón S1Q3T3)' : 'TEP (padrão S1Q3T3)',
            desc: isEs
              ? 'S profunda em D1, Q e T invertida em D3. Taquicardia sinusal + BCRD novo = alta suspeita.'
              : 'S profunda em D1, Q e T invertida em D3. Taquicardia sinusal + BCRD novo = alta suspeita.',
            color: const Color(0xFFB45309),
          ),
          _EcgPattern(
            pattern: isEs ? 'BAV Total (3° grado)' : 'BAV Total (3° grau)',
            desc: isEs
              ? 'Dissociação AV completa. Escape juncional (FC 40–60) ou ventricular (FC 20–40). Atropina + MP urgente.'
              : 'Dissociação AV completa. Escape juncional (FC 40–60) ou ventricular (FC 20–40). Atropina + MP urgente.',
            color: const Color(0xFFCC2222),
          ),
          _EcgPattern(
            pattern: isEs ? 'Hipocalemia' : 'Hipocalemia',
            desc: isEs
              ? 'Achatamiento/inversión onda T, ondas U prominentes, QTc prolongado. KCl IV urgente si K+ <2,5.'
              : 'Achatamento/inversão onda T, ondas U proeminentes, QTc prolongado. KCl IV urgente se K+ <2,5.',
            color: const Color(0xFFB45309),
          ),
        ]),
      ),
      _SectionCard(
        title: isEs ? 'Territorios Coronarios' : 'Territórios Coronários',
        icon: Icons.favorite_rounded,
        child: Column(children: [
          _LabRow(name: 'DA (anterior)', ref: 'V1–V4 + aVL', note: isEs ? 'ADA: paredes anterior e septal' : 'ADA: paredes anterior e septal'),
          _LabRow(name: 'Cx (lateral)', ref: 'I, aVL, V5–V6', note: isEs ? 'Arteria circunfleja' : 'Artéria circunflexa'),
          _LabRow(name: 'CD (inferior)', ref: 'II, III, aVF', note: isEs ? 'Considerar IAM VD: V3R-V4R' : 'Considerar IAM VD: V3R-V4R'),
          _LabRow(name: isEs ? 'Posterior' : 'Posterior', ref: 'V7–V9 (espelho V1-V3)', note: isEs ? 'Infra ST anterior = supra posterior' : 'Infra ST anterior = supra posterior'),
        ]),
      ),
    ]);
  }

  // ── ANTÍDOTOS ────────────────────────────────────────────────────
  Widget _buildAntidotes(bool isEs) {
    final antidotes = [
      ['Paracetamol', 'N-Acetilcisteína', isEs ? '150 mg/kg IV em 60 min, depois 50 mg/kg em 4h, depois 100 mg/kg em 16h. Usar nomograma Rumack-Matthew.' : '150 mg/kg IV em 60 min, depois 50 mg/kg em 4h, depois 100 mg/kg em 16h. Nomograma Rumack-Matthew.', '🟡'],
      ['Opioides', 'Naloxona', isEs ? '0,4–2 mg IV/IM/SC a cada 2–3 min. Duração 30–90 min (< que morfina) — repetir ou infusão.' : '0,4–2 mg IV/IM/SC a cada 2–3 min. Duração 30–90 min (< que morfina) — repetir ou infusão contínua.', '🔴'],
      ['Benzodiazepínicos', 'Flumazenil', isEs ? '0,2 mg IV em 30s; repetir 0,1 mg/min; máx. 1 mg. CUIDADO: convulsões em dependentes crônicos.' : '0,2 mg IV em 30s; repetir 0,1 mg/min; máx. 1 mg. CUIDADO: convulsões em dependentes crônicos.', '🟡'],
      ['Digoxina', 'Anticorpos anti-Digoxina (Digibind)', isEs ? '80 mg IV neutraliza 1 mg digoxina. Indicação: K+ >5, arritmias ameaçadoras.' : '80 mg IV neutraliza 1 mg digoxina. Indicação: K+ >5, arritmias ameaçadoras.', '🔴'],
      ['Heparina NF', 'Sulfato de Protamina', isEs ? '1 mg neutraliza 100 UI HNF. IV lento em 10 min (hipotensão). Máx. 50 mg/dose.' : '1 mg neutraliza 100 UI HNF. IV lento em 10 min (hipotensão). Máx. 50 mg/dose.', '🟡'],
      ['Warfarina', 'Vitamina K + PFC/CCP', isEs ? 'INR >10 sem sangrado: Vit K 2,5–5 mg VO. Com sangrado grave: CCP 25–50 UI/kg IV + Vit K 5–10 mg IV.' : 'INR >10 sem sangrado: Vit K 2,5–5 mg VO. Com sangrado grave: CCP 25–50 UI/kg IV + Vit K 5–10 mg IV.', '🔴'],
      ['Rivaroxabana/Apixabana', 'Andexanet alfa', isEs ? '400–800 mg IV bolo + infusão. Alto custo. Alternativa: CCP 4 fatores 25–50 UI/kg.' : '400–800 mg IV bolo + infusão. Alto custo. Alternativa: CCP 4 fatores 25–50 UI/kg.', '🔴'],
      ['Dabigatrana', 'Idarucizumabe', isEs ? '5 g IV (2 frascos de 2,5 g). Reversão completa e imediata.' : '5 g IV (2 frascos de 2,5 g). Reversão completa e imediata.', '🔴'],
      ['Organofosforados', 'Atropina + Pralidoxima', isEs ? 'Atropina 2–4 mg IV (titular pelos secretos). Pralidoxima 1–2 g IV em 30 min. Repetir atropina até secar secreções.' : 'Atropina 2–4 mg IV (titular pelos secretos). Pralidoxima 1–2 g IV em 30 min. Titular atropina até secar secreções.', '🔴'],
      ['Sulfato de Magnésio (tóxico)', 'Gluconato de Cálcio', isEs ? '1 g (10 mL de sol. 10%) IV lento em 3 min. Antagonismo fisiológico imediato.' : '1 g (10 mL sol. 10%) IV lento em 3 min. Antagonismo fisiológico imediato.', '🔴'],
      ['Metanol/Etilenoglicol', 'Fomepizole + Hemodiálise', isEs ? 'Fomepizol 15 mg/kg IV + hemodiálise urgente. Etanol 10% IV como alternativa.' : 'Fomepizol 15 mg/kg IV + hemodiálise urgente. Etanol 10% IV como alternativa.', '🔴'],
      ['Cianeto', 'Hidroxocobalamina', isEs ? '5 g IV em 15 min. Alternativa: Nitrito de amila (inalação) + Tiosulfato de sódio 12,5 g IV.' : '5 g IV em 15 min. Alternativa: Nitrito de amila (inalação) + Tiosulfato de sódio 12,5 g IV.', '🔴'],
      ['Monóxido de Carbono', 'O2 100% / Câmara Hiperbárica', isEs ? 'O2 100% máscara NRB até COHb <5%. Hiperbárica se: COHb >25%, gestante, inconsciente, cardíaco.' : 'O2 100% máscara NRB até COHb <5%. Câmara hiperbárica se: COHb >25%, gestante, coma, cardiopata.', '🔴'],
      ['Antidepressivos Tricíclicos', 'Bicarbonato de Sódio', isEs ? 'NaHCO3 1–2 mEq/kg IV se QRS >120ms. Meta: pH 7,45–7,55. Diazepam nas convulsões.' : 'NaHCO3 1–2 mEq/kg IV se QRS >120ms. Meta: pH 7,45–7,55. Diazepam nas convulsões.', '🔴'],
      ['Hiperpotassemia', 'Gluconato de Cálcio', isEs ? '1 g IV em 2 min (estabiliza membrana). Insulina 10 UI + Glicose 50% para shift intracelular.' : '1 g IV em 2 min (estabiliza membrana). Insulina 10 UI + Glicose 50% para shift intracelular.', '🔴'],
      ['Hipoglicemia', 'Glicose 50% IV / Glucagon', isEs ? 'Glicose 50%: 50 mL IV. Glucagon 1 mg IM/SC se sem acesso. SNG: suco de laranja.' : 'Glicose 50%: 50 mL IV. Glucagon 1 mg IM/SC se sem acesso. VO: suco de laranja/mel.', '🔴'],
      ['β-Bloqueadores (tóxico)', 'Glucagon + Emulsão Lipídica', isEs ? 'Glucagon 3–10 mg IV bolo + 3–10 mg/h infusão. Emulsão lipídica 20%: 1,5 mL/kg IV bolo.' : 'Glucagon 3–10 mg IV bolo + 3–10 mg/h infusão. Emulsão lipídica 20%: 1,5 mL/kg IV bolo.', '🟠'],
      ['Bloq. Canal de Cálcio (tóxico)', 'Cálcio IV + Insulina Alta Dose', isEs ? 'CaCl2 1–2 g IV. Insulina 1 UI/kg/h + Glicose. Emulsão lipídica 20% se refratário.' : 'CaCl2 1–2 g IV. Insulina 1 UI/kg/h + Glicose. Emulsão lipídica 20% se refratário.', '🟠'],
    ];

    return _SectionCard(
      title: isEs ? 'Antídotos Clínicos Essenciales' : 'Antídotos Clínicos Essenciais',
      icon: Icons.medical_services_rounded,
      child: Column(
        children: antidotes.map((row) => _AntidoteRow(
          toxin: row[0],
          antidote: row[1],
          dose: row[2],
          level: row[3],
        )).toList(),
      ),
    );
  }

  // ── ACESSO VASCULAR ───────────────────────────────────────────────
  Widget _buildAccess(bool isEs) {
    return Column(children: [
      _SectionCard(
        title: isEs ? 'Catéter Venoso Central — Localización' : 'Acesso Venoso Central — Localização',
        icon: Icons.hub_rounded,
        child: Column(children: [
          _AccessRow(
            site: isEs ? 'Jugular Interna D' : 'Jugular Interna D',
            pros: isEs ? 'Fácil, baixo PTX, pulmão D maior' : 'Fácil, baixo PTX, pulmão D maior',
            cons: isEs ? 'Artéria carótida próxima' : 'Artéria carótida próxima',
          ),
          _AccessRow(
            site: isEs ? 'Subclávio' : 'Subclávio',
            pros: isEs ? 'Confortável, baixa infecção' : 'Confortável, baixa infecção',
            cons: isEs ? 'Alto risco PTX, hemotórax' : 'Alto risco PTX, hemotórax',
          ),
          _AccessRow(
            site: 'Femoral',
            pros: isEs ? 'Fácil, rápido, sem PTX' : 'Fácil, rápido, sem PTX',
            cons: isEs ? 'Alta infecção, TVP, não ideal PCR' : 'Alta infecção, TVP, não ideal PCR',
          ),
          const SizedBox(height: 8),
          _InfoNote(text: isEs
            ? '📍 Confirmar posição com Rx tórax antes de usar. Ponta ideal: junção cava superior-átrio direito. Eco point-of-care facilita.'
            : '📍 Confirmar posição com Rx tórax antes de usar. Ponta ideal: junção cava superior-átrio direito. Eco point-of-care facilita.'),
        ]),
      ),
      _SectionCard(
        title: isEs ? 'Tamaño de Catéter por Situación' : 'Calibre de Cateter por Situação',
        icon: Icons.linear_scale_rounded,
        child: Column(children: [
          _LabRow(name: isEs ? 'Ressuscitação' : 'Ressuscitação', ref: '14–16 G periférico', note: isEs ? '2 acessos curtos e grossos > 1 central' : '2 acessos curtos e grossos > 1 central'),
          _LabRow(name: isEs ? 'Vasopressor' : 'Vasopressor', ref: 'CVC (3 lumens)', note: isEs ? 'Prefetir subclávia/jugular interna' : 'Preferir subclávia/jugular interna'),
          _LabRow(name: isEs ? 'Transfusão rápida' : 'Transfusão rápida', ref: '14–16 G + introdutor 8,5Fr', note: isEs ? 'Introdutor = fluxo máximo' : 'Introdutor = maior fluxo'),
          _LabRow(name: isEs ? 'Nutrição parenteral' : 'Nutrição parenteral', ref: 'PICC ou CVC', note: isEs ? 'Osmolaridade > 900 mOsm = central' : 'Osmolaridade > 900 mOsm = central'),
          _LabRow(name: isEs ? 'Hemodiálise' : 'Hemodiálise', ref: 'Cateter duplo-lúmen 11–13Fr', note: isEs ? 'Jugular D > femoral > subclávia' : 'Jugular D > femoral > subclávia'),
        ]),
      ),
      _SectionCard(
        title: isEs ? 'Presiones de Referencia — Invasivo' : 'Pressões de Referência — Invasivo',
        icon: Icons.speed_rounded,
        child: Column(children: [
          _LabRow(name: 'PAM', ref: '70–105 mmHg', note: isEs ? 'Meta ≥65 no choque' : 'Meta ≥65 no choque'),
          _LabRow(name: 'PVC', ref: '2–8 mmHg', note: isEs ? 'Isolado pouco confiável' : 'Isolado pouco confiável'),
          _LabRow(name: 'PCP (wedge)', ref: '6–12 mmHg', note: isEs ? '>18 = sobrecarga; <6 = hipovolemia' : '>18 = sobrecarga; <6 = hipovolemia'),
          _LabRow(name: 'DC', ref: '4–8 L/min', note: 'IC: 2,5–4,0 L/min/m²'),
          _LabRow(name: 'RVSP', ref: '<30 mmHg', note: isEs ? '>35 = hipertensão pulmonar' : '>35 = hipertensão pulmonar'),
          _LabRow(name: 'SvO2', ref: '65–75%', note: isEs ? '<65% = extração aumentada (baixo DC)' : '<65% = extração aumentada (baixo DC)'),
        ]),
      ),
    ]);
  }

  // ── GASOMETRIA ────────────────────────────────────────────────────
  Widget _buildGasometry(bool isEs) {
    return Column(children: [
      _SectionCard(
        title: isEs ? 'Valores Normales — GAS Arterial' : 'Valores Normais — GAS Arterial',
        icon: Icons.air_rounded,
        child: Column(children: [
          _LabRow(name: 'pH', ref: '7,35–7,45', note: '<7,35=acidose; >7,45=alcalose'),
          _LabRow(name: 'PaCO2', ref: '35–45 mmHg', note: isEs ? '<35=alcalose resp; >45=acidose resp' : '<35=alcalose resp; >45=acidose resp'),
          _LabRow(name: 'PaO2', ref: '80–100 mmHg', note: isEs ? '<80 hipoxemia (ar ambiente)' : '<80 hipoxemia (ar ambiente)'),
          _LabRow(name: 'HCO3', ref: '22–26 mEq/L', note: isEs ? '<22=acidose met; >26=alcalose met' : '<22=acidose met; >26=alcalose met'),
          _LabRow(name: 'BE', ref: '-2 a +2 mEq/L', note: '<-2=déficit base; >+2=excesso base'),
          _LabRow(name: 'SpO2', ref: '95–100%', note: '<90% = hipoxemia clínica'),
          _LabRow(name: 'PaO2/FiO2', ref: '>400', note: '<300=SRAG leve; <200=moderado; <100=grave'),
          _LabRow(name: 'Lactato', ref: '<2 mmol/L', note: isEs ? '>2=hipoperfusão; >4=choque metabólico' : '>2=hipoperfusão; >4=choque metabólico'),
        ]),
      ),
      _SectionCard(
        title: isEs ? 'Algoritmo de Gasometría (4 pasos)' : 'Algoritmo de Gasometria (4 passos)',
        icon: Icons.account_tree_rounded,
        child: Column(children: [
          _StepRow(step: '1', title: isEs ? 'pH: ácido (<7,35) ou alcalino (>7,45)?' : 'pH: ácido (<7,35) ou alcalino (>7,45)?', sub: ''),
          _StepRow(step: '2', title: isEs ? 'Distúrbio primário: PaCO2 ou HCO3?' : 'Distúrbio primário: PaCO2 ou HCO3?',
            sub: isEs ? 'pH↓+PaCO2↑=acid.resp | pH↓+HCO3↓=acid.met\npH↑+PaCO2↓=alc.resp | pH↑+HCO3↑=alc.met' : 'pH↓+PaCO2↑=acid.resp | pH↓+HCO3↓=acid.met\npH↑+PaCO2↓=alc.resp | pH↑+HCO3↑=alc.met'),
          _StepRow(step: '3', title: isEs ? 'Compensação adequada?' : 'Compensação adequada?',
            sub: isEs
              ? 'Acid.met: PaCO2 = 1,5×HCO3 + 8 ±2 (Winter)\nAlc.met: PaCO2 aumenta 0,7 por cada 1 mEq/L HCO3\nAcid.resp aguda: HCO3 sobe 1 por cada 10 mmHg PaCO2\nAcid.resp crônica: HCO3 sobe 3,5 por cada 10 mmHg'
              : 'Acid.met: PaCO2 = 1,5×HCO3 + 8 ±2 (Winter)\nAlc.met: PaCO2 ↑ 0,7 por cada 1 mEq/L HCO3\nAcid.resp aguda: HCO3 ↑ 1 por cada 10 mmHg PaCO2\nAcid.resp crônica: HCO3 ↑ 3,5 por cada 10 mmHg'),
          _StepRow(step: '4', title: isEs ? 'Anion Gap (se acidose met)' : 'Anion Gap (se acidose met)',
            sub: isEs ? 'AG = Na – (Cl + HCO3). Normal: 8–12. >12 = AG elevado (MUDPILES).\nMUDPILES: Metanol, Uremia, DKA, Propileno, Isoniazida, Lactato, Etilenoglicol, Salicilato' : 'AG = Na – (Cl + HCO3). Normal: 8–12. >12 = AG elevado (MUDPILES).\nMUDPILES: Metanol, Uremia, CAD, Propileno, Isoniazida, Lactato, Etilenoglicol, Salicilato'),
        ]),
      ),
      _SectionCard(
        title: isEs ? 'Causas de Hipoxemia' : 'Causas de Hipoxemia',
        icon: Icons.help_outline_rounded,
        child: Column(children: [
          _LabRow(name: 'Hipoventilação', ref: isEs ? 'PaCO2 ↑, A-a normal' : 'PaCO2 ↑, A-a normal', note: isEs ? 'BNZ, opioides, miastenia' : 'BZD, opioides, miastenia'),
          _LabRow(name: 'V/Q mismatch', ref: 'A-a ↑, responde a O2', note: isEs ? 'DPOC, asma, TEP' : 'DPOC, asma, TEP'),
          _LabRow(name: 'Shunt', ref: 'A-a ↑, NÃO responde a O2', note: isEs ? 'SARA, pneumonia lobar, atelectasia' : 'SARA, pneumonia lobar, atelectasia'),
          _LabRow(name: isEs ? 'Difusión' : 'Difusão', ref: 'A-a ↑, responde a O2', note: isEs ? 'Fibrose pulmonar' : 'Fibrose pulmonar'),
          const SizedBox(height: 4),
          _InfoNote(text: isEs
            ? '⚗️ Gradiente A-a = PAO2 – PaO2. PAO2 = FiO2×(Patm–PH2O) – PaCO2/0,8. Normal: <10 jovem; <25 idoso.'
            : '⚗️ Gradiente A-a = PAO2 – PaO2. PAO2 = FiO2×(Patm–PH2O) – PaCO2/0,8. Normal: <10 jovem; <25 idoso.'),
        ]),
      ),
    ]);
  }
}

// ── Widgets auxiliares da aba Referência ─────────────────────────
class _LabRow extends StatelessWidget {
  final String name, ref, note;
  const _LabRow({required this.name, required this.ref, required this.note});

  @override
  Widget build(BuildContext context) {
    final isAlert = note.contains('<') || note.contains('>') || note.contains('=') || note.contains('↑') || note.contains('↓');
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110,
          child: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kToolDark))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ref, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
          if (note.isNotEmpty)
            Text(note, style: TextStyle(fontSize: 10, color: isAlert ? const Color(0xFFB45309) : const Color(0xFF666666), height: 1.3)),
        ])),
      ]),
    );
  }
}

class _EcgPattern extends StatelessWidget {
  final String pattern, desc;
  final Color color;
  const _EcgPattern({required this.pattern, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pattern, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF444444), height: 1.4)),
        ]),
      ),
    );
  }
}

class _AntidoteRow extends StatelessWidget {
  final String toxin, antidote, dose, level;
  const _AntidoteRow({required this.toxin, required this.antidote, required this.dose, required this.level});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF8F8F8),
          border: Border.all(color: kToolBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(level, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(child: Text(toxin, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kToolDark))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF075f45).withValues(alpha: 0.12)),
              child: Text(antidote, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF075f45))),
            ),
          ]),
          const SizedBox(height: 5),
          Text(dose, style: const TextStyle(fontSize: 11, color: Color(0xFF555555), height: 1.4)),
        ]),
      ),
    );
  }
}

class _AccessRow extends StatelessWidget {
  final String site, pros, cons;
  const _AccessRow({required this.site, required this.pros, required this.cons});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kToolBorder))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(site, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kToolDark)),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('✅ ', style: TextStyle(fontSize: 11)),
              Expanded(child: Text(pros, style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.3))),
            ])),
            const SizedBox(width: 8),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('⚠️ ', style: TextStyle(fontSize: 11)),
              Expanded(child: Text(cons, style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.3))),
            ])),
          ]),
        ]),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step, title, sub;
  const _StepRow({required this.step, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26, height: 26,
          decoration: const BoxDecoration(color: kToolDark, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(step, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kToolGold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kToolDark)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 10.5, color: Color(0xFF555555), height: 1.5, fontFamily: 'monospace')),
          ],
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 7 — PRESCRIÇÕES-MODELO DE PLANTÃO
// ══════════════════════════════════════════════════════════════════
class _PrescriptionsTab extends StatefulWidget {
  @override
  State<_PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends State<_PrescriptionsTab> {
  int _cat = 0;
  final _categories = [
    'DOR/FEBRE', 'NÁUSEA', 'INFECÇÃO', 'HAS', 'HipoK+',
    'SEDAÇÃO', 'SEPSE', 'COAGULAÇÃO', 'ANTI-HAS GRAVE', 'DISPNEIA',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    return Column(children: [
      Container(
        color: const Color(0xFF0A1A10),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_categories.length, (i) {
              final active = _cat == i;
              return GestureDetector(
                onTap: () => setState(() => _cat = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active ? const Color(0xFFC5A365) : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: active ? const Color(0xFFC5A365) : Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(_categories[i],
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: active ? const Color(0xFF07110d) : Colors.white60, letterSpacing: 0.5)),
                ),
              );
            }),
          ),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: _buildPrescription(isEs),
        ),
      ),
    ]);
  }

  Widget _buildPrescription(bool isEs) {
    switch (_cat) {
      case 0: return _buildPainFever(isEs);
      case 1: return _buildNausea(isEs);
      case 2: return _buildInfection(isEs);
      case 3: return _buildHAS(isEs);
      case 4: return _buildHypoK(isEs);
      case 5: return _buildSedation(isEs);
      case 6: return _buildSepsis(isEs);
      case 7: return _buildCoagulation(isEs);
      case 8: return _buildHypertensiveEmergency(isEs);
      case 9: return _buildDyspnea(isEs);
      default: return const SizedBox();
    }
  }

  Widget _buildPainFever(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Dolor Leve–Moderado (Adulto)' : 'Dor Leve–Moderada (Adulto)',
        level: '🟡',
        items: [
          _PrescItem('1.', isEs ? 'Paracetamol 1 g VO/IV 6/6h (máx. 4 g/dia). Preferir para febre e dor leve.' : 'Paracetamol 1 g VO/IV 6/6h (máx. 4 g/dia). Preferir para febre e dor leve.'),
          _PrescItem('2.', isEs ? 'SE necessário: Ibuprofeno 400–600 mg 8/8h VO (com alimento). Evitar em IR, úlcera, ICC.' : 'SE necessário: Ibuprofeno 400–600 mg 8/8h VO (com alimento). Evitar IR, úlcera, ICC.'),
          _PrescItem('3.', isEs ? 'Dipirona 1 g VO/IV 6/6h (IV lento ≥15 min). Alternativa eficaz.' : 'Dipirona 1 g VO/IV 6/6h (IV lento ≥15 min). Alternativa eficaz.'),
          _PrescItem('⚠️', isEs ? 'Não combinar dois AINEs. Evitar em gestante, IR grave, plaquetopenia.' : 'Não combinar dois AINEs. Evitar em gestante, IR grave, plaquetopenia.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Dolor Moderado–Severo' : 'Dor Moderada–Grave',
        level: '🔴',
        items: [
          _PrescItem('1.', isEs ? 'Tramadol 50–100 mg VO 8/8h (ou IV lento em 100 mL SF). Máx. 400 mg/dia.' : 'Tramadol 50–100 mg VO 8/8h (ou IV lento em 100 mL SF). Máx. 400 mg/dia.'),
          _PrescItem('2.', isEs ? 'Morfina 2–5 mg IV lento a cada 4h. Titular pela dor (EV ou PO). Cuidado: depressão respiratória.' : 'Morfina 2–5 mg IV lento a cada 4h. Titular pela dor (EV ou PO). Cuidado: depressão resp.'),
          _PrescItem('3.', isEs ? 'Cetorolaco 30 mg IV/IM 8/8h (máx. 5 dias). Excelente para cólica renal.' : 'Cetorolaco 30 mg IV/IM 8/8h (máx. 5 dias). Excelente para cólica renal.'),
          _PrescItem('⚠️', isEs ? 'Naloxona 0,4 mg IV disponível. Monitorar SpO2 contínua com opioides IV.' : 'Naloxona 0,4 mg IV disponível. Monitorar SpO2 contínua com opioides IV.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Fiebre (T >38,3°C)' : 'Febre (T >38,3°C)',
        level: '🟡',
        items: [
          _PrescItem('1.', isEs ? 'Paracetamol 750 mg–1 g VO/IV 6/6h. Primeira escolha — seguro e eficaz.' : 'Paracetamol 750 mg–1 g VO/IV 6/6h. Primeira escolha — seguro e eficaz.'),
          _PrescItem('2.', isEs ? 'Dipirona 1 g IV 6/6h (lento) se febre persistente ou mal-tolerada.' : 'Dipirona 1 g IV 6/6h (lento) se febre persistente ou mal-tolerada.'),
          _PrescItem('3.', isEs ? 'Compressa morna se T > 40°C e paciente confortável.' : 'Compressa morna se T >40°C e paciente confortável.'),
          _PrescItem('⚠️', isEs ? 'Investigar CAUSA — não tratar febre isoladamente sem colher culturas.' : 'Investigar CAUSA — não tratar febre isoladamente sem colher culturas.'),
        ],
      ),
    ]);
  }

  Widget _buildNausea(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Náuseas y Vómitos — 1ª Línea' : 'Náuseas e Vômitos — 1ª Linha',
        level: '🟡',
        items: [
          _PrescItem('1.', isEs ? 'Ondansetrona 4–8 mg IV lento (2–5 min) 8/8h. Primeira escolha — menos sedação.' : 'Ondansetrona 4–8 mg IV lento (2–5 min) 8/8h. Primeira escolha — menos sedação.'),
          _PrescItem('2.', isEs ? 'Metoclopramida 10 mg IV 8/8h (lento em 50 mL SF, 15 min). Útil se dismotilidade gástrica.' : 'Metoclopramida 10 mg IV 8/8h (lento em 50 mL SF, 15 min). Útil se dismotilidade gástrica.'),
          _PrescItem('3.', isEs ? 'Dimenidrinato 50 mg IV/VO 8/8h se náusea vestibular.' : 'Dimenidrinato 50 mg IV/VO 8/8h se náusea vestibular.'),
          _PrescItem('⚠️', isEs ? 'Metoclopramida: evitar em parkinsonismo. Ondansetrona: monitorar QT.' : 'Metoclopramida: evitar em parkinsonismo. Ondansetrona: monitorar QT.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Vómitos Incoercibles / Quimioterapia' : 'Vômitos Incoercíveis / Quimioterapia',
        level: '🔴',
        items: [
          _PrescItem('1.', isEs ? 'Ondansetrona 8 mg IV 8/8h + Dexametasona 8 mg IV 12/12h.' : 'Ondansetrona 8 mg IV 8/8h + Dexametasona 8 mg IV 12/12h.'),
          _PrescItem('2.', isEs ? 'Aprepitanto 125 mg D1 + 80 mg D2-D3 (se disponível — antagonista NK1).' : 'Aprepitanto 125 mg D1 + 80 mg D2-D3 (se disponível — antagonista NK1).'),
          _PrescItem('3.', isEs ? 'Hidratação IV se ingestão oral comprometida.' : 'Hidratação IV se ingestão oral comprometida.'),
        ],
      ),
    ]);
  }

  Widget _buildInfection(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'ITU no Complicada (ambulatorio)' : 'ITU não Complicada (ambulatorial)',
        level: '🟡',
        items: [
          _PrescItem('1.ª opção', isEs ? 'Nitrofurantoína 100 mg VO 12/12h × 5 dias (não usar em IR: ClCr <45).' : 'Nitrofurantoína 100 mg VO 12/12h × 5 dias (não usar em IR: ClCr <45).'),
          _PrescItem('2.ª opção', isEs ? 'Fosfomicina 3 g VO dose única (cistite simples).' : 'Fosfomicina 3 g VO dose única (cistite simples).'),
          _PrescItem('3.ª opção', isEs ? 'Ciprofloxacino 500 mg VO 12/12h × 3 dias (reservar quinolonas).' : 'Ciprofloxacino 500 mg VO 12/12h × 3 dias (reservar quinolonas).'),
          _PrescItem('⚠️', isEs ? 'Amoxicilina isolada: alta resistência (>30%). Evitar sem antibiograma.' : 'Amoxicilina isolada: alta resistência (>30%). Evitar sem antibiograma.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'ITU Complicada / Pielonefritis' : 'ITU Complicada / Pielonefrite',
        level: '🔴',
        items: [
          _PrescItem('Internado IV', isEs ? 'Ceftriaxona 1–2 g IV/dia ou Ciprofloxacino 400 mg IV 12/12h.' : 'Ceftriaxona 1–2 g IV/dia ou Ciprofloxacino 400 mg IV 12/12h.'),
          _PrescItem('Ambulatorial', isEs ? 'Ciprofloxacino 500 mg VO 12/12h × 7 dias (pielonefrite leve).' : 'Ciprofloxacino 500 mg VO 12/12h × 7 dias (pielonefrite leve).'),
          _PrescItem('Cultura+', isEs ? 'Aguardar antibiograma e desescalar em 48–72h.' : 'Aguardar antibiograma e desescalar em 48–72h.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'PAC Leve–Moderada (ambulatorio)' : 'PAC Leve–Moderada (ambulatorial)',
        level: '🟡',
        items: [
          _PrescItem('Sem comorbidade', isEs ? 'Amoxicilina 1 g VO 8/8h × 5 dias (pneumococo — 1ª opção).' : 'Amoxicilina 1 g VO 8/8h × 5 dias (pneumococo — 1ª opção).'),
          _PrescItem('Atípico suspeito', isEs ? 'Azitromicina 500 mg/dia × 5 dias OU Doxiciclina 100 mg 12/12h × 7 dias.' : 'Azitromicina 500 mg/dia × 5 dias OU Doxiciclina 100 mg 12/12h × 7 dias.'),
          _PrescItem('Com comorbidade', isEs ? 'Amox+Clav 875/125 mg 12/12h + Azitromicina × 7 dias.' : 'Amox+Clav 875/125 mg 12/12h + Azitromicina × 7 dias.'),
          _PrescItem('⚠️', isEs ? 'CURB-65 ≥2 = considerar internação. ≥3 = UTI avaliação.' : 'CURB-65 ≥2 = considerar internação. ≥3 = avaliar UTI.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Celulitis / Erisipela' : 'Celulite / Erisipela',
        level: '🟡',
        items: [
          _PrescItem('Leve VO', isEs ? 'Cefalexina 500 mg VO 6/6h × 5–7 dias (estafilococo/estreptococo).' : 'Cefalexina 500 mg VO 6/6h × 5–7 dias (estafilococo/estreptococo).'),
          _PrescItem('Moderada IV', isEs ? 'Oxacilina 2 g IV 4/4h ou Cefazolina 2 g IV 8/8h.' : 'Oxacilina 2 g IV 4/4h ou Cefazolina 2 g IV 8/8h.'),
          _PrescItem('MRSA suspeito', isEs ? 'Vancomicina 15–20 mg/kg IV 12/12h.' : 'Vancomicina 15–20 mg/kg IV 12/12h.'),
        ],
      ),
    ]);
  }

  Widget _buildHAS(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'HAS Estágio 1–2 (ambulatorio)' : 'HAS Estágio 1–2 (ambulatorial)',
        level: '🟡',
        items: [
          _PrescItem('1.ª linha', isEs ? 'Anlodipino 5 mg VO 1×/dia (pode titular para 10 mg).' : 'Anlodipino 5 mg VO 1×/dia (pode titular para 10 mg).'),
          _PrescItem('Ou', isEs ? 'Losartana 50 mg VO 1×/dia (titular para 100 mg). Preferir em DM/proteinúria.' : 'Losartana 50 mg VO 1×/dia (titular para 100 mg). Preferir em DM/proteinúria.'),
          _PrescItem('Ou', isEs ? 'Enalapril 5–10 mg VO 12/12h. Monitorar K+ e creatinina.' : 'Enalapril 5–10 mg VO 12/12h. Monitorar K+ e creatinina.'),
          _PrescItem('Combinação', isEs ? 'Anlodipino + Losartana se PA não controlada com monoterapia em 4 semanas.' : 'Anlodipino + Losartana se PA não controlada com monoterapia em 4 semanas.'),
          _PrescItem('⚠️', isEs ? 'IECA/ARA2: contraindicados na gravidez. Monitorar K+ com poupadores.' : 'IECA/ARA2: contraindicados na gravidez. Monitorar K+ com poupadores.'),
        ],
      ),
    ]);
  }

  Widget _buildHypoK(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Hipopotasemia — Reposición' : 'Hipopotassemia — Reposição',
        level: '🔴',
        items: [
          _PrescItem('K+ 3,0–3,5', isEs ? 'KCl 40 mEq VO (frutas, sal light) ou KCl oral 40 mEq fracionado.' : 'KCl 40 mEq VO (frutas, sal light) ou KCl oral 40 mEq fracionado.'),
          _PrescItem('K+ 2,5–3,0', isEs ? 'KCl 40–60 mEq em 500 mL SF IV em 4–6h (taxa máx. 10 mEq/h periférica).' : 'KCl 40–60 mEq em 500 mL SF IV em 4–6h (taxa máx. 10 mEq/h periférica).'),
          _PrescItem('K+ <2,5/ECG alt.', isEs ? 'KCl até 20–40 mEq/h em via central com monitorização ECG contínua.' : 'KCl até 20–40 mEq/h em via central com monitorização ECG contínua.'),
          _PrescItem('⚠️', isEs ? 'NUNCA KCl IV direto (bolus). Sempre diluído. Verificar e repor Mg2+ junto (hipoMg perpetua hipoK).' : 'NUNCA KCl IV direto (bolus). Sempre diluído. Repor Mg2+ junto (hipoMg perpetua hipoK).'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Hipomagnesemia' : 'Hipomagnesemia',
        level: '🟡',
        items: [
          _PrescItem('Reposição IV', isEs ? 'MgSO4 2 g IV em 100 mL SF em 15–20 min. Repetir se Mg <1,5 mg/dL.' : 'MgSO4 2 g IV em 100 mL SF em 15–20 min. Repetir se Mg <1,5 mg/dL.'),
          _PrescItem('Manutenção VO', isEs ? 'Óxido de Magnésio 400 mg VO 1–2×/dia.' : 'Óxido de Magnésio 400 mg VO 1–2×/dia.'),
          _PrescItem('⚠️', isEs ? 'Hipomagnesemia: causa comum de hipocalemia e hipocalcemia refratária.' : 'Hipomagnesemia: causa comum de hipocalemia e hipocalcemia refratária.'),
        ],
      ),
    ]);
  }

  Widget _buildSedation(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Sedación/Analgesia en UTI (PADIS 2018)' : 'Sedação/Analgesia em UTI (PADIS 2018)',
        level: '🔴',
        items: [
          _PrescItem('1. Analgesia', isEs ? 'Analgesia-PRIMEIRO: Fentanil 25–50 mcg IV PRN ou Morfina 2–4 mg IV PRN.' : 'Analgesia-PRIMEIRO: Fentanil 25–50 mcg IV PRN ou Morfina 2–4 mg IV PRN.'),
          _PrescItem('2. Sedação leve', isEs ? 'Meta RASS -1 a 0. Propofol 0,5–3 mg/kg/h IV OU Dexmedetomidina 0,2–1,5 mcg/kg/h.' : 'Meta RASS -1 a 0. Propofol 0,5–3 mg/kg/h IV OU Dexmedetomidina 0,2–1,5 mcg/kg/h.'),
          _PrescItem('3. Delirium', isEs ? 'Haloperidol 0,25–0,5 mg IV 8/8h se agitação. Orientação + luz + mobilização precoce.' : 'Haloperidol 0,25–0,5 mg IV 8/8h se agitação. Orientação + luz + mobilização precoce.'),
          _PrescItem('Sedação profunda', isEs ? 'Midazolam 0,02–0,1 mg/kg/h + Fentanil 25–100 mcg/h (IOT/SARA/status).' : 'Midazolam 0,02–0,1 mg/kg/h + Fentanil 25–100 mcg/h (IOT/SARA/status).'),
          _PrescItem('⚠️', isEs ? 'Interrupção diária da sedação ("sedation vacation"). Avaliar RASS 4×/dia.' : 'Interrupção diária da sedação ("sedation vacation"). Avaliar RASS 4×/dia.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Escalas RASS / BPS (referencia)' : 'Escalas RASS / BPS (referência)',
        level: '🟡',
        items: [
          _PrescItem('RASS', isEs ? '+4=combativo; +1=agitado; 0=alerta; -1=sonolento; -3=moderado; -5=não responsivo.' : '+4=combativo; +1=agitado; 0=alerta; -1=sonolento; -3=moderado; -5=não responsivo.'),
          _PrescItem('BPS', isEs ? '3=sem dor; 12=dor máxima. Avaliação: expressão facial + membro + ventilação.' : '3=sem dor; 12=dor máxima. Avaliação: expressão facial + membro + ventilação.'),
          _PrescItem('CAM-ICU', isEs ? 'Avalia delirium em ventilado: 1)início agudo+flutuação, 2)desatenção, 3)consciência alt ou pensamento desorganizado.' : 'Avalia delirium em ventilado: 1)início agudo+flutuação, 2)desatenção, 3)consciência alt. ou pensamento desorganizado.'),
        ],
      ),
    ]);
  }

  Widget _buildSepsis(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Bundle de Sepsis — HORA 1 (SSC 2021)' : 'Bundle de Sepse — HORA 1 (SSC 2021)',
        level: '🔴',
        items: [
          _PrescItem('✅ 1.', isEs ? 'Medir lactato (repetir se >2 mmol/L).' : 'Medir lactato (repetir se >2 mmol/L).'),
          _PrescItem('✅ 2.', isEs ? 'Hemocultura 2× ANTES do antibiótico.' : 'Hemocultura 2× ANTES do antibiótico.'),
          _PrescItem('✅ 3.', isEs ? 'Antibiótico de amplo espectro em <1h.' : 'Antibiótico de amplo espectro em <1h.'),
          _PrescItem('✅ 4.', isEs ? 'SF/RL 30 mL/kg IV em ≤3h se hipoperfusão.' : 'SF/RL 30 mL/kg IV em ≤3h se hipoperfusão.'),
          _PrescItem('✅ 5.', isEs ? 'Vasopressor se PAM <65 após volume: Noradrenalina 0,1–1 µg/kg/min.' : 'Vasopressor se PAM <65 após volume: Noradrenalina 0,1–1 µg/kg/min.'),
          _PrescItem('ATB empírico', isEs ? 'Pip-Tazo 4,5g IV 6/6h + Vancomicina 25 mg/kg IV (1ª dose, com infusão 1–2h).' : 'Pip-Tazo 4,5g IV 6/6h + Vancomicina 25 mg/kg IV (1ª dose, infusão 1–2h).'),
          _PrescItem('⚠️', isEs ? 'Desescalar em 48–72h com cultura. Avaliar foco cirúrgico.' : 'Desescalar em 48–72h com cultura. Avaliar foco cirúrgico.'),
        ],
      ),
    ]);
  }

  Widget _buildCoagulation(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Profilaxis de TVP / TEP' : 'Profilaxia de TVP / TEP',
        level: '🟡',
        items: [
          _PrescItem('Internados ClCr>30', isEs ? 'Enoxaparina 40 mg SC 1×/dia.' : 'Enoxaparina 40 mg SC 1×/dia.'),
          _PrescItem('Obesos >100 kg', isEs ? 'Enoxaparina 40 mg SC 12/12h ou 0,5 mg/kg/dia.' : 'Enoxaparina 40 mg SC 12/12h ou 0,5 mg/kg/dia.'),
          _PrescItem('ClCr <30', isEs ? 'HNF 5000 UI SC 8/8h (preferir em IR grave).' : 'HNF 5000 UI SC 8/8h (preferir em IR grave).'),
          _PrescItem('⚠️', isEs ? 'Contraindicada: sangramento ativo, plaquetas <50k, cirurgia SNC recente.' : 'Contraindicada: sangramento ativo, plaquetas <50k, cirurgia SNC recente.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Anticoagulación FA (inicio)' : 'Anticoagulação FA (início)',
        level: '🟡',
        items: [
          _PrescItem('CHA2DS2 ≥2 (H) / ≥3 (M)', isEs ? 'Indicação formal de anticoagulação.' : 'Indicação formal de anticoagulação.'),
          _PrescItem('1.ª opção', isEs ? 'Rivaroxabana 20 mg 1×/dia (com jantar). ClCr 15–49: 15 mg/dia.' : 'Rivaroxabana 20 mg 1×/dia (com jantar). ClCr 15–49: 15 mg/dia.'),
          _PrescItem('Alternativa', isEs ? 'Apixabana 5 mg 12/12h. Reduzir para 2,5 mg se ≥2: idade≥80/peso≤60/Cr≥1,5.' : 'Apixabana 5 mg 12/12h. Reduzir para 2,5 mg se ≥2: idade≥80/peso≤60/Cr≥1,5.'),
          _PrescItem('Valvar/mecânica', isEs ? 'Warfarina (alvo INR 2–3 ou 2,5–3,5 mecânica). DOAC contraindicado.' : 'Warfarina (alvo INR 2–3 ou 2,5–3,5 mecânica). DOAC contraindicado.'),
        ],
      ),
    ]);
  }

  Widget _buildHypertensiveEmergency(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Emergencia Hipertensiva — UTI' : 'Emergência Hipertensiva — UTI',
        level: '🔴',
        items: [
          _PrescItem('Meta geral', isEs ? 'Reduzir PAM 20–25% nas primeiras 1–2h. NÃO normalizar abruptamente.' : 'Reduzir PAM 20–25% nas primeiras 1–2h. NÃO normalizar abruptamente.'),
          _PrescItem('EAP/encef.', isEs ? 'Nitroprussiato 0,5–10 µg/kg/min IV (titular) OU Nicardipino 5–15 mg/h IV.' : 'Nitroprussiato 0,5–10 µg/kg/min IV (titular) OU Nicardipino 5–15 mg/h IV.'),
          _PrescItem('Disseção Ao.', isEs ? 'Esmolol 500 mcg/kg IV + 50–200 mcg/kg/min + Nitroprussiato. Meta PAS ≤120.' : 'Esmolol 500 mcg/kg IV + 50–200 mcg/kg/min + Nitroprussiato. Meta PAS ≤120.'),
          _PrescItem('Eclâmpsia', isEs ? 'Hidralazina 5–10 mg IV 20 min + MgSO4 4–6 g IV (ver protocolo pré-ecl.).' : 'Hidralazina 5–10 mg IV 20 min + MgSO4 4–6 g IV (ver protocolo pré-ecl.).'),
          _PrescItem('⛔', isEs ? 'NUNCA nifedipino sublingual — queda abrupta e imprevisível → isquemia.' : 'NUNCA nifedipino sublingual — queda abrupta e imprevisível → isquemia.'),
        ],
      ),
    ]);
  }

  Widget _buildDyspnea(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Dispnea Aguda — Algoritmo Rápido' : 'Dispneia Aguda — Algoritmo Rápido',
        level: '🔴',
        items: [
          _PrescItem('ABCDE', isEs ? 'Posição sentada, O2 por máscara (Venturi 35–50% se DPOC: máx. SpO2 88–92%).' : 'Posição sentada, O2 por máscara (Venturi 35–50% se DPOC: máx. SpO2 88–92%).'),
          _PrescItem('EAP', isEs ? 'Furosemida 40–80 mg IV + NTG 5–10 µg/min IV + VNI (CPAP ≥5 cmH2O).' : 'Furosemida 40–80 mg IV + NTG 5–10 µg/min IV + VNI (CPAP ≥5 cmH2O).'),
          _PrescItem('Broncoespasmo', isEs ? 'Salbutamol 2,5 mg NEB a cada 20 min × 3 + Ipratrópio 0,5 mg NEB + MgSO4 2g IV.' : 'Salbutamol 2,5 mg NEB a cada 20 min × 3 + Ipratrópio 0,5 mg NEB + MgSO4 2g IV.'),
          _PrescItem('DPOC exacerb.', isEs ? 'Broncodilatadores + Prednisona 40 mg/dia × 5d + ATB (azitro/amox-clav) se infecção.' : 'Broncodilatadores + Prednisona 40 mg/dia × 5d + ATB (azitro/amox-clav) se infecção.'),
          _PrescItem('TEP', isEs ? 'Anticoagulação imediata (enoxaparina ou rivaroxabana). Trombólise se instável.' : 'Anticoagulação imediata (enoxaparina ou rivaroxabana). Trombólise se instável.'),
          _PrescItem('⚠️', isEs ? 'O2 alvo: SpO2 94–98% (geral) OU 88–92% (DPOC/hipoxemia crônica).' : 'O2 alvo: SpO2 94–98% (geral) OU 88–92% (DPOC/hipoxemia crônica).'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'VNI — Indicaciones y Configuración' : 'VNI — Indicações e Configuração',
        level: '🟡',
        items: [
          _PrescItem('Indicações', isEs ? 'EAP cardiogênico, DPOC exacerbação, hipoxemia leve-mod (SpO2 <92% com O2 convencional).' : 'EAP cardiogênico, DPOC exacerbação, hipoxemia leve-mod (SpO2 <92% com O2 convencional).'),
          _PrescItem('Início CPAP', isEs ? 'CPAP 5–8 cmH2O + FiO2 40–60%. Reavaliação em 30–60 min.' : 'CPAP 5–8 cmH2O + FiO2 40–60%. Reavaliação em 30–60 min.'),
          _PrescItem('BiPAP', isEs ? 'IPAP 12–20 / EPAP 4–8 cmH2O. FR backup 12–16/min.' : 'IPAP 12–20 / EPAP 4–8 cmH2O. FR backup 12–16/min.'),
          _PrescItem('⛔ Contra', isEs ? 'Parada respiratória, incapacidade de proteger VA, vômitos, agitação severa, politrauma facial.' : 'Parada respiratória, incapacidade de proteger VA, vômitos, agitação severa, politrauma facial.'),
        ],
      ),
    ]);
  }
}

class _PrescCard extends StatelessWidget {
  final String title, level;
  final List<_PrescItem> items;
  const _PrescCard({required this.title, required this.level, required this.items});

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(level, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kToolDark, letterSpacing: -0.3))),
        ]),
        const SizedBox(height: 10),
        Divider(color: kToolBorder, height: 1),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              constraints: const BoxConstraints(minWidth: 56),
              child: Text(item.step,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF075f45))),
            ),
            Expanded(child: Text(item.desc,
              style: const TextStyle(fontSize: 12, color: Color(0xFF333333), height: 1.45))),
          ]),
        )),
      ]),
    );
  }
}

class _PrescItem {
  final String step, desc;
  const _PrescItem(this.step, this.desc);
}

// ══════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final String? badge;
  final Color? badgeColor;
  const _SectionCard({required this.title, required this.icon, required this.child, this.badge, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: kToolDark),
            child: Icon(icon, size: 16, color: kToolGold),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kToolDark, letterSpacing: -0.3))),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: badgeColor ?? kToolGreen),
              child: Text(badge!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
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
    final hasVal = value != null && value != '—';
    final noteColor = (note ?? '').contains('⛔') ? const Color(0xFFCC2222)
        : (note ?? '').contains('⚠') ? const Color(0xFFB45309)
        : (note ?? '').contains('↑') ? const Color(0xFFB45309)
        : const Color(0xFF065F46);
    return Container(
      width: full ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: hasVal ? const Color(0xFFECFDF5) : const Color(0xFFF8F8F8),
        border: Border.all(color: hasVal ? const Color(0xFFBBF7D0) : kToolBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF666666))),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: Text(value ?? '—',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
              color: hasVal ? kToolDark : const Color(0xFFCCCCCC), letterSpacing: -0.5))),
          if (unit != null && unit!.isNotEmpty && hasVal) ...[
            const SizedBox(width: 3),
            Padding(padding: const EdgeInsets.only(bottom: 2),
              child: Text(unit!, style: const TextStyle(fontSize: 10, color: Color(0xFF888888)))),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFFF8E7), border: Border.all(color: const Color(0xFFFFE0A0))),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7A5F00), height: 1.4)),
    );
  }
}

class _RenalGuideRow extends StatelessWidget {
  final String label, status;
  final bool ok, warn, danger;
  const _RenalGuideRow({required this.label, required this.status, this.ok = false, this.warn = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final bg      = danger ? const Color(0xFFFFF0F0) : warn ? const Color(0xFFFFF8E7) : ok ? const Color(0xFFECFDF5) : const Color(0xFFF8F8F8);
    final border  = danger ? const Color(0xFFFFCCCC) : warn ? const Color(0xFFFFE0A0) : ok ? const Color(0xFFBBF7D0) : kToolBorder;
    final txtColor= danger ? const Color(0xFFCC2222) : warn ? const Color(0xFFB45309) : ok ? const Color(0xFF065F46) : kToolDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: bg, border: Border.all(color: border)),
        child: Row(children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: txtColor))),
          const SizedBox(width: 8),
          Expanded(child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: txtColor, height: 1.3))),
        ]),
      ),
    );
  }
}

// Extension helpers
extension on double {
  double get sqrt => _sqrt(this);
}

double _sqrt(double x) {
  if (x <= 0) return 0;
  double g = x / 2;
  for (int i = 0; i < 50; i++) g = (g + x / g) / 2;
  return g;
}

double _pow(double base, num exp) {
  if (exp == 0) return 1;
  if (exp < 0) return 1 / _pow(base, -exp);
  double result = 1;
  double b = base;
  num e = exp;
  while (e >= 1) { result *= b; e--; }
  if (e > 0) result *= _powFrac(base, e);
  return result;
}

double _powFrac(double base, num frac) => _exp(frac * _ln(base));
double _ln(double x) { if (x <= 0) return double.negativeInfinity; double s = 0, b = (x-1)/(x+1); double t = b; for (int i=1; i<100; i+=2) { s += t/i; t *= b*b; } return 2*s; }
double _exp(double x) { double s = 1, t = 1; for (int i=1; i<100; i++) { t *= x/i; s += t; if (t.abs() < 1e-15) break; } return s; }
