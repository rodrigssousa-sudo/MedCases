// ══════════════════════════════════════════════════════════════════════════════
// hepatology_tools_screen.dart — BUILD 420-HEPATOLOGY / BUILD 445-CROSS-CALC-STATE
//
// CENTRAL DE HEPATOLOGÍA CLÍNICA — Interface nativa premium unificada.
//
// CONFORMIDADE APPLE STORE:
//   • Exibe APENAS resultados numéricos, cálculos matemáticos e estadiamentos.
//   • ZERO condutas terapêuticas, doses ou prescrições nativas.
//   • Toda a conduta clínica final é delegada ao WebView via Deeplink estruturado.
//
// MOTORES MATEMÁTICOS:
//   1. MELD-Na        (Model for End-Stage Liver Disease + Sódio)
//   2. Child-Pugh     (Classe A/B/C — escore cirrose)
//   3. FIB-4          (Índice de fibrose hepática)
//   4. APRI           (AST-to-Platelet Ratio Index)
//   5. Maddrey DF     (Hepatite Alcoólica — discriminant function)
//   6. Critérios de Milán (Oncologia CHC — transplante)
//
// INTERNACIONALIZAÇÃO: isEs (Português / Espanhol) em todas as strings.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/tools_state_provider.dart'; // BUILD 445
import 'calculadora_screen.dart' show CalculadoraScreen; // BUILD 429
import 'tools_patient_import.dart';
import 'tools_restore_banner.dart';
import 'internacion/services/internacion_persistence.dart';
import 'internacion/services/internacion_firestore_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta canônica MedCases Pro (dark-first) — idêntica a nephrology/cardio
// ─────────────────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F1116);
const _kSurface = Color(0xFF1A1D23);
const _kBorder  = Color(0xFF2D3340);
const _kCyan    = Color(0xFF00E5FF);
// BUILD 450: Azul Petróleo — substitui neon no Light Mode
const _kPetroleo = Color(0xFF1A365D);
const _kGreen   = Color(0xFF10B981);
const _kAmber   = Color(0xFFF59E0B);
const _kRed     = Color(0xFFEF4444);
const _kTextSub = Color(0xFF8B9BB4);

// ─────────────────────────────────────────────────────────────────────────────
// HepatologyToolsScreen — ponto de entrada público
// ─────────────────────────────────────────────────────────────────────────────
// BUILD 445: AutomaticKeepAliveClientMixin → estado visual sobrevive à troca de aba
class HepatologyToolsScreen extends StatefulWidget {
  const HepatologyToolsScreen({super.key});
  @override
  State<HepatologyToolsScreen> createState() => _HepatologyToolsScreenState();
}

class _HepatologyToolsScreenState extends State<HepatologyToolsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p    = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final dark = p.darkMode;
    return _HepatologyBody(isEs: isEs, dark: dark);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HepatologyBody — StatefulWidget principal
// ─────────────────────────────────────────────────────────────────────────────
class _HepatologyBody extends StatefulWidget {
  final bool isEs;
  final bool dark;
  const _HepatologyBody({required this.isEs, required this.dark});

  @override
  State<_HepatologyBody> createState() => _HepatologyBodyState();
}

class _HepatologyBodyState extends State<_HepatologyBody>
    with SingleTickerProviderStateMixin {

  // BUILD 445: Controllers COMPARTILHADOS via ToolsStateProvider:
  //   ageCtrl, naCtrl, biliCtrl (bilirrubina), crCtrl (creatinina), inrCtrl, albCtrl,
  //   astCtrl, altCtrl, platCtrl.
  // Controllers PRIVADOS (específicos de hepatologia):
  bool  _dialysis   = false;
  final _astUlnCtrl = TextEditingController();
  final _altUlnCtrl = TextEditingController();
  final _faCtrl     = TextEditingController();
  final _faUlnCtrl  = TextEditingController();

  // ── Seletores — Bloco 4: Avaliação de Cirrose (CTP & Maddrey) ────────────
  int _ascites        = 1; // 1=Ausente, 2=Leve/Mod, 3=Grave/Tensa
  int _encephalopathy = 1; // 1=Ausente, 2=Grau 1-2, 3=Grau 3-4
  final _tpPatientCtrl = TextEditingController();
  final _tpControlCtrl = TextEditingController();

  // ── Controllers — Bloco 5: Critérios de Milán ─────────────────────────────
  final _noduleCountCtrl  = TextEditingController();
  final _noduleSizesCtrl  = TextEditingController();
  bool  _hasMetastasis    = false;
  bool  _hasMacroInvasion = false;

  // ── BUILD 427: Restore banner state
  bool _showRestoreBanner = false;

  // ── Resultados e animação ─────────────────────────────────────────────────
  _HepResult? _result;
  String?     _errorMsg;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // ── Form key ──────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    // Preenche ULN padrão para facilitar entrada
    _astUlnCtrl.text = '40';
    _altUlnCtrl.text = '40';
    _faUlnCtrl.text  = '120';

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
    final p  = context.read<AppProvider>();
    final tp = context.read<ToolsStateProvider>();
    tp.applyFromCache(p.toolsInputCache);
    setState(() => _showRestoreBanner = false);
  }

  void _discardCache() {
    context.read<AppProvider>().clearToolsCache();
    setState(() => _showRestoreBanner = false);
  }

  @override
  void dispose() {
    // BUILD 445: controllers compartilhados pertencem ao ToolsStateProvider — NÃO dispose aqui.
    try {
      final p  = context.read<AppProvider>();
      final tp = context.read<ToolsStateProvider>();
      tp.refreshPendingFlag();
      p.saveToolsCache(tp.exportToCache());
    } catch (_) {}
    _animCtrl.dispose();
    // Apenas controllers PRIVADOS de hepatologia:
    _astUlnCtrl.dispose();
    _altUlnCtrl.dispose();
    _faCtrl.dispose();
    _faUlnCtrl.dispose();
    _tpPatientCtrl.dispose();
    _tpControlCtrl.dispose();
    _noduleCountCtrl.dispose();
    _noduleSizesCtrl.dispose();
    super.dispose();
  }

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

  /// Mapeamento demográfico seguro para Hepatologia:
  ///   idade → _ageCtrl
  ///   sexo  → _dialysis permanece false (sem campo estruturado)
  /// Labs (bilirrubina, creatinina, sódio, INR, albumina) são free-text
  /// no internacion → NÃO mapeados automaticamente.
  void _autofillFromSession(PacienteSession session) {
    try {
      final paciente = session.paciente;
      final tp = context.read<ToolsStateProvider>();

      // Idade → tp.ageCtrl (compartilhado)
      final age = parseAgeFromString(paciente.idade);
      if (age != null && tp.ageCtrl.text.isEmpty) tp.ageCtrl.text = age.toString();
      setState(() {}); // rebuild mínimo
    } catch (_) {
      // Falha silenciosa — nunca quebra a UI clínica
    }
  }

  // ── BUILD 428: Sync labs + scores to Firestore (fire-and-forget) ─────────
  void _syncResultToFirestore(_HepResult r) {
    try {
      final p = context.read<AppProvider>();
      final uid        = p.currentUser?.uid ?? '';
      final patientKey = p.activeImportedPatientKey ?? '';
      if (uid.isEmpty || patientKey.isEmpty) return;

      final tp2 = context.read<ToolsStateProvider>();
      final labData = <String, dynamic>{
        'bilirrubina': tp2.biliCtrl.text,
        'creatinina':  tp2.crCtrl.text,
        'inr':         tp2.inrCtrl.text,
        'albumina':    tp2.albCtrl.text,
        'sodio':       tp2.naCtrl.text,
        'ast':         tp2.astCtrl.text,
        'alt':         tp2.altCtrl.text,
        'plaquetas':   tp2.platCtrl.text,
        'edad':        tp2.ageCtrl.text,
      };

      final scores = <String, dynamic>{
        'meldNa':          r.meldNa,
        'childPughPoints': r.childPughPoints,
        'childPughClass':  r.childPughClass,
        'fib4':            r.fib4,
        'apri':            r.apri,
        'factorR':         r.factorR,
        'maddreyDf':       r.maddreyDf,
        'milanCriteria':   r.milanCriteria,
      };

      final scoresText =
          'MELD-Na: \${r.meldNa}, Child-Pugh: Classe \${r.childPughClass} '
          '(\${r.childPughPoints}pts), FIB-4: \${r.fib4.toStringAsFixed(2)}, '
          'APRI: \${r.apri.toStringAsFixed(2)}, '
          'Maddrey DF: \${r.maddreyDf.toStringAsFixed(1)}, '
          'Milan: \${r.milanCriteria ? "Dentro" : "Fora"}';

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

  // ── Helper: parse double seguro ──────────────────────────────────────────
  double? _pd(String v) {
    final s = v.trim().replaceAll(',', '.');
    return double.tryParse(s);
  }

  // ── Validators ────────────────────────────────────────────────────────────
  String? _reqPositive(String? v) {
    if (v == null || v.trim().isEmpty) {
      return widget.isEs ? 'Requerido' : 'Obrigatório';
    }
    final n = _pd(v);
    if (n == null || n <= 0) {
      return widget.isEs ? 'Valor inválido' : 'Valor inválido';
    }
    return null;
  }

  String? _reqNonNegInt(String? v) {
    if (v == null || v.trim().isEmpty) {
      return widget.isEs ? 'Requerido' : 'Obrigatório';
    }
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) {
      return widget.isEs ? 'Valor inválido' : 'Valor inválido';
    }
    return null;
  }

  // ── Calcular ──────────────────────────────────────────────────────────────
  void _calculate() {
    HapticFeedback.lightImpact();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final tp  = context.read<ToolsStateProvider>();
    final age    = int.tryParse(tp.ageCtrl.text.trim());
    final na     = _pd(tp.naCtrl.text);
    final bili   = _pd(tp.biliCtrl.text);
    final creat  = _pd(tp.crCtrl.text);
    final inr    = _pd(tp.inrCtrl.text);
    final alb    = _pd(tp.albCtrl.text);
    final ast    = _pd(tp.astCtrl.text);
    final astUln = _pd(_astUlnCtrl.text);
    final alt    = _pd(tp.altCtrl.text);
    final altUln = _pd(_altUlnCtrl.text);
    final fa     = _pd(_faCtrl.text);
    final faUln  = _pd(_faUlnCtrl.text);
    final plat   = _pd(tp.platCtrl.text);
    final tpPat  = _pd(_tpPatientCtrl.text);
    final tpCtrl = _pd(_tpControlCtrl.text);

    // Nódulos de Milán
    final noduleCount = int.tryParse(_noduleCountCtrl.text.trim()) ?? 0;
    final noduleSizes = _parseSizes(_noduleSizesCtrl.text);

    if (age == null || na == null || bili == null || creat == null ||
        inr == null || alb == null || ast == null || astUln == null ||
        alt == null || altUln == null || fa == null || faUln == null ||
        plat == null || tpPat == null || tpCtrl == null) {
      setState(() => _errorMsg = widget.isEs
          ? 'Verifica los valores ingresados.'
          : 'Verifique os valores inseridos.');
      return;
    }

    setState(() {
      _errorMsg = null;
      _result   = _HepEngine.compute(
        age:            age,
        na:             na,
        biliTotal:      bili,
        creatinine:     creat,
        inr:            inr,
        albumin:        alb,
        ast:            ast,
        astUln:         astUln,
        alt:            alt,
        altUln:         altUln,
        fa:             fa,
        faUln:          faUln,
        platelets:      plat,
        ascites:        _ascites,
        encephalopathy: _encephalopathy,
        tpPatient:      tpPat,
        tpControl:      tpCtrl,
        dialysis:       _dialysis,
        noduleCount:    noduleCount,
        noduleSizes:    noduleSizes,
        hasMetastasis:  _hasMetastasis,
        hasMacroInvasion: _hasMacroInvasion,
      );
    });

    if (_result != null) _syncResultToFirestore(_result!);

    _animCtrl
      ..reset()
      ..forward();
  }

  List<double> _parseSizes(String raw) {
    if (raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((s) => double.tryParse(s.trim().replaceAll(',', '.')))
        .whereType<double>()
        .toList();
  }

  // ── Deeplink ──────────────────────────────────────────────────────────────
  // BUILD 444 [P2+P3]: URL dinâmica Hepatologia → condutas/hepatologia.
  // Abre CalculadoraScreen (WebView integrada em tela cheia) no endpoint
  // da especialidade — NUNCA launchUrl externo (Apple compliance).
  void _launchDeeplink() {
    if (_result == null) return;
    HapticFeedback.mediumImpact();
    // BUILD 447-URL-PAYLOAD + BUILD 449-LANG-PAYLOAD: serializa idioma e
    // campos Hepatologia como query params.
    const baseUrl = 'https://medcasescalcu.com/condutas/hepatologia';
    final langCode = widget.isEs ? 'es' : 'pt';
    final queryParams = context.read<ToolsStateProvider>()
        .buildQueryStringForSpecialty('hepato', langCode);
    final conductaUrl = '$baseUrl$queryParams';
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalculadoraScreen(initialUrl: conductaUrl),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final dark = widget.dark;
    final bg     = dark ? _kBg      : const Color(0xFFF1F5F9);
    final surf   = dark ? _kSurface : Colors.white;
    final txt    = dark ? Colors.white : const Color(0xFF0F1116);
    final sub    = dark ? _kTextSub  : const Color(0xFF64748B);
    final border = dark ? _kBorder   : const Color(0xFFCBD5E1);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _Header(isEs: isEs, dark: dark, txt: txt, sub: sub),
              ),

              // ── BUILD 426: Chip de importação de paciente ─────────────────
              SliverToBoxAdapter(
                child: ToolsPatientImportChip(
                  isEs: isEs,
                  dark: dark,
                  onTap: () {
                    final p = context.read<AppProvider>();
                    _showPatientSelectionSheet(context, p);
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),

              // ── BUILD 427: Restore Banner ─────────────────────────────────
              if (_showRestoreBanner)
                SliverToBoxAdapter(
                  child: ToolsRestoreBanner(
                    isEs: isEs,
                    dark: dark,
                    onRestore: _restoreFromCache,
                    onDiscard: _discardCache,
                  ),
                ),

              // ── Inputs ──────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _InputSection(
                    isEs:             isEs,
                    dark:             dark,
                    surf:             surf,
                    txt:              txt,
                    sub:              sub,
                    border:           border,
                    ageCtrl:          context.read<ToolsStateProvider>().ageCtrl,
                    naCtrl:           context.read<ToolsStateProvider>().naCtrl,
                    dialysis:         _dialysis,
                    onDialysisChange: (v) => setState(() => _dialysis = v),
                    biliCtrl:         context.read<ToolsStateProvider>().biliCtrl,
                    creatCtrl:        context.read<ToolsStateProvider>().crCtrl,
                    inrCtrl:          context.read<ToolsStateProvider>().inrCtrl,
                    albCtrl:          context.read<ToolsStateProvider>().albCtrl,
                    astCtrl:          context.read<ToolsStateProvider>().astCtrl,
                    astUlnCtrl:       _astUlnCtrl,
                    altCtrl:          context.read<ToolsStateProvider>().altCtrl,
                    altUlnCtrl:       _altUlnCtrl,
                    faCtrl:           _faCtrl,
                    faUlnCtrl:        _faUlnCtrl,
                    platCtrl:         context.read<ToolsStateProvider>().platCtrl,
                    ascites:          _ascites,
                    encephalopathy:   _encephalopathy,
                    onAscitesChange:  (v) => setState(() => _ascites = v),
                    onEncephChange:   (v) => setState(() => _encephalopathy = v),
                    tpPatientCtrl:    _tpPatientCtrl,
                    tpControlCtrl:    _tpControlCtrl,
                    noduleCountCtrl:  _noduleCountCtrl,
                    noduleSizesCtrl:  _noduleSizesCtrl,
                    hasMetastasis:    _hasMetastasis,
                    hasMacroInvasion: _hasMacroInvasion,
                    onMetastasisChange:    (v) => setState(() => _hasMetastasis = v),
                    onMacroInvasionChange: (v) => setState(() => _hasMacroInvasion = v),
                    validatePos:      _reqPositive,
                    validateInt:      _reqNonNegInt,
                  ),
                ),
              ),

              // ── Error ────────────────────────────────────────────────────
              if (_errorMsg != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                        color: _kRed, fontSize: 12, fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // ── Botão Calcular ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _CalcButton(isEs: isEs, onTap: _calculate),
                ),
              ),

              // ── Resultados animados ───────────────────────────────────────
              if (_result != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: _ResultsSection(
                          result:     _result!,
                          isEs:       isEs,
                          dark:       dark,
                          surf:       surf,
                          txt:        txt,
                          sub:        sub,
                          border:     border,
                          onDeeplink: _launchDeeplink,
                        ),
                      ),
                    ),
                  ),
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool isEs, dark;
  final Color txt, sub;
  const _Header({
    required this.isEs,
    required this.dark,
    required this.txt,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? _kSurface : Colors.white,
        border: Border(
          bottom: BorderSide(color: dark ? _kBorder : const Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              // BUILD 450: header icon petróleo
              color: _kPetroleo.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.layers_outlined, color: _kPetroleo, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'HEPATOLOGÍA CLÍNICA' : 'HEPATOLOGIA CLÍNICA',
                  style: TextStyle(
                    color: txt,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'MELD-Na · Child-Pugh · FIB-4 · APRI · Maddrey · Milán',
                  style: TextStyle(color: sub, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Section — todos os 5 blocos de afinidade
// ─────────────────────────────────────────────────────────────────────────────
class _InputSection extends StatelessWidget {
  final bool isEs, dark;
  final Color surf, txt, sub, border;

  // Bloco 1
  final TextEditingController ageCtrl, naCtrl;
  final bool dialysis;
  final ValueChanged<bool> onDialysisChange;

  // Bloco 2
  final TextEditingController biliCtrl, creatCtrl, inrCtrl, albCtrl;

  // Bloco 3
  final TextEditingController astCtrl, astUlnCtrl, altCtrl, altUlnCtrl;
  final TextEditingController faCtrl, faUlnCtrl, platCtrl;

  // Bloco 4
  final int ascites, encephalopathy;
  final ValueChanged<int> onAscitesChange, onEncephChange;
  final TextEditingController tpPatientCtrl, tpControlCtrl;

  // Bloco 5
  final TextEditingController noduleCountCtrl, noduleSizesCtrl;
  final bool hasMetastasis, hasMacroInvasion;
  final ValueChanged<bool> onMetastasisChange, onMacroInvasionChange;

  // Validators
  final FormFieldValidator<String> validatePos;
  final FormFieldValidator<String> validateInt;

  const _InputSection({
    required this.isEs,
    required this.dark,
    required this.surf,
    required this.txt,
    required this.sub,
    required this.border,
    required this.ageCtrl,
    required this.naCtrl,
    required this.dialysis,
    required this.onDialysisChange,
    required this.biliCtrl,
    required this.creatCtrl,
    required this.inrCtrl,
    required this.albCtrl,
    required this.astCtrl,
    required this.astUlnCtrl,
    required this.altCtrl,
    required this.altUlnCtrl,
    required this.faCtrl,
    required this.faUlnCtrl,
    required this.platCtrl,
    required this.ascites,
    required this.encephalopathy,
    required this.onAscitesChange,
    required this.onEncephChange,
    required this.tpPatientCtrl,
    required this.tpControlCtrl,
    required this.noduleCountCtrl,
    required this.noduleSizesCtrl,
    required this.hasMetastasis,
    required this.hasMacroInvasion,
    required this.onMetastasisChange,
    required this.onMacroInvasionChange,
    required this.validatePos,
    required this.validateInt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // ── BLOCO 1: Dados Clínicos e Demográficos ──────────────────────────
        _SectionLabel(
          isEs ? 'DATOS CLÍNICOS Y DEMOGRÁFICOS' : 'DADOS CLÍNICOS E DEMOGRÁFICOS',
          sub,
        ),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark, surf: surf, border: border,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  ageCtrl,
                      label: isEs ? 'Edad (años)' : 'Idade (anos)',
                      type:  TextInputType.number,
                      dark:  dark, txt: txt, sub: sub,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return isEs ? 'Requerido' : 'Obrigatório';
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 1 || n > 120) {
                          return isEs ? 'Inválido' : 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl:  naCtrl,
                      label: isEs
                          ? 'Sodio Sérico (mEq/L)'
                          : 'Sódio Sérico (mEq/L)',
                      hint:  '125 – 145',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DialysisToggle(
                isEs:     isEs,
                dark:     dark,
                txt:      txt,
                sub:      sub,
                border:   border,
                dialysis: dialysis,
                onChange: onDialysisChange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── BLOCO 2: Perfil Laboratorial Hepático e Renal ───────────────────
        _SectionLabel(
          isEs
              ? 'PERFIL DE LABORATORIO (HEPÁTICO Y RENAL)'
              : 'PERFIL LABORATORIAL (HEPÁTICO E RENAL)',
          sub,
        ),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark, surf: surf, border: border,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  biliCtrl,
                      label: isEs
                          ? 'Bilirrubina Total (mg/dL)'
                          : 'Bilirrubina Total (mg/dL)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl:  creatCtrl,
                      label: isEs
                          ? 'Creatinina Sérica (mg/dL)'
                          : 'Creatinina Sérica (mg/dL)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  inrCtrl,
                      label: 'INR',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl:  albCtrl,
                      label: isEs
                          ? 'Albúmina Sérica (g/dL)'
                          : 'Albumina Sérica (g/dL)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── BLOCO 3: Enzimas Hepáticas e Plaquetas ──────────────────────────
        _SectionLabel(
          isEs
              ? 'ENZIMAS HEPÁTICAS Y PLAQUETAS'
              : 'ENZIMAS HEPÁTICAS E PLAQUETAS',
          sub,
        ),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark, surf: surf, border: border,
          child: Column(
            children: [
              // AST + AST ULN
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  astCtrl,
                      label: 'AST/TGO (U/L)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl:  astUlnCtrl,
                      label: isEs ? 'AST ULN (Ref: 40)' : 'AST ULN (Ref: 40)',
                      hint:  '40',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ALT + ALT ULN
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  altCtrl,
                      label: 'ALT/TGP (U/L)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl:  altUlnCtrl,
                      label: isEs ? 'ALT ULN (Ref: 40)' : 'ALT ULN (Ref: 40)',
                      hint:  '40',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // FA + FA ULN + Plaquetas
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  faCtrl,
                      label: 'FA (U/L)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl:  faUlnCtrl,
                      label: isEs ? 'FA ULN (Ref: 120)' : 'FA ULN (Ref: 120)',
                      hint:  '120',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _FieldBox(
                ctrl:  platCtrl,
                label: isEs
                    ? 'Plaquetas (×10³/µL — ex: 150 = 150.000)'
                    : 'Plaquetas (×10³/µL — ex: 150 = 150.000)',
                type:  const TextInputType.numberWithOptions(decimal: true),
                dark:  dark, txt: txt, sub: sub,
                validator: validatePos,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── BLOCO 4: Avaliação de Cirrose (CTP & Maddrey) ──────────────────
        _SectionLabel(
          isEs
              ? 'EVALUACIÓN DE CIRROSIS (CTP & MADDREY)'
              : 'AVALIAÇÃO DE CIRROSE (CTP & MADDREY)',
          sub,
        ),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark, surf: surf, border: border,
          child: Column(
            children: [
              // Ascites selector
              _ScoreSelector(
                label:    isEs ? 'Ascitis' : 'Ascite',
                dark:     dark,
                txt:      txt,
                sub:      sub,
                border:   border,
                surf:     surf,
                value:    ascites,
                options: isEs
                    ? const ['1: Ausente', '2: Leve/Mod', '3: Grave/Tensa']
                    : const ['1: Ausente', '2: Leve/Mod', '3: Grave/Tensa'],
                onChanged: onAscitesChange,
              ),
              const SizedBox(height: 10),
              // Encephalopathy selector
              _ScoreSelector(
                label:    isEs ? 'Encefalopatía' : 'Encefalopatia',
                dark:     dark,
                txt:      txt,
                sub:      sub,
                border:   border,
                surf:     surf,
                value:    encephalopathy,
                options: isEs
                    ? const ['1: Ausente', '2: Grado 1–2', '3: Grado 3–4']
                    : const ['1: Ausente', '2: Grau 1–2', '3: Grau 3–4'],
                onChanged: onEncephChange,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  tpPatientCtrl,
                      label: isEs ? 'TP Paciente (seg)' : 'TP Paciente (seg)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl:  tpControlCtrl,
                      label: isEs ? 'TP Control (seg)' : 'TP Controle (seg)',
                      type:  const TextInputType.numberWithOptions(decimal: true),
                      dark:  dark, txt: txt, sub: sub,
                      validator: validatePos,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── BLOCO 5: Critérios de Milán (CHC) ──────────────────────────────
        _SectionLabel(
          isEs
              ? 'CRITERIOS DE MILÁN (ONCOLOGÍA CHC)'
              : 'CRITÉRIOS DE MILÃO (ONCOLOGIA CHC)',
          sub,
        ),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark, surf: surf, border: border,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl:  noduleCountCtrl,
                      label: isEs ? 'Número de Nódulos' : 'Número de Nódulos',
                      type:  TextInputType.number,
                      dark:  dark, txt: txt, sub: sub,
                      validator: validateInt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBoxFreeText(
                      ctrl:  noduleSizesCtrl,
                      label: isEs
                          ? 'Diámetros (cm) — separados por coma'
                          : 'Diâmetros (cm) — separados por vírgula',
                      hint: isEs ? 'Ex: 2.5, 1.8' : 'Ex: 2.5, 1.8',
                      dark:  dark, txt: txt, sub: sub,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _BoolToggle(
                label: isEs ? 'Metástasis Extrahepática' : 'Metástase Extra-hepática',
                dark:    dark,
                txt:     txt,
                sub:     sub,
                border:  border,
                value:   hasMetastasis,
                onChange: onMetastasisChange,
              ),
              const SizedBox(height: 8),
              _BoolToggle(
                label: isEs ? 'Invasión Macrovascular' : 'Invasão Macrovascular',
                dark:    dark,
                txt:     txt,
                sub:     sub,
                border:  border,
                value:   hasMacroInvasion,
                onChange: onMacroInvasionChange,
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
  final _HepResult result;
  final bool isEs, dark;
  final Color surf, txt, sub, border;
  final VoidCallback onDeeplink;

  const _ResultsSection({
    required this.result,
    required this.isEs,
    required this.dark,
    required this.surf,
    required this.txt,
    required this.sub,
    required this.border,
    required this.onDeeplink,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(isEs ? 'RESULTADOS' : 'RESULTADOS', sub),
        const SizedBox(height: 10),

        // ── MELD-Na ────────────────────────────────────────────────────────
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.monitor_heart_rounded,
          iconColor: _meldColor(result.meldNa),
          title: 'MELD-Na',
          valueRow: Row(
            children: [
              Text(
                '${result.meldNa}',
                // BUILD 450: MELD score value petróleo
                style: const TextStyle(
                  color: _kPetroleo, fontSize: 24, fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              _MeldBadge(score: result.meldNa, isEs: isEs),
            ],
          ),
          subText: _meldInterpretation(result.meldNa, isEs),
          subColor: _meldColor(result.meldNa),
          formula: 'MELD = 9.57·ln(Cr) + 3.78·ln(Bili) + 11.20·ln(INR) + 6.43  '
              '→  MELD-Na = MELD + 1.32·(137−Na) − [0.033·MELD·(137−Na)]',
        ),
        const SizedBox(height: 10),

        // ── Child-Pugh ─────────────────────────────────────────────────────
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.bar_chart_rounded,
          iconColor: _ctpColor(result.childPughClass),
          title: 'Child-Pugh (CTP)',
          valueRow: Row(
            children: [
              Text(
                '${result.childPughPoints} pts',
                style: TextStyle(
                  color: _ctpColor(result.childPughClass),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              _ClassBadge(cls: result.childPughClass),
            ],
          ),
          subText: _ctpInterpretation(result.childPughClass, isEs),
          subColor: _ctpColor(result.childPughClass),
          formula: isEs
              ? 'Bili + Alb + INR + Ascitis + Encefalopatía  |  A(5–6) · B(7–9) · C(10–15)'
              : 'Bili + Alb + INR + Ascite + Encefalopatia  |  A(5–6) · B(7–9) · C(10–15)',
        ),
        const SizedBox(height: 10),

        // ── FIB-4 ─────────────────────────────────────────────────────────
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.grain_rounded,
          iconColor: _fib4Color(result.fib4),
          title: 'FIB-4',
          valueRow: Row(
            children: [
              Text(
                result.fib4.toStringAsFixed(2),
                style: TextStyle(
                  color: _fib4Color(result.fib4),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              _Pill(
                label: _fib4Label(result.fib4, isEs),
                color: _fib4Color(result.fib4),
              ),
            ],
          ),
          subText: _fib4Interpretation(result.fib4, isEs),
          subColor: _fib4Color(result.fib4),
          formula: 'FIB-4 = (Edad × AST) / (Plaquetas × √ALT)  |  '
              '< 1.30: F0–F1 · 1.30–2.67: Indeterminado · > 2.67: F3–F4',
        ),
        const SizedBox(height: 10),

        // ── APRI ──────────────────────────────────────────────────────────
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.bloodtype_rounded,
          iconColor: _apriColor(result.apri),
          title: 'APRI',
          valueRow: Row(
            children: [
              Text(
                result.apri.toStringAsFixed(2),
                style: TextStyle(
                  color: _apriColor(result.apri),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              _Pill(
                label: _apriLabel(result.apri, isEs),
                color: _apriColor(result.apri),
              ),
            ],
          ),
          subText: _apriInterpretation(result.apri, isEs),
          subColor: _apriColor(result.apri),
          formula: 'APRI = ((AST / AST_ULN) × 100) / Plaquetas  |  '
              '< 0.5: Sin Fibrosis / Sem Fibrose · > 1.5: Cirrosis / Cirrose',
        ),
        const SizedBox(height: 10),

        // ── Maddrey DF ────────────────────────────────────────────────────
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.local_drink_rounded,
          iconColor: result.maddreyDf >= 32.0 ? _kRed : _kGreen,
          title: 'Maddrey DF',
          valueRow: Row(
            children: [
              Text(
                result.maddreyDf.toStringAsFixed(1),
                style: TextStyle(
                  color: result.maddreyDf >= 32.0 ? _kRed : _kGreen,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              if (result.maddreyDf >= 32.0)
                _Pill(
                  label: isEs ? 'Terapia Indicada' : 'Terapia Indicada',
                  color: _kRed,
                )
              else
                _Pill(
                  label: isEs ? 'Bajo Riesgo' : 'Baixo Risco',
                  color: _kGreen,
                ),
            ],
          ),
          subText: result.maddreyDf >= 32.0
              ? (isEs
                  ? 'DF ≥ 32 — Considerar corticoterapia. Mortalidad a 30 días elevada.'
                  : 'DF ≥ 32 — Considerar corticoterapia. Mortalidade em 30 dias elevada.')
              : (isEs
                  ? 'DF < 32 — Riesgo de mortalidad a corto plazo bajo.'
                  : 'DF < 32 — Risco de mortalidade a curto prazo baixo.'),
          subColor: result.maddreyDf >= 32.0 ? _kRed : _kGreen,
          formula: 'Maddrey DF = 4.6 × (TP Paciente − TP Controle) + Bilirrubina Total',
        ),
        const SizedBox(height: 10),

        // ── Critérios de Milán ────────────────────────────────────────────
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.verified_rounded,
          iconColor: result.milanCriteria ? _kGreen : _kRed,
          title: isEs ? 'Criterios de Milán (CHC)' : 'Critérios de Milão (CHC)',
          valueRow: Text(
            result.milanCriteria
                ? (isEs ? 'DENTRO dos Criterios' : 'DENTRO dos Critérios')
                : (isEs ? 'FUERA de Criterios' : 'FORA dos Critérios'),
            style: TextStyle(
              color:      result.milanCriteria ? _kGreen : _kRed,
              fontSize:   18,
              fontWeight: FontWeight.w800,
            ),
          ),
          subText: result.milanCriteria
              ? (isEs
                  ? 'Paciente elegible para trasplante hepático según criterios de Milán (1996).'
                  : 'Paciente elegível para transplante hepático segundo critérios de Milão (1996).')
              : (isEs
                  ? 'Paciente fuera de los criterios. Evaluar criterios extendidos (UCSF, Up-to-7).'
                  : 'Paciente fora dos critérios. Avaliar critérios estendidos (UCSF, Up-to-7).'),
          subColor: result.milanCriteria ? _kGreen : _kRed,
          formula: isEs
              ? 'Nódulo único ≤ 5 cm  OU  até 3 nódulos ≤ 3 cm · Sem metástasis · Sin invasión macrovascular'
              : 'Nódulo único ≤ 5 cm  OU  até 3 nódulos ≤ 3 cm · Sem metástase · Sem invasão macrovascular',
        ),

        // ── Factor R ──────────────────────────────────────────────────────
        const SizedBox(height: 10),
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.swap_vert_rounded,
          iconColor: _factorRColor(result.factorR),
          title: isEs ? 'Factor R — Patrón de Daño' : 'Fator R — Padrão de Lesão',
          valueRow: Row(
            children: [
              Text(
                result.factorR.toStringAsFixed(2),
                style: TextStyle(
                  color: _factorRColor(result.factorR),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              _Pill(
                label: _factorRLabel(result.factorR, isEs),
                color: _factorRColor(result.factorR),
              ),
            ],
          ),
          subText: _factorRInterpretation(result.factorR, isEs),
          subColor: _factorRColor(result.factorR),
          formula: 'Factor R = (ALT / ALT_ULN) / (FA / FA_ULN)  |  '
              'R > 5: Hepatocelular · R 2–5: Mixto · R < 2: Colestático',
        ),

        const SizedBox(height: 24),

        // ── Deeplink Conduta ──────────────────────────────────────────────
        _DeeplinkButton(isEs: isEs, onTap: onDeeplink),
        const SizedBox(height: 8),

        Text(
          isEs
              ? '⚕ Los resultados son de uso clínico exclusivo. La conducta terapéutica se abre en el módulo especializado.'
              : '⚕ Resultados de uso clínico exclusivo. A conduta terapêutica é aberta no módulo especializado.',
          style: TextStyle(color: sub, fontSize: 10, height: 1.4),
        ),
      ],
    );
  }

  // ── Helpers de cor/label MELD ─────────────────────────────────────────────
  Color _meldColor(int score) {
    if (score <= 9)  return _kGreen;
    if (score <= 18) return _kAmber;
    if (score <= 24) return const Color(0xFFf97316);
    return _kRed;
  }

  String _meldInterpretation(int score, bool es) {
    if (score <= 9)  return es ? 'Mortalidad 90 días ~1–2%' : 'Mortalidade 90 dias ~1–2%';
    if (score <= 18) return es ? 'Mortalidad 90 días ~6%'   : 'Mortalidade 90 dias ~6%';
    if (score <= 24) return es ? 'Mortalidad 90 días ~19%'  : 'Mortalidade 90 dias ~19%';
    if (score <= 29) return es ? 'Mortalidad 90 días ~52%'  : 'Mortalidade 90 dias ~52%';
    if (score <= 39) return es ? 'Mortalidad 90 días ~71%'  : 'Mortalidade 90 dias ~71%';
    return es ? 'Mortalidad 90 días ~100%' : 'Mortalidade 90 dias ~100%';
  }

  // ── Helpers de cor/label Child-Pugh ──────────────────────────────────────
  Color _ctpColor(String cls) {
    switch (cls) {
      case 'A': return _kGreen;
      case 'B': return _kAmber;
      default:  return _kRed;
    }
  }

  String _ctpInterpretation(String cls, bool es) {
    switch (cls) {
      case 'A': return es
          ? 'Clase A — Cirrosis compensada. Supervivencia a 1 año ~100%.'
          : 'Classe A — Cirrose compensada. Sobrevida em 1 ano ~100%.';
      case 'B': return es
          ? 'Clase B — Compromiso funcional significativo. Supervivencia a 1 año ~80%.'
          : 'Classe B — Comprometimento funcional significativo. Sobrevida em 1 ano ~80%.';
      default:  return es
          ? 'Clase C — Cirrosis descompensada. Supervivencia a 1 año ~45%.'
          : 'Classe C — Cirrose descompensada. Sobrevida em 1 ano ~45%.';
    }
  }

  // ── FIB-4 ─────────────────────────────────────────────────────────────────
  Color _fib4Color(double v) {
    if (v < 1.30)  return _kGreen;
    if (v <= 2.67) return _kAmber;
    return _kRed;
  }

  String _fib4Label(double v, bool es) {
    if (v < 1.30)  return es ? 'F0–F1'        : 'F0–F1';
    if (v <= 2.67) return es ? 'Indeterminado' : 'Indeterminado';
    return es ? 'F3–F4' : 'F3–F4';
  }

  String _fib4Interpretation(double v, bool es) {
    if (v < 1.30)  return es
        ? 'Bajo riesgo de fibrosis avanzada (F0–F1).'
        : 'Baixo risco de fibrose avançada (F0–F1).';
    if (v <= 2.67) return es
        ? 'Zona indeterminada — considerar biópsia o elastografia.'
        : 'Zona indeterminada — considerar biópsia ou elastografia.';
    return es
        ? 'Alto riesgo de fibrosis avanzada (F3–F4) — evaluar biopsia.'
        : 'Alto risco de fibrose avançada (F3–F4) — avaliar biópsia.';
  }

  // ── APRI ──────────────────────────────────────────────────────────────────
  Color _apriColor(double v) {
    if (v < 0.5)  return _kGreen;
    if (v <= 1.5) return _kAmber;
    return _kRed;
  }

  String _apriLabel(double v, bool es) {
    if (v < 0.5)  return es ? 'Sin Fibrosis'  : 'Sem Fibrose';
    if (v <= 1.5) return es ? 'Indeterminado' : 'Indeterminado';
    return es ? 'Cirrosis' : 'Cirrose';
  }

  String _apriInterpretation(double v, bool es) {
    if (v < 0.5)  return es
        ? 'APRI < 0.5 — Fibrose significativa improvável.'
        : 'APRI < 0.5 — Fibrose significativa improvável.';
    if (v <= 1.5) return es
        ? 'APRI 0.5–1.5 — Zona indeterminada.'
        : 'APRI 0.5–1.5 — Zona indeterminada.';
    return es
        ? 'APRI > 1.5 — Cirrose provável. Evaluar biopsia.'
        : 'APRI > 1.5 — Cirrose provável. Avaliar biópsia.';
  }

  // ── Fator R ───────────────────────────────────────────────────────────────
  Color _factorRColor(double v) {
    if (v > 5.0) return _kRed;
    if (v >= 2.0) return _kAmber;
    // BUILD 450: normal Fator R → petróleo
    return _kPetroleo;
  }

  String _factorRLabel(double v, bool es) {
    if (v > 5.0)  return es ? 'Hepatocelular' : 'Hepatocelular';
    if (v >= 2.0) return es ? 'Mixto'         : 'Misto';
    return es ? 'Colestático' : 'Colestático';
  }

  String _factorRInterpretation(double v, bool es) {
    if (v > 5.0)  return es
        ? 'Patrón hepatocelular predominante (RUCAM).'
        : 'Padrão hepatocelular predominante (RUCAM).';
    if (v >= 2.0) return es
        ? 'Patrón mixto — componente hepatocelular y colestático.'
        : 'Padrão misto — componente hepatocelular e colestático.';
    return es
        ? 'Patrón colestático predominante.'
        : 'Padrão colestático predominante.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares de UI
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel(this.label, this.color);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          color:       color,
          fontSize:    10,
          fontWeight:  FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );
}

class _InputCard extends StatelessWidget {
  final bool dark;
  final Color surf, border;
  final Widget child;
  const _InputCard({
    required this.dark,
    required this.surf,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      );
}

class _FieldBox extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final TextInputType type;
  final bool dark;
  final Color txt, sub;
  final FormFieldValidator<String>? validator;

  const _FieldBox({
    required this.ctrl,
    required this.label,
    required this.type,
    required this.dark,
    required this.txt,
    required this.sub,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    // BUILD 450: light-mode fill = grey[100] + texto preto; dark unchanged
    final fill   = dark ? const Color(0xFF2A2F3A) : const Color(0xFFF1F3F5);
    final border = dark ? _kBorder : const Color(0xFFCBD5E1);
    final accent = dark ? _kCyan : _kPetroleo;
    final inputTxtColor = dark ? txt : Colors.black87;

    return TextFormField(
      controller:  ctrl,
      keyboardType: type,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      validator: validator,
      style: TextStyle(color: inputTxtColor, fontSize: 13, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:      label,
        hintText:       hint,
        labelStyle:     TextStyle(color: sub, fontSize: 11),
        hintStyle:      TextStyle(color: sub.withOpacity(0.5), fontSize: 11),
        filled:         true,
        fillColor:      fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        isDense:        true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: _kRed, width: 1.5),
        ),
        errorStyle: const TextStyle(color: _kRed, fontSize: 9),
      ),
    );
  }
}

/// Campo de texto livre (sem FilteringTextInputFormatter de dígitos)
/// — usado para o campo de diâmetros dos nódulos (aceita vírgulas e espaços)
class _FieldBoxFreeText extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final bool dark;
  final Color txt, sub;

  const _FieldBoxFreeText({
    required this.ctrl,
    required this.label,
    required this.dark,
    required this.txt,
    required this.sub,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    // BUILD 450: light-mode fill = grey[100] + texto preto
    final fill   = dark ? const Color(0xFF2A2F3A) : const Color(0xFFF1F3F5);
    final border = dark ? _kBorder : const Color(0xFFCBD5E1);
    final accent = dark ? _kCyan : _kPetroleo;
    final inputTxtColor = dark ? txt : Colors.black87;

    return TextFormField(
      controller:   ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: inputTxtColor, fontSize: 13, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:      label,
        hintText:       hint,
        labelStyle:     TextStyle(color: sub, fontSize: 11),
        hintStyle:      TextStyle(color: sub.withOpacity(0.5), fontSize: 11),
        filled:         true,
        fillColor:      fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        isDense:        true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }
}

/// Dialysis toggle compacto — Switch row com label
class _DialysisToggle extends StatelessWidget {
  final bool isEs, dark, dialysis;
  final Color txt, sub, border;
  final ValueChanged<bool> onChange;

  const _DialysisToggle({
    required this.isEs,
    required this.dark,
    required this.dialysis,
    required this.txt,
    required this.sub,
    required this.border,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2F3A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isEs
                  ? 'Diálisis en la última semana'
                  : 'Diálise na última semana',
              style: TextStyle(
                color: txt, fontSize: 12, fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value:          dialysis,
            onChanged:      onChange,
            // BUILD 450: petr\u00f3leo no light, cyan no dark
            activeColor:    _kPetroleo,
            inactiveThumbColor: Colors.white54,
          ),
        ],
      ),
    );
  }
}

/// Score selector — inline chip row (1/2/3)
class _ScoreSelector extends StatelessWidget {
  final String label;
  final bool dark;
  final Color txt, sub, border, surf;
  final int value;
  final List<String> options;
  final ValueChanged<int> onChanged;

  const _ScoreSelector({
    required this.label,
    required this.dark,
    required this.txt,
    required this.sub,
    required this.border,
    required this.surf,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: sub, fontSize: 11)),
        const SizedBox(height: 6),
        Row(
          children: List.generate(options.length, (i) {
            final score  = i + 1;
            final active = value == score;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(score),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: i < options.length - 1 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  // BUILD 450: ativo=petróleo sólido/branco, inativo=cinza
                  decoration: BoxDecoration(
                    color: active
                        ? _kPetroleo
                        : (dark ? const Color(0xFF2A2F3A) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? _kPetroleo : border,
                      width: active ? 1.5 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:   10,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color:      active ? Colors.white : sub,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Toggle bool compacto (metástase / invasão)
class _BoolToggle extends StatelessWidget {
  final String label;
  final bool dark, value;
  final Color txt, sub, border;
  final ValueChanged<bool> onChange;

  const _BoolToggle({
    required this.label,
    required this.dark,
    required this.value,
    required this.txt,
    required this.sub,
    required this.border,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2F3A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? _kRed.withOpacity(0.5) : border,
          width: value ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: value ? _kRed : txt,
                fontSize: 12,
                fontWeight: value ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Switch.adaptive(
            value:       value,
            onChanged:   onChange,
            activeColor: _kRed,
            inactiveThumbColor: Colors.white54,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calcular Button
// ─────────────────────────────────────────────────────────────────────────────
class _CalcButton extends StatelessWidget {
  final bool isEs;
  final VoidCallback onTap;
  const _CalcButton({required this.isEs, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            // BUILD 450: petróleo + branco
            backgroundColor: _kPetroleo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'CALCULAR',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.0,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Result Card
// ─────────────────────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final bool dark;
  final Color surf, border, iconColor, subColor;
  final IconData icon;
  final String title, subText;
  final Widget valueRow;
  final String? formula;

  const _ResultCard({
    required this.dark,
    required this.surf,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subText,
    required this.valueRow,
    required this.subColor,
    this.formula,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
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
                      color:      iconColor,
                      fontSize:   10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  valueRow,
                  if (subText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subText,
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

// ─────────────────────────────────────────────────────────────────────────────
// Badge Widgets
// ─────────────────────────────────────────────────────────────────────────────
class _MeldBadge extends StatelessWidget {
  final int score;
  final bool isEs;
  const _MeldBadge({required this.score, required this.isEs});

  Color get _color {
    if (score <= 9)  return _kGreen;
    if (score <= 18) return _kAmber;
    if (score <= 24) return const Color(0xFFf97316);
    return _kRed;
  }

  String get _label {
    if (score <= 9)  return '< 10';
    if (score <= 18) return '10–18';
    if (score <= 24) return '19–24';
    if (score <= 29) return '25–29';
    if (score <= 39) return '30–39';
    return '≥ 40';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        _color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: _color, fontSize: 11, fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _ClassBadge extends StatelessWidget {
  final String cls;
  const _ClassBadge({required this.cls});

  Color get _color {
    switch (cls) {
      case 'A': return _kGreen;
      case 'B': return _kAmber;
      default:  return _kRed;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        _color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Text(
          'Clase $cls',
          style: TextStyle(
            color: _color, fontSize: 11, fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Deeplink Button
// ─────────────────────────────────────────────────────────────────────────────
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
                  // BUILD 444 [P1]: string compliance Apple CDS
                  isEs ? 'Acceder al Soporte' : 'Acessar Suporte',
                  style: const TextStyle(
                    fontSize:   14,
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

// ─────────────────────────────────────────────────────────────────────────────
// _HepResult — resultado tipado imutável
// ─────────────────────────────────────────────────────────────────────────────
class _HepResult {
  final int    meldNa;
  final int    childPughPoints;
  final String childPughClass;
  final double fib4;
  final double apri;
  final double factorR;
  final double maddreyDf;
  final bool   milanCriteria;

  const _HepResult({
    required this.meldNa,
    required this.childPughPoints,
    required this.childPughClass,
    required this.fib4,
    required this.apri,
    required this.factorR,
    required this.maddreyDf,
    required this.milanCriteria,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _HepEngine — motores matemáticos puros, sem efeitos colaterais
// ─────────────────────────────────────────────────────────────────────────────
class _HepEngine {
  _HepEngine._(); // non-instantiable

  // ── MELD-Na ───────────────────────────────────────────────────────────────
  // Referência: Kamath et al. (2001) + Kim et al. (2008) — MELD-Na UNOS 2016.
  // Proteção: log de valores negativos impossibilitada pelo piso em 1.0.
  static int _meldNa({
    required double biliTotal,
    required double creatinine,
    required double inr,
    required double na,
    required bool   dialysis,
  }) {
    // Pisos obrigatórios
    final bili = biliTotal < 1.0 ? 1.0 : biliTotal;
    final safeInr = inr < 1.0 ? 1.0 : inr;

    // Creatinina: diálise ou > 4.0 → fixa em 4.0; senão piso em 1.0
    final double cr;
    if (dialysis || creatinine > 4.0) {
      cr = 4.0;
    } else {
      cr = creatinine < 1.0 ? 1.0 : creatinine;
    }

    // MELD original (arredondado)
    final meldRaw = 9.57 * math.log(cr) +
                    3.78 * math.log(bili) +
                    11.20 * math.log(safeInr) +
                    6.43;
    final meldI = meldRaw.round();

    // Incorporação do Sódio apenas se MELD > 11
    if (meldI <= 11) {
      return meldI.clamp(6, 40);
    }

    // Sódio limitado entre 125 e 137
    final safeNa = na.clamp(125.0, 137.0);
    final meldNaRaw = meldI +
        1.32 * (137.0 - safeNa) -
        (0.033 * meldI * (137.0 - safeNa));

    return meldNaRaw.round().clamp(6, 40);
  }

  // ── Child-Pugh ─────────────────────────────────────────────────────────────
  // Referência: Pugh et al. (1973) — escores de 1 a 3 por parâmetro.
  static ({int points, String cls}) _childPugh({
    required double biliTotal,
    required double albumin,
    required double inr,
    required int    ascites,        // 1=Ausente, 2=Leve/Mod, 3=Grave
    required int    encephalopathy, // 1=Ausente, 2=G1-2, 3=G3-4
  }) {
    // Bilirrubina
    final int biliPts;
    if (biliTotal < 2.0)       biliPts = 1;
    else if (biliTotal <= 3.0) biliPts = 2;
    else                       biliPts = 3;

    // Albumina
    final int albPts;
    if (albumin > 3.5)       albPts = 1;
    else if (albumin >= 2.8) albPts = 2;
    else                     albPts = 3;

    // INR
    final int inrPts;
    if (inr < 1.7)       inrPts = 1;
    else if (inr <= 2.3) inrPts = 2;
    else                 inrPts = 3;

    // Ascite e encefalopatia: soma direta dos pontos 1–3
    final total = biliPts + albPts + inrPts +
                  ascites.clamp(1, 3) + encephalopathy.clamp(1, 3);

    final String cls;
    if (total <= 6)      cls = 'A';
    else if (total <= 9) cls = 'B';
    else                 cls = 'C';

    return (points: total, cls: cls);
  }

  // ── FIB-4 ─────────────────────────────────────────────────────────────────
  // Referência: Sterling et al. (2006).
  // Proteção: ALT ou Plaquetas == 0 → retorna 0.0 (divisão por zero segura).
  static double _fib4({
    required int    age,
    required double ast,
    required double alt,
    required double platelets,
  }) {
    if (alt <= 0.0 || platelets <= 0.0) return 0.0;
    final sqrtAlt = math.sqrt(alt);
    if (sqrtAlt == 0.0) return 0.0;
    return (age * ast) / (platelets * sqrtAlt);
  }

  // ── APRI ──────────────────────────────────────────────────────────────────
  // Referência: Wai et al. (2003).
  static double _apri({
    required double ast,
    required double astUln,
    required double platelets,
  }) {
    if (astUln <= 0.0 || platelets <= 0.0) return 0.0;
    return ((ast / astUln) * 100.0) / platelets;
  }

  // ── Fator R ───────────────────────────────────────────────────────────────
  // Referência: RUCAM (Danan & Benichou, 1993).
  static double _factorR({
    required double alt,
    required double altUln,
    required double fa,
    required double faUln,
  }) {
    if (altUln <= 0.0 || faUln <= 0.0 || fa <= 0.0) return 0.0;
    return (alt / altUln) / (fa / faUln);
  }

  // ── Maddrey Discriminant Function ─────────────────────────────────────────
  // Referência: Maddrey et al. (1978) — Hepatite Alcoólica Grave.
  static double _maddreyDf({
    required double tpPatient,
    required double tpControl,
    required double biliTotal,
  }) {
    return 4.6 * (tpPatient - tpControl) + biliTotal;
  }

  // ── Critérios de Milán ────────────────────────────────────────────────────
  // Referência: Mazzaferro et al. (1996) — N Engl J Med.
  static bool _milanCriteria({
    required int          noduleCount,
    required List<double> noduleSizes,
    required bool         hasMetastasis,
    required bool         hasMacroInvasion,
  }) {
    // Exclusão imediata
    if (hasMetastasis || hasMacroInvasion) return false;
    if (noduleCount <= 0)                  return false;

    // Lesão única ≤ 5 cm
    if (noduleCount == 1) {
      if (noduleSizes.isEmpty) return false;
      return noduleSizes.first <= 5.0;
    }

    // Até 3 lesões, todas ≤ 3 cm
    if (noduleCount <= 3) {
      if (noduleSizes.length < noduleCount) return false;
      return noduleSizes.every((s) => s <= 3.0);
    }

    // Mais de 3 lesões → excluído
    return false;
  }

  // ── Fachada pública ───────────────────────────────────────────────────────
  static _HepResult compute({
    required int    age,
    required double na,
    required double biliTotal,
    required double creatinine,
    required double inr,
    required double albumin,
    required double ast,
    required double astUln,
    required double alt,
    required double altUln,
    required double fa,
    required double faUln,
    required double platelets,
    required int    ascites,
    required int    encephalopathy,
    required double tpPatient,
    required double tpControl,
    required bool   dialysis,
    required int    noduleCount,
    required List<double> noduleSizes,
    required bool   hasMetastasis,
    required bool   hasMacroInvasion,
  }) {
    final ctp = _childPugh(
      biliTotal:      biliTotal,
      albumin:        albumin,
      inr:            inr,
      ascites:        ascites,
      encephalopathy: encephalopathy,
    );

    return _HepResult(
      meldNa: _meldNa(
        biliTotal:  biliTotal,
        creatinine: creatinine,
        inr:        inr,
        na:         na,
        dialysis:   dialysis,
      ),
      childPughPoints: ctp.points,
      childPughClass:  ctp.cls,
      fib4: _fib4(
        age:       age,
        ast:       ast,
        alt:       alt,
        platelets: platelets,
      ),
      apri: _apri(
        ast:       ast,
        astUln:    astUln,
        platelets: platelets,
      ),
      factorR: _factorR(
        alt:    alt,
        altUln: altUln,
        fa:     fa,
        faUln:  faUln,
      ),
      maddreyDf: _maddreyDf(
        tpPatient: tpPatient,
        tpControl: tpControl,
        biliTotal: biliTotal,
      ),
      milanCriteria: _milanCriteria(
        noduleCount:     noduleCount,
        noduleSizes:     noduleSizes,
        hasMetastasis:   hasMetastasis,
        hasMacroInvasion: hasMacroInvasion,
      ),
    );
  }
}
