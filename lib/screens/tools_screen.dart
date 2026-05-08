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
    _tabCtrl = TabController(length: 5, vsync: this);
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
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kToolBorder), color: Colors.white),
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: kToolBorder), color: Colors.white),
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: kToolBorder), color: Colors.white),
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
  final _phCtrl   = TextEditingController();
  final _pco2Ctrl = TextEditingController();
  final _beCtrl   = TextEditingController();
  final _wCtrl    = TextEditingController();

  @override
  void dispose() {
    for (final c in [_naCtrl, _clCtrl, _hco3Ctrl, _glucCtrl, _albumCtrl, _caCtrl, _phCtrl, _pco2Ctrl, _beCtrl, _wCtrl]) {
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
    final bun = 0.0;
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFFF8F8F8), border: Border.all(color: kToolBorder)),
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
  double pow(num exp) => _pow(this, exp);
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
