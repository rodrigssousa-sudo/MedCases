// MEDCASES_PRODUCTIVE_SECOND_BRAND_B1_V2_R1_ELECTRO
// LIGHT_MODE_PREMIUM_V1_A_R14_SECTION_LABELS
// ══════════════════════════════════════════════════════════════════════════════
// electrolytes_tools_screen.dart — BUILD 445-CROSS-CALC-STATE — BUILD 415-UX-HARMONY
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
// Paleta canônica MedCases Pro (dark-first)
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
const _kBlue = Color(0xFF3B82F6);
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

class ElectrolytesToolsScreen extends StatefulWidget {
  const ElectrolytesToolsScreen({super.key});
  @override
  State<ElectrolytesToolsScreen> createState() =>
      _ElectrolytesToolsScreenState();
}

class _ElectrolytesToolsScreenState extends State<ElectrolytesToolsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
  final bool hasHighAG;

  const _ElectroResult({
    required this.gasInterp,
    required this.ph,
    required this.pco2,
    required this.hco3,
    required this.be,
    required this.anionGap,
    required this.corrNa,
    required this.corrCa,
    required this.osmolarity,
    required this.bicarbonateDef,
    required this.na,
    required this.cl,
    required this.gluc,
    required this.ca,
    required this.albumin,
    required this.bun,
    required this.weight,
    required this.hasHighAG,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure math engines
// ─────────────────────────────────────────────────────────────────────────────
class _ElectroEngine {
  // Gasometria — interpretação ácido-base completa
  static String _gasInterp({
    required double ph,
    required double pco2,
    required double hco3,
    required double be,
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

    if (be < -3) {
      comp +=
          '${comp.isNotEmpty ? " | " : ""}BE: déficit de base (${be.toStringAsFixed(1)})';
    }
    if (be > 3) {
      comp +=
          '${comp.isNotEmpty ? " | " : ""}BE: ↑ excesso de base (${be.toStringAsFixed(1)})';
    }

    return '$primary${comp.isNotEmpty ? "\n$comp" : ""}';
  }

  static _ElectroResult compute({
    required double na,
    required double cl,
    required double hco3,
    required double gluc,
    required double ca,
    required double albumin,
    required double bun,
    required double weight,
    required double ph,
    required double pco2,
    required double be,
  }) {
    final ag = na - (cl + hco3);
    final cNa = na + 1.6 * ((gluc - 100) / 100);
    final cCa = ca + 0.8 * (4.0 - albumin);
    final osm = 2 * na + gluc / 18 + bun / 2.8;
    final biDef = (weight * 0.3 * (24 - hco3)).clamp(0.0, 9999.0);
    final interp = _gasInterp(ph: ph, pco2: pco2, hco3: hco3, be: be);

    return _ElectroResult(
      gasInterp: interp,
      ph: ph,
      pco2: pco2,
      hco3: hco3,
      be: be,
      anionGap: ag,
      corrNa: cNa,
      corrCa: cCa,
      osmolarity: osm,
      bicarbonateDef: biDef,
      na: na,
      cl: cl,
      gluc: gluc,
      ca: ca,
      albumin: albumin,
      bun: bun,
      weight: weight,
      hasHighAG: ag > 12,
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

class _ElectroBodyState extends State<_ElectroBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _keyboardFlow = _ToolsKeyboardFlowController();
  // BUILD 445: controllers compartilhados vêm do ToolsStateProvider:
  //   naCtrl, hco3Ctrl, albCtrl (albumCtrl), weightCtrl, phCtrl, pco2Ctrl, beCtrl,
  //   clCtrl, glucCtrl, caCtrl, bunCtrl.
  // Todos são acessados via context.read<ToolsStateProvider>().xxxCtrl.

  // ── State ─────────────────────────────────────────────────────────────────
  _ElectroResult? _result;
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

  // BUILD 445: restaura campos eletrolíticos — todos compartilhados via ToolsStateProvider
  void _restoreFromCache() {
    final p = context.read<AppProvider>();
    final tp = context.read<ToolsStateProvider>();
    tp.applyFromCache(p.toolsInputCache);
    setState(() => _showRestoreBanner = false);
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
      tp.refreshPendingFlag();
      p.saveToolsCache(tp.exportToCache());
    } catch (_) {}
    _animCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _keyboardFlow.dispose();
    super.dispose();
  }

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

  /// Autofill: peso (weight) mapeado de AppProvider.patient.weight se disponível,
  /// já que PacienteInternacaoData não tem campo de peso estruturado.
  /// Para Electrolitos: _weightCtrl ← AppProvider.patient.weight (single patient)
  void _autofillFromSession(PacienteSession session) {
    try {
      final paciente = session.paciente;
      final age = parseAgeFromString(paciente.idade);
      final sexo = paciente.sexo.trim().toUpperCase();
      final bool? female = sexo.isEmpty ? null : sexo == 'F';
      context.read<ToolsStateProvider>().applyFromPatient(
            age: age,
            female: female,
          );
      if (mounted) setState(() {});
    } catch (_) {
      // Falha silenciosa — nunca quebra a UI clínica.
    }
  }

  // ── BUILD 428: Sync labs + scores to Firestore (fire-and-forget) ──────────
  void _syncResultToFirestore(_ElectroResult r) {
    try {
      final p = context.read<AppProvider>();
      final uid = p.currentUser?.uid ?? '';
      final patientKey = p.activeImportedPatientKey ?? '';
      if (uid.isEmpty || patientKey.isEmpty) return;

      final labData = <String, dynamic>{
        'sodio': context.read<ToolsStateProvider>().naCtrl.text,
        'cloro': context.read<ToolsStateProvider>().clCtrl.text,
        'hco3': context.read<ToolsStateProvider>().hco3Ctrl.text,
        'glicose': context.read<ToolsStateProvider>().glucCtrl.text,
        'calcio': context.read<ToolsStateProvider>().caCtrl.text,
        'albumina': context.read<ToolsStateProvider>().albCtrl.text,
        'bun': context.read<ToolsStateProvider>().bunCtrl.text,
        'peso': context.read<ToolsStateProvider>().weightCtrl.text,
      };

      final scores = <String, dynamic>{
        'anionGap': r.anionGap,
        'sodioCorrigido': r.corrNa,
        'calcioCorrigido': r.corrCa,
        'osmolaridade': r.osmolarity,
        'deficitHco3': r.bicarbonateDef,
      };

      final gasLine = r.gasInterp.replaceAll('\n', ' | ');
      final scoresText = 'Anion Gap: ${r.anionGap.toStringAsFixed(1)}, '
          'Gasometria: $gasLine, '
          'Na corrigido: ${r.corrNa.toStringAsFixed(1)} mEq/L, '
          'Ca corrigido: ${r.corrCa.toStringAsFixed(2)} mg/dL, '
          'Osmolaridade: ${r.osmolarity.toStringAsFixed(0)} mOsm/L, '
          'Deficit HCO3: ${r.bicarbonateDef.toStringAsFixed(1)} mEq';

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
        na: _pdOr(context.read<ToolsStateProvider>().naCtrl, 140),
        cl: _pdOr(context.read<ToolsStateProvider>().clCtrl, 104),
        hco3: _pdOr(context.read<ToolsStateProvider>().hco3Ctrl, 24),
        gluc: _pdOr(context.read<ToolsStateProvider>().glucCtrl, 100),
        ca: _pdOr(context.read<ToolsStateProvider>().caCtrl, 9.5),
        albumin: _pdOr(context.read<ToolsStateProvider>().albCtrl, 4.0),
        bun: _pdOr(context.read<ToolsStateProvider>().bunCtrl, 14),
        weight: _pdOr(context.read<ToolsStateProvider>().weightCtrl, 70),
        ph: _pdOr(context.read<ToolsStateProvider>().phCtrl, 7.40),
        pco2: _pdOr(context.read<ToolsStateProvider>().pco2Ctrl, 40),
        be: _pdOr(context.read<ToolsStateProvider>().beCtrl, 0),
      );
    });
    if (_result != null) _syncResultToFirestore(_result!);

    _animCtrl.forward(from: 0);
  }

  // BUILD 429-APPLE-COMPLIANCE: sync — abre CalculadoraScreen interna.
  // BUILD 444 [P2+P3]: URL dinâmica Eletrólitos → /?modulo=eletrolitos.
  // Abre CalculadoraScreen (WebView integrada em tela cheia) no endpoint
  // da especialidade — NUNCA launchUrl externo (Apple compliance).
  void _launchDeeplink() {
    if (_result == null) return;
    HapticFeedback.mediumImpact();
    // BUILD 447-URL-PAYLOAD + BUILD 449-LANG-PAYLOAD: serializa idioma e
    // campos Eletrólitos/Gasometria como query params.
    const baseUrl = 'https://medcasescalcu.com/';
    final langCode = widget.isEs ? 'es' : 'pt';
    final queryParams = context
        .read<ToolsStateProvider>()
        .buildQueryStringForSpecialty('eletrolitos', langCode);
    final deeplinkPayload = queryParams.startsWith('?')
        ? queryParams.substring(1)
        : queryParams;
    final conductaUrl =
        '$baseUrl?modulo=eletrolitos&$deeplinkPayload';
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
        toolsState.phCtrl,
        toolsState.pco2Ctrl,
        toolsState.hco3Ctrl,
        toolsState.beCtrl,
        toolsState.naCtrl,
        toolsState.clCtrl,
        toolsState.glucCtrl,
        toolsState.caCtrl,
        toolsState.albCtrl,
        toolsState.bunCtrl,
        toolsState.weightCtrl,
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
                  const SizedBox(height: 22),

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
                    surf: surf,
                    bord: bord,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _NField(
                                label: 'pH',
                                ctrl: context.read<ToolsStateProvider>().phCtrl,
                                hint: '7,40',
                                validator: _validateRequired,
                                refRange: '7,35–7,45',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _NField(
                                label: 'pCO₂ (mmHg)',
                                ctrl:
                                    context.read<ToolsStateProvider>().pco2Ctrl,
                                hint: '40',
                                validator: _validateRequired,
                                refRange: '35–45',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _NField(
                                label: 'HCO₃⁻ (mEq/L)',
                                ctrl:
                                    context.read<ToolsStateProvider>().hco3Ctrl,
                                hint: '24',
                                validator: _validateRequired,
                                refRange: '22–26',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _NField(
                                label: 'BE (mEq/L)',
                                ctrl: context.read<ToolsStateProvider>().beCtrl,
                                hint: '0',
                                validator: _validateRequired,
                                refRange: '−2 a +2',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Bloco 2: ELETRÓLITOS SÉRICOS ───────────────────────────────
                  _InputCard(
                    title:
                        isEs ? 'ELECTROLITOS SÉRICOS' : 'ELETRÓLITOS SÉRICOS',
                    surf: surf,
                    bord: bord,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _NField(
                                label: 'Na⁺ (mEq/L)',
                                ctrl: context.read<ToolsStateProvider>().naCtrl,
                                hint: '140',
                                validator: _validateRequired,
                                refRange: '136–145',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _NField(
                                label: 'Cl⁻ (mEq/L)',
                                ctrl: context.read<ToolsStateProvider>().clCtrl,
                                hint: '104',
                                validator: _validateRequired,
                                refRange: '98–106',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _NField(
                                label: isEs
                                    ? 'Glucosa (mg/dL)'
                                    : 'Glicose (mg/dL)',
                                ctrl:
                                    context.read<ToolsStateProvider>().glucCtrl,
                                hint: '100',
                                validator: _validateRequired,
                                refRange: '70–100',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _NField(
                                label: 'Ca²⁺ total (mg/dL)',
                                ctrl: context.read<ToolsStateProvider>().caCtrl,
                                hint: '9,5',
                                validator: _validateRequired,
                                refRange: '8,5–10,5',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _NField(
                                label: isEs
                                    ? 'Albúmina (g/dL)'
                                    : 'Albumina (g/dL)',
                                ctrl:
                                    context.read<ToolsStateProvider>().albCtrl,
                                hint: '4,0',
                                validator: _validateRequired,
                                refRange: '3,5–5,0',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _NField(
                                label:
                                    isEs ? 'BUN (mg/dL)' : 'BUN/Ureia (mg/dL)',
                                ctrl:
                                    context.read<ToolsStateProvider>().bunCtrl,
                                hint: '14',
                                validator: _validateRequired,
                                refRange: '7–20',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Peso — para déficit HCO₃
                        _NField(
                          label: isEs
                              ? 'Peso corporal (kg)'
                              : 'Peso corporal (kg)',
                          ctrl: context.read<ToolsStateProvider>().weightCtrl,
                          hint: '70',
                          validator: _validateRequired,
                          refRange: '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

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
class _ElectroHeader extends StatelessWidget {
  final bool isEs;
  final Color surf, bord, txt, sub;
  const _ElectroHeader({
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
                        const Icon(Icons.science_rounded,
                            color: _kPetroleo, size: 20),
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
                                  fontSize: MedTypography.internalTitleSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEs
                                    ? 'Déficit HCO₃ · Gasometría · Brecha Aniónica · Na/Ca Corregido'
                                    : 'Déficit HCO₃ · Gasometria · Brecha Aniônica · Na/Ca Corrigido',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: MedTypography.auxiliarySize) /* MEDCASES_TOOLS_V1_H_R9_CANONICAL_HEADER_STYLE */,
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
// Results Section
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsSection extends StatelessWidget {
  final _ElectroResult result;
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

  Color _phColor(double ph) {
    if (ph >= 7.35 && ph <= 7.45) return _kGreen;
    if ((ph >= 7.30 && ph < 7.35) || (ph > 7.45 && ph <= 7.50)) return _kAmber;
    return _kRed;
  }

  Color _agColor(double ag) {
    if (ag < 8) return _kBlue;
    if (ag <= 12) return _kGreen;
    if (ag <= 20) return _kAmber;
    return _kRed;
  }

  String _agLabel(double ag, {required bool es}) {
    if (ag < 8) return es ? '↓ Bajo (<8)' : '↓ Baixo (<8)';
    if (ag <= 12) return es ? '✓ Normal (8–12)' : '✓ Normal (8–12)';
    if (ag <= 20) return es ? '⚠ Elevado (12–20)' : '⚠ Elevado (12–20)';
    return es
        ? '⬆ Muy elevado — acidosis AG alto'
        : '⬆ Muito elevado — acidose AG alto';
  }

  Color _caColor(double ca) {
    if (ca < 8.5) return _kBlue;
    if (ca > 10.5) return _kRed;
    return _kGreen;
  }

  String _caLabel(double ca, {required bool es}) {
    if (ca < 8.5) return es ? 'Hipocalcemia' : 'Hipocalcemia';
    if (ca > 10.5) return es ? 'Hipercalcemia' : 'Hipercalcemia';
    return es ? 'Normal (8,5–10,5)' : 'Normal (8,5–10,5)';
  }

  Color _osmColor(double o) {
    if (o < 280) return _kBlue;
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
            color: sub,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.75,
          ),
        ),
        const SizedBox(height: 6),

        // 1. Gasometria — interpretação
        _ResultCard(
          dark: dark,
          surf: surf,
          bord: bord,
          icon: Icons.air_rounded,
          iconColor: _phColor(r.ph),
          title: isEs ? 'GASOMETRÍA ARTERIAL' : 'GASOMETRIA ARTERIAL',
          valueRow: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MiniPill(
                      label: 'pH',
                      value: r.ph.toStringAsFixed(2),
                      color: _phColor(r.ph)),
                  const SizedBox(width: 6),
                  _MiniPill(
                      label: 'pCO₂',
                      value: '${r.pco2.toStringAsFixed(0)} mmHg',
                      color: _kTextSub),
                  const SizedBox(width: 6),
                  _MiniPill(
                      label: 'HCO₃',
                      value: '${r.hco3.toStringAsFixed(1)} mEq',
                      color: _kTextSub),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                r.gasInterp,
                style: TextStyle(
                  color: _phColor(r.ph),
                  fontSize: MedTypography.clinicalBodySize,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
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
        const SizedBox(height: 6),

        // 2. Déficit de HCO₃⁻
        _ResultCard(
          dark: dark,
          surf: surf,
          bord: bord,
          icon: Icons.calculate_rounded,
          iconColor: _kAmber,
          title: isEs ? 'DÉFICIT DE HCO₃⁻' : 'DÉFICIT DE HCO₃⁻',
          valueRow: Text(
            '${r.bicarbonateDef.toStringAsFixed(0)} mEq',
            style: TextStyle(
              color: txt,
              fontSize: 22,
              fontWeight: FontWeight.w700,
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
        const SizedBox(height: 6),

        // 3. Gap / Brecha Aniônica + Osmolaridade
        _ResultCard(
          dark: dark,
          surf: surf,
          bord: bord,
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
                          color: txt,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
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
                        style: const TextStyle(color: _kTextSub, fontSize: MedTypography.auxiliarySize),
                      ),
                      Text(
                        '${r.osmolarity.toStringAsFixed(0)} mOsm/kg',
                        style: TextStyle(
                          color: _osmColor(r.osmolarity),
                          fontSize: MedTypography.auxiliarySize,
                          fontWeight: FontWeight.w700,
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
        const SizedBox(height: 6),

        // 4. Na⁺ Corrigido + Ca²⁺ Corrigido
        _ResultCard(
          dark: dark,
          surf: surf,
          bord: bord,
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
                  color: _caColor(r.corrCa),
                  fontSize: MedTypography.auxiliarySize,
                  fontWeight: FontWeight.w600,
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

        const SizedBox(height: 12),

        // ── Deeplink button ────────────────────────────────────────────────
        _DeeplinkButton(isEs: isEs, onTap: onDeeplink),
        const SizedBox(height: 8),

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

// LIGHT_MODE_PREMIUM_V1_A_R14_ELECTRO_INPUTCARD_SECTION
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


/// Campo numérico com label + faixa de referência no hint
// LIGHT_MODE_PREMIUM_V1_A_R14_ELECTRO_NFIELD
class _NField extends StatelessWidget {
  final String label, hint, refRange;
  final TextEditingController ctrl;
  final FormFieldValidator<String> validator;

  const _NField({
    required this.label,
    required this.ctrl,
    required this.hint,
    required this.validator,
    this.refRange = '',
  });

  IconData get _fieldIcon {
    final normalized = label.toLowerCase();
    if (normalized.contains('peso')) {
      return Icons.monitor_weight_outlined;
    }
    if (normalized.contains('gluc')) {
      return Icons.water_drop_outlined;
    }
    if (normalized.contains('na') ||
        normalized.contains('cl') ||
        normalized.contains('ca') ||
        normalized.contains('album') ||
        normalized.contains('bun')) {
      return Icons.water_drop_outlined;
    }
    return Icons.science_outlined;
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
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: secondary,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ),
            if (refRange.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                refRange,
                maxLines: 1,
                style: TextStyle(
                  color: secondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
            ],
          ],
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

class _MiniPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniPill(
      {required this.label, required this.value, required this.color});

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
                style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: MedTypography.microTextSize,
                    fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: value,
                style: TextStyle(
                    color: color, fontSize: MedTypography.microTextSize, fontWeight: FontWeight.w800),
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
    if (ag < 8) return _kBlue;
    if (ag <= 12) return _kGreen;
    if (ag <= 20) return _kAmber;
    return _kRed;
  }

  String get _label {
    if (ag < 8) return 'Baixo';
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
            color: _color,
            fontSize: MedTypography.microTextSize,
            fontWeight: FontWeight.w700,
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
