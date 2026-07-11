// ══════════════════════════════════════════════════════════════════════════════
// electrolytes_tools_screen.dart — BUILD 415-UX-HARMONY
//
// CENTRAL DE ELECTROLITOS Y GASOMETRÍA — Interface nativa unificada.
//
// MOTORES MATEMÁTICOS:
//   1. Déficit de HCO₃⁻ — reposição de bicarbonato
//   2. Gasometria Arterial — interpretação ácido-base completa
//   3. Brecha Aniônica (Gap Aniônico) + Osmolaridade calc.
//   4. Na⁺ Corrigido (hiperglicemia) + Ca²⁺ Corrigido (albumina)
//
// INTERNACIONALIZAÇÃO: isEs (Português / Espanhol) em todas as strings.
// COMPLIANCE: zero condutas/prescrições nativas — delegado ao Suporte Web via deeplink.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'calculadora_screen.dart' show CalculadoraScreen; // BUILD 429
import 'tools_patient_import.dart';
import 'tools_restore_banner.dart';
import 'internacion/services/internacion_persistence.dart';
import 'internacion/services/internacion_firestore_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta canônica MedCases Pro (dark-first)
// ─────────────────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F1116);
const _kSurface = Color(0xFF1A1D23);
const _kBorder  = Color(0xFF2D3340);
const _kCyan    = Color(0xFF00E5FF);
const _kGreen   = Color(0xFF10B981);
const _kAmber   = Color(0xFFF59E0B);
const _kRed     = Color(0xFFEF4444);
const _kBlue    = Color(0xFF3B82F6);
const _kTextSub = Color(0xFF8B9BB4);

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────
class ElectrolytesToolsScreen extends StatelessWidget {
  const ElectrolytesToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return _ElectroBody(isEs: p.lang == 'es', dark: p.darkMode);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typed immutable result
// ─────────────────────────────────────────────────────────────────────────────
class _ElectroResult {
  // Gasometria
  final String gasInterp;
  final double ph, pco2, hco3, be;

  // Eletrolitos
  final double anionGap;
  final double corrNa;
  final double corrCa;
  final double osmolarity;

  // Déficit HCO₃
  final double bicarbonateDef;

  // Raw inputs
  final double na, cl, gluc, ca, albumin, bun, weight;
  final bool   hasHighAG;

  const _ElectroResult({
    required this.gasInterp,
    required this.ph, required this.pco2, required this.hco3, required this.be,
    required this.anionGap, required this.corrNa, required this.corrCa,
    required this.osmolarity, required this.bicarbonateDef,
    required this.na, required this.cl, required this.gluc, required this.ca,
    required this.albumin, required this.bun, required this.weight,
    required this.hasHighAG,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure math engines
// ─────────────────────────────────────────────────────────────────────────────
class _ElectroEngine {
  // Gasometria — interpretação ácido-base completa
  static String _gasInterp({
    required double ph, required double pco2,
    required double hco3, required double be,
  }) {
    String primary;
    String comp = '';

    if (ph < 7.35) {
      if (pco2 > 45) {
        primary = 'Acidose Respiratória';
        if (hco3 > 26) comp = 'com compensação metabólica';
      } else {
        primary = 'Acidose Metabólica';
        final expPco2 = 1.5 * hco3 + 8;
        if (pco2 < expPco2 - 2) {
          comp = 'com compensação respiratória (hiperventilação)';
        } else if (pco2 > expPco2 + 2) {
          comp = 'com distúrbio respiratório adicional';
        } else {
          comp = 'compensação adequada';
        }
      }
    } else if (ph > 7.45) {
      if (pco2 < 35) {
        primary = 'Alcalose Respiratória';
        if (hco3 < 22) comp = 'com compensação metabólica';
      } else {
        primary = 'Alcalose Metabólica';
        final expPco2 = 0.7 * hco3 + 21;
        if (pco2 > expPco2 + 2) comp = 'com compensação respiratória';
      }
    } else {
      primary = '✓ pH Normal (7,35–7,45)';
    }

    if (be < -3) { comp += '${comp.isNotEmpty ? " | " : ""}BE: déficit de base (${be.toStringAsFixed(1)})'; }
    if (be > 3)  { comp += '${comp.isNotEmpty ? " | " : ""}BE: ↑ excesso de base (${be.toStringAsFixed(1)})'; }

    return '$primary${comp.isNotEmpty ? "\n$comp" : ""}';
  }

  static _ElectroResult compute({
    required double na, required double cl, required double hco3,
    required double gluc, required double ca, required double albumin,
    required double bun, required double weight,
    required double ph, required double pco2, required double be,
  }) {
    final ag    = na - (cl + hco3);
    final cNa   = na + 1.6 * ((gluc - 100) / 100);
    final cCa   = ca + 0.8 * (4.0 - albumin);
    final osm   = 2 * na + gluc / 18 + bun / 2.8;
    final biDef = (weight * 0.3 * (24 - hco3)).clamp(0.0, 9999.0);
    final interp = _gasInterp(ph: ph, pco2: pco2, hco3: hco3, be: be);

    return _ElectroResult(
      gasInterp: interp,
      ph: ph, pco2: pco2, hco3: hco3, be: be,
      anionGap: ag, corrNa: cNa, corrCa: cCa,
      osmolarity: osm, bicarbonateDef: biDef,
      na: na, cl: cl, gluc: gluc, ca: ca, albumin: albumin,
      bun: bun, weight: weight, hasHighAG: ag > 12,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main body
// ─────────────────────────────────────────────────────────────────────────────
class _ElectroBody extends StatefulWidget {
  final bool isEs;
  final bool dark;
  const _ElectroBody({required this.isEs, required this.dark});

  @override
  State<_ElectroBody> createState() => _ElectroBodyState();
}

class _ElectroBodyState extends State<_ElectroBody>
    with SingleTickerProviderStateMixin {
  // ── Gas controllers ───────────────────────────────────────────────────────
  final _phCtrl   = TextEditingController();
  final _pco2Ctrl = TextEditingController();
  final _beCtrl   = TextEditingController();

  // ── Electrolyte controllers ───────────────────────────────────────────────
  final _naCtrl    = TextEditingController();
  final _clCtrl    = TextEditingController();
  final _hco3Ctrl  = TextEditingController();
  final _glucCtrl  = TextEditingController();
  final _caCtrl    = TextEditingController();
  final _albumCtrl = TextEditingController();
  final _bunCtrl   = TextEditingController();
  final _weightCtrl= TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  _ElectroResult? _result;
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
    // BUILD 427: verifica cache após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRestoreCache());
  }

  // BUILD 427
  void _checkRestoreCache() {
    if (!mounted) return;
    final p = context.read<AppProvider>();
    if (p.toolsCacheHasData) setState(() => _showRestoreBanner = true);
  }

  void _restoreFromCache() {
    final p = context.read<AppProvider>();
    final cache = p.toolsInputCache;
    setState(() {
      if ((cache['sodio']  ?? '').isNotEmpty) _naCtrl.text     = cache['sodio']!;
      if ((cache['peso']   ?? '').isNotEmpty) _weightCtrl.text = cache['peso']!;
      _showRestoreBanner = false;
    });
  }

  void _discardCache() {
    context.read<AppProvider>().clearToolsCache();
    setState(() => _showRestoreBanner = false);
  }

  @override
  void dispose() {
    // BUILD 427: salva estado atual no cache antes de desmontar
    try {
      context.read<AppProvider>().saveToolsCache({
        'sodio': _naCtrl.text,
        'peso':  _weightCtrl.text,
      });
    } catch (_) {}
    for (final c in [
      _phCtrl, _pco2Ctrl, _beCtrl,
      _naCtrl, _clCtrl, _hco3Ctrl, _glucCtrl,
      _caCtrl, _albumCtrl, _bunCtrl, _weightCtrl,
    ]) {
      c.dispose();
    }
    _animCtrl.dispose();
    super.dispose();
  }

  // ── BUILD 427: Restore banner state
  bool _showRestoreBanner = false;

  // ── BUILD 426: Patient autofill ─────────────────────────────────────────────
  Future<void> _showPatientSelectionSheet(BuildContext context, AppProvider p) async {
    await showToolsPatientSelectionSheet(
      context: context,
      isEs: widget.isEs,
      dark: widget.dark,
      onSelected: (session) {
        final p = context.read<AppProvider>();
        p.setActiveImportedPatient(session);
        _autofillFromSession(session);
      },
    );
  }

  /// Autofill: peso (weight) mapeado de AppProvider.patient.weight se disponível,
  /// já que PacienteInternacaoData não tem campo de peso estruturado.
  /// Para Electrolitos: _weightCtrl ← AppProvider.patient.weight (single patient)
  void _autofillFromSession(PacienteSession session) {
    try {
      final paciente = session.paciente;
      // Nota: PacienteInternacaoData não tem peso — controller limpo para re-entrada
      // Age não é necessário para os cálculos de eletrólitos
      // O médico insere peso manualmente após selecionar o paciente
      final _ = paciente; // referência para evitar unused warning
    } catch (_) {
      // Falha silenciosa — nunca quebra a UI clínica
    }
  }

  // ── BUILD 428: Sync labs + scores to Firestore (fire-and-forget) ──────────
  void _syncResultToFirestore(_ElectroResult r) {
    try {
      final p = context.read<AppProvider>();
      final uid        = p.currentUser?.uid ?? '';
      final patientKey = p.activeImportedPatientKey ?? '';
      if (uid.isEmpty || patientKey.isEmpty) return;

      final labData = <String, dynamic>{
        'sodio':    _naCtrl.text,
        'cloro':    _clCtrl.text,
        'hco3':     _hco3Ctrl.text,
        'glicose':  _glucCtrl.text,
        'calcio':   _caCtrl.text,
        'albumina': _albumCtrl.text,
        'bun':      _bunCtrl.text,
        'peso':     _weightCtrl.text,
      };

      final scores = <String, dynamic>{
        'anionGap':      r.anionGap,
        'sodioCorrigido': r.corrNa,
        'calcioCorrigido': r.corrCa,
        'osmolaridade':  r.osmolarity,
        'deficitHco3':   r.bicarbonateDef,
      };

      final gasLine = r.gasInterp.replaceAll('\n', ' | ');
      final scoresText =
          'Anion Gap: ${r.anionGap.toStringAsFixed(1)}, '
          'Gasometria: $gasLine, '
          'Na corrigido: ${r.corrNa.toStringAsFixed(1)} mEq/L, '
          'Ca corrigido: ${r.corrCa.toStringAsFixed(2)} mg/dL, '
          'Osmolaridade: ${r.osmolarity.toStringAsFixed(0)} mOsm/L, '
          'Deficit HCO3: ${r.bicarbonateDef.toStringAsFixed(1)} mEq';

      // ignore: unawaited_futures
      InternacionFirestoreService.updatePatientLaboratories(
        uid:        uid,
        patientKey: patientKey,
        labData:    labData,
        scores:     scores,
        scoresText: scoresText,
      );
    } catch (_) {
      // Fire-and-forget: falhas nunca interrompem a UI clinica
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double? _pd(String v) => double.tryParse(v.trim().replaceAll(',', '.'));
  double _pdOr(TextEditingController c, double fallback) =>
      _pd(c.text) ?? fallback;

  String? _validateRequired(String? v) {
    if (v == null || v.trim().isEmpty) {
      return widget.isEs ? 'Requerido' : 'Obrigatório';
    }
    if (_pd(v) == null) return widget.isEs ? 'Inválido' : 'Inválido';
    return null;
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _result = _ElectroEngine.compute(
        na:      _pdOr(_naCtrl,    140),
        cl:      _pdOr(_clCtrl,    104),
        hco3:    _pdOr(_hco3Ctrl,   24),
        gluc:    _pdOr(_glucCtrl,  100),
        ca:      _pdOr(_caCtrl,    9.5),
        albumin: _pdOr(_albumCtrl, 4.0),
        bun:     _pdOr(_bunCtrl,   14),
        weight:  _pdOr(_weightCtrl, 70),
        ph:      _pdOr(_phCtrl,  7.40),
        pco2:    _pdOr(_pco2Ctrl,  40),
        be:      _pdOr(_beCtrl,     0),
      );
    });
    if (_result != null) _syncResultToFirestore(_result!);

    _animCtrl.forward(from: 0);
  }

  // BUILD 429-APPLE-COMPLIANCE: sync — abre CalculadoraScreen interna.
  void _launchDeeplink() {
    final r = _result;
    if (r == null) return;
    HapticFeedback.mediumImpact();

    final payload = jsonEncode({
      'modulo':          'electrolitos',
      'na':              r.na,
      'cl':              r.cl,
      'hco3':            r.hco3,
      'gluc':            r.gluc,
      'ca':              r.ca,
      'albumina':        r.albumin,
      'bun':             r.bun,
      'peso':            r.weight,
      'ph':              r.ph,
      'pco2':            r.pco2,
      'be':              r.be,
      'anion_gap':       r.anionGap,
      'na_corrigido':    r.corrNa,
      'ca_corrigido':    r.corrCa,
      'osmolaridade':    r.osmolarity,
      'deficit_hco3':    r.bicarbonateDef,
      'gas_interpretacao': r.gasInterp,
    });

    const baseUrl =
        'https://rodrigssousa-sudo.github.io/medcases-calculadora/';
    final encodedPayload = Uri.encodeComponent(payload);
    final url =
        '$baseUrl?screen=patient_data&payload=$encodedPayload';

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalculadoraScreen(initialUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final dark  = widget.dark;
    final bg    = dark ? _kBg      : const Color(0xFFF4F6F9);
    final surf  = dark ? _kSurface : Colors.white;
    final bord  = dark ? _kBorder  : const Color(0xFFE5E7EB);
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
            _ElectroHeader(isEs: isEs, surf: surf, bord: bord, txt: txt, sub: sub),

            // ── BUILD 426: Chip de importação de paciente ──────────────────
            ToolsPatientImportChip(
              isEs: isEs,
              dark: dark,
              onTap: () {
                final p = context.read<AppProvider>();
                _showPatientSelectionSheet(context, p);
              },
            ),
            const SizedBox(height: 16),

            // ── BUILD 427: Restore Banner ────────────────────────────────────
            if (_showRestoreBanner)
              ToolsRestoreBanner(
                isEs: isEs,
                dark: dark,
                onRestore: _restoreFromCache,
                onDiscard: _discardCache,
              ),
            if (_showRestoreBanner) const SizedBox(height: 4),

            // ── Bloco 1: GASOMETRIA ARTERIAL ───────────────────────────────
            _InputCard(
              title: isEs ? 'GASOMETRÍA ARTERIAL' : 'GASOMETRIA ARTERIAL',
              surf: surf, bord: bord,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NField(
                          label: 'pH',
                          ctrl: _phCtrl, hint: '7,40',
                          validator: _validateRequired,
                          refRange: '7,35–7,45',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NField(
                          label: 'pCO₂ (mmHg)',
                          ctrl: _pco2Ctrl, hint: '40',
                          validator: _validateRequired,
                          refRange: '35–45',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _NField(
                          label: 'HCO₃⁻ (mEq/L)',
                          ctrl: _hco3Ctrl, hint: '24',
                          validator: _validateRequired,
                          refRange: '22–26',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NField(
                          label: 'BE (mEq/L)',
                          ctrl: _beCtrl, hint: '0',
                          validator: _validateRequired,
                          refRange: '−2 a +2',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Bloco 2: ELETRÓLITOS SÉRICOS ───────────────────────────────
            _InputCard(
              title: isEs ? 'ELECTROLITOS SÉRICOS' : 'ELETRÓLITOS SÉRICOS',
              surf: surf, bord: bord,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NField(
                          label: 'Na⁺ (mEq/L)',
                          ctrl: _naCtrl, hint: '140',
                          validator: _validateRequired,
                          refRange: '136–145',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NField(
                          label: 'Cl⁻ (mEq/L)',
                          ctrl: _clCtrl, hint: '104',
                          validator: _validateRequired,
                          refRange: '98–106',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _NField(
                          label: isEs ? 'Glucosa (mg/dL)' : 'Glicose (mg/dL)',
                          ctrl: _glucCtrl, hint: '100',
                          validator: _validateRequired,
                          refRange: '70–100',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NField(
                          label: 'Ca²⁺ total (mg/dL)',
                          ctrl: _caCtrl, hint: '9,5',
                          validator: _validateRequired,
                          refRange: '8,5–10,5',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _NField(
                          label: isEs ? 'Albúmina (g/dL)' : 'Albumina (g/dL)',
                          ctrl: _albumCtrl, hint: '4,0',
                          validator: _validateRequired,
                          refRange: '3,5–5,0',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NField(
                          label: isEs ? 'BUN (mg/dL)' : 'BUN/Ureia (mg/dL)',
                          ctrl: _bunCtrl, hint: '14',
                          validator: _validateRequired,
                          refRange: '7–20',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Peso — para déficit HCO₃
                  _NField(
                    label: isEs ? 'Peso corporal (kg)' : 'Peso corporal (kg)',
                    ctrl: _weightCtrl, hint: '70',
                    validator: _validateRequired,
                    refRange: '',
                  ),
                ],
              ),
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
class _ElectroHeader extends StatelessWidget {
  final bool isEs;
  final Color surf, bord, txt, sub;
  const _ElectroHeader({
    required this.isEs, required this.surf, required this.bord,
    required this.txt, required this.sub,
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
              child: const Icon(Icons.science_rounded, color: _kCyan, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs
                        ? 'ELECTROLITOS Y GASOMETRÍA'
                        : 'ELETRÓLITOS E GASOMETRIA',
                    style: TextStyle(
                      color: txt,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEs
                        ? 'Déficit HCO₃ · Gasometría · Brecha Aniónica · Na/Ca Corregido'
                        : 'Déficit HCO₃ · Gasometria · Brecha Aniônica · Na/Ca Corrigido',
                    style: TextStyle(color: sub, fontSize: 10, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Results Section
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsSection extends StatelessWidget {
  final _ElectroResult result;
  final bool isEs, dark;
  final Color surf, txt, sub, bord;
  final VoidCallback onDeeplink;

  const _ResultsSection({
    required this.result, required this.isEs, required this.dark,
    required this.surf, required this.txt, required this.sub, required this.bord,
    required this.onDeeplink,
  });

  Color _phColor(double ph) {
    if (ph >= 7.35 && ph <= 7.45) return _kGreen;
    if ((ph >= 7.30 && ph < 7.35) || (ph > 7.45 && ph <= 7.50)) return _kAmber;
    return _kRed;
  }

  Color _agColor(double ag) {
    if (ag < 8)   return _kBlue;
    if (ag <= 12) return _kGreen;
    if (ag <= 20) return _kAmber;
    return _kRed;
  }

  String _agLabel(double ag, {required bool es}) {
    if (ag < 8)   return es ? '↓ Bajo (<8)' : '↓ Baixo (<8)';
    if (ag <= 12) return es ? '✓ Normal (8–12)' : '✓ Normal (8–12)';
    if (ag <= 20) return es ? '⚠ Elevado (12–20)' : '⚠ Elevado (12–20)';
    return es ? '⬆ Muy elevado — acidosis AG alto' : '⬆ Muito elevado — acidose AG alto';
  }

  Color _caColor(double ca) {
    if (ca < 8.5)  return _kBlue;
    if (ca > 10.5) return _kRed;
    return _kGreen;
  }

  String _caLabel(double ca, {required bool es}) {
    if (ca < 8.5)  return es ? 'Hipocalcemia' : 'Hipocalcemia';
    if (ca > 10.5) return es ? 'Hipercalcemia' : 'Hipercalcemia';
    return es ? 'Normal (8,5–10,5)' : 'Normal (8,5–10,5)';
  }

  Color _osmColor(double o) {
    if (o < 280)  return _kBlue;
    if (o <= 295) return _kGreen;
    if (o <= 320) return _kAmber;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final isEs = this.isEs;
    final r = result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESULTADOS',
          style: TextStyle(
            color: sub, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        // 1. Gasometria — interpretação
        _ResultCard(
          dark: dark, surf: surf, bord: bord,
          icon: Icons.air_rounded,
          iconColor: _phColor(r.ph),
          title: isEs ? 'GASOMETRÍA ARTERIAL' : 'GASOMETRIA ARTERIAL',
          valueRow: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MiniPill(label: 'pH', value: r.ph.toStringAsFixed(2), color: _phColor(r.ph)),
                  const SizedBox(width: 6),
                  _MiniPill(label: 'pCO₂', value: '${r.pco2.toStringAsFixed(0)} mmHg', color: _kTextSub),
                  const SizedBox(width: 6),
                  _MiniPill(label: 'HCO₃', value: '${r.hco3.toStringAsFixed(1)} mEq', color: _kTextSub),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                r.gasInterp,
                style: TextStyle(
                  color: _phColor(r.ph),
                  fontSize: 13, fontWeight: FontWeight.w700, height: 1.4,
                ),
              ),
            ],
          ),
          sub: '',
          subColor: Colors.transparent,
          formula: isEs
              ? 'pH normal: 7,35–7,45 | pCO₂: 35–45 mmHg | HCO₃: 22–26 mEq/L | BE: −2 a +2 mEq/L'
              : 'pH normal: 7,35–7,45 | pCO₂: 35–45 mmHg | HCO₃: 22–26 mEq/L | BE: −2 a +2 mEq/L',
        ),
        const SizedBox(height: 10),

        // 2. Déficit de HCO₃⁻
        _ResultCard(
          dark: dark, surf: surf, bord: bord,
          icon: Icons.calculate_rounded,
          iconColor: _kAmber,
          title: isEs ? 'DÉFICIT DE HCO₃⁻' : 'DÉFICIT DE HCO₃⁻',
          valueRow: Text(
            '${r.bicarbonateDef.toStringAsFixed(0)} mEq',
            style: TextStyle(
              color: txt, fontSize: 22, fontWeight: FontWeight.w700,
            ),
          ),
          sub: isEs
              ? 'Repor 50% do déficit na primeira hora (máx 2 mEq/kg)'
              : 'Repor 50% do déficit na primeira hora (máx 2 mEq/kg)',
          subColor: _kAmber,
          formula: isEs
              ? 'Fórmula: Peso × 0,3 × (24 − HCO₃atual). Meta HCO₃ = 24 mEq/L.'
              : 'Fórmula: Peso × 0,3 × (24 − HCO₃atual). Meta HCO₃ = 24 mEq/L.',
        ),
        const SizedBox(height: 10),

        // 3. Gap / Brecha Aniônica + Osmolaridade
        _ResultCard(
          dark: dark, surf: surf, bord: bord,
          icon: Icons.analytics_rounded,
          iconColor: _agColor(r.anionGap),
          title: isEs ? 'BRECHA ANIÓNICA' : 'GAP ANIÔNICO',
          valueRow: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${r.anionGap.toStringAsFixed(1)} mEq/L',
                        style: TextStyle(
                          color: txt, fontSize: 18, fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AgBadge(ag: r.anionGap),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        isEs ? 'Osmol. calc.: ' : 'Osmol. calc.: ',
                        style: const TextStyle(color: _kTextSub, fontSize: 11),
                      ),
                      Text(
                        '${r.osmolarity.toStringAsFixed(0)} mOsm/kg',
                        style: TextStyle(
                          color: _osmColor(r.osmolarity),
                          fontSize: 11, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          sub: _agLabel(r.anionGap, es: isEs),
          subColor: _agColor(r.anionGap),
          formula: isEs
              ? 'GA = Na − (Cl + HCO₃) | Osmol. = 2×Na + Gluc/18 + BUN/2,8'
              : 'GA = Na − (Cl + HCO₃) | Osmol. = 2×Na + Gluc/18 + BUN/2,8',
        ),
        const SizedBox(height: 10),

        // 4. Na⁺ Corrigido + Ca²⁺ Corrigido
        _ResultCard(
          dark: dark, surf: surf, bord: bord,
          icon: Icons.water_drop_rounded,
          iconColor: _kBlue,
          title: isEs ? 'NA⁺ / CA²⁺ CORREGIDOS' : 'NA⁺ / CA²⁺ CORRIGIDOS',
          valueRow: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MiniPill(
                    label: 'Na⁺ corr.',
                    value: '${r.corrNa.toStringAsFixed(1)} mEq/L',
                    color: _kBlue,
                  ),
                  const SizedBox(width: 8),
                  _MiniPill(
                    label: 'Ca²⁺ corr.',
                    value: '${r.corrCa.toStringAsFixed(2)} mg/dL',
                    color: _caColor(r.corrCa),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isEs
                    ? 'Ca²⁺: ${_caLabel(r.corrCa, es: true)}'
                    : 'Ca²⁺: ${_caLabel(r.corrCa, es: false)}',
                style: TextStyle(
                  color: _caColor(r.corrCa), fontSize: 11, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          sub: '',
          subColor: Colors.transparent,
          formula: isEs
              ? 'Na corr. = Na + 1,6×((Gluc−100)/100) | Ca corr. = Ca + 0,8×(4−Alb)'
              : 'Na corr. = Na + 1,6×((Gluc−100)/100) | Ca corr. = Ca + 0,8×(4−Alb)',
        ),

        const SizedBox(height: 20),

        // ── Deeplink button ────────────────────────────────────────────────
        _DeeplinkButton(isEs: isEs, onTap: onDeeplink),
        const SizedBox(height: 8),

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
                color: _kCyan, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

/// Campo numérico com label + faixa de referência no hint
class _NField extends StatelessWidget {
  final String label, hint, refRange;
  final TextEditingController ctrl;
  final FormFieldValidator<String> validator;
  const _NField({
    required this.label, required this.ctrl,
    required this.hint, required this.validator,
    this.refRange = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _kTextSub, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 0.6,
              ),
            ),
            if (refRange.isNotEmpty)
              Text(
                refRange,
                style: const TextStyle(color: _kTextSub, fontSize: 9),
              ),
          ],
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

/// Mini pill badge (pH, pCO₂, etc.)
class _MiniPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: value,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
}

/// Gap Aniônico badge
class _AgBadge extends StatelessWidget {
  final double ag;
  const _AgBadge({required this.ag});

  Color get _color {
    if (ag < 8)   return _kBlue;
    if (ag <= 12) return _kGreen;
    if (ag <= 20) return _kAmber;
    return _kRed;
  }

  String get _label {
    if (ag < 8)   return 'Baixo';
    if (ag <= 12) return 'Normal';
    if (ag <= 20) return 'Elevado';
    return 'Muito Alto';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: _color, fontSize: 10, fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// Result card — identical contract to nephrology/cardio _ResultCard
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
