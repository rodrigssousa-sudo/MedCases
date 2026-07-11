// ══════════════════════════════════════════════════════════════════════════════
// cardio_tools_screen.dart — BUILD 415-UX-HARMONY
//
// CENTRAL DE CARDIOLOGIA — Interface nativa unificada ao Design System Premium.
//
// MOTORES MATEMÁTICOS:
//   1. PREVENT/ASCVD — risco cardiovascular 10 anos (modelo ponderado)
//   2. CHA₂DS₂-VASc — risco de AVC em FA (score por critérios)
//   3. HAS-BLED      — risco de sangramento em FA (score por critérios)
//   4. QTc Bazett    — intervalo QT corrigido pela FC
//
// INTERNACIONALIZAÇÃO: isEs (Português / Espanhol) em todas as strings.
// COMPLIANCE: zero condutas/prescrições nativas — delegado ao Suporte Web via deeplink.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta canônica MedCases Pro (dark-first) — espelhada de nephrology_tools_screen
// ─────────────────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F1116);
const _kSurface = Color(0xFF1A1D23);
const _kBorder  = Color(0xFF2D3340);
const _kCyan    = Color(0xFF00E5FF);
const _kGreen   = Color(0xFF10B981);
const _kAmber   = Color(0xFFF59E0B);
const _kRed     = Color(0xFFEF4444);
const _kPurple  = Color(0xFF8B5CF6);
const _kTextSub = Color(0xFF8B9BB4);

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────
class CardioToolsScreen extends StatelessWidget {
  const CardioToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return _CardioBody(isEs: p.lang == 'es', dark: p.darkMode);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typed immutable result
// ─────────────────────────────────────────────────────────────────────────────
class _CardioResult {
  final double preventRisk;   // % 10-year ASCVD
  final int    cha2Score;     // 0–9
  final int    hasbledScore;  // 0–9
  final double qtcMs;         // ms

  // Raw inputs preserved for deeplink payload
  final int    age;
  final bool   isFemale;
  final bool   hasDiabetes;
  final bool   isSmoker;
  final bool   hasHtn;
  final bool   hasCvDisease;
  final bool   hasChf;
  final bool   hasCkd;
  final bool   hadStroke;
  final bool   hasBleedHx;
  final bool   hasLabilInr;
  final bool   agePlus65;
  final bool   usesDrugsAlcohol;
  final double pas;
  final double colTotal;
  final double qtMs;
  final double fcBpm;

  const _CardioResult({
    required this.preventRisk,
    required this.cha2Score,
    required this.hasbledScore,
    required this.qtcMs,
    required this.age,
    required this.isFemale,
    required this.hasDiabetes,
    required this.isSmoker,
    required this.hasHtn,
    required this.hasCvDisease,
    required this.hasChf,
    required this.hasCkd,
    required this.hadStroke,
    required this.hasBleedHx,
    required this.hasLabilInr,
    required this.agePlus65,
    required this.usesDrugsAlcohol,
    required this.pas,
    required this.colTotal,
    required this.qtMs,
    required this.fcBpm,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure math engines
// ─────────────────────────────────────────────────────────────────────────────
class _CardioEngine {
  // PREVENT/ASCVD — modelo ponderado (aproximado) para triagem clínica
  static double _prevent({
    required bool isFemale,
    required bool hasDiabetes,
    required bool isSmoker,
    required bool hasHtn,
    required double pas,
    required double colTotal,
  }) {
    double base = 1.2;
    if (isSmoker)   base += 2.5;
    if (hasDiabetes) base += 3.1;
    if (hasHtn)     base += 1.8;
    base += (pas - 110).clamp(0, 90) * 0.15;
    base += (colTotal - 150).clamp(0, 250) * 0.05;
    if (isFemale) base *= 0.85;
    return base.clamp(0.5, 95.0);
  }

  // CHA₂DS₂-VASc (FA): max 9 pts
  static int _cha2({
    required bool hasChf,
    required bool hasHtn,
    required bool hasDiabetes,
    required bool hadStroke,   // +2
    required bool hasCvDisease,
    required bool isFemale,
    required int  age,
  }) {
    int s = 0;
    if (hasChf)       s += 1;
    if (hasHtn)       s += 1;
    if (hasDiabetes)  s += 1;
    if (hadStroke)    s += 2;
    if (hasCvDisease) s += 1;
    if (isFemale)     s += 1;
    if (age >= 75) {
      s += 2;
    } else if (age >= 65) {
      s += 1;
    }
    return s.clamp(0, 9);
  }

  // HAS-BLED: max 9 pts
  static int _hasbled({
    required bool hasHtn,        // PAS >160 mmHg
    required bool hasCkd,        // Cr >2,3 ou diálise
    required bool hadStroke,
    required bool hasBleedHx,
    required bool hasLabilInr,
    required bool agePlus65,
    required bool usesDrugsAlcohol, // antiplaquetários, AINEs ou ≥8 doses/sem
  }) {
    int s = 0;
    if (hasHtn)           s += 1;
    if (hasCkd)           s += 1;
    if (hadStroke)        s += 1;
    if (hasBleedHx)       s += 1;
    if (hasLabilInr)      s += 1;
    if (agePlus65)        s += 1;
    if (usesDrugsAlcohol) s += 1;
    return s.clamp(0, 9);
  }

  // QTc Bazett: QTc = QT / √(RR)   RR = 60/FC (em segundos)
  static double _qtc({required double qtMs, required double fcBpm}) {
    if (fcBpm <= 0) return 0;
    final rr = 60 / fcBpm;
    return (qtMs / 1000) / _sqrt(rr) * 1000;
  }

  static double _sqrt(double v) => v <= 0 ? 1.0 : v < 1e-12 ? 1.0 : v == 1.0 ? 1.0 : _dartSqrt(v);
  static double _dartSqrt(double v) {
    // Newton–Raphson (no dart:math import needed; avoids adding dependency)
    double x = v;
    for (int i = 0; i < 40; i++) {
      final nx = 0.5 * (x + v / x);
      if ((nx - x).abs() < 1e-10) return nx;
      x = nx;
    }
    return x;
  }

  static _CardioResult compute({
    required int    age,
    required bool   isFemale,
    required bool   hasDiabetes,
    required bool   isSmoker,
    required bool   hasHtn,
    required bool   hasCvDisease,
    required bool   hasChf,
    required bool   hasCkd,
    required bool   hadStroke,
    required bool   hasBleedHx,
    required bool   hasLabilInr,
    required bool   agePlus65,
    required bool   usesDrugsAlcohol,
    required double pas,
    required double colTotal,
    required double qtMs,
    required double fcBpm,
  }) {
    return _CardioResult(
      preventRisk:    _prevent(isFemale: isFemale, hasDiabetes: hasDiabetes, isSmoker: isSmoker, hasHtn: hasHtn, pas: pas, colTotal: colTotal),
      cha2Score:      _cha2(hasChf: hasChf, hasHtn: hasHtn, hasDiabetes: hasDiabetes, hadStroke: hadStroke, hasCvDisease: hasCvDisease, isFemale: isFemale, age: age),
      hasbledScore:   _hasbled(hasHtn: hasHtn, hasCkd: hasCkd, hadStroke: hadStroke, hasBleedHx: hasBleedHx, hasLabilInr: hasLabilInr, agePlus65: agePlus65, usesDrugsAlcohol: usesDrugsAlcohol),
      qtcMs:          _qtc(qtMs: qtMs, fcBpm: fcBpm),
      age: age, isFemale: isFemale, hasDiabetes: hasDiabetes, isSmoker: isSmoker,
      hasHtn: hasHtn, hasCvDisease: hasCvDisease, hasChf: hasChf, hasCkd: hasCkd,
      hadStroke: hadStroke, hasBleedHx: hasBleedHx, hasLabilInr: hasLabilInr,
      agePlus65: agePlus65, usesDrugsAlcohol: usesDrugsAlcohol,
      pas: pas, colTotal: colTotal, qtMs: qtMs, fcBpm: fcBpm,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main body — StatefulWidget with animation
// ─────────────────────────────────────────────────────────────────────────────
class _CardioBody extends StatefulWidget {
  final bool isEs;
  final bool dark;
  const _CardioBody({required this.isEs, required this.dark});

  @override
  State<_CardioBody> createState() => _CardioBodyState();
}

class _CardioBodyState extends State<_CardioBody>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _ageCtrl    = TextEditingController();
  final _pasCtrl    = TextEditingController();
  final _colCtrl    = TextEditingController();
  final _qtCtrl     = TextEditingController();
  final _fcCtrl     = TextEditingController();

  // ── Boolean risk factors ──────────────────────────────────────────────────
  bool _isFemale       = false;
  bool _hasDiabetes    = false;
  bool _isSmoker       = false;
  bool _hasHtn         = false;
  bool _hasCvDisease   = false;
  bool _hasChf         = false;
  bool _hasCkd         = false;
  bool _hadStroke      = false;
  bool _hasBleedHx     = false;
  bool _hasLabilInr    = false;
  bool _agePlus65      = false;
  bool _usesDrugsAlc   = false;

  // ── State ─────────────────────────────────────────────────────────────────
  _CardioResult? _result;
  final _formKey = GlobalKey<FormState>();

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _pasCtrl.dispose();
    _colCtrl.dispose();
    _qtCtrl.dispose();
    _fcCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double? _pd(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  String? _validatePositive(String? v) {
    if (v == null || v.trim().isEmpty) {
      return widget.isEs ? 'Requerido' : 'Obrigatório';
    }
    final n = _pd(v);
    if (n == null || n <= 0) {
      return widget.isEs ? 'Valor inválido' : 'Valor inválido';
    }
    return null;
  }

  String? _validateAge(String? v) {
    if (v == null || v.trim().isEmpty) {
      return widget.isEs ? 'Requerido' : 'Obrigatório';
    }
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0 || n > 120) {
      return widget.isEs ? 'Idade inválida' : 'Idade inválida';
    }
    return null;
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    final age     = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final pas     = _pd(_pasCtrl.text) ?? 120.0;
    final col     = _pd(_colCtrl.text) ?? 200.0;
    final qt      = _pd(_qtCtrl.text)  ?? 400.0;
    final fc      = _pd(_fcCtrl.text)  ?? 75.0;

    setState(() {
      _agePlus65 = age >= 65;
      _result = _CardioEngine.compute(
        age: age, isFemale: _isFemale,
        hasDiabetes: _hasDiabetes, isSmoker: _isSmoker,
        hasHtn: _hasHtn, hasCvDisease: _hasCvDisease,
        hasChf: _hasChf, hasCkd: _hasCkd,
        hadStroke: _hadStroke, hasBleedHx: _hasBleedHx,
        hasLabilInr: _hasLabilInr, agePlus65: _agePlus65,
        usesDrugsAlcohol: _usesDrugsAlc,
        pas: pas, colTotal: col,
        qtMs: qt, fcBpm: fc,
      );
    });
    _animCtrl.forward(from: 0);
  }

  Future<void> _launchDeeplink() async {
    final r = _result;
    if (r == null) return;
    HapticFeedback.mediumImpact();

    final payload = jsonEncode({
      'modulo':       'cardio',
      'age':          r.age,
      'sexo':         r.isFemale ? 'F' : 'M',
      'pas':          r.pas,
      'col_total':    r.colTotal,
      'diabetes':     r.hasDiabetes,
      'tabagismo':    r.isSmoker,
      'htn':          r.hasHtn,
      'cv_disease':   r.hasCvDisease,
      'ic':           r.hasChf,
      'ckd':          r.hasCkd,
      'avc_previo':   r.hadStroke,
      'sangramento':  r.hasBleedHx,
      'inr_labil':    r.hasLabilInr,
      'drogas_alcool': r.usesDrugsAlcohol,
      'qt_ms':        r.qtMs,
      'fc_bpm':       r.fcBpm,
      'prevent_risco': r.preventRisk,
      'cha2_score':   r.cha2Score,
      'hasbled_score': r.hasbledScore,
      'qtc_ms':       r.qtcMs,
    });

    const baseUrl =
        'https://rodrigssousa-sudo.github.io/medcases-calculadora/';
    final encodedPayload = Uri.encodeComponent(payload);
    final uri = Uri.parse(
      '$baseUrl?screen=patient_data&payload=$encodedPayload',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEs
                ? 'No se pudo abrir el Soporte de Decisión Clínica.'
                : 'Não foi possível abrir o Suporte de Decisão Clínica.'),
            backgroundColor: _kSurface,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final dark  = widget.dark;
    final bg    = dark ? _kBg     : const Color(0xFFF4F6F9);
    final surf  = dark ? _kSurface: Colors.white;
    final bord  = dark ? _kBorder : const Color(0xFFE5E7EB);
    final txt   = dark ? Colors.white       : const Color(0xFF0F1116);
    final sub   = dark ? _kTextSub          : const Color(0xFF6B7280);

    return ColoredBox(
      color: bg,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _CardioHeader(isEs: isEs, surf: surf, bord: bord, txt: txt, sub: sub),
            const SizedBox(height: 16),

            // ── Input Section ───────────────────────────────────────────────
            _InputSection(
              isEs: isEs, surf: surf, bord: bord, txt: txt, sub: sub,
              ageCtrl: _ageCtrl, pasCtrl: _pasCtrl,
              colCtrl: _colCtrl, qtCtrl:  _qtCtrl, fcCtrl: _fcCtrl,
              isFemale:     _isFemale,
              hasDiabetes:  _hasDiabetes,
              isSmoker:     _isSmoker,
              hasHtn:       _hasHtn,
              hasCvDisease: _hasCvDisease,
              hasChf:       _hasChf,
              hasCkd:       _hasCkd,
              hadStroke:    _hadStroke,
              hasBleedHx:   _hasBleedHx,
              hasLabilInr:  _hasLabilInr,
              usesDrugsAlc: _usesDrugsAlc,
              onToggleFemale:      (v) => setState(() => _isFemale      = v),
              onToggleDiabetes:    (v) => setState(() => _hasDiabetes   = v),
              onToggleSmoker:      (v) => setState(() => _isSmoker      = v),
              onToggleHtn:         (v) => setState(() => _hasHtn        = v),
              onToggleCvDisease:   (v) => setState(() => _hasCvDisease  = v),
              onToggleChf:         (v) => setState(() => _hasChf        = v),
              onToggleCkd:         (v) => setState(() => _hasCkd        = v),
              onToggleStroke:      (v) => setState(() => _hadStroke     = v),
              onToggleBleedHx:     (v) => setState(() => _hasBleedHx    = v),
              onToggleLabilInr:    (v) => setState(() => _hasLabilInr   = v),
              onToggleDrugsAlc:    (v) => setState(() => _usesDrugsAlc  = v),
              validatePositive: _validatePositive,
              validateAge:      _validateAge,
            ),
            const SizedBox(height: 16),

            // ── Calcular button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCyan,
                  foregroundColor: _kBg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEs ? 'CALCULAR' : 'CALCULAR',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

            // ── Results (animated) ──────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _ResultsSection(
                    result: _result!,
                    isEs: isEs, dark: dark,
                    surf: surf, txt: txt, sub: sub, bord: bord,
                    onDeeplink: _launchDeeplink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _CardioHeader extends StatelessWidget {
  final bool isEs;
  final Color surf, bord, txt, sub;
  const _CardioHeader({
    required this.isEs, required this.surf, required this.bord,
    required this.txt,  required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bord),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _kCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.favorite_rounded, color: _kCyan, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'CARDIOLOGÍA' : 'CARDIOLOGIA',
                    style: TextStyle(
                      color: txt,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PREVENT/ASCVD · CHA₂DS₂-VASc · HAS-BLED · QTc',
                    style: TextStyle(color: sub, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Section
// ─────────────────────────────────────────────────────────────────────────────
class _InputSection extends StatelessWidget {
  final bool isEs;
  final Color surf, bord, txt, sub;
  final TextEditingController ageCtrl, pasCtrl, colCtrl, qtCtrl, fcCtrl;

  final bool isFemale, hasDiabetes, isSmoker, hasHtn, hasCvDisease;
  final bool hasChf, hasCkd, hadStroke, hasBleedHx, hasLabilInr, usesDrugsAlc;

  final ValueChanged<bool> onToggleFemale, onToggleDiabetes, onToggleSmoker;
  final ValueChanged<bool> onToggleHtn, onToggleCvDisease, onToggleChf;
  final ValueChanged<bool> onToggleCkd, onToggleStroke, onToggleBleedHx;
  final ValueChanged<bool> onToggleLabilInr, onToggleDrugsAlc;

  final FormFieldValidator<String> validatePositive;
  final FormFieldValidator<String> validateAge;

  const _InputSection({
    required this.isEs, required this.surf, required this.bord,
    required this.txt,  required this.sub,
    required this.ageCtrl, required this.pasCtrl, required this.colCtrl,
    required this.qtCtrl,  required this.fcCtrl,
    required this.isFemale, required this.hasDiabetes, required this.isSmoker,
    required this.hasHtn, required this.hasCvDisease, required this.hasChf,
    required this.hasCkd, required this.hadStroke, required this.hasBleedHx,
    required this.hasLabilInr, required this.usesDrugsAlc,
    required this.onToggleFemale, required this.onToggleDiabetes,
    required this.onToggleSmoker, required this.onToggleHtn,
    required this.onToggleCvDisease, required this.onToggleChf,
    required this.onToggleCkd, required this.onToggleStroke,
    required this.onToggleBleedHx, required this.onToggleLabilInr,
    required this.onToggleDrugsAlc,
    required this.validatePositive, required this.validateAge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Bloco 1: Dados Demográficos + Hemodinâmicos ───────────────────
        _InputCard(
          title: isEs ? 'DATOS CLÍNICOS' : 'DADOS CLÍNICOS',
          surf: surf, bord: bord,
          child: Column(
            children: [
              // Linha 1: Idade + Sexo
              Row(
                children: [
                  Expanded(
                    child: _NField(
                      label: isEs ? 'Edad (años)' : 'Idade (anos)',
                      ctrl: ageCtrl,
                      hint: '55',
                      validator: validateAge,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SexToggle(
                      isEs: isEs,
                      isFemale: isFemale,
                      onChanged: onToggleFemale,
                      sub: sub,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Linha 2: PAS + Colesterol Total
              Row(
                children: [
                  Expanded(
                    child: _NField(
                      label: isEs ? 'PAS (mmHg)' : 'PAS (mmHg)',
                      ctrl: pasCtrl,
                      hint: '120',
                      validator: validatePositive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NField(
                      label: isEs ? 'Col. Total (mg/dL)' : 'Col. Total (mg/dL)',
                      ctrl: colCtrl,
                      hint: '200',
                      validator: validatePositive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Linha 3: QT + FC (para QTc)
              Row(
                children: [
                  Expanded(
                    child: _NField(
                      label: isEs ? 'QT medido (ms)' : 'QT medido (ms)',
                      ctrl: qtCtrl,
                      hint: '400',
                      validator: validatePositive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NField(
                      label: isEs ? 'FC (bpm)' : 'FC (bpm)',
                      ctrl: fcCtrl,
                      hint: '75',
                      validator: validatePositive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Bloco 2: Fatores de Risco (toggles compactos) ─────────────────
        _InputCard(
          title: isEs ? 'FACTORES DE RIESGO' : 'FATORES DE RISCO',
          surf: surf, bord: bord,
          child: Column(
            children: [
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'Diabetes' : 'Diabetes',
                    value: hasDiabetes, onChanged: onToggleDiabetes,
                  ),
                  _ToggleItem(
                    label: isEs ? 'Tabaquismo' : 'Tabagismo',
                    value: isSmoker, onChanged: onToggleSmoker,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'HTA' : 'HAS',
                    value: hasHtn, onChanged: onToggleHtn,
                  ),
                  _ToggleItem(
                    label: isEs ? 'Enf. Vascular' : 'D. Vascular',
                    value: hasCvDisease, onChanged: onToggleCvDisease,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'IC Congestiva' : 'IC Congestiva',
                    value: hasChf, onChanged: onToggleChf,
                  ),
                  _ToggleItem(
                    label: isEs ? 'ERC (Cr>2,3)' : 'DRC (Cr>2,3)',
                    value: hasCkd, onChanged: onToggleCkd,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'ACV/AIT previo' : 'AVC/AIT prévio',
                    value: hadStroke, onChanged: onToggleStroke,
                  ),
                  _ToggleItem(
                    label: isEs ? 'Hx Sangrado' : 'Hx Sangramento',
                    value: hasBleedHx, onChanged: onToggleBleedHx,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'INR Lábil' : 'INR Lábil',
                    value: hasLabilInr, onChanged: onToggleLabilInr,
                  ),
                  _ToggleItem(
                    label: isEs ? 'Drogas/Alcohol' : 'Drogas/Álcool',
                    value: usesDrugsAlc, onChanged: onToggleDrugsAlc,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results Section
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsSection extends StatelessWidget {
  final _CardioResult result;
  final bool isEs, dark;
  final Color surf, txt, sub, bord;
  final VoidCallback onDeeplink;

  const _ResultsSection({
    required this.result, required this.isEs, required this.dark,
    required this.surf, required this.txt, required this.sub, required this.bord,
    required this.onDeeplink,
  });

  // ── PREVENT color ─────────────────────────────────────────────────────────
  Color _preventColor(double risk) {
    if (risk < 5)  return _kGreen;
    if (risk < 10) return _kAmber;
    if (risk < 20) return const Color(0xFFf97316);
    return _kRed;
  }

  String _preventLabel(double risk, {required bool es}) {
    if (risk < 5)  return es ? 'Riesgo Bajo (<5%)' : 'Risco Baixo (<5%)';
    if (risk < 10) return es ? 'Riesgo Limítrofe (5-10%)' : 'Risco Limítrofe (5-10%)';
    if (risk < 20) return es ? 'Riesgo Intermedio (10-20%)' : 'Risco Intermediário (10-20%)';
    return es ? 'Riesgo Alto (≥20%)' : 'Risco Alto (≥20%)';
  }

  // ── CHA₂DS₂-VASc label ───────────────────────────────────────────────────
  Color _cha2Color(int s) {
    if (s == 0) return _kGreen;
    if (s == 1) return _kAmber;
    return _kRed;
  }

  String _cha2Label(int s, {required bool es}) {
    if (s == 0) return es ? 'Sin anticoagulación indicada' : 'Sem anticoagulação indicada';
    if (s == 1) return es ? 'Considerar anticoagulación (♂) / Sin indicación (♀)' : 'Considerar anticoagulação (♂) / Sem indicação (♀)';
    return es ? 'Anticoagulación recomendada (AVC anual ≥2%)' : 'Anticoagulação recomendada (AVC anual ≥2%)';
  }

  // ── HAS-BLED label ────────────────────────────────────────────────────────
  Color _hasbledColor(int s) {
    if (s <= 1) return _kGreen;
    if (s <= 2) return _kAmber;
    return _kRed;
  }

  String _hasbledLabel(int s, {required bool es}) {
    if (s <= 1) return es ? 'Riesgo bajo de sangrado' : 'Risco baixo de sangramento';
    if (s <= 2) return es ? 'Riesgo moderado — vigilar factores corregibles' : 'Risco moderado — vigiar fatores corrigíveis';
    return es ? 'Riesgo alto — revisar necesidad de anticoagulación' : 'Risco alto — revisar necessidade de anticoagulação';
  }

  // ── QTc label ─────────────────────────────────────────────────────────────
  Color _qtcColor(double ms) {
    if (ms <= 440) return _kGreen;
    if (ms <= 480) return _kAmber;
    return _kRed;
  }

  String _qtcLabel(double ms, {required bool es}) {
    if (ms <= 440) return es ? 'QTc normal (≤440 ms)' : 'QTc normal (≤440 ms)';
    if (ms <= 480) return es ? 'QTc prolongado — vigilar' : 'QTc prolongado — vigilar';
    return es ? 'QTc muy prolongado — riesgo de Torsades' : 'QTc muito prolongado — risco de Torsades';
  }

  // ── Score badge ───────────────────────────────────────────────────────────
  Widget _scoreBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEs = this.isEs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Text(
          'RESULTADOS',
          style: TextStyle(
            color: sub, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        // 1. PREVENT/ASCVD
        _ResultCard(
          dark: dark, surf: surf, bord: bord,
          icon: Icons.monitor_heart_rounded,
          iconColor: _preventColor(result.preventRisk),
          title: 'PREVENT / ASCVD',
          valueRow: Row(
            children: [
              Text(
                '${result.preventRisk.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: txt, fontSize: 22, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _scoreBadge(
                isEs ? '10 años' : '10 anos',
                _preventColor(result.preventRisk),
              ),
            ],
          ),
          sub: _preventLabel(result.preventRisk, es: isEs),
          subColor: _preventColor(result.preventRisk),
          formula: isEs
              ? 'Modelo ponderado PREVENT/ACC-AHA: tabaquismo, DM, HTA, PAS, Col. Total, sexo.'
              : 'Modelo ponderado PREVENT/ACC-AHA: tabagismo, DM, HAS, PAS, Col. Total, sexo.',
        ),
        const SizedBox(height: 10),

        // 2. CHA₂DS₂-VASc
        _ResultCard(
          dark: dark, surf: surf, bord: bord,
          icon: Icons.bloodtype_rounded,
          iconColor: _cha2Color(result.cha2Score),
          title: 'CHA₂DS₂-VASc',
          valueRow: Row(
            children: [
              Text(
                '${result.cha2Score} pts',
                style: TextStyle(
                  color: txt, fontSize: 22, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _scoreBadge('FA', _cha2Color(result.cha2Score)),
            ],
          ),
          sub: _cha2Label(result.cha2Score, es: isEs),
          subColor: _cha2Color(result.cha2Score),
          formula: isEs
              ? 'IC+HTA+DM+ACV(×2)+EnfVasc+Femenino+Edad65-74(+1)/≥75(+2). Máx 9 pts.'
              : 'IC+HAS+DM+AVC(×2)+D.Vasc+Feminino+Idade65-74(+1)/≥75(+2). Máx 9 pts.',
        ),
        const SizedBox(height: 10),

        // 3. HAS-BLED
        _ResultCard(
          dark: dark, surf: surf, bord: bord,
          icon: Icons.warning_amber_rounded,
          iconColor: _hasbledColor(result.hasbledScore),
          title: 'HAS-BLED',
          valueRow: Row(
            children: [
              Text(
                '${result.hasbledScore} pts',
                style: TextStyle(
                  color: txt, fontSize: 22, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _scoreBadge(
                isEs ? 'Sangrado' : 'Sangramento',
                _hasbledColor(result.hasbledScore),
              ),
            ],
          ),
          sub: _hasbledLabel(result.hasbledScore, es: isEs),
          subColor: _hasbledColor(result.hasbledScore),
          formula: isEs
              ? 'H-HTA + A-Renal/Hep + S-ACV + B-Sangrado + L-INR + E->65 + D-Drogas/Alcohol.'
              : 'H-HAS + A-Renal/Hep + S-AVC + B-Sangramento + L-INR + E->65 + D-Drogas/Álcool.',
        ),
        const SizedBox(height: 10),

        // 4. QTc
        _ResultCard(
          dark: dark, surf: surf, bord: bord,
          icon: Icons.graphic_eq_rounded,
          iconColor: _qtcColor(result.qtcMs),
          title: 'QTc (Bazett)',
          valueRow: Row(
            children: [
              Text(
                '${result.qtcMs.toStringAsFixed(0)} ms',
                style: TextStyle(
                  color: txt, fontSize: 22, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _scoreBadge('ECG', _qtcColor(result.qtcMs)),
            ],
          ),
          sub: _qtcLabel(result.qtcMs, es: isEs),
          subColor: _qtcColor(result.qtcMs),
          formula: 'Fórmula: QTc = QT(s) / √(RR)   |   RR = 60 / FC',
        ),

        const SizedBox(height: 20),

        // ── Deeplink button ────────────────────────────────────────────────
        _DeeplinkButton(isEs: isEs, onTap: onDeeplink),
        const SizedBox(height: 8),

        // Disclaimer Apple-compliant
        Text(
          isEs
              ? '⚕ Resultados para apoyo clínico educacional. No sustituye juicio médico individualizado.'
              : '⚕ Resultados para apoio clínico educacional. Não substitui julgamento médico individualizado.',
          style: TextStyle(color: sub, fontSize: 10, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared leaf widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Sub-card fosco de superfície para agrupamento de inputs
class _InputCard extends StatelessWidget {
  final String title;
  final Color surf, bord;
  final Widget child;
  const _InputCard({
    required this.title, required this.surf, required this.bord,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bord),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _kCyan,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

/// Campo numérico com label canônico
class _NField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final FormFieldValidator<String> validator;
  const _NField({
    required this.label, required this.ctrl,
    required this.hint, required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kTextSub,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          validator: validator,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kTextSub, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF0F1116),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kCyan, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kRed),
            ),
            errorStyle: const TextStyle(color: _kRed, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

/// Toggle de sexo compacto
class _SexToggle extends StatelessWidget {
  final bool isEs, isFemale;
  final ValueChanged<bool> onChanged;
  final Color sub;
  const _SexToggle({
    required this.isEs, required this.isFemale,
    required this.onChanged, required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEs ? 'SEXO' : 'SEXO',
          style: const TextStyle(
            color: _kTextSub, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1116),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isFemale ? _kCyan.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                      border: !isFemale
                          ? Border.all(color: _kCyan.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Text(
                      isEs ? 'Masculino' : 'Masculino',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: !isFemale ? _kCyan : _kTextSub,
                        fontSize: 12, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isFemale ? _kPurple.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                      border: isFemale
                          ? Border.all(color: _kPurple.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Text(
                      isEs ? 'Femenino' : 'Feminino',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isFemale ? _kPurple : _kTextSub,
                        fontSize: 12, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Par de toggles compactos em linha
class _ToggleItem {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem({required this.label, required this.value, required this.onChanged});
}

class _ToggleRow extends StatelessWidget {
  final List<_ToggleItem> items;
  const _ToggleRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        return Expanded(
          child: GestureDetector(
            onTap: () => item.onChanged(!item.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(
                right: items.indexOf(item) < items.length - 1 ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: item.value
                    ? _kCyan.withValues(alpha: 0.12)
                    : const Color(0xFF0F1116),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.value ? _kCyan.withValues(alpha: 0.5) : _kBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: item.value ? _kCyan : _kTextSub,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.value
                          ? _kCyan
                          : _kBorder,
                    ),
                    child: item.value
                        ? const Icon(Icons.check, size: 10, color: Color(0xFF0F1116))
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Result card — identical contract to nephrology_tools_screen._ResultCard
class _ResultCard extends StatelessWidget {
  final bool dark;
  final Color surf, bord, iconColor, subColor;
  final IconData icon;
  final String title, sub;
  final Widget valueRow;
  final String? formula;

  const _ResultCard({
    required this.dark, required this.surf, required this.bord,
    required this.icon, required this.iconColor,
    required this.title, required this.sub,
    required this.valueRow, required this.subColor,
    this.formula,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bord),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: iconColor, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  valueRow,
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: TextStyle(color: subColor, fontSize: 11, height: 1.3),
                    ),
                  ],
                  if (formula != null && formula!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      formula!,
                      style: const TextStyle(
                        fontSize: 11, color: Colors.white54, height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

/// Deeplink button — neon gradient, compliance-safe text
class _DeeplinkButton extends StatelessWidget {
  final bool isEs;
  final VoidCallback onTap;
  const _DeeplinkButton({required this.isEs, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00B4CC), Color(0xFF00E5FF)],
              begin: Alignment.centerLeft,
              end:   Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor:     Colors.transparent,
              foregroundColor: const Color(0xFF0F1116),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isEs
                      ? 'Acceder al Soporte de Decisión Clínica'
                      : 'Acessar Suporte de Decisão Clínica',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      );
}
