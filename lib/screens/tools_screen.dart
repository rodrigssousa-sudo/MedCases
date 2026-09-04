// MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_2C_V2_B_R1_R1_LINE_SCOPED_ALLOWLIST
// MEDCASES_PRODUCTIVE_SECOND_BRAND_BATCH_2A_V2_B_R1_GENERIC_OWNER_PATCH
import 'dart:ui' show ImageFilter;

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/medcases_webview_screen.dart'; // BUILD 323 — MANDATO 2: in-app WebView
import 'reference_screens.dart'; // Fix#7: Dashboard Grid de Referências (mantido para uso interno)
import 'hepatology_tools_screen.dart'
    show HepatologyToolsScreen; // BUILD 420-HEPATOLOGY
import '../providers/app_provider.dart';
import '../providers/tools_state_provider.dart'; // BUILD 445
import '../data/evidence_database.dart';
import '../data/pediatrics/pediatric_growth_engine_v2026.dart';
import '../data/pediatrics/pediatric_pews_engine_v2026.dart';
import '../data/pediatrics/pediatric_reference_registry_v2026.dart';
import '../data/pediatrics/pediatric_renal_engine_v2026.dart';
import '../widgets/common_widgets.dart';
import '../widgets/lab_exam_bottom_sheet.dart';
import '../services/activity_service.dart';
import '../design_system/foundation/med_typography.dart';
import '../main.dart' show MainShell; // SUPER ORDEM 313: pendingTab fallback
// BUILD 408-NATIVE: substitui _BiometricsTab por NephrologyToolsScreen na tab 0.
import 'nephrology_tools_screen.dart' show NephrologyToolsScreen;
// BUILD 415-UX-HARMONY: substitui CardioHubView e _ElectrolytesTab por telas unificadas.
import 'cardio_tools_screen.dart' show CardioToolsScreen;
import 'electrolytes_tools_screen.dart' show ElectrolytesToolsScreen;

// ──────────────────────────────────────────────────────────────────
// COLOR CONSTANTS — alinhadas com common_widgets.dart
// ──────────────────────────────────────────────────────────────────
// kDark, kGold, kGoldLight, kGreen, kBorder importados de common_widgets
const kToolGreen = Color(0xFF0E8000); // verde padrão do app (mesmo kGreen)
const kToolBorder = Color(0xFFE2E6EA); // mesmo kBorder
// kToolDark removido — usar AppColors.of(context).textPrimary / .darkBtn
const kToolGold = kGoldLight; // alias para kGoldLight

// ──────────────────────────────────────────────────────────────────
// NAVEGAÇÃO EXTERNA → TAB ESPECÍFICA
// ValueNotifier global: permite que HomeScreen (ou qualquer lugar)
// instrua o ToolsScreen a mudar para uma aba específica sem precisar
// passar parâmetros pelo widget tree (ToolsScreen é const no IndexedStack).
// Uso: toolsScreenTabNotifier.value = <índice da aba>;
// ──────────────────────────────────────────────────────────────────
final ValueNotifier<int?> toolsScreenTabNotifier = ValueNotifier<int?>(null);

// BUILD 445: Notifier que MainShell usa para avisar quando a tela de Ferramentas
// fica visível (true) ou oculta (false) no IndexedStack.
// Permite que ToolsScreen exiba o dialog de retorno ao reentrar na seção.
final ValueNotifier<bool> toolsScreenVisibleNotifier =
    ValueNotifier<bool>(false);

class ToolsScreen extends StatefulWidget {
  final bool hideHeader;
  const ToolsScreen({super.key, this.hideHeader = false});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // BUILD 445 — PASSO 3: controle do dialog de retorno
  bool _returnDialogPending = false; // evita exibir dialog duas vezes
  bool _wasEverVisible = false; // distingue primeira exibição de retorno

  @override
  void initState() {
    super.initState();
    // BUILD 93 — INFUSÃO (idx 4) e SIMULAÇÕES (idx 6) ocultas → 6 tabs visíveis
    // BUILD 277-CROMATICO — 5 tabs: BIOMETRIA, CARDIO, ELETRÓLITOS, REFERÊNCIAS, PEDIATRIA (SCORES removed)
    // SUPER ORDEM VISUAL 10 — 4 tabs: PEDIATRIA extinta (classe mantida para home_screen.dart)
    _tabCtrl = TabController(length: 4, vsync: this);
    // Ouve o notifier externo para mudar de aba
    toolsScreenTabNotifier.addListener(_onExternalTabRequest);
    // BUILD 445: ouve visibilidade para exibir dialog de retorno
    toolsScreenVisibleNotifier.addListener(_onVisibilityChanged);
  }

  void _onExternalTabRequest() {
    final idx = toolsScreenTabNotifier.value;
    if (idx == null) return;
    // Usa addPostFrameCallback para garantir que o widget já está montado
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tabCtrl.animateTo(
          idx.clamp(0, 3)); // SUPER ORDEM VISUAL 10: 4 tabs visíveis (0-3)
      // Reseta para null após consumir
      toolsScreenTabNotifier.value = null;
    });
  }

  // BUILD 445 — PASSO 3: chamado quando MainShell muda visibilidade desta tela
  void _onVisibilityChanged() {
    final visible = toolsScreenVisibleNotifier.value;
    if (visible && _wasEverVisible && !_returnDialogPending) {
      // Usuário retornou à seção de Ferramentas
      _returnDialogPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeShowReturnDialog();
      });
    }
    if (visible) _wasEverVisible = true;
  }

  // BUILD 445 — PASSO 3: verifica dados pendentes e exibe dialog elegante
  Future<void> _maybeShowReturnDialog() async {
    _returnDialogPending = false;
    if (!mounted) return;
    final tp = context.read<ToolsStateProvider>();
    tp.refreshPendingFlag();
    if (!tp.hasPendingData) return; // nenhum dado — não incomoda o médico

    final p = context.read<AppProvider>();
    final isEs = p.lang == 'es';
    final dark = p.darkMode;

    await _showReturnDataDialog(
      context: context,
      isEs: isEs,
      dark: dark,
      tp: tp,
    );
  }

  @override
  void dispose() {
    toolsScreenTabNotifier.removeListener(_onExternalTabRequest);
    toolsScreenVisibleNotifier.removeListener(_onVisibilityChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    // SUPER ORDEM: header sempre visível (mobile + desktop) quando não suprimido.
    // Peça única solidária Dark Graphite com título + pílulas embutidas.
    final showHeader = !widget.hideHeader;

    final dark = p.darkMode;
    final pageBg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final double topPad =
        View.of(context).padding.top / View.of(context).devicePixelRatio;

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TOPBAR BLEED — Stack com Positioned negativo.
    //
    // CONTEXTO: MainShell._buildMobileShell() aplica para as abas 3/4/5:
    //   Padding(top: statusBarHeight) antes do IndexedStack.
    // Isso desloca TODA a tela para baixo por statusBarHeight — a topbar
    // começa ABAIXO da status bar, deixando uma falha no topo.
    //
    // SOLUÇÃO SEM TOCAR EM main.dart:
    // Usar Stack com Positioned(top: -topPad) para subir o Container
    // da topbar para atrás da status bar física. O topPad é lido via
    // View.of(context) — imune ao MediaQuery.removePadding do MainShell.
    //
    // ESTRUTURA:
    //   Stack(clipBehavior: Clip.none)
    //     ├── Column (SizedBox compensatório + TabRow + conteúdo)
    //     └── Positioned(top: -topPad, height: topPad+56)
    //           └── Container(cor/gradiente)
    //                 └── SafeArea(bottom:false) → posiciona conteúdo abaixo notch
    //                       └── SizedBox(56) + Stack(botão + título)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    if (!showHeader) {
      return Column(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // BUILD 408-NATIVE: Biometria → Função Renal / Nefrología
                const NephrologyToolsScreen(),
                // BUILD 415-UX-HARMONY: Cardio unificado
                const CardioToolsScreen(),
                // BUILD 415-UX-HARMONY: Eletrólitos unificado
                const ElectrolytesToolsScreen(),
                const HepatologyToolsScreen(), // BUILD 420-HEPATOLOGY
              ],
            ),
          ),
        ),
      ]);
    }

    // MEDCASES_HERRAMIENTAS_TOPBAR_UNIFIED_OWNER_CUTOVER_V1_B_R5_R1
    // Tab 4 não recebe mais padding.top do MainShell.
    // Esta tela agora é dona do inset físico superior:
    // 1) UMA única _ToolsTopbarBg cobre status area + 48 px;
    // 2) conteúdo interativo começa exatamente após topPad;
    // 3) tabs começam exatamente após topPad + 48;
    // 4) não existe segunda superfície ou bleed negativo em runtime.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: ColoredBox(
        color: pageBg,
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: topPad + 48),
                _ToolsTabRow(dark: dark, isEs: isEs, tabCtrl: _tabCtrl),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // BUILD 408-NATIVE: Biometria → Função Renal / Nefrología
                      const NephrologyToolsScreen(),
                      // BUILD 415-UX-HARMONY: Cardio unificado
                      const CardioToolsScreen(),
                      // BUILD 415-UX-HARMONY: Eletrólitos unificado
                      const ElectrolytesToolsScreen(),
                      const HepatologyToolsScreen(), // BUILD 420-HEPATOLOGY
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topPad + 48,
              child: const _ToolsTopbarBg(),
            ),
            Positioned(
              top: topPad,
              left: 0,
              right: 0,
              height: 48,
              child: _ToolsTopbarContent(dark: dark, isEs: isEs),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 331 — TOPBAR FERRAMENTAS
// Identidade visual: Black Piano #111622 sólido — mesmo tom da AI ActionBar.
// Geometria estrita: SafeArea(bottom:false) + SizedBox(48).
// Stack sem Padding wrapper — botão em Positioned(left:12), título em Align(center).
// Borda inferior #2D3340 0.5px + BoxShadow blur:6 — acabamento premium.
// ─────────────────────────────────────────────────────────────────────────────
// ── Fundo da topbar (sem conteúdo, apenas visual) ────────────────────────────
class _ToolsTopbarBg extends StatelessWidget {
  const _ToolsTopbarBg();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = dark
        ? const Color(0xFF252930).withOpacity(0.70)
        : Colors.white.withOpacity(0.70);
    final borderColor =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    // MEDCASES_HERRAMIENTAS_HOME_TOPBAR_V1_B_R1
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 14,
          sigmaY: 14,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Conteúdo interativo da topbar (botão voltar + título) ─────────────────────
class _ToolsTopbarContent extends StatelessWidget {
  final bool dark;
  final bool isEs;
  const _ToolsTopbarContent({required this.dark, required this.isEs});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── BOTÃO ESQUERDO ────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  MainShell.pendingTab.value = 0;
                }
              },
              child: SizedBox(
                width: 36,
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: /* MEDCASES_TOOLS_BACK_LEFT_V1_B_R0 */
                        Theme.of(context).brightness == Brightness.dark
                            ? (Colors.white)
                            : (const Color(0xFF05070A)),
                  ),
                ),
              ),
            ),
          ),
          // ── TÍTULO — centro geométrico absoluto ──────────────────────────
          Text(
            isEs ? 'HERRAMIENTAS' : 'FERRAMENTAS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: /* MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R16_R5_R13 */
                  Theme.of(context).brightness == Brightness.dark
                      ? (Colors.white)
                      : (const Color(0xFF05070A)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 331 — SELETOR QUÁDRUPLO FERRAMENTAS (BIOMETRIA|CARDIO|ELETRÓLITOS|REFERÊNCIAS)
// Desacoplado da topbar — sobre fundo nativo sólido do corpo.
// Cores adaptativas: dark → branco/branco60; light → preto/preto45.
// ─────────────────────────────────────────────────────────────────────────────
class _ToolsTabRow extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final TabController tabCtrl;

  const _ToolsTabRow({
    required this.dark,
    required this.isEs,
    required this.tabCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final surface = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE7EBEF);

    final labels = isEs
        ? const ['Nefrología', 'Cardio', 'Electrolitos', 'Hepatología']
        : const ['Nefrologia', 'Cardio', 'Eletrólitos', 'Hepatologia'];

    const icons = <IconData>[
      Icons.water_drop_outlined,
      Icons.favorite_border,
      Icons.science_outlined,
      Icons.local_hospital_outlined,
    ];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: divider, width: 0.7),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: _ToolsFlatTab(
                label: labels[i],
                icon: icons[i],
                index: i,
                tabCtrl: tabCtrl,
                dark: dark,
              ),
            ),
            if (i < labels.length - 1)
              SizedBox(
                width: 0.7,
                height: 40,
                child: Center(
                  child: Container(
                    width: 0.7,
                    height: 20,
                    color: divider,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ToolsFlatTab extends StatefulWidget {
  final String label;
  final IconData icon;
  final int index;
  final TabController tabCtrl;
  final bool dark;

  const _ToolsFlatTab({
    required this.label,
    required this.icon,
    required this.index,
    required this.tabCtrl,
    this.dark = true,
  });

  @override
  State<_ToolsFlatTab> createState() => _ToolsFlatTabState();
}

class _ToolsFlatTabState extends State<_ToolsFlatTab> {
  @override
  void initState() {
    super.initState();
    widget.tabCtrl.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.tabCtrl.removeListener(_onTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.tabCtrl.index == widget.index;

    final inactiveColor =
        widget.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final activeColor =
        widget.dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);
    final activeBackground = widget.dark
        ? const Color(0xFF0D6B57).withValues(alpha: 0.10)
        : const Color(0xFF0D6B57).withValues(alpha: 0.06);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.tabCtrl.animateTo(widget.index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? activeBackground : Colors.transparent,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                widget.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: isActive ? activeColor : inactiveColor,
                  letterSpacing: 0.05,
                ),
              ),
            ),
            if (isActive)
              Positioned(
                left: 12,
                right: 12,
                bottom: 9,
                child: Container(
                  height: 2,
                  color: const Color(0xFF0D6B57),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BiometricsTab extends StatefulWidget {
  @override
  State<_BiometricsTab> createState() => _BiometricsTabState();
}

class _BiometricsTabState extends State<_BiometricsTab> {
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _crCtrl = TextEditingController();
  bool _sexFem = false;

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    _ageCtrl.dispose();
    _crCtrl.dispose();
    super.dispose();
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.'));
  String _fmt(double? v) {
    if (v == null || !v.isFinite) return '—';
    if (v.abs() >= 1000) return v.round().toString();
    if (v.abs() >= 100) return v.toStringAsFixed(0);
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
    final ratio = cr / kappa;
    double gfr = 142 *
        _pow(ratio < 1 ? ratio : 1, alpha) *
        _pow(ratio > 1 ? ratio : 1, -1.200) *
        _pow(0.9938, a);
    if (_sexFem) gfr *= 1.012;
    return _fmt(gfr);
  }

  String _bmiLabel(double? v) {
    if (v == null) return '';
    if (v < 16) return 'ATENÇÃO: Desnutrição grave (<16)';
    if (v < 18.5) return '↓ Abaixo do peso';
    if (v < 25) return '✓ Peso normal';
    if (v < 30) return '↑ Sobrepeso';
    if (v < 35) return '↑↑ Obesidade I';
    if (v < 40) return '↑↑↑ Obesidade II';
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
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Peso (kg)' : 'Peso (kg)',
                      ctrl: _wCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '78')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Talla (cm)' : 'Altura (cm)',
                      ctrl: _hCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '171')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Edad (años)' : 'Idade (anos)',
                      ctrl: _ageCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '60')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Creatinina (mg/dL)' : 'Creatinina (mg/dL)',
                      ctrl: _crCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '1,0')),
            ]),
            const SizedBox(height: 10),
            _CanonicalSexToggle(
              isEs: isEs,
              isFemale: _sexFem,
              onChanged: (value) => setState(() => _sexFem = value),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _ResultTile(
                      label: 'IMC',
                      value: _fmt(_bmiVal),
                      unit: 'kg/m²',
                      note: _bmiLabel(_bmiVal))),
              const SizedBox(width: 8),
              Expanded(
                  child: _ResultTile(
                      label: isEs ? 'Peso Ideal' : 'Peso Ideal',
                      value: _idealWeight,
                      unit: 'kg')),
            ]),
            const SizedBox(height: 8),
            _ResultTile(
                label:
                    isEs ? 'Peso Ajustado (obesos)' : 'Peso Ajustado (obesos)',
                value: _adjustedWeight,
                unit: 'kg',
                full: true,
                note: isEs
                    ? 'Usar en obesos (IMC>30) para dosis de fármacos'
                    : 'Usar em obesos (IMC>30) para dose de fármacos'),
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: isEs ? 'Función Renal' : 'Função Renal',
          icon: Icons.water_rounded,
          child: Column(children: [
            _ResultTile(
                label:
                    isEs ? 'ClCr — Cockcroft-Gault' : 'ClCr — Cockcroft-Gault',
                value: _clcr,
                unit: 'mL/min',
                note: _clcrLabel(_clcr),
                full: true),
            const SizedBox(height: 8),
            _ResultTile(
                label: isEs ? 'TFG — CKD-EPI 2021' : 'TFG — CKD-EPI 2021',
                value: _ckdEpi,
                unit: 'mL/min/1,73m²',
                note: _clcrLabel(_ckdEpi),
                full: true),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
                    ? 'Cockcroft-Gault: usar para ajuste de fármacos. CKD-EPI: estadificación de ERC (KDIGO).'
                    : 'Cockcroft-Gault: usar para ajuste de fármacos. CKD-EPI: estadiamento de DRC (KDIGO).'),
            const SizedBox(height: 8),
            _RenalGuideRow(
                label: '≥ 90',
                status: isEs ? 'G1 — Función normal' : 'G1 — Função normal',
                ok: true),
            _RenalGuideRow(
                label: '60–89',
                status: isEs ? 'G2 — Leve. Vigilar' : 'G2 — Leve. Monitorar'),
            _RenalGuideRow(
                label: '30–59',
                status: isEs
                    ? 'G3 — Moderada. Ajuste frecuente'
                    : 'G3 — Moderada. Ajuste frequente',
                warn: true),
            _RenalGuideRow(
                label: '15–29',
                status: isEs
                    ? 'G4 — Grave. Ajuste obligatorio'
                    : 'G4 — Grave. Ajuste obrigatório',
                warn: true),
            _RenalGuideRow(
                label: '<15',
                status: isEs
                    ? 'G5 — Falla. Dosis muy reducida'
                    : 'G5 — Falência. Dose muito reduzida',
                danger: true),
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

class _CanonicalSexToggle extends StatelessWidget {
  final bool isEs;
  final bool isFemale;
  final ValueChanged<bool> onChanged;

  const _CanonicalSexToggle({
    required this.isEs,
    required this.isFemale,
    required this.onChanged,
  });

  // UI V1-J-R1: contrato canônico copiado da Cardiologia
  // UI V1-J-R3: sem subtítulo redundante; alinhado ao campo adjacente

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF2D3340),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF374151)),
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
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF2D3340),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(9),
                      ),
                    ),
                    child: Text(
                      'Masculino',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: !isFemale ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                          ? const Color(0xFFEC4899)
                          : const Color(0xFF2D3340),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(9),
                      ),
                    ),
                    child: Text(
                      isEs ? 'Femenino' : 'Feminino',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isFemale ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

class _ScoresTabState extends State<_ScoresTab> {
  // ── Glasgow ──────────────────────────────────────────
  int _glasEye = 4;
  int _glasVerbal = 5;
  int _glasMotor = 6;

  // ── SOFA ────────────────────────────────────────────
  int _sofaResp = 0; // PaO2/FiO2
  int _sofaCoag = 0; // Platelets
  int _sofaLiver = 0; // Bilirubin
  int _sofaCardio = 0; // MAP / vasopressors
  int _sofaNeuro = 0; // GCS
  int _sofaRenal = 0; // Creatinine / urine

  // ── CHA2DS2-VASc ────────────────────────────────────
  bool _cha_ic = false;
  bool _cha_has = false;
  bool _cha_age75 = false;
  bool _cha_dm = false;
  bool _cha_stroke = false;
  bool _cha_vasc = false;
  bool _cha_age65_74 = false;
  bool _cha_female = false;

  // ── Wells TVP ───────────────────────────────────────
  bool _wt_active_cancer = false;
  bool _wt_paralysis = false;
  bool _wt_recent_immob = false;
  bool _wt_localized_tender = false;
  bool _wt_entire_leg_swol = false;
  bool _wt_calf_swol3cm = false;
  bool _wt_pitting_edema = false;
  bool _wt_collateral_veins = false;
  bool _wt_previous_dvt = false;
  bool _wt_alt_dx_likely = false;

  // ── Wells TEP ───────────────────────────────────────
  bool _wp_dvt_signs = false;
  bool _wp_no_alt_dx = false;
  bool _wp_hr100 = false;
  bool _wp_immob = false;
  bool _wp_prev_dvt = false;
  bool _wp_hemoptysis = false;
  bool _wp_malignancy = false;

  // ── CURB-65 ─────────────────────────────────────────
  bool _curb_confusion = false;
  bool _curb_ureia = false;
  bool _curb_rr = false;
  bool _curb_bp = false;
  bool _curb_age65 = false;

  // ── NEWS2 ────────────────────────────────────────────
  int _news_rr = 0; // 0–3
  int _news_spo2 = 0; // 0–3
  // _news_spo2b reservado para escala B DPOC
  bool _news_supo2 = false; // O2 suplementar
  int _news_sbp = 0; // 0–3
  int _news_hr = 0; // 0–3
  int _news_neuro = 0; // 0–3 (AVPU)
  int _news_temp = 0; // 0–3

  // ── Child-Pugh ──────────────────────────────────────
  int _cp_bili = 1; // 1–3
  int _cp_alb = 1; // 1–3
  int _cp_pt = 1; // 1–3 (INR)
  int _cp_ascite = 1; // 1–3
  int _cp_encef = 1; // 1–3

  // ── PSI/PORT ────────────────────────────────────────
  // Demographics
  bool _psi_nursing = false; // nursing home
  bool _psi_neoplasm = false;
  bool _psi_liver = false;
  bool _psi_chf = false;
  bool _psi_cva = false;
  bool _psi_renal = false;
  // Exam
  bool _psi_alt_ms = false;
  bool _psi_rr30 = false;
  bool _psi_sbp90 = false;
  bool _psi_temp = false; // <35 or ≥40
  bool _psi_hr125 = false;
  // Labs/x-ray
  bool _psi_ph735 = false;
  bool _psi_bun30 = false;
  bool _psi_na130 = false;
  bool _psi_gluc250 = false;
  bool _psi_hct30 = false;
  bool _psi_po2_60 = false;
  bool _psi_eff = false; // pleural effusion
  final _psiAgeCtrl = TextEditingController();

  @override
  void dispose() {
    _psiAgeCtrl.dispose();
    super.dispose();
  }

  int get _glasGCS => _glasEye + _glasVerbal + _glasMotor;
  int get _sofaTotal =>
      _sofaResp +
      _sofaCoag +
      _sofaLiver +
      _sofaCardio +
      _sofaNeuro +
      _sofaRenal;

  int get _chaScore {
    int s = 0;
    if (_cha_ic) s += 1;
    if (_cha_has) s += 1;
    if (_cha_age75) s += 2;
    if (_cha_dm) s += 1;
    if (_cha_stroke) s += 2;
    if (_cha_vasc) s += 1;
    if (_cha_age65_74) s += 1;
    if (_cha_female) s += 1;
    return s;
  }

  double get _wtScore {
    double s = 0;
    if (_wt_active_cancer) s += 1;
    if (_wt_paralysis) s += 1;
    if (_wt_recent_immob) s += 1;
    if (_wt_localized_tender) s += 1;
    if (_wt_entire_leg_swol) s += 1;
    if (_wt_calf_swol3cm) s += 1;
    if (_wt_pitting_edema) s += 1;
    if (_wt_collateral_veins) s += 1;
    if (_wt_previous_dvt) s += 1;
    if (_wt_alt_dx_likely) s -= 2;
    return s;
  }

  double get _wpScore {
    double s = 0;
    if (_wp_dvt_signs) s += 3;
    if (_wp_no_alt_dx) s += 3;
    if (_wp_hr100) s += 1.5;
    if (_wp_immob) s += 1.5;
    if (_wp_prev_dvt) s += 1.5;
    if (_wp_hemoptysis) s += 1;
    if (_wp_malignancy) s += 1;
    return s;
  }

  String _glasLabel(int g) {
    if (g >= 14) return '✓ Leve (14–15)';
    if (g >= 9) return '⚠ Moderado (9–13)';
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
    if (_curb_ureia) s++;
    if (_curb_rr) s++;
    if (_curb_bp) s++;
    if (_curb_age65) s++;
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
  int get _newsTotal =>
      _news_rr +
      _news_spo2 +
      (_news_supo2 ? 2 : 0) +
      _news_sbp +
      _news_hr +
      _news_neuro +
      _news_temp;
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
    if (_psi_nursing) s += 10;
    if (_psi_neoplasm) s += 30;
    if (_psi_liver) s += 20;
    if (_psi_chf) s += 10;
    if (_psi_cva) s += 10;
    if (_psi_renal) s += 10;
    if (_psi_alt_ms) s += 20;
    if (_psi_rr30) s += 20;
    if (_psi_sbp90) s += 20;
    if (_psi_temp) s += 15;
    if (_psi_hr125) s += 10;
    if (_psi_ph735) s += 30;
    if (_psi_bun30) s += 20;
    if (_psi_na130) s += 20;
    if (_psi_gluc250) s += 10;
    if (_psi_hct30) s += 10;
    if (_psi_po2_60) s += 10;
    if (_psi_eff) s += 10;
    return s;
  }

  String _psiClass(int s) {
    if (s <= 50) return 'Classe I–II (≤50) — ambulatorial (mort. <1%)';
    if (s <= 70) return 'Classe III (51–70) — ambulatorial curto (mort. ~2%)';
    if (s <= 90) return 'Classe IV (71–90) — internação (mort. ~8%)';
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
    if (s < 2) return '✓ TEP improvável (<2)';
    if (s <= 6) return '⚠ TEP moderado (2–6)';
    return 'TEP PROVÁVEL (>6)';
  }

  Widget _scoreRow(String label, bool value, VoidCallback onTap,
          {double points = 1}) =>
      GestureDetector(
        onTap: () {
          AppHaptics.selection(context);
          onTap();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: value ? const Color(0xFFECFDF5) : const Color(0xFFF8F8F8),
            border: Border.all(
                color: value ? const Color(0xFFBBF7D0) : kToolBorder),
          ),
          child: Row(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? kToolGreen : Colors.white,
                  border: Border.all(
                      color: value ? kToolGreen : const Color(0xFFA8B2C1),
                      width: 2)),
              child: value
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: value
                            ? AppColors.of(context).textPrimary
                            : AppColors.of(context).textSecondary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: value
                      ? kToolGreen.withOpacity(0.15)
                      : AppColors.of(context).surface),
              child: Text(
                  points == points.roundToDouble()
                      ? '+${points.toInt()}'
                      : '${points > 0 ? "+" : ""}$points',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color:
                          value ? kToolGreen : AppColors.of(context).textHint)),
            ),
          ]),
        ),
      );

  Widget _glasRow(String label, int value, int max, VoidCallback onDec,
          VoidCallback onInc) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.of(context).textPrimary))),
          IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 22,
              color: kToolGreen,
              onPressed: value > 1 ? onDec : null),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text('$value',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.of(context).textPrimary)),
          ),
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 22,
              color: kToolGreen,
              onPressed: value < max ? onInc : null),
          SizedBox(
              width: 30,
              child: Text('/$max',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.of(context).textHint))),
        ]),
      );

  Widget _sofaDropRow(String label, int value, List<String> options,
          ValueChanged<int?> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.of(context).textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: kToolBorder)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isDense: true,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.of(context).textPrimary),
                onChanged: onChanged,
                items: List.generate(options.length,
                    (i) => DropdownMenuItem(value: i, child: Text(options[i]))),
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
          badgeColor: _glasGCS >= 14
              ? kToolGreen
              : _glasGCS >= 9
                  ? const Color(0xFFB45309)
                  : const Color(0xFFCC2222),
          child: Column(children: [
            _glasRow(
                isEs ? 'Abertura Ocular (O)' : 'Abertura Ocular (O)',
                _glasEye,
                4,
                () => setState(() => _glasEye--),
                () => setState(() => _glasEye++)),
            _glasRow(
                isEs ? 'Respuesta Verbal (V)' : 'Resposta Verbal (V)',
                _glasVerbal,
                5,
                () => setState(() => _glasVerbal--),
                () => setState(() => _glasVerbal++)),
            _glasRow(
                isEs ? 'Respuesta Motora (M)' : 'Resposta Motora (M)',
                _glasMotor,
                6,
                () => setState(() => _glasMotor--),
                () => setState(() => _glasMotor++)),
            const Divider(),
            _ResultTile(
                label: 'GCS Total',
                value: '$_glasGCS',
                unit: '/15',
                note: _glasLabel(_glasGCS),
                full: true),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
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
          badgeColor: _sofaTotal <= 6
              ? kToolGreen
              : _sofaTotal <= 9
                  ? const Color(0xFFB45309)
                  : const Color(0xFFCC2222),
          child: Column(children: [
            _sofaDropRow(
                isEs ? 'Respiratorio (PaO2/FiO2)' : 'Respiratório (PaO2/FiO2)',
                _sofaResp,
                isEs
                    ? [
                        '≥400 (0)',
                        '<400 (1)',
                        '<300 (2)',
                        '<200+VPP (3)',
                        '<100+VPP (4)'
                      ]
                    : [
                        '≥400 (0)',
                        '<400 (1)',
                        '<300 (2)',
                        '<200+VPP (3)',
                        '<100+VPP (4)'
                      ],
                (v) => setState(() => _sofaResp = v ?? 0)),
            _sofaDropRow(
                isEs ? 'Coagulación (Plaquetas)' : 'Coagulação (Plaquetas)',
                _sofaCoag,
                ['≥150k (0)', '<150k (1)', '<100k (2)', '<50k (3)', '<20k (4)'],
                (v) => setState(() => _sofaCoag = v ?? 0)),
            _sofaDropRow(
                isEs ? 'Hepático (Bilirrubina)' : 'Hepático (Bilirrubina)',
                _sofaLiver,
                [
                  '<1,2 (0)',
                  '1,2–1,9 (1)',
                  '2,0–5,9 (2)',
                  '6,0–11,9 (3)',
                  '≥12,0 (4)'
                ],
                (v) => setState(() => _sofaLiver = v ?? 0)),
            _sofaDropRow(
                isEs
                    ? 'Cardiovascular (PAM/Vaso)'
                    : 'Cardiovascular (PAM/Vaso)',
                _sofaCardio,
                isEs
                    ? [
                        'PAM≥70(0)',
                        'PAM<70(1)',
                        'Dopa≤5(2)',
                        'Dopa>5/NA≤0,1(3)',
                        'Dopa>15/NA>0,1(4)'
                      ]
                    : [
                        'PAM≥70(0)',
                        'PAM<70(1)',
                        'Dopa≤5(2)',
                        'Dopa>5/NA≤0,1(3)',
                        'Dopa>15/NA>0,1(4)'
                      ],
                (v) => setState(() => _sofaCardio = v ?? 0)),
            _sofaDropRow(
                isEs ? 'Neurológico (GCS)' : 'Neurológico (GCS)',
                _sofaNeuro,
                ['15 (0)', '13–14 (1)', '10–12 (2)', '6–9 (3)', '<6 (4)'],
                (v) => setState(() => _sofaNeuro = v ?? 0)),
            _sofaDropRow(
                isEs
                    ? 'Renal (Creatinina/Diuresis)'
                    : 'Renal (Creatinina/Diurese)',
                _sofaRenal,
                [
                  '<1,2 (0)',
                  '1,2–1,9 (1)',
                  '2,0–3,4 (2)',
                  '3,5–4,9/<500mL(3)',
                  '>5/>200mL(4)'
                ],
                (v) => setState(() => _sofaRenal = v ?? 0)),
            const Divider(),
            _ResultTile(
                label: 'SOFA Total',
                value: '$_sofaTotal',
                unit: '/24',
                note: _sofaLabel(_sofaTotal),
                full: true),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
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
          badgeColor: _chaScore == 0
              ? kToolGreen
              : _chaScore == 1
                  ? const Color(0xFFB45309)
                  : const Color(0xFFCC2222),
          child: Column(children: [
            _scoreRow(isEs ? 'IC / FE reduzida (C)' : 'IC / FE reduzida (C)',
                _cha_ic, () => setState(() => _cha_ic = !_cha_ic)),
            _scoreRow(isEs ? 'Hipertensión (H)' : 'Hipertensão (H)', _cha_has,
                () => setState(() => _cha_has = !_cha_has)),
            _scoreRow(isEs ? 'Edad ≥75 años (A₂)' : 'Idade ≥75 anos (A₂)',
                _cha_age75, () => setState(() => _cha_age75 = !_cha_age75),
                points: 2),
            _scoreRow(isEs ? 'Diabetes mellitus (D)' : 'Diabetes mellitus (D)',
                _cha_dm, () => setState(() => _cha_dm = !_cha_dm)),
            _scoreRow(
                isEs
                    ? 'AVC/AIT/Tromboembolismo (S₂)'
                    : 'AVC/AIT/Tromboembolismo (S₂)',
                _cha_stroke,
                () => setState(() => _cha_stroke = !_cha_stroke),
                points: 2),
            _scoreRow(isEs ? 'Enfermedad Vascular (V)' : 'Doença Vascular (V)',
                _cha_vasc, () => setState(() => _cha_vasc = !_cha_vasc)),
            _scoreRow(
                isEs ? 'Edad 65–74 años (A)' : 'Idade 65–74 anos (A)',
                _cha_age65_74,
                () => setState(() => _cha_age65_74 = !_cha_age65_74)),
            _scoreRow(isEs ? 'Sexo femenino (Sc)' : 'Sexo feminino (Sc)',
                _cha_female, () => setState(() => _cha_female = !_cha_female)),
            const Divider(),
            Row(children: [
              Expanded(
                  child: _ResultTile(
                      label: isEs ? 'Puntuación' : 'Pontuação',
                      value: '$_chaScore',
                      unit: '/9')),
              const SizedBox(width: 8),
              Expanded(
                  child: _ResultTile(
                      label: isEs ? 'AVC/año' : 'AVC/ano',
                      value: _chaStroke(_chaScore),
                      unit: '')),
            ]),
            const SizedBox(height: 8),
            _InfoNote(text: _chaRisk(_chaScore)),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Wells TVP ─────────────────────────────────────────────────
        _SectionCard(
          title: isEs
              ? 'Wells — TVP (Trombosis Venosa)'
              : 'Wells — TVP (Trombose Venosa)',
          icon: Icons.airline_seat_flat_angled_rounded,
          badge: _wtScore.toStringAsFixed(0),
          badgeColor: _wtScore <= 0
              ? kToolGreen
              : _wtScore <= 2
                  ? const Color(0xFFB45309)
                  : const Color(0xFFCC2222),
          child: Column(children: [
            _scoreRow(
                isEs ? 'Cáncer activo (trat. <6m)' : 'Câncer ativo (trat. <6m)',
                _wt_active_cancer,
                () => setState(() => _wt_active_cancer = !_wt_active_cancer)),
            _scoreRow(
                isEs ? 'Parálisis/paresia MMII' : 'Paralisia/paresia MMII',
                _wt_paralysis,
                () => setState(() => _wt_paralysis = !_wt_paralysis)),
            _scoreRow(
                isEs
                    ? 'Inmovilización >3 días / cirugía <12 semanas'
                    : 'Imobilização >3 dias / cirurgia <12 semanas',
                _wt_recent_immob,
                () => setState(() => _wt_recent_immob = !_wt_recent_immob)),
            _scoreRow(
                isEs ? 'Dolor a la palpación venosa' : 'Dor à palpação venosa',
                _wt_localized_tender,
                () => setState(
                    () => _wt_localized_tender = !_wt_localized_tender)),
            _scoreRow(
                isEs ? 'Edema de toda la pierna' : 'Edema de toda a perna',
                _wt_entire_leg_swol,
                () =>
                    setState(() => _wt_entire_leg_swol = !_wt_entire_leg_swol)),
            _scoreRow(
                isEs
                    ? 'Pantorrilla ≥3 cm mayor que contralateral'
                    : 'Panturrilha ≥3 cm maior que contralateral',
                _wt_calf_swol3cm,
                () => setState(() => _wt_calf_swol3cm = !_wt_calf_swol3cm)),
            _scoreRow(
                isEs
                    ? 'Edema con fóvea en pierna sintomática'
                    : 'Edema com cacifo na perna sintomática',
                _wt_pitting_edema,
                () => setState(() => _wt_pitting_edema = !_wt_pitting_edema)),
            _scoreRow(
                isEs
                    ? 'Venas superficiales colaterales'
                    : 'Veias superficiais colaterais',
                _wt_collateral_veins,
                () => setState(
                    () => _wt_collateral_veins = !_wt_collateral_veins)),
            _scoreRow(
                isEs ? 'TVP previa documentada' : 'TVP prévia documentada',
                _wt_previous_dvt,
                () => setState(() => _wt_previous_dvt = !_wt_previous_dvt)),
            _scoreRow(
                isEs
                    ? 'Diagnóstico alternativo más probable (−2)'
                    : 'Diagnóstico alternativo mais provável (−2)',
                _wt_alt_dx_likely,
                () => setState(() => _wt_alt_dx_likely = !_wt_alt_dx_likely),
                points: -2),
            const Divider(),
            _ResultTile(
                label: isEs ? 'Score Wells TVP' : 'Score Wells TVP',
                value: _wtScore.toStringAsFixed(0),
                unit: 'pts',
                note: _wtLabel(_wtScore),
                full: true),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
                    ? '≤0: Baja → D-dímero. 1–2: Moderada → D-dímero o eco-Doppler. ≥3: Alta → Eco-Doppler direto.'
                    : '≤0: Baixa → D-dímero. 1–2: Moderada → D-dímero ou eco-Doppler. ≥3: Alta → Eco-Doppler direto.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Wells TEP ─────────────────────────────────────────────────
        _SectionCard(
          title: isEs
              ? 'Wells — TEP (Tromboembolismo Pulmonar)'
              : 'Wells — TEP (Tromboembolismo Pulmonar)',
          icon: Icons.air_rounded,
          badge: _wpScore.toStringAsFixed(1),
          badgeColor: _wpScore < 2
              ? kToolGreen
              : _wpScore <= 6
                  ? const Color(0xFFB45309)
                  : const Color(0xFFCC2222),
          child: Column(children: [
            _scoreRow(
                isEs
                    ? 'Signos/síntomas de TVP (+3)'
                    : 'Sinais/sintomas de TVP (+3)',
                _wp_dvt_signs,
                () => setState(() => _wp_dvt_signs = !_wp_dvt_signs),
                points: 3),
            _scoreRow(
                isEs
                    ? 'TEP el diagnóstico más probable (+3)'
                    : 'TEP o diagnóstico mais provável (+3)',
                _wp_no_alt_dx,
                () => setState(() => _wp_no_alt_dx = !_wp_no_alt_dx),
                points: 3),
            _scoreRow(isEs ? 'FC > 100 bpm (+1,5)' : 'FC > 100 bpm (+1,5)',
                _wp_hr100, () => setState(() => _wp_hr100 = !_wp_hr100),
                points: 1.5),
            _scoreRow(
                isEs
                    ? 'Inmovilización ≥3 días / cirugía <4 semanas (+1,5)'
                    : 'Imobilização ≥3 dias / cirurgia <4 semanas (+1,5)',
                _wp_immob,
                () => setState(() => _wp_immob = !_wp_immob),
                points: 1.5),
            _scoreRow(
                isEs ? 'TVP/TEP previo (+1,5)' : 'TVP/TEP prévio (+1,5)',
                _wp_prev_dvt,
                () => setState(() => _wp_prev_dvt = !_wp_prev_dvt),
                points: 1.5),
            _scoreRow(
                isEs ? 'Hemoptisis (+1)' : 'Hemoptise (+1)',
                _wp_hemoptysis,
                () => setState(() => _wp_hemoptysis = !_wp_hemoptysis)),
            _scoreRow(
                isEs ? 'Malignidad activa (+1)' : 'Malignidade ativa (+1)',
                _wp_malignancy,
                () => setState(() => _wp_malignancy = !_wp_malignancy)),
            const Divider(),
            _ResultTile(
                label: isEs ? 'Score Wells TEP' : 'Score Wells TEP',
                value: _wpScore.toStringAsFixed(1),
                unit: 'pts',
                note: _wpLabel(_wpScore),
                full: true),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
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
          badgeColor: _curbScore <= 1
              ? kToolGreen
              : _curbScore == 2
                  ? const Color(0xFFB45309)
                  : const Color(0xFFCC2222),
          child: Column(children: [
            _scoreRow(
                isEs ? 'Confusión (nueva)' : 'Confusão (nova)',
                _curb_confusion,
                () => setState(() => _curb_confusion = !_curb_confusion)),
            _scoreRow(isEs ? 'Urea >50 mg/dL' : 'Ureia >50 mg/dL', _curb_ureia,
                () => setState(() => _curb_ureia = !_curb_ureia)),
            _scoreRow(isEs ? 'FR ≥30/min' : 'FR ≥30 irpm', _curb_rr,
                () => setState(() => _curb_rr = !_curb_rr)),
            _scoreRow(
                isEs ? 'PAS <90 o PAD ≤60 mmHg' : 'PAS <90 ou PAD ≤60 mmHg',
                _curb_bp,
                () => setState(() => _curb_bp = !_curb_bp)),
            _scoreRow(isEs ? 'Edad ≥65 años' : 'Idade ≥65 anos', _curb_age65,
                () => setState(() => _curb_age65 = !_curb_age65)),
            const Divider(),
            Row(children: [
              Expanded(
                  child: _ResultTile(
                      label: 'CURB-65', value: '$_curbScore', unit: '/5')),
              const SizedBox(width: 8),
              Expanded(
                  child: _ResultTile(
                      label: isEs ? 'Mortalidad' : 'Mortalidade',
                      value: _curbMort(_curbScore),
                      unit: '')),
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
          badgeColor: _newsTotal == 0
              ? kToolGreen
              : _newsTotal <= 4
                  ? const Color(0xFFB45309)
                  : const Color(0xFFCC2222),
          child: Column(children: [
            // FR
            _sofaDropRow(
                isEs ? 'FR (irpm)' : 'FR (irpm)',
                _news_rr,
                ['≤8 (+3)', '9–11 (+1)', '12–20 (0)', '21–24 (+2)', '≥25 (+3)'],
                (v) => setState(() => _news_rr = v ?? 0)),
            // SpO2 escala A
            _sofaDropRow(
                isEs ? 'SpO₂ % (Esc. A)' : 'SpO₂ % (Esc. A)',
                _news_spo2,
                ['≤91 (+3)', '92–93 (+2)', '94–95 (+1)', '≥96 (0)'],
                (v) => setState(() => _news_spo2 = v ?? 0)),
            // O2 suplementar
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(
                    child: Text(
                        isEs ? 'O₂ suplementario (+2)' : 'O₂ suplementar (+2)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.of(context).textPrimary))),
                Switch(
                  value: _news_supo2,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? kToolGreen
                        : null,
                  ),
                  onChanged: (v) => setState(() => _news_supo2 = v),
                ),
              ]),
            ),
            // PA sistólica
            _sofaDropRow(
                isEs ? 'PAS (mmHg)' : 'PAS (mmHg)',
                _news_sbp,
                [
                  '≤90 (+3)',
                  '91–100 (+2)',
                  '101–110 (+1)',
                  '111–219 (0)',
                  '≥220 (+3)'
                ],
                (v) => setState(() => _news_sbp = v ?? 0)),
            // FC
            _sofaDropRow(
                isEs ? 'FC (bpm)' : 'FC (bpm)',
                _news_hr,
                [
                  '≤40 (+3)',
                  '41–50 (+1)',
                  '51–90 (0)',
                  '91–110 (+1)',
                  '111–130 (+2)',
                  '≥131 (+3)'
                ],
                (v) => setState(() => _news_hr = v ?? 0)),
            // Nível consciência AVPU
            _sofaDropRow(
                isEs ? 'Conciencia (AVPU)' : 'Consciência (AVPU)',
                _news_neuro,
                isEs
                    ? [
                        'Alerta (0)',
                        'Voz/Confuso (+3)',
                        'Dolor (+3)',
                        'Inconsciente (+3)'
                      ]
                    : [
                        'Alerta (0)',
                        'Voz/Confuso (+3)',
                        'Dor (+3)',
                        'Inconsciente (+3)'
                      ],
                (v) =>
                    setState(() => _news_neuro = v != null && v > 0 ? 3 : 0)),
            // Temperatura
            _sofaDropRow(
                isEs ? 'Temperatura °C' : 'Temperatura °C',
                _news_temp,
                [
                  '≤35,0 (+3)',
                  '35,1–36,0 (+1)',
                  '36,1–38,0 (0)',
                  '38,1–39,0 (+1)',
                  '≥39,1 (+2)'
                ],
                (v) => setState(() => _news_temp = v ?? 0)),
            const Divider(),
            _ResultTile(
                label: 'NEWS2 Total',
                value: '$_newsTotal',
                unit: 'pts',
                note: _newsLabel(_newsTotal),
                full: true),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
                    ? 'Desarrollado por la Royal College of Physicians (RCP) 2017. Score ≥7 = activar respuesta crítica inmediata.'
                    : 'Royal College of Physicians 2017. Score ≥7 = acionar resposta de emergência imediata.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Child-Pugh ────────────────────────────────────────────────
        _SectionCard(
          title: isEs
              ? 'Child-Pugh (Hepatopatía Crónica)'
              : 'Child-Pugh (Hepatopatia Crônica)',
          icon: Icons.local_hospital_rounded,
          badge: '$_cpTotal',
          badgeColor: _cpTotal <= 6
              ? kToolGreen
              : _cpTotal <= 9
                  ? const Color(0xFFB45309)
                  : const Color(0xFFCC2222),
          child: Column(children: [
            _sofaDropRow(
                isEs ? 'Bilirrubina total' : 'Bilirrubina total',
                _cp_bili - 1,
                isEs
                    ? ['<2 mg/dL (1)', '2–3 mg/dL (2)', '>3 mg/dL (3)']
                    : ['<2 mg/dL (1)', '2–3 mg/dL (2)', '>3 mg/dL (3)'],
                (v) => setState(() => _cp_bili = (v ?? 0) + 1)),
            _sofaDropRow(
                isEs ? 'Albúmina sérica' : 'Albumina sérica',
                _cp_alb - 1,
                ['>3,5 g/dL (1)', '2,8–3,5 g/dL (2)', '<2,8 g/dL (3)'],
                (v) => setState(() => _cp_alb = (v ?? 0) + 1)),
            _sofaDropRow(
                'TP / INR',
                _cp_pt - 1,
                isEs
                    ? [
                        '<4 s / <1,7 (1)',
                        '4–6 s / 1,7–2,3 (2)',
                        '>6 s / >2,3 (3)'
                      ]
                    : [
                        '<4 s / <1,7 (1)',
                        '4–6 s / 1,7–2,3 (2)',
                        '>6 s / >2,3 (3)'
                      ],
                (v) => setState(() => _cp_pt = (v ?? 0) + 1)),
            _sofaDropRow(
                isEs ? 'Ascitis' : 'Ascite',
                _cp_ascite - 1,
                isEs
                    ? ['Ausente (1)', 'Leve (2)', 'Tensa/refractaria (3)']
                    : ['Ausente (1)', 'Leve (2)', 'Tensa/refratária (3)'],
                (v) => setState(() => _cp_ascite = (v ?? 0) + 1)),
            _sofaDropRow(
                isEs ? 'Encefalopatía' : 'Encefalopatia',
                _cp_encef - 1,
                isEs
                    ? [
                        'Ninguna — Grado 0 (1)',
                        'Grado I–II (2)',
                        'Grado III–IV (3)'
                      ]
                    : [
                        'Nenhuma — Grau 0 (1)',
                        'Grau I–II (2)',
                        'Grau III–IV (3)'
                      ],
                (v) => setState(() => _cp_encef = (v ?? 0) + 1)),
            const Divider(),
            _ResultTile(
                label: 'Child-Pugh',
                value: '$_cpTotal',
                unit: 'pts',
                note: _cpClass(_cpTotal),
                full: true),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
                    ? 'A (<6): cirrosis compensada. B (7–9): disfunción hepática significativa. C (≥10): descompensada — lista de trasplante.'
                    : 'A (≤6): cirrose compensada. B (7–9): disfunção hepática significativa. C (≥10): descompensada — avaliar transplante.'),
          ]),
        ),

        const SizedBox(height: 12),

        // ── PSI/PORT ──────────────────────────────────────────────────
        _SectionCard(
          title: isEs
              ? 'PSI/PORT (Neumonía — Gravedad)'
              : 'PSI/PORT (PAC — Gravidade)',
          icon: Icons.air_outlined,
          badge: '$_psiScore',
          badgeColor: _psiScore <= 70
              ? kToolGreen
              : _psiScore <= 90
                  ? const Color(0xFFB45309)
                  : const Color(0xFFCC2222),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Idade
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    child: Text(
                        isEs
                            ? 'Edad (años) — pontuação direta'
                            : 'Idade (anos) — pontuação direta',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.of(context).textPrimary))),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _psiAgeCtrl,
                    keyboardType: TextInputType.number,
                    spellCheckConfiguration:
                        const SpellCheckConfiguration.disabled(),
                    autocorrect: false,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.of(context).textPrimary),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      hintText: '65',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: kToolBorder)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
            ),
            Text('COMORBIDADES (+pts)',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.of(context).textHint)),
            const SizedBox(height: 6),
            _scoreRow(
                isEs ? 'Neoplasia activa (+30)' : 'Neoplasia ativa (+30)',
                _psi_neoplasm,
                () => setState(() => _psi_neoplasm = !_psi_neoplasm),
                points: 30),
            _scoreRow(
                isEs
                    ? 'Hepatopatía crónica (+20)'
                    : 'Hepatopatia crônica (+20)',
                _psi_liver,
                () => setState(() => _psi_liver = !_psi_liver),
                points: 20),
            _scoreRow(
                isEs ? 'ICC / cardiopatía (+10)' : 'ICC / cardiopatia (+10)',
                _psi_chf,
                () => setState(() => _psi_chf = !_psi_chf),
                points: 10),
            _scoreRow(isEs ? 'AVC / secuelas (+10)' : 'AVC / sequela (+10)',
                _psi_cva, () => setState(() => _psi_cva = !_psi_cva),
                points: 10),
            _scoreRow(isEs ? 'ERC (+10)' : 'DRC (+10)', _psi_renal,
                () => setState(() => _psi_renal = !_psi_renal),
                points: 10),
            _scoreRow(
                isEs
                    ? 'Internado en residencia (+10)'
                    : 'Institucionalizado (+10)',
                _psi_nursing,
                () => setState(() => _psi_nursing = !_psi_nursing),
                points: 10),
            const SizedBox(height: 8),
            Text('EXAME FÍSICO / CLÍNICA (+pts)',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.of(context).textHint)),
            const SizedBox(height: 6),
            _scoreRow(
                isEs
                    ? 'Confusión/alteración mental (+20)'
                    : 'Confusão / alt. mental (+20)',
                _psi_alt_ms,
                () => setState(() => _psi_alt_ms = !_psi_alt_ms),
                points: 20),
            _scoreRow(isEs ? 'FR ≥30/min (+20)' : 'FR ≥30 irpm (+20)',
                _psi_rr30, () => setState(() => _psi_rr30 = !_psi_rr30),
                points: 20),
            _scoreRow(isEs ? 'PAS <90 mmHg (+20)' : 'PAS <90 mmHg (+20)',
                _psi_sbp90, () => setState(() => _psi_sbp90 = !_psi_sbp90),
                points: 20),
            _scoreRow(isEs ? 'Tª <35 o ≥40°C (+15)' : 'T° <35 ou ≥40°C (+15)',
                _psi_temp, () => setState(() => _psi_temp = !_psi_temp),
                points: 15),
            _scoreRow(isEs ? 'FC ≥125 bpm (+10)' : 'FC ≥125 bpm (+10)',
                _psi_hr125, () => setState(() => _psi_hr125 = !_psi_hr125),
                points: 10),
            const SizedBox(height: 8),
            Text('LABS / IMAGEM (+pts)',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.of(context).textHint)),
            const SizedBox(height: 6),
            _scoreRow(
                isEs ? 'pH arterial <7,35 (+30)' : 'pH arterial <7,35 (+30)',
                _psi_ph735,
                () => setState(() => _psi_ph735 = !_psi_ph735),
                points: 30),
            _scoreRow(isEs ? 'BUN >30 mg/dL (+20)' : 'Ureia >30 mg/dL (+20)',
                _psi_bun30, () => setState(() => _psi_bun30 = !_psi_bun30),
                points: 20),
            _scoreRow(isEs ? 'Na <130 mEq/L (+20)' : 'Na <130 mEq/L (+20)',
                _psi_na130, () => setState(() => _psi_na130 = !_psi_na130),
                points: 20),
            _scoreRow(
                isEs ? 'Glucosa ≥250 mg/dL (+10)' : 'Glicose ≥250 mg/dL (+10)',
                _psi_gluc250,
                () => setState(() => _psi_gluc250 = !_psi_gluc250),
                points: 10),
            _scoreRow(isEs ? 'Hto <30% (+10)' : 'Ht <30% (+10)', _psi_hct30,
                () => setState(() => _psi_hct30 = !_psi_hct30),
                points: 10),
            _scoreRow(isEs ? 'PaO₂ <60 mmHg (+10)' : 'PaO₂ <60 mmHg (+10)',
                _psi_po2_60, () => setState(() => _psi_po2_60 = !_psi_po2_60),
                points: 10),
            _scoreRow(isEs ? 'Derrame pleural (+10)' : 'Derrame pleural (+10)',
                _psi_eff, () => setState(() => _psi_eff = !_psi_eff),
                points: 10),
            const Divider(),
            _ResultTile(
                label: 'PSI/PORT',
                value: '$_psiScore',
                unit: 'pts',
                note: _psiClass(_psiScore),
                full: true),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
                    ? 'Fine MJ, NEJM 1997. Clases I–II: ambulatorio. III: observación. IV–V: hospitalización. CURB-65 para comparar.'
                    : 'Fine MJ, NEJM 1997. Classes I–II: ambulatorial. III: observação. IV–V: internação. Comparar com CURB-65.'),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 3 — CARDIO HUB (Build 331 — Hub de Cards Clínicos)
//  childAspectRatio: 1.15 — 4 cards cabem limpos na tela mobile.
//  Cada card abre modal interativo com cálculo 100% funcional.
// ══════════════════════════════════════════════════════════════════
class CardioHubView extends StatefulWidget {
  const CardioHubView({Key? key}) : super(key: key);

  @override
  State<CardioHubView> createState() => _CardioHubViewState();
}

class _CardioHubViewState extends State<CardioHubView> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Fix #2: i18n CardioHub — lê o lang do AppProvider para PT/ES
    final isEs = context.watch<AppProvider>().lang == 'es';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEs ? 'Cardiología' : 'Cardiologia',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isEs
                ? 'Seleccione una calculadora para comenzar.'
                : 'Selecione uma calculadora para começar.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 14),

          // GRID COMPACTO: childAspectRatio 1.15 — 4 cards cabem na tela mobile
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [
              _buildCalcCard(
                context,
                isEs: isEs,
                title: isEs
                    ? 'Riesgo Cardiovascular (PREVENT / ASCVD)'
                    : 'Risco Cardiovascular (PREVENT / ASCVD)',
                desc: isEs
                    ? 'Estima el riesgo de 10 años para eventos de enfermedad cardiovascular aterosclerótica.'
                    : 'Estima o risco de 10 anos para eventos de doença cardiovascular aterosclerótica.',
                onTap: () => _openPREVENTModal(context),
              ),
              _buildCalcCard(
                context,
                isEs: isEs,
                title: isEs ? 'Escala CHA₂DS₂-VASc' : 'Escore CHA₂DS₂-VASc',
                desc: isEs
                    ? 'Estima el riesgo de ACV en pacientes con Fibrilación Auricular.'
                    : 'Estima o risco de AVC em pacientes com Fibrilação Atrial.',
                onTap: () => _openCHA2DS2VAScModal(context),
              ),
              _buildCalcCard(
                context,
                isEs: isEs,
                title: isEs
                    ? 'Intervalo QT Corregido (QTc)'
                    : 'Intervalo QT Corrigido (QTc)',
                desc: isEs
                    ? 'Calcula el intervalo QT corregido por la frecuencia cardíaca.'
                    : 'Calcula o intervalo QT corrigido pela frequência cardíaca.',
                onTap: () => _openQTcModal(context),
              ),
              _buildCalcCard(
                context,
                isEs: isEs,
                title: isEs ? 'Escala HAS-BLED' : 'Escore HAS-BLED',
                desc: isEs
                    ? 'Riesgo de sangrado en Fibrilación Auricular.'
                    : 'Risco de sangramento em Fibrilação Atrial.',
                onTap: () => _openHASBLEDModal(context),
              ),
            ],
          ),
          const SizedBox(
              height: 80), // Margem de segurança para o Dock flutuante inferior
        ],
      ),
    );
  }

  Widget _buildCalcCard(
    BuildContext context, {
    required String title,
    required String desc,
    required VoidCallback onTap,
    bool isEs = false, // Fix #2: param i18n — action label PT/ES
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2330) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isEs
                      ? 'Cardiología'
                      : 'Cardiologia', // BUILD 332: badge i18n OK
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              Icon(
                Icons.star_border_rounded,
                size: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  // Fix #2: maxLines:2 evita truncamento em ES (títulos mais longos)
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fix #2: label i18n PT/ES — arrow embutido na string
                Text(
                  isEs
                      ? 'Abrir calculadora >'
                      : 'Abrir Calculadora >', // BUILD 332 Fix 3: ES lowercase
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 8, color: Colors.blue[600]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. MODAL: QTc — Fórmula de Bazett ────────────────────────────
  void _openQTcModal(BuildContext context) {
    double qt = 400;
    double fc = 75;
    double qtcResult = 447;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void recalculate() {
            if (fc > 0) {
              final double rr = 60 / fc;
              qtcResult = (qt / 1000) / sqrt(rr) * 1000;
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Intervalo QT Corrigido (Bazett)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Intervalo QT: ${qt.round()} ms',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: qt,
                  min: 200,
                  max: 600,
                  activeColor: Colors.blue,
                  onChanged: (v) => setModalState(() {
                    qt = v;
                    recalculate();
                  }),
                ),
                Text(
                  'Frequência Cardíaca: ${fc.round()} bpm',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: fc,
                  min: 40,
                  max: 180,
                  activeColor: Colors.blue,
                  onChanged: (v) => setModalState(() {
                    fc = v;
                    recalculate();
                  }),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Resultado QTc: ${qtcResult.toStringAsFixed(0)} ms',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 2. MODAL: CHA₂DS₂-VASc ────────────────────────────────────────
  void _openCHA2DS2VAScModal(BuildContext context) {
    int score = 0;
    final Map<String, int> criteria = {
      'Insuficiência Cardíaca Congestiva': 1,
      'Hipertensão Arterial': 1,
      'Diabetes Mellitus': 1,
      'Doença Vascular (IM prévio, DAP ou placa na aorta)': 1,
      'Sexo Feminino': 1,
    };
    final Map<String, bool> selectedCriteria = {
      for (final k in criteria.keys) k: false,
    };
    int ageGroup = 0; // 0 = <65, 1 = 65-74 (+1), 2 = >=75 (+2)
    bool historicStroke = false; // +2

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void calculate() {
            int current = 0;
            selectedCriteria.forEach((key, val) {
              if (val) current += criteria[key]!;
            });
            if (ageGroup == 1) current += 1;
            if (ageGroup == 2) current += 2;
            if (historicStroke) current += 2;
            score = current;
          }

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Escore CHA₂DS₂-VASc',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ...criteria.keys.map((key) => CheckboxListTile(
                        title: Text(key, style: const TextStyle(fontSize: 13)),
                        value: selectedCriteria[key],
                        dense: true,
                        activeColor: Colors.blue,
                        onChanged: (val) => setModalState(() {
                          selectedCriteria[key] = val ?? false;
                          calculate();
                        }),
                      )),
                  CheckboxListTile(
                    title: const Text(
                      'AVC / AIT / Tromboembolismo Prévio (+2)',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    value: historicStroke,
                    dense: true,
                    activeColor: Colors.blue,
                    onChanged: (val) => setModalState(() {
                      historicStroke = val ?? false;
                      calculate();
                    }),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'Faixa Etária:',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ChoiceChip(
                        label: const Text('<65 anos'),
                        selected: ageGroup == 0,
                        selectedColor: Colors.blue,
                        onSelected: (_) => setModalState(() {
                          ageGroup = 0;
                          calculate();
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('65-74 (+1)'),
                        selected: ageGroup == 1,
                        selectedColor: Colors.blue,
                        onSelected: (_) => setModalState(() {
                          ageGroup = 1;
                          calculate();
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('≥75 (+2)'),
                        selected: ageGroup == 2,
                        selectedColor: Colors.blue,
                        onSelected: (_) => setModalState(() {
                          ageGroup = 2;
                          calculate();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Pontuação: $score Pts',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 3. MODAL: HAS-BLED ────────────────────────────────────────────
  void _openHASBLEDModal(BuildContext context) {
    int score = 0;
    final Map<String, bool> criteria = {
      'Hipertensão (PAS > 160 mmHg)': false,
      'Função Renal Alterada (Cr > 2.3 mg/dL ou Diálise)': false,
      'Função Hepática Alterada (Cirrose ou Bilirrubina 2x LNS)': false,
      'Histórico de AVC / AIT': false,
      'Histórico de Sangramento Prévio ou Predisposição': false,
      'INR Instável (Tempo na faixa terapêutica < 60%)': false,
      'Idade > 65 anos': false,
      'Uso de Medicamentos (Antiplaquetários / AINEs)': false,
      'Consumo de Álcool Abusivo (≥ 8 doses/semana)': false,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void calculate() {
            int current = 0;
            criteria.forEach((key, val) {
              if (val) current++;
            });
            score = current;
          }

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Escore HAS-BLED',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ...criteria.keys.map((key) => CheckboxListTile(
                        title: Text(key, style: const TextStyle(fontSize: 13)),
                        value: criteria[key],
                        dense: true,
                        activeColor: Colors.blue,
                        onChanged: (val) => setModalState(() {
                          criteria[key] = val ?? false;
                          calculate();
                        }),
                      )),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Pontuação: $score Pts',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 4. MODAL: PREVENT / ASCVD (modelo ponderado aproximado) ───────
  void _openPREVENTModal(BuildContext context) {
    bool isFemale = false;
    bool hasDiabetes = false;
    bool isSmoker = false;
    double pas = 120;
    double colTotal = 200;
    double riskResult = 4.2;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void calculate() {
            double base = 1.2;
            if (isSmoker) base += 2.5;
            if (hasDiabetes) base += 3.1;
            base += (pas - 110) * 0.15;
            base += (colTotal - 150) * 0.05;
            if (isFemale) base *= 0.85;
            riskResult = base.clamp(0.5, 95.0);
          }

          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Risco Cardiovascular (PREVENT / ASCVD)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Sexo Feminino',
                        style: TextStyle(fontSize: 13)),
                    value: isFemale,
                    activeColor: Colors.blue,
                    dense: true,
                    onChanged: (val) => setModalState(() {
                      isFemale = val;
                      calculate();
                    }),
                  ),
                  SwitchListTile(
                    title: const Text('Diabetes Mellitus',
                        style: TextStyle(fontSize: 13)),
                    value: hasDiabetes,
                    activeColor: Colors.blue,
                    dense: true,
                    onChanged: (val) => setModalState(() {
                      hasDiabetes = val;
                      calculate();
                    }),
                  ),
                  SwitchListTile(
                    title: const Text('Tabagista Ativo',
                        style: TextStyle(fontSize: 13)),
                    value: isSmoker,
                    activeColor: Colors.blue,
                    dense: true,
                    onChanged: (val) => setModalState(() {
                      isSmoker = val;
                      calculate();
                    }),
                  ),
                  Text(
                    'Pressão Arterial Sistólica: ${pas.round()} mmHg',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Slider(
                    value: pas,
                    min: 90,
                    max: 200,
                    activeColor: Colors.blue,
                    onChanged: (v) => setModalState(() {
                      pas = v;
                      calculate();
                    }),
                  ),
                  Text(
                    'Colesterol Total: ${colTotal.round()} mg/dL',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Slider(
                    value: colTotal,
                    min: 100,
                    max: 400,
                    activeColor: Colors.blue,
                    onChanged: (v) => setModalState(() {
                      colTotal = v;
                      calculate();
                    }),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Risco em 10 anos: ${riskResult.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
      onTap: () {
        AppHaptics.light(context);
        showAnalyzeExamBottomSheet(context, locale);
      },
      child: Container(
        decoration: BoxDecoration(
          // Gradiente escuro alinhado ao header do app
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F1116), Color(0xFF1B3D2A), Color(0xFF17502E)],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: kGold.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF0D6B57).withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () {
              AppHaptics.light(context);
              showAnalyzeExamBottomSheet(context, locale);
            },
            borderRadius: BorderRadius.circular(18),
            splashColor: kGoldLight.withOpacity(0.06),
            highlightColor: kGoldLight.withOpacity(0.03),
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
                      color: kGold.withOpacity(0.12),
                      border: Border.all(
                        color: kGold.withOpacity(0.30),
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
                            color: Colors.white.withOpacity(0.52),
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
                          color: const Color(0xFF46E28C).withOpacity(0.14),
                          border: Border.all(
                            color: const Color(0xFF46E28C).withOpacity(0.35),
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
                        color: Colors.white.withOpacity(0.30),
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
  final _naCtrl = TextEditingController();
  final _clCtrl = TextEditingController();
  final _hco3Ctrl = TextEditingController();
  final _glucCtrl = TextEditingController();
  final _albumCtrl = TextEditingController();
  final _caCtrl = TextEditingController();
  final _bunCtrl = TextEditingController();
  final _phCtrl = TextEditingController();
  final _pco2Ctrl = TextEditingController();
  final _beCtrl = TextEditingController();
  final _wCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _naCtrl,
      _clCtrl,
      _hco3Ctrl,
      _glucCtrl,
      _albumCtrl,
      _caCtrl,
      _bunCtrl,
      _phCtrl,
      _pco2Ctrl,
      _beCtrl,
      _wCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.'));
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
    final ph = _n(_phCtrl);
    final pco2 = _n(_pco2Ctrl);
    final hco3 = _n(_hco3Ctrl);
    final be = _n(_beCtrl);
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
        comp = pco2 < expPco2 - 2
            ? 'com compensação respiratória (hiperventilação)'
            : pco2 > expPco2 + 2
                ? 'com distúrbio respiratório adicional'
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
      if (be > 3) comp += ' | BE: ↑ excesso de base (${_fmt(be)})';
    }

    return '$primary${comp.isNotEmpty ? "\n$comp" : ""}';
  }

  String _agLabel(String? v) {
    final d = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (d == null) return '';
    if (d < 8) return '↓ Baixo (<8)';
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
              Expanded(
                  child: _LabeledInput(
                      label: 'Na⁺ (mEq/L)',
                      ctrl: _naCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '140')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: 'Cl⁻ (mEq/L)',
                      ctrl: _clCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '104')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _LabeledInput(
                      label: 'HCO₃⁻ (mEq/L)',
                      ctrl: _hco3Ctrl,
                      onChanged: (_) => setState(() {}),
                      hint: '24')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Glucosa (mg/dL)' : 'Glicose (mg/dL)',
                      ctrl: _glucCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '100')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Ca²⁺ total (mg/dL)' : 'Ca²⁺ total (mg/dL)',
                      ctrl: _caCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '9,5')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Albúmina (g/dL)' : 'Albumina (g/dL)',
                      ctrl: _albumCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '4,0')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'BUN (mg/dL)' : 'BUN/Ureia (mg/dL)',
                      ctrl: _bunCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '14')),
              const SizedBox(width: 10),
              Expanded(child: SizedBox()), // espaço reservado para simetria
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _ResultTile(
                      label: isEs ? 'Gap Aniónico' : 'Gap Aniônico',
                      value: _anionGap,
                      unit: 'mEq/L',
                      note: _agLabel(_anionGap))),
              const SizedBox(width: 8),
              Expanded(
                  child: _ResultTile(
                      label: 'Na⁺ Corrigido', value: _corrNa, unit: 'mEq/L')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _ResultTile(
                      label: isEs ? 'Ca²⁺ Corregido' : 'Ca²⁺ Corrigido',
                      value: _corrCa,
                      unit: 'mg/dL',
                      note: double.tryParse(
                                  (_corrCa ?? '').replaceAll(',', '.')) !=
                              null
                          ? (double.parse(_corrCa!.replaceAll(',', '.')) < 8.5
                              ? 'BAIXO: Hipocalcemia'
                              : double.parse(_corrCa!.replaceAll(',', '.')) >
                                      10.5
                                  ? 'ALTO: Hipercalcemia'
                                  : 'Normal')
                          : '')),
              const SizedBox(width: 8),
              Expanded(
                  child: _ResultTile(
                      label: isEs ? 'Osmolaridad calc.' : 'Osmolaridade calc.',
                      value: _osmolarity,
                      unit: 'mOsm/kg')),
            ]),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
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
              Expanded(
                  child: _LabeledInput(
                      label: 'pH',
                      ctrl: _phCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '7,40')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: 'pCO₂ (mmHg)',
                      ctrl: _pco2Ctrl,
                      onChanged: (_) => setState(() {}),
                      hint: '40')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _LabeledInput(
                      label: 'HCO₃⁻ (mEq/L)',
                      ctrl: _hco3Ctrl,
                      onChanged: (_) => setState(() {}),
                      hint: '24')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: 'BE (mEq/L)',
                      ctrl: _beCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '0')),
            ]),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF0F1116),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INTERPRETAÇÃO',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xBFFFE8A6),
                            letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(_gasInterpret(),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.5)),
                  ]),
            ),
            const SizedBox(height: 10),
            _InfoNote(
                text: isEs
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
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Peso (kg)' : 'Peso (kg)',
                      ctrl: _wCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '70')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: 'HCO₃⁻ atual (mEq/L)',
                      ctrl: _hco3Ctrl,
                      onChanged: (_) => setState(() {}),
                      hint: '18')),
            ]),
            const SizedBox(height: 14),
            _ResultTile(
                label: isEs
                    ? 'Déficit de HCO₃⁻ (meta: 24)'
                    : 'Déficit de HCO₃⁻ (meta: 24)',
                value: _bicarbonateDef,
                unit: 'mEq',
                full: true,
                note: isEs
                    ? 'Fórmula: Peso × 0,3 × (24 − HCO₃). Repor 50% do déficit inicialmente.'
                    : 'Fórmula: Peso × 0,3 × (24 − HCO₃). Repor 50% do déficit inicialmente.'),
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
    required this.name,
    required this.dose,
    required this.concDefault,
    required this.indication,
    this.risks = const [],
    this.avoid = const [],
  });
}

class _InfusionTab extends StatefulWidget {
  @override
  State<_InfusionTab> createState() => _InfusionTabState();
}

class _InfusionTabState extends State<_InfusionTab> {
  final _infDrugCtrl = TextEditingController(text: 'Noradrenalina');
  final _infConcCtrl = TextEditingController(text: '4');
  final _infRateCtrl = TextEditingController(text: '10');
  final _infWeightCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _concCalcCtrl = TextEditingController();
  final _weightCalcCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

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
      indication:
          'Inotrópico 1ª linha — IC com baixo débito / choque cardiogênico',
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
      indication:
          'Adjuvante vasopressor — sepse refratária (dose fixa, não titular)',
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
      indication:
          'Vasopressor alternativo — bradicardia + hipotensão (2ª linha)',
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
      indication:
          'Vasodilatador venoso/arterial — angina instável / EPA / crise HAS',
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
      indication:
          'Antiarrítmico 1ª linha — FA/flutter/TV com pulso / PCR (FV/TVSP)',
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
      indication:
          'Antiarrítmico ventricular — TV refratária / FV pós-PCR / analgesia IV',
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
      indication:
          'Analgesia IV potente — dor aguda grave / crise álgica oncológica',
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
      indication:
          'Sedação em UTI / indução anestésica / IOT de sequência rápida',
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
      indication:
          'Sedação em UTI / status epilepticus / pré-medicação anestésica',
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
    // Registra uso da calculadora no histórico
    ActivityService.log(
      type: ActivityType.calculadora,
      title: d.name,
      subtitle: 'Calculadora de Infusão',
    );
    setState(() {
      _infDrugCtrl.text = d.name;
      _infConcCtrl.text = d.concDefault;
      _infRateCtrl.text = '10';
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
    // MEMLEAK-FIX: _scrollCtrl estava faltando — adicionado para fechar
    // o ScrollController da lista de infusões e liberar listeners nativos.
    _scrollCtrl.dispose();
    for (final c in [
      _infDrugCtrl,
      _infConcCtrl,
      _infRateCtrl,
      _infWeightCtrl,
      _doseCtrl,
      _concCalcCtrl,
      _weightCalcCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.'));
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
    final conc = _n(_infConcCtrl);
    final rate = _n(_infRateCtrl);
    final weight = _n(_infWeightCtrl);
    if (conc == null || rate == null) return null;
    final mgH = conc * rate;
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
              Expanded(
                  child: _LabeledInput(
                      label: isEs
                          ? 'Concentración (mg/mL)'
                          : 'Concentração (mg/mL)',
                      ctrl: _infConcCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '4')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Velocidad (mL/h)' : 'Velocidade (mL/h)',
                      ctrl: _infRateCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '10')),
            ]),
            const SizedBox(height: 10),
            _LabeledInput(
                label: isEs
                    ? 'Peso (kg) — opcional para mcg/kg/min'
                    : 'Peso (kg) — opcional para mcg/kg/min',
                ctrl: _infWeightCtrl,
                onChanged: (_) => setState(() {}),
                hint: '70'),
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
            _InfoNote(
                text: isEs
                    ? 'Verificar prescripción antes de administrar. Revisar protocolo institucional.'
                    : 'Verificar prescrição antes de administrar. Revisar protocolo institucional.'),
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: isEs
              ? 'Dosis → Velocidad (mcg/kg/min)'
              : 'Dose → Velocidade (mcg/kg/min)',
          icon: Icons.swap_vert_rounded,
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: _LabeledInput(
                      label: isEs ? 'Dosis (mcg/kg/min)' : 'Dose (mcg/kg/min)',
                      ctrl: _doseCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '0,1')),
              const SizedBox(width: 10),
              Expanded(
                  child: _LabeledInput(
                      label: isEs
                          ? 'Concentración (mg/mL)'
                          : 'Concentração (mg/mL)',
                      ctrl: _concCalcCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: '4')),
            ]),
            const SizedBox(height: 10),
            _LabeledInput(
                label:
                    isEs ? 'Peso del paciente (kg)' : 'Peso do paciente (kg)',
                ctrl: _weightCalcCtrl,
                onChanged: (_) => setState(() {}),
                hint: '70'),
            const SizedBox(height: 14),
            _ResultTile(
                label: isEs ? 'Velocidad de Infusión' : 'Velocidade de Infusão',
                value: _doseToRate,
                unit: '',
                full: true,
                note: isEs
                    ? 'Fórmula: Dosis × Peso × 60 / (Conc × 1000)'
                    : 'Fórmula: Dose × Peso × 60 / (Conc × 1000)'),
          ]),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: isEs
              ? 'Fármacos de Referencia (toque para simular)'
              : 'Fármacos de Referência (toque para simular)',
          icon: Icons.touch_app_rounded,
          child: Column(children: [
            _InfoNote(
                text: isEs
                    ? 'Toque en un fármaco para cargar los parámetros de referencia de la literatura médica. El simulador requiere peso y velocidad teóricos.'
                    : 'Toque em um fármaco para carregar os parâmetros de referência da literatura médica. O simulador requer peso e velocidade teóricos.'),
            const SizedBox(height: 10),
            ..._rescue.map((d) => _VasoRefRow(
                  drug: d.name,
                  dose: d.dose,
                  note: d.indication,
                  onTap: () => _fillAndScroll(d, context),
                )),
            const SizedBox(height: 8),
            _InfoNote(
                text: isEs
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
          colors: [
            Color(0xFF071510),
            Color(0xFF0D2B1C),
            Color(0xFF0F3D28),
            Color(0xFF075f45)
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF075f45).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF0D6B57).withOpacity(0.6),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8A6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFFE8A6).withOpacity(0.30),
                        ),
                      ),
                      child: Text(
                        isEs
                            ? 'RESULTADO DE LA INFUSIÓN'
                            : 'RESULTADO DA INFUSÃO',
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
                  drugName.isNotEmpty
                      ? drugName
                      : (isEs ? 'Fármaco' : 'Medicamento'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(hasResult ? 1.0 : 0.5),
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
                            size: 16, color: Colors.white.withOpacity(0.35)),
                        const SizedBox(width: 8),
                        Text(
                          isEs
                              ? 'Ingrese concentración y velocidad'
                              : 'Informe concentração e velocidade',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.40),
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
                        Expanded(
                            child: _ResultMetric(
                                value: parts[0],
                                label: _labelFor(parts[0], isEs))),
                        Container(
                            width: 1,
                            height: 60,
                            color: Colors.white.withOpacity(0.12)),
                        Expanded(
                            child: _ResultMetric(
                                value: parts[1],
                                label: _labelFor(parts[1], isEs))),
                      ],
                    )
                  else
                    _ResultMetric(
                        value: parts[0],
                        label: _labelFor(parts[0], isEs),
                        large: true),

                  const SizedBox(height: 14),
                  // ── Fórmula utilizada ───────────────────────────────────────
                  if (infusionFormula != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.functions_rounded,
                                  size: 11, color: const Color(0xBFFFE8A6)),
                              const SizedBox(width: 5),
                              Text(
                                isEs
                                    ? 'FÓRMULA UTILIZADA'
                                    : 'FÓRMULA UTILIZADA', // técnico — igual em ambos os idiomas
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.menu_book_rounded,
                                size: 11, color: const Color(0xBFFFE8A6)),
                            const SizedBox(width: 5),
                            Text(
                              isEs
                                  ? 'REFERENCIAS BIBLIOGRÁFICAS'
                                  : 'REFERÊNCIAS BIBLIOGRÁFICAS',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Color(0xBFFFE8A6),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          _RefLine(
                              text: isEs
                                  ? '1. Brunton LL, et al. Goodman & Gilman\'s Pharmacological Basis of Therapeutics, 14th ed. McGraw-Hill, 2023.'
                                  : '1. Brunton LL, et al. Goodman & Gilman\'s Pharmacological Basis of Therapeutics, 14ª ed. McGraw-Hill, 2023.'),
                          const SizedBox(height: 3),
                          _RefLine(
                              text: isEs
                                  ? '2. Marino PL. The ICU Book, 4th ed. Lippincott Williams & Wilkins, 2014.'
                                  : '2. Marino PL. The ICU Book, 4ª ed. Lippincott Williams & Wilkins, 2014.'),
                          const SizedBox(height: 3),
                          _RefLine(
                              text: isEs
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
    if (val.contains('mcg/kg/min'))
      return isEs ? 'Microgramos/kg/min' : 'Microgramos/kg/min';
    if (val.contains('mcg/h'))
      return isEs ? 'Microgramos por hora' : 'Microgramas por hora';
    if (val.contains('mg/h'))
      return isEs ? 'Miligramos por hora' : 'Miligramas por hora';
    if (val.contains('mL/h'))
      return isEs ? 'Mililitros por hora' : 'Mililitros por hora';
    return '';
  }
}

// Métrica individual dentro do card de resultado
class _ResultMetric extends StatelessWidget {
  final String value;
  final String label;
  final bool large;
  const _ResultMetric(
      {required this.value, required this.label, this.large = false});

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
            color: Colors.white.withOpacity(0.50),
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
  const _VasoRefRow(
      {required this.drug, required this.dose, required this.note, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dark = context.watch<AppProvider>().darkMode;
    final tappable = onTap != null;
    return GestureDetector(
      onTap: onTap != null
          ? () {
              AppHaptics.selection(context);
              onTap!();
            }
          : null,
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
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(drug,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(note,
                    style: TextStyle(
                        fontSize: 11, color: c.textSecondary, height: 1.3)),
              ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: kToolGreen.withOpacity(0.12),
              ),
              child: Text(dose,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kToolGreen)),
            ),
            if (tappable) ...[
              const SizedBox(height: 3),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.touch_app_rounded,
                    size: 9,
                    color: dark
                        ? const Color(0xFF0D6B57)
                        : const Color(0xFF0D6B57)),
                const SizedBox(width: 3),
                Text('calcular',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: dark
                            ? const Color(0xFF0D6B57)
                            : const Color(0xFF0D6B57))),
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
    final bg = dark ? const Color(0xFF252930) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
                child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color:
                      dark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 14),

            // Cabeçalho
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFEF4444).withOpacity(0.12)),
                child: const Icon(Icons.medication_rounded,
                    size: 18, color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(drug.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color:
                                dark ? Colors.white : const Color(0xFF0F172A))),
                    Text('Calculadora preenchida — informe peso e velocidade',
                        style: TextStyle(
                            fontSize: 11,
                            color: dark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280))),
                  ])),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close_rounded,
                    size: 20,
                    color: dark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280)),
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
                  backgroundColor: kToolGreen.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.calculate_rounded,
                      size: 16, color: kToolGreen),
                  const SizedBox(width: 8),
                  const Text('Entendido — ir para a calculadora',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kToolGreen)),
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
    required this.label,
    required this.labelColor,
    required this.icon,
    required this.items,
    required this.bgDark,
    required this.bgLight,
    required this.borderDark,
    required this.borderLight,
    required this.textDark,
    required this.textLight,
    required this.dark,
  }) : iconColor = labelColor;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? bgDark : bgLight;
    final border = dark ? borderDark : borderLight;
    final text = dark ? textDark : textLight;

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
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: labelColor,
                  letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                        color: text.withOpacity(0.6), shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(item,
                        style:
                            TextStyle(fontSize: 12, color: text, height: 1.4))),
              ]),
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 6 — REFERÊNCIA RÁPIDA (Fix#7: Dashboard Grid)
//  Sub-tabs removidas. Tela raiz = ReferenceDashboard (grid 2 colunas).
//  Navegação via Navigator.push → 4 telas filhas dedicadas.
// ══════════════════════════════════════════════════════════════════
class _ReferenceTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const ReferenceDashboard();
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
        isEs ? 'NÁUSEAS' : 'NÁUSEA',
        isEs ? 'INFECCIÓN' : 'INFECÇÃO',
        'HAS',
        'HipoK+',
        isEs ? 'SEDACIÓN' : 'SEDAÇÃO',
        isEs ? 'SEPSIS' : 'SEPSE',
        isEs ? 'COAGULACIÓN' : 'COAGULAÇÃO',
        isEs ? 'ANTI-HAS GRAVE' : 'ANTI-HAS GRAVE',
        isEs ? 'DISNEA' : 'DISPNEIA',
      ];

  // Ícones por categoria de prescrição
  static const _catIcons = [
    Icons.healing_rounded, // DOR/FEBRE
    Icons.sick_rounded, // NÁUSEA
    Icons.coronavirus_rounded, // INFECÇÃO
    Icons.monitor_heart_rounded, // HAS
    Icons.science_rounded, // HipoK+
    Icons.bedtime_rounded, // SEDAÇÃO
    Icons.warning_amber_rounded, // SEPSE
    Icons.bloodtype_rounded, // COAGULAÇÃO
    Icons.local_fire_department_rounded, // ANTI-HAS GRAVE
    Icons.air_rounded, // DISPNEIA
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final categories = _categories(isEs);

    return Column(children: [
      // ── Sub-tabs com underline indicator ──────────────────────
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1116),
          border: Border(
              bottom:
                  BorderSide(color: Colors.white.withOpacity(0.08), width: 1)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: List.generate(categories.length, (i) {
              final active = _cat == i;
              return GestureDetector(
                onTap: () {
                  AppHaptics.selection(context);
                  setState(() => _cat = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                      color:
                          active ? const Color(0xFF0D6B57) : Colors.transparent,
                      width: 2.5,
                    )),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_catIcons[i],
                        size: 13,
                        color: active
                            ? const Color(0xFF0D6B57)
                            : Colors.white.withOpacity(0.40)),
                    const SizedBox(width: 5),
                    Text(categories[i],
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w500,
                          color: active
                              ? const Color(0xFF0D6B57)
                              : Colors.white.withOpacity(0.45),
                          letterSpacing: 0.5,
                        )),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          child: _buildPrescription(isEs),
        ),
      ),
    ]);
  }

  Widget _buildPrescription(bool isEs) {
    switch (_cat) {
      case 0:
        return _buildPainFever(isEs);
      case 1:
        return _buildNausea(isEs);
      case 2:
        return _buildInfection(isEs);
      case 3:
        return _buildHAS(isEs);
      case 4:
        return _buildHypoK(isEs);
      case 5:
        return _buildSedation(isEs);
      case 6:
        return _buildSepsis(isEs);
      case 7:
        return _buildCoagulation(isEs);
      case 8:
        return _buildHypertensiveEmergency(isEs);
      case 9:
        return _buildDyspnea(isEs);
      default:
        return const SizedBox();
    }
  }

  Widget _buildPainFever(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs
            ? 'Dolor Leve–Moderado (Adulto)'
            : 'Dor Leve–Moderada (Adulto)',
        level: 'MOD',
        badge: isEs ? '1ª Elección' : '1ª Escolha',
        sideTitle: isEs ? 'Claves rápidas' : 'Pontos-chave',
        sideBody: isEs
            ? 'Paracetamol es seguro, eficaz y puede combinarse con otras medicaciones.'
            : 'Paracetamol é seguro, eficaz e pode ser combinado com outras medicações.',
        sideType: _SideNoteType.info,
        evidence: isEs
            ? 'Modelo educativo · WHO Essential Medicines 2023 · UpToDate: Acetaminophen use in adults · Micromedex DrugDex'
            : 'Modelo educacional · OMS Medicamentos Essenciais 2023 · UpToDate: Paracetamol no adulto · Micromedex DrugDex',
        tags: [
          _PrescTag(isEs ? 'DOR LEVE' : 'DOR LEVE', const Color(0xFF059669)),
          _PrescTag(
              isEs ? 'DOR MODERADA' : 'DOR MODERADA', const Color(0xFFD97706)),
          _PrescTag('Adulto', const Color(0xFF6366F1)),
        ],
        items: [
          _PrescItem(
              '1.',
              isEs
                  ? 'Paracetamol 1 g VO/IV 6/6h (máx. 4 g/dia). Preferir para febre e dor leve.'
                  : 'Paracetamol 1 g VO/IV 6/6h (máx. 4 g/dia). Preferir para febre e dor leve.'),
          _PrescItem(
              '2.',
              isEs
                  ? 'SE necessário: Ibuprofeno 400–600 mg 8/8h VO (com alimento). Evitar em IR, úlcera, ICC.'
                  : 'SE necessário: Ibuprofeno 400–600 mg 8/8h VO (com alimento). Evitar IR, úlcera, ICC.'),
          _PrescItem(
              '3.',
              isEs
                  ? 'Dipirona 1 g VO/IV 6/6h (IV lento ≥15 min). Alternativa eficaz.'
                  : 'Dipirona 1 g VO/IV 6/6h (IV lento ≥15 min). Alternativa eficaz.'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'Não combinar dois AINEs. Evitar em gestante, IR grave, plaquetopenia.'
                  : 'Não combinar dois AINEs. Evitar em gestante, IR grave, plaquetopenia.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Dolor Moderado–Severo' : 'Dor Moderada–Grave',
        level: 'ALTO',
        badge: isEs ? 'Uso cuidadoso' : 'Uso cuidadoso',
        sideTitle: isEs ? 'Precaución' : 'Precaução',
        sideBody: isEs
            ? 'Opioides pueden causar depresión respiratoria. Monitorización esencial.'
            : 'Opioides podem causar depressão respiratória. Monitorização essencial.',
        sideType: _SideNoteType.warning,
        evidence: isEs
            ? 'Modelo educativo · Lexicomp Opioid Analgesics · APS Pain Guidelines 2022 · UpToDate: Management of acute pain'
            : 'Modelo educacional · Lexicomp Analgésicos Opioides · APS Pain Guidelines 2022 · UpToDate: Manejo da dor aguda',
        tags: [
          _PrescTag(
              isEs ? 'DOR MODERADA' : 'DOR MODERADA', const Color(0xFFD97706)),
          _PrescTag(
              isEs ? 'DOR SEVERA' : 'DOR SEVERA', const Color(0xFFDC2626)),
          _PrescTag('Adulto', const Color(0xFF6366F1)),
        ],
        items: [
          _PrescItem(
              '1.',
              isEs
                  ? 'Tramadol 50–100 mg VO 8/8h (ou IV lento em 100 mL SF). Máx. 400 mg/dia.'
                  : 'Tramadol 50–100 mg VO 8/8h (ou IV lento em 100 mL SF). Máx. 400 mg/dia.'),
          _PrescItem(
              '2.',
              isEs
                  ? 'Morfina 2–5 mg IV lento a cada 4h. Titular pela dor (EV ou PO). Cuidado: depressão respiratória.'
                  : 'Morfina 2–5 mg IV lento a cada 4h. Titular pela dor (EV ou PO). Cuidado: depressão resp.'),
          _PrescItem(
              '3.',
              isEs
                  ? 'Cetorolaco 30 mg IV/IM 8/8h (máx. 5 dias). Excelente para cólica renal.'
                  : 'Cetorolaco 30 mg IV/IM 8/8h (máx. 5 dias). Excelente para cólica renal.'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'Naloxona 0,4 mg IV disponível. Monitorar SpO2 contínua com opioides IV.'
                  : 'Naloxona 0,4 mg IV disponível. Monitorar SpO2 contínua com opioides IV.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Fiebre (T >38,3°C)' : 'Febre (T >38,3°C)',
        level: 'MOD',
        badge: isEs ? '1ª Elección' : '1ª Escolha',
        sideTitle: isEs ? 'Importante' : 'Importante',
        sideBody: isEs
            ? 'Tratar la causa es más importante que solo reducir la fiebre.'
            : 'Tratar a causa é mais importante que apenas reduzir a febre.',
        sideType: _SideNoteType.important,
        evidence: isEs
            ? 'Modelo educativo · WHO Fever Management Guidelines · UpToDate: Approach to the adult with fever · Micromedex'
            : 'Modelo educacional · OMS Manejo da Febre · UpToDate: Abordagem do adulto com febre · Micromedex',
        tags: [
          _PrescTag(
              isEs ? 'FIEBRE LEVE' : 'FEBRE LEVE', const Color(0xFF059669)),
          _PrescTag(isEs ? 'FIEBRE MODERADA' : 'FEBRE MODERADA',
              const Color(0xFFD97706)),
          _PrescTag('Adulto', const Color(0xFF6366F1)),
        ],
        items: [
          _PrescItem(
              '1.',
              isEs
                  ? 'Paracetamol 750 mg–1 g VO/IV 6/6h. Primeira escolha — seguro e eficaz.'
                  : 'Paracetamol 750 mg–1 g VO/IV 6/6h. Primeira escolha — seguro e eficaz.'),
          _PrescItem(
              '2.',
              isEs
                  ? 'Dipirona 1 g IV 6/6h (lento) se febre persistente ou mal-tolerada.'
                  : 'Dipirona 1 g IV 6/6h (lento) se febre persistente ou mal-tolerada.'),
          _PrescItem(
              '3.',
              isEs
                  ? 'Compressa morna se T > 40°C e paciente confortável.'
                  : 'Compressa morna se T >40°C e paciente confortável.'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'Investigar CAUSA — não tratar febre isoladamente sem colher culturas.'
                  : 'Investigar CAUSA — não tratar febre isoladamente sem colher culturas.'),
        ],
      ),
    ]);
  }

  Widget _buildNausea(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs
            ? 'Náuseas y Vómitos — 1ª Línea'
            : 'Náuseas e Vômitos — 1ª Linha',
        level: 'MOD',
        evidence: isEs
            ? 'Modelo educativo · UpToDate: Antiemetics — pharmacology and principles of use · Micromedex Ondansetron'
            : 'Modelo educacional · UpToDate: Antieméticos — farmacologia e uso · Micromedex Ondansetrona',
        items: [
          _PrescItem(
              '1.',
              isEs
                  ? 'Ondansetrona 4–8 mg IV lento (2–5 min) 8/8h. Primeira escolha — menos sedação.'
                  : 'Ondansetrona 4–8 mg IV lento (2–5 min) 8/8h. Primeira escolha — menos sedação.'),
          _PrescItem(
              '2.',
              isEs
                  ? 'Metoclopramida 10 mg IV 8/8h (lento em 50 mL SF, 15 min). Útil se dismotilidade gástrica.'
                  : 'Metoclopramida 10 mg IV 8/8h (lento em 50 mL SF, 15 min). Útil se dismotilidade gástrica.'),
          _PrescItem(
              '3.',
              isEs
                  ? 'Dimenidrinato 50 mg IV/VO 8/8h se náusea vestibular.'
                  : 'Dimenidrinato 50 mg IV/VO 8/8h se náusea vestibular.'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'Metoclopramida: evitar em parkinsonismo. Ondansetrona: monitorar QT.'
                  : 'Metoclopramida: evitar em parkinsonismo. Ondansetrona: monitorar QT.'),
        ],
      ),
      _PrescCard(
        title: isEs
            ? 'Vómitos Incoercibles / Quimioterapia'
            : 'Vômitos Incoercíveis / Quimioterapia',
        level: 'ALTO',
        evidence: isEs
            ? 'Modelo educativo · ASCO Antiemesis Guidelines 2020 · Lexicomp Aprepitant · UpToDate: CINV management'
            : 'Modelo educacional · ASCO Antiemese 2020 · Lexicomp Aprepitanto · UpToDate: Manejo da NVIQ',
        items: [
          _PrescItem(
              '1.',
              isEs
                  ? 'Ondansetrona 8 mg IV 8/8h + Dexametasona 8 mg IV 12/12h.'
                  : 'Ondansetrona 8 mg IV 8/8h + Dexametasona 8 mg IV 12/12h.'),
          _PrescItem(
              '2.',
              isEs
                  ? 'Aprepitanto 125 mg D1 + 80 mg D2-D3 (se disponível — antagonista NK1).'
                  : 'Aprepitanto 125 mg D1 + 80 mg D2-D3 (se disponível — antagonista NK1).'),
          _PrescItem(
              '3.',
              isEs
                  ? 'Hidratação IV se ingestão oral comprometida.'
                  : 'Hidratação IV se ingestão oral comprometida.'),
        ],
      ),
    ]);
  }

  Widget _buildInfection(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs
            ? 'ITU no Complicada (ambulatorio)'
            : 'ITU não Complicada (ambulatorial)',
        level: 'MOD',
        evidence: isEs
            ? 'Modelo educativo · IDSA UTI Guidelines 2011 (actualización 2022) · UpToDate: Uncomplicated UTI in women · Micromedex'
            : 'Modelo educacional · IDSA ITU Guidelines 2022 · UpToDate: ITU não complicada na mulher · SBI 2023',
        items: [
          _PrescItem(
              '1.ª opção',
              isEs
                  ? 'Nitrofurantoína 100 mg VO 12/12h × 5 dias (não usar em IR: ClCr <45).'
                  : 'Nitrofurantoína 100 mg VO 12/12h × 5 dias (não usar em IR: ClCr <45).'),
          _PrescItem(
              '2.ª opção',
              isEs
                  ? 'Fosfomicina 3 g VO dose única (cistite simples).'
                  : 'Fosfomicina 3 g VO dose única (cistite simples).'),
          _PrescItem(
              '3.ª opção',
              isEs
                  ? 'Ciprofloxacino 500 mg VO 12/12h × 3 dias (reservar quinolonas).'
                  : 'Ciprofloxacino 500 mg VO 12/12h × 3 dias (reservar quinolonas).'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'Amoxicilina isolada: alta resistência (>30%). Evitar sem antibiograma.'
                  : 'Amoxicilina isolada: alta resistência (>30%). Evitar sem antibiograma.'),
        ],
      ),
      _PrescCard(
        title: isEs
            ? 'ITU Complicada / Pielonefritis'
            : 'ITU Complicada / Pielonefrite',
        level: 'ALTO',
        evidence: isEs
            ? 'Modelo educativo · IDSA Pyelonephritis Guidelines · UpToDate: Acute complicated UTI in adults · Lexicomp Ceftriaxone'
            : 'Modelo educacional · IDSA Pielonefrite · UpToDate: ITU complicada no adulto · Lexicomp Ceftriaxona',
        items: [
          _PrescItem(
              'Internado IV',
              isEs
                  ? 'Ceftriaxona 1–2 g IV/dia ou Ciprofloxacino 400 mg IV 12/12h.'
                  : 'Ceftriaxona 1–2 g IV/dia ou Ciprofloxacino 400 mg IV 12/12h.'),
          _PrescItem(
              'Ambulatorial',
              isEs
                  ? 'Ciprofloxacino 500 mg VO 12/12h × 7 dias (pielonefrite leve).'
                  : 'Ciprofloxacino 500 mg VO 12/12h × 7 dias (pielonefrite leve).'),
          _PrescItem(
              'Cultura+',
              isEs
                  ? 'Aguardar antibiograma e desescalar em 48–72h.'
                  : 'Aguardar antibiograma e desescalar em 48–72h.'),
        ],
      ),
      _PrescCard(
        title: isEs
            ? 'PAC Leve–Moderada (ambulatorio)'
            : 'PAC Leve–Moderada (ambulatorial)',
        level: 'MOD',
        evidence: isEs
            ? 'Modelo educativo · ATS/IDSA CAP Guidelines 2019 · CURB-65 score · UpToDate: CAP treatment in adults'
            : 'Modelo educacional · ATS/IDSA PAC 2019 · Escore CURB-65 · UpToDate: Tratamento da PAC no adulto · SBPT',
        items: [
          _PrescItem(
              'Sem comorbidade',
              isEs
                  ? 'Amoxicilina 1 g VO 8/8h × 5 dias (pneumococo — 1ª opção).'
                  : 'Amoxicilina 1 g VO 8/8h × 5 dias (pneumococo — 1ª opção).'),
          _PrescItem(
              'Atípico suspeito',
              isEs
                  ? 'Azitromicina 500 mg/dia × 5 dias OU Doxiciclina 100 mg 12/12h × 7 dias.'
                  : 'Azitromicina 500 mg/dia × 5 dias OU Doxiciclina 100 mg 12/12h × 7 dias.'),
          _PrescItem(
              'Com comorbidade',
              isEs
                  ? 'Amox+Clav 875/125 mg 12/12h + Azitromicina × 7 dias.'
                  : 'Amox+Clav 875/125 mg 12/12h + Azitromicina × 7 dias.'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'CURB-65 ≥2 = considerar internação. ≥3 = UTI avaliação.'
                  : 'CURB-65 ≥2 = considerar internação. ≥3 = avaliar UTI.'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Celulitis / Erisipela' : 'Celulite / Erisipela',
        level: 'MOD',
        evidence: isEs
            ? 'Modelo educativo · IDSA Skin & Soft Tissue Infections 2014 · UpToDate: Cellulitis and skin abscess · Lexicomp'
            : 'Modelo educacional · IDSA Infecções de Pele 2014 · UpToDate: Celulite e abscesso · Lexicomp Cefalexina',
        items: [
          _PrescItem(
              'Leve VO',
              isEs
                  ? 'Cefalexina 500 mg VO 6/6h × 5–7 dias (estafilococo/estreptococo).'
                  : 'Cefalexina 500 mg VO 6/6h × 5–7 dias (estafilococo/estreptococo).'),
          _PrescItem(
              'Moderada IV',
              isEs
                  ? 'Oxacilina 2 g IV 4/4h ou Cefazolina 2 g IV 8/8h.'
                  : 'Oxacilina 2 g IV 4/4h ou Cefazolina 2 g IV 8/8h.'),
          _PrescItem(
              'MRSA suspeito',
              isEs
                  ? 'Vancomicina 15–20 mg/kg IV 12/12h.'
                  : 'Vancomicina 15–20 mg/kg IV 12/12h.'),
        ],
      ),
    ]);
  }

  Widget _buildHAS(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs
            ? 'HAS Estágio 1–2 (ambulatorio)'
            : 'HAS Estágio 1–2 (ambulatorial)',
        level: 'MOD',
        evidence: isEs
            ? 'Modelo educativo · ESC/ESH Hypertension Guidelines 2023 · JNC 8 · UpToDate: Choice of drug therapy in primary HTN'
            : 'Modelo educacional · ESC/ESH HAS 2023 · Diretriz Brasileira HAS 2023 · UpToDate: Escolha do anti-hipertensivo',
        items: [
          _PrescItem(
              '1.ª linha',
              isEs
                  ? 'Anlodipino 5 mg VO 1×/dia (pode titular para 10 mg).'
                  : 'Anlodipino 5 mg VO 1×/dia (pode titular para 10 mg).'),
          _PrescItem(
              'Ou',
              isEs
                  ? 'Losartana 50 mg VO 1×/dia (titular para 100 mg). Preferir em DM/proteinúria.'
                  : 'Losartana 50 mg VO 1×/dia (titular para 100 mg). Preferir em DM/proteinúria.'),
          _PrescItem(
              'Ou',
              isEs
                  ? 'Enalapril 5–10 mg VO 12/12h. Monitorar K+ e creatinina.'
                  : 'Enalapril 5–10 mg VO 12/12h. Monitorar K+ e creatinina.'),
          _PrescItem(
              'Combinação',
              isEs
                  ? 'Anlodipino + Losartana se PA não controlada com monoterapia em 4 semanas.'
                  : 'Anlodipino + Losartana se PA não controlada com monoterapia em 4 semanas.'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'IECA/ARA2: contraindicados na gravidez. Monitorar K+ com poupadores.'
                  : 'IECA/ARA2: contraindicados na gravidez. Monitorar K+ com poupadores.'),
        ],
      ),
    ]);
  }

  Widget _buildHypoK(bool isEs) {
    return Column(children: [
      _PrescCard(
        title:
            isEs ? 'Hipopotasemia — Reposición' : 'Hipopotassemia — Reposição',
        level: 'ALTO',
        evidence: isEs
            ? 'Modelo educativo · UpToDate: Clinical manifestations and treatment of hypokalemia · Micromedex KCl · Lexicomp'
            : 'Modelo educacional · UpToDate: Manifestações e tratamento da hipocalemia · Micromedex KCl · Lexicomp',
        items: [
          _PrescItem(
              'K+ 3,0–3,5',
              isEs
                  ? 'KCl 40 mEq VO (frutas, sal light) ou KCl oral 40 mEq fracionado.'
                  : 'KCl 40 mEq VO (frutas, sal light) ou KCl oral 40 mEq fracionado.'),
          _PrescItem(
              'K+ 2,5–3,0',
              isEs
                  ? 'KCl 40–60 mEq em 500 mL SF IV em 4–6h (taxa máx. 10 mEq/h periférica).'
                  : 'KCl 40–60 mEq em 500 mL SF IV em 4–6h (taxa máx. 10 mEq/h periférica).'),
          _PrescItem(
              'K+ <2,5/ECG alt.',
              isEs
                  ? 'KCl até 20–40 mEq/h em via central com monitorização ECG contínua.'
                  : 'KCl até 20–40 mEq/h em via central com monitorização ECG contínua.'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'NUNCA KCl IV direto (bolus). Sempre diluído. Verificar e repor Mg2+ junto (hipoMg perpetua hipoK).'
                  : 'NUNCA KCl IV direto (bolus). Sempre diluído. Repor Mg2+ junto (hipoMg perpetua hipoK).'),
        ],
      ),
      _PrescCard(
        title: isEs ? 'Hipomagnesemia' : 'Hipomagnesemia',
        level: 'MOD',
        items: [
          _PrescItem(
              'Reposição IV',
              isEs
                  ? 'MgSO4 2 g IV em 100 mL SF em 15–20 min. Repetir se Mg <1,5 mg/dL.'
                  : 'MgSO4 2 g IV em 100 mL SF em 15–20 min. Repetir se Mg <1,5 mg/dL.'),
          _PrescItem(
              'Manutenção VO',
              isEs
                  ? 'Óxido de Magnésio 400 mg VO 1–2×/dia.'
                  : 'Óxido de Magnésio 400 mg VO 1–2×/dia.'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'Hipomagnesemia: causa comum de hipocalemia e hipocalcemia refratária.'
                  : 'Hipomagnesemia: causa comum de hipocalemia e hipocalcemia refratária.'),
        ],
      ),
    ]);
  }

  Widget _buildSedation(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs
            ? 'Sedación/Analgesia en UTI (PADIS 2018)'
            : 'Sedação/Analgesia em UTI (PADIS 2018)',
        level: 'ALTO',
        items: [
          _PrescItem(
              isEs ? '1. Analgesia' : '1. Analgesia',
              isEs
                  ? 'Analgesia-PRIMERO: Fentanil 25–50 mcg IV PRN o Morfina 2–4 mg IV PRN.'
                  : 'Analgesia-PRIMEIRO: Fentanil 25–50 mcg IV PRN ou Morfina 2–4 mg IV PRN.'),
          _PrescItem(
              isEs ? '2. Sedación leve' : '2. Sedação leve',
              isEs
                  ? 'Meta RASS -1 a 0. Propofol 0,5–3 mg/kg/h IV O Dexmedetomidina 0,2–1,5 mcg/kg/h.'
                  : 'Meta RASS -1 a 0. Propofol 0,5–3 mg/kg/h IV OU Dexmedetomidina 0,2–1,5 mcg/kg/h.'),
          _PrescItem(
              '3. Delirium',
              isEs
                  ? 'Haloperidol 0,25–0,5 mg IV 8/8h si agitación. Orientación + luz + movilización precoz.'
                  : 'Haloperidol 0,25–0,5 mg IV 8/8h se agitação. Orientação + luz + mobilização precoce.'),
          _PrescItem(
              isEs ? 'Sedación profunda' : 'Sedação profunda',
              isEs
                  ? 'Midazolam 0,02–0,1 mg/kg/h + Fentanil 25–100 mcg/h (IOT/SDRA/status).'
                  : 'Midazolam 0,02–0,1 mg/kg/h + Fentanil 25–100 mcg/h (IOT/SARA/status).'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'Interrupción diaria de la sedación ("sedation vacation"). Evaluar RASS 4×/día.'
                  : 'Interrupção diária da sedação ("sedation vacation"). Avaliar RASS 4×/dia.'),
        ],
      ),
      _PrescCard(
        title: isEs
            ? 'Escalas RASS / BPS (referencia)'
            : 'Escalas RASS / BPS (referência)',
        level: 'MOD',
        items: [
          _PrescItem(
              'RASS',
              isEs
                  ? '+4=combativo; +1=agitado; 0=alerta; -1=somnoliento; -3=moderado; -5=no responsivo.'
                  : '+4=combativo; +1=agitado; 0=alerta; -1=sonolento; -3=moderado; -5=não responsivo.'),
          _PrescItem(
              'BPS',
              isEs
                  ? '3=sin dolor; 12=dolor máximo. Evaluación: expresión facial + extremidad + ventilación.'
                  : '3=sem dor; 12=dor máxima. Avaliação: expressão facial + membro + ventilação.'),
          _PrescItem(
              'CAM-ICU',
              isEs
                  ? 'Evalúa delirium en ventilado: 1)inicio agudo+fluctuación, 2)desatención, 3)alteración consciencia o pensamiento desorganizado.'
                  : 'Avalia delirium em ventilado: 1)início agudo+flutuação, 2)desatenção, 3)consciência alt. ou pensamento desorganizado.'),
        ],
      ),
    ]);
  }

  Widget _buildSepsis(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs
            ? 'Bundle de Sepsis — HORA 1 (SSC 2021)'
            : 'Bundle de Sepse — HORA 1 (SSC 2021)',
        level: 'ALTO',
        items: [
          _PrescItem(
              '1.',
              isEs
                  ? 'Medir lactato (repetir se >2 mmol/L).'
                  : 'Medir lactato (repetir se >2 mmol/L).'),
          _PrescItem(
              '2.',
              isEs
                  ? 'Hemocultura 2× ANTES do antibiótico.'
                  : 'Hemocultura 2× ANTES do antibiótico.'),
          _PrescItem(
              '3.',
              isEs
                  ? 'Antibiótico de amplo espectro em <1h.'
                  : 'Antibiótico de amplo espectro em <1h.'),
          _PrescItem(
              '4.',
              isEs
                  ? 'SF/RL 30 mL/kg IV em ≤3h se hipoperfusão.'
                  : 'SF/RL 30 mL/kg IV em ≤3h se hipoperfusão.'),
          _PrescItem(
              '5.',
              isEs
                  ? 'Vasopressor se PAM <65 após volume: Noradrenalina 0,1–1 µg/kg/min.'
                  : 'Vasopressor se PAM <65 após volume: Noradrenalina 0,1–1 µg/kg/min.'),
          _PrescItem(
              'ATB empírico',
              isEs
                  ? 'Pip-Tazo 4,5g IV 6/6h + Vancomicina 25 mg/kg IV (1ª dose, com infusão 1–2h).'
                  : 'Pip-Tazo 4,5g IV 6/6h + Vancomicina 25 mg/kg IV (1ª dose, infusão 1–2h).'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'Desescalar em 48–72h com cultura. Avaliar foco cirúrgico.'
                  : 'Desescalar em 48–72h com cultura. Avaliar foco cirúrgico.'),
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
          _PrescItem(
              'Internados ClCr>30',
              isEs
                  ? 'Enoxaparina 40 mg SC 1×/dia.'
                  : 'Enoxaparina 40 mg SC 1×/dia.'),
          _PrescItem(
              'Obesos >100 kg',
              isEs
                  ? 'Enoxaparina 40 mg SC 12/12h ou 0,5 mg/kg/dia.'
                  : 'Enoxaparina 40 mg SC 12/12h ou 0,5 mg/kg/dia.'),
          _PrescItem(
              'ClCr <30',
              isEs
                  ? 'HNF 5000 UI SC 8/8h (preferir em IR grave).'
                  : 'HNF 5000 UI SC 8/8h (preferir em IR grave).'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'Contraindicada: sangramento ativo, plaquetas <50k, cirurgia SNC recente.'
                  : 'Contraindicada: sangramento ativo, plaquetas <50k, cirurgia SNC recente.'),
        ],
      ),
      _PrescCard(
        title:
            isEs ? 'Anticoagulación FA (inicio)' : 'Anticoagulação FA (início)',
        level: 'MOD',
        items: [
          _PrescItem(
              'CHA2DS2 ≥2 (H) / ≥3 (M)',
              isEs
                  ? 'Indicação formal de anticoagulação.'
                  : 'Indicação formal de anticoagulação.'),
          _PrescItem(
              '1.ª opção',
              isEs
                  ? 'Rivaroxabana 20 mg 1×/dia (com jantar). ClCr 15–49: 15 mg/dia.'
                  : 'Rivaroxabana 20 mg 1×/dia (com jantar). ClCr 15–49: 15 mg/dia.'),
          _PrescItem(
              'Alternativa',
              isEs
                  ? 'Apixabana 5 mg 12/12h. Reduzir para 2,5 mg se ≥2: idade≥80/peso≤60/Cr≥1,5.'
                  : 'Apixabana 5 mg 12/12h. Reduzir para 2,5 mg se ≥2: idade≥80/peso≤60/Cr≥1,5.'),
          _PrescItem(
              'Valvar/mecânica',
              isEs
                  ? 'Warfarina (alvo INR 2–3 ou 2,5–3,5 mecânica). DOAC contraindicado.'
                  : 'Warfarina (alvo INR 2–3 ou 2,5–3,5 mecânica). DOAC contraindicado.'),
        ],
      ),
    ]);
  }

  Widget _buildHypertensiveEmergency(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs
            ? 'Emergencia Hipertensiva — UTI'
            : 'Emergência Hipertensiva — UTI',
        level: 'ALTO',
        items: [
          _PrescItem(
              'Meta geral',
              isEs
                  ? 'Reduzir PAM 20–25% nas primeiras 1–2h. NÃO normalizar abruptamente.'
                  : 'Reduzir PAM 20–25% nas primeiras 1–2h. NÃO normalizar abruptamente.'),
          _PrescItem(
              'EAP/encef.',
              isEs
                  ? 'Nitroprussiato 0,5–10 µg/kg/min IV (titular) OU Nicardipino 5–15 mg/h IV.'
                  : 'Nitroprussiato 0,5–10 µg/kg/min IV (titular) OU Nicardipino 5–15 mg/h IV.'),
          _PrescItem(
              'Disseção Ao.',
              isEs
                  ? 'Esmolol 500 mcg/kg IV + 50–200 mcg/kg/min + Nitroprussiato. Meta PAS ≤120.'
                  : 'Esmolol 500 mcg/kg IV + 50–200 mcg/kg/min + Nitroprussiato. Meta PAS ≤120.'),
          _PrescItem(
              'Eclâmpsia',
              isEs
                  ? 'Hidralazina 5–10 mg IV 20 min + MgSO4 4–6 g IV (ver protocolo pré-ecl.).'
                  : 'Hidralazina 5–10 mg IV 20 min + MgSO4 4–6 g IV (ver protocolo pré-ecl.).'),
          _PrescItem(
              'Contra.',
              isEs
                  ? 'NUNCA nifedipino sublingual — queda abrupta e imprevisível → isquemia.'
                  : 'NUNCA nifedipino sublingual — queda abrupta e imprevisível → isquemia.'),
        ],
      ),
    ]);
  }

  Widget _buildDyspnea(bool isEs) {
    return Column(children: [
      _PrescCard(
        title: isEs
            ? 'Dispnea Aguda — Algoritmo Rápido'
            : 'Dispneia Aguda — Algoritmo Rápido',
        level: 'ALTO',
        items: [
          _PrescItem(
              'ABCDE',
              isEs
                  ? 'Posição sentada, O2 por máscara (Venturi 35–50% se DPOC: máx. SpO2 88–92%).'
                  : 'Posição sentada, O2 por máscara (Venturi 35–50% se DPOC: máx. SpO2 88–92%).'),
          _PrescItem(
              'EAP',
              isEs
                  ? 'Furosemida 40–80 mg IV + NTG 5–10 µg/min IV + VNI (CPAP ≥5 cmH2O).'
                  : 'Furosemida 40–80 mg IV + NTG 5–10 µg/min IV + VNI (CPAP ≥5 cmH2O).'),
          _PrescItem(
              'Broncoespasmo',
              isEs
                  ? 'Salbutamol 2,5 mg NEB a cada 20 min × 3 + Ipratrópio 0,5 mg NEB + MgSO4 2g IV.'
                  : 'Salbutamol 2,5 mg NEB a cada 20 min × 3 + Ipratrópio 0,5 mg NEB + MgSO4 2g IV.'),
          _PrescItem(
              'DPOC exacerb.',
              isEs
                  ? 'Broncodilatadores + Prednisona 40 mg/dia × 5d + ATB (azitro/amox-clav) se infecção.'
                  : 'Broncodilatadores + Prednisona 40 mg/dia × 5d + ATB (azitro/amox-clav) se infecção.'),
          _PrescItem(
              'TEP',
              isEs
                  ? 'Anticoagulação imediata (enoxaparina ou rivaroxabana). Trombólise se instável.'
                  : 'Anticoagulação imediata (enoxaparina ou rivaroxabana). Trombólise se instável.'),
          _PrescItem(
              'Aten.',
              isEs
                  ? 'O2 alvo: SpO2 94–98% (geral) OU 88–92% (DPOC/hipoxemia crônica).'
                  : 'O2 alvo: SpO2 94–98% (geral) OU 88–92% (DPOC/hipoxemia crônica).'),
        ],
      ),
      _PrescCard(
        title: isEs
            ? 'VNI — Indicaciones y Configuración'
            : 'VNI — Indicações e Configuração',
        level: 'MOD',
        items: [
          _PrescItem(
              'Indicações',
              isEs
                  ? 'EAP cardiogênico, DPOC exacerbação, hipoxemia leve-mod (SpO2 <92% com O2 convencional).'
                  : 'EAP cardiogênico, DPOC exacerbação, hipoxemia leve-mod (SpO2 <92% com O2 convencional).'),
          _PrescItem(
              'Início CPAP',
              isEs
                  ? 'CPAP 5–8 cmH2O + FiO2 40–60%. Reavaliação em 30–60 min.'
                  : 'CPAP 5–8 cmH2O + FiO2 40–60%. Reavaliação em 30–60 min.'),
          _PrescItem(
              'BiPAP',
              isEs
                  ? 'IPAP 12–20 / EPAP 4–8 cmH2O. FR backup 12–16/min.'
                  : 'IPAP 12–20 / EPAP 4–8 cmH2O. FR backup 12–16/min.'),
          _PrescItem(
              'Contra.',
              isEs
                  ? 'Parada respiratória, incapacidade de proteger VA, vômitos, agitação severa, politrauma facial.'
                  : 'Parada respiratória, incapacidade de proteger VA, vômitos, agitação severa, politrauma facial.'),
        ],
      ),
    ]);
  }
}

/// Card de Prescrição — redesign premium com numeração visual, painel lateral e badges
class _PrescCard extends StatelessWidget {
  final String title, level;
  final List<_PrescItem> items;

  /// Texto do badge top-right (ex: '1ª Elección', 'Uso cuidadoso')
  final String? badge;

  /// Nota lateral (ex: 'Claves rápidas', 'Precaución')
  final String? sideTitle;
  final String? sideBody;
  final _SideNoteType sideType;

  /// Tags coloridas no rodapé
  final List<_PrescTag>? tags;

  /// Referência bibliográfica no rodapé (opcional — usa padrão da categoria se null)
  final String? evidence;

  const _PrescCard({
    required this.title,
    required this.level,
    required this.items,
    this.badge,
    this.sideTitle,
    this.sideBody,
    this.sideType = _SideNoteType.info,
    this.tags,
    this.evidence,
  });

  Color get _levelColor => level == 'ALTO'
      ? const Color(0xFFDC2626)
      : level == 'MOD'
          ? const Color(0xFFD97706)
          : const Color(0xFF059669);

  Color get _levelBg => level == 'ALTO'
      ? const Color(0xFFDC2626).withOpacity(0.10)
      : level == 'MOD'
          ? const Color(0xFFD97706).withOpacity(0.10)
          : const Color(0xFF059669).withOpacity(0.10);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hasSide = sideTitle != null && sideBody != null;
    final hasTags = tags != null && tags!.isNotEmpty;
    final isAlto = level == 'ALTO';

    // Separar itens numerados vs "Aten." vs "Contra."
    final steps = items.where((i) => !_isSpecial(i.step)).toList();
    final specials = items.where((i) => _isSpecial(i.step)).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                isAlto ? const Color(0xFFDC2626).withOpacity(0.20) : c.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header colorido ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: isAlto
                ? const Color(0xFFDC2626).withOpacity(0.04)
                : const Color(0xFFD97706).withOpacity(0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
                bottom: BorderSide(
                    color: isAlto
                        ? const Color(0xFFDC2626).withOpacity(0.12)
                        : const Color(0xFFD97706).withOpacity(0.12))),
          ),
          child: Row(children: [
            // Level badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _levelBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(level,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: _levelColor)),
            ),
            const SizedBox(width: 10),
            // Título
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: c.textPrimary,
                        letterSpacing: -0.3))),
            // Badge top-right
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isAlto
                          ? const Color(0xFFDC2626).withOpacity(0.4)
                          : c.border),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isAlto
                            ? const Color(0xFFDC2626)
                            : c.textSecondary)),
              ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Steps sempre full-width
            _buildSteps(context, steps, specials, c),
            // SideNote abaixo dos steps, full-width compacto
            if (hasSide) ...[
              const SizedBox(height: 10),
              _PrescSideNote(
                title: sideTitle!,
                body: sideBody!,
                type: sideType,
                fullWidth: true,
              ),
            ],
          ]),
        ),

        // ── Tags de rodapé ──────────────────────────────────────
        if (hasTags)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags!.map((t) => _PrescTagChip(tag: t)).toList()),
          ),

        // ── Linha de evidência bibliográfica ────────────────────
        _PrescEvidenceFooter(evidence: evidence, c: c),
      ]),
    );
  }

  bool _isSpecial(String step) =>
      step.startsWith('Aten') ||
      step.startsWith('Contra') ||
      step.startsWith('⚠') ||
      step.startsWith('!');

  Widget _buildSteps(BuildContext context, List<_PrescItem> steps,
      List<_PrescItem> specials, AppColors c) {
    int stepNum = 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...steps.map((item) {
        // Detectar se é numerado (começa com dígito ou "1." etc.) ou label
        final isNum = RegExp(r'^\d').hasMatch(item.step);
        if (isNum) stepNum++;
        final numToShow = isNum ? stepNum : null;
        return _PrescStepRow(
            item: item, stepNum: numToShow, isAlto: level == 'ALTO');
      }),
      if (specials.isNotEmpty) const SizedBox(height: 4),
      ...specials.map((item) => _PrescAttenRow(item: item)),
    ]);
  }
}

enum _SideNoteType { info, warning, important }

// ─────────────────────────────────────────────────────────────────────────────
// RODAPÉ DE EVIDÊNCIA — linha bibliográfica em cada _PrescCard
// ─────────────────────────────────────────────────────────────────────────────
class _PrescEvidenceFooter extends StatelessWidget {
  final String? evidence;
  final AppColors c;
  const _PrescEvidenceFooter({required this.evidence, required this.c});

  // Referência padrão quando o card não passa evidência explícita
  static const _defaultEvidence =
      'Modelo educativo · Basado en UpToDate / Micromedex / Lexicomp / Diretrizes institucionais';

  @override
  Widget build(BuildContext context) {
    final ref = evidence ?? _defaultEvidence;
    final dark = c.dark;
    final lineCol = dark ? const Color(0xFF1E2E24) : const Color(0xFFE8F0EA);
    final textCol = dark ? const Color(0xFF4A7A5A) : const Color(0xFF7A9B82);
    final iconCol = dark ? const Color(0xFF3A6A4A) : const Color(0xFF9AB89F);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 0, 0),
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: lineCol, width: 1)),
      ),
      child: Row(children: [
        Icon(Icons.menu_book_rounded, size: 11, color: iconCol),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            ref,
            style: TextStyle(
              fontSize: 9.5,
              color: textCol,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
              height: 1.3,
            ),
          ),
        ),
      ]),
    );
  }
}

class _PrescItem {
  final String step, desc;
  const _PrescItem(this.step, this.desc);
}

class _PrescTag {
  final String label;
  final Color color;
  const _PrescTag(this.label, this.color);
}

/// Linha numerada ou com label — suporte a círculo colorido
class _PrescStepRow extends StatelessWidget {
  final _PrescItem item;
  final int? stepNum;
  final bool isAlto;
  const _PrescStepRow({required this.item, this.stepNum, this.isAlto = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final circleColor =
        isAlto ? const Color(0xFFDC2626) : const Color(0xFF059669);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Número circular OU label step
        if (stepNum != null)
          Container(
            width: 22,
            height: 22,
            decoration:
                BoxDecoration(color: circleColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$stepNum',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(item.step,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                    letterSpacing: 0.5)),
          ),
        const SizedBox(width: 10),
        Expanded(
            child: Padding(
          padding: EdgeInsets.only(top: stepNum != null ? 3 : 1),
          child: Text(item.desc,
              style: TextStyle(
                  fontSize: 12.5, color: c.textSecondary, height: 1.45)),
        )),
      ]),
    );
  }
}

/// Linha de atenção/contraindicação com ícone de alerta
class _PrescAttenRow extends StatelessWidget {
  final _PrescItem item;
  const _PrescAttenRow({required this.item});

  bool get _isContra => item.step.toLowerCase().startsWith('contra');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isContra = _isContra;
    final bgColor =
        isContra ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final bgFill = bgColor.withOpacity(0.07);
    final border = bgColor.withOpacity(0.20);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgFill,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isContra ? Icons.block_rounded : Icons.warning_amber_rounded,
            size: 14, color: bgColor),
        const SizedBox(width: 7),
        Container(
          margin: const EdgeInsets.only(right: 6, top: 1),
          child: Text(item.step,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: bgColor,
                  letterSpacing: 0.3)),
        ),
        Expanded(
            child: Text(item.desc,
                style: TextStyle(
                    fontSize: 11.5, color: c.textSecondary, height: 1.4))),
      ]),
    );
  }
}

/// Painel lateral com nota clínica (Claves rápidas, Precaución, Importante)
class _PrescSideNote extends StatelessWidget {
  final String title, body;
  final _SideNoteType type;
  final bool fullWidth;
  const _PrescSideNote(
      {required this.title,
      required this.body,
      required this.type,
      this.fullWidth = false});

  Color get _accent {
    switch (type) {
      case _SideNoteType.warning:
        return const Color(0xFFDC2626);
      case _SideNoteType.important:
        return const Color(0xFFD97706);
      case _SideNoteType.info:
        return const Color(0xFF059669);
    }
  }

  IconData get _icon {
    switch (type) {
      case _SideNoteType.warning:
        return Icons.warning_amber_rounded;
      case _SideNoteType.important:
        return Icons.lightbulb_outline_rounded;
      case _SideNoteType.info:
        return Icons.tips_and_updates_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = _accent;

    // fullWidth: layout horizontal compacto (ícone + título | corpo)
    if (fullWidth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(0.18)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_icon, size: 13, color: accent),
          const SizedBox(width: 7),
          Expanded(
              child: RichText(
            text: TextSpan(children: [
              TextSpan(
                text: '$title  ',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: accent),
              ),
              TextSpan(
                text: body,
                style: TextStyle(
                    fontSize: 11,
                    color: c.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w400),
              ),
            ]),
          )),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.20)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent))),
        ]),
        const SizedBox(height: 7),
        Text(body,
            style:
                TextStyle(fontSize: 11, color: c.textSecondary, height: 1.4)),
      ]),
    );
  }
}

/// Tag colorida de rodapé do card
class _PrescTagChip extends StatelessWidget {
  final _PrescTag tag;
  const _PrescTagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tag.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tag.color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: tag.color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(tag.label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: tag.color)),
      ]),
    );
  }
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
  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.child,
      this.badge,
      this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return StandardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.of(context).darkBtn),
            child: Icon(icon, size: 16, color: kToolGold),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.of(context).textPrimary,
                      letterSpacing: -0.3))),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: badgeColor ?? kToolGreen),
              child: Text(badge!,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
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
  const _LabeledInput(
      {required this.label,
      required this.ctrl,
      required this.onChanged,
      required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.of(context).textHint)),
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

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 331 — SELETOR QUÁDRUPLO PEDIATRIA (BIOMETRIA|SCHWARTZ|PEWS|REFERÊNCIA)
// Desacoplado do gradiente verde — sobre fundo nativo sólido do corpo.
// Cores adaptativas: dark → branco/branco60; light → preto/preto45.
// ─────────────────────────────────────────────────────────────────────────────
// MEDCASES_PEDS_VISUAL_REBALANCE_V1_C_R3
// MEDCASES_PEDIATRIA_CANONICAL_SUPERBUILD_V1_B_R0_R4_TRANSACTIONAL
// MEDCASES_PEDIATRIA_FINAL_GAP_0_5PX_DIVIDER_CLEANUP_V1_B_R0_R1_TRANSACTIONAL
// MEDCASES_PEDIATRIA_LIGHT_SURFACE_CONTRAST_FINAL_V1_B_R0_TRANSACTIONAL
// MEDCASES_PEDIATRIA_SECTION_CARDS_FINAL_V1_B_R0_TRANSACTIONAL
// MEDCASES_PEDIATRIA_FINAL_TYPE_SCALE_CARD_GEOMETRY_V1_B_R0_TRANSACTIONAL
// MEDCASES_PEDIATRIA_PREMIUM_SECTION_SPACING_HIERARCHY_V1_B_R0_R1_TRANSACTIONAL
// MEDCASES_PEDIATRIA_FINAL_FIRST_CARD_TITLE_REFERENCES_V1_B_R0_R2_TRANSACTIONAL
// MEDCASES_PEDIATRIA_FINAL_SCROLLABLE_SUBNAV_WHITE_TITLES_V1_B_R0_R5_UNTRACKED_SCOPE_EXCLUSION_FIX_TRANSACTIONAL
// Escala visual local: corrige apenas a densidade do subgrafo pediátrico.
class _PediatricsVisualScaleR3 {
  const _PediatricsVisualScaleR3._();

  static const double tabLabel = 12.0;

  // Premium hierarchy: card title > clinical result/input > body/options >
  // field label > PEWS subgroup > source/micro.
  static const double sectionTitle = 14.0;
  static const double sectionLabel = 13.0;
  static const double subsectionTitle = 12.5;
  static const double body = 14.5;
  static const double micro = 11.5;
  static const double inputText = 15.5;
  static const double hint = 14.0;
  static const double option = 14.5;
  static const double result = 15.5;
}

class _PediatTabRow extends StatelessWidget {
  final bool dark;
  final List<String> sections;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  const _PediatTabRow({
    required this.dark,
    required this.sections,
    required this.activeIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final surface = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE7EBEF);
    final activeColor =
        dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);
    final inactiveColor =
        dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final activeBackground = dark
        ? const Color(0xFF0D6B57).withValues(alpha: 0.10)
        : const Color(0xFF0D6B57).withValues(alpha: 0.06);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: divider, width: 0.7),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  constraints: const BoxConstraints(minWidth: 112),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: activeIndex == i
                        ? activeBackground
                        : Colors.transparent,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          sections[i],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _PediatricsVisualScaleR3.tabLabel,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color:
                                activeIndex == i ? activeColor : inactiveColor,
                            letterSpacing: 0.05,
                          ),
                        ),
                      ),
                      if (activeIndex == i)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 9,
                          child: Container(
                            height: 2,
                            color: const Color(0xFF0D6B57),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (i < sections.length - 1)
                SizedBox(
                  width: 0.7,
                  height: 40,
                  child: Center(
                    child: Container(
                      width: 0.7,
                      height: 20,
                      color: divider,
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

  static const int _biometrySection = 0;
  static const int _growthSection = 1;
  static const int _renalSection = 2;
  static const int _pewsSection = 3;

  List<String> _sectionLabels(bool isEs) => isEs
      ? const ['BIOMETRÍA', 'CRECIMIENTO', 'FUNCIÓN RENAL', 'PEWS']
      : const ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS'];

  // ── Controllers ────────────────────────────────────────────────
  // Biometria
  final _ageYCtrl = TextEditingController(); // anos
  final _ageMCtrl = TextEditingController(); // meses
  final _weightCtrl = TextEditingController(); // peso real
  final _heightCtrl = TextEditingController(); // altura cm

  // Função renal
  final _swCrCtrl = TextEditingController();

  // Crescimento WHO
  PediatricBiologicalSex _growthSex = PediatricBiologicalSex.male;
  PediatricGrowthIndicator _growthIndicator =
      PediatricGrowthIndicator.weightForAge;

  // Brighton PEWS
  int _pewsBehavior = 0;
  int _pewsCardio = 0;
  int _pewsRespiratory = 0;
  bool _pewsQuarterHourlyNebulizer = false;
  bool _pewsPersistentPostOpVomiting = false;

  // Doses — peso local (editável direto na aba, sincronizado com _weightCtrl)
  final _dosesWeightCtrl = TextEditingController();

  @override
  void dispose() {
    _ageYCtrl.dispose();
    _ageMCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _swCrCtrl.dispose();
    _dosesWeightCtrl.dispose();
    super.dispose();
  }

  double? _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.'));
  String _fmt(double? v, {int dec = 1}) {
    if (v == null || !v.isFinite) return '—';
    if (v >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(dec).replaceAll('.', ',');
  }

  // ── Antropometria / crescimento WHO ──────────────────────────────
  int? get _ageMonths {
    final y = _n(_ageYCtrl);
    final m = _n(_ageMCtrl) ?? 0;
    if (y == null || y < 0 || m < 0 || m >= 12) return null;
    final total = (y.round() * 12) + m.round();
    if (total < 0 || total > 228) return null;
    return total;
  }

  // LEGACY HIDDEN-DOSES COMPATIBILITY ONLY.
  // _buildDoses() remains intentionally inaccessible in the visible
  // Pediatrics navigation, but its previous fallback depends on _estWeight.
  // Keep the exact historical helper so V1-B does not mutate/disable that
  // protected dormant code path. It is NOT used for WHO percentiles/P50.
  double? get _estWeight {
    final y = _n(_ageYCtrl);
    final m = _n(_ageMCtrl) ?? 0;
    if (y == null) return null;
    final totalMonths = y * 12 + m;
    if (totalMonths < 1) return null;
    if (totalMonths < 12) return (totalMonths / 2) + 4;
    final years = totalMonths / 12;
    if (years <= 10) return (years + 4) * 2;
    return 3 * years + 7;
  }

  double? get _bmi {
    final w = _n(_weightCtrl), h = _n(_heightCtrl);
    if (w == null || h == null || h <= 0) return null;
    return PediatricGrowthEngineV2026.bmi(
      weightKg: w,
      heightCm: h,
    );
  }

  double? get _bsa {
    final w = _n(_weightCtrl);
    final h = _n(_heightCtrl);
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return _sqrt((w * h) / 3600);
  }

  double? get _whoP50Weight {
    final months = _ageMonths;
    if (months == null) return null;
    return PediatricGrowthEngineV2026.referenceValueForIndicatorAtZ(
      indicator: PediatricGrowthIndicator.weightForAge,
      sex: _growthSex,
      ageMonths: months,
      z: 0,
    );
  }

  // ── Sinais vitais — Resuscitation Council UK 2025 ───────────────
  static const _vitalAgeMonths = <double>[1, 12, 24, 60, 120, 216];

  double _interpVital(double ageMonths, List<double> values) {
    if (ageMonths <= _vitalAgeMonths.first) return values.first;
    if (ageMonths >= _vitalAgeMonths.last) return values.last;
    for (var i = 0; i < _vitalAgeMonths.length - 1; i++) {
      final a0 = _vitalAgeMonths[i];
      final a1 = _vitalAgeMonths[i + 1];
      if (ageMonths >= a0 && ageMonths <= a1) {
        final t = (ageMonths - a0) / (a1 - a0);
        return values[i] + (values[i + 1] - values[i]) * t;
      }
    }
    return values.last;
  }

  double _vitalMonths(double? y, double? m) =>
      (((y ?? 0) * 12) + (m ?? 0)).clamp(1, 216).toDouble();

  String _hrNormal(double? y, double? m) {
    final age = _vitalMonths(y, m);
    final low = _interpVital(age, const [110, 100, 90, 70, 60, 60]).round();
    final high =
        _interpVital(age, const [180, 170, 160, 140, 120, 100]).round();
    return '$low–$high bpm';
  }

  String _rrNormal(double? y, double? m) {
    final age = _vitalMonths(y, m);
    final low = _interpVital(age, const [25, 20, 18, 17, 14, 12]).round();
    final high = _interpVital(age, const [60, 50, 40, 30, 25, 20]).round();
    return '$low–$high irpm';
  }

  String _pasSystNormal(double? y, double? m) {
    final age = _vitalMonths(y, m);
    final p50 = _interpVital(age, const [75, 95, 98, 100, 110, 120]).round();
    return 'P50 ≈ $p50 mmHg';
  }

  String _minPas(double? y, double? m) {
    final age = _vitalMonths(y, m);
    final p5 = _interpVital(age, const [50, 70, 73, 75, 80, 90]).round();
    return 'P5 ≈ $p5 mmHg';
  }

  // ── Função renal ────────────────────────────────────────────────
  double? get _egfrU25 {
    final ageMonths = _ageMonths;
    final h = _n(_heightCtrl);
    final cr = _n(_swCrCtrl);
    if (ageMonths == null || h == null || cr == null) return null;
    return PediatricRenalEngineV2026.ckidU25Creatinine(
      sex: _growthSex,
      ageYears: ageMonths / 12,
      heightCm: h,
      creatinineMgDl: cr,
    );
  }

  double? get _egfrBedside2009 {
    final h = _n(_heightCtrl);
    final cr = _n(_swCrCtrl);
    if (h == null || cr == null) return null;
    return PediatricRenalEngineV2026.ckidBedside2009(
      heightCm: h,
      creatinineMgDl: cr,
    );
  }

  // ── PEWS ────────────────────────────────────────────────────────
  BrightonPewsResultV2026 get _pewsResult => BrightonPewsEngineV2026.calculate(
        behavior: _pewsBehavior,
        cardiovascular: _pewsCardio,
        respiratory: _pewsRespiratory,
        quarterHourlyNebulizer: _pewsQuarterHourlyNebulizer,
        persistentPostOpVomiting: _pewsPersistentPostOpVomiting,
      );

  int get _pewsTotal => _pewsResult.total;

  Color _pewsColor(int score) {
    if (score <= 1) return const Color(0xFF059669);
    if (score <= 3) return const Color(0xFFD97706);
    if (score <= 5) return const Color(0xFFDC2626);
    return const Color(0xFF991B1B);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final c = AppColors.of(context);
    final sections = _sectionLabels(isEs);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: ColoredBox(
        color: p.darkMode ? const Color(0xFF1A1D23) : const Color(0xFFE7ECEF),
        child: Column(
          children: [
            const SizedBox(height: 0),
            _PediatTabRow(
              dark: p.darkMode,
              sections: sections,
              activeIndex: _section,
              onSelect: (i) {
                AppHaptics.selection(context);
                setState(() => _section = i);
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0.5, 0.1, 0.5, 100),
                child: _buildSection(isEs, c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(bool isEs, AppColors c) {
    switch (_section) {
      case _biometrySection:
        return _buildBiometria(isEs, c);
      case _growthSection:
        return _buildGrowth(isEs, c);
      case _renalSection:
        return _buildRenal(isEs, c);
      case _pewsSection:
        return _buildPews(isEs, c);
      default:
        return const SizedBox.shrink();
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SEÇÃO 1 — BIOMETRIA PEDIÁTRICA
  // ──────────────────────────────────────────────────────────────
  Widget _buildBiometria(bool isEs, AppColors c) {
    final ageY = _n(_ageYCtrl);
    final ageM = _n(_ageMCtrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PedFlatSection(
          quietHeader: true,
          title: isEs ? 'Edad y sexo biológico' : 'Idade e sexo biológico',
          icon: Icons.child_care_rounded,
          child: Column(
            children: [
              _PedSexSelector(
                isEs: isEs,
                dark: c.dark,
                value: _growthSex,
                onChanged: (value) => setState(() => _growthSex = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Años' : 'Anos',
                      ctrl: _ageYCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 5' : 'Ex. 5',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Meses adicionales' : 'Meses adicionais',
                      ctrl: _ageMCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 0' : 'Ex. 0',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _PedSectionGap(),
        _PedFlatSection(
          quietHeader: true,
          title: isEs ? 'Antropometría' : 'Antropometria',
          icon: Icons.straighten_rounded,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Peso (kg)' : 'Peso (kg)',
                      ctrl: _weightCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 20' : 'Ex. 20',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Talla (cm)' : 'Altura (cm)',
                      ctrl: _heightCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 110' : 'Ex. 110',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PedMetricRow(
                label: isEs
                    ? 'Peso P50 WHO para edad/sexo'
                    : 'Peso P50 WHO para idade/sexo',
                value: _fmt(_whoP50Weight),
                unit: 'kg',
                accent: const Color(0xFF10B981),
              ),
              _PedMetricRow(
                label: 'IMC',
                value: _fmt(_bmi),
                unit: 'kg/m²',
                accent: const Color(0xFF2563EB),
              ),
              _PedMetricRow(
                label: isEs
                    ? 'Superficie corporal (Mosteller)'
                    : 'Superfície corporal (Mosteller)',
                value: _fmt(_bsa, dec: 2),
                unit: 'm²',
                accent: const Color(0xFF7C3AED),
                last: true,
              ),
              const SizedBox(height: 10),
              _PedSourceNote(
                isEs: isEs,
                text: isEs
                    ? 'Crecimiento: WHO Child Growth Standards / WHO Growth Reference 2007. Superficie corporal: Mosteller RD, NEJM 1987. Revisión MedCases 2026.'
                    : 'Crescimento: WHO Child Growth Standards / WHO Growth Reference 2007. Superfície corporal: Mosteller RD, NEJM 1987. Revisão MedCases 2026.',
              ),
            ],
          ),
        ),
        _PedSectionGap(),
        _PedFlatSection(
          quietHeader: true,
          title: isEs
              ? 'Signos vitales de referencia'
              : 'Sinais vitais de referência',
          icon: Icons.monitor_heart_rounded,
          child: Column(
            children: [
              _PedVitalRow(
                label: 'FC',
                value: _hrNormal(ageY, ageM),
                icon: Icons.favorite_rounded,
                color: const Color(0xFFDC2626),
              ),
              _PedVitalRow(
                label: 'FR',
                value: _rrNormal(ageY, ageM),
                icon: Icons.air_rounded,
                color: const Color(0xFF2563EB),
              ),
              _PedVitalRow(
                label: isEs ? 'PAS de referencia' : 'PAS de referência',
                value: _pasSystNormal(ageY, ageM),
                icon: Icons.speed_rounded,
                color: const Color(0xFF059669),
              ),
              _PedVitalRow(
                label: isEs ? 'PAS — percentil 5' : 'PAS — percentil 5',
                value: _minPas(ageY, ageM),
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFD97706),
                last: true,
              ),
              const SizedBox(height: 10),
              _PedSourceNote(
                isEs: isEs,
                text: isEs
                    ? 'Resuscitation Council UK, Paediatric Life Support 2025, Tabla 1. Valores aproximados; se interpolan entre edades de referencia.'
                    : 'Resuscitation Council UK, Paediatric Life Support 2025, Tabela 1. Valores aproximados; interpolação entre idades de referência.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // SEÇÃO 2 — CRESCIMENTO WHO + FUNÇÃO RENAL (TFG pediátrica)
  // ──────────────────────────────────────────────────────────────
  Widget _buildGrowth(bool isEs, AppColors c) {
    final ageMonths = _ageMonths;
    final weight = _n(_weightCtrl);
    final height = _n(_heightCtrl);

    PediatricGrowthAssessmentV2026? assessment;
    double? patientValue;

    if (ageMonths != null) {
      switch (_growthIndicator) {
        case PediatricGrowthIndicator.weightForAge:
          patientValue = weight;
          if (weight != null) {
            assessment = PediatricGrowthEngineV2026.weightForAge(
              sex: _growthSex,
              ageMonths: ageMonths,
              weightKg: weight,
            );
          }
        case PediatricGrowthIndicator.heightForAge:
          patientValue = height;
          if (height != null) {
            assessment = PediatricGrowthEngineV2026.heightForAge(
              sex: _growthSex,
              ageMonths: ageMonths,
              heightCm: height,
            );
          }
        case PediatricGrowthIndicator.bmiForAge:
          if (weight != null && height != null) {
            patientValue = PediatricGrowthEngineV2026.bmi(
              weightKg: weight,
              heightCm: height,
            );
            assessment = PediatricGrowthEngineV2026.bmiForAge(
              sex: _growthSex,
              ageMonths: ageMonths,
              weightKg: weight,
              heightCm: height,
            );
          }
      }
    }

    final sourceName = assessment?.reference ==
            PediatricGrowthReference.whoChildGrowthStandards2006
        ? 'WHO Child Growth Standards'
        : 'WHO Growth Reference 2007';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PedFlatSection(
          quietHeader: true,
          title: isEs ? 'Datos para crecimiento' : 'Dados para crescimento',
          icon: Icons.child_friendly_rounded,
          child: Column(
            children: [
              _PedSexSelector(
                isEs: isEs,
                dark: c.dark,
                value: _growthSex,
                onChanged: (value) => setState(() => _growthSex = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Años' : 'Anos',
                      ctrl: _ageYCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 5' : 'Ex. 5',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Meses' : 'Meses',
                      ctrl: _ageMCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 0' : 'Ex. 0',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Peso (kg)' : 'Peso (kg)',
                      ctrl: _weightCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 20' : 'Ex. 20',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Talla (cm)' : 'Altura (cm)',
                      ctrl: _heightCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 110' : 'Ex. 110',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _PedSectionGap(),
        _PedFlatSection(
          quietHeader: true,
          title: isEs ? 'Curva de crecimiento WHO' : 'Curva de crescimento WHO',
          icon: Icons.show_chart_rounded,
          child: Column(
            children: [
              _PedGrowthIndicatorToggle(
                isEs: isEs,
                value: _growthIndicator,
                onChanged: (value) => setState(() => _growthIndicator = value),
              ),
              const SizedBox(height: 12),
              if (assessment != null && patientValue != null) ...[
                SizedBox(
                  height: 230,
                  width: double.infinity,
                  child: _PedGrowthChart(
                    indicator: _growthIndicator,
                    sex: _growthSex,
                    patientAgeMonths: ageMonths!,
                    patientValue: patientValue,
                    dark: c.dark,
                  ),
                ),
                const SizedBox(height: 12),
                _PedMetricRow(
                  label: isEs ? 'Percentil estimado' : 'Percentil estimado',
                  value: 'P${assessment.percentile.round()}',
                  unit: '',
                  accent: const Color(0xFF10B981),
                ),
                _PedMetricRow(
                  label: 'Z-score',
                  value: assessment.zScore.toStringAsFixed(2),
                  unit: 'DP',
                  accent: const Color(0xFF2563EB),
                ),
                _PedMetricRow(
                  label: 'P50',
                  value: _fmt(assessment.p50, dec: 2),
                  unit: assessment.unit,
                  accent: const Color(0xFF7C3AED),
                ),
                _PedMetricRow(
                  label: isEs ? 'Interpretación' : 'Interpretação',
                  value: isEs
                      ? assessment.interpretationEs
                      : assessment.interpretationPt,
                  unit: '',
                  accent: const Color(0xFF475569),
                  last: true,
                  valueSmall: true,
                ),
                const SizedBox(height: 10),
                _PedSourceNote(
                  isEs: isEs,
                  text:
                      '$sourceName · LMS oficial WHO · revisión MedCases ${PediatricReferenceRegistryV2026.reviewDate}.',
                ),
              ] else ...[
                _PedSourceNote(
                  isEs: isEs,
                  text: _growthIndicator ==
                              PediatricGrowthIndicator.weightForAge &&
                          ageMonths != null &&
                          ageMonths > 120
                      ? (isEs
                          ? 'WHO peso/edad se utiliza hasta 10 años. Para mayores, use talla/edad o IMC/edad.'
                          : 'WHO peso/idade é utilizado até 10 anos. Para maiores, use altura/idade ou IMC/idade.')
                      : (isEs
                          ? 'Complete edad, sexo, peso y/o talla para calcular el percentil y dibujar la curva.'
                          : 'Preencha idade, sexo, peso e/ou altura para calcular o percentil e desenhar a curva.'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRenal(bool isEs, AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PedFlatSection(
          quietHeader: true,
          title: isEs ? 'Función renal pediátrica' : 'Função renal pediátrica',
          icon: Icons.water_drop_outlined,
          child: Column(
            children: [
              _PedSexSelector(
                isEs: isEs,
                dark: c.dark,
                value: _growthSex,
                onChanged: (value) => setState(() => _growthSex = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Años' : 'Anos',
                      ctrl: _ageYCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 8' : 'Ex. 8',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Meses' : 'Meses',
                      ctrl: _ageMCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 0' : 'Ex. 0',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Talla (cm)' : 'Altura (cm)',
                      ctrl: _heightCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 120' : 'Ex. 120',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PedCompactInput(
                      label: isEs ? 'Creatinina (mg/dL)' : 'Creatinina (mg/dL)',
                      ctrl: _swCrCtrl,
                      onChanged: (_) => setState(() {}),
                      hint: isEs ? 'Ej. 0,6' : 'Ex. 0,6',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PedMetricRow(
                label: 'CKiD U25 — creatinina',
                value: _fmt(_egfrU25, dec: 1),
                unit: 'mL/min/1,73m²',
                accent: const Color(0xFF10B981),
              ),
              _PedMetricRow(
                label: 'CKiD bedside 2009',
                value: _fmt(_egfrBedside2009, dec: 1),
                unit: 'mL/min/1,73m²',
                accent: const Color(0xFF2563EB),
                last: true,
              ),
              const SizedBox(height: 10),
              _PedSourceNote(
                isEs: isEs,
                text: isEs
                    ? 'Preferente: CKiD U25 para 1–25 años en el contexto de ERC. Alternativa histórica rápida: CKiD bedside 2009. NIDDK/CKiD; Pierce et al., Kidney Int 2021.'
                    : 'Preferencial: CKiD U25 para 1–25 anos no contexto de DRC. Alternativa histórica rápida: CKiD bedside 2009. NIDDK/CKiD; Pierce et al., Kidney Int 2021.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // SEÇÃO 4 — PEWS (Pediatric Early Warning Score)
  // ──────────────────────────────────────────────────────────────
  Widget _buildPews(bool isEs, AppColors c) {
    final result = _pewsResult;
    final total = result.total;
    final riskColor = _pewsColor(total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PedFlatSection(
          title: 'Brighton PEWS',
          icon: Icons.monitor_heart_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(0, 2, 0, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 54,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: riskColor.withValues(alpha: 0.06),
                            border: Border.all(
                              color: riskColor.withValues(alpha: 0.48),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 22,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: riskColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEs ? 'RESULTADO ACTUAL' : 'RESULTADO ATUAL',
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: riskColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEs
                                  ? result.interpretationEs
                                  : result.interpretationPt,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.28,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 0.7, color: c.border),
              const SizedBox(height: 12),
              _PedPewsSelectorFlat(
                title: isEs ? 'Comportamiento' : 'Comportamento',
                value: _pewsBehavior,
                options: isEs
                    ? const [
                        'Jugando / apropiado',
                        'Dormido',
                        'Irritable',
                        'Letárgico/confuso o respuesta reducida al dolor',
                      ]
                    : const [
                        'Brincando / adequado',
                        'Dormindo',
                        'Irritável',
                        'Letárgico/confuso ou resposta reduzida à dor',
                      ],
                onChanged: (v) => setState(() => _pewsBehavior = v),
              ),
              const SizedBox(height: 14),
              _PedPewsSelectorFlat(
                title: isEs ? 'Cardiovascular' : 'Cardiovascular',
                value: _pewsCardio,
                options: isEs
                    ? const [
                        'Rosado y/o TRC 1–2 s',
                        'Pálido y/o TRC 3 s',
                        'Gris y/o TRC 4 s o FC >20 sobre normal',
                        'Gris/moteado o TRC ≥5 s o FC >30 sobre normal o bradicardia',
                      ]
                    : const [
                        'Rosado e/ou TEC 1–2 s',
                        'Pálido e/ou TEC 3 s',
                        'Cinza e/ou TEC 4 s ou FC >20 acima do normal',
                        'Cinza/moteado ou TEC ≥5 s ou FC >30 acima do normal ou bradicardia',
                      ],
                onChanged: (v) => setState(() => _pewsCardio = v),
              ),
              const SizedBox(height: 14),
              _PedPewsSelectorFlat(
                title: isEs ? 'Respiratorio' : 'Respiratório',
                value: _pewsRespiratory,
                options: isEs
                    ? const [
                        'Dentro de parámetros normales, sin retracciones',
                        'FR >10 sobre normal, accesorios o FiO₂ ≥30% / ≥3 L/min',
                        'FR >20 sobre normal, retracciones o FiO₂ ≥40% / ≥6 L/min',
                        'FR >5 por debajo de normal con retracciones/quejido o FiO₂ ≥50% / ≥8 L/min',
                      ]
                    : const [
                        'Dentro dos parâmetros normais, sem retrações',
                        'FR >10 acima do normal, acessórios ou FiO₂ ≥30% / ≥3 L/min',
                        'FR >20 acima do normal, retrações ou FiO₂ ≥40% / ≥6 L/min',
                        'FR >5 abaixo do normal com retrações/gemido ou FiO₂ ≥50% / ≥8 L/min',
                      ],
                onChanged: (v) => setState(() => _pewsRespiratory = v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'MODIFICADORES +2',
                      style: TextStyle(
                        fontSize: _PediatricsVisualScaleR3.subsectionTitle,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _PedCheckRow(
                label: isEs
                    ? 'Nebulizador/broncodilatador cada 15 min (+2)'
                    : 'Nebulizador/broncodilatador a cada 15 min (+2)',
                value: _pewsQuarterHourlyNebulizer,
                onChanged: (v) =>
                    setState(() => _pewsQuarterHourlyNebulizer = v),
              ),
              _PedCheckRow(
                label: isEs
                    ? 'Vómitos persistentes postoperatorios (+2)'
                    : 'Vômitos persistentes pós-operatórios (+2)',
                value: _pewsPersistentPostOpVomiting,
                onChanged: (v) =>
                    setState(() => _pewsPersistentPostOpVomiting = v),
                last: true,
              ),
              const SizedBox(height: 10),
              _PedSourceNote(
                isEs: isEs,
                text: isEs
                    ? 'Brighton PEWS: Monaghan 2005, DOI 10.7748/paed2005.02.17.1.32.c964. Criterios reproducidos en Duraisamy et al. 2021, DOI 10.32677/IJCH.2021.v08.i06.003. Revisión MedCases 2026.'
                    : 'Brighton PEWS: Monaghan 2005, DOI 10.7748/paed2005.02.17.1.32.c964. Critérios reproduzidos em Duraisamy et al. 2021, DOI 10.32677/IJCH.2021.v08.i06.003. Revisão MedCases 2026.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // SEÇÃO OCULTA — DOSES PEDIÁTRICAS
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
          color: const Color(0xFF065F46).withOpacity(0.08),
          border: Border.all(color: const Color(0xFF065F46).withOpacity(0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.scale_rounded, size: 18, color: Color(0xFF065F46)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isEs ? 'Peso del paciente' : 'Peso do paciente',
                style: const TextStyle(
                    fontSize: _PediatricsVisualScaleR3.sectionLabel,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                    letterSpacing: 0.3),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 32,
                child: TextField(
                  controller: _dosesWeightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontSize: _PediatricsVisualScaleR3.body,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF065F46)),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: isEs ? 'Ej: 25,0' : 'Ex: 25,0',
                    hintStyle: TextStyle(
                        fontSize: _PediatricsVisualScaleR3.body,
                        color: const Color(0xFF065F46).withOpacity(0.4)),
                    border: InputBorder.none,
                    suffix: const Text('kg',
                        style: TextStyle(
                            fontSize: _PediatricsVisualScaleR3.body,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46))),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
          ),
          if (w != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF065F46).withOpacity(0.12),
              ),
              child: Text('${_fmt(w)} kg',
                  style: const TextStyle(
                      fontSize: _PediatricsVisualScaleR3.body,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF065F46))),
            )
          ],
        ]),
      ),

      // ── Disclaimer Apple Guideline 1.4.2 + dica de interação ─────
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF1E3A8A).withOpacity(0.06),
          border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.verified_user_outlined,
                size: 12, color: Color(0xFF1E3A8A)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
              isEs
                  ? 'Doses baseadas em diretrizes AHA PALS 2020, WHO e Harriet Lane Handbook 22ª ed.'
                  : 'Doses baseadas em diretrizes AHA PALS 2020, WHO e Harriet Lane Handbook 22ª ed.',
              style: const TextStyle(
                  fontSize: _PediatricsVisualScaleR3.sectionLabel,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                  height: 1.3),
            )),
          ]),
          const SizedBox(height: 5),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.touch_app_rounded,
                size: 12, color: Color(0xFF1E3A8A)),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
              isEs
                  ? 'Toque em cada fármaco para ver contraindicações e referências bibliográficas completas.'
                  : 'Toque em cada fármaco para ver contraindicações e referências bibliográficas completas.',
              style: TextStyle(
                  fontSize: _PediatricsVisualScaleR3.sectionLabel,
                  color: const Color(0xFF1E3A8A).withOpacity(0.75),
                  height: 1.3),
            )),
          ]),
        ]),
      ),

      _SectionCard(
        title: isEs
            ? 'Reanimación — PCR Pediátrica'
            : 'Reanimação — PCR Pediátrica',
        icon: Icons.emergency_rounded,
        child: Column(children: [
          _PedDoseRow(
              label: 'Adrenalina IV/IO',
              dose: '0,01 mg/kg',
              weight: w,
              mgPerKg: 0.01,
              unit: 'mg',
              maxDose: '1 mg',
              color: const Color(0xFFCC2222),
              line: _TherapeuticLine.first,
              indication: isEs
                  ? 'PCR em assistolia, AESP, FV/TV sem pulso'
                  : 'PCR em assistolia, AESP, FV/TV sem pulso',
              warningNote: isEs
                  ? 'Repetir a cada 3–5 min. Administrar rapidamente em bolus. Seguir imediatamente com flush. Monitorizar ECG e PA.'
                  : 'Repetir a cada 3–5 min. Administrar rapidamente em bolus. Seguir imediatamente com flush. Monitorizar ECG e PA.',
              contraindications: isEs
                  ? [
                      'Taquicardia ventricular sin FV',
                      'Hipertensión severa no controlada',
                      'Feocromocitoma (relativa)',
                      'Monitorización ECG continua obligatoria'
                    ]
                  : [
                      'Taquicardia ventricular sem FV',
                      'Hipertensão severa não controlada',
                      'Feocromocitoma (relativa)',
                      'Monitorização ECG contínua obrigatória'
                    ]),
          _PedDoseRow(
              label: 'Amiodarona IV/IO',
              dose: '5 mg/kg',
              weight: w,
              mgPerKg: 5.0,
              unit: 'mg',
              maxDose: '300 mg',
              color: const Color(0xFFD97706),
              line: _TherapeuticLine.second,
              indication: isEs
                  ? 'FV/TV refractaria (2ª dose adrenalina)'
                  : 'FV/TV refratária (após 2ª dose adrenalina)',
              warningNote: isEs
                  ? 'Infundir lentamente em 10–20 min. Monitorizar hipotensão. Prolongar QT.'
                  : 'Infundir lentamente em 10–20 min. Monitorizar hipotensão. Prolonga QT.',
              contraindications: isEs
                  ? [
                      'Bradicardia sinusal grave',
                      'Bloqueo AV de 2º y 3º grado sin marcapaso',
                      'Hipersensibilidad al yodo',
                      'Hipotensión severa',
                      'QT largo congénito'
                    ]
                  : [
                      'Bradicardia sinusal grave',
                      'Bloqueio AV 2º e 3º grau sem marca-passo',
                      'Hipersensibilidade ao iodo',
                      'Hipotensão severa',
                      'QT longo congênito'
                    ]),
          _PedDoseRow(
              label: 'Adenosina IV (TSV)',
              dose: '0,1 mg/kg',
              weight: w,
              mgPerKg: 0.1,
              unit: 'mg',
              maxDose: '6 mg',
              color: const Color(0xFFD97706),
              line: _TherapeuticLine.first,
              indication: 'TSV — taquicardia supraventricular',
              warningNote: isEs
                  ? 'Bolus IV RÁPIDO (1–2 s). Seguir com flush SF 20 mL. Pode causar assistolia transitória.'
                  : 'Bolus IV RÁPIDO (1–2 s). Seguir com flush SF 20 mL. Pode causar assistolia transitória.',
              contraindications: isEs
                  ? [
                      'Bloqueo AV 2º y 3º grado',
                      'Síndrome del seno enfermo',
                      'Asma bronquial (broncoespasmo)',
                      'Flutter/fibrilación auricular',
                      'Administrar en bolo IV rápido (bolus 1-2 s)'
                    ]
                  : [
                      'Bloqueio AV 2º e 3º grau',
                      'Doença do nó sinusal',
                      'Asma brônquica (broncoespasmo)',
                      'Flutter/fibrilação atrial',
                      'Administrar em bolus IV rápido (1-2 s)'
                    ]),
          _PedDoseRow(
              label: 'Atropina IV (bradicardia)',
              dose: '0,02 mg/kg',
              weight: w,
              mgPerKg: 0.02,
              unit: 'mg',
              maxDose: '0,5 mg',
              color: const Color(0xFF1D4ED8),
              line: _TherapeuticLine.second,
              indication: isEs
                  ? 'Bradicardia sintomática con hipotensión'
                  : 'Bradicardia sintomática com hipotensão',
              warningNote: isEs
                  ? 'Dosis MÍNIMA 0,1 mg — dosis menores pueden causar bradicardia paradójica.'
                  : 'Dose MÍNIMA 0,1 mg — doses menores podem causar bradicardia paradoxal.',
              contraindications: isEs
                  ? [
                      'Glaucoma de ángulo cerrado',
                      'Taquicardia sinusal',
                      'Miastenia gravis',
                      'Dosis mínima 0,1 mg (dosis menores → bradicardia paradójica)',
                      'Íleo paralítico / obstrucción intestinal'
                    ]
                  : [
                      'Glaucoma de ângulo fechado',
                      'Taquicardia sinusal',
                      'Miastenia gravis',
                      'Dose mínima 0,1 mg (doses menores → bradicardia paradoxal)',
                      'Íleo paralítico / obstrução intestinal'
                    ]),
          _PedDoseRow(
              label: 'Glicose 10% IV (hipoglicemia)',
              dose: '2–5 mL/kg',
              weight: w,
              mgPerKg: 3.0,
              unit: 'mL',
              maxDose: '250 mL',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      'Hiperglucemia (BGL > 180 mg/dL)',
                      'Confirmar hipoglucemia antes de administrar',
                      'Acceso venoso periférico preferible (osmolaridade 556 mOsm/L)'
                    ]
                  : [
                      'Hiperglicemia (BGL > 180 mg/dL)',
                      'Confirmar hipoglicemia antes de administrar',
                      'Acesso venoso periférico preferível (osmolaridade 556 mOsm/L)'
                    ]),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Dor ────────────────────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Analgesia — Dolor' : 'Analgesia — Dor',
        icon: Icons.healing_rounded,
        child: Column(children: [
          _PedDoseRow(
              label: 'Paracetamol VO/VR',
              dose: '10–15 mg/kg q4–6h',
              weight: w,
              mgPerKg: 12.5,
              unit: 'mg',
              maxDose: '1000 mg',
              color: const Color(0xFF065F46),
              line: _TherapeuticLine.first,
              indication: isEs
                  ? '1ª elección — analgesia y antipiresis'
                  : '1ª escolha — analgesia e antipirese',
              contraindications: isEs
                  ? [
                      'Insuficiencia hepática grave',
                      'Hipersensibilidad al paracetamol',
                      'No superar 4 dosis/día',
                      'Evitar en neonatos < 32 semanas (ajustar dosis)'
                    ]
                  : [
                      'Insuficiência hepática grave',
                      'Hipersensibilidade ao paracetamol',
                      'Não ultrapassar 4 doses/dia',
                      'Evitar em neonatos < 32 semanas (ajustar dose)'
                    ]),
          _PedDoseRow(
              label: 'Ibuprofeno VO',
              dose: '5–10 mg/kg q6–8h',
              weight: w,
              mgPerKg: 7.5,
              unit: 'mg',
              maxDose: '400 mg',
              color: const Color(0xFF065F46),
              line: _TherapeuticLine.second,
              indication: isEs
                  ? 'Dolor leve–moderado (≥ 6 meses)'
                  : 'Dor leve–moderada (≥ 6 meses)',
              warningNote: isEs
                  ? 'Evitar em Dengue. Não usar < 6 meses. Evitar desidratação.'
                  : 'Evitar em Dengue. Não usar < 6 meses. Evitar desidratação.',
              contraindications: isEs
                  ? [
                      '< 6 meses de edad (contraindicado)',
                      'Insuficiencia renal / deshidratación',
                      'Úlcera péptica activa',
                      'Dengue (riesgo de sangrado)',
                      'Asma inducida por AINEs',
                      'Insuficiencia hepática'
                    ]
                  : [
                      '< 6 meses de idade (contraindicado)',
                      'Insuficiência renal / desidratação',
                      'Úlcera péptica ativa',
                      'Dengue (risco de sangramento)',
                      'Asma induzida por AINEs',
                      'Insuficiência hepática'
                    ]),
          _PedDoseRow(
              label: 'Dipirona/Metamizol VO/IV',
              dose: '15 mg/kg q6h',
              weight: w,
              mgPerKg: 15.0,
              unit: 'mg',
              maxDose: '1000 mg',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      '< 3 meses / < 5 kg (contraindicado IV)',
                      'Hipersensibilidad a pirazolonas',
                      'Porfiria hepática aguda',
                      'Riesgo de agranulocitosis (monitorizar CBC)',
                      'Hipotensión en administración IV rápida'
                    ]
                  : [
                      '< 3 meses / < 5 kg (contraindicado IV)',
                      'Hipersensibilidade a pirazolonas',
                      'Porfiria hepática aguda',
                      'Risco de agranulocitose (monitorar hemograma)',
                      'Hipotensão em administração IV rápida'
                    ]),
          _PedDoseRow(
              label: 'Morfina IV/SC',
              dose: '0,05–0,1 mg/kg q2–4h',
              weight: w,
              mgPerKg: 0.1,
              unit: 'mg',
              maxDose: '5 mg',
              color: const Color(0xFF7C3AED),
              line: _TherapeuticLine.second,
              indication: isEs
                  ? 'Dolor severo, procedimientos dolorosos'
                  : 'Dor severa, procedimentos dolorosos',
              warningNote: isEs
                  ? 'Monitorizar SpO₂ e FR. Ter Naloxona 0,01 mg/kg disponível. Titular pela resposta.'
                  : 'Monitorizar SpO₂ e FR. Ter Naloxona 0,01 mg/kg disponível. Titular pela resposta.',
              contraindications: isEs
                  ? [
                      '< 6 meses (ajuste de dosis — alta sensibilidad)',
                      'Depresión respiratoria',
                      'Íleo paralítico',
                      'Hipertensión intracraneal aguda',
                      'Hipotensión severa',
                      'Antídoto: Naloxona 0,01 mg/kg IV'
                    ]
                  : [
                      '< 6 meses (ajuste de dose — alta sensibilidade)',
                      'Depressão respiratória',
                      'Íleo paralítico',
                      'Hipertensão intracraniana aguda',
                      'Hipotensão severa',
                      'Antídoto: Naloxona 0,01 mg/kg IV'
                    ]),
          _PedDoseRow(
              label: 'Tramadol VO/IV',
              dose: '1–2 mg/kg q4–6h',
              weight: w,
              mgPerKg: 1.5,
              unit: 'mg',
              maxDose: '100 mg',
              color: const Color(0xFF7C3AED),
              line: _TherapeuticLine.third,
              indication: isEs
                  ? '> 12 años VO solamente (FDA 2017)'
                  : '> 12 anos VO somente (FDA 2017)',
              warningNote: isEs
                  ? '⚠ CONTRAINDICADO < 12 años VO — riesgo fatal CYP2D6. Prohibido post-amigdalectomía.'
                  : '⚠ CONTRAINDICADO < 12 anos VO — risco fatal CYP2D6. Proibido pós-amigdalectomia.',
              contraindications: isEs
                  ? [
                      '< 12 años VO (metabolizadores ultrarrápidos CYP2D6 — riesgo mortal)',
                      'Post-amigdalectomía / adenoidectomía (< 18 años)',
                      'Epilepsia no controlada',
                      'Depresión respiratoria',
                      'IMAO concomitante'
                    ]
                  : [
                      '< 12 anos VO (metabolizadores ultrarrápidos CYP2D6 — risco fatal)',
                      'Pós-amigdalectomia / adenoidectomia (< 18 anos)',
                      'Epilepsia não controlada',
                      'Depressão respiratória',
                      'IMAO concomitante'
                    ]),
          _PedDoseRow(
              label: 'Cetorolaco IV/IM',
              dose: '0,5 mg/kg q6h',
              weight: w,
              mgPerKg: 0.5,
              unit: 'mg',
              maxDose: '30 mg',
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      '< 2 años (contraindicado)',
                      'Insuficiencia renal',
                      'Úlcera péptica activa',
                      'Sangrado gastrointestinal activo',
                      'Máximo 5 días de uso'
                    ]
                  : [
                      '< 2 anos (contraindicado)',
                      'Insuficiência renal',
                      'Úlcera péptica ativa',
                      'Sangramento gastrointestinal ativo',
                      'Máximo 5 dias de uso'
                    ]),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Febre ──────────────────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Antitérmicos — Fiebre' : 'Antipiréticos — Febre',
        icon: Icons.thermostat_rounded,
        child: Column(children: [
          _PedDoseRow(
              label: 'Paracetamol VO/VR',
              dose: '10–15 mg/kg q4–6h',
              weight: w,
              mgPerKg: 12.5,
              unit: 'mg',
              maxDose: '1000 mg',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      'Insuficiencia hepática grave',
                      'No superar 5 dosis/día',
                      'Intervalo mínimo de 4h entre dosis'
                    ]
                  : [
                      'Insuficiência hepática grave',
                      'Não ultrapassar 5 doses/dia',
                      'Intervalo mínimo de 4h entre doses'
                    ]),
          _PedDoseRow(
              label: 'Ibuprofeno VO',
              dose: '5–10 mg/kg q6–8h',
              weight: w,
              mgPerKg: 7.5,
              unit: 'mg',
              maxDose: '400 mg',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      '< 6 meses (contraindicado)',
                      'Dengue — evitar AINEs',
                      'Deshidratación / hipovolemia',
                      'No combinar con otros AINEs'
                    ]
                  : [
                      '< 6 meses (contraindicado)',
                      'Dengue — evitar AINEs',
                      'Desidratação / hipovolemia',
                      'Não combinar com outros AINEs'
                    ]),
          _PedDoseRow(
              label: 'Dipirona VO/IV',
              dose: '15 mg/kg q6h',
              weight: w,
              mgPerKg: 15.0,
              unit: 'mg',
              maxDose: '500 mg',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      '< 3 meses / < 5 kg',
                      'Hipersensibilidad a pirazolonas',
                      'IV lenta (riesgo hipotensión)'
                    ]
                  : [
                      '< 3 meses / < 5 kg',
                      'Hipersensibilidade a pirazolonas',
                      'IV lenta (risco hipotensão)'
                    ]),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Descongestionantes / Respiratório ──────────────────────────
      _SectionCard(
        title: isEs
            ? 'Descongestionantes y Vía Aérea'
            : 'Descongestionantes e Via Aérea',
        icon: Icons.air_rounded,
        child: Column(children: [
          _PedDoseRow(
              label: 'Salbutamol inalatório (crise)',
              dose: '2,5–5 mg (nebulização)',
              weight: w,
              mgPerKg: null,
              unit: 'mg',
              maxDose: null,
              color: const Color(0xFF1D4ED8),
              line: _TherapeuticLine.first,
              indication: isEs
                  ? 'Crisis de asma, broncoespasmo agudo'
                  : 'Crise de asma, broncoespasmo agudo',
              warningNote: isEs
                  ? 'Repetir a cada 20 min × 3. Monitorizar FC e SpO₂ durante nebulização.'
                  : 'Repetir a cada 20 min × 3. Monitorizar FC e SpO₂ durante nebulização.',
              contraindications: isEs
                  ? [
                      'Hipersensibilidad a salbutamol',
                      'Taquicardia no controlada',
                      'Monitorizar FC y SpO₂ durante nebulización',
                      'Preferir MDI + espaciador en < 5 años'
                    ]
                  : [
                      'Hipersensibilidade ao salbutamol',
                      'Taquicardia não controlada',
                      'Monitorar FC e SpO₂ durante nebulização',
                      'Preferir MDI + espaçador em < 5 anos'
                    ]),
          _PedDoseRow(
              label: 'Ipratrópio inalatório',
              dose: '250–500 mcg nebulização',
              weight: w,
              mgPerKg: null,
              unit: 'mcg',
              maxDose: null,
              color: const Color(0xFF1D4ED8),
              contraindications: isEs
                  ? [
                      'Hipersensibilidad a atropina / brometo',
                      'Glaucoma de ángulo cerrado',
                      'Retención urinaria / hipertrofia prostática'
                    ]
                  : [
                      'Hipersensibilidade à atropina / brometo',
                      'Glaucoma de ângulo fechado',
                      'Retenção urinária / hipertrofia prostática'
                    ]),
          _PedDoseRow(
              label: 'Adrenalina nebulizada (crupe)',
              dose: '0,5 mL/kg de 1:1000',
              weight: w,
              mgPerKg: null,
              unit: 'mL',
              maxDose: '5 mL',
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      'Taquicardia > 200 bpm',
                      'Cardiopatía congénita cianótica',
                      'Observar 2–4h post-nebulización (efecto rebote)',
                      'No usar sin supervisión médica continua'
                    ]
                  : [
                      'Taquicardia > 200 bpm',
                      'Cardiopatia congênita cianótica',
                      'Observar 2–4h pós-nebulização (efeito rebote)',
                      'Não usar sem supervisão médica contínua'
                    ]),
          _PedDoseRow(
              label: 'Dexametasona VO/IM (crupe)',
              dose: '0,15–0,6 mg/kg dose única',
              weight: w,
              mgPerKg: 0.3,
              unit: 'mg',
              maxDose: '10 mg',
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      'Infección viral sin indicación clínica',
                      'Infección bacteriana activa no tratada',
                      'Inmunosupresión severa (relativa)',
                      'Varicela activa'
                    ]
                  : [
                      'Infecção viral sem indicação clínica',
                      'Infecção bacteriana ativa não tratada',
                      'Imunossupressão grave (relativa)',
                      'Varicela ativa'
                    ]),
          _PedDoseRow(
              label: 'Prednisolona VO',
              dose: '1–2 mg/kg/dia ÷ 1–2x',
              weight: w,
              mgPerKg: 1.0,
              unit: 'mg',
              maxDose: '40 mg',
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      'Infección fúngica sistémica',
                      'Varicela / Herpes activo',
                      'Vacunas vivas (evitar durante tratamiento)',
                      'Tuberculosis activa no tratada'
                    ]
                  : [
                      'Infecção fúngica sistêmica',
                      'Varicela / Herpes ativo',
                      'Vacinas vivas (evitar durante o tratamento)',
                      'Tuberculose ativa não tratada'
                    ]),
          _PedDoseRow(
              label: 'Solução Fisiológica nasal',
              dose: '2–3 gotas/narina q4–6h',
              weight: w,
              mgPerKg: null,
              unit: '',
              maxDose: null,
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      'Sin contraindicaciones absolutas',
                      'Evitar en neonatos sin orientación',
                      'Primera línea en congestión nasal pediátrica'
                    ]
                  : [
                      'Sem contraindicações absolutas',
                      'Evitar em neonatos sem orientação',
                      'Primeira linha na congestão nasal pediátrica'
                    ]),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Sedação e Analgesia Procedural ────────────────────────────
      _SectionCard(
        title: isEs ? 'Sedación y Analgesia' : 'Sedação e Analgesia',
        icon: Icons.medication_rounded,
        child: Column(children: [
          _PedDoseRow(
              label: 'Midazolam IV/IM',
              dose: '0,05–0,1 mg/kg',
              weight: w,
              mgPerKg: 0.1,
              unit: 'mg',
              maxDose: '5 mg',
              color: const Color(0xFF7C3AED),
              contraindications: isEs
                  ? [
                      'Hipersensibilidad a benzodiacepinas',
                      'Glaucoma de ángulo cerrado',
                      'Depresión respiratoria severa',
                      'Antídoto: Flumazenil 0,01 mg/kg IV',
                      'Monitorizar SpO₂ continuamente'
                    ]
                  : [
                      'Hipersensibilidade a benzodiazepinas',
                      'Glaucoma de ângulo fechado',
                      'Depressão respiratória grave',
                      'Antídoto: Flumazenil 0,01 mg/kg IV',
                      'Monitorar SpO₂ continuamente'
                    ]),
          _PedDoseRow(
              label: 'Cetamina IV',
              dose: '1–2 mg/kg (procedimentos)',
              weight: w,
              mgPerKg: 1.5,
              unit: 'mg',
              maxDose: '200 mg',
              color: const Color(0xFF7C3AED),
              contraindications: isEs
                  ? [
                      'Hipertensión intracraneal (TEC grave)',
                      'Psicosis activa',
                      'Eclampsia / preeclampsia',
                      'Cirugía de laringe/tráquea (laringoespasmo)',
                      'Asociar con midazolam para prevenir alucinaciones'
                    ]
                  : [
                      'Hipertensão intracraniana (TCE grave)',
                      'Psicose ativa',
                      'Eclâmpsia / pré-eclâmpsia',
                      'Cirurgia de laringe/traqueia (laringoespasmo)',
                      'Associar com midazolam para prevenir alucinações'
                    ]),
          _PedDoseRow(
              label: 'Fentanil IV',
              dose: '1–2 mcg/kg',
              weight: w,
              mgPerKg: 0.0015,
              unit: 'mg',
              maxDose: '100 mcg',
              color: const Color(0xFF7C3AED),
              contraindications: isEs
                  ? [
                      'Depresión respiratoria',
                      'Hipotensión severa',
                      'Rigidez torácica ("tórax leñoso") con dosis altas — usar lentamente',
                      'Antídoto: Naloxona 0,01 mg/kg IV'
                    ]
                  : [
                      'Depressão respiratória',
                      'Hipotensão severa',
                      'Rigidez torácica ("tórax lenhoso") com doses altas — administrar lentamente',
                      'Antídoto: Naloxona 0,01 mg/kg IV'
                    ]),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Antibióticos ───────────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Antibióticos Pediátricos' : 'Antibióticos Pediátricos',
        icon: Icons.science_rounded,
        child: Column(children: [
          _PedDoseRow(
              label: 'Amoxicilina VO',
              dose: '40–90 mg/kg/dia ÷ 3x',
              weight: w,
              mgPerKg: 50.0,
              unit: 'mg',
              maxDose: '3000 mg',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      'Alergia a penicilinas',
                      'Mononucleosis (rash generalizado)',
                      'Insuficiencia renal grave (ajustar dosis)'
                    ]
                  : [
                      'Alergia a penicilinas',
                      'Mononucleose (rash generalizado)',
                      'Insuficiência renal grave (ajustar dose)'
                    ]),
          _PedDoseRow(
              label: 'Amox-Clavulanato VO',
              dose: '40–90 mg/kg/dia ÷ 2–3x',
              weight: w,
              mgPerKg: 45.0,
              unit: 'mg',
              maxDose: '1500 mg',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      'Alergia a penicilinas / clavulanato',
                      'Hepatitis colestásica previa por amox-clav',
                      'Mononucleosis infecciosa',
                      'Ajustar en insuficiencia renal'
                    ]
                  : [
                      'Alergia a penicilinas / clavulanato',
                      'Hepatite colestática prévia por amox-clav',
                      'Mononucleose infecciosa',
                      'Ajustar em insuficiência renal'
                    ]),
          _PedDoseRow(
              label: 'Azitromicina VO',
              dose: '10 mg/kg/dia 1x (3–5d)',
              weight: w,
              mgPerKg: 10.0,
              unit: 'mg',
              maxDose: '500 mg',
              color: const Color(0xFF1D4ED8),
              contraindications: isEs
                  ? [
                      'Hipersensibilidad a macrólidos',
                      'QT largo / uso de otros fármacos QT',
                      'Insuficiencia hepática grave',
                      'Arritmia cardíaca preexistente'
                    ]
                  : [
                      'Hipersensibilidade a macrolídeos',
                      'QT longo / uso de outros fármacos QT',
                      'Insuficiência hepática grave',
                      'Arritmia cardíaca preexistente'
                    ]),
          _PedDoseRow(
              label: 'Ceftriaxona IV/IM',
              dose: '50–100 mg/kg/dia ÷ 1–2x',
              weight: w,
              mgPerKg: 50.0,
              unit: 'mg',
              maxDose: '4000 mg',
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      'Alergia a cefalosporinas (precaución cruzada con penicilinas)',
                      'Neonatos ictéricos o prematuros (desplaza bilirrubina)',
                      'No mezclar con calcio IV (precipita en neonatos — riesgo de muerte)',
                      'Insuficiencia renal grave + hepática simultánea'
                    ]
                  : [
                      'Alergia a cefalosporinas (precaução cruzada com penicilinas)',
                      'Neonatos ictéricos ou prematuros (desloca bilirrubina)',
                      'Não misturar com cálcio IV (precipita em neonatos — risco de morte)',
                      'Insuficiência renal grave + hepática simultânea'
                    ]),
          _PedDoseRow(
              label: 'Cefalexina VO',
              dose: '25–50 mg/kg/dia ÷ 4x',
              weight: w,
              mgPerKg: 25.0,
              unit: 'mg',
              maxDose: '2000 mg',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      'Alergia a cefalosporinas',
                      'Insuficiencia renal (ajustar dosis)',
                      'Precaución en alérgicos a penicilinas (5–10% reacción cruzada)'
                    ]
                  : [
                      'Alergia a cefalosporinas',
                      'Insuficiência renal (ajustar dose)',
                      'Precaução em alérgicos a penicilinas (5–10% reação cruzada)'
                    ]),
          _PedDoseRow(
              label: 'Sulfametoxazol-Trimetoprim VO',
              dose: '8 mg/kg/dia (TMP) ÷ 2x',
              weight: w,
              mgPerKg: 8.0,
              unit: 'mg',
              maxDose: '320 mg',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      '< 2 meses (kernicterus neonatal)',
                      'Insuficiencia renal grave',
                      'Deficiencia de G6PD',
                      'Hipersensibilidad a sulfonamidas',
                      'Embarazo (1º y 3º trimestre)',
                      'Monitorizar CBC en uso prolongado'
                    ]
                  : [
                      '< 2 meses (kernicterus neonatal)',
                      'Insuficiência renal grave',
                      'Deficiência de G6PD',
                      'Hipersensibilidade a sulfonamidas',
                      'Monitorar hemograma em uso prolongado'
                    ]),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Crise Convulsiva ───────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Crisis Convulsiva' : 'Crise Convulsiva',
        icon: Icons.bolt_rounded,
        child: Column(children: [
          _PedDoseRow(
              label: 'Diazepam IV (1ª linha)',
              dose: '0,2–0,5 mg/kg',
              weight: w,
              mgPerKg: 0.3,
              unit: 'mg',
              maxDose: '10 mg',
              color: const Color(0xFF1D4ED8),
              contraindications: isEs
                  ? [
                      'Depresión respiratoria severa',
                      'Glaucoma de ángulo cerrado',
                      'Antídoto: Flumazenil 0,01 mg/kg IV',
                      'IV lento: riesgo de apnea'
                    ]
                  : [
                      'Depressão respiratória grave',
                      'Glaucoma de ângulo fechado',
                      'Antídoto: Flumazenil 0,01 mg/kg IV',
                      'IV lento: risco de apneia'
                    ]),
          _PedDoseRow(
              label: 'Midazolam IM/IO (1ª linha)',
              dose: '0,2 mg/kg',
              weight: w,
              mgPerKg: 0.2,
              unit: 'mg',
              maxDose: '10 mg',
              color: const Color(0xFF1D4ED8),
              contraindications: isEs
                  ? [
                      'Depresión respiratoria',
                      'Hipotensión severa',
                      'Antídoto: Flumazenil 0,01 mg/kg',
                      'Monitorizar SpO₂'
                    ]
                  : [
                      'Depressão respiratória',
                      'Hipotensão severa',
                      'Antídoto: Flumazenil 0,01 mg/kg',
                      'Monitorar SpO₂'
                    ]),
          _PedDoseRow(
              label: 'Fenitoína IV (2ª linha)',
              dose: '20 mg/kg',
              weight: w,
              mgPerKg: 20.0,
              unit: 'mg',
              maxDose: '1000 mg',
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      'Bradicardia sinusal / bloqueo AV',
                      'Síndrome de Adams-Stokes',
                      'Infusión lenta < 1 mg/kg/min (arritmia y hipotensión)',
                      'No mezclar con glucosa (precipita)',
                      'Extravasación → necrosis tisular'
                    ]
                  : [
                      'Bradicardia sinusal / bloqueio AV',
                      'Síndrome de Adams-Stokes',
                      'Infusão lenta < 1 mg/kg/min (arritmia e hipotensão)',
                      'Não misturar com glicose (precipita)',
                      'Extravasamento → necrose tissular'
                    ]),
          _PedDoseRow(
              label: 'Fenobarbital IV (2ª linha)',
              dose: '20 mg/kg',
              weight: w,
              mgPerKg: 20.0,
              unit: 'mg',
              maxDose: '1000 mg',
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      'Depresión respiratoria grave (riesgo de apnea)',
                      'Porfiria aguda',
                      'Insuficiencia hepática grave',
                      'Hipotensión — infusión lenta'
                    ]
                  : [
                      'Depressão respiratória grave (risco de apneia)',
                      'Porfiria aguda',
                      'Insuficiência hepática grave',
                      'Hipotensão — infusão lenta'
                    ]),
          _PedDoseRow(
              label: 'Levetiracetam IV (2ª linha)',
              dose: '60 mg/kg',
              weight: w,
              mgPerKg: 60.0,
              unit: 'mg',
              maxDose: '3000 mg',
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      'Hipersensibilidad al levetiracetam',
                      'Insuficiencia renal grave (ajustar)',
                      'Monitorizar comportamiento: agitación, psicosis en niños'
                    ]
                  : [
                      'Hipersensibilidade ao levetiracetam',
                      'Insuficiência renal grave (ajustar)',
                      'Monitorar comportamento: agitação, psicose em crianças'
                    ]),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Vasopressores ──────────────────────────────────────────────
      _SectionCard(
        title: isEs ? 'Vasopresores y Líquidos' : 'Vasopressores e Fluidos',
        icon: Icons.water_rounded,
        child: Column(children: [
          _PedDoseRow(
              label: 'SF 0,9% bolus (choque)',
              dose: '10–20 mL/kg',
              weight: w,
              mgPerKg: 15.0,
              unit: 'mL',
              maxDose: '500 mL',
              color: const Color(0xFF065F46),
              contraindications: isEs
                  ? [
                      'Insuficiencia cardíaca congestiva descompensada',
                      'Edema pulmonar',
                      'Monitorizar auscultación y SpO₂ durante expansión'
                    ]
                  : [
                      'Insuficiência cardíaca congestiva descompensada',
                      'Edema pulmonar',
                      'Monitorar ausculta e SpO₂ durante expansão'
                    ]),
          _PedDoseRow(
              label: 'Noradrenalina (dose início)',
              dose: '0,1 mcg/kg/min',
              weight: w,
              mgPerKg: null,
              unit: 'mcg/kg/min',
              maxDose: null,
              color: const Color(0xFFCC2222),
              contraindications: isEs
                  ? [
                      'Hipovolemia no corregida',
                      'Trombosis vascular mesentérica / periférica',
                      'Acceso venoso central preferido (extravasación → necrosis)',
                      'Antídoto extravasación: fentolamina local'
                    ]
                  : [
                      'Hipovolemia não corrigida',
                      'Trombose vascular mesentérica / periférica',
                      'Acesso venoso central preferido (extravasamento → necrose)',
                      'Antídoto extravasamento: fentolamina local'
                    ]),
          _PedDoseRow(
              label: 'Dopamina (dose renal)',
              dose: '2–5 mcg/kg/min',
              weight: w,
              mgPerKg: null,
              unit: 'mcg/kg/min',
              maxDose: null,
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      'Feocromocitoma',
                      'Fibrilación ventricular',
                      'Taquiarritmias no tratadas',
                      'Monitorización ECG continua',
                      'Acceso venoso central preferido'
                    ]
                  : [
                      'Feocromocitoma',
                      'Fibrilação ventricular',
                      'Taquiarritmias não tratadas',
                      'Monitorização ECG contínua',
                      'Acesso venoso central preferido'
                    ]),
          _PedDoseRow(
              label: 'Dobutamina (inotrópico)',
              dose: '5–20 mcg/kg/min',
              weight: w,
              mgPerKg: null,
              unit: 'mcg/kg/min',
              maxDose: null,
              color: const Color(0xFFD97706),
              contraindications: isEs
                  ? [
                      'Obstrucción subaórtica hipertrófica',
                      'Fibrilación auricular (aumenta FC)',
                      'Hipovolemia no corregida',
                      'Monitorización ECG y PA invasiva'
                    ]
                  : [
                      'Obstrução subaórtica hipertrófica',
                      'Fibrilação atrial (aumenta FC)',
                      'Hipovolemia não corrigida',
                      'Monitorização ECG e PA invasiva'
                    ]),
        ]),
      ),
      const SizedBox(height: 12),

      _InfoNote(
          text: isEs
              ? '⚠ Doses calculadas para referência. Confirmar com farmácia pediátrica. Limite pela dose máxima informada.'
              : '⚠ Doses calculadas para referência. Confirmar com farmácia pediátrica. Limite pela dose máxima informada.'),
    ]);
  }
}

// ── Widgets auxiliares de Pediatria ───────────────────────────────────────────

// MEDCASES_PEDS_2026_UI_RECOVERY_GROWTH_V1_B_R3
// MEDCASES_PEDS_2026_TAB_CONTAINER_RUNTIME_FIX_V1_B_R4
// MEDCASES_PEDS_2026_DEVICE_VISUAL_FIX_V1_B_R5
// MEDCASES_PEDS_2026_KEYBOARD_DISMISS_V1_B_R6_R1
// MEDCASES_PEDS_2026_REMOVE_DUPLICATE_NAV_V1_B_R7_R1

class _PedCompactInput extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final ValueChanged<String>? onChanged;
  final String? hint;

  const _PedCompactInput({
    required this.label,
    required this.ctrl,
    this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dark = c.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: _PediatricsVisualScaleR3.sectionLabel,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            cursorColor: const Color(0xFF0D6B57),
            style: TextStyle(
              fontSize: _PediatricsVisualScaleR3.inputText,
              height: 1.05,
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor:
                  dark ? const Color(0xFF1F232A) : const Color(0xFFFFFFFF),
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: _PediatricsVisualScaleR3.hint,
                fontWeight: FontWeight.w400,
                color: c.textHint,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.border, width: 0.7),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF0D6B57), width: 1.1),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: c.border, width: 0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PedSectionGap extends StatelessWidget {
  const _PedSectionGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 3);
}

class _PedFlatSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool quietHeader;

  const _PedFlatSection({
    required this.title,
    required this.icon,
    required this.child,
    this.quietHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 10, 17, 10),
      decoration: BoxDecoration(
        color: c.dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: quietHeader ? 14 : 15,
                color: const Color(0xFF0D6B57),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  quietHeader ? title : title.toUpperCase(),
                  style: TextStyle(
                    fontSize: _PediatricsVisualScaleR3.sectionTitle,
                    fontWeight: quietHeader ? FontWeight.w700 : FontWeight.w900,
                    letterSpacing: quietHeader ? 0.0 : 0.4,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: quietHeader ? 7 : 5),
          Container(height: 0.7, color: c.border),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _PedMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;
  final bool last;
  final bool valueSmall;

  const _PedMetricRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    this.last = false,
    this.valueSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: _PediatricsVisualScaleR3.sectionLabel,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              unit.isEmpty ? value : '$value $unit',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: valueSmall ? 13.5 : _PediatricsVisualScaleR3.result,
                height: valueSmall ? 1.3 : 1.1,
                fontWeight: valueSmall ? FontWeight.w600 : FontWeight.w700,
                color: value == '—' ? c.textHint : accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PedSourceNote extends StatefulWidget {
  final bool isEs;
  final String text;

  const _PedSourceNote({
    required this.isEs,
    required this.text,
  });

  @override
  State<_PedSourceNote> createState() => _PedSourceNoteState();
}

class _PedSourceNoteState extends State<_PedSourceNote> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 13,
                  color: c.textSecondary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.isEs ? 'Referencias' : 'Referências',
                    style: TextStyle(
                      fontSize: _PediatricsVisualScaleR3.micro,
                      height: 1.2,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: c.textHint,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 4),
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: _PediatricsVisualScaleR3.micro,
                height: 1.4,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _PedNavRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool last;

  const _PedNavRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: c.border, width: 0.6)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: c.textHint),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textHint),
          ],
        ),
      ),
    );
  }
}

class _PedSexSelector extends StatelessWidget {
  final bool isEs;
  final bool dark;
  final PediatricBiologicalSex value;
  final ValueChanged<PediatricBiologicalSex> onChanged;

  const _PedSexSelector({
    required this.isEs,
    required this.dark,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFD8E0E7);
    const active = Color(0xFF0D6B57);

    Widget option(
      String label,
      PediatricBiologicalSex sex,
    ) {
      final selected = value == sex;

      return Expanded(
        child: InkWell(
          onTap: () => onChanged(sex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 38,
            alignment: Alignment.center,
            color: selected
                ? active.withValues(alpha: dark ? 0.16 : 0.08)
                : Colors.transparent,
            child: Text(
              label,
              style: TextStyle(
                fontSize: _PediatricsVisualScaleR3.option,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? active : c.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? Colors.transparent : const Color(0xFFFFFFFF),
        border: Border.all(color: border, width: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          option(
            isEs ? 'Masculino' : 'Masculino',
            PediatricBiologicalSex.male,
          ),
          Container(width: 0.7, height: 38, color: border),
          option(
            isEs ? 'Femenino' : 'Feminino',
            PediatricBiologicalSex.female,
          ),
        ],
      ),
    );
  }
}

class _PedGrowthIndicatorToggle extends StatelessWidget {
  final bool isEs;
  final PediatricGrowthIndicator value;
  final ValueChanged<PediatricGrowthIndicator> onChanged;

  const _PedGrowthIndicatorToggle({
    required this.isEs,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final options = <(PediatricGrowthIndicator, String)>[
      (
        PediatricGrowthIndicator.weightForAge,
        isEs ? 'Peso/edad' : 'Peso/idade',
      ),
      (
        PediatricGrowthIndicator.heightForAge,
        isEs ? 'Talla/edad' : 'Altura/idade',
      ),
      (
        PediatricGrowthIndicator.bmiForAge,
        isEs ? 'IMC/edad' : 'IMC/idade',
      ),
    ];

    const activeColor = Color(0xFF0D6B57);

    return Container(
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.dark ? Colors.transparent : const Color(0xFFFFFFFF),
        border: Border.all(color: c.border, width: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(options.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Container(
              width: 0.7,
              height: 38,
              color: c.border,
            );
          }

          final item = options[index ~/ 2];
          final selected = item.$1 == value;

          return Expanded(
            child: InkWell(
              onTap: () => onChanged(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                alignment: Alignment.center,
                color: selected
                    ? activeColor.withValues(
                        alpha: c.dark ? 0.16 : 0.08,
                      )
                    : Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _PediatricsVisualScaleR3.option,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? activeColor : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PedPewsSelectorFlat extends StatelessWidget {
  final String title;
  final int value;
  final List<String> options;
  final ValueChanged<int> onChanged;

  const _PedPewsSelectorFlat({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF0D6B57),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: _PediatricsVisualScaleR3.subsectionTitle,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: c.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...List.generate(options.length, (i) {
          final active = value == i;
          return InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(bottom: 1),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF0D6B57).withValues(alpha: 0.055)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? const Color(0xFF0D6B57)
                                : Colors.transparent,
                            border: Border.all(
                              color:
                                  active ? const Color(0xFF0D6B57) : c.border,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$i',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: active ? Colors.white : c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.28,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PedCheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  const _PedCheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(
              value
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: value ? const Color(0xFF0D6B57) : c.textHint,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: _PediatricsVisualScaleR3.sectionLabel,
                  color: c.textPrimary,
                  fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PedGrowthChart extends StatelessWidget {
  final PediatricGrowthIndicator indicator;
  final PediatricBiologicalSex sex;
  final int patientAgeMonths;
  final double patientValue;
  final bool dark;

  const _PedGrowthChart({
    required this.indicator,
    required this.sex,
    required this.patientAgeMonths,
    required this.patientValue,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PedGrowthChartPainter(
        indicator: indicator,
        sex: sex,
        patientAgeMonths: patientAgeMonths,
        patientValue: patientValue,
        dark: dark,
      ),
    );
  }
}

class _PedGrowthChartPainter extends CustomPainter {
  final PediatricGrowthIndicator indicator;
  final PediatricBiologicalSex sex;
  final int patientAgeMonths;
  final double patientValue;
  final bool dark;

  const _PedGrowthChartPainter({
    required this.indicator,
    required this.sex,
    required this.patientAgeMonths,
    required this.patientValue,
    required this.dark,
  });

  static const _zCurves = <double>[
    -1.880793608,
    -1.036433389,
    0,
    1.036433389,
    1.880793608,
  ];
  static const _labels = <String>['P3', 'P15', 'P50', 'P85', 'P97'];

  @override
  void paint(Canvas canvas, Size size) {
    final startAge = patientAgeMonths < 60 ? 0 : 60;
    final endAge = indicator == PediatricGrowthIndicator.weightForAge
        ? (patientAgeMonths < 60 ? 59 : 120)
        : (patientAgeMonths < 60 ? 59 : 228);

    final curveData = <List<Offset>>[];
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

    for (final z in _zCurves) {
      final raw = <(int, double)>[];
      for (var age = startAge; age <= endAge; age++) {
        final value = PediatricGrowthEngineV2026.referenceValueForIndicatorAtZ(
          indicator: indicator,
          sex: sex,
          ageMonths: age,
          z: z,
        );
        if (value != null && value.isFinite) {
          raw.add((age, value));
          if (value < minY) minY = value;
          if (value > maxY) maxY = value;
        }
      }
      curveData.add(raw.map((e) => Offset(e.$1.toDouble(), e.$2)).toList());
    }

    if (!minY.isFinite || !maxY.isFinite || maxY <= minY) return;

    minY = minY < patientValue ? minY : patientValue;
    maxY = maxY > patientValue ? maxY : patientValue;
    final padY = (maxY - minY) * 0.08;
    minY -= padY;
    maxY += padY;

    const left = 34.0;
    const right = 32.0;
    const top = 10.0;
    const bottom = 26.0;
    final plotW = size.width - left - right;
    final plotH = size.height - top - bottom;

    double xFor(double age) =>
        left + ((age - startAge) / (endAge - startAge)) * plotW;
    double yFor(double value) =>
        top + (1 - ((value - minY) / (maxY - minY))) * plotH;

    final gridPaint = Paint()
      ..color = dark ? const Color(0xFF334155) : const Color(0xFFD8E0E7)
      ..strokeWidth = 0.7;

    for (var i = 0; i <= 4; i++) {
      final y = top + (plotH / 4) * i;
      canvas.drawLine(Offset(left, y), Offset(left + plotW, y), gridPaint);
    }

    final lineColors = <Color>[
      const Color(0xFF94A3B8),
      const Color(0xFF64748B),
      const Color(0xFF10B981),
      const Color(0xFF64748B),
      const Color(0xFF94A3B8),
    ];

    for (var i = 0; i < curveData.length; i++) {
      final points = curveData[i];
      if (points.length < 2) continue;
      final path = Path();
      for (var j = 0; j < points.length; j++) {
        final p = Offset(xFor(points[j].dx), yFor(points[j].dy));
        if (j == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColors[i].withValues(alpha: i == 2 ? 0.95 : 0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 2 ? 1.8 : 1.0,
      );

      final last = points.last;
      _text(
        canvas,
        _labels[i],
        Offset(xFor(last.dx) + 4, yFor(last.dy) - 6),
        lineColors[i],
        8.5,
        FontWeight.w700,
      );
    }

    if (patientAgeMonths >= startAge && patientAgeMonths <= endAge) {
      final px = xFor(patientAgeMonths.toDouble());
      final py = yFor(patientValue);
      canvas.drawCircle(
        Offset(px, py),
        5.5,
        Paint()..color = const Color(0xFF10B981),
      );
      canvas.drawCircle(
        Offset(px, py),
        8.5,
        Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
    }

    final axisColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    _text(
      canvas,
      '${(startAge / 12).toStringAsFixed(startAge % 12 == 0 ? 0 : 1)}a',
      Offset(left - 4, size.height - 18),
      axisColor,
      8.5,
      FontWeight.w600,
    );
    _text(
      canvas,
      '${(endAge / 12).toStringAsFixed(endAge % 12 == 0 ? 0 : 1)}a',
      Offset(left + plotW - 14, size.height - 18),
      axisColor,
      8.5,
      FontWeight.w600,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size,
    FontWeight weight,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PedGrowthChartPainter oldDelegate) =>
      oldDelegate.indicator != indicator ||
      oldDelegate.sex != sex ||
      oldDelegate.patientAgeMonths != patientAgeMonths ||
      oldDelegate.patientValue != patientValue ||
      oldDelegate.dark != dark;
}

class _PedVitalRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? note;
  final bool last;

  const _PedVitalRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.note,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: _PediatricsVisualScaleR3.sectionLabel,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: _PediatricsVisualScaleR3.body,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: TextStyle(
                    fontSize: _PediatricsVisualScaleR3.micro,
                    color: c.textHint,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Modelo de referência bibliográfica para fármacos pediátricos ───────────
class _PedDrugRef {
  final String type; // 'Diretriz' | 'Estudo' | 'Base de Dados' | 'Protocolo'
  final String source; // Ex: 'American Heart Association (AHA)'
  final String detail; // Ex: 'PALS Provider Manual, 2020'
  final String? doi;
  const _PedDrugRef(
      {required this.type,
      required this.source,
      required this.detail,
      this.doi});
}

// ── Mapa global de referências por fármaco (Apple Guideline 1.4.2) ──────────
const Map<String, List<_PedDrugRef>> _kPedDrugRefs = {
  'Adrenalina IV/IO': [
    _PedDrugRef(
        type: 'Diretriz',
        source: 'American Heart Association (AHA)',
        detail: 'Pediatric Advanced Life Support (PALS) Provider Manual, 2020.',
        doi: null),
    _PedDrugRef(
        type: 'Estudo',
        source: 'Zhang Z, et al.',
        detail:
            'Efficacy and safety of epinephrine in pediatric cardiac arrest: A systematic review. Resuscitation, 2019; 136: 102–108.',
        doi: '10.1016/j.resuscitation.2019.01.023'),
    _PedDrugRef(
        type: 'Base de Dados',
        source: 'Micromedex®',
        detail: 'Epinephrine Injection. Truven Health Analytics, 2024.',
        doi: null),
  ],
  'Amiodarona IV/IO': [
    _PedDrugRef(
        type: 'Diretriz',
        source: 'American Heart Association (AHA)',
        detail:
            'PALS Guidelines 2020 — Antiarrhythmic Therapy in Pediatric Cardiac Arrest.',
        doi: null),
    _PedDrugRef(
        type: 'Base de Dados',
        source: 'Micromedex®',
        detail:
            'Amiodarone Hydrochloride Injection. Truven Health Analytics, 2024.',
        doi: null),
  ],
  'Adenosina IV (TSV)': [
    _PedDrugRef(
        type: 'Diretriz',
        source: 'American Heart Association (AHA)',
        detail:
            'PALS 2020 — Management of Supraventricular Tachycardia in Children.',
        doi: null),
    _PedDrugRef(
        type: 'Estudo',
        source: 'Weindling SN, et al.',
        detail:
            'Duration of complete atrioventricular block after adenosine-induced transient heart block. Am Heart J. 1996;131(6):1129–32.',
        doi: null),
  ],
  'Atropina IV (bradicardia)': [
    _PedDrugRef(
        type: 'Diretriz',
        source: 'American Heart Association (AHA)',
        detail: 'PALS 2020 — Bradycardia Management Algorithm.',
        doi: null),
    _PedDrugRef(
        type: 'Base de Dados',
        source: 'Harriet Lane Handbook',
        detail: 'Atropine. In: Harriet Lane Handbook, 22nd ed. Elsevier, 2021.',
        doi: null),
  ],
  'Glicose 10% IV (hipoglicemia)': [
    _PedDrugRef(
        type: 'Protocolo',
        source: 'WHO / UNICEF',
        detail:
            'Hypoglycaemia management in children. IMCI guidelines, WHO, 2019.',
        doi: null),
    _PedDrugRef(
        type: 'Base de Dados',
        source: 'Micromedex®',
        detail: 'Dextrose 10% Injection. Truven Health Analytics, 2024.',
        doi: null),
  ],
  'Paracetamol VO/VR': [
    _PedDrugRef(
        type: 'Diretriz',
        source: 'SBP / Academia Americana de Pediatria',
        detail:
            'Guideline for use of analgesics/antipyretics in children. Pediatrics, 2011;127(3):580–587.',
        doi: '10.1542/peds.2010-3852'),
    _PedDrugRef(
        type: 'Base de Dados',
        source: 'Micromedex®',
        detail: 'Acetaminophen. Truven Health Analytics, 2024.',
        doi: null),
  ],
  'Ibuprofeno VO': [
    _PedDrugRef(
        type: 'Diretriz',
        source: 'Academia Americana de Pediatria',
        detail:
            'Clinical Report — Fever in Children. Pediatrics, 2011;127(3):580–587.',
        doi: '10.1542/peds.2010-3852'),
    _PedDrugRef(
        type: 'Base de Dados',
        source: 'Harriet Lane Handbook',
        detail:
            'Ibuprofen. In: Harriet Lane Handbook, 22nd ed. Elsevier, 2021.',
        doi: null),
  ],
  'Morfina IV/SC': [
    _PedDrugRef(
        type: 'Diretriz',
        source: 'WHO',
        detail:
            'WHO guidelines on the pharmacological treatment of persisting pain in children with medical illnesses. WHO, 2012.',
        doi: null),
    _PedDrugRef(
        type: 'Base de Dados',
        source: 'Micromedex®',
        detail: 'Morphine Sulfate. Truven Health Analytics, 2024.',
        doi: null),
  ],
  'Tramadol VO/IV': [
    _PedDrugRef(
        type: 'Diretriz',
        source: 'FDA / EMA',
        detail:
            'Tramadol: contraindicated in children <12 years for pain. FDA Drug Safety Communication, 2017.',
        doi: null),
    _PedDrugRef(
        type: 'Base de Dados',
        source: 'Harriet Lane Handbook',
        detail: 'Tramadol. In: Harriet Lane Handbook, 22nd ed. Elsevier, 2021.',
        doi: null),
  ],
  'Salbutamol inalatório (crise)': [
    _PedDrugRef(
        type: 'Diretriz',
        source: 'GINA / SBPT',
        detail:
            'Global Initiative for Asthma (GINA) Report, 2023 — Management of acute asthma in children.',
        doi: null),
    _PedDrugRef(
        type: 'Base de Dados',
        source: 'Micromedex®',
        detail:
            'Albuterol (Salbutamol) Inhalation. Truven Health Analytics, 2024.',
        doi: null),
  ],
};

// ── Badge de linha terapêutica ────────────────────────────────────────────────
enum _TherapeuticLine { first, second, third, none }

/// _PedDoseRow — card premium com dose calculada, badge de linha, contraindicações e referências
class _PedDoseRow extends StatefulWidget {
  final String label, dose;
  final double? weight, mgPerKg;
  final String unit;
  final String? maxDose;
  final Color color;
  final List<String> contraindications;
  final _TherapeuticLine line;
  final String?
      indication; // breve indicação clínica (ex: 'PCR, FV/TV sem pulso')
  final String? warningNote; // nota de atenção clínica rápida

  const _PedDoseRow({
    required this.label,
    required this.dose,
    required this.weight,
    required this.mgPerKg,
    required this.unit,
    required this.maxDose,
    required this.color,
    this.contraindications = const [],
    this.line = _TherapeuticLine.none,
    this.indication,
    this.warningNote,
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
      final maxNum = double.tryParse(widget.maxDose!
          .replaceAll(RegExp(r'[^\d,\.]'), '')
          .replaceAll(',', '.'));
      if (maxNum != null && raw > maxNum) raw = maxNum;
    }
    return raw >= 100
        ? '${raw.toStringAsFixed(0)} ${widget.unit}'
        : '${raw.toStringAsFixed(1).replaceAll('.', ',')} ${widget.unit}';
  }

  // Badge linha terapêutica
  Widget _buildLineBadge() {
    if (widget.line == _TherapeuticLine.none) return const SizedBox.shrink();
    final (label, bg, fg) = switch (widget.line) {
      _TherapeuticLine.first => (
          '1ª linha',
          const Color(0xFFDC2626).withOpacity(0.12),
          const Color(0xFFDC2626)
        ),
      _TherapeuticLine.second => (
          '2ª linha',
          const Color(0xFFD97706).withOpacity(0.12),
          const Color(0xFFD97706)
        ),
      _TherapeuticLine.third => (
          '3ª linha',
          const Color(0xFF6366F1).withOpacity(0.12),
          const Color(0xFF6366F1)
        ),
      _TherapeuticLine.none => ('', Colors.transparent, Colors.transparent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: MedTypography.sectionLabelSize,
              fontWeight: FontWeight.w900,
              color: fg,
              letterSpacing: 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final calcDose = _calcDose();
    final hasContra = widget.contraindications.isNotEmpty;
    final refs = _kPedDrugRefs[widget.label] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: (hasContra || refs.isNotEmpty)
            ? () => setState(() => _expanded = !_expanded)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: c.dark ? Colors.white.withOpacity(0.03) : Colors.white,
            border: Border.all(
              color: _expanded ? widget.color.withOpacity(0.50) : c.border,
              width: _expanded ? 1.5 : 1.0,
            ),
            boxShadow: _expanded
                ? [
                    BoxShadow(
                        color: widget.color.withOpacity(0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header do card ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 0),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Barra colorida de categoria
                Container(
                  width: 3,
                  height: 42,
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Nome + badge linha
                      Row(children: [
                        Expanded(
                            child: Text(widget.label,
                                style: TextStyle(
                                    fontSize: MedTypography.clinicalBodySize,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary))),
                        _buildLineBadge(),
                        if (hasContra || refs.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: c.textHint),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      // Dose por kg + máx
                      Row(children: [
                        Text(widget.dose,
                            style: TextStyle(
                                fontSize: MedTypography.auxiliarySize,
                                fontWeight: FontWeight.w600,
                                color: c.textSecondary)),
                        if (widget.maxDose != null) ...[
                          Text('  ·  máx: ${widget.maxDose}',
                              style: TextStyle(
                                  fontSize: MedTypography.auxiliarySize,
                                  color: c.textHint)),
                        ],
                      ]),
                      if (widget.indication != null) ...[
                        const SizedBox(height: 2),
                        Text(widget.indication!,
                            style: TextStyle(
                                fontSize: MedTypography.microTextSize,
                                color: widget.color.withOpacity(0.8),
                                fontStyle: FontStyle.italic)),
                      ],
                    ])),
                // Dose calculada em destaque
                if (widget.weight != null && widget.mgPerKg != null) ...[
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: widget.color.withOpacity(0.12),
                        border:
                            Border.all(color: widget.color.withOpacity(0.30)),
                      ),
                      child: Text(calcDose,
                          style: TextStyle(
                              fontSize: MedTypography.clinicalBodySize,
                              fontWeight: FontWeight.w900,
                              color: widget.color)),
                    ),
                    const SizedBox(height: 3),
                    Text('dose calc.',
                        style: TextStyle(
                            fontSize: MedTypography.auxiliarySize,
                            color: c.textHint)),
                  ]),
                ],
              ]),
            ),

            const SizedBox(height: 10),

            // ── Painel expandido ──────────────────────────────────
            if (_expanded) ...[
              Divider(height: 1, color: widget.color.withOpacity(0.15)),

              // Nota de atenção rápida
              if (widget.warningNote != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: const Color(0xFFD97706).withOpacity(0.25)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 13, color: Color(0xFFD97706)),
                          const SizedBox(width: 7),
                          Expanded(
                              child: Text(widget.warningNote!,
                                  style: const TextStyle(
                                      fontSize: MedTypography.microTextSize,
                                      color: Color(0xFF7A5F00),
                                      fontWeight: FontWeight.w600,
                                      height: 1.4))),
                        ]),
                  ),
                ),

              // Contraindicações
              if (hasContra)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFDC2626).withOpacity(0.06),
                      border: Border.all(
                          color: const Color(0xFFDC2626).withOpacity(0.22)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.block_rounded,
                                size: 12, color: Color(0xFFDC2626)),
                            const SizedBox(width: 6),
                            const Text('Contraindicações / Precauções',
                                style: TextStyle(
                                    fontSize: MedTypography.microTextSize,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFDC2626),
                                    letterSpacing: 0.2)),
                          ]),
                          const SizedBox(height: 7),
                          ...widget.contraindications.map((ci) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.only(
                                              top: 5, right: 7),
                                          decoration: const BoxDecoration(
                                              color: Color(0xFFDC2626),
                                              shape: BoxShape.circle)),
                                      Expanded(
                                          child: Text(ci,
                                              style: const TextStyle(
                                                  fontSize: MedTypography
                                                      .microTextSize,
                                                  color: Color(0xFFDC2626),
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.4))),
                                    ]),
                              )),
                        ]),
                  ),
                ),

              // Referências locales + evidencia global (Apple Guideline 1.4.2)
              if (refs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.menu_book_rounded,
                              size: 12, color: widget.color.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Text('Referencias y Evidencias',
                              style: TextStyle(
                                  fontSize: MedTypography.microTextSize,
                                  fontWeight: FontWeight.w900,
                                  color: widget.color,
                                  letterSpacing: 0.2)),
                        ]),
                        const SizedBox(height: 8),
                        ...refs.map((ref) =>
                            _PedRefCitation(ref: ref, accent: widget.color)),
                      ]),
                ),

              // Tarjeta de evidencia global (base de datos unificada)
              Builder(builder: (ctx) {
                final globalEv = getGlobalEvidence(widget.label);
                if (globalEv == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: EvidenceCardWidget(ev: globalEv),
                );
              }),

              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 2),
          ]),
        ),
      ),
    );
  }
}

/// Card de citação bibliográfica — usado nas referências por fármaco
class _PedRefCitation extends StatelessWidget {
  final _PedDrugRef ref;
  final Color accent;
  const _PedRefCitation({required this.ref, required this.accent});

  Color get _typeColor {
    switch (ref.type) {
      case 'Diretriz':
        return const Color(0xFF059669);
      case 'Estudo':
        return const Color(0xFF2563EB);
      case 'Base de Dados':
        return const Color(0xFF7C3AED);
      case 'Protocolo':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color:
            c.dark ? Colors.white.withOpacity(0.03) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ícone
        Container(
          padding: const EdgeInsets.all(5),
          margin: const EdgeInsets.only(right: 9),
          decoration: BoxDecoration(
            color: _typeColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(Icons.library_books_rounded, size: 12, color: _typeColor),
        ),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(ref.type,
                  style: TextStyle(
                      fontSize: MedTypography.microTextSize,
                      fontWeight: FontWeight.w900,
                      color: _typeColor,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(width: 7),
            Expanded(
                child: Text(ref.source,
                    style: TextStyle(
                        fontSize: MedTypography.microTextSize,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(ref.detail,
              style: TextStyle(
                  fontSize: MedTypography.sectionLabelSize,
                  color: c.textSecondary,
                  height: 1.35)),
          if (ref.doi != null) ...[
            const SizedBox(height: 3),
            Text('DOI: ${ref.doi}',
                style: TextStyle(
                    fontSize: MedTypography.sectionLabelSize,
                    color: _typeColor,
                    fontWeight: FontWeight.w600)),
          ],
        ])),
      ]),
    );
  }
}

// PEDIATRIC_LAB_REFERENCE_REMOVED_V1_B_R3

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
  static const _kBlueBg = Color(0xFF1D4ED8);
  static const _kBlueBgLt = Color(0xFFEFF6FF); // tema claro

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
        children: List.generate(options.length, (i) {
      final sel = value == i;
      final dotColor = _kColors[i.clamp(0, 3)];
      final isNormal = i == 0;

      return GestureDetector(
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 6),
          padding: EdgeInsets.fromLTRB(
              14, sel && isNormal ? 12 : 10, 14, sel && isNormal ? 12 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Selecionado normal → azul sólido; outros → cor da severidade
            color: sel
                ? (isNormal
                    ? _kBlueBg.withOpacity(0.12)
                    : dotColor.withOpacity(0.10))
                : c.surface,
            border: Border.all(
              color:
                  sel ? dotColor.withOpacity(isNormal ? 0.70 : 0.50) : c.border,
              width: sel ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Ícone check / círculo
                Container(
                  width: 18,
                  height: 18,
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
                Expanded(
                    child: Text(options[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                          color: sel ? dotColor : c.textSecondary,
                        ))),
                // Badge de pontuação
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: sel
                        ? dotColor.withOpacity(0.15)
                        : c.border.withOpacity(0.4),
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
              if (sel && isNormal && referenceLines.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _kBlueBg.withOpacity(0.08),
                    border: Border.all(color: _kBlueBg.withOpacity(0.20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.info_outline_rounded,
                            size: 11, color: _kBlueBg.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text('Valores de referência normais',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: _kBlueBg.withOpacity(0.8),
                            )),
                      ]),
                      const SizedBox(height: 5),
                      ...referenceLines.map((line) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: _kBlueBg.withOpacity(0.6))),
                                Expanded(
                                    child: Text(line,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: _kBlueBg.withOpacity(0.85),
                                          height: 1.4,
                                        ))),
                              ],
                            ),
                          )),
                    ],
                  ),
                )
              ],
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
  const _ResultTile(
      {required this.label,
      this.value,
      this.unit,
      this.note,
      this.full = false});

  @override
  Widget build(BuildContext context) {
    final hasVal = value != null && value != '—';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final noteColor = (note ?? '').startsWith('BAIXO') ||
            (note ?? '').startsWith('ATENÇÃO') ||
            (note ?? '').startsWith('GRAVE') ||
            (note ?? '').startsWith('CRÍTICO') ||
            (note ?? '').startsWith('FALÊNCIA') ||
            (note ?? '').startsWith('ALTO') ||
            (note ?? '').startsWith('DÉFICIT')
        ? const Color(0xFFCC2222)
        : (note ?? '').startsWith('RISCO') ||
                (note ?? '').contains('↑') ||
                (note ?? '').contains('Hipercalcemia')
            ? const Color(0xFFB45309)
            : (dark ? const Color(0xFF34D399) : const Color(0xFF065F46));

    // Cores adaptativas ao tema:
    //  Modo claro: fundo verde-menta suave (0xFFECFDF5) — padrão original
    //  Modo escuro: fundo verde escuro sutil (0xFF0D2B1E) — hierarquia clara
    final tileBg = hasVal
        ? (dark ? const Color(0xFF0D2B1E) : const Color(0xFFECFDF5))
        : AppColors.of(context).surface;
    final tileBorder = hasVal
        ? (dark ? const Color(0xFF1A4D35) : const Color(0xFFBBF7D0))
        : AppColors.of(context).border;
    // Valor numérico: no dark mode usa verde-menta vibrante para destacar
    final valueColor = hasVal
        ? (dark ? const Color(0xFF6EE7B7) : AppColors.of(context).textPrimary)
        : (dark ? const Color(0xFF4B5563) : const Color(0xFFA8B2C1));

    return Container(
      width: full ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: tileBg,
        border: Border.all(color: tileBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.of(context).textHint)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // AUDIT 2.1: Flexible + overflow=ellipsis previne RenderFlex overflow
          // quando valor numérico é exibido em Row com Expanded-siblings.
          // Sem overflow handler, valores longos (ex: "1234,56") num Row de
          // dois tiles causa layout exception no iOS/Android (Impeller/Skia).
          Flexible(
              child: Text(value ?? '—',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: valueColor,
                      letterSpacing: -0.5))),
          if (unit != null && unit!.isNotEmpty && hasVal) ...[
            const SizedBox(width: 3),
            Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(unit!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 10, color: AppColors.of(context).textHint))),
          ],
        ]),
        if (note != null && note!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(note!,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: noteColor,
                  height: 1.3)),
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
        color: Colors.white.withOpacity(0.48),
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
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFFF8E7),
          border: Border.all(color: const Color(0xFFFFE0A0))),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7A5F00),
              height: 1.4)),
    );
  }
}

class _RenalGuideRow extends StatelessWidget {
  final String label, status;
  final bool ok, warn, danger;
  const _RenalGuideRow(
      {required this.label,
      required this.status,
      this.ok = false,
      this.warn = false,
      this.danger = false});

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFFFF0F0)
        : warn
            ? const Color(0xFFFFF8E7)
            : ok
                ? const Color(0xFFECFDF5)
                : const Color(0xFFF8F8F8);
    final border = danger
        ? const Color(0xFFFFCCCC)
        : warn
            ? const Color(0xFFFFE0A0)
            : ok
                ? const Color(0xFFBBF7D0)
                : kToolBorder;
    final txtColor = danger
        ? const Color(0xFFCC2222)
        : warn
            ? const Color(0xFFB45309)
            : ok
                ? const Color(0xFF065F46)
                : AppColors.of(context).textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: bg,
            border: Border.all(color: border)),
        child: Row(children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: txtColor))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(status,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: txtColor,
                      height: 1.3))),
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
  while (e >= 1) {
    result *= b;
    e--;
  }
  if (e > 0) result *= _powFrac(base, e);
  return result;
}

double _powFrac(double base, num frac) => _exp(frac * _ln(base));
double _ln(double x) {
  if (x <= 0) return double.negativeInfinity;
  double s = 0, b = (x - 1) / (x + 1);
  double t = b;
  for (int i = 1; i < 100; i += 2) {
    s += t / i;
    t *= b * b;
  }
  return 2 * s;
}

double _exp(double x) {
  double s = 1, t = 1;
  for (int i = 1; i < 100; i++) {
    t *= x / i;
    s += t;
    if (t.abs() < 1e-15) break;
  }
  return s;
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÃO DE FONTES ACADÉMICAS — aparece no FINAL do scroll da aba Referência.
// Substituiu a barra fixa inferior — libera 100% do espaço útil de leitura.
// ─────────────────────────────────────────────────────────────────────────────
class _SourcesButton extends StatelessWidget {
  final bool isEs;
  const _SourcesButton({required this.isEs});

  static const _kSourcesUrl =
      'https://www.promedcases.com/fontes-e-referencias';
  static const _kSourcesTitle = 'Fontes e Referências — MedCases Pro';
  static const _kSourcesTitleEs = 'Fuentes y Referencias — MedCases Pro';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // BUILD 323 — MANDATO 2: in-app WebView encapsulado, sem ejetar para browser.
      // MANDATO 1: label semântico exibido, URL nunca visível na UI.
      onTap: () {
        AppHaptics.light(context);
        openAcademicSourceSecurely(
          context,
          isEs ? _kSourcesTitleEs : _kSourcesTitle,
          _kSourcesUrl,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D6B57).withOpacity(0.07),
          border: Border.all(
            color: const Color(0xFF0D6B57).withOpacity(0.22),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 15,
                  color: Color(0xFF0D6B57),
                ),
                const SizedBox(width: 8),
                Text(
                  isEs ? 'Ver Fuentes Académicas' : 'Ver Fontes Acadêmicas',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D6B57),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'AHA · ACC · WHO · PubMed · UpToDate · KDIGO',
              style: TextStyle(
                fontSize: 10,
                color: const Color(0xFF0D6B57).withOpacity(0.6),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BUILD 445-CROSS-CALC-STATE — PASSO 3: Dialog de Retorno às Ferramentas
//
// Aparece quando o médico RETORNA à seção de Ferramentas e havia dados clínicos
// preenchidos em memória (ToolsStateProvider.hasPendingData == true).
//
// Design: dark-first, ciano + vermelho, dois botões estilizados.
//   Botão 1 (Outlined vermelho)     → "Limpar Tudo"   → tp.clearAll()
//   Botão 2 (Filled ciano)          → "Usar Anteriores" → mantém estado
// ══════════════════════════════════════════════════════════════════════════════

// Paleta local do dialog
const _kDlgBg = Color(0xFF1A1D23);
const _kDlgBorder = Color(0xFF2D3340);
const _kDlgCyan = Color(0xFF0D6B57);
const _kDlgRed = Color(0xFFEF4444);
const _kDlgSub = Color(0xFF8B9BB4);

/// Exibe o dialog nativo de retorno com animação scale + fade.
Future<void> _showReturnDataDialog({
  required BuildContext context,
  required bool isEs,
  required bool dark,
  required ToolsStateProvider tp,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (_, anim, __, child) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        ),
        child: FadeTransition(
          opacity: anim,
          child: child,
        ),
      );
    },
    pageBuilder: (dialogCtx, _, __) {
      final bg = dark ? _kDlgBg : Colors.white;
      final txt = dark ? Colors.white : const Color(0xFF0F1116);
      final sub = dark ? _kDlgSub : const Color(0xFF64748B);
      final border = dark ? _kDlgBorder : const Color(0xFFE2E8F0);

      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _kDlgCyan.withValues(alpha: dark ? 0.25 : 0.20),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.40 : 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Ícone + título ───────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kDlgCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('🧪', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEs
                            ? 'Datos Anteriores Detectados'
                            : 'Dados Anteriores Detectados',
                        style: TextStyle(
                          color: txt,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Divider ───────────────────────────────────────────────────
                Container(height: 1, color: border),
                const SizedBox(height: 14),

                // ── Mensagem ──────────────────────────────────────────────────
                Text(
                  isEs
                      ? '¿Desea reaprovechar los datos clínicos completados recientemente o prefiere comenzar un nuevo cálculo desde cero?'
                      : 'Deseja reaproveitar os dados clínicos preenchidos recentemente ou prefere iniciar um novo cálculo do zero?',
                  style: TextStyle(
                    color: sub,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),

                // ── Botões ────────────────────────────────────────────────────
                Row(
                  children: [
                    // Botão 1: Limpar Tudo (outlined vermelho)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          tp.clearAll();
                          Navigator.of(dialogCtx).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kDlgRed,
                          side: const BorderSide(color: _kDlgRed, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isEs ? 'Limpiar Todo' : 'Limpar Tudo',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Botão 2: Usar Dados Anteriores (filled ciano)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Mantém estado — apenas fecha o dialog
                          Navigator.of(dialogCtx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kDlgCyan,
                          foregroundColor: const Color(0xFF0F1116),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isEs ? 'Usar Anteriores' : 'Usar Anteriores',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
