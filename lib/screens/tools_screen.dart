import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../widgets/lab_exam_bottom_sheet.dart';

// ──────────────────────────────────────────────────────────────────
// COLOR CONSTANTS — alinhadas com common_widgets.dart
// ──────────────────────────────────────────────────────────────────
// kDark, kGold, kGoldLight, kGreen, kBorder importados de common_widgets
const kToolGreen  = Color(0xFF075f45);   // verde padrão do app (mesmo kGreen)
const kToolBorder = Color(0xFFE2E6EA);   // mesmo kBorder
// kToolDark removido — usar AppColors.of(context).textPrimary / .darkBtn
const kToolGold   = kGoldLight;         // alias para kGoldLight

class ToolsScreen extends StatefulWidget {
  final bool hideHeader;
  const ToolsScreen({super.key, this.hideHeader = false});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 8, vsync: this);
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
    // No desktop a sidebar substitui o shell AppBar → mantém o header próprio.
    // Em mobile/tablet o shell AppBar já está visível → oculta o header próprio
    // para evitar double-header (duas barras empilhadas).
    final bp = MedBreakpoints.of(context);
    final showHeader = widget.hideHeader ? false : bp.isDesktop;

    return Column(children: [
      // ── Header (visível apenas no desktop ou quando explicitamente solicitado)
      if (showHeader)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F1C14), Color(0xFF1B3D2A), Color(0xFF1F6B48)],
            ),
          ),
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
          ]),
        ),
      // ── TabBar (sempre visível) ──────────────────────────────────
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F1C14), Color(0xFF1B3D2A), Color(0xFF1F6B48)],
          ),
        ),
        child: TabBar(
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
            Tab(text: isEs ? 'PEDIATRÍA' : 'PEDIATRIA'),
          ],
        ),
      ),

      // ── Content ─────────────────────────────────────────────────
      // GestureDetector com behavior translucent: um tap em qualquer área
      // vazia (fora de TextField) fecha o teclado sem bloquear scroll nem
      // gestos internos (botões, seletores, swipe de tab).
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
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
              PediatricsTabContent(),
            ],
          ),
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
    if (v < 16) return 'ATENÇÃO: Desnutrição grave (<16)';
    if (v < 18.5) return '↓ Abaixo do peso';
    if (v < 25)   return '✓ Peso normal';
    if (v < 30)   return '↑ Sobrepeso';
    if (v < 35)   return '↑↑ Obesidade I';
    if (v < 40)   return '↑↑↑ Obesidade II';
    return 'Obesidade III (Mórbida)';
  }

  String _clcrLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d >= 90) return '✓ Normal (≥90)';
    if (d >= 60) return 'Leve (60–89)';
    if (d >= 30) return '⚠ Moderada (30–59)';
    if (d >= 15) return 'GRAVE (15–29)';
    return 'FALÊNCIA (<15)';
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _sexFem
                        ? Colors.pink.withValues(alpha: 0.4)
                        : const Color(0xFF1565C0).withValues(alpha: 0.3),
                  ),
                  color: _sexFem
                      ? Colors.pink.withValues(alpha: 0.05)
                      : const Color(0xFF1565C0).withValues(alpha: 0.04),
                ),
                child: Row(children: [
                  Icon(_sexFem ? Icons.female : Icons.male, size: 18,
                    color: _sexFem ? Colors.pink : const Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Text(_sexFem ? (isEs ? 'Femenino' : 'Feminino') : (isEs ? 'Masculino' : 'Masculino'),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.of(context).textPrimary)),
                  const Spacer(),
                  Text(isEs ? 'Toque para cambiar' : 'Toque para alternar',
                    style: TextStyle(fontSize: 10, color: AppColors.of(context).textHint)),
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
    return 'GRAVE (≤8) — considerar IOT';
  }

  String _sofaLabel(int s) {
    if (s == 0) return '✓ Mortalidade ~0%';
    if (s <= 6) return '⚠ Mortalidade ~2–4%';
    if (s <= 9) return '⚠ Mortalidade ~20%';
    if (s <= 12) return 'GRAVE — Mortalidade ~40%';
    return 'CRÍTICO — Mortalidade >80%';
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
    return 'GRAVE (≥3) — internação + avaliar UTI';
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
    if (s <= 6) return 'RISCO MÉDIO — médico urgente + monitorização contínua';
    return 'RISCO ALTO (≥7) — UTI ou semi-intensivo imediato';
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
    return 'ALTO RISCO — anticoagulação indicada';
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
    return 'ALTA PROBABILIDADE de TVP';
  }

  String _wpLabel(double s) {
    if (s < 2)  return '✓ TEP improvável (<2)';
    if (s <= 6) return '⚠ TEP moderado (2–6)';
    return 'TEP PROVÁVEL (>6)';
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
          color: value ? AppColors.of(context).textPrimary : AppColors.of(context).textSecondary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
            color: value ? kToolGreen.withValues(alpha: 0.15) : AppColors.of(context).surface),
          child: Text(points == points.roundToDouble() ? '+${points.toInt()}' : '${points > 0 ? "+" : ""}$points',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
              color: value ? kToolGreen : AppColors.of(context).textHint)),
        ),
      ]),
    ),
  );

  Widget _glasRow(String label, int value, int max, VoidCallback onDec, VoidCallback onInc) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary))),
      IconButton(icon: const Icon(Icons.remove_circle_outline), iconSize: 22, color: kToolGreen, onPressed: value > 1 ? onDec : null),
      Container(
        width: 36, alignment: Alignment.center,
        child: Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.of(context).textPrimary)),
      ),
      IconButton(icon: const Icon(Icons.add_circle_outline), iconSize: 22, color: kToolGreen, onPressed: value < max ? onInc : null),
      SizedBox(width: 30, child: Text('/$max', style: TextStyle(fontSize: 11, color: AppColors.of(context).textHint))),
    ]),
  );

  Widget _sofaDropRow(String label, int value, List<String> options, ValueChanged<int?> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: kToolBorder)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            isDense: true,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary))),
                Switch(
                  value: _news_supo2,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? kToolGreen : null,
                  ),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.of(context).textPrimary))),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _psiAgeCtrl,
                    keyboardType: TextInputType.number,
                    spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                    autocorrect: false,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.of(context).textPrimary),
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
            Text('COMORBIDADES (+pts)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.of(context).textHint)),
            const SizedBox(height: 6),
            _scoreRow(isEs ? 'Neoplasia activa (+30)' : 'Neoplasia ativa (+30)', _psi_neoplasm, () => setState(() => _psi_neoplasm = !_psi_neoplasm), points: 30),
            _scoreRow(isEs ? 'Hepatopatía crónica (+20)' : 'Hepatopatia crônica (+20)', _psi_liver, () => setState(() => _psi_liver = !_psi_liver), points: 20),
            _scoreRow(isEs ? 'ICC / cardiopatía (+10)' : 'ICC / cardiopatia (+10)', _psi_chf, () => setState(() => _psi_chf = !_psi_chf), points: 10),
            _scoreRow(isEs ? 'AVC / secuelas (+10)' : 'AVC / sequela (+10)', _psi_cva, () => setState(() => _psi_cva = !_psi_cva), points: 10),
            _scoreRow(isEs ? 'ERC (+10)' : 'DRC (+10)', _psi_renal, () => setState(() => _psi_renal = !_psi_renal), points: 10),
            _scoreRow(isEs ? 'Internado en residencia (+10)' : 'Institucionalizado (+10)', _psi_nursing, () => setState(() => _psi_nursing = !_psi_nursing), points: 10),
            const SizedBox(height: 8),
            Text('EXAME FÍSICO / CLÍNICA (+pts)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.of(context).textHint)),
            const SizedBox(height: 6),
            _scoreRow(isEs ? 'Confusión/alteración mental (+20)' : 'Confusão / alt. mental (+20)', _psi_alt_ms, () => setState(() => _psi_alt_ms = !_psi_alt_ms), points: 20),
            _scoreRow(isEs ? 'FR ≥30/min (+20)' : 'FR ≥30 irpm (+20)', _psi_rr30, () => setState(() => _psi_rr30 = !_psi_rr30), points: 20),
            _scoreRow(isEs ? 'PAS <90 mmHg (+20)' : 'PAS <90 mmHg (+20)', _psi_sbp90, () => setState(() => _psi_sbp90 = !_psi_sbp90), points: 20),
            _scoreRow(isEs ? 'Tª <35 o ≥40°C (+15)' : 'T° <35 ou ≥40°C (+15)', _psi_temp, () => setState(() => _psi_temp = !_psi_temp), points: 15),
            _scoreRow(isEs ? 'FC ≥125 bpm (+10)' : 'FC ≥125 bpm (+10)', _psi_hr125, () => setState(() => _psi_hr125 = !_psi_hr125), points: 10),
            const SizedBox(height: 8),
            Text('LABS / IMAGEM (+pts)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.of(context).textHint)),
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
    if (d < 60)  return 'CRÍTICO (<60) — risco de isquemia';
    if (d < 65)  return 'HIPOPERFUSÃO (<65)';
    if (d <= 105) return '✓ Adequada (65–105)';
    return '↑ Elevada (>105)';
  }

  String _qtcLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d < 440) return '✓ Normal (<440 ms)';
    if (d < 500) return '⚠ Limítrofe (440–499 ms) — monitorar';
    return 'PROLONGADO (≥500 ms) — risco torsades';
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
          Text('UNIDADE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.of(context).textHint)),
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
              Container(width: 70, child: Text(e.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.of(context).textPrimary))),
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
//  CARD: Importar Exame por IA (gatilho do LabParserService)
// ══════════════════════════════════════════════════════════════════
class _LabImportCard extends StatelessWidget {
  final String locale;
  const _LabImportCard({required this.locale});

  @override
  Widget build(BuildContext context) {
    final isEs = locale == 'es';

    return GestureDetector(
      onTap: () => showAnalyzeExamBottomSheet(context, locale),
      child: Container(
        decoration: BoxDecoration(
          // Gradiente escuro alinhado ao header do app
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F1C14), Color(0xFF1B3D2A), Color(0xFF17502E)],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: kGold.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF1F6B48).withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => showAnalyzeExamBottomSheet(context, locale),
            borderRadius: BorderRadius.circular(18),
            splashColor: kGoldLight.withValues(alpha: 0.06),
            highlightColor: kGoldLight.withValues(alpha: 0.03),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  // Ícone central
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: kGold.withValues(alpha: 0.12),
                      border: Border.all(
                        color: kGold.withValues(alpha: 0.30),
                        width: 1.0,
                      ),
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: kGoldLight,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Texto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs
                              ? 'Importar Examen por IA'
                              : 'Importar Exame por IA',
                          style: const TextStyle(
                            color: kGoldLight,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isEs
                              ? 'Foto · PDF · Screenshot · Texto — preenche os campos automaticamente'
                              : 'Foto · PDF · Screenshot · Texto — preenche os campos automaticamente',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.52),
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Seta + badge IA
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF46E28C).withValues(alpha: 0.14),
                          border: Border.all(
                            color: const Color(0xFF46E28C).withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'IA',
                          style: TextStyle(
                            color: Color(0xFF46E28C),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
      if (be < -3) comp += ' | BE: DÉFICIT de base (${_fmt(be)})';
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
    return 'MUITO ELEVADO (>20) — acidose de AG alto';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [

        // ── Card de importação automática por IA ─────────────────────────
        _LabImportCard(locale: p.lang),
        const SizedBox(height: 12),

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
                  ? (double.parse(_corrCa!.replaceAll(',', '.')) < 8.5 ? 'BAIXO: Hipocalcemia' : double.parse(_corrCa!.replaceAll(',', '.')) > 10.5 ? 'ALTO: Hipercalcemia' : 'Normal') : '')),
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
                color: const Color(0xFF0F1C14),
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
// ── Modelo de fármaco de resgate ────────────────────────────────────────────
class _RescueDrug {
  final String name, dose, concDefault, indication;
  final List<String> risks, avoid;
  const _RescueDrug({
    required this.name, required this.dose,
    required this.concDefault, required this.indication,
    this.risks = const [], this.avoid = const [],
  });
}

class _InfusionTab extends StatefulWidget {
  @override
  State<_InfusionTab> createState() => _InfusionTabState();
}

class _InfusionTabState extends State<_InfusionTab> {
  final _infDrugCtrl    = TextEditingController(text: 'Noradrenalina');
  final _infConcCtrl    = TextEditingController(text: '4');
  final _infRateCtrl    = TextEditingController(text: '10');
  final _infWeightCtrl  = TextEditingController();
  final _doseCtrl       = TextEditingController();
  final _concCalcCtrl   = TextEditingController();
  final _weightCalcCtrl = TextEditingController();
  final _scrollCtrl     = ScrollController();

  static const _rescue = [
    // ── VASOPRESSORES ──────────────────────────────────────────────────────
    _RescueDrug(
      name: 'Noradrenalina',
      dose: '0,01–3 µg/kg/min',
      concDefault: '4',
      indication: '1ª linha vasopressor — sepse/choque distributivo',
      risks: [
        'Vasoconstrição periférica intensa — monitorar perfusão distal',
        'Isquemia digital, mesentérica e renal em doses altas (>0,5 µg/kg/min)',
        'Arritmias (taquicardia reflexa, extrassístoles)',
        'Necrose tecidual grave por extravasamento em veia periférica',
      ],
      avoid: [
        'Hipovolemia não corrigida (ressuscitar antes de iniciar)',
        'Veia periférica: preferir CVC ou acesso central; se periférica, monitorar sítio a cada hora',
        'Não suspender abruptamente — desmame gradual de 10–20%/h',
      ],
    ),
    _RescueDrug(
      name: 'Dobutamina',
      dose: '2–20 µg/kg/min',
      concDefault: '1',
      indication: 'Inotrópico 1ª linha — IC com baixo débito / choque cardiogênico',
      risks: [
        'Taquicardia (frequente) — reduzir dose se FC >130 bpm',
        'Arritmias ventriculares e supraventriculares',
        'Hipotensão por vasodilatação periférica (efeito β₂)',
        'Aumenta consumo de O₂ miocárdico — risco de isquemia em DAC',
        'Tolerância farmacológica após 48–72h de infusão contínua',
      ],
      avoid: [
        'Cardiomiopatia hipertrófica obstrutiva (CMHO) — piora obstrução',
        'Taquicardia grave prévia sem controle (FC basal >120 bpm)',
        'Não combinar com β-bloqueador — antagonismo competitivo',
      ],
    ),
    _RescueDrug(
      name: 'Adrenalina',
      dose: '0,01–1 µg/kg/min',
      concDefault: '0.1',
      indication: 'Choque refratário / anafilaxia grave / PCR (ACLS)',
      risks: [
        'Taquicardia intensa e arritmias ventriculares graves (FV)',
        'Isquemia miocárdica — ↑ consumo O₂ e vasoespasmo coronário',
        'Hiperglicemia (↑ glicogenólise) e hipocalemia (efeito β₂)',
        'Vasoconstrição esplâncnica — isquemia mesentérica',
        'Necrose extensa por extravasamento',
      ],
      avoid: [
        'Anestesia com halogenados (sevoflurano/isoflurano) — risco de FV',
        'IMAO (fenelzina, tranilcipromina) — crise hipertensiva fatal',
        'Dose excessiva em choque de baixo débito sem vasoplegía — piora isquemia',
      ],
    ),
    _RescueDrug(
      name: 'Vasopressina',
      dose: '0,03–0,04 UI/min',
      concDefault: '0.04',
      indication: 'Adjuvante vasopressor — sepse refratária (dose fixa, não titular)',
      risks: [
        'Isquemia coronária, mesentérica e cutânea (vasoconstrição V1)',
        'Bradicardia reflexa',
        'Hiponatremia dilucional com uso prolongado (efeito antidiurético V2)',
        'Isquemia digital em doses suprafisiológicas',
      ],
      avoid: [
        'Titular acima de 0,04 UI/min — sem benefício adicional, ↑ isquemia',
        'Doença arterial coronária grave descompensada sem monitorização',
        'Uso em choque cardiogênico puro (↑ pós-carga sem benefício)',
      ],
    ),
    _RescueDrug(
      name: 'Dopamina',
      dose: '3–20 µg/kg/min',
      concDefault: '1.6',
      indication: 'Vasopressor alternativo — bradicardia + hipotensão (2ª linha)',
      risks: [
        'Fibrilação atrial (↑ 2–3× vs noradrenalina — dados SOAP II)',
        'Taquicardia e outras arritmias ventriculares',
        'Náuseas e vômitos',
        'Necrose tecidual grave por extravasamento',
        '↑ consumo de O₂ miocárdico em doses >10 µg/kg/min',
      ],
      avoid: [
        'Fibrilação atrial prévia ou paroxística — preferir noradrenalina',
        'Feocromocitoma (liberação de catecolaminas endógenas)',
        'IMAO nas últimas 2–3 semanas — crise hipertensiva grave',
        'Choque séptico como 1ª linha (noradrenalina é superior — NEJM 2010)',
      ],
    ),
    _RescueDrug(
      name: 'Fenilefrina',
      dose: '0,5–5 µg/kg/min',
      concDefault: '0.1',
      indication: 'Vasopressor puro (α₁) — hipotensão anestésica / TPSV',
      risks: [
        'Bradicardia reflexa intensa (efeito barorreceptor)',
        'Redução do débito cardíaco por ↑ pós-carga (sem efeito inotrópico)',
        'Vasoconstrição renal e esplâncnica',
        'Hipertensão de rebote se infusão rápida em bólus',
      ],
      avoid: [
        'IC com baixo débito — piora débito cardíaco pela ↑ pós-carga',
        'Bradicardia severa sem marca-passo disponível',
        'Estenose aórtica grave descompensada',
      ],
    ),
    // ── INOTRÓPICOS / VASODILATADORES ─────────────────────────────────────
    _RescueDrug(
      name: 'Milrinona',
      dose: '0,375–0,75 µg/kg/min',
      concDefault: '0.2',
      indication: 'Inodilatador — IC refratária / pós-cirurgia cardíaca',
      risks: [
        'Hipotensão arterial (efeito vasodilatador — frequente em 10–15%)',
        'Arritmias ventriculares (TV sustentada)',
        'Trombocitopenia (uso prolongado — monitorar plaquetas)',
        'Semivida longa (2–3h) — efeitos persistem após suspensão',
      ],
      avoid: [
        'Insuficiência renal grave (ClCr <20 mL/min) — acúmulo; reduzir 50%',
        'IAM agudo fase inicial sem monitorização hemodinâmica invasiva',
        'Estenose aórtica ou pulmonar severa (↑ gradiente com ↑ débito)',
      ],
    ),
    _RescueDrug(
      name: 'Nitroglicerina',
      dose: '5–200 µg/min',
      concDefault: '0.1',
      indication: 'Vasodilatador venoso/arterial — angina instável / EPA / crise HAS',
      risks: [
        'Hipotensão grave, especialmente com hipovolemia',
        'Cefaleia intensa por vasodilatação meníngea',
        'Tolerância farmacológica rápida após 24–48h contínuas (down-regulation)',
        'Metemoglobinemia com doses muito altas (>10 µg/kg/min prolongado)',
      ],
      avoid: [
        'Inibidores de PDE-5 (sildenafila, tadalafila, vardenafila) — hipotensão fatal (24h para sildenafila, 48h para tadalafila)',
        'Hipovolemia não corrigida (PAS <90 mmHg ou FC >100 bpm)',
        'IAM de VD (dependente de pré-carga — colapso hemodinâmico)',
      ],
    ),
    _RescueDrug(
      name: 'Nitroprussiato',
      dose: '0,3–10 µg/kg/min',
      concDefault: '0.1',
      indication: 'Emergência hipertensiva severa / dissecção aórtica / EPA',
      risks: [
        'Toxicidade por cianeto: doses >3 µg/kg/min por >72h — acidose láctica, confusão, convulsão',
        'Toxicidade por tiocianato em insuf. renal (acúmulo lento)',
        'Hipotensão grave de difícil reversão (ação ultracurta mas acumulação)',
        'Roubo coronário em angina instável (vasodilatação coronária excessiva)',
      ],
      avoid: [
        'Insuficiência renal grave (acúmulo de tiocianato) e hepática grave',
        'Gestação (cianeto atravessa placenta)',
        'Obrigatório proteger da luz: cobrir frasco e equipo com papel alumínio',
        'Monitorar nível de tiocianato se uso >72h: meta <100 µg/mL',
      ],
    ),
    // ── ANTIARRÍTMICOS ─────────────────────────────────────────────────────
    _RescueDrug(
      name: 'Amiodarona',
      dose: 'Ataque: 5 mg/kg IV em 1h\nManutenção: 10–15 mg/kg/dia',
      concDefault: '1.5',
      indication: 'Antiarrítmico 1ª linha — FA/flutter/TV com pulso / PCR (FV/TVSP)',
      risks: [
        'Hipotensão significativa na infusão rápida (>150 mg em <10 min)',
        'Bradicardia e bloqueio AV (especialmente com β-bloqueador ou digital)',
        'Flebite e necrose em veia periférica (concentração >2 mg/mL)',
        'Prolongamento do QT — monitorar ECG',
        'Toxicidade pulmonar, tireoidiana e hepática (uso crônico)',
      ],
      avoid: [
        'Bloqueio AV 2º grau Mobitz II ou 3º grau sem marca-passo implantado',
        'Combinação com QT-prolongadores (haloperidol, cloroquina, azitromicina)',
        'Disfunção tireoidiana ativa grave (hiper ou hipotireoidismo)',
        'Concentrar ≥2 mg/mL somente em CVC — periférica: máx 1 mg/mL',
      ],
    ),
    _RescueDrug(
      name: 'Lidocaína',
      dose: 'Ataque: 1–1,5 mg/kg IV em bólus\nManutenção: 1–4 mg/min',
      concDefault: '4',
      indication: 'Antiarrítmico ventricular — TV refratária / FV pós-PCR / analgesia IV',
      risks: [
        'Neurotoxicidade: parestesias, zumbidos, visão turva, agitação (precede convulsão)',
        'Convulsões e coma com doses tóxicas (>5 µg/mL)',
        'Bradicardia sinusal e bloqueio AV (especialmente em cardiopatia prévia)',
        'Depressão miocárdica em doses altas',
      ],
      avoid: [
        'Bloqueio AV avançado (2º grau Mobitz II e 3º grau) sem estimulação',
        'Insuf. hepática grave — reduzir dose de manutenção em 50%',
        'ICC grave (↑ Volume de distribuição → acúmulo → toxicidade)',
        'Monitorar nível sérico se infusão >24h: meta 1,5–5 µg/mL',
      ],
    ),
    // ── METABÓLICOS / SEDAÇÃO ──────────────────────────────────────────────
    _RescueDrug(
      name: 'Insulina Regular',
      dose: '0,05–0,15 UI/kg/h\n(habitual: 0,1 UI/kg/h)',
      concDefault: '1',
      indication: 'Infusão contínua — CAD / EHH / hiperglicemia grave em UTI',
      risks: [
        'Hipoglicemia (risco principal) — monitorar glicemia a cada 1–2h',
        'Hipocalemia (insulina ativa Na/K-ATPase) — repor K⁺ se <3,5 mEq/L antes de iniciar',
        'Hipofosfatemia com infusão prolongada',
        'Edema cerebral na CAD pediátrica (correção muito rápida da glicemia)',
      ],
      avoid: [
        'Glicemia <200 mg/dL na CAD sem adicionar glicose ao soro (parar insulina se <150)',
        'Hipocalemia não corrigida (K⁺ <3,3 mEq/L) — repor K⁺ antes de iniciar insulina',
        'Não suspender insulina na CAD antes de pH>7,30 e cetonúria negativa',
      ],
    ),
    _RescueDrug(
      name: 'Morfina',
      dose: '1–10 mg/h (titulação)\nBólus: 2–4 mg IV em 15 min',
      concDefault: '1',
      indication: 'Analgesia IV potente — dor aguda grave / crise álgica oncológica',
      risks: [
        'Depressão respiratória dose-dependente (FR <12 irpm — naloxona 0,4 mg IV)',
        'Hipotensão por liberação de histamina e vasodilatação',
        'Bradicardia (efeito vagotônico)',
        'Náuseas, vômitos e íleo paralítico',
        'Sedação excessiva — avaliar escala de sedação (RASS)',
      ],
      avoid: [
        'Asma brônquica ativa ou broncoespasmo grave (broncoconstrição)',
        'TCE com hipertensão intracraniana (↑ PaCO₂ por hipoventilação → ↑ PIC)',
        'Íleo paralítico estabelecido (agrava dismotilidade)',
        'Combinar com benzodiazepínicos sem monitorização rigorosa (↑ depressão respiratória)',
      ],
    ),
    _RescueDrug(
      name: 'Propofol',
      dose: '5–50 µg/kg/min\n(0,3–3 mg/kg/h)',
      concDefault: '10',
      indication: 'Sedação em UTI / indução anestésica / IOT de sequência rápida',
      risks: [
        'Síndrome de infusão do propofol (PRIS): dose >4 mg/kg/h por >48h → acidose, rabdomiólise, FA, óbito',
        'Hipotensão significativa (vasodilatação + cardiodepressão)',
        'Hipertrigliceridemia — monitorar triglicérides a cada 48–72h',
        'Dor à injeção em veia periférica (usar lidocaína prévia ou veia calibrosa)',
        'Propofol 1% = 1,1 kcal/mL — computar na dieta do paciente',
      ],
      avoid: [
        'Alergia a ovo ou soja (veículo em emulsão lipídica)',
        'Crianças <3 anos para sedação prolongada em UTI (risco de PRIS aumentado)',
        'Doses >4 mg/kg/h (>67 µg/kg/min) por tempo prolongado',
        'Hipertrigliceridemia grave (TG >400 mg/dL)',
      ],
    ),
    _RescueDrug(
      name: 'Midazolam',
      dose: '0,02–0,1 mg/kg/h\n(titulação: 1–5 mg/h)',
      concDefault: '1',
      indication: 'Sedação em UTI / status epilepticus / pré-medicação anestésica',
      risks: [
        'Depressão respiratória dose-dependente — risco ↑↑ com opioides (sinergismo)',
        'Hipotensão, especialmente em hipovolemia ou cardiopatas',
        'Acúmulo e sedação prolongada em obesos, idosos e insuf. hepática/renal',
        'Agitação paradoxal em idosos e pacientes com demência',
        'Tolerância e síndrome de abstinência em infusões >7 dias',
      ],
      avoid: [
        'DPOC grave ou hipercapnia sem suporte ventilatório mecânico',
        'Combinar com opioide sem monitorização rigorosa de FR e SpO₂',
        'Insuf. hepática grave: semivida aumenta >10× — reduzir dose em 50–75%',
        'Não usar como único agente para analgesia (sem efeito analgésico)',
      ],
    ),
  ];

  void _fillAndScroll(_RescueDrug d, BuildContext ctx) {
    setState(() {
      _infDrugCtrl.text  = d.name;
      _infConcCtrl.text  = d.concDefault;
      _infRateCtrl.text  = '10';
      _concCalcCtrl.text = d.concDefault;
    });
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RiskSheet(drug: d),
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic);
        }
      });
    });
  }

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

  /// Retorna a fórmula matemática explícita do cálculo Velocidade → Dose
  String? get _infusionFormula {
    final conc   = _n(_infConcCtrl);
    final rate   = _n(_infRateCtrl);
    final weight = _n(_infWeightCtrl);
    if (conc == null || rate == null) return null;
    final mgH  = conc * rate;
    final mcgH = mgH * 1000;
    if (weight != null && weight > 0) {
      final mcgKgMin = mcgH / (weight * 60);
      return '${_fmt(conc)} mg/mL × ${_fmt(rate)} mL/h = ${_fmt(mgH)} mg/h\n'
             '÷ (${_fmt(weight)} kg × 60 min) = ${_fmt(mcgKgMin, dec: 3)} mcg/kg/min';
    }
    return '${_fmt(conc)} mg/mL × ${_fmt(rate)} mL/h = ${_fmt(mgH)} mg/h';
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
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [

        _SectionCard(
          title: isEs ? 'Velocidad → Dosis' : 'Velocidade → Dose',
          icon: Icons.water_drop_rounded,
          child: Column(children: [
            DrugAutocompleteField(
              controller: _infDrugCtrl,
              drugs: p.drugsDB,
              label: 'Fármaco',
              hint: 'Noradrenalina',
              onChanged: (_) => setState(() {}),
            ),
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
            // ════════════════════════════════════════════════════════════════
            // CARD RESULTADO PREMIUM — layout visual exclusivo
            // ════════════════════════════════════════════════════════════════
            _InfusionResultCard(
              isEs: isEs,
              drugName: _infDrugCtrl.text,
              infusionRate: _infusionRate,
              infusionFormula: _infusionFormula,
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
          title: isEs ? 'Fármacos de Rescate (toque para calcular)' : 'Fármacos de Resgate (toque para calcular)',
          icon: Icons.touch_app_rounded,
          child: Column(children: [
            _InfoNote(text: isEs
              ? 'Toque en un fármaco para autocompletar la calculadora. Solo informe peso y velocidad.'
              : 'Toque em um fármaco para preencher a calculadora. Informe apenas peso e velocidade.'),
            const SizedBox(height: 10),
            ..._rescue.map((d) => _VasoRefRow(
              drug: d.name, dose: d.dose, note: d.indication,
              onTap: () => _fillAndScroll(d, context),
            )),
            const SizedBox(height: 8),
            _InfoNote(text: isEs
              ? 'Preferir CVC para vasopresores. Titular conforme PAM objetivo ≥65 mmHg.'
              : 'Preferir CVC para vasopressores. Titular conforme PAM alvo ≥65 mmHg.'),
          ]),
        ),

      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// CARD RESULTADO PREMIUM — Calculadora de Infusão
// Layout exclusivo com gradiente, valores lado a lado, fórmula e referências
// ─────────────────────────────────────────────────────────────────────────────
class _InfusionResultCard extends StatelessWidget {
  final bool isEs;
  final String drugName;
  final String? infusionRate;
  final String? infusionFormula;

  const _InfusionResultCard({
    required this.isEs,
    required this.drugName,
    required this.infusionRate,
    required this.infusionFormula,
  });

  // Divide o _infusionRate (pode ter \n) em 2 linhas para layout side-by-side
  List<String> get _rateParts {
    if (infusionRate == null) return [];
    return infusionRate!.split('\n');
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = infusionRate != null;
    final parts = _rateParts;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071510), Color(0xFF0D2B1C), Color(0xFF0F3D28), Color(0xFF075f45)],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF075f45).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF1F6B48).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // ── Decoração de fundo: ícone fantasma ──────────────────────────
          Positioned(
            right: -10,
            top: -10,
            child: Opacity(
              opacity: 0.06,
              child: Icon(
                Icons.water_drop_rounded,
                size: 120,
                color: Colors.white,
              ),
            ),
          ),
          // ── Conteúdo principal ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabeçalho: badge + nome do fármaco ─────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8A6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFFE8A6).withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        isEs ? 'RESULTADO DE LA INFUSIÓN' : 'RESULTADO DA INFUSÃO',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFE8A6),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Nome do fármaco ─────────────────────────────────────────
                Text(
                  drugName.isNotEmpty ? drugName : (isEs ? 'Fármaco' : 'Fármaco'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: hasResult ? 1.0 : 0.5),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),

                if (!hasResult)
                  // ── Estado vazio elegante ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: Colors.white.withValues(alpha: 0.35)),
                        const SizedBox(width: 8),
                        Text(
                          isEs ? 'Ingrese concentración y velocidad' : 'Informe concentração e velocidade',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.40),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // ── Valores: lado a lado se 2 unidades, empilhado se 1 ─────
                  if (parts.length >= 2)
                    Row(
                      children: [
                        Expanded(child: _ResultMetric(value: parts[0], label: _labelFor(parts[0], isEs))),
                        Container(width: 1, height: 60, color: Colors.white.withValues(alpha: 0.12)),
                        Expanded(child: _ResultMetric(value: parts[1], label: _labelFor(parts[1], isEs))),
                      ],
                    )
                  else
                    _ResultMetric(value: parts[0], label: _labelFor(parts[0], isEs), large: true),

                  const SizedBox(height: 14),
                  // ── Fórmula utilizada ───────────────────────────────────────
                  if (infusionFormula != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.functions_rounded,
                              size: 11, color: const Color(0xBFFFE8A6)),
                          const SizedBox(width: 5),
                          Text(
                            isEs ? 'FÓRMULA UTILIZADA' : 'FÓRMULA UTILIZADA',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Color(0xBFFFE8A6),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        Text(
                          infusionFormula!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  // ── Referências bibliográficas ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.menu_book_rounded,
                            size: 11, color: const Color(0xBFFFE8A6)),
                        const SizedBox(width: 5),
                        Text(
                          isEs ? 'REFERENCIAS BIBLIOGRÁFICAS' : 'REFERÊNCIAS BIBLIOGRÁFICAS',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Color(0xBFFFE8A6),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      _RefLine(text: isEs
                        ? '1. Brunton LL, et al. Goodman & Gilman\'s Pharmacological Basis of Therapeutics, 14th ed. McGraw-Hill, 2023.'
                        : '1. Brunton LL, et al. Goodman & Gilman\'s Pharmacological Basis of Therapeutics, 14ª ed. McGraw-Hill, 2023.'),
                      const SizedBox(height: 3),
                      _RefLine(text: isEs
                        ? '2. Marino PL. The ICU Book, 4th ed. Lippincott Williams & Wilkins, 2014.'
                        : '2. Marino PL. The ICU Book, 4ª ed. Lippincott Williams & Wilkins, 2014.'),
                      const SizedBox(height: 3),
                      _RefLine(text: isEs
                        ? '3. Rhodes A, et al. Surviving Sepsis Campaign Guidelines. Crit Care Med. 2017;45(3):486-552.'
                        : '3. Rhodes A, et al. Surviving Sepsis Campaign Guidelines. Crit Care Med. 2017;45(3):486-552.'),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Infere o label da unidade a partir do valor calculado
  String _labelFor(String val, bool isEs) {
    if (val.contains('mcg/kg/min')) return isEs ? 'Microgramos/kg/min' : 'Microgramos/kg/min';
    if (val.contains('mcg/h'))     return isEs ? 'Microgramos por hora' : 'Microgramas por hora';
    if (val.contains('mg/h'))      return isEs ? 'Miligramos por hora'  : 'Miligramas por hora';
    if (val.contains('mL/h'))      return isEs ? 'Mililitros por hora'  : 'Mililitros por hora';
    return '';
  }
}

// Métrica individual dentro do card de resultado
class _ResultMetric extends StatelessWidget {
  final String value;
  final String label;
  final bool large;
  const _ResultMetric({required this.value, required this.label, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 28 : 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.50),
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    );
  }
}

class _VasoRefRow extends StatelessWidget {
  final String drug, dose, note;
  final VoidCallback? onTap;
  const _VasoRefRow({required this.drug, required this.dose, required this.note, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c    = AppColors.of(context);
    final dark = context.watch<AppProvider>().darkMode;
    final tappable = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: tappable
              ? (dark ? const Color(0xFF1C2A20) : const Color(0xFFF0FDF4))
              : c.cardBg,
          border: Border.all(
            color: tappable
                ? (dark ? const Color(0xFF22543D) : const Color(0xFFBBF7D0))
                : c.border,
          ),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(drug, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary)),
            const SizedBox(height: 2),
            Text(note, style: TextStyle(fontSize: 11, color: c.textSecondary, height: 1.3)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: kToolGreen.withValues(alpha: 0.12),
              ),
              child: Text(dose, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kToolGreen)),
            ),
            if (tappable) ...[
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.touch_app_rounded, size: 9,
                  color: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
                const SizedBox(width: 3),
                Text('calcular',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                    color: dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))),
              ]),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ── Bottom sheet: riscos e interações ──────────────────────────────────────
class _RiskSheet extends StatelessWidget {
  final _RescueDrug drug;
  const _RiskSheet({required this.drug});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().darkMode;
    final bg   = dark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20,
          20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Handle
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 14),

        // Cabeçalho
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFEF4444).withValues(alpha: 0.12)),
            child: const Icon(Icons.medication_rounded, size: 18, color: Color(0xFFEF4444)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(drug.name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                color: dark ? Colors.white : const Color(0xFF0F172A))),
            Text('Calculadora preenchida — informe peso e velocidade',
              style: TextStyle(fontSize: 11,
                color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280))),
          ])),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(Icons.close_rounded, size: 20,
              color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
          ),
        ]),

        const SizedBox(height: 14),

        // Riscos
        if (drug.risks.isNotEmpty) ...[
          _RiskBlock(
            label: 'ATENÇÃO — EFEITOS E RISCOS',
            labelColor: const Color(0xFFF59E0B),
            icon: Icons.info_outline_rounded,
            items: drug.risks,
            bgDark: const Color(0xFF271C0A),
            bgLight: const Color(0xFFFFFBEB),
            borderDark: const Color(0xFF5C3D0A),
            borderLight: const Color(0xFFFCD34D),
            textDark: const Color(0xFFFDE68A),
            textLight: const Color(0xFF78350F),
            dark: dark,
          ),
          const SizedBox(height: 8),
        ],

        // Evitar / Contraindicações
        if (drug.avoid.isNotEmpty) ...[
          _RiskBlock(
            label: 'EVITAR / CONTRAINDICADO',
            labelColor: const Color(0xFFEF4444),
            icon: Icons.block_rounded,
            items: drug.avoid,
            bgDark: const Color(0xFF2A1515),
            bgLight: const Color(0xFFFFF0F0),
            borderDark: const Color(0xFF6B2020),
            borderLight: const Color(0xFFFCA5A5),
            textDark: const Color(0xFFFFCCCC),
            textLight: const Color(0xFF7F1D1D),
            dark: dark,
          ),
          const SizedBox(height: 12),
        ],

        // Botão de ação
        SizedBox(
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: kToolGreen.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.calculate_rounded, size: 16, color: kToolGreen),
              const SizedBox(width: 8),
              const Text('Entendido — ir para a calculadora',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kToolGreen)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _RiskBlock extends StatelessWidget {
  final String label;
  final Color labelColor, iconColor;
  final IconData icon;
  final List<String> items;
  final Color bgDark, bgLight, borderDark, borderLight, textDark, textLight;
  final bool dark;

  const _RiskBlock({
    required this.label, required this.labelColor,
    required this.icon, required this.items,
    required this.bgDark, required this.bgLight,
    required this.borderDark, required this.borderLight,
    required this.textDark, required this.textLight,
    required this.dark,
  }) : iconColor = labelColor;

  @override
  Widget build(BuildContext context) {
    final bg     = dark ? bgDark     : bgLight;
    final border = dark ? borderDark : borderLight;
    final text   = dark ? textDark   : textLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 11, color: labelColor),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w900,
            color: labelColor, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color: text.withValues(alpha: 0.6),
                  shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(item,
              style: TextStyle(fontSize: 12, color: text, height: 1.4))),
          ]),
        )),
      ]),
    );
  }
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
                      color: active ? const Color(0xFF0F1C14) : Colors.white60, letterSpacing: 0.5)),
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
      ['Paracetamol', 'N-Acetilcisteína', isEs ? '150 mg/kg IV em 60 min, depois 50 mg/kg em 4h, depois 100 mg/kg em 16h. Usar nomograma Rumack-Matthew.' : '150 mg/kg IV em 60 min, depois 50 mg/kg em 4h, depois 100 mg/kg em 16h. Nomograma Rumack-Matthew.',  'MOD'],
      ['Opioides', 'Naloxona', isEs ? '0,4–2 mg IV/IM/SC a cada 2–3 min. Duração 30–90 min (< que morfina) — repetir ou infusão.' : '0,4–2 mg IV/IM/SC a cada 2–3 min. Duração 30–90 min (< que morfina) — repetir ou infusão contínua.',  'ALTO'],
      ['Benzodiazepínicos', 'Flumazenil', isEs ? '0,2 mg IV em 30s; repetir 0,1 mg/min; máx. 1 mg. CUIDADO: convulsões em dependentes crônicos.' : '0,2 mg IV em 30s; repetir 0,1 mg/min; máx. 1 mg. CUIDADO: convulsões em dependentes crônicos.',  'MOD'],
      ['Digoxina', 'Anticorpos anti-Digoxina (Digibind)', isEs ? '80 mg IV neutraliza 1 mg digoxina. Indicação: K+ >5, arritmias ameaçadoras.' : '80 mg IV neutraliza 1 mg digoxina. Indicação: K+ >5, arritmias ameaçadoras.',  'ALTO'],
      ['Heparina NF', 'Sulfato de Protamina', isEs ? '1 mg neutraliza 100 UI HNF. IV lento em 10 min (hipotensão). Máx. 50 mg/dose.' : '1 mg neutraliza 100 UI HNF. IV lento em 10 min (hipotensão). Máx. 50 mg/dose.',  'MOD'],
      ['Warfarina', 'Vitamina K + PFC/CCP', isEs ? 'INR >10 sem sangrado: Vit K 2,5–5 mg VO. Com sangrado grave: CCP 25–50 UI/kg IV + Vit K 5–10 mg IV.' : 'INR >10 sem sangrado: Vit K 2,5–5 mg VO. Com sangrado grave: CCP 25–50 UI/kg IV + Vit K 5–10 mg IV.',  'ALTO'],
      ['Rivaroxabana/Apixabana', 'Andexanet alfa', isEs ? '400–800 mg IV bolo + infusão. Alto custo. Alternativa: CCP 4 fatores 25–50 UI/kg.' : '400–800 mg IV bolo + infusão. Alto custo. Alternativa: CCP 4 fatores 25–50 UI/kg.',  'ALTO'],
      ['Dabigatrana', 'Idarucizumabe', isEs ? '5 g IV (2 frascos de 2,5 g). Reversão completa e imediata.' : '5 g IV (2 frascos de 2,5 g). Reversão completa e imediata.',  'ALTO'],
      ['Organofosforados', 'Atropina + Pralidoxima', isEs ? 'Atropina 2–4 mg IV (titular pelos secretos). Pralidoxima 1–2 g IV em 30 min. Repetir atropina até secar secreções.' : 'Atropina 2–4 mg IV (titular pelos secretos). Pralidoxima 1–2 g IV em 30 min. Titular atropina até secar secreções.',  'ALTO'],
      ['Sulfato de Magnésio (tóxico)', 'Gluconato de Cálcio', isEs ? '1 g (10 mL de sol. 10%) IV lento em 3 min. Antagonismo fisiológico imediato.' : '1 g (10 mL sol. 10%) IV lento em 3 min. Antagonismo fisiológico imediato.',  'ALTO'],
      ['Metanol/Etilenoglicol', 'Fomepizole + Hemodiálise', isEs ? 'Fomepizol 15 mg/kg IV + hemodiálise urgente. Etanol 10% IV como alternativa.' : 'Fomepizol 15 mg/kg IV + hemodiálise urgente. Etanol 10% IV como alternativa.',  'ALTO'],
      ['Cianeto', 'Hidroxocobalamina', isEs ? '5 g IV em 15 min. Alternativa: Nitrito de amila (inalação) + Tiosulfato de sódio 12,5 g IV.' : '5 g IV em 15 min. Alternativa: Nitrito de amila (inalação) + Tiosulfato de sódio 12,5 g IV.',  'ALTO'],
      ['Monóxido de Carbono', 'O2 100% / Câmara Hiperbárica', isEs ? 'O2 100% máscara NRB até COHb <5%. Hiperbárica se: COHb >25%, gestante, inconsciente, cardíaco.' : 'O2 100% máscara NRB até COHb <5%. Câmara hiperbárica se: COHb >25%, gestante, coma, cardiopata.',  'ALTO'],
      ['Antidepressivos Tricíclicos', 'Bicarbonato de Sódio', isEs ? 'NaHCO3 1–2 mEq/kg IV se QRS >120ms. Meta: pH 7,45–7,55. Diazepam nas convulsões.' : 'NaHCO3 1–2 mEq/kg IV se QRS >120ms. Meta: pH 7,45–7,55. Diazepam nas convulsões.',  'ALTO'],
      ['Hiperpotassemia', 'Gluconato de Cálcio', isEs ? '1 g IV em 2 min (estabiliza membrana). Insulina 10 UI + Glicose 50% para shift intracelular.' : '1 g IV em 2 min (estabiliza membrana). Insulina 10 UI + Glicose 50% para shift intracelular.',  'ALTO'],
      ['Hipoglicemia', 'Glicose 50% IV / Glucagon', isEs ? 'Glicose 50%: 50 mL IV. Glucagon 1 mg IM/SC se sem acesso. SNG: suco de laranja.' : 'Glicose 50%: 50 mL IV. Glucagon 1 mg IM/SC se sem acesso. VO: suco de laranja/mel.',  'ALTO'],
      ['β-Bloqueadores (tóxico)', 'Glucagon + Emulsão Lipídica', isEs ? 'Glucagon 3–10 mg IV bolo + 3–10 mg/h infusão. Emulsão lipídica 20%: 1,5 mL/kg IV bolo.' : 'Glucagon 3–10 mg IV bolo + 3–10 mg/h infusão. Emulsão lipídica 20%: 1,5 mL/kg IV bolo.',  'MOD'],
      ['Bloq. Canal de Cálcio (tóxico)', 'Cálcio IV + Insulina Alta Dose', isEs ? 'CaCl2 1–2 g IV. Insulina 1 UI/kg/h + Glicose. Emulsão lipídica 20% se refratário.' : 'CaCl2 1–2 g IV. Insulina 1 UI/kg/h + Glicose. Emulsão lipídica 20% se refratário.',  'MOD'],
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
            ? 'Confirmar posição com Rx tórax antes de usar. Ponta ideal: junção cava superior-átrio direito. Eco point-of-care facilita.'
            : 'Confirmar posição com Rx tórax antes de usar. Ponta ideal: junção cava superior-átrio direito. Eco point-of-care facilita.'),
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
            ? 'Gradiente A-a = PAO2 – PaO2. PAO2 = FiO2×(Patm–PH2O) – PaCO2/0,8. Normal: <10 jovem; <25 idoso.'
            : 'Gradiente A-a = PAO2 – PaO2. PAO2 = FiO2×(Patm–PH2O) – PaCO2/0,8. Normal: <10 jovem; <25 idoso.'),
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
          child: Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.of(context).textPrimary))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ref, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
          if (note.isNotEmpty)
            Text(note, style: TextStyle(fontSize: 10, color: isAlert ? const Color(0xFFB45309) : AppColors.of(context).textSecondary, height: 1.3)),
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
          Text(desc, style: TextStyle(fontSize: 11, color: AppColors.of(context).textSecondary, height: 1.4)),
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
          color: AppColors.of(context).cardBg,
          border: Border.all(color: AppColors.of(context).border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: level == 'ALTO'
                    ? const Color(0xFFCC2222).withValues(alpha: 0.10)
                    : const Color(0xFFC5A365).withValues(alpha: 0.12),
              ),
              child: Text(
                level,
                style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0,
                  color: level == 'ALTO'
                      ? const Color(0xFFCC2222)
                      : const Color(0xFFC5A365),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(toxin, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.of(context).textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF1F6B48).withValues(alpha: 0.12)),
              child: Text(antidote, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1F6B48))),
            ),
          ]),
          const SizedBox(height: 5),
          Text(dose, style: TextStyle(fontSize: 11, color: AppColors.of(context).textSecondary, height: 1.4)),
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
          Text(site, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.of(context).textPrimary)),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF065F46)),
              Expanded(child: Text(pros, style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.3))),
            ])),
            const SizedBox(width: 8),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFB45309)),
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
          decoration: BoxDecoration(color: AppColors.of(context).darkBtn, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(step, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kToolGold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.of(context).textPrimary)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 10.5, color: AppColors.of(context).textSecondary, height: 1.5, fontFamily: 'monospace')),
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

  List<String> _categories(bool isEs) => [
    isEs ? 'DOLOR/FIEBRE' : 'DOR/FEBRE',
    isEs ? 'NÁUSEAS'      : 'NÁUSEA',
    isEs ? 'INFECCIÓN'    : 'INFECÇÃO',
    'HAS',
    'HipoK+',
    isEs ? 'SEDACIÓN'     : 'SEDAÇÃO',
    isEs ? 'SEPSIS'       : 'SEPSE',
    isEs ? 'COAGULACIÓN'  : 'COAGULAÇÃO',
    isEs ? 'ANTI-HAS GRAVE' : 'ANTI-HAS GRAVE',
    isEs ? 'DISNEA'       : 'DISPNEIA',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final categories = _categories(isEs);

    return Column(children: [
      Container(
        color: const Color(0xFF0A1A10),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(categories.length, (i) {
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
                  child: Text(categories[i],
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: active ? const Color(0xFF0F1C14) : Colors.white60, letterSpacing: 0.5)),
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
        level: 'MOD',
        items: [
          _PrescItem('1.', isEs ? 'Paracetamol 1 g VO/IV 6/6h (máx. 4 g/dia). Preferir para febre e dor leve.' : 'Paracetamol 1 g VO/IV 6/6h (máx. 4 g/dia). Preferir para febre e dor leve.'),
          _PrescItem('2.', isEs ? 'SE necessário: Ibuprofeno 400–600 mg 8/8h VO (com alimento). Evitar em IR, úlcera, ICC.' : 'SE necessário: Ibuprofeno 400–600 mg 8/8h VO (com alimento). Evitar IR, úlcera, ICC.'),
          _PrescItem('3.', isEs ? 'Dipirona 1 g VO/IV 6/6h (IV lento ≥15 min). Alternativa eficaz.' : 'Dipirona 1 g VO/IV 6/6h (IV lento ≥15 min). Alternativa eficaz.'),
          _PrescItem('Aten.', isEs ? 'Não combinar dois AINEs. Evitar em gestante, IR grave, plaquetopenia.' : 'Não combinar dois AINEs. Evitar em gestante, IR grave, plaquetopenia.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Dolor Moderado–Severo' : 'Dor Moderada–Grave',
        level: 'ALTO',
        items: [
          _PrescItem('1.', isEs ? 'Tramadol 50–100 mg VO 8/8h (ou IV lento em 100 mL SF). Máx. 400 mg/dia.' : 'Tramadol 50–100 mg VO 8/8h (ou IV lento em 100 mL SF). Máx. 400 mg/dia.'),
          _PrescItem('2.', isEs ? 'Morfina 2–5 mg IV lento a cada 4h. Titular pela dor (EV ou PO). Cuidado: depressão respiratória.' : 'Morfina 2–5 mg IV lento a cada 4h. Titular pela dor (EV ou PO). Cuidado: depressão resp.'),
          _PrescItem('3.', isEs ? 'Cetorolaco 30 mg IV/IM 8/8h (máx. 5 dias). Excelente para cólica renal.' : 'Cetorolaco 30 mg IV/IM 8/8h (máx. 5 dias). Excelente para cólica renal.'),
          _PrescItem('Aten.', isEs ? 'Naloxona 0,4 mg IV disponível. Monitorar SpO2 contínua com opioides IV.' : 'Naloxona 0,4 mg IV disponível. Monitorar SpO2 contínua com opioides IV.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Fiebre (T >38,3°C)' : 'Febre (T >38,3°C)',
        level: 'MOD',
        items: [
          _PrescItem('1.', isEs ? 'Paracetamol 750 mg–1 g VO/IV 6/6h. Primeira escolha — seguro e eficaz.' : 'Paracetamol 750 mg–1 g VO/IV 6/6h. Primeira escolha — seguro e eficaz.'),
          _PrescItem('2.', isEs ? 'Dipirona 1 g IV 6/6h (lento) se febre persistente ou mal-tolerada.' : 'Dipirona 1 g IV 6/6h (lento) se febre persistente ou mal-tolerada.'),
          _PrescItem('3.', isEs ? 'Compressa morna se T > 40°C e paciente confortável.' : 'Compressa morna se T >40°C e paciente confortável.'),
          _PrescItem('Aten.', isEs ? 'Investigar CAUSA — não tratar febre isoladamente sem colher culturas.' : 'Investigar CAUSA — não tratar febre isoladamente sem colher culturas.'),
        ],
      ),
    ]);
  }

  Widget _buildNausea(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Náuseas y Vómitos — 1ª Línea' : 'Náuseas e Vômitos — 1ª Linha',
        level: 'MOD',
        items: [
          _PrescItem('1.', isEs ? 'Ondansetrona 4–8 mg IV lento (2–5 min) 8/8h. Primeira escolha — menos sedação.' : 'Ondansetrona 4–8 mg IV lento (2–5 min) 8/8h. Primeira escolha — menos sedação.'),
          _PrescItem('2.', isEs ? 'Metoclopramida 10 mg IV 8/8h (lento em 50 mL SF, 15 min). Útil se dismotilidade gástrica.' : 'Metoclopramida 10 mg IV 8/8h (lento em 50 mL SF, 15 min). Útil se dismotilidade gástrica.'),
          _PrescItem('3.', isEs ? 'Dimenidrinato 50 mg IV/VO 8/8h se náusea vestibular.' : 'Dimenidrinato 50 mg IV/VO 8/8h se náusea vestibular.'),
          _PrescItem('Aten.', isEs ? 'Metoclopramida: evitar em parkinsonismo. Ondansetrona: monitorar QT.' : 'Metoclopramida: evitar em parkinsonismo. Ondansetrona: monitorar QT.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Vómitos Incoercibles / Quimioterapia' : 'Vômitos Incoercíveis / Quimioterapia',
        level: 'ALTO',
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
        level: 'MOD',
        items: [
          _PrescItem('1.ª opção', isEs ? 'Nitrofurantoína 100 mg VO 12/12h × 5 dias (não usar em IR: ClCr <45).' : 'Nitrofurantoína 100 mg VO 12/12h × 5 dias (não usar em IR: ClCr <45).'),
          _PrescItem('2.ª opção', isEs ? 'Fosfomicina 3 g VO dose única (cistite simples).' : 'Fosfomicina 3 g VO dose única (cistite simples).'),
          _PrescItem('3.ª opção', isEs ? 'Ciprofloxacino 500 mg VO 12/12h × 3 dias (reservar quinolonas).' : 'Ciprofloxacino 500 mg VO 12/12h × 3 dias (reservar quinolonas).'),
          _PrescItem('Aten.', isEs ? 'Amoxicilina isolada: alta resistência (>30%). Evitar sem antibiograma.' : 'Amoxicilina isolada: alta resistência (>30%). Evitar sem antibiograma.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'ITU Complicada / Pielonefritis' : 'ITU Complicada / Pielonefrite',
        level: 'ALTO',
        items: [
          _PrescItem('Internado IV', isEs ? 'Ceftriaxona 1–2 g IV/dia ou Ciprofloxacino 400 mg IV 12/12h.' : 'Ceftriaxona 1–2 g IV/dia ou Ciprofloxacino 400 mg IV 12/12h.'),
          _PrescItem('Ambulatorial', isEs ? 'Ciprofloxacino 500 mg VO 12/12h × 7 dias (pielonefrite leve).' : 'Ciprofloxacino 500 mg VO 12/12h × 7 dias (pielonefrite leve).'),
          _PrescItem('Cultura+', isEs ? 'Aguardar antibiograma e desescalar em 48–72h.' : 'Aguardar antibiograma e desescalar em 48–72h.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'PAC Leve–Moderada (ambulatorio)' : 'PAC Leve–Moderada (ambulatorial)',
        level: 'MOD',
        items: [
          _PrescItem('Sem comorbidade', isEs ? 'Amoxicilina 1 g VO 8/8h × 5 dias (pneumococo — 1ª opção).' : 'Amoxicilina 1 g VO 8/8h × 5 dias (pneumococo — 1ª opção).'),
          _PrescItem('Atípico suspeito', isEs ? 'Azitromicina 500 mg/dia × 5 dias OU Doxiciclina 100 mg 12/12h × 7 dias.' : 'Azitromicina 500 mg/dia × 5 dias OU Doxiciclina 100 mg 12/12h × 7 dias.'),
          _PrescItem('Com comorbidade', isEs ? 'Amox+Clav 875/125 mg 12/12h + Azitromicina × 7 dias.' : 'Amox+Clav 875/125 mg 12/12h + Azitromicina × 7 dias.'),
          _PrescItem('Aten.', isEs ? 'CURB-65 ≥2 = considerar internação. ≥3 = UTI avaliação.' : 'CURB-65 ≥2 = considerar internação. ≥3 = avaliar UTI.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Celulitis / Erisipela' : 'Celulite / Erisipela',
        level: 'MOD',
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
        level: 'MOD',
        items: [
          _PrescItem('1.ª linha', isEs ? 'Anlodipino 5 mg VO 1×/dia (pode titular para 10 mg).' : 'Anlodipino 5 mg VO 1×/dia (pode titular para 10 mg).'),
          _PrescItem('Ou', isEs ? 'Losartana 50 mg VO 1×/dia (titular para 100 mg). Preferir em DM/proteinúria.' : 'Losartana 50 mg VO 1×/dia (titular para 100 mg). Preferir em DM/proteinúria.'),
          _PrescItem('Ou', isEs ? 'Enalapril 5–10 mg VO 12/12h. Monitorar K+ e creatinina.' : 'Enalapril 5–10 mg VO 12/12h. Monitorar K+ e creatinina.'),
          _PrescItem('Combinação', isEs ? 'Anlodipino + Losartana se PA não controlada com monoterapia em 4 semanas.' : 'Anlodipino + Losartana se PA não controlada com monoterapia em 4 semanas.'),
          _PrescItem('Aten.', isEs ? 'IECA/ARA2: contraindicados na gravidez. Monitorar K+ com poupadores.' : 'IECA/ARA2: contraindicados na gravidez. Monitorar K+ com poupadores.'),
        ],
      ),
    ]);
  }

  Widget _buildHypoK(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Hipopotasemia — Reposición' : 'Hipopotassemia — Reposição',
        level: 'ALTO',
        items: [
          _PrescItem('K+ 3,0–3,5', isEs ? 'KCl 40 mEq VO (frutas, sal light) ou KCl oral 40 mEq fracionado.' : 'KCl 40 mEq VO (frutas, sal light) ou KCl oral 40 mEq fracionado.'),
          _PrescItem('K+ 2,5–3,0', isEs ? 'KCl 40–60 mEq em 500 mL SF IV em 4–6h (taxa máx. 10 mEq/h periférica).' : 'KCl 40–60 mEq em 500 mL SF IV em 4–6h (taxa máx. 10 mEq/h periférica).'),
          _PrescItem('K+ <2,5/ECG alt.', isEs ? 'KCl até 20–40 mEq/h em via central com monitorização ECG contínua.' : 'KCl até 20–40 mEq/h em via central com monitorização ECG contínua.'),
          _PrescItem('Aten.', isEs ? 'NUNCA KCl IV direto (bolus). Sempre diluído. Verificar e repor Mg2+ junto (hipoMg perpetua hipoK).' : 'NUNCA KCl IV direto (bolus). Sempre diluído. Repor Mg2+ junto (hipoMg perpetua hipoK).'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Hipomagnesemia' : 'Hipomagnesemia',
        level: 'MOD',
        items: [
          _PrescItem('Reposição IV', isEs ? 'MgSO4 2 g IV em 100 mL SF em 15–20 min. Repetir se Mg <1,5 mg/dL.' : 'MgSO4 2 g IV em 100 mL SF em 15–20 min. Repetir se Mg <1,5 mg/dL.'),
          _PrescItem('Manutenção VO', isEs ? 'Óxido de Magnésio 400 mg VO 1–2×/dia.' : 'Óxido de Magnésio 400 mg VO 1–2×/dia.'),
          _PrescItem('Aten.', isEs ? 'Hipomagnesemia: causa comum de hipocalemia e hipocalcemia refratária.' : 'Hipomagnesemia: causa comum de hipocalemia e hipocalcemia refratária.'),
        ],
      ),
    ]);
  }

  Widget _buildSedation(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Sedación/Analgesia en UTI (PADIS 2018)' : 'Sedação/Analgesia em UTI (PADIS 2018)',
        level: 'ALTO',
        items: [
          _PrescItem(isEs ? '1. Analgesia' : '1. Analgesia', isEs ? 'Analgesia-PRIMERO: Fentanil 25–50 mcg IV PRN o Morfina 2–4 mg IV PRN.' : 'Analgesia-PRIMEIRO: Fentanil 25–50 mcg IV PRN ou Morfina 2–4 mg IV PRN.'),
          _PrescItem(isEs ? '2. Sedación leve' : '2. Sedação leve', isEs ? 'Meta RASS -1 a 0. Propofol 0,5–3 mg/kg/h IV O Dexmedetomidina 0,2–1,5 mcg/kg/h.' : 'Meta RASS -1 a 0. Propofol 0,5–3 mg/kg/h IV OU Dexmedetomidina 0,2–1,5 mcg/kg/h.'),
          _PrescItem('3. Delirium', isEs ? 'Haloperidol 0,25–0,5 mg IV 8/8h si agitación. Orientación + luz + movilización precoz.' : 'Haloperidol 0,25–0,5 mg IV 8/8h se agitação. Orientação + luz + mobilização precoce.'),
          _PrescItem(isEs ? 'Sedación profunda' : 'Sedação profunda', isEs ? 'Midazolam 0,02–0,1 mg/kg/h + Fentanil 25–100 mcg/h (IOT/SDRA/status).' : 'Midazolam 0,02–0,1 mg/kg/h + Fentanil 25–100 mcg/h (IOT/SARA/status).'),
          _PrescItem('Aten.', isEs ? 'Interrupción diaria de la sedación ("sedation vacation"). Evaluar RASS 4×/día.' : 'Interrupção diária da sedação ("sedation vacation"). Avaliar RASS 4×/dia.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Escalas RASS / BPS (referencia)' : 'Escalas RASS / BPS (referência)',
        level: 'MOD',
        items: [
          _PrescItem('RASS', isEs ? '+4=combativo; +1=agitado; 0=alerta; -1=somnoliento; -3=moderado; -5=no responsivo.' : '+4=combativo; +1=agitado; 0=alerta; -1=sonolento; -3=moderado; -5=não responsivo.'),
          _PrescItem('BPS', isEs ? '3=sin dolor; 12=dolor máximo. Evaluación: expresión facial + extremidad + ventilación.' : '3=sem dor; 12=dor máxima. Avaliação: expressão facial + membro + ventilação.'),
          _PrescItem('CAM-ICU', isEs ? 'Evalúa delirium en ventilado: 1)inicio agudo+fluctuación, 2)desatención, 3)alteración consciencia o pensamiento desorganizado.' : 'Avalia delirium em ventilado: 1)início agudo+flutuação, 2)desatenção, 3)consciência alt. ou pensamento desorganizado.'),
        ],
      ),
    ]);
  }

  Widget _buildSepsis(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Bundle de Sepsis — HORA 1 (SSC 2021)' : 'Bundle de Sepse — HORA 1 (SSC 2021)',
        level: 'ALTO',
        items: [
          _PrescItem('1.', isEs ? 'Medir lactato (repetir se >2 mmol/L).' : 'Medir lactato (repetir se >2 mmol/L).'),
          _PrescItem('2.', isEs ? 'Hemocultura 2× ANTES do antibiótico.' : 'Hemocultura 2× ANTES do antibiótico.'),
          _PrescItem('3.', isEs ? 'Antibiótico de amplo espectro em <1h.' : 'Antibiótico de amplo espectro em <1h.'),
          _PrescItem('4.', isEs ? 'SF/RL 30 mL/kg IV em ≤3h se hipoperfusão.' : 'SF/RL 30 mL/kg IV em ≤3h se hipoperfusão.'),
          _PrescItem('5.', isEs ? 'Vasopressor se PAM <65 após volume: Noradrenalina 0,1–1 µg/kg/min.' : 'Vasopressor se PAM <65 após volume: Noradrenalina 0,1–1 µg/kg/min.'),
          _PrescItem('ATB empírico', isEs ? 'Pip-Tazo 4,5g IV 6/6h + Vancomicina 25 mg/kg IV (1ª dose, com infusão 1–2h).' : 'Pip-Tazo 4,5g IV 6/6h + Vancomicina 25 mg/kg IV (1ª dose, infusão 1–2h).'),
          _PrescItem('Aten.', isEs ? 'Desescalar em 48–72h com cultura. Avaliar foco cirúrgico.' : 'Desescalar em 48–72h com cultura. Avaliar foco cirúrgico.'),
        ],
      ),
    ]);
  }

  Widget _buildCoagulation(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Profilaxis de TVP / TEP' : 'Profilaxia de TVP / TEP',
        level: 'MOD',
        items: [
          _PrescItem('Internados ClCr>30', isEs ? 'Enoxaparina 40 mg SC 1×/dia.' : 'Enoxaparina 40 mg SC 1×/dia.'),
          _PrescItem('Obesos >100 kg', isEs ? 'Enoxaparina 40 mg SC 12/12h ou 0,5 mg/kg/dia.' : 'Enoxaparina 40 mg SC 12/12h ou 0,5 mg/kg/dia.'),
          _PrescItem('ClCr <30', isEs ? 'HNF 5000 UI SC 8/8h (preferir em IR grave).' : 'HNF 5000 UI SC 8/8h (preferir em IR grave).'),
          _PrescItem('Aten.', isEs ? 'Contraindicada: sangramento ativo, plaquetas <50k, cirurgia SNC recente.' : 'Contraindicada: sangramento ativo, plaquetas <50k, cirurgia SNC recente.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Anticoagulación FA (inicio)' : 'Anticoagulação FA (início)',
        level: 'MOD',
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
        level: 'ALTO',
        items: [
          _PrescItem('Meta geral', isEs ? 'Reduzir PAM 20–25% nas primeiras 1–2h. NÃO normalizar abruptamente.' : 'Reduzir PAM 20–25% nas primeiras 1–2h. NÃO normalizar abruptamente.'),
          _PrescItem('EAP/encef.', isEs ? 'Nitroprussiato 0,5–10 µg/kg/min IV (titular) OU Nicardipino 5–15 mg/h IV.' : 'Nitroprussiato 0,5–10 µg/kg/min IV (titular) OU Nicardipino 5–15 mg/h IV.'),
          _PrescItem('Disseção Ao.', isEs ? 'Esmolol 500 mcg/kg IV + 50–200 mcg/kg/min + Nitroprussiato. Meta PAS ≤120.' : 'Esmolol 500 mcg/kg IV + 50–200 mcg/kg/min + Nitroprussiato. Meta PAS ≤120.'),
          _PrescItem('Eclâmpsia', isEs ? 'Hidralazina 5–10 mg IV 20 min + MgSO4 4–6 g IV (ver protocolo pré-ecl.).' : 'Hidralazina 5–10 mg IV 20 min + MgSO4 4–6 g IV (ver protocolo pré-ecl.).'),
          _PrescItem('Contra.', isEs ? 'NUNCA nifedipino sublingual — queda abrupta e imprevisível → isquemia.' : 'NUNCA nifedipino sublingual — queda abrupta e imprevisível → isquemia.'),
        ],
      ),
    ]);
  }

  Widget _buildDyspnea(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs ? 'Dispnea Aguda — Algoritmo Rápido' : 'Dispneia Aguda — Algoritmo Rápido',
        level: 'ALTO',
        items: [
          _PrescItem('ABCDE', isEs ? 'Posição sentada, O2 por máscara (Venturi 35–50% se DPOC: máx. SpO2 88–92%).' : 'Posição sentada, O2 por máscara (Venturi 35–50% se DPOC: máx. SpO2 88–92%).'),
          _PrescItem('EAP', isEs ? 'Furosemida 40–80 mg IV + NTG 5–10 µg/min IV + VNI (CPAP ≥5 cmH2O).' : 'Furosemida 40–80 mg IV + NTG 5–10 µg/min IV + VNI (CPAP ≥5 cmH2O).'),
          _PrescItem('Broncoespasmo', isEs ? 'Salbutamol 2,5 mg NEB a cada 20 min × 3 + Ipratrópio 0,5 mg NEB + MgSO4 2g IV.' : 'Salbutamol 2,5 mg NEB a cada 20 min × 3 + Ipratrópio 0,5 mg NEB + MgSO4 2g IV.'),
          _PrescItem('DPOC exacerb.', isEs ? 'Broncodilatadores + Prednisona 40 mg/dia × 5d + ATB (azitro/amox-clav) se infecção.' : 'Broncodilatadores + Prednisona 40 mg/dia × 5d + ATB (azitro/amox-clav) se infecção.'),
          _PrescItem('TEP', isEs ? 'Anticoagulação imediata (enoxaparina ou rivaroxabana). Trombólise se instável.' : 'Anticoagulação imediata (enoxaparina ou rivaroxabana). Trombólise se instável.'),
          _PrescItem('Aten.', isEs ? 'O2 alvo: SpO2 94–98% (geral) OU 88–92% (DPOC/hipoxemia crônica).' : 'O2 alvo: SpO2 94–98% (geral) OU 88–92% (DPOC/hipoxemia crônica).'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'VNI — Indicaciones y Configuración' : 'VNI — Indicações e Configuração',
        level: 'MOD',
        items: [
          _PrescItem('Indicações', isEs ? 'EAP cardiogênico, DPOC exacerbação, hipoxemia leve-mod (SpO2 <92% com O2 convencional).' : 'EAP cardiogênico, DPOC exacerbação, hipoxemia leve-mod (SpO2 <92% com O2 convencional).'),
          _PrescItem('Início CPAP', isEs ? 'CPAP 5–8 cmH2O + FiO2 40–60%. Reavaliação em 30–60 min.' : 'CPAP 5–8 cmH2O + FiO2 40–60%. Reavaliação em 30–60 min.'),
          _PrescItem('BiPAP', isEs ? 'IPAP 12–20 / EPAP 4–8 cmH2O. FR backup 12–16/min.' : 'IPAP 12–20 / EPAP 4–8 cmH2O. FR backup 12–16/min.'),
          _PrescItem('Contra.', isEs ? 'Parada respiratória, incapacidade de proteger VA, vômitos, agitação severa, politrauma facial.' : 'Parada respiratória, incapacidade de proteger VA, vômitos, agitação severa, politrauma facial.'),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: level == 'ALTO'
                  ? const Color(0xFFCC2222).withValues(alpha: 0.10)
                  : const Color(0xFFC5A365).withValues(alpha: 0.12),
            ),
            child: Text(
              level,
              style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.2,
                color: level == 'ALTO'
                    ? const Color(0xFFCC2222)
                    : const Color(0xFFC5A365),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.of(context).textPrimary, letterSpacing: -0.3))),
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
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1F6B48))),
            ),
            Expanded(child: Text(item.desc,
              style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary, height: 1.45))),
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.of(context).darkBtn),
            child: Icon(icon, size: 16, color: kToolGold),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.of(context).textPrimary, letterSpacing: -0.3))),
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
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.of(context).textHint)),
      const SizedBox(height: 5),
      MedInput(
        controller: ctrl,
        hintText: hint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 8 — PEDIATRIA
// ══════════════════════════════════════════════════════════════════
class PediatricsTabContent extends StatefulWidget {
  const PediatricsTabContent({super.key});
  @override
  State<PediatricsTabContent> createState() => _PediatricsTabContentState();
}

class _PediatricsTabContentState extends State<PediatricsTabContent> {
  int _section = 0;
  static const _sections = ['BIOMETRIA', 'SCHWARTZ', 'PEWS', 'DOSES', 'REFERÊNCIA'];

  // ── Controllers ────────────────────────────────────────────────
  // Biometria
  final _ageYCtrl  = TextEditingController(); // anos
  final _ageMCtrl  = TextEditingController(); // meses
  final _weightCtrl= TextEditingController(); // peso real
  final _heightCtrl= TextEditingController(); // altura cm

  // Schwartz
  final _swCrCtrl  = TextEditingController();
  final _swHCtrl   = TextEditingController();
  final _swAgeCtrl = TextEditingController();

  // PEWS
  int _pewsBehavior    = 0;
  int _pewsCardio      = 0;
  int _pewsRespiratory = 0;

  // Doses — peso local (editável direto na aba, sincronizado com _weightCtrl)
  final _dosesWeightCtrl = TextEditingController();

  @override
  void dispose() {
    _ageYCtrl.dispose(); _ageMCtrl.dispose(); _weightCtrl.dispose(); _heightCtrl.dispose();
    _swCrCtrl.dispose(); _swHCtrl.dispose(); _swAgeCtrl.dispose();
    _dosesWeightCtrl.dispose();
    super.dispose();
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
  String _fmt(double? v, {int dec = 1}) {
    if (v == null || !v.isFinite) return '—';
    if (v >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(dec).replaceAll('.', ',');
  }

  // ── Estimativa de peso ──────────────────────────────────────────
  // Broselow / APLS: 2–10 anos → (idade+4)×2; >10 → 3×idade+7
  double? get _estWeight {
    final y = _n(_ageYCtrl);
    final m = _n(_ageMCtrl) ?? 0;
    if (y == null) return null;
    final totalMonths = y * 12 + m;
    if (totalMonths < 1) return null;
    if (totalMonths < 12) return (totalMonths / 2) + 4;          // < 1 ano
    final years = totalMonths / 12;
    if (years <= 10) return (years + 4) * 2;                    // APLS
    return 3 * years + 7;                                        // > 10 anos
  }

  // Peso ideal pediátrico (50º percentil OMS simplificado)
  double? get _idealWeight {
    final y = _n(_ageYCtrl); final m = _n(_ageMCtrl) ?? 0;
    if (y == null) return null;
    final months = y * 12 + m;
    if (months < 1)  return null;
    if (months <= 6) return 3.5 + months * 0.6;
    if (months <= 12) return 7.0 + (months - 6) * 0.35;
    final yrs = months / 12;
    if (yrs <= 10)  return (yrs + 4) * 2;
    return 3 * yrs + 7;
  }

  // IMC pediátrico
  double? get _bmi {
    final w = _n(_weightCtrl), h = _n(_heightCtrl);
    if (w == null || h == null || h <= 0) return null;
    return w / ((h / 100) * (h / 100));
  }

  String _bmiLabel(double? v, double? ageY) {
    if (v == null) return '';
    final a = ageY ?? 0;
    if (a < 2) return 'IMC não recomendado < 2 anos';
    if (v < 14) return '⚠ Desnutrição grave';
    if (v < 18) return '↓ Abaixo do peso';
    if (v < 25) return '✓ Eutrófico';
    if (v < 30) return '↑ Sobrepeso';
    return '↑↑ Obesidade';
  }

  // Superfície corporal (Mosteller)
  double? get _bsa {
    final w = _n(_weightCtrl) ?? _estWeight;
    final h = _n(_heightCtrl);
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return _sqrt((w * h) / 3600);
  }

  // Frequência cardíaca / respiratória normal por faixa
  String _hrNormal(double? y, double? m) {
    final months = (y ?? 0) * 12 + (m ?? 0);
    if (months < 1)   return '120–160 bpm';
    if (months < 12)  return '100–160 bpm';
    if (months < 36)  return '90–150 bpm';
    if (months < 72)  return '80–140 bpm';
    if (months < 144) return '70–120 bpm';
    return '60–100 bpm';
  }

  String _rrNormal(double? y, double? m) {
    final months = (y ?? 0) * 12 + (m ?? 0);
    if (months < 1)   return '30–60 irpm';
    if (months < 12)  return '25–50 irpm';
    if (months < 36)  return '20–40 irpm';
    if (months < 72)  return '18–30 irpm';
    if (months < 144) return '15–25 irpm';
    return '12–20 irpm';
  }

  String _pasSystNormal(double? y) {
    final yrs = y ?? 0;
    if (yrs < 1)   return '60–90 mmHg';
    if (yrs < 3)   return '75–100 mmHg';
    if (yrs < 7)   return '80–110 mmHg';
    if (yrs < 12)  return '85–120 mmHg';
    return '90–130 mmHg';
  }

  // PAS mín aceitável: 70 + (2 × idade anos)
  String _minPas(double? y) {
    if (y == null) return '—';
    return '${(70 + 2 * y).round()} mmHg';
  }

  // ── Schwartz (TFG pediátrica) ───────────────────────────────────
  // TFG = k × altura(cm) / Cr(mg/dL)
  // k: neonatos 0.45 / lactentes 0.45 / crianças 0.55 / meninas adol. 0.55 / meninos adol. 0.70
  double? get _schwartz {
    final cr = _n(_swCrCtrl), h = _n(_swHCtrl), age = _n(_swAgeCtrl);
    if (cr == null || h == null || cr <= 0 || h <= 0) return null;
    double k = 0.55;
    if (age != null) {
      if (age < 0.5) k = 0.45;
      else if (age < 2) k = 0.45;
      else if (age >= 13) k = 0.70; // meninos adolescentes (default)
    }
    return k * h / cr;
  }

  String _schwartzLabel(double? v) {
    if (v == null) return '';
    if (v >= 90) return '✓ Normal (≥90)';
    if (v >= 60) return 'Leve (60–89)';
    if (v >= 30) return '⚠ Moderada (30–59)';
    if (v >= 15) return 'GRAVE (15–29)';
    return 'FALÊNCIA (<15)';
  }

  // ── PEWS ────────────────────────────────────────────────────────
  int get _pewsTotal => _pewsBehavior + _pewsCardio + _pewsRespiratory;

  String _pewsRisk(int score) {
    if (score <= 1) return '✓ Baixo risco';
    if (score <= 3) return '⚠ Risco intermediário — Notificar equipe';
    if (score <= 5) return 'ALTO RISCO — Avaliar urgente';
    return 'CRÍTICO — Acionar UTI pediátrica';
  }

  Color _pewsColor(int score) {
    if (score <= 1) return const Color(0xFF065F46);
    if (score <= 3) return const Color(0xFFB45309);
    if (score <= 5) return const Color(0xFFCC2222);
    return const Color(0xFF7F1D1D);
  }

  Color _pewsBg(int score) {
    if (score <= 1) return const Color(0xFFECFDF5);
    if (score <= 3) return const Color(0xFFFFFBEB);
    if (score <= 5) return const Color(0xFFFFF0F0);
    return const Color(0xFFFEF2F2);
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final c    = AppColors.of(context);

    return Column(children: [
      // ── Sub-menu azul (igual ao header) — botões individuais full-width ──
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A2540), Color(0xFF103D70), Color(0xFF2563EB)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Row(
          children: List.generate(_sections.length, (i) {
            final active = _section == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _section = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: active
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.transparent,
                    border: Border.all(
                      color: active
                          ? Colors.white.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.18),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _sections[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),

      // ── Content ─────────────────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: _buildSection(isEs, c),
        ),
      ),
    ]);
  }

  Widget _buildSection(bool isEs, AppColors c) {
    switch (_section) {
      case 0: return _buildBiometria(isEs, c);
      case 1: return _buildSchwartz(isEs, c);
      case 2: return _buildPews(isEs, c);
      case 3: return _buildDoses(isEs, c);
      case 4: return _buildReferencia(isEs, c);
      default: return const SizedBox.shrink();
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SEÇÃO 1 — BIOMETRIA PEDIÁTRICA
  // ──────────────────────────────────────────────────────────────
  Widget _buildBiometria(bool isEs, AppColors c) {
    final ageY = _n(_ageYCtrl);
    final ageM = _n(_ageMCtrl);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(
        title: isEs ? 'Edad del Paciente' : 'Idade do Paciente',
        icon: Icons.child_care_rounded,
        child: Row(children: [
          Expanded(child: _LabeledInput(
            label: isEs ? 'Anos' : 'Anos',
            ctrl: _ageYCtrl,
            onChanged: (_) => setState(() {}),
            hint: '5',
          )),
          const SizedBox(width: 10),
          Expanded(child: _LabeledInput(
            label: isEs ? 'Meses (adicional)' : 'Meses (adicional)',
            ctrl: _ageMCtrl,
            onChanged: (_) => setState(() {}),
            hint: '0',
          )),
        ]),
      ),
      const SizedBox(height: 12),

      _SectionCard(
        title: isEs ? 'Antropometría' : 'Antropometria',
        icon: Icons.straighten_rounded,
        child: Column(children: [
          Row(children: [
            Expanded(child: _LabeledInput(
              label: isEs ? 'Peso real (kg)' : 'Peso real (kg)',
              ctrl: _weightCtrl,
              onChanged: (_) => setState(() {}),
              hint: '20',
            )),
            const SizedBox(width: 10),
            Expanded(child: _LabeledInput(
              label: isEs ? 'Altura (cm)' : 'Altura (cm)',
              ctrl: _heightCtrl,
              onChanged: (_) => setState(() {}),
              hint: '110',
            )),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _ResultTile(
              label: isEs ? 'Peso Estimado (APLS)' : 'Peso Estimado (APLS)',
              value: _fmt(_estWeight),
              unit: 'kg',
              note: _estWeight != null ? 'Fórmula: (idade+4)×2 / 3×idade+7' : null,
            )),
            const SizedBox(width: 10),
            Expanded(child: _ResultTile(
              label: isEs ? 'Peso Ideal (P50 OMS)' : 'Peso Ideal (P50 OMS)',
              value: _fmt(_idealWeight),
              unit: 'kg',
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ResultTile(
              label: 'IMC',
              value: _fmt(_bmi),
              unit: 'kg/m²',
              note: _bmiLabel(_bmi, ageY),
            )),
            const SizedBox(width: 10),
            Expanded(child: _ResultTile(
              label: isEs ? 'Sup. Corporal (Mosteller)' : 'Sup. Corporal (Mosteller)',
              value: _fmt(_bsa, dec: 2),
              unit: 'm²',
            )),
          ]),
        ]),
      ),
      const SizedBox(height: 12),

      _SectionCard(
        title: isEs ? 'Parámetros Vitales Normales' : 'Parâmetros Vitais Normais',
        icon: Icons.monitor_heart_rounded,
        child: Column(children: [
          _PedVitalRow(
            label: 'FC normal',
            value: _hrNormal(ageY, ageM),
            icon: Icons.favorite_rounded,
            color: const Color(0xFFCC2222),
          ),
          const SizedBox(height: 8),
          _PedVitalRow(
            label: 'FR normal',
            value: _rrNormal(ageY, ageM),
            icon: Icons.air_rounded,
            color: const Color(0xFF1D4ED8),
          ),
          const SizedBox(height: 8),
          _PedVitalRow(
            label: 'PAS normal',
            value: _pasSystNormal(ageY),
            icon: Icons.speed_rounded,
            color: const Color(0xFF065F46),
          ),
          const SizedBox(height: 8),
          _PedVitalRow(
            label: isEs ? 'PAS mín aceptable' : 'PAS mín aceitável',
            value: _minPas(ageY),
            icon: Icons.warning_rounded,
            color: const Color(0xFFD97706),
            note: isEs ? '70 + (2 × edad años)' : '70 + (2 × idade anos)',
          ),
          const SizedBox(height: 10),
          _InfoNote(text: isEs
              ? 'Valores para faixa etária calculada. Informe a idade para resultados específicos.'
              : 'Valores para a faixa etária calculada. Informe a idade para resultados específicos.'),
        ]),
      ),
    ]);
  }

  // ──────────────────────────────────────────────────────────────
  // SEÇÃO 2 — SCHWARTZ (TFG pediátrica)
  // ──────────────────────────────────────────────────────────────
  Widget _buildSchwartz(bool isEs, AppColors c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(
        title: isEs ? 'Schwartz — TFG Pediátrica' : 'Schwartz — TFG Pediátrica',
        icon: Icons.water_drop_rounded,
        child: Column(children: [
          Row(children: [
            Expanded(child: _LabeledInput(
              label: isEs ? 'Creatinina (mg/dL)' : 'Creatinina (mg/dL)',
              ctrl: _swCrCtrl,
              onChanged: (_) => setState(() {}),
              hint: '0,6',
            )),
            const SizedBox(width: 10),
            Expanded(child: _LabeledInput(
              label: isEs ? 'Altura (cm)' : 'Altura (cm)',
              ctrl: _swHCtrl,
              onChanged: (_) => setState(() {}),
              hint: '110',
            )),
          ]),
          const SizedBox(height: 10),
          _LabeledInput(
            label: isEs ? 'Edad (años)' : 'Idade (anos)',
            ctrl: _swAgeCtrl,
            onChanged: (_) => setState(() {}),
            hint: '8',
          ),
          const SizedBox(height: 14),
          _ResultTile(
            label: isEs ? 'TFG — Schwartz' : 'TFG — Schwartz',
            value: _fmt(_schwartz),
            unit: 'mL/min/1,73m²',
            note: _schwartzLabel(_schwartz),
            full: true,
          ),
          const SizedBox(height: 10),
          _InfoNote(text: isEs
              ? 'Fórmula: k × altura(cm) / Cr\nk = 0,45 (<2 anos) | 0,55 (2–12 anos / meninas adol.) | 0,70 (meninos >13 anos)'
              : 'Fórmula: k × altura(cm) / Cr\nk = 0,45 (<2 anos) | 0,55 (2–12 anos / meninas adol.) | 0,70 (meninos >13 anos)'),
        ]),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: isEs ? 'Estadios ERC Pediátrica' : 'Estadios DRC Pediátrica',
        icon: Icons.table_rows_rounded,
        child: Column(children: [
          _RenalGuideRow(label: '≥ 90',  status: 'G1 — Normal ou aumentada', ok: true),
          _RenalGuideRow(label: '60–89', status: 'G2 — Leve. Monitorar'),
          _RenalGuideRow(label: '30–59', status: 'G3 — Moderada. Ajuste frequente', warn: true),
          _RenalGuideRow(label: '15–29', status: 'G4 — Grave. Ajuste obrigatório', warn: true),
          _RenalGuideRow(label: '<15',   status: 'G5 — Falência renal', danger: true),
        ]),
      ),
    ]);
  }

  // ──────────────────────────────────────────────────────────────
  // SEÇÃO 3 — PEWS (Pediatric Early Warning Score)
  // ──────────────────────────────────────────────────────────────
  Widget _buildPews(bool isEs, AppColors c) {
    final total = _pewsTotal;
    final riskColor = _pewsColor(total);
    final riskBg    = _pewsBg(total);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Score total
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: riskBg,
          border: Border.all(color: riskColor.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: riskColor.withValues(alpha: 0.15),
              border: Border.all(color: riskColor.withValues(alpha: 0.4), width: 2),
            ),
            child: Center(child: Text('$total',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: riskColor))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PEWS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
              letterSpacing: 1.4, color: riskColor.withValues(alpha: 0.7))),
            const SizedBox(height: 3),
            Text(_pewsRisk(total), style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: riskColor)),
          ])),
        ]),
      ),

      _SectionCard(
        title: isEs ? 'Comportamiento' : 'Comportamento',
        icon: Icons.psychology_rounded,
        child: _PewsSelector(
          options: isEs
              ? ['Jugando / Apropiado (0)', 'Dormido (1)', 'Irritable (2)', 'Confuso / Reducida resp. al dolor (3)']
              : ['Brincando / Adequado (0)', 'Dormindo (1)', 'Irritável (2)', 'Confuso / Reduz. resp. a dor (3)'],
          value: _pewsBehavior,
          onChanged: (v) => setState(() => _pewsBehavior = v),
          referenceLines: isEs
              ? ['Alerta, interactivo, juega espontáneamente', 'Apropiado para la edad', 'Sin cambios en nivel de conciencia']
              : ['Alerta, interativo, brinca espontaneamente', 'Adequado para a idade', 'Sem alteração do nível de consciência'],
        ),
      ),
      const SizedBox(height: 10),

      _SectionCard(
        title: isEs ? 'Cardiovascular' : 'Cardiovascular',
        icon: Icons.favorite_rounded,
        child: _PewsSelector(
          options: isEs
              ? ['Normal para la edad (0)', 'FC ±20 bpm / TLL 3s (1)', 'FC ±30 bpm / TLL 4s / hipotensión (2)', 'FC ±40 bpm / TLL ≥5s / bradicardia (3)']
              : ['Normal para a idade (0)', 'FC ±20 bpm / TLL 3s (1)', 'FC ±30 bpm / TLL 4s / hipotensão (2)', 'FC ±40 bpm / TLL ≥5s / bradicardia (3)'],
          value: _pewsCardio,
          onChanged: (v) => setState(() => _pewsCardio = v),
          referenceLines: isEs
              ? ['RN: FC 120–160 | Lactante: 110–160 | 2–5a: 90–140', 'Preescolar: 80–120 | Escolar: 70–110 | Adolescente: 60–100', 'TLL ≤2s · PA normal para la edad · Pulso fuerte']
              : ['RN: FC 120–160 | Lactente: 110–160 | 2–5a: 90–140', 'Pré-escolar: 80–120 | Escolar: 70–110 | Adolescente: 60–100', 'TEC ≤2s · PA normal para a idade · Pulso forte'],
        ),
      ),
      const SizedBox(height: 10),

      _SectionCard(
        title: isEs ? 'Respiratorio' : 'Respiratório',
        icon: Icons.air_rounded,
        child: _PewsSelector(
          options: isEs
              ? ['Normal para la edad (0)', 'FR ±10 / FiO₂ ≥30% (1)', 'FR ±20 / retracción / FiO₂ ≥40% (2)', 'FR ±30 / tiraje grave / FiO₂ ≥50% (3)']
              : ['Normal para a idade (0)', 'FR ±10 / FiO₂ ≥30% (1)', 'FR ±20 / retração / FiO₂ ≥40% (2)', 'FR ±30 / tiragem grave / FiO₂ ≥50% (3)'],
          value: _pewsRespiratory,
          onChanged: (v) => setState(() => _pewsRespiratory = v),
          referenceLines: isEs
              ? ['RN: FR 40–60 | Lactante: 30–50 | 2–5a: 25–40', 'Preescolar: 20–30 | Escolar: 18–25 | Adolescente: 12–20', 'SpO₂ ≥95% en AA · Sin tiraje · Sin quejido']
              : ['RN: FR 40–60 | Lactente: 30–50 | 2–5a: 25–40', 'Pré-escolar: 20–30 | Escolar: 18–25 | Adolescente: 12–20', 'SpO₂ ≥95% em AR · Sem tiragem · Sem gemido'],
        ),
      ),
      const SizedBox(height: 12),

      _InfoNote(text: isEs
          ? '≤1 → Baixo risco  |  2–3 → Notificar médico  |  4–5 → Avaliação urgente  |  ≥6 → Acionar UTI'
          : '≤1 → Baixo risco  |  2–3 → Notificar médico  |  4–5 → Avaliação urgente  |  ≥6 → Acionar UTI'),
    ]);
  }

  // ──────────────────────────────────────────────────────────────
  // SEÇÃO 4 — DOSES PEDIÁTRICAS
  // ──────────────────────────────────────────────────────────────
  Widget _buildDoses(bool isEs, AppColors c) {
    // Peso: prioridade → campo local da aba Doses → Biometria → estimado
    final wLocal = _n(_dosesWeightCtrl);
    final w = wLocal ?? _n(_weightCtrl) ?? _estWeight;
    // Sincroniza campo Doses com Biometria se o local estiver vazio
    if (wLocal == null && _dosesWeightCtrl.text.isEmpty) {
      final bio = _n(_weightCtrl) ?? _estWeight;
      if (bio != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && _dosesWeightCtrl.text.isEmpty) {
            _dosesWeightCtrl.text = _fmt(bio, dec: 1);
          }
        });
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Campo de peso editável ───────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF065F46).withValues(alpha: 0.08),
          border: Border.all(color: const Color(0xFF065F46).withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.scale_rounded, size: 18, color: Color(0xFF065F46)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isEs ? 'Peso del paciente' : 'Peso do paciente',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46), letterSpacing: 0.3),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 32,
                child: TextField(
                  controller: _dosesWeightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                      color: Color(0xFF065F46)),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: isEs ? 'Ej: 25,0' : 'Ex: 25,0',
                    hintStyle: TextStyle(fontSize: 14, color:
                        const Color(0xFF065F46).withValues(alpha: 0.4)),
                    border: InputBorder.none,
                    suffix: const Text('kg', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46))),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          ),
          if (w != null) ...[const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF065F46).withValues(alpha: 0.12),
              ),
              child: Text('${_fmt(w)} kg',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                    color: Color(0xFF065F46))),
            )],
        ]),
      ),

      // ── Toque no fármaco para ver contraindicações ──────────────
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(Icons.touch_app_rounded, size: 13,
              color: const Color(0xFF065F46).withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          Text(
            isEs ? 'Toca un fármaco para ver contraindicaciones'
                 : 'Toque um fármaco para ver contraindicações',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                color: const Color(0xFF065F46).withValues(alpha: 0.8)),
          ),
        ]),
      ),

      _SectionCard(
        title: isEs ? 'Reanimación — PCR Pediátrica' : 'Reanimação — PCR Pediátrica',
        icon: Icons.emergency_rounded,
        child: Column(children: [
          _PedDoseRow(label: 'Adrenalina IV/IO', dose: '0,01 mg/kg', weight: w,
            mgPerKg: 0.01, unit: 'mg', maxDose: '1 mg', color: const Color(0xFFCC2222),
            contraindications: isEs
              ? ['Taquicardia ventricular sin FV', 'Hipertensión severa no controlada',
                 'Feocromocitoma (relativa)', 'Monitorización ECG continua obligatoria']
              : ['Taquicardia ventricular sem FV', 'Hipertensão severa não controlada',
                 'Feocromocitoma (relativa)', 'Monitorização ECG contínua obrigatória']),
          _PedDoseRow(label: 'Amiodarona IV/IO', dose: '5 mg/kg', weight: w,
            mgPerKg: 5.0, unit: 'mg', maxDose: '300 mg', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Bradicardia sinusal grave', 'Bloqueo AV de 2º y 3º grado sin marcapaso',
                 'Hipersensibilidad al yodo', 'Hipotensión severa', 'QT largo congénito']
              : ['Bradicardia sinusal grave', 'Bloqueio AV 2º e 3º grau sem marca-passo',
                 'Hipersensibilidade ao iodo', 'Hipotensão severa', 'QT longo congênito']),
          _PedDoseRow(label: 'Adenosina IV (TSV)', dose: '0,1 mg/kg', weight: w,
            mgPerKg: 0.1, unit: 'mg', maxDose: '6 mg', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Bloqueo AV 2º y 3º grado', 'Síndrome del seno enfermo',
                 'Asma bronquial (broncoespasmo)', 'Flutter/fibrilación auricular',
                 'Administrar en bolo IV rápido (bolus 1-2 s)']
              : ['Bloqueio AV 2º e 3º grau', 'Doença do nó sinusal',
                 'Asma brônquica (broncoespasmo)', 'Flutter/fibrilação atrial',
                 'Administrar em bolus IV rápido (1-2 s)']),
          _PedDoseRow(label: 'Atropina IV (bradicardia)', dose: '0,02 mg/kg', weight: w,
            mgPerKg: 0.02, unit: 'mg', maxDose: '0,5 mg', color: const Color(0xFF1D4ED8),
            contraindications: isEs
              ? ['Glaucoma de ángulo cerrado', 'Taquicardia sinusal', 'Miastenia gravis',
                 'Dosis mínima 0,1 mg (dosis menores → bradicardia paradójica)',
                 'Íleo paralítico / obstrucción intestinal']
              : ['Glaucoma de ângulo fechado', 'Taquicardia sinusal', 'Miastenia gravis',
                 'Dose mínima 0,1 mg (doses menores → bradicardia paradoxal)',
                 'Íleo paralítico / obstrução intestinal']),
          _PedDoseRow(label: 'Glicose 10% IV (hipoglicemia)', dose: '2–5 mL/kg', weight: w,
            mgPerKg: 3.0, unit: 'mL', maxDose: '250 mL', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['Hiperglucemia (BGL > 180 mg/dL)', 'Confirmar hipoglucemia antes de administrar',
                 'Acceso venoso periférico preferible (osmolaridade 556 mOsm/L)']
              : ['Hiperglicemia (BGL > 180 mg/dL)', 'Confirmar hipoglicemia antes de administrar',
                 'Acesso venoso periférico preferível (osmolaridade 556 mOsm/L)']),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Dor ────────────────────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Analgesia — Dolor' : 'Analgesia — Dor',
        icon: Icons.healing_rounded,
        child: Column(children: [
          _PedDoseRow(label: 'Paracetamol VO/VR', dose: '10–15 mg/kg q4–6h', weight: w,
            mgPerKg: 12.5, unit: 'mg', maxDose: '1000 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['Insuficiencia hepática grave', 'Hipersensibilidad al paracetamol',
                 'No superar 4 dosis/día', 'Evitar en neonatos < 32 semanas (ajustar dosis)']
              : ['Insuficiência hepática grave', 'Hipersensibilidade ao paracetamol',
                 'Não ultrapassar 4 doses/dia', 'Evitar em neonatos < 32 semanas (ajustar dose)']),
          _PedDoseRow(label: 'Ibuprofeno VO', dose: '5–10 mg/kg q6–8h', weight: w,
            mgPerKg: 7.5, unit: 'mg', maxDose: '400 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['< 6 meses de edad (contraindicado)', 'Insuficiencia renal / deshidratación',
                 'Úlcera péptica activa', 'Dengue (riesgo de sangrado)',
                 'Asma inducida por AINEs', 'Insuficiencia hepática']
              : ['< 6 meses de idade (contraindicado)', 'Insuficiência renal / desidratação',
                 'Úlcera péptica ativa', 'Dengue (risco de sangramento)',
                 'Asma induzida por AINEs', 'Insuficiência hepática']),
          _PedDoseRow(label: 'Dipirona/Metamizol VO/IV', dose: '15 mg/kg q6h', weight: w,
            mgPerKg: 15.0, unit: 'mg', maxDose: '1000 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['< 3 meses / < 5 kg (contraindicado IV)', 'Hipersensibilidad a pirazolonas',
                 'Porfiria hepática aguda', 'Riesgo de agranulocitosis (monitorizar CBC)',
                 'Hipotensión en administración IV rápida']
              : ['< 3 meses / < 5 kg (contraindicado IV)', 'Hipersensibilidade a pirazolonas',
                 'Porfiria hepática aguda', 'Risco de agranulocitose (monitorar hemograma)',
                 'Hipotensão em administração IV rápida']),
          _PedDoseRow(label: 'Morfina IV/SC', dose: '0,05–0,1 mg/kg q2–4h', weight: w,
            mgPerKg: 0.1, unit: 'mg', maxDose: '5 mg', color: const Color(0xFF7C3AED),
            contraindications: isEs
              ? ['< 6 meses (ajuste de dosis — alta sensibilidad)', 'Depresión respiratoria',
                 'Íleo paralítico', 'Hipertensión intracraneal aguda',
                 'Hipotensión severa', 'Antídoto: Naloxona 0,01 mg/kg IV']
              : ['< 6 meses (ajuste de dose — alta sensibilidade)', 'Depressão respiratória',
                 'Íleo paralítico', 'Hipertensão intracraniana aguda',
                 'Hipotensão severa', 'Antídoto: Naloxona 0,01 mg/kg IV']),
          _PedDoseRow(label: 'Tramadol VO/IV', dose: '1–2 mg/kg q4–6h', weight: w,
            mgPerKg: 1.5, unit: 'mg', maxDose: '100 mg', color: const Color(0xFF7C3AED),
            contraindications: isEs
              ? ['< 12 años VO (metabolizadores ultrarrápidos CYP2D6 — riesgo mortal)',
                 'Post-amigdalectomía / adenoidectomía (< 18 años)',
                 'Epilepsia no controlada', 'Depresión respiratoria', 'IMAO concomitante']
              : ['< 12 anos VO (metabolizadores ultrarrápidos CYP2D6 — risco fatal)',
                 'Pós-amigdalectomia / adenoidectomia (< 18 anos)',
                 'Epilepsia não controlada', 'Depressão respiratória', 'IMAO concomitante']),
          _PedDoseRow(label: 'Cetorolaco IV/IM', dose: '0,5 mg/kg q6h', weight: w,
            mgPerKg: 0.5, unit: 'mg', maxDose: '30 mg', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['< 2 años (contraindicado)', 'Insuficiencia renal', 'Úlcera péptica activa',
                 'Sangrado gastrointestinal activo', 'Máximo 5 días de uso']
              : ['< 2 anos (contraindicado)', 'Insuficiência renal', 'Úlcera péptica ativa',
                 'Sangramento gastrointestinal ativo', 'Máximo 5 dias de uso']),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Febre ──────────────────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Antitérmicos — Fiebre' : 'Antipiréticos — Febre',
        icon: Icons.thermostat_rounded,
        child: Column(children: [
          _PedDoseRow(label: 'Paracetamol VO/VR', dose: '10–15 mg/kg q4–6h', weight: w,
            mgPerKg: 12.5, unit: 'mg', maxDose: '1000 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['Insuficiencia hepática grave', 'No superar 5 dosis/día',
                 'Intervalo mínimo de 4h entre dosis']
              : ['Insuficiência hepática grave', 'Não ultrapassar 5 doses/dia',
                 'Intervalo mínimo de 4h entre doses']),
          _PedDoseRow(label: 'Ibuprofeno VO', dose: '5–10 mg/kg q6–8h', weight: w,
            mgPerKg: 7.5, unit: 'mg', maxDose: '400 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['< 6 meses (contraindicado)', 'Dengue — evitar AINEs',
                 'Deshidratación / hipovolemia', 'No combinar con otros AINEs']
              : ['< 6 meses (contraindicado)', 'Dengue — evitar AINEs',
                 'Desidratação / hipovolemia', 'Não combinar com outros AINEs']),
          _PedDoseRow(label: 'Dipirona VO/IV', dose: '15 mg/kg q6h', weight: w,
            mgPerKg: 15.0, unit: 'mg', maxDose: '500 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['< 3 meses / < 5 kg', 'Hipersensibilidad a pirazolonas',
                 'IV lenta (riesgo hipotensión)']
              : ['< 3 meses / < 5 kg', 'Hipersensibilidade a pirazolonas',
                 'IV lenta (risco hipotensão)']),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Descongestionantes / Respiratório ──────────────────────────
      _SectionCard(
        title: isEs ? 'Descongestionantes y Vía Aérea' : 'Descongestionantes e Via Aérea',
        icon: Icons.air_rounded,
        child: Column(children: [
          _PedDoseRow(label: 'Salbutamol inalatório (crise)', dose: '2,5–5 mg (nebulização)', weight: w,
            mgPerKg: null, unit: 'mg', maxDose: null, color: const Color(0xFF1D4ED8),
            contraindications: isEs
              ? ['Hipersensibilidad a salbutamol', 'Taquicardia no controlada',
                 'Monitorizar FC y SpO₂ durante nebulización',
                 'Preferir MDI + espaciador en < 5 años']
              : ['Hipersensibilidade ao salbutamol', 'Taquicardia não controlada',
                 'Monitorar FC e SpO₂ durante nebulização',
                 'Preferir MDI + espaçador em < 5 anos']),
          _PedDoseRow(label: 'Ipratrópio inalatório', dose: '250–500 mcg nebulização', weight: w,
            mgPerKg: null, unit: 'mcg', maxDose: null, color: const Color(0xFF1D4ED8),
            contraindications: isEs
              ? ['Hipersensibilidad a atropina / brometo', 'Glaucoma de ángulo cerrado',
                 'Retención urinaria / hipertrofia prostática']
              : ['Hipersensibilidade à atropina / brometo', 'Glaucoma de ângulo fechado',
                 'Retenção urinária / hipertrofia prostática']),
          _PedDoseRow(label: 'Adrenalina nebulizada (crupe)', dose: '0,5 mL/kg de 1:1000', weight: w,
            mgPerKg: null, unit: 'mL', maxDose: '5 mL', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Taquicardia > 200 bpm', 'Cardiopatía congénita cianótica',
                 'Observar 2–4h post-nebulización (efecto rebote)',
                 'No usar sin supervisión médica continua']
              : ['Taquicardia > 200 bpm', 'Cardiopatia congênita cianótica',
                 'Observar 2–4h pós-nebulização (efeito rebote)',
                 'Não usar sem supervisão médica contínua']),
          _PedDoseRow(label: 'Dexametasona VO/IM (crupe)', dose: '0,15–0,6 mg/kg dose única', weight: w,
            mgPerKg: 0.3, unit: 'mg', maxDose: '10 mg', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Infección viral sin indicación clínica', 'Infección bacteriana activa no tratada',
                 'Inmunosupresión severa (relativa)', 'Varicela activa']
              : ['Infecção viral sem indicação clínica', 'Infecção bacteriana ativa não tratada',
                 'Imunossupressão grave (relativa)', 'Varicela ativa']),
          _PedDoseRow(label: 'Prednisolona VO', dose: '1–2 mg/kg/dia ÷ 1–2x', weight: w,
            mgPerKg: 1.0, unit: 'mg', maxDose: '40 mg', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Infección fúngica sistémica', 'Varicela / Herpes activo',
                 'Vacunas vivas (evitar durante tratamiento)',
                 'Tuberculosis activa no tratada']
              : ['Infecção fúngica sistêmica', 'Varicela / Herpes ativo',
                 'Vacinas vivas (evitar durante o tratamento)',
                 'Tuberculose ativa não tratada']),
          _PedDoseRow(label: 'Solução Fisiológica nasal', dose: '2–3 gotas/narina q4–6h', weight: w,
            mgPerKg: null, unit: '', maxDose: null, color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['Sin contraindicaciones absolutas', 'Evitar en neonatos sin orientación',
                 'Primera línea en congestión nasal pediátrica']
              : ['Sem contraindicações absolutas', 'Evitar em neonatos sem orientação',
                 'Primeira linha na congestão nasal pediátrica']),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Sedação e Analgesia Procedural ────────────────────────────
      _SectionCard(
        title: isEs ? 'Sedación y Analgesia' : 'Sedação e Analgesia',
        icon: Icons.medication_rounded,
        child: Column(children: [
          _PedDoseRow(label: 'Midazolam IV/IM', dose: '0,05–0,1 mg/kg', weight: w,
            mgPerKg: 0.1, unit: 'mg', maxDose: '5 mg', color: const Color(0xFF7C3AED),
            contraindications: isEs
              ? ['Hipersensibilidad a benzodiacepinas', 'Glaucoma de ángulo cerrado',
                 'Depresión respiratoria severa', 'Antídoto: Flumazenil 0,01 mg/kg IV',
                 'Monitorizar SpO₂ continuamente']
              : ['Hipersensibilidade a benzodiazepinas', 'Glaucoma de ângulo fechado',
                 'Depressão respiratória grave', 'Antídoto: Flumazenil 0,01 mg/kg IV',
                 'Monitorar SpO₂ continuamente']),
          _PedDoseRow(label: 'Cetamina IV', dose: '1–2 mg/kg (procedimentos)', weight: w,
            mgPerKg: 1.5, unit: 'mg', maxDose: '200 mg', color: const Color(0xFF7C3AED),
            contraindications: isEs
              ? ['Hipertensión intracraneal (TEC grave)', 'Psicosis activa',
                 'Eclampsia / preeclampsia', 'Cirugía de laringe/tráquea (laringoespasmo)',
                 'Asociar con midazolam para prevenir alucinaciones']
              : ['Hipertensão intracraniana (TCE grave)', 'Psicose ativa',
                 'Eclâmpsia / pré-eclâmpsia', 'Cirurgia de laringe/traqueia (laringoespasmo)',
                 'Associar com midazolam para prevenir alucinações']),
          _PedDoseRow(label: 'Fentanil IV', dose: '1–2 mcg/kg', weight: w,
            mgPerKg: 0.0015, unit: 'mg', maxDose: '100 mcg', color: const Color(0xFF7C3AED),
            contraindications: isEs
              ? ['Depresión respiratoria', 'Hipotensión severa',
                 'Rigidez torácica ("tórax leñoso") con dosis altas — usar lentamente',
                 'Antídoto: Naloxona 0,01 mg/kg IV']
              : ['Depressão respiratória', 'Hipotensão severa',
                 'Rigidez torácica ("tórax lenhoso") com doses altas — administrar lentamente',
                 'Antídoto: Naloxona 0,01 mg/kg IV']),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Antibióticos ───────────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Antibióticos Pediátricos' : 'Antibióticos Pediátricos',
        icon: Icons.science_rounded,
        child: Column(children: [
          _PedDoseRow(label: 'Amoxicilina VO', dose: '40–90 mg/kg/dia ÷ 3x', weight: w,
            mgPerKg: 50.0, unit: 'mg', maxDose: '3000 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['Alergia a penicilinas', 'Mononucleosis (rash generalizado)',
                 'Insuficiencia renal grave (ajustar dosis)']
              : ['Alergia a penicilinas', 'Mononucleose (rash generalizado)',
                 'Insuficiência renal grave (ajustar dose)']),
          _PedDoseRow(label: 'Amox-Clavulanato VO', dose: '40–90 mg/kg/dia ÷ 2–3x', weight: w,
            mgPerKg: 45.0, unit: 'mg', maxDose: '1500 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['Alergia a penicilinas / clavulanato', 'Hepatitis colestásica previa por amox-clav',
                 'Mononucleosis infecciosa', 'Ajustar en insuficiencia renal']
              : ['Alergia a penicilinas / clavulanato', 'Hepatite colestática prévia por amox-clav',
                 'Mononucleose infecciosa', 'Ajustar em insuficiência renal']),
          _PedDoseRow(label: 'Azitromicina VO', dose: '10 mg/kg/dia 1x (3–5d)', weight: w,
            mgPerKg: 10.0, unit: 'mg', maxDose: '500 mg', color: const Color(0xFF1D4ED8),
            contraindications: isEs
              ? ['Hipersensibilidad a macrólidos', 'QT largo / uso de otros fármacos QT',
                 'Insuficiencia hepática grave', 'Arritmia cardíaca preexistente']
              : ['Hipersensibilidade a macrolídeos', 'QT longo / uso de outros fármacos QT',
                 'Insuficiência hepática grave', 'Arritmia cardíaca preexistente']),
          _PedDoseRow(label: 'Ceftriaxona IV/IM', dose: '50–100 mg/kg/dia ÷ 1–2x', weight: w,
            mgPerKg: 50.0, unit: 'mg', maxDose: '4000 mg', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Alergia a cefalosporinas (precaución cruzada con penicilinas)',
                 'Neonatos ictéricos o prematuros (desplaza bilirrubina)',
                 'No mezclar con calcio IV (precipita en neonatos — riesgo de muerte)',
                 'Insuficiencia renal grave + hepática simultánea']
              : ['Alergia a cefalosporinas (precaução cruzada com penicilinas)',
                 'Neonatos ictéricos ou prematuros (desloca bilirrubina)',
                 'Não misturar com cálcio IV (precipita em neonatos — risco de morte)',
                 'Insuficiência renal grave + hepática simultânea']),
          _PedDoseRow(label: 'Cefalexina VO', dose: '25–50 mg/kg/dia ÷ 4x', weight: w,
            mgPerKg: 25.0, unit: 'mg', maxDose: '2000 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['Alergia a cefalosporinas', 'Insuficiencia renal (ajustar dosis)',
                 'Precaución en alérgicos a penicilinas (5–10% reacción cruzada)']
              : ['Alergia a cefalosporinas', 'Insuficiência renal (ajustar dose)',
                 'Precaução em alérgicos a penicilinas (5–10% reação cruzada)']),
          _PedDoseRow(label: 'Sulfametoxazol-Trimetoprim VO', dose: '8 mg/kg/dia (TMP) ÷ 2x', weight: w,
            mgPerKg: 8.0, unit: 'mg', maxDose: '320 mg', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['< 2 meses (kernicterus neonatal)', 'Insuficiencia renal grave',
                 'Deficiencia de G6PD', 'Hipersensibilidad a sulfonamidas',
                 'Embarazo (1º y 3º trimestre)', 'Monitorizar CBC en uso prolongado']
              : ['< 2 meses (kernicterus neonatal)', 'Insuficiência renal grave',
                 'Deficiência de G6PD', 'Hipersensibilidade a sulfonamidas',
                 'Monitorar hemograma em uso prolongado']),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Crise Convulsiva ───────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Crisis Convulsiva' : 'Crise Convulsiva',
        icon: Icons.bolt_rounded,
        child: Column(children: [
          _PedDoseRow(label: 'Diazepam IV (1ª linha)', dose: '0,2–0,5 mg/kg', weight: w,
            mgPerKg: 0.3, unit: 'mg', maxDose: '10 mg', color: const Color(0xFF1D4ED8),
            contraindications: isEs
              ? ['Depresión respiratoria severa', 'Glaucoma de ángulo cerrado',
                 'Antídoto: Flumazenil 0,01 mg/kg IV', 'IV lento: riesgo de apnea']
              : ['Depressão respiratória grave', 'Glaucoma de ângulo fechado',
                 'Antídoto: Flumazenil 0,01 mg/kg IV', 'IV lento: risco de apneia']),
          _PedDoseRow(label: 'Midazolam IM/IO (1ª linha)', dose: '0,2 mg/kg', weight: w,
            mgPerKg: 0.2, unit: 'mg', maxDose: '10 mg', color: const Color(0xFF1D4ED8),
            contraindications: isEs
              ? ['Depresión respiratoria', 'Hipotensión severa',
                 'Antídoto: Flumazenil 0,01 mg/kg', 'Monitorizar SpO₂']
              : ['Depressão respiratória', 'Hipotensão severa',
                 'Antídoto: Flumazenil 0,01 mg/kg', 'Monitorar SpO₂']),
          _PedDoseRow(label: 'Fenitoína IV (2ª linha)', dose: '20 mg/kg', weight: w,
            mgPerKg: 20.0, unit: 'mg', maxDose: '1000 mg', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Bradicardia sinusal / bloqueo AV', 'Síndrome de Adams-Stokes',
                 'Infusión lenta < 1 mg/kg/min (arritmia y hipotensión)',
                 'No mezclar con glucosa (precipita)', 'Extravasación → necrosis tisular']
              : ['Bradicardia sinusal / bloqueio AV', 'Síndrome de Adams-Stokes',
                 'Infusão lenta < 1 mg/kg/min (arritmia e hipotensão)',
                 'Não misturar com glicose (precipita)', 'Extravasamento → necrose tissular']),
          _PedDoseRow(label: 'Fenobarbital IV (2ª linha)', dose: '20 mg/kg', weight: w,
            mgPerKg: 20.0, unit: 'mg', maxDose: '1000 mg', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Depresión respiratoria grave (riesgo de apnea)', 'Porfiria aguda',
                 'Insuficiencia hepática grave', 'Hipotensión — infusión lenta']
              : ['Depressão respiratória grave (risco de apneia)', 'Porfiria aguda',
                 'Insuficiência hepática grave', 'Hipotensão — infusão lenta']),
          _PedDoseRow(label: 'Levetiracetam IV (2ª linha)', dose: '60 mg/kg', weight: w,
            mgPerKg: 60.0, unit: 'mg', maxDose: '3000 mg', color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Hipersensibilidad al levetiracetam', 'Insuficiencia renal grave (ajustar)',
                 'Monitorizar comportamiento: agitación, psicosis en niños']
              : ['Hipersensibilidade ao levetiracetam', 'Insuficiência renal grave (ajustar)',
                 'Monitorar comportamento: agitação, psicose em crianças']),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Vasopressores ──────────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Vasopresores y Líquidos' : 'Vasopressores e Fluidos',
        icon: Icons.water_rounded,
        child: Column(children: [
          _PedDoseRow(label: 'SF 0,9% bolus (choque)', dose: '10–20 mL/kg', weight: w,
            mgPerKg: 15.0, unit: 'mL', maxDose: '500 mL', color: const Color(0xFF065F46),
            contraindications: isEs
              ? ['Insuficiencia cardíaca congestiva descompensada', 'Edema pulmonar',
                 'Monitorizar auscultación y SpO₂ durante expansión']
              : ['Insuficiência cardíaca congestiva descompensada', 'Edema pulmonar',
                 'Monitorar ausculta e SpO₂ durante expansão']),
          _PedDoseRow(label: 'Noradrenalina (dose início)', dose: '0,1 mcg/kg/min', weight: w,
            mgPerKg: null, unit: 'mcg/kg/min', maxDose: null, color: const Color(0xFFCC2222),
            contraindications: isEs
              ? ['Hipovolemia no corregida', 'Trombosis vascular mesentérica / periférica',
                 'Acceso venoso central preferido (extravasación → necrosis)',
                 'Antídoto extravasación: fentolamina local']
              : ['Hipovolemia não corrigida', 'Trombose vascular mesentérica / periférica',
                 'Acesso venoso central preferido (extravasamento → necrose)',
                 'Antídoto extravasamento: fentolamina local']),
          _PedDoseRow(label: 'Dopamina (dose renal)', dose: '2–5 mcg/kg/min', weight: w,
            mgPerKg: null, unit: 'mcg/kg/min', maxDose: null, color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Feocromocitoma', 'Fibrilación ventricular', 'Taquiarritmias no tratadas',
                 'Monitorización ECG continua', 'Acceso venoso central preferido']
              : ['Feocromocitoma', 'Fibrilação ventricular', 'Taquiarritmias não tratadas',
                 'Monitorização ECG contínua', 'Acesso venoso central preferido']),
          _PedDoseRow(label: 'Dobutamina (inotrópico)', dose: '5–20 mcg/kg/min', weight: w,
            mgPerKg: null, unit: 'mcg/kg/min', maxDose: null, color: const Color(0xFFD97706),
            contraindications: isEs
              ? ['Obstrucción subaórtica hipertrófica', 'Fibrilación auricular (aumenta FC)',
                 'Hipovolemia no corregida', 'Monitorización ECG y PA invasiva']
              : ['Obstrução subaórtica hipertrófica', 'Fibrilação atrial (aumenta FC)',
                 'Hipovolemia não corrigida', 'Monitorização ECG e PA invasiva']),
        ]),
      ),
      const SizedBox(height: 12),

      _InfoNote(text: isEs
          ? '⚠ Doses calculadas para referência. Confirmar com farmácia pediátrica. Limite pela dose máxima informada.'
          : '⚠ Doses calculadas para referência. Confirmar com farmácia pediátrica. Limite pela dose máxima informada.'),
    ]);
  }

  // ──────────────────────────────────────────────────────────────
  // SEÇÃO 5 — VALORES DE REFERÊNCIA PEDIÁTRICOS
  // ──────────────────────────────────────────────────────────────
  Widget _buildReferencia(bool isEs, AppColors c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionCard(
        title: isEs ? 'Hemograma Pediátrico' : 'Hemograma Pediátrico',
        icon: Icons.bloodtype_rounded,
        child: Column(children: [
          _PedRefHeader(),
          _PedRefRow(param: 'Hb (g/dL)',    neo: '14–22', lac: '10–15', cri: '11–14', ado: '12–16'),
          _PedRefRow(param: 'Ht (%)',        neo: '42–65', lac: '31–41', cri: '33–42', ado: '36–50'),
          _PedRefRow(param: 'Leuc (×10³)',   neo: '9–30',  lac: '6–17',  cri: '5–14',  ado: '4–11'),
          _PedRefRow(param: 'Neut (%)',      neo: '40–80', lac: '20–50', cri: '30–60', ado: '40–70'),
          _PedRefRow(param: 'Linf (%)',      neo: '20–40', lac: '40–70', cri: '30–60', ado: '20–45'),
          _PedRefRow(param: 'Plaq (×10³)',   neo: '150–400', lac: '150–400', cri: '150–400', ado: '150–400'),
        ]),
      ),
      const SizedBox(height: 12),

      _SectionCard(
        title: isEs ? 'Bioquímica Pediátrica' : 'Bioquímica Pediátrica',
        icon: Icons.science_rounded,
        child: Column(children: [
          _PedRefHeader(),
          _PedRefRow(param: 'Glicose (mg/dL)', neo: '45–100', lac: '60–100', cri: '70–110', ado: '70–110'),
          _PedRefRow(param: 'Na (mEq/L)',       neo: '133–146', lac: '133–146', cri: '135–145', ado: '135–145'),
          _PedRefRow(param: 'K (mEq/L)',        neo: '3,5–5,5', lac: '3,5–5,0', cri: '3,5–5,0', ado: '3,5–5,0'),
          _PedRefRow(param: 'Ca total (mg/dL)', neo: '7–11',  lac: '9–11',  cri: '9–11',  ado: '8,5–10,5'),
          _PedRefRow(param: 'Creat (mg/dL)',    neo: '0,3–1,0', lac: '0,2–0,5', cri: '0,3–0,7', ado: '0,5–1,2'),
          _PedRefRow(param: 'Ureia (mg/dL)',    neo: '5–25',  lac: '5–20',  cri: '8–25',  ado: '10–40'),
          _PedRefRow(param: 'BT (mg/dL)',       neo: '1–12',  lac: '0–1,0', cri: '0–1,0', ado: '0–1,2'),
          _PedRefRow(param: 'TGO (U/L)',        neo: '10–80', lac: '20–60', cri: '15–45', ado: '10–40'),
          _PedRefRow(param: 'TGP (U/L)',        neo: '5–45',  lac: '10–50', cri: '10–45', ado: '7–56'),
        ]),
      ),
      const SizedBox(height: 12),

      _SectionCard(
        title: isEs ? 'Gasometría Pediátrica' : 'Gasometria Pediátrica',
        icon: Icons.air_rounded,
        child: Column(children: [
          _PedRefRow2(param: 'pH',           value: '7,35 – 7,45'),
          _PedRefRow2(param: 'PaCO₂ (mmHg)', value: '35 – 45'),
          _PedRefRow2(param: 'PaO₂ (mmHg)',  value: '80 – 100'),
          _PedRefRow2(param: 'HCO₃ (mEq/L)', value: '22 – 26'),
          _PedRefRow2(param: 'BE',            value: '−3 a +3'),
          _PedRefRow2(param: 'SatO₂',        value: '≥ 95%'),
          const SizedBox(height: 6),
          _InfoNote(text: isEs
              ? 'Valores gasométricos similares aos adultos. Neonatos: PaCO₂ pode ser 35–45, HCO₃ 20–26.'
              : 'Valores gasométricos similares aos adultos. Neonatos: PaCO₂ pode ser 35–45, HCO₃ 20–26.'),
        ]),
      ),
      const SizedBox(height: 12),

      _SectionCard(
        title: isEs ? 'Tubos y Accesos' : 'Tubos e Acessos',
        icon: Icons.medical_services_rounded,
        child: Column(children: [
          _PedRefRow2(param: 'TOT (Cuffless < 8a)', value: '(idade/4) + 4'),
          _PedRefRow2(param: 'TOT (Cuffed)',         value: '(idade/4) + 3,5'),
          _PedRefRow2(param: 'Profundidade TOT',     value: 'N° tubo × 3 cm'),
          _PedRefRow2(param: 'Sonda nasogástrica',   value: 'Peso (kg) + 12 cm'),
          _PedRefRow2(param: 'Cateter IO',           value: 'Tíbia proximal / distal'),
          _PedRefRow2(param: 'Desfibrilação',        value: '2 J/kg → 4 J/kg (máx 200 J)'),
          _PedRefRow2(param: 'Cardioversão sinc.',   value: '0,5–1 J/kg → 2 J/kg'),
        ]),
      ),
    ]);
  }
}

// ── Widgets auxiliares de Pediatria ───────────────────────────────────────────

class _PedVitalRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? note;
  const _PedVitalRow({required this.label, required this.value, required this.icon, required this.color, this.note});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: c.textHint)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!, style: TextStyle(fontSize: 10, color: c.textHint)),
          ],
        ])),
      ]),
    );
  }
}

class _PedDoseRow extends StatefulWidget {
  final String label, dose;
  final double? weight, mgPerKg;
  final String unit;
  final String? maxDose;
  final Color color;
  final List<String> contraindications; // contraindicações expansíveis

  const _PedDoseRow({
    required this.label, required this.dose, required this.weight,
    required this.mgPerKg, required this.unit, required this.maxDose,
    required this.color,
    this.contraindications = const [],
  });

  @override
  State<_PedDoseRow> createState() => _PedDoseRowState();
}

class _PedDoseRowState extends State<_PedDoseRow> {
  bool _expanded = false;

  String _calcDose() {
    if (widget.weight == null || widget.mgPerKg == null) return '—';
    double raw = widget.weight! * widget.mgPerKg!;
    if (widget.maxDose != null) {
      final maxNum = double.tryParse(
          widget.maxDose!.replaceAll(RegExp(r'[^\d,\.]'), '').replaceAll(',', '.'));
      if (maxNum != null && raw > maxNum) raw = maxNum;
    }
    final result = raw >= 100
        ? '${raw.toStringAsFixed(0)} ${widget.unit}'
        : '${raw.toStringAsFixed(1).replaceAll('.', ',')} ${widget.unit}';
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final calcDose = _calcDose();
    final hasContra = widget.contraindications.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: hasContra ? () => setState(() => _expanded = !_expanded) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _expanded
                ? widget.color.withValues(alpha: 0.11)
                : widget.color.withValues(alpha: 0.06),
            border: Border.all(
              color: _expanded
                  ? widget.color.withValues(alpha: 0.45)
                  : widget.color.withValues(alpha: 0.2),
              width: _expanded ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(widget.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: c.textPrimary))),
                    if (hasContra) ...[
                      const SizedBox(width: 6),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.info_outline_rounded,
                        size: 14, color: widget.color.withValues(alpha: 0.7)),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(widget.dose, style: TextStyle(fontSize: 10, color: c.textHint)),
                  if (widget.maxDose != null)
                    Text('máx: ${widget.maxDose}',
                        style: TextStyle(fontSize: 9, color: c.textHint)),
                ])),
                if (widget.weight != null && widget.mgPerKg != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: widget.color.withValues(alpha: 0.13),
                    ),
                    child: Text(calcDose, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900, color: widget.color)),
                  ),
                ],
              ]),

              // Painel de contraindicações expansível
              if (_expanded && hasContra) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFCC2222).withValues(alpha: 0.07),
                    border: Border.all(
                        color: const Color(0xFFCC2222).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.block_rounded, size: 12,
                            color: Color(0xFFCC2222)),
                        const SizedBox(width: 5),
                        Text('Contraindicações / Precauções',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: const Color(0xFFCC2222).withValues(alpha: 0.9),
                              letterSpacing: 0.2,
                            )),
                      ]),
                      const SizedBox(height: 6),
                      ...widget.contraindications.map((ci) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(
                                fontSize: 10, color: Color(0xFFCC2222))),
                            Expanded(child: Text(ci, style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w500,
                                color: Color(0xFFCC2222), height: 1.4))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PedRefHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const SizedBox(width: 90),
        Expanded(child: Text('Neonato', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.textHint, letterSpacing: 0.5), textAlign: TextAlign.center)),
        Expanded(child: Text('Lactente', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.textHint, letterSpacing: 0.5), textAlign: TextAlign.center)),
        Expanded(child: Text('Criança', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.textHint, letterSpacing: 0.5), textAlign: TextAlign.center)),
        Expanded(child: Text('Adolesc.', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.textHint, letterSpacing: 0.5), textAlign: TextAlign.center)),
      ]),
    );
  }
}

class _PedRefRow extends StatelessWidget {
  final String param, neo, lac, cri, ado;
  const _PedRefRow({required this.param, required this.neo, required this.lac, required this.cri, required this.ado});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        SizedBox(width: 90, child: Text(param, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.textPrimary))),
        Expanded(child: Text(neo, style: TextStyle(fontSize: 9, color: c.textSecondary), textAlign: TextAlign.center)),
        Expanded(child: Text(lac, style: TextStyle(fontSize: 9, color: c.textSecondary), textAlign: TextAlign.center)),
        Expanded(child: Text(cri, style: TextStyle(fontSize: 9, color: c.textSecondary), textAlign: TextAlign.center)),
        Expanded(child: Text(ado, style: TextStyle(fontSize: 9, color: c.textSecondary), textAlign: TextAlign.center)),
      ]),
    );
  }
}

class _PedRefRow2 extends StatelessWidget {
  final String param, value;
  const _PedRefRow2({required this.param, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        Expanded(child: Text(param, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF065F46))),
      ]),
    );
  }
}

class _PewsSelector extends StatelessWidget {
  final List<String> options;
  final int value;
  final ValueChanged<int> onChanged;
  final List<String> referenceLines; // linhas de referência clínica normal

  const _PewsSelector({
    required this.options,
    required this.value,
    required this.onChanged,
    this.referenceLines = const [],
  });

  // Paleta por índice: 0=azul (normal), 1=amarelo, 2=laranja-vermelho, 3=vermelho escuro
  static const _kColors = [
    Color(0xFF1D4ED8), // azul — normal / pontuação 0
    Color(0xFFB45309), // âmbar — leve
    Color(0xFFCC2222), // vermelho — moderado
    Color(0xFF7F1D1D), // vinho — grave
  ];

  // Fundo azul claro para o card selecionado score=0
  static const _kBlueBg   = Color(0xFF1D4ED8);
  static const _kBlueBgLt = Color(0xFFEFF6FF); // tema claro

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(children: List.generate(options.length, (i) {
      final sel      = value == i;
      final dotColor = _kColors[i.clamp(0, 3)];
      final isNormal = i == 0;

      return GestureDetector(
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 6),
          padding: EdgeInsets.fromLTRB(14, sel && isNormal ? 12 : 10, 14, sel && isNormal ? 12 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Selecionado normal → azul sólido; outros → cor da severidade
            color: sel
                ? (isNormal
                    ? _kBlueBg.withValues(alpha: 0.12)
                    : dotColor.withValues(alpha: 0.10))
                : c.surface,
            border: Border.all(
              color: sel
                  ? dotColor.withValues(alpha: isNormal ? 0.70 : 0.50)
                  : c.border,
              width: sel ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Ícone check / círculo
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? dotColor : Colors.transparent,
                    border: Border.all(
                      color: sel ? dotColor : c.border, width: 1.5),
                  ),
                  child: sel
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(options[i], style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                  color: sel ? dotColor : c.textSecondary,
                ))),
                // Badge de pontuação
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: sel
                        ? dotColor.withValues(alpha: 0.15)
                        : c.border.withValues(alpha: 0.4),
                  ),
                  child: Text(
                    '+$i pt',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: sel ? dotColor : c.textSecondary,
                    ),
                  ),
                ),
              ]),

              // Referências clínicas — só aparecem quando este card está selecionado e é o normal (i==0)
              if (sel && isNormal && referenceLines.isNotEmpty) ...
                [const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _kBlueBg.withValues(alpha: 0.08),
                    border: Border.all(
                      color: _kBlueBg.withValues(alpha: 0.20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline_rounded,
                            size: 11, color: _kBlueBg.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text('Valores de referência normais',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: _kBlueBg.withValues(alpha: 0.8),
                            )),
                      ]),
                      const SizedBox(height: 5),
                      ...referenceLines.map((line) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(
                              fontSize: 10, color: _kBlueBg.withValues(alpha: 0.6))),
                            Expanded(child: Text(line, style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _kBlueBg.withValues(alpha: 0.85),
                              height: 1.4,
                            ))),
                          ],
                        ),
                      )),
                    ],
                  ),
                )],
            ],
          ),
        ),
      );
    }));
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
    final hasVal  = value != null && value != '—';
    final dark    = Theme.of(context).brightness == Brightness.dark;
    final noteColor = (note ?? '').startsWith('BAIXO') || (note ?? '').startsWith('ATENÇÃO') || (note ?? '').startsWith('GRAVE') || (note ?? '').startsWith('CRÍTICO') || (note ?? '').startsWith('FALÊNCIA') || (note ?? '').startsWith('ALTO') || (note ?? '').startsWith('DÉFICIT')
        ? const Color(0xFFCC2222)
        : (note ?? '').startsWith('RISCO') || (note ?? '').contains('↑') || (note ?? '').contains('Hipercalcemia')
        ? const Color(0xFFB45309)
        : (dark ? const Color(0xFF34D399) : const Color(0xFF065F46));

    // Cores adaptativas ao tema:
    //  Modo claro: fundo verde-menta suave (0xFFECFDF5) — padrão original
    //  Modo escuro: fundo verde escuro sutil (0xFF0D2B1E) — hierarquia clara
    final tileBg     = hasVal
        ? (dark ? const Color(0xFF0D2B1E) : const Color(0xFFECFDF5))
        : AppColors.of(context).surface;
    final tileBorder = hasVal
        ? (dark ? const Color(0xFF1A4D35) : const Color(0xFFBBF7D0))
        : AppColors.of(context).border;
    // Valor numérico: no dark mode usa verde-menta vibrante para destacar
    final valueColor = hasVal
        ? (dark ? const Color(0xFF6EE7B7) : AppColors.of(context).textPrimary)
        : (dark ? const Color(0xFF4B5563) : const Color(0xFFCCCCCC));

    return Container(
      width: full ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: tileBg,
        border: Border.all(color: tileBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.of(context).textHint)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: Text(value ?? '—',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
              color: valueColor, letterSpacing: -0.5))),
          if (unit != null && unit!.isNotEmpty && hasVal) ...[
            const SizedBox(width: 3),
            Padding(padding: const EdgeInsets.only(bottom: 2),
              child: Text(unit!, style: TextStyle(fontSize: 10, color: AppColors.of(context).textHint))),
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

// Linha de referência bibliográfica dentro do card de resultado da infusão
class _RefLine extends StatelessWidget {
  final String text;
  const _RefLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.48),
        fontStyle: FontStyle.italic,
        height: 1.5,
      ),
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
    final txtColor= danger ? const Color(0xFFCC2222) : warn ? const Color(0xFFB45309) : ok ? const Color(0xFF065F46) : AppColors.of(context).textPrimary;
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
