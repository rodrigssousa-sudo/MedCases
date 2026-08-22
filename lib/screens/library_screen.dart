import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/medcases_webview_screen.dart'; // BUILD 323 — MANDATO 2
import '../providers/app_provider.dart';
import '../main.dart' show MainShell; // SUPER ORDEM 313: pendingTab fallback
import '../services/firestore_service.dart';
import '../models/guide_model.dart';
import '../models/protocol_model.dart';
import '../widgets/common_widgets.dart' show MedBreakpoints;
import '../home_v2/theme/home_v2_palette.dart';
import '../home_v2/components/common/home_v2_press_surface.dart';
import 'protocols_screen.dart' show openSimulationProtocolPage;

// MEDCASES_SIMULATION_VISUAL_STANDARD_V1_R1
// MEDCASES_SIMULATION_DETAIL_CONTEXT_V1_R2
// Paleta dark unificada — verde-escuro legacy removido (PR #65)
const _kGreen = Color(0xFF075f45); // mantido apenas para textos/acentos ativos

// ─────────────────────────────────────────────────────────────────────────────
// LIBRARY SCREEN — Biblioteca Clínica
// 2 abas: Guias PDF · Casos de Estudo
// Apple App Store Compliance: terminologia estritamente educacional/pedagógica.
// Nenhuma aba ou string usa "Protocolo" como rótulo navegável.
// ─────────────────────────────────────────────────────────────────────────────
enum ClinicalLearningDestination {
  guide,
  simulation,
}

class ClinicalGuideScreen extends StatelessWidget {
  const ClinicalGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LibraryScreen(
      destination: ClinicalLearningDestination.guide,
    );
  }
}

class ClinicalSimulationScreen extends StatelessWidget {
  const ClinicalSimulationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LibraryScreen(
      destination: ClinicalLearningDestination.simulation,
    );
  }
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.destination,
  });

  final ClinicalLearningDestination destination;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // 2 abas: índice 0 = Guias PDF, índice 1 = Casos de Estudo

  final _searchCtrl = TextEditingController();
  String _search = '';
  String _category = 'Todos';

  StreamSubscription<List<GuideModel>>? _sub;
  List<GuideModel> _guides = [];
  bool _loading = true;
  String _guidesError = '';

  void _log(String message) {
    if (kDebugMode) debugPrint('[LibraryScreen] $message');
  }

  void _syncCategoryWithData() {
    if (_category == 'Todos') return;
    final exists = _guides.any((g) => g.category == _category);
    if (!exists) _category = 'Todos';
  }

  Future<void> _refreshGuides({
    bool forceRemote = false,
    String reason = 'manual',
    bool showLoader = false,
  }) async {
    _log(
        'refresh start reason=$reason forceRemote=$forceRemote kIsWeb=$kIsWeb');
    if (mounted && showLoader) {
      setState(() {
        _loading = true;
        _guidesError = '';
      });
    }
    try {
      final list = await FirestoreService.loadPublishedGuides(
        forceRemote: forceRemote,
      ).timeout(
        const Duration(seconds: 18),
        onTimeout: () => throw TimeoutException(
          'Library guides refresh timeout after 18s ($reason)',
        ),
      );
      final serviceError = FirestoreService.lastGuidesErrorMessage;
      if (!mounted) return;
      setState(() {
        if (list.isNotEmpty || _guides.isEmpty) {
          _guides = list;
        }
        _guidesError =
            (_guides.isEmpty && serviceError.isNotEmpty) ? serviceError : '';
        _syncCategoryWithData();
        _loading = false;
      });
      _log(
          'refresh done reason=$reason count=${list.length} error="$serviceError"');
    } catch (e) {
      _log('refresh failed reason=$reason error=$e');
      if (!mounted) return;
      setState(() {
        _guidesError = e.toString();
        _loading = false;
      });
    }
  }

  void _subscribeGuidesStream() {
    _log('subscribe stream start kIsWeb=$kIsWeb');
    _sub?.cancel();
    _sub = FirestoreService.guidesStream().timeout(
      const Duration(seconds: 25),
      onTimeout: (sink) {
        sink.addError(
          TimeoutException('Library guides stream timeout: no events in 25s'),
        );
      },
    ).listen((list) {
      _log('stream event count=${list.length}');
      if (!mounted) return;
      setState(() {
        if (list.isNotEmpty || _guides.isEmpty) {
          _guides = list;
        }
        _guidesError = (_guides.isEmpty &&
                FirestoreService.lastGuidesErrorMessage.isNotEmpty)
            ? FirestoreService.lastGuidesErrorMessage
            : '';
        _syncCategoryWithData();
        _loading = false;
      });
    }, onError: (Object error, StackTrace stackTrace) async {
      _log('stream error=$error');
      if (mounted) {
        setState(() {
          _guidesError = error.toString();
          _loading = false;
        });
      }
      await _refreshGuides(
        forceRemote: true,
        reason: 'stream-error',
      );
    });
  }

  Future<void> _handleManualRefresh() async {
    _log('manual refresh requested');
    await FirestoreService.clearPublishedGuidesCache(
        reason: 'manual-refresh-button');
    await _refreshGuides(
      forceRemote: true,
      reason: 'manual-refresh-button',
      showLoader: true,
    );
    if (!mounted) return;
    _subscribeGuidesStream();
  }

  Future<void> _initGuides() async {
    _log('init start kIsWeb=$kIsWeb');
    try {
      try {
        final cacheCleared =
            await FirestoreService.clearPublishedGuidesCacheOnFirstOpen();
        _log('init first-open cacheCleared=$cacheCleared');
      } catch (e) {
        _log('error clear cache first open: $e');
      }

      final cached = await FirestoreService.loadCachedPublishedGuides()
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => const <GuideModel>[],
          )
          .catchError((_) => const <GuideModel>[]);

      if (mounted && cached.isNotEmpty) {
        setState(() {
          _guides = cached;
          _guidesError = '';
          _syncCategoryWithData();
          _loading = false;
        });
        _log('init cache preload count=${cached.length}');
      }
    } catch (e) {
      _log('critical error in _initGuides: $e');
    } finally {
      try {
        await _refreshGuides(forceRemote: true, reason: 'init-fallback');
      } catch (e) {
        _log('init fallback refresh failed: $e');
      }

      try {
        if (mounted) _subscribeGuidesStream();
      } catch (e) {
        _log('init stream subscribe failed: $e');
      }

      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.destination == ClinicalLearningDestination.guide) {
      _initGuides();
      _searchCtrl.addListener(() {
        if (mounted) {
          setState(() => _search = _searchCtrl.text.toLowerCase());
        }
      });
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GuideModel> get _filtered {
    return _guides.where((g) {
      final matchCat = _category == 'Todos' || g.category == _category;
      final matchText = _search.isEmpty ||
          g.title.toLowerCase().contains(_search) ||
          g.description.toLowerCase().contains(_search) ||
          g.authors.toLowerCase().contains(_search) ||
          g.category.toLowerCase().contains(_search) ||
          g.year.toLowerCase().contains(_search);
      return matchCat && matchText;
    }).toList();
  }

  List<String> get _categories {
    final cats = {'Todos', ..._guides.map((g) => g.category)};
    return cats.toList();
  }

  // BUILD 323 — MANDATO 2: abre PDF/URL da diretriz in-app (WebView encapsulado).
  // MANDATO 1: título semântico (g.title) exibido — URL nunca visível na UI.
  void _openPdf(GuideModel g) {
    if (g.pdfUrl.isEmpty) return;
    FirestoreService.incrementGuideDownload(g.id);
    openAcademicSourceSecurely(
      context,
      g.title,
      g.pdfUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';
    final isSimulation =
        widget.destination == ClinicalLearningDestination.simulation;
    final bg = dark
        ? const Color(0xFF1A1D23)
        : const Color(0xFFECF1F3);
    final filtered = _filtered;
    final isDesktop = MedBreakpoints.of(context).isDesktop;

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TOPBAR BLEED — Stack com Positioned negativo.
    //
    // CONTEXTO: MainShell._buildMobileShell() aplica Padding(top:statusBarH)
    // para as abas 3/4/5 (History/Tools/Library) antes do IndexedStack.
    // Isso desloca a tela para baixo — a topbar fica ABAIXO da status bar.
    //
    // SOLUÇÃO: Stack com Positioned(top: -topPad) sobe o Container da topbar
    // para trás da status bar física. topPad lido via View.of() — imune ao
    // MediaQuery.removePadding do MainShell.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final double topPad =
        View.of(context).padding.top / View.of(context).devicePixelRatio;
    const double topbarHeight = 48.0;

    return ColoredBox(
      color: bg,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Corpo: espaço reservado + TabRow + conteúdo ──────────────
          Column(
            children: [
              // Reserva espaço para a topbar (fica por baixo do Positioned)
              SizedBox(height: topbarHeight),
              // BUILD 331: Seletor de abas desacoplado da Topbar — fica no corpo
              // PERF-FIX: RepaintBoundary isola a lista de guias da topbar.
              // Scroll, filtro de categoria e carregamento não invalidam
              // o layer do background da topbar no Impeller.
              Expanded(
                child: RepaintBoundary(
                  child: widget.destination == ClinicalLearningDestination.guide
                      ? _GuidesTab(
                          dark: dark,
                          isEs: isEs,
                          loading: _loading,
                          filtered: filtered,
                          categories: _categories,
                          selectedCategory: _category,
                          searchCtrl: _searchCtrl,
                          errorMessage: _guidesError,
                          onCategorySelect: (c) =>
                              setState(() => _category = c),
                          onOpen: _openPdf,
                          onRetry: _handleManualRefresh,
                        )
                      : _CasosDeEstudoTab(dark: dark, isEs: isEs, p: p),
                ), // RepaintBoundary
              ),
            ],
          ),

          // ── CAMADA 1: Fundo — sobe para trás da status bar ──────────
          Positioned(
            top: -topPad,
            left: 0,
            right: 0,
            height: topPad + topbarHeight,
            child: _LibraryTopbarBg(
              /* MEDCASES_SIMULATION_VISUAL_STANDARD_V1_R1 */
              isDark: Theme.of(context).brightness == Brightness.dark,
              flatSimulation: isSimulation,
            ),
          ),

          // ── CAMADA 2: Conteúdo interativo — permanece em y=0 ─────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topbarHeight,
            child: _LibraryTopbarContent(
              title: widget.destination == ClinicalLearningDestination.guide
                  ? (isEs ? 'GUÍA CLÍNICA' : 'GUIA CLÍNICO')
                  : (isEs ? 'SIMULACIÓN' : 'SIMULAÇÃO'),
              dark: dark,
              isEs: isEs,
              isDesktop: isDesktop,
              canonicalHomeStyle: true,
              onRefreshGuides:
                  widget.destination == ClinicalLearningDestination.guide &&
                          isDesktop
                      ? _handleManualRefresh
                      : null,
              refreshing: isDesktop ? _loading : false,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 331 — TOPBAR BIBLIOTECA
// Geometria estrita: PreferredSize 48px, SafeArea(bottom:false), SizedBox(48),
// padding h:12, fundo sólido adaptativo, border 0.5px, BoxShadow blur:6.
// Título "BIBLIOTECA" centralizado via Stack — sem desvio do botão de voltar.
// ─────────────────────────────────────────────────────────────────────────────
// ── Fundo da topbar Biblioteca (gradiente, sem conteúdo interativo) ──────────
class _LibraryTopbarBg extends StatelessWidget {
  final bool isDark;
  final bool flatSimulation;

  const _LibraryTopbarBg({
    required this.isDark,
    this.flatSimulation = false,
  });

  @override
  Widget build(BuildContext context) {
    if (flatSimulation) {
      // MEDCASES_SIMULACAO_HOME_TOPBAR_V1_B_R0
      // Simulação: replica a topbar canônica da Home sem alterar o título da tela.
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF252930).withOpacity(0.70)
                  : Colors.white.withOpacity(0.70),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE2E7EC),
                  width: 0.7,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // MEDCASES_GUIA_CLINICO_HOME_TOPBAR_V1_B_R0
    // Guia Clínico: replica a topbar canônica da Home sem copiar "MEDCASES PRO".
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF252930).withOpacity(0.70)
                : Colors.white.withOpacity(0.70),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFE2E7EC),
                width: 0.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Conteúdo interativo da topbar Biblioteca (botões, título) ────────────────
class _LibraryTopbarContent extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final bool isDesktop;
  final bool canonicalHomeStyle;
  final String title;
  final VoidCallback? onRefreshGuides;
  final bool refreshing;

  const _LibraryTopbarContent({
    required this.title,
    required this.dark,
    required this.isEs,
    required this.isDesktop,
    required this.canonicalHomeStyle,
    this.onRefreshGuides,
    this.refreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── CENTER: título BRANCO ─────────────────────────────────────
          Text(
            title,
            style: TextStyle(
              fontSize: canonicalHomeStyle ? 16 : 20,
              fontWeight:
                  canonicalHomeStyle ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: canonicalHomeStyle ? 1.2 : 0.4,
              color: /* MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R16_R5_R13 */
                  Theme.of(context).brightness == Brightness.dark
                      ? (Colors.white)
                      : (const Color(0xFF05070A)),
            ),
          ),
          // ── LEFT: botão de voltar ─────────────────────────────────────
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
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: /* MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R16_R5_R13 */
                      Theme.of(context).brightness == Brightness.dark
                          ? (Colors.white)
                          : (const Color(0xFF05070A)),
                ),
              ),
            ),
          ),
          // ── RIGHT: botão refresh (desktop only) ───────────────────────
          if (isDesktop && onRefreshGuides != null)
            Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: isEs ? 'Actualizar guías' : 'Atualizar guias',
                child: GestureDetector(
                  onTap: refreshing ? null : onRefreshGuides,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: refreshing
                        ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 331 — SELETOR DE ABAS (desacoplado da Topbar)
// Posição: logo abaixo da Topbar, no topo do corpo rolável.
// Cores adaptativas: dark → texto branco; light → texto preto.
// ─────────────────────────────────────────────────────────────────────────────
class _LibTabRow extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final TabController tabCtrl;

  const _LibTabRow({
    required this.dark,
    required this.isEs,
    required this.tabCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1D23) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: _LibFlatTab(
                label: isEs ? 'GUÍAS PDF' : 'GUIAS PDF',
                index: 0,
                tabCtrl: tabCtrl,
                dark: dark,
              ),
            ),
            _LibTabDivider(dark: dark),
            Expanded(
              child: _LibFlatTab(
                label: isEs ? 'CASOS DE ESTUDIO' : 'CASOS DE ESTUDO',
                index: 1,
                tabCtrl: tabCtrl,
                dark: dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS: tab flat minimalista + divisória fio — BUILD 331
// Cores adaptativas: dark → branco/branco60; light → preto/preto45.
// ─────────────────────────────────────────────────────────────────────────────

/// Divisória vertical fio entre as abas — 1×14px, adaptativa dark/light.
class _LibTabDivider extends StatelessWidget {
  final bool dark;
  const _LibTabDivider({this.dark = true});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 14,
      color: dark ? Colors.white24 : Colors.black12,
    );
  }
}

/// Tab flat minimalista — underline ciano quando ativa, texto dark/light.
class _LibFlatTab extends StatefulWidget {
  final String label;
  final int index;
  final TabController tabCtrl;
  final bool dark;
  const _LibFlatTab({
    required this.label,
    required this.index,
    required this.tabCtrl,
    this.dark = true,
  });
  @override
  State<_LibFlatTab> createState() => _LibFlatTabState();
}

class _LibFlatTabState extends State<_LibFlatTab> {
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
    // BUILD 331: dark → branco; light → preto — máxima hierarquia de leitura
    final activeColor = widget.dark ? Colors.white : const Color(0xFF0F1116);
    final inactiveColor = widget.dark
        ? Colors.white60
        : const Color(0xFF0F1116).withOpacity(0.45);
    return GestureDetector(
      onTap: () => widget.tabCtrl.animateTo(widget.index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: isActive
                ? const BorderSide(color: Color(0xFF00E5FF), width: 2.0)
                : BorderSide.none,
          ),
        ),
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? activeColor : inactiveColor,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ABA 0 — Guias PDF (inalterada)
// ─────────────────────────────────────────────────────────────────────────────
class _GuidesTab extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final bool loading;
  final List<GuideModel> filtered;
  final List<String> categories;
  final String selectedCategory;
  final TextEditingController searchCtrl;
  final String errorMessage;
  final ValueChanged<String> onCategorySelect;
  final ValueChanged<GuideModel> onOpen;
  final VoidCallback onRetry;

  const _GuidesTab({
    required this.dark,
    required this.isEs,
    required this.loading,
    required this.filtered,
    required this.categories,
    required this.selectedCategory,
    required this.searchCtrl,
    required this.errorMessage,
    required this.onCategorySelect,
    required this.onOpen,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // MEDCASES_GUIA_CLINICA_COMPACT_CLINICAL_HUB_V1_B_R0
    final hasSearch = searchCtrl.text.isNotEmpty;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final primary = dark ? Colors.white : const Color(0xFF05070A);
    final secondary =
        dark ? const Color(0xFFCBD5E1) : const Color(0xFF59636E);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final border =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    final bodySliver = loading
        ? const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(
                color: _kGreen,
                strokeWidth: 2,
              ),
            ),
          )
        : filtered.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: errorMessage.isNotEmpty && !hasSearch
                    ? _GuideErrorState(
                        dark: dark,
                        isEs: isEs,
                        message: errorMessage,
                        onRetry: onRetry,
                      )
                    : _EmptyState(
                        dark: dark,
                        isEs: isEs,
                        hasSearch: hasSearch,
                      ),
              )
            : SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  4,
                  4,
                  4,
                  114 + safeBottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _GuideCard(
                      guide: filtered[i],
                      dark: dark,
                      onOpen: () => onOpen(filtered[i]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              );

    return CustomScrollView(
      primary: false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 3),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: searchCtrl,
                textInputAction: TextInputAction.search,
                scrollPadding: const EdgeInsets.only(bottom: 16),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                style: TextStyle(
                  color: primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: surface,
                  hintText: isEs
                      ? 'Buscar patología, guía o especialidad'
                      : 'Buscar patologia, guia ou especialidade',
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: secondary.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: secondary,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: border,
                      width: 0.7,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF008F66),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (categories.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _CategoryFilter(
                categories: categories,
                selected: selectedCategory,
                dark: dark,
                isEs: isEs,
                onSelect: (value) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  onCategorySelect(value);
                },
              ),
            ),
          ),
        if (!loading && filtered.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 2),
              child: Row(
                children: [
                  Text(
                    isEs ? 'GUÍAS' : 'GUIAS',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length}',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        bodySliver,
      ],
    );
  }
}


class _CasosDeEstudoTab extends StatefulWidget {
  final bool dark;
  final bool isEs;
  final AppProvider p;
  const _CasosDeEstudoTab(
      {required this.dark, required this.isEs, required this.p});

  @override
  State<_CasosDeEstudoTab> createState() => _CasosDeEstudoTabState();
}

class _CasosDeEstudoTabState extends State<_CasosDeEstudoTab> {
  // Dois sub-segmentos dentro da aba Casos de Estudo:
  // 0 = "Simulações" (casos clínicos narrativos do ProtocolModel com IDs de caso)
  // 1 = "Fluxos" (todos os demais itens da base: fluxos simulados por especialidade)
  int _segment = 0;

  // ── IDs que são "Casos Clínicos Narrativos" (mantidos da lógica original) ──
  static const Set<String> _casoNarrativoIds = {
    'caso_enxaqueca_aura', 'caso_avc_isquemico', 'caso_status_epilepticus',
    'caso_stemi', 'caso_icc_descompensada', 'caso_tep_alto_risco',
    'caso_pac_grave',
    'caso_cistite_aguda', 'caso_itu_recorrente', 'caso_sepse_idoso',
    'caso_cetoacidose_diabetica', 'caso_anafilaxia_grave', 'caso_hda_varicosa',
    'pancreatitis_aguda_005', 'diarrea_aguda_009', 'hda_ulcera_peptica_013',
    'hdb_sangrado_rectal_014', 'diverticulitis_aguda_015',
    'sindrome_ascitico_debut_016', 'sindrome_ascitico_edematoso_017',
    'hepatitis_b_aguda_detallada_2026', 'hepatitis_c_cronica_detallada_2026',
    'gripe_influenza_010',
    'rinosinusitis_aguda_007', 'faringitis_estreptococica_008',
    'faringitis_viral_011', 'faringitis_bacteriana_012',
    // IDs que antes figuravam apenas na aba Protocolos — agora absorbidos aqui
    'iam_congestao', 'choque_cardiogenico', 'anafilaxia', 'tpsv', 'fa_aguda',
    'crise_hipertensiva', 'avc_hemorragico', 'asma_grave', 'dpoc_exacerbacao',
    'tep_agudo', 'sepse', 'cad_shh', 'pcr_adulto', 'hda_varizeal',
    'avc_isquemico', 'status_epilepticus', 'meningite_bacteriana',
    'cetoacidose_diabetica', 'tromboembolismo_pulmonar', 'pneumonia_grave',
    'choque_septico_avancado', 'hiperpotassemia_grave', 'intoxicacao_exogena',
    'pancreatite_aguda_grave', 'hda_nao_varicosa', 'lesao_renal_aguda',
    'coagulacao_intravascular', 'politrauma_atls', 'eclampsia_hellp',
    'crise_adrenal', 'agitacao_psicomotora', 'neutropenia_febril',
    'pcr_pediatrica', 'bronquiolite_aguda', 'laringite_estridulosa',
    'intox_paracetamol', 'intox_opioides', 'crise_tireotoxica',
    'hipoglicemia_grave', 'apendicite_aguda',
    'iam_supra', 'crise_convulsiva', 'intoxicacao_overdose',
  };

  // ── Grupos para sub-segmento "Simulações" (casos narrativos) ─────────────
  // BUILD 331: cores dark premium — sem pastéis, tema escuro MedCases Pro.
  // color       = fundo do card (escuro profundo adaptativo)
  // borderColor = borda fina sutil com accent da especialidade
  // iconColor   = acento vibrante para ícone, título e subtítulo
  static const List<_GrupoConfig> _gruposSimulacao = [
    _GrupoConfig(
      icon: Icons.psychology_outlined,
      titlePt: 'Neurologia',
      titleEs: 'Neurología',
      color: Color(0xFF1E1A2E), // dark roxo profundo
      borderColor: Color(0xFF4A3880), // roxo médio sutil
      iconColor: Color(0xFFA78BFA), // violeta lavanda vibrante
      ids: {
        'caso_enxaqueca_aura',
        'caso_avc_isquemico',
        'caso_status_epilepticus'
      },
    ),
    _GrupoConfig(
      icon: Icons.favorite_outline_rounded,
      titlePt: 'Cardiologia & Pneumologia',
      titleEs: 'Cardiología & Neumología',
      color: Color(0xFF1F1419), // dark vermelho profundo
      borderColor: Color(0xFF7A2035), // bordô sutil
      iconColor: Color(0xFFFC8181), // vermelho coral vibrante
      ids: {
        'caso_stemi',
        'caso_icc_descompensada',
        'caso_tep_alto_risco',
        'caso_pac_grave'
      },
    ),
    _GrupoConfig(
      icon: Icons.biotech_outlined,
      titlePt: 'Infectologia, Emergência & Metabólico',
      titleEs: 'Infectología, Emergencia & Metabólico',
      color: Color(0xFF121F19), // dark verde profundo
      borderColor: Color(0xFF1A5E38), // verde escuro médico
      iconColor: Color(0xFF34D399), // verde esmeralda clínico
      ids: {
        'caso_cistite_aguda',
        'caso_itu_recorrente',
        'caso_sepse_idoso',
        'caso_cetoacidose_diabetica',
        'caso_anafilaxia_grave',
        'caso_hda_varicosa',
      },
    ),
    _GrupoConfig(
      icon: Icons.local_hospital_outlined,
      titlePt: 'Gastroenterologia & Hepatologia',
      titleEs: 'Gastroenterología & Hepatología',
      color: Color(0xFF1C1A14), // dark âmbar profundo
      borderColor: Color(0xFF6B5500), // dourado escuro
      iconColor: Color(0xFFFBBF24), // âmbar dourado
      ids: {
        'pancreatitis_aguda_005',
        'diarrea_aguda_009',
        'hda_ulcera_peptica_013',
        'hdb_sangrado_rectal_014',
        'diverticulitis_aguda_015',
        'sindrome_ascitico_debut_016',
        'sindrome_ascitico_edematoso_017',
      },
    ),
    _GrupoConfig(
      icon: Icons.science_outlined,
      titlePt: 'Hepatites Virais & Gripe',
      titleEs: 'Hepatitis Virales & Gripe',
      color: Color(0xFF141E1C), // dark teal profundo
      borderColor: Color(0xFF1A5E55), // teal escuro
      iconColor: Color(0xFF2DD4BF), // teal menta brilhante
      ids: {
        'hepatitis_b_aguda_detallada_2026',
        'hepatitis_c_cronica_detallada_2026',
        'gripe_influenza_010',
      },
    ),
    _GrupoConfig(
      icon: Icons.hearing_outlined,
      titlePt: 'ORL & Medicina Geral',
      titleEs: 'ORL & Medicina General',
      color: Color(0xFF141820), // dark azul profundo
      borderColor: Color(0xFF1E3A6E), // azul médico sutil
      iconColor: Color(0xFF60A5FA), // azul céu brilhante
      ids: {
        'rinosinusitis_aguda_007',
        'faringitis_estreptococica_008',
        'faringitis_viral_011',
        'faringitis_bacteriana_012',
      },
    ),
  ];

  // ── Categorias para sub-segmento "Fluxos Simulados" ──────────────────────
  // Classificação dinâmica por keywords no id — igual à lógica anterior
  static const _catDefs = [
    ('Todos', 'Todos', Icons.apps_rounded, <String>[]),
    (
      'Emergências',
      'Emergencias',
      Icons.emergency_rounded,
      <String>[
        'pcr',
        'anafilaxia',
        'sepse',
        'choque',
        'tep_agudo',
        'tromboembolismo_pulmonar',
        'politrauma',
        'caso_anafilaxia',
        'caso_tep',
        'caso_stemi',
        'caso_sepse',
      ]
    ),
    (
      'Cardio / Neuro',
      'Cardio / Neuro',
      Icons.favorite_rounded,
      <String>[
        'iam',
        'fa_aguda',
        'tpsv',
        'hipertensiva',
        'avc',
        'status_epilepticus',
        'caso_avc',
        'caso_icc',
        'caso_status_epilep',
        'caso_enxaqueca',
      ]
    ),
    (
      'Respiratório',
      'Respiratorio',
      Icons.air_rounded,
      <String>[
        'asma',
        'dpoc',
        'pneumonia',
        'bronquiolite',
        'laringite',
        'caso_pac',
      ]
    ),
    (
      'Metabólico',
      'Metabólico',
      Icons.science_rounded,
      <String>[
        'cad_shh',
        'cetoacidose',
        'hipoglicemia',
        'hiperpotassemia',
        'lesao_renal',
        'crise_adrenal',
        'crise_tireotoxica',
        'caso_cetoacidose',
      ]
    ),
    (
      'Digestivo',
      'Digestivo',
      Icons.local_hospital_rounded,
      <String>[
        'hda',
        'hdb',
        'pancreatite',
        'pancreatitis',
        'coagulacao_intravascular',
        'diverticulitis',
        'diarrea',
        'sindrome_ascitico',
        'caso_hda',
      ]
    ),
    (
      'Infecto',
      'Infectología',
      Icons.bug_report_rounded,
      <String>[
        'meningite',
        'neutropenia_febril',
        'faringit',
        'faringitis',
        'rinosinusitis',
        'gripe',
        'hepatitis',
        'sepse_foco',
        'caso_cistite',
        'caso_itu',
        'caso_pac_grave',
      ]
    ),
    (
      'Intoxicações',
      'Intoxicaciones',
      Icons.warning_rounded,
      <String>[
        'intox',
        'intoxicacao',
      ]
    ),
    (
      'Outros',
      'Otros',
      Icons.more_horiz_rounded,
      <String>[
        'eclampsia',
        'agitacao',
        'caso_',
      ]
    ),
    (
      'Pediátrico',
      'Pediátrico',
      Icons.child_care_rounded,
      <String>[
        '_ped',
        'pcr_ped',
        'bronquiolite',
        'laringite',
      ]
    ),
  ];

  int _fluxoCat = 0;
  final _searchFluxoCtrl = TextEditingController();
  String _queryFluxo = '';

  @override
  void initState() {
    super.initState();
    _searchFluxoCtrl.addListener(() {
      if (mounted)
        setState(
            () => _queryFluxo = _searchFluxoCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchFluxoCtrl.dispose();
    super.dispose();
  }

  int _catIndexForId(String id) {
    for (int ci = 1; ci < _catDefs.length - 1; ci++) {
      final keywords = _catDefs[ci].$4;
      if (keywords.any((kw) => id.contains(kw))) return ci;
    }
    return _catDefs.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final dark = widget.dark;
    final isEs = widget.isEs;

    // Deduplica a DB uma única vez
    final seen = <String>{};
    final allDB = p.protocolsDB.where((x) => seen.add(x.id)).toList();

    return CustomScrollView(
      primary: false,
      slivers: [
        // ── Seletor de sub-segmento ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            // MEDCASES_SIMULACAO_LAYOUT_CARDS_V1_B_R1
            // MEDCASES_SIMULACAO_CANONICAL_DENSITY_V1_B_R0_R3
            // Densidade canônica local; topbar e shell global congelados.
            // Primeiro conteúdo visível: 6 px abaixo da topbar.
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Row(children: [
              _SegmentBtn(
                label: isEs ? 'Simulaciones' : 'Simulações',
                icon: Icons.cases_rounded,
                active: _segment == 0,
                dark: dark,
                onTap: () => setState(() => _segment = 0),
              ),
              const SizedBox(width: 0),
              _SegmentBtn(
                label: isEs ? 'Fluxos Simulados' : 'Fluxos Simulados',
                icon: Icons.account_tree_outlined,
                active: _segment == 1,
                dark: dark,
                onTap: () => setState(() => _segment = 1),
              ),
            ]),
          ),
        ),

        // ── Conteúdo do sub-segmento ────────────────────────────────────────
        if (_segment == 0)
          ..._buildSimulacoesSliver(allDB, dark, isEs, p)
        else
          ..._buildFluxosSliver(allDB, dark, isEs),
      ],
    );
  }

  // ── Sub-segmento 0: Simulações (grupos de casos narrativos) ────────────────
  List<Widget> _buildSimulacoesSliver(
    List<ProtocolModel> allDB,
    bool dark,
    bool isEs,
    AppProvider p,
  ) {
    final groups = _gruposSimulacao
        .where((g) => allDB.any((item) => g.ids.contains(item.id)))
        .toList();

    if (groups.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _LibraryTabEmptyState(
            dark: dark,
            icon: Icons.cases_outlined,
            title: isEs ? 'Sin casos disponibles' : 'Nenhum caso disponível',
            subtitle: isEs
                ? 'Los casos aparecerán aquí cuando estén disponibles.'
                : 'Os casos aparecerão aqui quando estiverem disponíveis.',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final group = groups[i];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == groups.length - 1 ? 0 : 3,
                ),
                child: _GrupoCard(
                  icon: group.icon,
                  titlePt: group.titlePt,
                  titleEs: group.titleEs,
                  color: group.color,
                  borderColor: group.borderColor,
                  iconColor: group.iconColor,
                  ids: group.ids,
                  allDB: allDB,
                  isEs: isEs,
                  p: p,
                  dark: dark,
                ),
              );
            },
            childCount: groups.length,
          ),
        ),
      ),
    ];
  }

  // ── Sub-segmento 1: Fluxos Simulados (todos os demais, com busca + filtro) ─
  List<Widget> _buildFluxosSliver(
    List<ProtocolModel> allDB,
    bool dark,
    bool isEs,
  ) {
    final List<ProtocolModel> fluxos;
    if (_queryFluxo.isNotEmpty) {
      fluxos = allDB.where((pr) {
        final t = (pr.title[isEs ? 'es' : 'pt'] ?? pr.title['pt'] ?? '')
            .toLowerCase();
        return t.contains(_queryFluxo);
      }).toList();
    } else if (_fluxoCat == 0) {
      fluxos = [...allDB]..sort((a, b) {
          final ta = (a.title[isEs ? 'es' : 'pt'] ?? a.title['pt'] ?? '')
              .toLowerCase();
          final tb = (b.title[isEs ? 'es' : 'pt'] ?? b.title['pt'] ?? '')
              .toLowerCase();
          return ta.compareTo(tb);
        });
    } else {
      fluxos = allDB.where((pr) => _catIndexForId(pr.id) == _fluxoCat).toList()
        ..sort((a, b) {
          final ta = (a.title[isEs ? 'es' : 'pt'] ?? a.title['pt'] ?? '')
              .toLowerCase();
          final tb = (b.title[isEs ? 'es' : 'pt'] ?? b.title['pt'] ?? '')
              .toLowerCase();
          return ta.compareTo(tb);
        });
    }

    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final divider = dark ? const Color(0xFF2D3340) : const Color(0xFFD8E0E7);
    final fieldBg = dark ? const Color(0xFF252930) : const Color(0xFFF8FAFC);
    final cardPalette = HomeV2Palette.resolve(dark);

    final bodySliver = fluxos.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: _LibraryTabEmptyState(
              dark: dark,
              icon: Icons.search_off_rounded,
              title: isEs
                  ? 'Sin casos en esta categoría'
                  : 'Nenhum caso nesta categoria',
              subtitle: _queryFluxo.isNotEmpty
                  ? (isEs
                      ? 'Intenta ajustar tu búsqueda.'
                      : 'Tente ajustar sua busca.')
                  : (isEs
                      ? 'Selecciona otra categoría.'
                      : 'Selecione outra categoria.'),
            ),
          )
        : SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final item = fluxos[i];
                  final title = item.getField(item.title, isEs ? 'es' : 'pt');
                  final severity =
                      item.getField(item.severity, isEs ? 'es' : 'pt');
                  final sevLow = severity.toLowerCase();
                  final Color sevColor;
                  if (sevLow.contains('crítico') ||
                      sevLow.contains('crítica') ||
                      sevLow.contains('grave') ||
                      sevLow.contains('alto')) {
                    sevColor = const Color(0xFFDC2626);
                  } else if (sevLow.contains('moderado') ||
                      sevLow.contains('médio') ||
                      sevLow.contains('urgência') ||
                      sevLow.contains('urgencia')) {
                    sevColor = const Color(0xFFD97706);
                  } else {
                    sevColor = const Color(0xFF16A34A);
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i == fluxos.length - 1 ? 0 : 3,
                    ),
                    child: HomeV2PressSurface(
                      palette: cardPalette,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            HomeV2SurfaceTokens.radius,
                          ),
                          overlayColor: cardPalette.pressedOverlay,
                          onTap: () =>
                              openSimulationProtocolPage(context, item),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 56),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 7, 8, 7),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Icon(
                                      Icons.school_outlined,
                                      size: 16,
                                      color: sevColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: cardPalette.textPrimary,
                                            height: 1.3,
                                          ),
                                        ),
                                        if (severity.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            severity,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: sevColor,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: cardPalette.textSecondary
                                        .withValues(alpha: 0.75),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: fluxos.length,
              ),
            ),
          );

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: TextField(
            controller: _searchFluxoCtrl,
            style: TextStyle(color: primary, fontSize: 12.5),
            decoration: InputDecoration(
              hintText:
                  isEs ? 'Buscar caso simulado…' : 'Buscar caso simulado…',
              hintStyle: TextStyle(color: secondary, fontSize: 12),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF10B981),
                size: 16,
              ),
              suffixIcon: _queryFluxo.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _searchFluxoCtrl.clear(),
                      child: Icon(
                        Icons.close_rounded,
                        color: secondary,
                        size: 16,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: fieldBg,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF10B981), width: 1),
              ),
            ),
          ),
        ),
      ),
      if (_queryFluxo.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_catDefs.length, (i) {
                  final active = _fluxoCat == i;
                  final ci = _catDefs[i];
                  final lbl = isEs ? ci.$2 : ci.$1;
                  final ico = ci.$3;
                  final color = active ? const Color(0xFF10B981) : secondary;

                  return GestureDetector(
                    onTap: () => setState(() => _fluxoCat = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.fromLTRB(4, 7, 4, 7),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: active
                              ? const BorderSide(
                                  color: Color(0xFF10B981),
                                  width: 2,
                                )
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(ico, size: 12, color: color),
                          const SizedBox(width: 5),
                          Text(
                            lbl,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      if (_queryFluxo.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
            child: Text(
              '${fluxos.length} resultado(s) para "$_queryFluxo"',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: secondary,
              ),
            ),
          ),
        ),
      bodySliver,
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÃO DE SUB-SEGMENTO
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  const _SegmentBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF10B981);
    final inactiveColor =
        dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: active
                  ? const BorderSide(
                      color: Color(0xFF10B981),
                      width: 2,
                    )
                  : BorderSide.none,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? activeColor : inactiveColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG DE GRUPO DE SIMULAÇÃO
// ─────────────────────────────────────────────────────────────────────────────
class _GrupoConfig {
  final IconData icon;
  final String titlePt;
  final String titleEs;
  final Color color;
  final Color borderColor;
  final Color iconColor;
  final Set<String> ids;

  const _GrupoConfig({
    required this.icon,
    required this.titlePt,
    required this.titleEs,
    required this.color,
    required this.borderColor,
    required this.iconColor,
    required this.ids,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE GRUPO — abre bottom sheet com a lista de itens
// ─────────────────────────────────────────────────────────────────────────────
class _GrupoCard extends StatelessWidget {
  final IconData icon;
  final String titlePt;
  final String titleEs;
  final Color color;
  final Color borderColor;
  final Color iconColor;
  final Set<String> ids;
  final List<ProtocolModel> allDB;
  final bool isEs;
  final AppProvider p;
  final bool dark;

  const _GrupoCard({
    required this.icon,
    required this.titlePt,
    required this.titleEs,
    required this.color,
    required this.borderColor,
    required this.iconColor,
    required this.ids,
    required this.allDB,
    required this.isEs,
    required this.p,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final casos = allDB.where((d) => ids.contains(d.id)).toList();
    if (casos.isEmpty) return const SizedBox.shrink();

    final title = isEs ? titleEs : titlePt;
    final palette = HomeV2Palette.resolve(dark);

    return HomeV2PressSurface(
      // MEDCASES_SIMULACAO_HOME_CARD_STANDARD_V1_B_R2
      palette: palette,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeV2SurfaceTokens.radius),
          overlayColor: palette.pressedOverlay,
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => _SimulacoesGroupPage(
                titlePt: titlePt,
                titleEs: titleEs,
                icon: icon,
                iconColor: iconColor,
                casos: casos,
              ),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${casos.length} ${casos.length == 1 ? (isEs ? "caso de estudio" : "caso de estudo") : (isEs ? "casos de estudio" : "casos de estudo")}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: palette.textSecondary.withValues(alpha: 0.75),
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

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET — lista de simulações do grupo
// ─────────────────────────────────────────────────────────────────────────────
class _SimulacoesGroupPage extends StatelessWidget {
  final String titlePt;
  final String titleEs;
  final IconData icon;
  final Color iconColor;
  final List<ProtocolModel> casos;

  const _SimulacoesGroupPage({
    required this.titlePt,
    required this.titleEs,
    required this.icon,
    required this.iconColor,
    required this.casos,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';
    final title = isEs ? titleEs : titlePt;
    final palette = HomeV2Palette.resolve(dark);
    final bg = HomeV2SurfaceTokens.pageBackground(dark);
    final topbarGlass = dark
        ? const Color(0xFF252930).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.70);
    final topbarDivider =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final topbarForeground = dark ? Colors.white : const Color(0xFF05070A);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: topbarGlass,
                  border: Border(
                    bottom: BorderSide(color: topbarDivider, width: 0.7),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 48),
                              child: Align(
                                alignment: Alignment.center,
                                child: Text(
                                  title.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: topbarForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).pop(),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Center(
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 20,
                                    color: topbarForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          itemCount: casos.length,
          itemBuilder: (_, i) {
            final caso = casos[i];
            final label = p.tDB(caso.title);
            final severity = p.tDB(caso.severity);

            return Padding(
              padding: EdgeInsets.only(
                bottom: i == casos.length - 1 ? 0 : 3,
              ),
              child: HomeV2PressSurface(
                // MEDCASES_SIMULATION_GROUP_FULL_PAGE_V1_B_R0
                palette: palette,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(HomeV2SurfaceTokens.radius),
                    overlayColor: palette.pressedOverlay,
                    onTap: () => openSimulationProtocolPage(context, caso),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Icon(
                                Icons.school_outlined,
                                size: 16,
                                color: iconColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: palette.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (severity.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      severity,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: iconColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: palette.textSecondary
                                  .withValues(alpha: 0.75),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTRO DE CATEGORIA (Guias PDF)
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryFilter extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final bool dark;
  final bool isEs;
  final ValueChanged<String> onSelect;

  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.dark,
    required this.isEs,
    required this.onSelect,
  });

  String _label(String category) {
    if (!isEs) return category;

    switch (category) {
      case 'Geral':
        return 'General';
      case 'Emergência':
        return 'Urgencias';
      case 'Cardiologia':
        return 'Cardiología';
      case 'Infectologia':
        return 'Infectología';
      case 'Pediatria':
        return 'Pediatría';
      case 'Neurologia':
        return 'Neurología';
      case 'Pneumologia':
        return 'Neumología';
      case 'UTI / Intensivismo':
        return 'UCI / Intensivismo';
      case 'Farmacologia':
        return 'Farmacología';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    // MEDCASES_GUIA_CLINICA_SPECIALTY_FILTER_V1_B_R0
    final inactive =
        dark ? const Color(0xFF2D3340) : const Color(0xFFFFFFFF);
    final border =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final text =
        dark ? const Color(0xFFCBD5E1) : const Color(0xFF59636E);

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final category = categories[i];
          final active = category == selected;

          return Padding(
            padding: EdgeInsets.only(
              right: i == categories.length - 1 ? 0 : 3,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelect(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 36,
                constraints: const BoxConstraints(minWidth: 62),
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: active ? _kGreen : inactive,
                  border: Border.all(
                    color: active ? _kGreen : border,
                    width: 0.7,
                  ),
                ),
                child: Text(
                  _label(category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : text,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// CARD DE GUIA PDF
// ─────────────────────────────────────────────────────────────────────────────
class _GuideCard extends StatelessWidget {
  final GuideModel guide;
  final bool dark;
  final VoidCallback onOpen;

  const _GuideCard({
    required this.guide,
    required this.dark,
    required this.onOpen,
  });

  Color get _categoryColor {
    switch (guide.category) {
      case 'Emergência':
        return const Color(0xFFEF4444);
      case 'Cardiologia':
        return const Color(0xFFEC4899);
      case 'Infectologia':
        return const Color(0xFF10B981);
      case 'Pediatria':
        return const Color(0xFF3B82F6);
      case 'Neurologia':
        return const Color(0xFF8B5CF6);
      case 'Pneumologia':
        return const Color(0xFF06B6D4);
      case 'UTI / Intensivismo':
        return const Color(0xFFF97316);
      case 'Farmacologia':
        return const Color(0xFFA855F7);
      default:
        return dark ? const Color(0xFF00C781) : const Color(0xFF008F66);
    }
  }

  String _categoryLabel(bool isEs) {
    if (!isEs) return guide.category;

    switch (guide.category) {
      case 'Geral':
        return 'General';
      case 'Emergência':
        return 'Urgencias';
      case 'Cardiologia':
        return 'Cardiología';
      case 'Infectologia':
        return 'Infectología';
      case 'Pediatria':
        return 'Pediatría';
      case 'Neurologia':
        return 'Neurología';
      case 'Pneumologia':
        return 'Neumología';
      case 'UTI / Intensivismo':
        return 'UCI / Intensivismo';
      case 'Farmacologia':
        return 'Farmacología';
      default:
        return guide.category;
    }
  }

  Widget _thumbnailFallback({
    required Color accent,
    required Color surfaceSoft,
    required Color border,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceSoft,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: border,
          width: 0.7,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 9,
            top: 9,
            child: Container(
              width: 18,
              height: 2,
              color: accent,
            ),
          ),
          Center(
            child: Icon(
              Icons.menu_book_rounded,
              size: 27,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // MEDCASES_GUIA_CLINICA_COMPACT_CARD_V1_B_R0
    final isEs = context.select<AppProvider, bool>((p) => p.lang == 'es');
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final surfaceSoft =
        dark ? const Color(0xFF2D3340) : const Color(0xFFF4F7F8);
    final border =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final primary = dark ? Colors.white : const Color(0xFF05070A);
    final secondary =
        dark ? const Color(0xFFCBD5E1) : const Color(0xFF59636E);
    final muted =
        dark ? const Color(0xFF94A3B8) : const Color(0xFF7B8794);
    final accent = _categoryColor;
    final category = _categoryLabel(isEs);

    final meta = <String>[
      if (guide.authors.trim().isNotEmpty) guide.authors.trim(),
      if (guide.year.trim().isNotEmpty) guide.year.trim(),
    ].join(' • ');

    final utility = <String>[
      if (guide.fileSizeLabel.isNotEmpty) guide.fileSizeLabel,
      if (guide.downloadCount > 0)
        isEs
            ? '${guide.downloadCount} descargas'
            : '${guide.downloadCount} downloads',
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: border,
            width: 0.7,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 88,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: guide.coverUrl.trim().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: guide.coverUrl.trim(),
                            fit: BoxFit.cover,
                            fadeInDuration:
                                const Duration(milliseconds: 120),
                            placeholder: (_, __) => DecoratedBox(
                              decoration: BoxDecoration(
                                color: surfaceSoft,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.6,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) =>
                                _thumbnailFallback(
                              accent: accent,
                              surfaceSoft: surfaceSoft,
                              border: border,
                            ),
                          )
                        : _thumbnailFallback(
                            accent: accent,
                            surfaceSoft: surfaceSoft,
                            border: border,
                          ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 88),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 9.8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.55,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          guide.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (guide.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            guide.description.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 13,
                              color: muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                utility.isEmpty ? 'PDF' : 'PDF • $utility',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Abrir',
                              style: TextStyle(
                                color: dark
                                    ? const Color(0xFF00C781)
                                    : const Color(0xFF008F66),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 17,
                              color: dark
                                  ? const Color(0xFF00C781)
                                  : const Color(0xFF008F66),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _LibraryTabEmptyState extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String subtitle;

  const _LibraryTabEmptyState({
    required this.dark,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 52,
                color: dark ? Colors.white12 : Colors.black.withOpacity(0.12)),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white54 : Colors.black.withOpacity(0.52),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: dark ? Colors.white30 : Colors.black.withOpacity(0.34),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideErrorState extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final String message;
  final VoidCallback onRetry;
  const _GuideErrorState({
    required this.dark,
    required this.isEs,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white70 : const Color(0xFF3B1F1F);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56,
                color: dark
                    ? Colors.orangeAccent.withOpacity(0.7)
                    : Colors.redAccent),
            const SizedBox(height: 14),
            Text(
              isEs ? 'Error al cargar guías' : 'Erro ao carregar guias',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: fg),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: dark ? Colors.white54 : Colors.black.withOpacity(0.62),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isEs ? 'Reintentar' : 'Tentar novamente'),
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final bool hasSearch;
  const _EmptyState(
      {required this.dark, required this.isEs, this.hasSearch = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.menu_book_rounded,
            size: 56,
            color: dark ? Colors.white12 : Colors.black.withOpacity(0.12),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? (isEs ? 'Sin resultados' : 'Nenhum resultado')
                : (isEs
                    ? 'Sin guías disponibles aún'
                    : 'Nenhuma guia disponível ainda'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white30 : Colors.black.withOpacity(0.26),
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            Text(
              isEs
                  ? 'El administrador aún no subió guías'
                  : 'O administrador ainda não enviou guias',
              style: TextStyle(
                  fontSize: 13,
                  color:
                      dark ? Colors.white24 : Colors.black.withOpacity(0.12)),
              textAlign: TextAlign.center,
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABA GENERAL — BUILD 277-CROMATICO
// Overview / landing tab with key library information
// ─────────────────────────────────────────────────────────────────────────────
class _GeneralTab extends StatelessWidget {
  final bool dark;
  final bool isEs;
  const _GeneralTab({required this.dark, required this.isEs});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFF7F8FA);
    final card = dark ? const Color(0xFF22262F) : Colors.white;
    final text1 = dark ? Colors.white : const Color(0xFF0F1116);
    final text2 = dark ? Colors.white54 : Colors.black54;

    final items = [
      _GenItem(
        icon: Icons.picture_as_pdf_rounded,
        color: const Color(0xFF1E3A5F),
        title: isEs ? 'Guías PDF Clínicas' : 'Guias PDF Clínicos',
        subtitle: isEs
            ? 'Protocolos clínicos en formato PDF de alta calidad.'
            : 'Protocolos clínicos em formato PDF de alta qualidade.',
      ),
      _GenItem(
        icon: Icons.school_rounded,
        color: const Color(0xFF065F45),
        title: isEs ? 'Casos de Estudio' : 'Casos de Estudo',
        subtitle: isEs
            ? 'Casos clínicos reales con discusión diagnóstica.'
            : 'Casos clínicos reais com discussão diagnóstica.',
      ),
      // BUILD 282 ORDEM 5: 'Actualización continua' e 'Fuentes científicas' REMOVIDOS
      // Guideline Apple 2.1: não oferecer funcionalidades sem backend implementado.
    ];

    return ColoredBox(
      color: bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isEs ? 'Bienvenido a la Biblioteca' : 'Bem-vindo à Biblioteca',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: text1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEs
                ? 'Acceda a guías, protocolos y casos de estudio clínico.'
                : 'Acesse guias, protocolos e casos de estudo clínico.',
            style: TextStyle(fontSize: 13, color: text2),
          ),
          const SizedBox(height: 20),
          ...items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: item.color.withOpacity(dark ? 0.22 : 0.12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: text1)),
                      const SizedBox(height: 3),
                      Text(item.subtitle,
                          style: TextStyle(
                              fontSize: 12, color: text2, height: 1.4)),
                    ],
                  )),
                ]),
              )),
        ]),
      ),
    );
  }
}

class _GenItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _GenItem(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle});
}
