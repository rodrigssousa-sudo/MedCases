// MEDCASES_PRODUCTIVE_SECOND_BRAND_B1_V2_R1_CARDIO
// LIGHT_MODE_PREMIUM_V1_A_R14_SECTION_LABELS
// ══════════════════════════════════════════════════════════════════════════════
// cardio_tools_screen.dart — BUILD 415-UX-HARMONY / BUILD 445-CROSS-CALC-STATE
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

import '../design_system/foundation/med_typography.dart';
import '../design_system/tokens/med_spacing.dart';
// ─────────────────────────────────────────────────────────────────────────────
// MEDCASES_FERRAMENTAS_4_TABS_SUPER_PREMIUM_STRUCTURED_FOOTER_V1_B_R0_R5_PROOF_GATE_FIX_TRANSACTIONAL
// Paleta canônica MedCases Pro (dark-first) — espelhada de nephrology_tools_screen
// ─────────────────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF1A1D23);
const _kSurface = Color(0xFF252930);
const _kBorder = Color(0xFF374151);
const _kCyan = Color(0xFF0D6B57);
// BUILD 450: Azul Petróleo — substitui neon no Light Mode
const _kPetroleo = Color(0xFF1A365D);
const _kGreen = Color(0xFF0D6B57);
const _kAmber = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kPurple = Color(0xFF8B5CF6);
const _kTextSub = Color(0xFFAEB9CC);

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────
// BUILD 445: AutomaticKeepAliveClientMixin → estado visual sobrevive à troca de aba
// MEDCASES_FERRAMENTAS_4_TABS_SUPER_PREMIUM_STRUCTURED_FOOTER_V1_B_R0_R5_PROOF_GATE_FIX_TRANSACTIONAL_FOOTER_CLEARANCE
double _toolsMainShellFooterBottomInset(BuildContext context) {
  final bottomInset = MediaQuery.of(context).padding.bottom;
  final safeBottom = bottomInset > 0 ? bottomInset : 16.0;
  // MEDCASES_FERRAMENTAS_KEYBOARD_VIEWPORT_SCROLL_PARITY_V1_B_R0
  if (MediaQuery.viewInsetsOf(context).bottom > 0) {
    return 16.0 + safeBottom;
  }
  return 114.0 + safeBottom;
}

class CardioToolsScreen extends StatefulWidget {
  const CardioToolsScreen({super.key});
  @override
  State<CardioToolsScreen> createState() => _CardioToolsScreenState();
}

class _CardioToolsScreenState extends State<CardioToolsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.watch<AppProvider>();
    return _CardioBody(isEs: p.lang == 'es', dark: p.darkMode);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typed immutable result
// ─────────────────────────────────────────────────────────────────────────────
class _CardioResult {
  final double preventRisk; // % 10-year ASCVD
  final int cha2Score; // 0–9
  final int hasbledScore; // 0–9
  final double qtcMs; // ms

  // Raw inputs preserved for deeplink payload
  final int age;
  final bool isFemale;
  final bool hasDiabetes;
  final bool isSmoker;
  final bool hasHtn;
  final bool hasCvDisease;
  final bool hasChf;
  final bool hasCkd;
  final bool hadStroke;
  final bool hasBleedHx;
  final bool hasLabilInr;
  final bool agePlus65;
  final bool usesDrugsAlcohol;
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
    if (isSmoker) base += 2.5;
    if (hasDiabetes) base += 3.1;
    if (hasHtn) base += 1.8;
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
    required bool hadStroke, // +2
    required bool hasCvDisease,
    required bool isFemale,
    required int age,
  }) {
    int s = 0;
    if (hasChf) s += 1;
    if (hasHtn) s += 1;
    if (hasDiabetes) s += 1;
    if (hadStroke) s += 2;
    if (hasCvDisease) s += 1;
    if (isFemale) s += 1;
    if (age >= 75) {
      s += 2;
    } else if (age >= 65) {
      s += 1;
    }
    return s.clamp(0, 9);
  }

  // HAS-BLED: max 9 pts
  static int _hasbled({
    required bool hasHtn, // PAS >160 mmHg
    required bool hasCkd, // Cr >2,3 ou diálise
    required bool hadStroke,
    required bool hasBleedHx,
    required bool hasLabilInr,
    required bool agePlus65,
    required bool usesDrugsAlcohol, // antiplaquetários, AINEs ou ≥8 doses/sem
  }) {
    int s = 0;
    if (hasHtn) s += 1;
    if (hasCkd) s += 1;
    if (hadStroke) s += 1;
    if (hasBleedHx) s += 1;
    if (hasLabilInr) s += 1;
    if (agePlus65) s += 1;
    if (usesDrugsAlcohol) s += 1;
    return s.clamp(0, 9);
  }

  // QTc Bazett: QTc = QT / √(RR)   RR = 60/FC (em segundos)
  static double _qtc({required double qtMs, required double fcBpm}) {
    if (fcBpm <= 0) return 0;
    final rr = 60 / fcBpm;
    return (qtMs / 1000) / _sqrt(rr) * 1000;
  }

  static double _sqrt(double v) => v <= 0
      ? 1.0
      : v < 1e-12
          ? 1.0
          : v == 1.0
              ? 1.0
              : _dartSqrt(v);
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
    required int age,
    required bool isFemale,
    required bool hasDiabetes,
    required bool isSmoker,
    required bool hasHtn,
    required bool hasCvDisease,
    required bool hasChf,
    required bool hasCkd,
    required bool hadStroke,
    required bool hasBleedHx,
    required bool hasLabilInr,
    required bool agePlus65,
    required bool usesDrugsAlcohol,
    required double pas,
    required double colTotal,
    required double qtMs,
    required double fcBpm,
  }) {
    return _CardioResult(
      preventRisk: _prevent(
          isFemale: isFemale,
          hasDiabetes: hasDiabetes,
          isSmoker: isSmoker,
          hasHtn: hasHtn,
          pas: pas,
          colTotal: colTotal),
      cha2Score: _cha2(
          hasChf: hasChf,
          hasHtn: hasHtn,
          hasDiabetes: hasDiabetes,
          hadStroke: hadStroke,
          hasCvDisease: hasCvDisease,
          isFemale: isFemale,
          age: age),
      hasbledScore: _hasbled(
          hasHtn: hasHtn,
          hasCkd: hasCkd,
          hadStroke: hadStroke,
          hasBleedHx: hasBleedHx,
          hasLabilInr: hasLabilInr,
          agePlus65: agePlus65,
          usesDrugsAlcohol: usesDrugsAlcohol),
      qtcMs: _qtc(qtMs: qtMs, fcBpm: fcBpm),
      age: age,
      isFemale: isFemale,
      hasDiabetes: hasDiabetes,
      isSmoker: isSmoker,
      hasHtn: hasHtn,
      hasCvDisease: hasCvDisease,
      hasChf: hasChf,
      hasCkd: hasCkd,
      hadStroke: hadStroke,
      hasBleedHx: hasBleedHx,
      hasLabilInr: hasLabilInr,
      agePlus65: agePlus65,
      usesDrugsAlcohol: usesDrugsAlcohol,
      pas: pas,
      colTotal: colTotal,
      qtMs: qtMs,
      fcBpm: fcBpm,
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

// ─────────────────────────────────────────────────────────────────────────────
// TOOLS V1-I-R1: fluxo canônico de teclado para iOS/Android
// ─────────────────────────────────────────────────────────────────────────────
class _ToolsKeyboardFlowController {
  List<TextEditingController> _order = const <TextEditingController>[];
  final Map<TextEditingController, FocusNode> _nodes =
      <TextEditingController, FocusNode>{};

  BuildContext? _hostContext;
  OverlayEntry? _toolbarEntry;
  int _visibilityRequest = 0;
  bool _disposed = false;
  bool _toolbarRebuildScheduled = false;

  void configure(
    BuildContext context,
    List<TextEditingController> controllers,
  ) {
    if (_disposed) return;
    _hostContext = context;

    final unique = <TextEditingController>[];
    for (final controller in controllers) {
      if (!unique.contains(controller)) unique.add(controller);
    }

    final removed = _nodes.keys
        .where((controller) => !unique.contains(controller))
        .toList(growable: false);
    for (final controller in removed) {
      final node = _nodes.remove(controller);
      node?.removeListener(_handleFocusChanged);
      node?.dispose();
    }

    for (final controller in unique) {
      _nodes.putIfAbsent(controller, () {
        final node = FocusNode(debugLabel: 'tools_keyboard_field');
        node.addListener(_handleFocusChanged);
        return node;
      });
    }

    _order = List<TextEditingController>.unmodifiable(unique);
    _scheduleToolbarRebuild();
  }

  FocusNode nodeFor(TextEditingController controller) {
    final node = _nodes[controller];
    assert(node != null, 'Controller fora do fluxo de teclado.');
    return node!;
  }

  bool isLast(TextEditingController controller) =>
      _order.isNotEmpty && identical(_order.last, controller);

  TextEditingController? get _activeController {
    for (final controller in _order) {
      if (_nodes[controller]?.hasFocus ?? false) return controller;
    }
    return null;
  }

  void _handleFocusChanged() {
    if (_disposed) return;
    final active = _activeController;

    if (active == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && _activeController == null) _removeToolbar();
      });
      return;
    }

    _ensureToolbar();
    final node = _nodes[active];
    if (node != null) _scheduleVisibility(node);
  }

  void advance(TextEditingController controller) {
    if (_disposed) return;
    final index = _order.indexOf(controller);
    if (index < 0) return;

    if (index >= _order.length - 1) {
      _nodes[controller]?.unfocus();
      _removeToolbar();
      return;
    }

    final nextController = _order[index + 1];
    final nextNode = _nodes[nextController];
    if (nextNode == null) return;

    nextNode.requestFocus();
    _scheduleVisibility(nextNode);
  }

  void handleMetricsChanged() {
    if (_disposed) return;
    _scheduleToolbarRebuild();
    final active = _activeController;
    final node = active == null ? null : _nodes[active];
    if (node != null) _scheduleVisibility(node);
  }

  void _scheduleVisibility(FocusNode node) {
    final request = ++_visibilityRequest;

    void ensureVisible() {
      if (_disposed || request != _visibilityRequest || !node.hasFocus) return;
      final fieldContext = node.context;
      if (fieldContext == null) return;

      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.24,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => ensureVisible());
    Future<void>.delayed(
      const Duration(milliseconds: 180),
      ensureVisible,
    );
    Future<void>.delayed(
      const Duration(milliseconds: 360),
      ensureVisible,
    );
  }

  void _ensureToolbar() {
    final hostContext = _hostContext;
    if (_disposed || hostContext == null) return;

    if (_toolbarEntry != null) {
      _scheduleToolbarRebuild();
      return;
    }

    final overlay = Overlay.maybeOf(hostContext, rootOverlay: true);
    if (overlay == null) return;

    _toolbarEntry = OverlayEntry(
      builder: (_) {
        final currentHost = _hostContext;
        final active = _activeController;
        if (currentHost == null || active == null) {
          return const SizedBox.shrink();
        }

        final keyboardHeight = MediaQuery.of(currentHost).viewInsets.bottom;
        if (keyboardHeight <= 0) return const SizedBox.shrink();
        final last = isLast(active);

        // MEDCASES_FERRAMENTAS_KEYBOARD_FLOATING_NEXT_ACCESSORY_V1_B_R0
        final isDark =
            Theme.of(currentHost).brightness == Brightness.dark;
        final isEs =
            Localizations.localeOf(currentHost).languageCode == 'es';
        final actionLabel =
            last ? 'OK' : (isEs ? 'SIGUIENTE' : 'PRÓXIMO');
        final buttonBg =
            isDark ? Colors.white : const Color(0xFF1A1D23);
        final buttonFg =
            isDark ? const Color(0xFF111318) : Colors.white;
        final buttonBorder =
            isDark ? const Color(0xFFD8DEE7) : const Color(0xFF374151);

        return Positioned(
          right: 12,
          bottom: keyboardHeight + 8,
          child: TextFieldTapRegion(
            child: Semantics(
              button: true,
              label: actionLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => advance(active),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 104),
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: buttonBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: buttonBorder,
                      width: 0.7,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.14 : 0.10,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel,
                        style: TextStyle(
                          color: buttonFg,
                          fontSize: MedTypography.auxiliarySize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          decoration: TextDecoration.none,
                          decorationColor: Colors.transparent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                        size: 15,
                        color: buttonFg,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_toolbarEntry!);
  }

  void _scheduleToolbarRebuild() {
    if (_disposed || _toolbarRebuildScheduled) return;
    _toolbarRebuildScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toolbarRebuildScheduled = false;
      if (_disposed) return;
      _toolbarEntry?.markNeedsBuild();
    });
  }

  void _removeToolbar() {
    _toolbarEntry?.remove();
    _toolbarEntry = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _visibilityRequest++;
    _removeToolbar();

    for (final node in _nodes.values) {
      node.removeListener(_handleFocusChanged);
      node.dispose();
    }
    _nodes.clear();
    _order = const <TextEditingController>[];
    _hostContext = null;
  }
}

class _ToolsKeyboardFlowScope extends InheritedWidget {
  final _ToolsKeyboardFlowController flow;

  const _ToolsKeyboardFlowScope({
    required this.flow,
    required super.child,
  });

  static _ToolsKeyboardFlowController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ToolsKeyboardFlowScope>();
    assert(scope != null, 'Fluxo de teclado não encontrado.');
    return scope!.flow;
  }

  @override
  bool updateShouldNotify(_ToolsKeyboardFlowScope oldWidget) =>
      !identical(flow, oldWidget.flow);
}

class _CardioBodyState extends State<_CardioBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _keyboardFlow = _ToolsKeyboardFlowController();
  // ── Controllers ──────────────────────────────────────────────────────────
  // BUILD 445: controllers via ToolsStateProvider — age, pas, col, qt, fc.
  // Sem controllers locais de texto em Cardio.

  // ── BUILD 427: Restore banner state
  bool _showRestoreBanner = false;

  // ── BUILD 426: Patient autofill ─────────────────────────────────────────────
  Future<void> _showPatientSelectionSheet(
      BuildContext context, AppProvider p) async {
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

  void _autofillFromSession(PacienteSession session) {
    try {
      final paciente = session.paciente;
      final tp = context.read<ToolsStateProvider>();
      final age = parseAgeFromString(paciente.idade);
      final sexo = paciente.sexo.trim().toUpperCase();
      final bool? female = sexo.isEmpty ? null : sexo == 'F';
      tp.applyFromPatient(age: age, female: female);
      if (!mounted) return;
      setState(() {
        _agePlus65 = (age ?? int.tryParse(tp.ageCtrl.text) ?? 0) >= 65;
        _isFemale = tp.isFemale;
      });
    } catch (_) {
      // Falha silenciosa — nunca quebra a UI clínica.
    }
  }

  // ── Boolean risk factors ──────────────────────────────────────────────────
  bool _isFemale = false;
  bool _hasDiabetes = false;
  bool _isSmoker = false;
  bool _hasHtn = false;
  bool _hasCvDisease = false;
  bool _hasChf = false;
  bool _hasCkd = false;
  bool _hadStroke = false;
  bool _hasBleedHx = false;
  bool _hasLabilInr = false;
  bool _agePlus65 = false;
  bool _usesDrugsAlc = false;

  // ── State ─────────────────────────────────────────────────────────────────
  _CardioResult? _result;
  final _formKey = GlobalKey<FormState>();

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
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

  // BUILD 445: restaura campos cardio — todos compartilhados via ToolsStateProvider
  void _restoreFromCache() {
    final p = context.read<AppProvider>();
    final tp = context.read<ToolsStateProvider>();
    tp.applyFromCache(p.toolsInputCache);
    setState(() {
      _isFemale = tp.isFemale;
      final age = int.tryParse(tp.ageCtrl.text) ?? 0;
      _agePlus65 = age >= 65;
      _showRestoreBanner = false;
    });
  }

  void _discardCache() {
    context.read<AppProvider>().clearToolsCache();
    setState(() => _showRestoreBanner = false);
  }

  @override
  void didChangeMetrics() {
    _keyboardFlow.handleMetricsChanged();
  }

  @override
  void dispose() {
    // BUILD 445: controllers pertencem ao ToolsStateProvider — NÃO dispose aqui.
    try {
      final p = context.read<AppProvider>();
      final tp = context.read<ToolsStateProvider>();
      tp.setFemale(_isFemale);
      tp.refreshPendingFlag();
      p.saveToolsCache(tp.exportToCache());
    } catch (_) {}
    _animCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _keyboardFlow.dispose();
    super.dispose();
  }

  // ── BUILD 428: Sync labs + scores to Firestore (fire-and-forget) ──────────
  void _syncResultToFirestore(_CardioResult r) {
    try {
      final p = context.read<AppProvider>();
      final uid = p.currentUser?.uid ?? '';
      final patientKey = p.activeImportedPatientKey ?? '';
      if (uid.isEmpty || patientKey.isEmpty) return;

      final tp2c = context.read<ToolsStateProvider>();
      final labData = <String, dynamic>{
        'edad': tp2c.ageCtrl.text,
        'pas': tp2c.pasCtrl.text,
        'colesterol': tp2c.colCtrl.text,
      };

      final scores = <String, dynamic>{
        'preventRisk': r.preventRisk,
        'cha2Score': r.cha2Score,
        'hasbledScore': r.hasbledScore,
        'qtcMs': r.qtcMs,
      };

      final scoresText = 'PREVENT/ASCVD: ${r.preventRisk.toStringAsFixed(1)}%, '
          'CHA2DS2-VASc: ${r.cha2Score}, '
          'HAS-BLED: ${r.hasbledScore}, '
          'QTc: ${r.qtcMs.toStringAsFixed(0)}ms';

      // ignore: unawaited_futures
      InternacionFirestoreService.updatePatientLaboratories(
        uid: uid,
        patientKey: patientKey,
        importedSession: context.read<AppProvider>().activeImportedSession,
        labData: labData,
        scores: scores,
        scoresText: scoresText,
      );
    } catch (_) {
      // Fire-and-forget: falhas nunca interrompem a UI clinica
    }
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
    final tp = context.read<ToolsStateProvider>();
    final age = int.tryParse(tp.ageCtrl.text.trim()) ?? 0;
    final pas = _pd(tp.pasCtrl.text) ?? 120.0;
    final col = _pd(tp.colCtrl.text) ?? 200.0;
    final qt = _pd(tp.qtCtrl.text) ?? 400.0;
    final fc = _pd(tp.fcCtrl.text) ?? 75.0;

    setState(() {
      _agePlus65 = age >= 65;
      _result = _CardioEngine.compute(
        age: age,
        isFemale: tp.isFemale,
        hasDiabetes: _hasDiabetes,
        isSmoker: _isSmoker,
        hasHtn: _hasHtn,
        hasCvDisease: _hasCvDisease,
        hasChf: _hasChf,
        hasCkd: _hasCkd,
        hadStroke: _hadStroke,
        hasBleedHx: _hasBleedHx,
        hasLabilInr: _hasLabilInr,
        agePlus65: _agePlus65,
        usesDrugsAlcohol: _usesDrugsAlc,
        pas: pas,
        colTotal: col,
        qtMs: qt,
        fcBpm: fc,
      );
    });
    if (_result != null) _syncResultToFirestore(_result!);

    _animCtrl.forward(from: 0);
  }

  // BUILD 429-APPLE-COMPLIANCE: sync — abre CalculadoraScreen interna.
  // BUILD 444 [P2+P3]: URL dinâmica Cardio → /?modulo=cardiologia.
  // Abre CalculadoraScreen (WebView integrada em tela cheia) no endpoint
  // da especialidade — NUNCA launchUrl externo (Apple compliance).
  void _launchDeeplink() {
    if (_result == null) return;
    HapticFeedback.mediumImpact();
    // BUILD 447-URL-PAYLOAD + BUILD 449-LANG-PAYLOAD: serializa idioma e
    // campos Cardio como query params.
    const baseUrl = 'https://medcasescalcu.com/';
    final langCode = widget.isEs ? 'es' : 'pt';
    final queryParams = context
        .read<ToolsStateProvider>()
        .buildQueryStringForSpecialty('cardio', langCode);
    final deeplinkPayload = queryParams.startsWith('?')
        ? queryParams.substring(1)
        : queryParams;
    final conductaUrl =
        '$baseUrl?modulo=cardiologia&$deeplinkPayload';
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalculadoraScreen(initialUrl: conductaUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final dark = widget.dark;
    final bg = dark ? _kBg : Colors.white; // MEDCASES_TOOLS_COMPACT_WHITE_CONTENT_V1_B_R3_LIGHT_WHITE
    final surf = dark ? _kSurface : Colors.white;
    final bord = dark ? _kBorder : const Color(0xFFE5E7EB);
    final txt = dark ? Colors.white : const Color(0xFF0F1116);
    final sub = dark ? _kTextSub : const Color(0xFF6B7280);

    final toolsState = context.watch<ToolsStateProvider>();
    _keyboardFlow.configure(
      context,
      <TextEditingController>[
        toolsState.ageCtrl,
        toolsState.pasCtrl,
        toolsState.colCtrl,
        toolsState.qtCtrl,
        toolsState.fcCtrl,
      ],
    );

    // MEDCASES_FERRAMENTAS_KEYBOARD_VIEWPORT_SCROLL_PARITY_V1_B_R0
    // MainShell é o único owner do recorte físico do teclado.
    return ColoredBox(
      color: bg,
      child: _ToolsKeyboardFlowScope(
          flow: _keyboardFlow,
          child: Form(
            key: _formKey,
            child: ListView(
                padding: EdgeInsets.fromLTRB(
                  MedSpacing.screenHorizontalPadding,
                  0,
                  MedSpacing.screenHorizontalPadding,
                  _toolsMainShellFooterBottomInset(context),
                ), // MEDCASES_TOOLS_COMPACT_WHITE_CONTENT_V1_B_R3_LIST_TOP_ZERO
                children: [
                  // ── Header ─────────────────────────────────────────────────────
                  const SizedBox(height: 0), // MEDCASES_TOOLS_COMPACT_WHITE_CONTENT_V1_B_R3_HEADER_REMOVED

                  // ── BUILD 426: Chip de importação de paciente ──────────────────
                  Align(
                      alignment: Alignment.center,
                      child: FractionallySizedBox(
                        widthFactor: 0.90,
                        child: ToolsPatientImportChip(
                    isEs: isEs,
                    dark: dark,
                    onTap: () {
                      final p = context.read<AppProvider>();
                      _showPatientSelectionSheet(context, p);
                    },
                  ),
                      ),
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

                  // ── Input Section ───────────────────────────────────────────────
                  _InputSection(
                    isEs: isEs,
                    surf: surf,
                    bord: bord,
                    txt: txt,
                    sub: sub,
                    ageCtrl: context.read<ToolsStateProvider>().ageCtrl,
                    pasCtrl: context.read<ToolsStateProvider>().pasCtrl,
                    colCtrl: context.read<ToolsStateProvider>().colCtrl,
                    qtCtrl: context.read<ToolsStateProvider>().qtCtrl,
                    fcCtrl: context.read<ToolsStateProvider>().fcCtrl,
                    isFemale: context.read<ToolsStateProvider>().isFemale,
                    hasDiabetes: _hasDiabetes,
                    isSmoker: _isSmoker,
                    hasHtn: _hasHtn,
                    hasCvDisease: _hasCvDisease,
                    hasChf: _hasChf,
                    hasCkd: _hasCkd,
                    hadStroke: _hadStroke,
                    hasBleedHx: _hasBleedHx,
                    hasLabilInr: _hasLabilInr,
                    usesDrugsAlc: _usesDrugsAlc,
                    onToggleFemale: (v) {
                      context.read<ToolsStateProvider>().setFemale(v);
                      setState(() => _isFemale = v);
                    },
                    onToggleDiabetes: (v) => setState(() => _hasDiabetes = v),
                    onToggleSmoker: (v) => setState(() => _isSmoker = v),
                    onToggleHtn: (v) => setState(() => _hasHtn = v),
                    onToggleCvDisease: (v) => setState(() => _hasCvDisease = v),
                    onToggleChf: (v) => setState(() => _hasChf = v),
                    onToggleCkd: (v) => setState(() => _hasCkd = v),
                    onToggleStroke: (v) => setState(() => _hadStroke = v),
                    onToggleBleedHx: (v) => setState(() => _hasBleedHx = v),
                    onToggleLabilInr: (v) => setState(() => _hasLabilInr = v),
                    onToggleDrugsAlc: (v) => setState(() => _usesDrugsAlc = v),
                    validatePositive: _validatePositive,
                    validateAge: _validateAge,
                  ),
                  const SizedBox(height: 16),

                  // ── Calcular button ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: // TOOLS V1-G-R1-R3: calcular delicado padronizado
                        Align(
                      alignment: Alignment.center,
                      child: FractionallySizedBox(
                        widthFactor: 0.72,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _calculate,
                            style: ElevatedButton.styleFrom(
                              // BUILD 450: petróleo + branco
                              backgroundColor: const Color(0xFF0D6B57),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              isEs ? 'CALCULAR' : 'CALCULAR',
                              style: const TextStyle(
                                fontSize: MedTypography.auxiliarySize,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
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
                          isEs: isEs,
                          dark: dark,
                          surf: surf,
                          txt: txt,
                          sub: sub,
                          bord: bord,
                          onDeeplink: _launchDeeplink,
                        ),
                      ),
                    ),
                  ],
                ],
              ), // ListView
          )), // Form
    ); // ColoredBox
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _CardioHeader extends StatelessWidget {
  final bool isEs;
  final Color surf, bord, txt, sub;
  const _CardioHeader({
    required this.isEs,
    required this.surf,
    required this.bord,
    required this.txt,
    required this.sub,
  });

  // TOOLS V1-H-R1: header plano unificado
  // TOOLS V1-H-R1: subtítulo branco

  @override
  Widget build(
          BuildContext
              context) => /* MEDCASES_TOOLS_V1_H_R12_R5_BACKGROUND_ONLY_EXTENSION */
      SizedBox(
        height: 68,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -MedSpacing.screenHorizontalPadding,
              right: -MedSpacing.screenHorizontalPadding,
              top: -32,
              height: 32,
              child: IgnorePointer(
                child: ColoredBox(
                  color: surf,
                ),
              ),
            ),
            Positioned(
              left: -MedSpacing.screenHorizontalPadding,
              right: -MedSpacing.screenHorizontalPadding,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(MedSpacing.screenHorizontalPadding, 14, MedSpacing.screenHorizontalPadding, 14),
                    decoration: BoxDecoration(
                      color: surf,
                      border: Border(
                        bottom: BorderSide(color: bord),
                      ),
                    ),
                    child: Row(
                      children: [
                        // TOOLS V1-H-R1: ícone sem box secundário
                        const Icon(Icons.favorite_rounded,
                            color: _kPetroleo, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEs ? 'CARDIOLOGÍA' : 'CARDIOLOGIA',
                                style: TextStyle(
                                  color: txt,
                                  fontSize: MedTypography.internalTitleSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'PREVENT/ASCVD · CHA₂DS₂-VASc · HAS-BLED · QTc',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize:
                                        MedTypography.auxiliarySize) /* MEDCASES_TOOLS_V1_H_R9_CANONICAL_HEADER_STYLE */,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    required this.isEs,
    required this.surf,
    required this.bord,
    required this.txt,
    required this.sub,
    required this.ageCtrl,
    required this.pasCtrl,
    required this.colCtrl,
    required this.qtCtrl,
    required this.fcCtrl,
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
    required this.usesDrugsAlc,
    required this.onToggleFemale,
    required this.onToggleDiabetes,
    required this.onToggleSmoker,
    required this.onToggleHtn,
    required this.onToggleCvDisease,
    required this.onToggleChf,
    required this.onToggleCkd,
    required this.onToggleStroke,
    required this.onToggleBleedHx,
    required this.onToggleLabilInr,
    required this.onToggleDrugsAlc,
    required this.validatePositive,
    required this.validateAge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Bloco 1: Dados Demográficos + Hemodinâmicos ───────────────────
        _InputCard(
          title: isEs ? 'DATOS CLÍNICOS' : 'DADOS CLÍNICOS',
          surf: surf,
          bord: bord,
          child: Column(
            children: [
              // Linha 1: Idade + Sexo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.5),
                      child: _SexToggle(
                        isEs: isEs,
                        isFemale: isFemale,
                        onChanged: onToggleFemale,
                        sub: sub,
                      ),
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
          surf: surf,
          bord: bord,
          child: Column(
            children: [
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'Diabetes' : 'Diabetes',
                    value: hasDiabetes,
                    onChanged: onToggleDiabetes,
                  ),
                  _ToggleItem(
                    label: isEs ? 'Tabaquismo' : 'Tabagismo',
                    value: isSmoker,
                    onChanged: onToggleSmoker,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'HTA' : 'HAS',
                    value: hasHtn,
                    onChanged: onToggleHtn,
                  ),
                  _ToggleItem(
                    label: isEs ? 'Enf. Vascular' : 'D. Vascular',
                    value: hasCvDisease,
                    onChanged: onToggleCvDisease,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'IC Congestiva' : 'IC Congestiva',
                    value: hasChf,
                    onChanged: onToggleChf,
                  ),
                  _ToggleItem(
                    label: isEs ? 'ERC (Cr>2,3)' : 'DRC (Cr>2,3)',
                    value: hasCkd,
                    onChanged: onToggleCkd,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'ACV/AIT previo' : 'AVC/AIT prévio',
                    value: hadStroke,
                    onChanged: onToggleStroke,
                  ),
                  _ToggleItem(
                    label: isEs ? 'Hx Sangrado' : 'Hx Sangramento',
                    value: hasBleedHx,
                    onChanged: onToggleBleedHx,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ToggleRow(
                items: [
                  _ToggleItem(
                    label: isEs ? 'INR Lábil' : 'INR Lábil',
                    value: hasLabilInr,
                    onChanged: onToggleLabilInr,
                  ),
                  _ToggleItem(
                    label: isEs ? 'Drogas/Alcohol' : 'Drogas/Álcool',
                    value: usesDrugsAlc,
                    onChanged: onToggleDrugsAlc,
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
    required this.result,
    required this.isEs,
    required this.dark,
    required this.surf,
    required this.txt,
    required this.sub,
    required this.bord,
    required this.onDeeplink,
  });

  // ── PREVENT color ─────────────────────────────────────────────────────────
  Color _preventColor(double risk) {
    if (risk < 5) return _kGreen;
    if (risk < 10) return _kAmber;
    if (risk < 20) return const Color(0xFFf97316);
    return _kRed;
  }

  String _preventLabel(double risk, {required bool es}) {
    if (risk < 5) return es ? 'Riesgo Bajo (<5%)' : 'Risco Baixo (<5%)';
    if (risk < 10)
      return es ? 'Riesgo Limítrofe (5-10%)' : 'Risco Limítrofe (5-10%)';
    if (risk < 20)
      return es ? 'Riesgo Intermedio (10-20%)' : 'Risco Intermediário (10-20%)';
    return es ? 'Riesgo Alto (≥20%)' : 'Risco Alto (≥20%)';
  }

  // ── CHA₂DS₂-VASc label ───────────────────────────────────────────────────
  Color _cha2Color(int s) {
    if (s == 0) return _kGreen;
    if (s == 1) return _kAmber;
    return _kRed;
  }

  String _cha2Label(int s, {required bool es}) {
    if (s == 0)
      return es
          ? 'Sin anticoagulación indicada'
          : 'Sem anticoagulação indicada';
    if (s == 1)
      return es
          ? 'Considerar anticoagulación (♂) / Sin indicación (♀)'
          : 'Considerar anticoagulação (♂) / Sem indicação (♀)';
    return es
        ? 'Anticoagulación recomendada (AVC anual ≥2%)'
        : 'Anticoagulação recomendada (AVC anual ≥2%)';
  }

  // ── HAS-BLED label ────────────────────────────────────────────────────────
  Color _hasbledColor(int s) {
    if (s <= 1) return _kGreen;
    if (s <= 2) return _kAmber;
    return _kRed;
  }

  String _hasbledLabel(int s, {required bool es}) {
    if (s <= 1)
      return es ? 'Riesgo bajo de sangrado' : 'Risco baixo de sangramento';
    if (s <= 2)
      return es
          ? 'Riesgo moderado — vigilar factores corregibles'
          : 'Risco moderado — vigiar fatores corrigíveis';
    return es
        ? 'Riesgo alto — revisar necesidad de anticoagulación'
        : 'Risco alto — revisar necessidade de anticoagulação';
  }

  // ── QTc label ─────────────────────────────────────────────────────────────
  Color _qtcColor(double ms) {
    if (ms <= 440) return _kGreen;
    if (ms <= 480) return _kAmber;
    return _kRed;
  }

  String _qtcLabel(double ms, {required bool es}) {
    if (ms <= 440) return es ? 'QTc normal (≤440 ms)' : 'QTc normal (≤440 ms)';
    if (ms <= 480)
      return es ? 'QTc prolongado — vigilar' : 'QTc prolongado — vigilar';
    return es
        ? 'QTc muy prolongado — riesgo de Torsades'
        : 'QTc muito prolongado — risco de Torsades';
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
          style: TextStyle(
              color: color, fontSize: MedTypography.microTextSize, fontWeight: FontWeight.w700),
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
            color: sub,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.75,
          ),
        ),
        const SizedBox(height: 6),

        // 1. PREVENT/ASCVD
        _ResultCard(
          dark: dark,
          surf: surf,
          bord: bord,
          icon: Icons.monitor_heart_rounded,
          iconColor: _preventColor(result.preventRisk),
          title: 'PREVENT / ASCVD',
          valueRow: Row(
            children: [
              Text(
                '${result.preventRisk.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: txt,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
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
        const SizedBox(height: 6),

        // 2. CHA₂DS₂-VASc
        _ResultCard(
          dark: dark,
          surf: surf,
          bord: bord,
          icon: Icons.bloodtype_rounded,
          iconColor: _cha2Color(result.cha2Score),
          title: 'CHA₂DS₂-VASc',
          valueRow: Row(
            children: [
              Text(
                '${result.cha2Score} pts',
                style: TextStyle(
                  color: txt,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
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
        const SizedBox(height: 6),

        // 3. HAS-BLED
        _ResultCard(
          dark: dark,
          surf: surf,
          bord: bord,
          icon: Icons.warning_amber_rounded,
          iconColor: _hasbledColor(result.hasbledScore),
          title: 'HAS-BLED',
          valueRow: Row(
            children: [
              Text(
                '${result.hasbledScore} pts',
                style: TextStyle(
                  color: txt,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
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
        const SizedBox(height: 6),

        // 4. QTc
        _ResultCard(
          dark: dark,
          surf: surf,
          bord: bord,
          icon: Icons.graphic_eq_rounded,
          iconColor: _qtcColor(result.qtcMs),
          title: 'QTc (Bazett)',
          valueRow: Row(
            children: [
              Text(
                '${result.qtcMs.toStringAsFixed(0)} ms',
                style: TextStyle(
                  color: txt,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
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

        const SizedBox(height: 12),

        // ── Deeplink button ────────────────────────────────────────────────
        _DeeplinkButton(isEs: isEs, onTap: onDeeplink),
        const SizedBox(height: 8),

        // Disclaimer Apple-compliant
        Text(
          isEs
              ? '⚕ Resultados para apoyo clínico educacional. No sustituye juicio médico individualizado.'
              : '⚕ Resultados para apoio clínico educacional. Não substitui julgamento médico individualizado.',
          style: TextStyle(color: sub, fontSize: MedTypography.microTextSize, height: 1.4),
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
// LIGHT_MODE_PREMIUM_V1_A_R14_CARDIO_INPUTCARD_SECTION
class _InputCard extends StatelessWidget {
  final String title;
  final Color surf, bord;
  final Widget child;

  const _InputCard({
    required this.title,
    required this.surf,
    required this.bord,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // MEDCASES_FERRAMENTAS_CANONICAL_FLAT_SURFACE_CONVERGENCE_V1_B_R0_SECTION_BODY
    final dark = Theme.of(context).brightness == Brightness.dark;
    final divider = dark
        ? const Color(0xFF374151)
        : const Color(0xFFD8E0E7);
    final heading = dark
        ? const Color(0xFFA8B2C1)
        : const Color(0xFF334155);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 7),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: heading,
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.75,
            ),
          ),
        ),
        child,
        const SizedBox(height: 11),
        Divider(
          height: 0.7,
          thickness: 0.7,
          color: divider,
        ),
      ],
    );
  }
}


/// Campo numérico com label canônico
// LIGHT_MODE_PREMIUM_V1_A_R14_CARDIO_NFIELD
class _NField extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final FormFieldValidator<String> validator;

  const _NField({
    required this.label,
    required this.ctrl,
    required this.hint,
    required this.validator,
  });

  IconData get _fieldIcon {
    final normalized = label.toLowerCase();
    if (normalized.contains('edad') || normalized.contains('idade')) {
      return Icons.person_outline;
    }
    if (normalized.contains('pas')) {
      return Icons.monitor_heart_outlined;
    }
    if (normalized.contains('qt')) {
      return Icons.timer_outlined;
    }
    if (normalized.contains('fc')) {
      return Icons.favorite_border_rounded;
    }
    if (normalized.contains('col')) {
      return Icons.water_drop_outlined;
    }
    return Icons.monitor_heart_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? const Color(0xFF20252D) : const Color(0xFFF7F9FB);
    final border = dark ? const Color(0xFF2A3039) : const Color(0xFFEDF1F4);
    final primary = dark ? Colors.white : const Color(0xFF0F172A);
    final secondary =
        dark ? const Color(0xFFA8B2C1) : const Color(0xFF334155);
    final flow = _ToolsKeyboardFlowScope.of(context);
    final node = flow.nodeFor(ctrl);
    final isLast = flow.isLast(ctrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: secondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedBuilder(
          animation: node,
          builder: (context, _) {
            final activeBorder =
                node.hasFocus ? const Color(0xFF0D6B57) : border;
            final activeIcon =
                node.hasFocus ? const Color(0xFF0D6B57) : secondary;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: activeBorder,
                  width: node.hasFocus ? 1.2 : 0.7,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(_fieldIcon, size: 17, color: activeIcon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      focusNode: node,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      textInputAction:
                          isLast ? TextInputAction.done : TextInputAction.next,
                      onFieldSubmitted: (_) => flow.advance(ctrl),
                      scrollPadding:
                          const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      cursorColor: const Color(0xFF0D6B57),
                      controller: ctrl,
                      validator: validator,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        color: primary,
                        fontSize: MedTypography.clinicalBodySize,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        errorStyle: TextStyle(
                          color: _kRed,
                          fontSize: MedTypography.microTextSize,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SexToggle extends StatelessWidget {
  final bool isEs, isFemale;
  final ValueChanged<bool> onChanged;
  final Color sub;
  const _SexToggle({
    required this.isEs,
    required this.isFemale,
    required this.onChanged,
    required this.sub,
  });

  // TOOLS V1-H-R1: seletor sexual unificado
  // UI V1-J-R5: altura idêntica ao input e alinhamento geométrico
  // MEDCASES_FERRAMENTAS_CARDIO_LIGHT_SEX_SELECTOR_V1_B_R0_R3

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(builder: (ctx) {
          final isDk = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDk ? const Color(0xFF2D3340) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDk
                    ? const Color(0xFF374151)
                    : const Color(0xFFD8E0E7),
                width: 0.7,
              ),
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
                        color: !isFemale
                            ? (isDk
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFEFF6FF))
                            : (isDk
                                ? const Color(0xFF2D3340)
                                : Colors.white),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(9),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEs ? 'Masculino' : 'Masculino',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDk
                                ? (!isFemale
                                    ? Colors.white
                                    : Colors.white70)
                                : (!isFemale
                                    ? const Color(0xFF1D4ED8)
                                    : const Color(0xFF334155)),
                            fontSize: MedTypography.auxiliarySize,
                            fontWeight: FontWeight.w600,
                          ),
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
                        color: isFemale
                            ? (isDk
                                ? const Color(0xFFEC4899)
                                : const Color(0xFFFDF2F8))
                            : (isDk
                                ? const Color(0xFF2D3340)
                                : Colors.white),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(9),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEs ? 'Femenino' : 'Feminino',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDk
                                ? (isFemale
                                    ? Colors.white
                                    : Colors.white70)
                                : (isFemale
                                    ? const Color(0xFFBE185D)
                                    : const Color(0xFF334155)),
                            fontSize: MedTypography.auxiliarySize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Par de toggles compactos em linha
class _ToggleItem {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleItem(
      {required this.label, required this.value, required this.onChanged});
}

class _ToggleRow extends StatelessWidget {
  final List<_ToggleItem> items;
  const _ToggleRow({required this.items});

  // TOOLS V1-H-R1: fatores de risco escuros
  // MEDCASES_FERRAMENTAS_CARDIO_LIGHT_RISK_SELECTOR_V1_B_R0_R3

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

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
                color: dark
                    ? (item.value
                        ? const Color(0xFF0D6B57).withOpacity(0.10)
                        : const Color(0xFF2D3340))
                    : (item.value
                        ? const Color(0xFFECFDF5)
                        : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: dark
                      ? (item.value
                          ? const Color(0xFF0D6B57).withOpacity(0.5)
                          : const Color(0xFF374151))
                      : (item.value
                          ? const Color(0xFF0D6B57)
                          : const Color(0xFFD8E0E7)),
                  width: 0.7,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: dark
                            ? (item.value
                                ? const Color(0xFF0D6B57)
                                : Colors.white)
                            : (item.value
                                ? const Color(0xFF0D6B57)
                                : const Color(0xFF111318)),
                        fontSize: MedTypography.auxiliarySize,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.value
                          ? const Color(0xFF0D6B57)
                          : (dark
                              ? const Color(0xFF374151)
                              : const Color(0xFFE2E8F0)),
                      border: item.value || dark
                          ? null
                          : Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 0.7,
                            ),
                    ),
                    child: item.value
                        ? const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white,
                          )
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
    required this.dark,
    required this.surf,
    required this.bord,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.valueRow,
    required this.subColor,
    this.formula,
  });

  // MEDCASES_FERRAMENTAS_RESULTS_CANONICAL_PREMIUM_COMPACT_LAYOUT_V1_B_R0
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: bord, width: 0.7),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: dark ? 0.12 : 0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF1F2937),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  valueRow,
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: TextStyle(
                        color: dark
                            ? const Color(0xFFA8B2C1)
                            : const Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                      ),
                    ),
                  ],
                  if (formula != null && formula!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      formula!,
                      style: TextStyle(
                        fontSize: 10,
                        color: dark
                            ? const Color(0xFF7F8A99)
                            : const Color(0xFF94A3B8),
                        height: 1.25,
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

  // MEDCASES_FERRAMENTAS_RESULTS_CTA_SECONDARY_COMPACT_V1_B_R0
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 42,
        child: DecoratedBox(
          // BUILD 450: fundo petróleo sólido + texto branco
          decoration: BoxDecoration(
            color: _kPetroleo,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
                    fontSize: MedTypography.auxiliarySize,
                    fontWeight: FontWeight.w700,
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
