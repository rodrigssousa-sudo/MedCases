// MEDCASES_PRODUCTIVE_SECOND_BRAND_B1_V2_R1_NEPHRO
// LIGHT_MODE_PREMIUM_V1_A_R14_SECTION_LABELS
// ══════════════════════════════════════════════════════════════════════════════
// nephrology_tools_screen.dart — BUILD 408-NATIVE / BUILD 445-CROSS-CALC-STATE
//
// CENTRAL DE FUNÇÃO RENAL / NEFROLOGÍA — Interface nativa minimalista.
//
// CONFORMIDADE APPLE STORE:
//   • Exibe APENAS resultados numéricos, cálculos matemáticos e estadiamentos.
//   • ZERO condutas terapêuticas, doses ou prescrições nativas.
//   • Toda a conduta clínica final é delegada ao WebView via Deeplink estruturado.
//
// MOTORES MATEMÁTICOS:
//   1. CKD-EPI 2021 (sem fator racial)
//   2. Cockcroft-Gault
//   3. KDIGO LRA (estadiamento)
//   4. FeNa (Fração de Excreção de Sódio)
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
const _kTextSub = Color(0xFFAEB9CC);

// ─────────────────────────────────────────────────────────────────────────────
// NephrologyToolsScreen — ponto de entrada público
// BUILD 445: AutomaticKeepAliveClientMixin → estado visual sobrevive à troca de aba
// ─────────────────────────────────────────────────────────────────────────────
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

class NephrologyToolsScreen extends StatefulWidget {
  const NephrologyToolsScreen({super.key});
  @override
  State<NephrologyToolsScreen> createState() => _NephrologyToolsScreenState();
}

class _NephrologyToolsScreenState extends State<NephrologyToolsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // obrigatório para AutomaticKeepAliveClientMixin
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final dark = p.darkMode;
    return _NephrologyBody(isEs: isEs, dark: dark);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NephrologyBody — StatefulWidget principal
// ─────────────────────────────────────────────────────────────────────────────
class _NephrologyBody extends StatefulWidget {
  final bool isEs;
  final bool dark;
  const _NephrologyBody({required this.isEs, required this.dark});

  @override
  State<_NephrologyBody> createState() => _NephrologyBodyState();
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

class _NephrologyBodyState extends State<_NephrologyBody>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _keyboardFlow = _ToolsKeyboardFlowController();
  // ── BUILD 445: Shared controllers vêm do ToolsStateProvider ──────────────
  // Demográficos e labs compartilhados: ageCtrl, weightCtrl, heightCtrl,
  // crCtrl (creatBase), naCtrl (naSerum) são obtidos via tp.xxxCtrl.
  // Apenas controllers EXCLUSIVOS de nefrologia permanecem locais:
  // Privados: apenas dados exclusivos de cálculos nefrológicos
  final _creatBaseCtrl = TextEditingController(); // Creatinina basal (KDIGO)
  final _naUrineCtrl = TextEditingController(); // Sódio urinário (FeNa)
  final _creatUrineCtrl = TextEditingController(); // Creatinina urinária (FeNa)
  // _naSerumCtrl → BUILD 445: substituído por tp.naCtrl (compartilhado)

  // ── Sexo — BUILD 445: leitura via ToolsStateProvider.isFemale ─────────────
  // _isFemale é acessado via tp.isFemale; mutação via tp.setFemale(v)

  // ── Resultados ─────────────────────────────────────────────────────────────
  _NephroResult? _result;

  // ── Animação fade/slide ─────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Form key ───────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Error message ──────────────────────────────────────────────────────────
  String? _errorMsg;

  // ── BUILD 427: Restore banner state
  bool _showRestoreBanner = false;

  // ── BUILD 426: Patient autofill ──────────────────────────────────────────────
  /// Abre o modal de seleção de paciente e faz autofill dos controllers demográficos.
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

  /// Mapeamento demográfico seguro: idade → _ageCtrl, sexo → _isFemale.
  /// Labs são free-text em internacion → NÃO mapeados (0 crashes garantido).
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    // BUILD 445: controllers compartilhados já estão no ToolsStateProvider —
    // não é preciso verificar cache aqui (feito pelo dialog de retorno da ToolsScreen).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRestoreCache());
  }

  // BUILD 427: verifica se há dados em cache para oferecer restauração
  void _checkRestoreCache() {
    if (!mounted) return;
    final p = context.read<AppProvider>();
    if (p.toolsCacheHasData) {
      setState(() => _showRestoreBanner = true);
    }
  }

  // BUILD 445: restaura campos nefro — compartilhados via ToolsStateProvider,
  // privados (creatBase) restaurados do cache local.
  void _restoreFromCache() {
    final p = context.read<AppProvider>();
    final tp = context.read<ToolsStateProvider>();
    final cache = p.toolsInputCache;
    // Campos compartilhados → ToolsStateProvider
    tp.applyFromCache(cache);
    // Creatinina basal é nefrológica; creatinina sérica atual é tp.crCtrl.
    // Fallback em 'creatinina' migra caches anteriores sem perda de dados.
    final basal =
        cache['creatinina_basal'] ?? cache['creatinina'] ?? '';
    if (basal.isNotEmpty && _creatBaseCtrl.text != basal) {
      _creatBaseCtrl.text = basal;
    }
    setState(() => _showRestoreBanner = false);
  }

  // BUILD 427: descarta cache e fecha banner
  void _discardCache() {
    final p = context.read<AppProvider>();
    p.clearToolsCache();
    setState(() => _showRestoreBanner = false);
  }

  @override
  void didChangeMetrics() {
    _keyboardFlow.handleMetricsChanged();
  }

  @override
  void dispose() {
    // BUILD 445: campos compartilhados pertencem ao ToolsStateProvider — NÃO dispose aqui.
    // Salva snapshot no AppProvider cache para compatibilidade com builds anteriores.
    try {
      final p = context.read<AppProvider>();
      final tp = context.read<ToolsStateProvider>();
      tp.refreshPendingFlag();
      p.saveToolsCache(tp.exportToCache()
        ..['creatinina_basal'] = _creatBaseCtrl.text); // exclusivo nefro
    } catch (_) {}
    _animCtrl.dispose();
    // Apenas controllers PRIVADOS de nefrologia são dispostos aqui:
    _creatBaseCtrl.dispose();
    _naUrineCtrl.dispose();
    // _naSerumCtrl removido — BUILD 445: substituído por tp.naCtrl
    _creatUrineCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _keyboardFlow.dispose();
    super.dispose();
  }

  // ── BUILD 428: Sync labs + scores to Firestore (fire-and-forget) ──────────
  void _syncResultToFirestore(_NephroResult r) {
    try {
      final p = context.read<AppProvider>();
      final uid = p.currentUser?.uid ?? '';
      final patientKey = p.activeImportedPatientKey ?? '';
      if (uid.isEmpty || patientKey.isEmpty) return;

      final tp2 = context.read<ToolsStateProvider>();
      final labData = <String, dynamic>{
        'creatinina': _creatBaseCtrl.text,
        'creatinina_atual': tp2.crCtrl.text,
        'sodio_urina': _naUrineCtrl.text,
        'na_serico': tp2.naCtrl.text,
        'creat_urina': _creatUrineCtrl.text,
        'peso': tp2.weightCtrl.text,
        'edad': tp2.ageCtrl.text,
      };

      final scores = <String, dynamic>{
        'ckdEpi': r.ckdEpi,
        'cockcroft': r.cockcroft,
        'kdigoStage': r.kdigoStage,
        if (r.fena != null) 'fena': r.fena,
      };

      final scoresText =
          'CKD-EPI: ${r.ckdEpi.toStringAsFixed(1)} mL/min/1.73m2, '
          'Cockcroft: ${r.cockcroft.toStringAsFixed(1)} mL/min, '
          'KDIGO: Estagio ${r.kdigoStage}'
          '${r.fena != null ? ", FeNa: ${r.fena!.toStringAsFixed(1)}%" : ""}';

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

  // ── Helper: parse double seguro ─────────────────────────────────────────────
  double? _pd(String v) {
    final s = v.trim().replaceAll(',', '.');
    return double.tryParse(s);
  }

  // ── Calcular ────────────────────────────────────────────────────────────────
  void _calculate() {
    HapticFeedback.lightImpact();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final tp = context.read<ToolsStateProvider>();
    final age = int.tryParse(tp.ageCtrl.text.trim());
    final weight = _pd(tp.weightCtrl.text);
    final creatBase = _pd(_creatBaseCtrl.text);
    final creatCurr = _pd(tp.crCtrl.text);

    // Opcionais para FeNa: Na urina/soro e creat urina são privados de nefro
    final naUrine = _pd(_naUrineCtrl.text);
    final naSerum = _pd(tp.naCtrl.text); // BUILD 445: Na sérico compartilhado
    final creatUrine = _pd(_creatUrineCtrl.text);

    if (age == null ||
        weight == null ||
        creatBase == null ||
        creatCurr == null) {
      setState(() => _errorMsg = widget.isEs
          ? 'Verifica los valores ingresados.'
          : 'Verifique os valores inseridos.');
      return;
    }

    setState(() {
      _errorMsg = null;
      _result = _NephroEngine.compute(
        age: age,
        isFemale: tp.isFemale,
        weight: weight,
        creatBase: creatBase,
        creatCurr: creatCurr,
        naUrine: naUrine,
        naSerum: naSerum,
        creatUrine: creatUrine,
      );
    });

    if (_result != null) _syncResultToFirestore(_result!);

    _animCtrl
      ..reset()
      ..forward();
  }

  // ── Deeplink conduta ────────────────────────────────────────────────────────
  // BUILD 444 [P2+P3]: URL dinâmica Nefrologia → /?modulo=nefrologia.
  // Abre CalculadoraScreen (WebView integrada em tela cheia) no endpoint
  // da especialidade — NUNCA launchUrl externo (Apple compliance).
  void _launchDeeplink() {
    if (_result == null) return;
    HapticFeedback.mediumImpact();
    // BUILD 447-URL-PAYLOAD + BUILD 449-LANG-PAYLOAD: serializa idioma e
    // campos Nefrologia como query params.
    const baseUrl = 'https://medcasescalcu.com/';
    final langCode = widget.isEs ? 'es' : 'pt';
    final queryParams = context
        .read<ToolsStateProvider>()
        .buildQueryStringForSpecialty('nefro', langCode);
    final deeplinkPayload = queryParams.startsWith('?')
        ? queryParams.substring(1)
        : queryParams;
    final conductaUrl =
        '$baseUrl?modulo=nefrologia&$deeplinkPayload';
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CalculadoraScreen(initialUrl: conductaUrl),
      ),
    );
  }

  // ── Validator genérico ──────────────────────────────────────────────────────
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

  String? _validateNonZero(String? v) {
    if (v == null || v.trim().isEmpty) return null; // opcional
    final n = _pd(v);
    if (n == null || n <= 0) {
      return widget.isEs ? 'Valor inválido' : 'Valor inválido';
    }
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final dark = widget.dark;
    final bg = dark ? _kBg : Colors.white; // MEDCASES_TOOLS_COMPACT_WHITE_CONTENT_V1_B_R3_LIGHT_WHITE
    final surf = dark ? _kSurface : Colors.white;
    final txt = dark ? Colors.white : const Color(0xFF0F1116);
    final sub = dark ? _kTextSub : const Color(0xFF64748B);
    final border = dark ? _kBorder : const Color(0xFFCBD5E1);

    final toolsState = context.watch<ToolsStateProvider>();
    _keyboardFlow.configure(
      context,
      <TextEditingController>[
        toolsState.ageCtrl,
        toolsState.weightCtrl,
        toolsState.heightCtrl,
        _creatBaseCtrl,
        toolsState.crCtrl,
        _naUrineCtrl,
        toolsState.naCtrl,
        _creatUrineCtrl,
      ],
    );

    // BUILD 452-3: resizeToAvoidBottomInset=true — o Scaffold cede espaço
    // ao teclado e o CustomScrollView rola naturalmente sem comprimir a viewport.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: bg,
      body: SafeArea(
        child: _ToolsKeyboardFlowScope(
            flow: _keyboardFlow,
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Header ────────────────────────────────────────────────────
                  const SliverToBoxAdapter(child: SizedBox(height: 0)), // MEDCASES_TOOLS_COMPACT_WHITE_CONTENT_V1_B_R3_HEADER_REMOVED

                  // ── BUILD 426: Chip de importação de paciente ─────────────────
                  SliverToBoxAdapter(
                    child: Align(
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
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),

                  // ── BUILD 427: Restore Banner ────────────────────────────────
                  if (_showRestoreBanner)
                    SliverToBoxAdapter(
                      child: ToolsRestoreBanner(
                        isEs: isEs,
                        dark: dark,
                        onRestore: _restoreFromCache,
                        onDiscard: _discardCache,
                      ),
                    ),

                  // ── Inputs ────────────────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(MedSpacing.screenHorizontalPadding, 0, MedSpacing.screenHorizontalPadding, 0),
                    sliver: SliverToBoxAdapter(
                      child: _InputSection(
                        isEs: isEs,
                        dark: dark,
                        surf: surf,
                        txt: txt,
                        sub: sub,
                        border: border,
                        ageCtrl: context.read<ToolsStateProvider>().ageCtrl,
                        weightCtrl:
                            context.read<ToolsStateProvider>().weightCtrl,
                        heightCtrl:
                            context.read<ToolsStateProvider>().heightCtrl,
                        creatBaseCtrl: _creatBaseCtrl,
                        creatCurrCtrl:
                            context.read<ToolsStateProvider>().crCtrl,
                        naUrineCtrl: _naUrineCtrl,
                        naSerumCtrl: context.read<ToolsStateProvider>().naCtrl,
                        creatUrineCtrl: _creatUrineCtrl,
                        isFemale: context.read<ToolsStateProvider>().isFemale,
                        onSexChange: (v) {
                          context.read<ToolsStateProvider>().setFemale(v);
                          setState(() {});
                        },
                        validatePos: _validatePositive,
                        validateNonZ: _validateNonZero,
                      ),
                    ),
                  ),

                  // ── Error ─────────────────────────────────────────────────────
                  if (_errorMsg != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(MedSpacing.screenHorizontalPadding, 8, MedSpacing.screenHorizontalPadding, 0),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(
                            color: _kRed,
                            fontSize: MedTypography.auxiliarySize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // ── Botão Calcular ─────────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(MedSpacing.screenHorizontalPadding, 16, MedSpacing.screenHorizontalPadding, 0),
                    sliver: SliverToBoxAdapter(
                      child: _CalcButton(isEs: isEs, onTap: _calculate),
                    ),
                  ),

                  // ── Resultados animados ────────────────────────────────────────
                  if (_result != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(MedSpacing.screenHorizontalPadding, 20, MedSpacing.screenHorizontalPadding, 0),
                      sliver: SliverToBoxAdapter(
                        child: FadeTransition(
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
                              border: border,
                              onDeeplink: _launchDeeplink,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // BUILD 454-3: AnimatedContainer amortece a transição do teclado em
                  // split view — evita o salto brusco que ocultava o campo ativo.
                  SliverToBoxAdapter(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      height: _toolsMainShellFooterBottomInset(context),
                    ),
                  ),
                ],
              ),
            )),
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

  // TOOLS V1-H-R1: header plano unificado
  // TOOLS V1-H-R1: subtítulo branco

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? _kSurface : Colors.white,
        border: Border(
          bottom: BorderSide(color: dark ? _kBorder : const Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(MedSpacing.screenHorizontalPadding, 14, MedSpacing.screenHorizontalPadding, 14),
      child: Row(
        children: [
          // TOOLS V1-H-R1: ícone sem box secundário
          const Icon(Icons.water_drop_rounded, color: _kPetroleo, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'FUNCIÓN RENAL' : 'FUNÇÃO RENAL',
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
                      ? 'CKD-EPI · Cockcroft-Gault · KDIGO · FeNa'
                      : 'CKD-EPI · Cockcroft-Gault · KDIGO · FeNa',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Section
// ─────────────────────────────────────────────────────────────────────────────
class _InputSection extends StatelessWidget {
  final bool isEs, dark;
  final Color surf, txt, sub, border;
  final TextEditingController ageCtrl, weightCtrl, heightCtrl;
  final TextEditingController creatBaseCtrl, creatCurrCtrl;
  final TextEditingController naUrineCtrl, naSerumCtrl, creatUrineCtrl;
  final bool isFemale;
  final ValueChanged<bool> onSexChange;
  final FormFieldValidator<String> validatePos;
  final FormFieldValidator<String> validateNonZ;

  const _InputSection({
    required this.isEs,
    required this.dark,
    required this.surf,
    required this.txt,
    required this.sub,
    required this.border,
    required this.ageCtrl,
    required this.weightCtrl,
    required this.heightCtrl,
    required this.creatBaseCtrl,
    required this.creatCurrCtrl,
    required this.naUrineCtrl,
    required this.naSerumCtrl,
    required this.creatUrineCtrl,
    required this.isFemale,
    required this.onSexChange,
    required this.validatePos,
    required this.validateNonZ,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // ── Grupo 1: Dados Demográficos ──────────────────────────────────────
        _SectionLabel(isEs ? 'DATOS DEMOGRÁFICOS' : 'DADOS DEMOGRÁFICOS', sub),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark,
          surf: surf,
          border: border,
          child: Column(
            children: [
              // Idade + Sexo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl: ageCtrl,
                      label: isEs ? 'Edad (años)' : 'Idade (anos)',
                      type: TextInputType.number,
                      dark: dark,
                      txt: txt,
                      sub: sub,
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
                    child: _SexToggle(
                      isEs: isEs,
                      dark: dark,
                      txt: txt,
                      sub: sub,
                      isFemale: isFemale,
                      onChange: onSexChange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Peso + Altura
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl: weightCtrl,
                      label: isEs ? 'Peso (kg)' : 'Peso (kg)',
                      type:
                          const TextInputType.numberWithOptions(decimal: true),
                      dark: dark,
                      txt: txt,
                      sub: sub,
                      validator: validatePos,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl: heightCtrl,
                      label: isEs ? 'Altura (cm)' : 'Altura (cm)',
                      type:
                          const TextInputType.numberWithOptions(decimal: true),
                      dark: dark,
                      txt: txt,
                      sub: sub,
                      validator: validateNonZ,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Grupo 2: Creatinina ──────────────────────────────────────────────
        _SectionLabel(
          isEs ? 'CREATININA SÉRICA' : 'CREATININA SÉRICA',
          sub,
        ),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark,
          surf: surf,
          border: border,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FieldBox(
                  ctrl: creatBaseCtrl,
                  label: isEs ? 'Basal (mg/dL)' : 'Basal (mg/dL)',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  dark: dark,
                  txt: txt,
                  sub: sub,
                  validator: validatePos,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FieldBox(
                  ctrl: creatCurrCtrl,
                  label: isEs ? 'Actual (mg/dL)' : 'Atual (mg/dL)',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  dark: dark,
                  txt: txt,
                  sub: sub,
                  validator: validatePos,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Grupo 3: FeNa (opcional) ─────────────────────────────────────────
        _SectionLabel(
          isEs
              ? 'FeNa — OPCIONAL (Sodio + Cr. Urinarios)'
              : 'FeNa — OPCIONAL (Sódio + Cr. Urinários)',
          sub,
        ),
        const SizedBox(height: 8),
        _InputCard(
          dark: dark,
          surf: surf,
          border: border,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldBox(
                      ctrl: naUrineCtrl,
                      label:
                          isEs ? 'Na Urinario (mEq/L)' : 'Na Urinário (mEq/L)',
                      type:
                          const TextInputType.numberWithOptions(decimal: true),
                      dark: dark,
                      txt: txt,
                      sub: sub,
                      validator: validateNonZ,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FieldBox(
                      ctrl: naSerumCtrl,
                      label: isEs ? 'Na Sérico (mEq/L)' : 'Na Sérico (mEq/L)',
                      type:
                          const TextInputType.numberWithOptions(decimal: true),
                      dark: dark,
                      txt: txt,
                      sub: sub,
                      validator: validateNonZ,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _FieldBox(
                ctrl: creatUrineCtrl,
                label: isEs
                    ? 'Creatinina Urinaria (mg/dL)'
                    : 'Creatinina Urinária (mg/dL)',
                type: const TextInputType.numberWithOptions(decimal: true),
                dark: dark,
                txt: txt,
                sub: sub,
                validator: validateNonZ,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
// LIGHT_MODE_PREMIUM_V1_A_R14_NEPHRO_SECTIONLABEL_SECTION
class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    // MEDCASES_FERRAMENTAS_CANONICAL_FLAT_SURFACE_CONVERGENCE_V1_B_R0_SECTION
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: dark
              ? const Color(0xFFA8B2C1)
              : const Color(0xFF334155),
          fontSize: 12.5,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.75,
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Input Card container
// ─────────────────────────────────────────────────────────────────────────────
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
  Widget build(BuildContext context) {
    // MEDCASES_FERRAMENTAS_CANONICAL_FLAT_SURFACE_CONVERGENCE_V1_B_R0_SECTION_BODY
    final divider = dark
        ? const Color(0xFF374151)
        : const Color(0xFFD8E0E7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 11),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: divider, width: 0.7),
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text field box
// ─────────────────────────────────────────────────────────────────────────────
// LIGHT_MODE_PREMIUM_V1_A_R14_NEPHRO_FIELDBOX
class _FieldBox extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
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
    this.validator,
  });

  IconData get _fieldIcon {
    final normalized = label.toLowerCase();
    if (normalized.contains('edad') || normalized.contains('idade')) {
      return Icons.person_outline;
    }
    if (normalized.contains('peso')) {
      return Icons.monitor_weight_outlined;
    }
    if (normalized.contains('altura')) {
      return Icons.straighten_outlined;
    }
    if (normalized.contains('urin')) {
      return Icons.science_outlined;
    }
    return Icons.water_drop_outlined;
  }

  @override
  Widget build(BuildContext context) {
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
                      keyboardType: type,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      validator: validator,
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
  final bool isEs, dark, isFemale;
  final Color txt, sub;
  final ValueChanged<bool> onChange;

  const _SexToggle({
    required this.isEs,
    required this.dark,
    required this.isFemale,
    required this.txt,
    required this.sub,
    required this.onChange,
  });

  // TOOLS V1-H-R1: seletor sexual unificado
  // UI V1-J-R2: contrato canônico da Cardiologia com helper preservado
  // UI V1-J-R5: altura idêntica ao input e alinhamento geométrico

  @override
  Widget build(BuildContext context) {
    assert(<Object?>[dark, txt, sub].isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18.5),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2D3340),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF374151)),
          ),
          child: Row(
            children: [
              _SexOption(
                label: 'Masculino',
                active: !isFemale,
                left: true,
                onTap: () => onChange(false),
              ),
              _SexOption(
                label: isEs ? 'Femenino' : 'Feminino',
                active: isFemale,
                left: false,
                onTap: () => onChange(true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SexOption extends StatelessWidget {
  final String label;
  final bool active, left;
  final VoidCallback onTap;

  const _SexOption({
    required this.label,
    required this.active,
    required this.left,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        left ? const Color(0xFF3B82F6) : const Color(0xFFEC4899);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? activeColor : const Color(0xFF2D3340),
            borderRadius: BorderRadius.horizontal(
              left: left ? const Radius.circular(9) : Radius.zero,
              right: left ? Radius.zero : const Radius.circular(9),
            ),
          ),
          child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontSize: MedTypography.auxiliarySize,
              fontWeight: FontWeight.w600,
            ),
          ),
                  ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botão Calcular
// ─────────────────────────────────────────────────────────────────────────────
class _CalcButton extends StatelessWidget {
  final bool isEs;
  final VoidCallback onTap;
  const _CalcButton({required this.isEs, required this.onTap});

  @override
  Widget build(
          BuildContext
              context) => // TOOLS V1-G-R1-R3: calcular delicado padronizado
      Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.72,
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                // BUILD 450: petróleo + branco
                backgroundColor: const Color(0xFF0D6B57),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                isEs ? 'CALCULAR' : 'CALCULAR',
                style: const TextStyle(
                  fontSize: MedTypography.auxiliarySize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Results Section
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsSection extends StatelessWidget {
  final _NephroResult result;
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
        const SizedBox(height: 6),

        // CKD-EPI
        _ResultCard(
          dark: dark, surf: surf, border: border,
          icon: Icons.science_rounded,
          // BUILD 450: CrCl/eGFR result icon petróleo
          iconColor: _kPetroleo,
          title: 'CKD-EPI 2021',
          valueRow: Row(
            children: [
              Text(
                '${result.ckdEpi.toStringAsFixed(1)} mL/min/1.73m²',
                style: TextStyle(
                  color: txt,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _GfRBadge(gfr: result.ckdEpi, isEs: isEs),
            ],
          ),
          sub: isEs
              ? _ckdStageLabel(result.ckdEpi, es: true)
              : _ckdStageLabel(result.ckdEpi, es: false),
          subColor: _ckdColor(result.ckdEpi),
          formula: isEs
              ? 'Ecuación CKD-EPI (2021): TFG basada em Creatinina Sérica sin factor de raza.'
              : 'Equação CKD-EPI (2021): TFG baseada em Creatinina Sérica sem fator de raça.',
        ),

        const SizedBox(height: 6),

        // Cockcroft-Gault
        _ResultCard(
          dark: dark,
          surf: surf,
          border: border,
          icon: Icons.medication_liquid_rounded,
          iconColor: _kGreen,
          title: 'Cockcroft-Gault',
          valueRow: Text(
            '${result.cockcroft.toStringAsFixed(1)} mL/min',
            style: TextStyle(
              color: txt,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          sub: isEs
              ? 'Utilizar para ajuste de dosis de prospecto'
              : 'Utilize para ajuste de dose de bula',
          subColor: sub,
          formula: isEs
              ? 'Fórmula: CLcr = ((140 − Edad) × Peso) / (72 × CrS) [× 0.85 si Femenino]'
              : 'Fórmula: CLcr = ((140 − Idade) × Peso) / (72 × CrS) [× 0.85 se Feminino]',
        ),

        const SizedBox(height: 6),

        // KDIGO LRA
        _ResultCard(
          dark: dark,
          surf: surf,
          border: border,
          icon: Icons.warning_amber_rounded,
          iconColor: _kdigoColor(result.kdigoStage),
          title: isEs ? 'KDIGO — LRA' : 'KDIGO — LRA',
          valueRow: Text(
            result.kdigoStage == 0
                ? (isEs ? 'Ausente' : 'Ausente')
                : 'Estágio ${result.kdigoStage}',
            style: TextStyle(
              color: _kdigoColor(result.kdigoStage),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          sub: isEs
              ? _kdigoSubEs(result.kdigoStage)
              : _kdigoSubPt(result.kdigoStage),
          subColor: _kdigoColor(result.kdigoStage).withOpacity(0.85),
          formula:
              'Fórmula: Proporção = CrAtual / CrBasal  |  Δ = CrAtual − CrBasal',
        ),

        const SizedBox(height: 6),

        // FeNa
        if (result.fena != null)
          _ResultCard(
            dark: dark,
            surf: surf,
            border: border,
            icon: Icons.water_rounded,
            iconColor: _kAmber,
            title: 'FeNa',
            valueRow: Row(
              children: [
                Text(
                  '${result.fena!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: txt,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isEs
                      ? _fenaLabelEs(result.fena!)
                      : _fenaLabelPt(result.fena!),
                  style: const TextStyle(
                    color: _kAmber,
                    fontSize: MedTypography.auxiliarySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            sub: isEs
                ? 'Fracción de Excreción de Sodio'
                : 'Fração de Excreção de Sódio',
            subColor: sub,
            formula: 'Fórmula: FeNa = ((NaU × CrS) / (NaS × CrU)) × 100',
          ),

        if (result.fena == null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.water_rounded,
                    color: _kAmber.withOpacity(0.4), size: 18),
                const SizedBox(width: 10),
                Text(
                  isEs
                      ? 'FeNa: campos opcionales vacíos'
                      : 'FeNa: campos opcionais não preenchidos',
                  style: TextStyle(color: sub, fontSize: MedTypography.auxiliarySize),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // ── Deeplink Conduta ───────────────────────────────────────────────
        _DeeplinkButton(isEs: isEs, onTap: onDeeplink),

        const SizedBox(height: 8),

        // Disclaimer Apple-compliant
        Text(
          isEs
              ? '⚕ Los resultados son de uso clínico exclusivo. La conducta terapéutica se abre en el módulo especializado.'
              : '⚕ Resultados de uso clínico exclusivo. A conduta terapêutica é aberta no módulo especializado.',
          style: TextStyle(color: sub, fontSize: MedTypography.microTextSize, height: 1.4),
        ),
      ],
    );
  }

  Color _kdigoColor(int stage) {
    switch (stage) {
      case 1:
        return _kAmber;
      case 2:
        return const Color(0xFFf97316); // orange
      case 3:
        return _kRed;
      default:
        return _kGreen;
    }
  }

  String _kdigoSubEs(int stage) {
    switch (stage) {
      case 0:
        return 'Sin criterios de LRA (KDIGO 2012)';
      case 1:
        return 'Δ Cr ≥ 0.3 mg/dL en 48h ó proporción 1.5–1.9×';
      case 2:
        return 'Proporción creatinina 2.0–2.9× basal';
      case 3:
        return 'Proporción ≥ 3.0× ó Cr ≥ 4.0 mg/dL con Δ ≥ 0.5';
      default:
        return '';
    }
  }

  String _kdigoSubPt(int stage) {
    switch (stage) {
      case 0:
        return 'Sem critérios de LRA (KDIGO 2012)';
      case 1:
        return 'Δ Cr ≥ 0,3 mg/dL em 48h ou proporção 1,5–1,9×';
      case 2:
        return 'Proporção creatinina 2,0–2,9× basal';
      case 3:
        return 'Proporção ≥ 3,0× ou Cr ≥ 4,0 mg/dL com Δ ≥ 0,5';
      default:
        return '';
    }
  }

  Color _ckdColor(double gfr) {
    if (gfr >= 90) return _kGreen;
    if (gfr >= 60) return _kGreen;
    if (gfr >= 45) return _kAmber;
    if (gfr >= 30) return const Color(0xFFf97316);
    if (gfr >= 15) return _kRed;
    return const Color(0xFF7C3AED);
  }

  String _ckdStageLabel(double gfr, {required bool es}) {
    if (es) {
      if (gfr >= 90) return 'G1 — Función normal o alta';
      if (gfr >= 60) return 'G2 — Levemente disminuida';
      if (gfr >= 45) return 'G3a — Leve a moderada';
      if (gfr >= 30) return 'G3b — Moderada a grave';
      if (gfr >= 15) return 'G4 — Gravemente disminuida';
      return 'G5 — Falla renal';
    } else {
      if (gfr >= 90) return 'G1 — Função normal ou aumentada';
      if (gfr >= 60) return 'G2 — Levemente diminuída';
      if (gfr >= 45) return 'G3a — Leve a moderada';
      if (gfr >= 30) return 'G3b — Moderada a grave';
      if (gfr >= 15) return 'G4 — Gravemente diminuída';
      return 'G5 — Falência renal';
    }
  }

  String _fenaLabelEs(double fena) {
    if (fena < 1.0) return '(Etiología Prerrenal)';
    if (fena > 2.0) return '(Etiología Renal/NTA)';
    return '(Zona de transición)';
  }

  String _fenaLabelPt(double fena) {
    if (fena < 1.0) return '(Etiologia Pré-Renal)';
    if (fena > 2.0) return '(Etiologia Renal/NTA)';
    return '(Zona de transição)';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result Card
// ─────────────────────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final bool dark;
  final Color surf, border, iconColor, subColor;
  final IconData icon;
  final String title, sub;
  final Widget valueRow;
  final String? formula; // BUILD 409-COMPLIANCE: rodapé científico discreto

  const _ResultCard({
    required this.dark,
    required this.surf,
    required this.border,
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
          border: Border.all(color: border, width: 0.7),
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

// ─────────────────────────────────────────────────────────────────────────────
// GFR Badge (G1–G5)
// ─────────────────────────────────────────────────────────────────────────────
class _GfRBadge extends StatelessWidget {
  final double gfr;
  final bool isEs;
  const _GfRBadge({required this.gfr, required this.isEs});

  String get _stage {
    if (gfr >= 90) return 'G1';
    if (gfr >= 60) return 'G2';
    if (gfr >= 45) return 'G3a';
    if (gfr >= 30) return 'G3b';
    if (gfr >= 15) return 'G4';
    return 'G5';
  }

  Color get _color {
    if (gfr >= 90) return _kGreen;
    if (gfr >= 60) return _kGreen;
    if (gfr >= 45) return _kAmber;
    if (gfr >= 30) return const Color(0xFFf97316);
    if (gfr >= 15) return _kRed;
    return const Color(0xFF7C3AED);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Text(
          _stage,
          style: TextStyle(
            color: _color,
            fontSize: MedTypography.microTextSize,
            fontWeight: FontWeight.w700,
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

  // MEDCASES_FERRAMENTAS_RESULTS_CTA_SECONDARY_COMPACT_V1_B_R0
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 42,
        child: DecoratedBox(
          // BUILD 450: fundo petróleo sólido + texto branco (substitui gradiente neon)
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

// ─────────────────────────────────────────────────────────────────────────────
// _NephroResult — resultado tipado imutável
// ─────────────────────────────────────────────────────────────────────────────
class _NephroResult {
  final double ckdEpi;
  final double cockcroft;
  final int kdigoStage;
  final double? fena;

  const _NephroResult({
    required this.ckdEpi,
    required this.cockcroft,
    required this.kdigoStage,
    this.fena,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _NephroEngine — motores matemáticos puros e sem efeitos colaterais
// ─────────────────────────────────────────────────────────────────────────────
class _NephroEngine {
  _NephroEngine._();

  // ── CKD-EPI 2021 (sem fator racial) ─────────────────────────────────────
  static double _ckdEpi({
    required int age,
    required bool isFemale,
    required double creatCurr,
  }) {
    double kappa, alpha, sexFactor;

    if (isFemale) {
      kappa = 0.7;
      alpha = -0.241;
      sexFactor = 1.012;
    } else {
      kappa = 0.9;
      alpha = -0.302;
      sexFactor = 1.0;
    }

    final ratio = creatCurr / kappa;
    final double power = creatCurr <= kappa ? alpha : -1.200;
    final gfr = 142.0 *
        math.pow(ratio, power) *
        math.pow(0.9938, age.toDouble()) *
        sexFactor;

    return _round1(gfr);
  }

  // ── Cockcroft-Gault ───────────────────────────────────────────────────────
  static double _cockcroftGault({
    required int age,
    required bool isFemale,
    required double weight,
    required double creatCurr,
  }) {
    double cl = ((140.0 - age) * weight) / (72.0 * creatCurr);
    if (isFemale) cl *= 0.85;
    return _round1(cl);
  }

  // ── KDIGO LRA ─────────────────────────────────────────────────────────────
  static int _kdigo({
    required double creatBase,
    required double creatCurr,
  }) {
    final delta = creatCurr - creatBase;
    final proportion = creatCurr / creatBase;

    // Estágio 3
    if (proportion >= 3.0) return 3;
    if (creatCurr >= 4.0 && delta >= 0.5) return 3;

    // Estágio 2
    if (proportion >= 2.0) return 2;

    // Estágio 1
    if (delta >= 0.3) return 1;
    if (proportion >= 1.5) return 1;

    return 0; // Ausente
  }

  // ── FeNa ──────────────────────────────────────────────────────────────────
  // Retorna null se qualquer parâmetro for inválido (divisão por zero segura).
  static double? _fena({
    required double? naUrine,
    required double? naSerum,
    required double? creatUrine,
    required double creatCurr,
  }) {
    if (naUrine == null || naSerum == null || creatUrine == null) return null;
    if (naSerum <= 0 || creatUrine <= 0) return null;

    final fena = (naUrine * creatCurr) / (naSerum * creatUrine) * 100.0;
    return _round1(fena);
  }

  // ── Arredondamento para 1 casa decimal ───────────────────────────────────
  static double _round1(double v) => (v * 10).round() / 10;

  // ── Fachada pública ───────────────────────────────────────────────────────
  static _NephroResult compute({
    required int age,
    required bool isFemale,
    required double weight,
    required double creatBase,
    required double creatCurr,
    double? naUrine,
    double? naSerum,
    double? creatUrine,
  }) {
    return _NephroResult(
      ckdEpi: _ckdEpi(
        age: age,
        isFemale: isFemale,
        creatCurr: creatCurr,
      ),
      cockcroft: _cockcroftGault(
        age: age,
        isFemale: isFemale,
        weight: weight,
        creatCurr: creatCurr,
      ),
      kdigoStage: _kdigo(
        creatBase: creatBase,
        creatCurr: creatCurr,
      ),
      fena: _fena(
        naUrine: naUrine,
        naSerum: naSerum,
        creatUrine: creatUrine,
        creatCurr: creatCurr,
      ),
    );
  }
}
