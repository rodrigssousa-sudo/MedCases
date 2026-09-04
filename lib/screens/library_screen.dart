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
import '../services/clinical_guides_editorial_service.dart';
import '../models/guide_model.dart';
import 'clinical_guide_article_screen.dart';
import '../models/protocol_model.dart';
import '../widgets/common_widgets.dart' show MedBreakpoints;
import '../home_v2/theme/home_v2_palette.dart';
import '../home_v2/components/common/home_v2_press_surface.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
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
enum ClinicalLearningDestination { guide, simulation }

class ClinicalGuideScreen extends StatelessWidget {
  const ClinicalGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LibraryScreen(destination: ClinicalLearningDestination.guide);
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
  const LibraryScreen({super.key, required this.destination});

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
  bool _loadingMoreGuides = false;
  bool _hasMoreGuides = true;
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
      'refresh start reason=$reason forceRemote=$forceRemote kIsWeb=$kIsWeb',
    );
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
          _hasMoreGuides = list.length >= FirestoreService.guidesPortalPageSize;
        }
        _guidesError =
            (_guides.isEmpty && serviceError.isNotEmpty) ? serviceError : '';
        _syncCategoryWithData();
        _loading = false;
      });
      _log(
        'refresh done reason=$reason count=${list.length} error="$serviceError"',
      );
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
          TimeoutException(
            'Library guides stream timeout: no events in 25s',
          ),
        );
      },
    ).listen(
      (list) {
        _log('stream event count=${list.length}');
        if (!mounted) return;
        setState(() {
          if (list.isNotEmpty || _guides.isEmpty) {
            _guides = list;
            _hasMoreGuides =
                list.length >= FirestoreService.guidesPortalPageSize;
          }
          _guidesError = (_guides.isEmpty &&
                  FirestoreService.lastGuidesErrorMessage.isNotEmpty)
              ? FirestoreService.lastGuidesErrorMessage
              : '';
          _syncCategoryWithData();
          _loading = false;
        });
      },
      onError: (Object error, StackTrace stackTrace) async {
        _log('stream error=$error');
        if (mounted) {
          setState(() {
            _guidesError = error.toString();
            _loading = false;
          });
        }
        await _refreshGuides(forceRemote: true, reason: 'stream-error');
      },
    );
  }

  Future<void> _loadMoreGuides() async {
    if (_loadingMoreGuides || !_hasMoreGuides || _guides.isEmpty) return;

    final cursor = _guides.last.uploadedAt.trim();
    if (cursor.isEmpty) {
      if (mounted) {
        setState(() => _hasMoreGuides = false);
      }
      return;
    }

    setState(() => _loadingMoreGuides = true);

    try {
      // O stream permanece responsável só pela primeira página.
      // Ao paginar, cancelamos para que uma atualização de 10 itens não
      // sobrescreva as páginas já concatenadas.
      await _sub?.cancel();
      _sub = null;

      final page = await FirestoreService.loadNextPublishedGuidesPage(
        afterUploadedAt: cursor,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Library guides next page timeout after 15s',
        ),
      );

      if (!mounted) return;

      final byId = <String, GuideModel>{
        for (final guide in _guides) guide.id: guide,
      };
      for (final guide in page) {
        byId[guide.id] = guide;
      }

      final merged = byId.values.toList(growable: false)
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      setState(() {
        _guides = merged;
        _hasMoreGuides = page.length >= FirestoreService.guidesPortalPageSize;
        _guidesError = '';
      });

      _log(
        'pagination received=${page.length} '
        'total=${_guides.length} hasMore=$_hasMoreGuides',
      );
    } catch (e) {
      _log('pagination failed error=$e');
    } finally {
      if (mounted) {
        setState(() => _loadingMoreGuides = false);
      }
    }
  }

  Future<void> _handleManualRefresh() async {
    _log('manual refresh requested');
    await FirestoreService.clearPublishedGuidesCache(
      reason: 'manual-refresh-button',
    );
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
    openAcademicSourceSecurely(context, g.title, g.pdfUrl);
  }

  Future<void> _openGuide(GuideModel g) async {
    try {
      final article = await ClinicalGuidesEditorialService.loadById(g.id);

      if (!mounted) return;

      if (article != null && article.hasEditorialBody) {
        final lang = Provider.of<AppProvider>(context, listen: false).lang;

        FirestoreService.incrementGuideDownload(g.id);

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ClinicalGuideArticleScreen(
              guide: article.forLanguage(lang),
              lang: lang,
            ),
          ),
        );
        return;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[Library] editorial guide fallback to legacy PDF '
          'id=${g.id} error=$error',
        );
      }
    }

    if (!mounted) return;
    _openPdf(g);
  }

  Future<void> _showGuidePortalSearch() async {
    final guides = List<GuideModel>.of(_guides);

    final isEs =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'es';

    final selected = await showSearch<GuideModel?>(
      context: context,
      delegate: _GuidePortalSearchDelegate(
        guides: guides,
        isEs: isEs,
        remoteSearch: FirestoreService.searchPublishedGuides,
      ),
    );

    if (!mounted || selected == null) return;
    await _openGuide(selected);
  }

  Future<void> _showSimulationPortalSearch(AppProvider p, bool isEs) async {
    // MEDCASES_SIMULACOES_TOPBAR_GLOBAL_SEARCH_GUIDE_PATTERN_V1_B_R0
    final seen = <String>{};
    final items = p.protocolsDB.where((item) => seen.add(item.id)).toList();

    final selected = await showSearch<ProtocolModel?>(
      context: context,
      delegate: _SimulationPortalSearchDelegate(items: items, isEs: isEs),
    );

    if (!mounted || selected == null) return;
    openSimulationProtocolPage(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';
    final isSimulation =
        widget.destination == ClinicalLearningDestination.simulation;
    final isGuide = widget.destination == ClinicalLearningDestination.guide;
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final filtered = _filtered
        .map((guide) => guide.localizedCopy(isEs))
        .toList(growable: false);
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

    // MEDCASES_GUIA_CLINICA_HOME_TOPBAR_EXACT_PARITY_V1_B_R0
    // Guide tab 5 owns physical Y=0. Simulation tab 7 keeps MainShell's
    // external status inset. Both destinations preserve the Home 6px content gap.
    // Home canonical initial content gap: 54 - 48 = 6 px.
    final double bodyTopReserve = isGuide
        ? topPad + topbarHeight + 6.0
        : isSimulation
            ? topbarHeight
            : topbarHeight;
    final double topbarBackgroundTop = isGuide ? 0.0 : -topPad;
    final double topbarContentTop = isGuide ? topPad : 0.0;

    return ColoredBox(
      color: bg,
      // GUIDE_PORTAL_NO_GLOBAL_GLASS_V1_B_R1
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Corpo: espaço reservado + TabRow + conteúdo ──────────────
          Column(
            children: [
              // Guia: status inset interno + 48px + gap canônico de 6px.
              // Simulação: MainShell já fornece status inset; reserva 48px + 6px.
              SizedBox(height: bodyTopReserve),
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
                          onOpen: _openGuide,
                          hasMore: _hasMoreGuides,
                          loadingMore: _loadingMoreGuides,
                          onLoadMore: _loadMoreGuides,
                          onRetry: _handleManualRefresh,
                        )
                      : _CasosDeEstudoTab(dark: dark, isEs: isEs, p: p),
                ), // RepaintBoundary
              ),
            ],
          ),

          // ── CAMADA 1: Fundo — sobe para trás da status bar ──────────
          Positioned(
            top: topbarBackgroundTop,
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
            top: topbarContentTop,
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

          if (isSimulation)
            Positioned(
              // SIMULATION_SEARCH_EXACT_TITLE_ROW
              top: topbarContentTop,
              right: 8,
              height: topbarHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: IconButton(
                    tooltip: isEs ? 'Buscar simulación' : 'Buscar simulação',
                    padding: EdgeInsets.zero,
                    onPressed: () => _showSimulationPortalSearch(p, isEs),
                    icon: const Icon(Icons.search_rounded, size: 30),
                  ),
                ),
              ),
            ),

          if (isGuide)
            Positioned(
              // GUIDE_SEARCH_EXACT_TITLE_ROW_GUIDE_ONLY
              top: topbarContentTop,
              right: 8,
              height: topbarHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: IconButton(
                    tooltip: 'Buscar',
                    padding: EdgeInsets.zero,
                    onPressed: _showGuidePortalSearch,
                    icon: const Icon(Icons.search_rounded, size: 30),
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
// BUILD 331 — TOPBAR BIBLIOTECA
// Geometria estrita: PreferredSize 48px, SafeArea(bottom:false), SizedBox(48),
// padding h:12, fundo sólido adaptativo, border 0.5px, BoxShadow blur:6.
// Título "BIBLIOTECA" centralizado via Stack — sem desvio do botão de voltar.
// ─────────────────────────────────────────────────────────────────────────────
// ── Fundo da topbar Biblioteca (gradiente, sem conteúdo interativo) ──────────
class _LibraryTopbarBg extends StatelessWidget {
  final bool isDark;
  final bool flatSimulation;

  const _LibraryTopbarBg({required this.isDark, this.flatSimulation = false});

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

    // MEDCASES_GUIA_CLINICO_TRUE_LIQUID_GLASS_V1_B_R1
    // Guide-only owner: same optical contract as Home. Simulation stays untouched.
    final glassColor = isDark
        ? const Color(0xFF161B22).withValues(alpha: 0.58)
        : Colors.white.withValues(alpha: 0.56);
    final liquidTop = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.46);
    final liquidMid = isDark
        ? Colors.white.withValues(alpha: 0.025)
        : Colors.white.withValues(alpha: 0.12);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.78);
    final liquidSpecular = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.86);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.07),
            blurRadius: 14,
            spreadRadius: -8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [liquidTop, liquidMid, Colors.transparent],
                stops: const [0.0, 0.42, 1.0],
              ),
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.7),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 0.7,
                  child: Container(
                    height: 0.7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          liquidSpecular,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
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
                ? const BorderSide(color: Color(0xFF0D6B57), width: 2.0)
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
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;
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
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // MEDCASES_GUIA_CLINICA_COMPACT_CLINICAL_HUB_V1_B_R0
    final hasSearch = searchCtrl.text.isNotEmpty;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final primary = dark ? Colors.white : const Color(0xFF05070A);
    final secondary = dark ? const Color(0xFFCBD5E1) : const Color(0xFF59636E);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    final bodySliver = loading
        ? const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
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
                    : _EmptyState(dark: dark, isEs: isEs, hasSearch: hasSearch),
              )
            : SliverPadding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 114 + safeBottom),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _GuideCard(
                      featured: i == 0,
                      portalGuides: filtered,
                      onOpenGuide: onOpen,
                      hasMore: hasMore,
                      loadingMore: loadingMore,
                      onLoadMore: onLoadMore,
                      guide: filtered[i],
                      dark: dark,
                      onOpen: () => onOpen(filtered[i]),
                    ),
                    childCount: filtered.isEmpty ? 0 : 1,
                  ),
                ),
              );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical &&
            hasMore &&
            !loadingMore &&
            notification.metrics.extentAfter <
                notification.metrics.viewportDimension * 0.75) {
          onLoadMore();
        }
        return false;
      },
      child: CustomScrollView(
        primary: false,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 2),
              child: const SizedBox
                  .shrink() /* MEDCASES_GUIDES_COUNT_HEADER_REMOVED_V1_B_R3 */,
            ),
          ),
          bodySliver,
        ],
      ),
    );
  }
}

String _simulationLearningPreview(ProtocolModel item, bool isEs) {
  final values = item.objectives?[isEs ? 'es' : 'pt'] ??
      item.objectives?['pt'] ??
      const <String>[];
  final raw = values.join(' ').trim();
  if (raw.isEmpty) return '';
  return raw
      .replaceAll(RegExp(r'[\n\r\t]+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceFirst(RegExp(r'^[•\-–—\d.)\s]+'), '')
      .trim();
}

// MEDCASES_SIMULATION_SPECIALTY_SVG_V1_B_R4
String _simulationGroupSvgAsset(String title) {
  final value = title.toLowerCase();
  if (value.contains('emerg'))
    return 'assets/icons/simulation/sim_emergencias.svg';
  if (value.contains('cardio'))
    return 'assets/icons/simulation/sim_cardiologia.svg';
  if (value.contains('neuro'))
    return 'assets/icons/simulation/sim_neurologia.svg';
  if (value.contains('pneumo') || value.contains('respirat'))
    return 'assets/icons/simulation/sim_pneumologia.svg';
  if (value.contains('infecto'))
    return 'assets/icons/simulation/sim_infectologia.svg';
  if (value.contains('gastro') || value.contains('hepato'))
    return 'assets/icons/simulation/sim_gastro_hepato.svg';
  if (value.contains('endocr') || value.contains('metab'))
    return 'assets/icons/simulation/sim_endocrino_metabolico.svg';
  if (value.contains('nefro') ||
      value.contains('eletr') ||
      value.contains('electr'))
    return 'assets/icons/simulation/sim_nefro_eletrolitos.svg';
  if (value.contains('pedi'))
    return 'assets/icons/simulation/sim_pediatria.svg';
  if (value.contains('gine') || value.contains('obst'))
    return 'assets/icons/simulation/sim_gineco_obstetricia.svg';
  if (value.contains('trauma') ||
      value.contains('cirurg') ||
      value.contains('cirug'))
    return 'assets/icons/simulation/sim_trauma_cirurgia.svg';
  if (value.contains('hemato'))
    return 'assets/icons/simulation/sim_hematologia.svg';
  if (value.contains('psiqui'))
    return 'assets/icons/simulation/sim_psiquiatria.svg';
  if (value.contains('tox'))
    return 'assets/icons/simulation/sim_toxicologia.svg';
  if (value.contains('orl') ||
      value.contains('otorr') ||
      value.contains('medicina geral') ||
      value.contains('medicina general'))
    return 'assets/icons/simulation/sim_orl_medicina.svg';
  return 'assets/icons/simulation/sim_outros.svg';
}

String _simulationGroupEmoji(String title) {
  final value = title.toLowerCase();
  if (value.contains('emerg')) return '🚨';
  if (value.contains('cardio')) return '🫀';
  if (value.contains('neuro')) return '🧠';
  if (value.contains('pneumo') || value.contains('respirat')) return '🫁';
  if (value.contains('infecto')) return '🦠';
  if (value.contains('gastro')) return '🩺';
  if (value.contains('hepato')) return '🧪';
  if (value.contains('endocr') || value.contains('metab')) return '🧬';
  if (value.contains('nefro') || value.contains('eletr')) return '💧';
  if (value.contains('pedi')) return '🧒';
  if (value.contains('gine') || value.contains('obst')) return '🤰';
  if (value.contains('trauma') || value.contains('cirurg')) return '🩹';
  if (value.contains('hemato')) return '🩸';
  if (value.contains('psiqui')) return '🧠';
  if (value.contains('tox')) return '☣️';
  if (value.contains('orl')) return '👂';
  if (value.contains('outros') || value.contains('otros')) return '⚕️';
  return '⚕️';
}

String _simulationCategoryEmoji(int index) {
  switch (index) {
    case 1:
      return '🚨';
    case 2:
      return '🫀';
    case 3:
      return '🫁';
    case 4:
      return '🧪';
    case 5:
      return '🩺';
    case 6:
      return '🦠';
    case 7:
      return '⚠️';
    case 8:
      return '📋';
    case 9:
      return '🧒';
    default:
      return '⚕️';
  }
}

class _SimulationPlainHeader extends StatelessWidget {
  final bool dark;
  final String title;
  final String countLabel;

  const _SimulationPlainHeader({
    required this.dark,
    required this.title,
    required this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? Colors.white : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Semantics(
      header: true,
      label: '$title. $countLabel',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: primary,
                  fontSize: 17,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              countLabel,
              style: TextStyle(
                color: secondary,
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CasosDeEstudoTab extends StatefulWidget {
  final bool dark;
  final bool isEs;
  final AppProvider p;
  const _CasosDeEstudoTab({
    required this.dark,
    required this.isEs,
    required this.p,
  });

  @override
  State<_CasosDeEstudoTab> createState() => _CasosDeEstudoTabState();
}

class _CasosDeEstudoTabState extends State<_CasosDeEstudoTab> {
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
    // MEDCASES_SIMULACOES_TOXICOLOGIA_10_CASES_V1_B_R1
    'intox_benzodiazepinas',
    'intox_organofosforados',
    'intox_triciclicos',
    'intox_betabloqueadores',
    'intox_monoxido_carbono',
    'intox_metanol_etilenoglicol',
    // MEDCASES_TOXICOLOGIA_HIPOXIA_TOXICA_10_NEW_CASES_2026
    'intox_co2_espaco_confinado',
    'intox_cianeto',
    'intox_fumaca_co_cianeto',
    'metahemoglobinemia_adquirida',
    'metahemoglobinemia_dapsona',
    'metahemoglobinemia_nitrito_nitrato',
    'metahemoglobinemia_anestesico_local',
    'metahemoglobinemia_anilina_nitrobenzeno',
    'intox_sulfeto_hidrogenio',
    'intox_cloreto_metileno',
    // MEDCASES_TOXICOLOGIA_30_COMPLETE_2026
    'intox_salicilatos',
    'intox_bloqueadores_canal_calcio',
    'intox_digoxina_glicosideos',
    'intox_litio',
    'intox_valproato',
    'intox_ferro',
    'intox_isoniazida',
    'intox_cocaina_simpaticomimeticos',
    'sindrome_serotoninergica',
    'intox_anestesico_local_last',
    // MEDCASES_TOXICOLOGIA_LATAM_VENOMS_BOTULISM_10_NEW_CASES_2026
    'botulismo_neuroparalitico',
    'ofidismo_bothrops_alternatus_yarara',
    'ofidismo_bothrops_jararaca_jararacucu',
    'ofidismo_crotalus_durissus',
    'ofidismo_micrurus_coral',
    'escorpionismo_tityus_argentina',
    'escorpionismo_tityus_brasil',
    'araneismo_loxosceles',
    'araneismo_phoneutria',
    'araneismo_latrodectus',
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
        'caso_status_epilepticus',
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
        'caso_pac_grave',
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
    // MEDCASES_SIMULACOES_TOXICOLOGIA_10_CASES_V1_B_R1
    _GrupoConfig(
      icon: Icons.science_outlined,
      titlePt: 'Toxicologia',
      titleEs: 'Toxicología',
      color: Color(0xFF151E1C),
      borderColor: Color(0xFF256B5A),
      iconColor: Color(0xFF34D399),
      ids: {
        'intoxicacao_exogena',
        'intox_paracetamol',
        'intox_opioides',
        'intox_benzodiazepinas',
        'intox_organofosforados',
        'intox_triciclicos',
        'intox_betabloqueadores',
        'intox_monoxido_carbono',
        'intox_metanol_etilenoglicol',
        'intoxicacao_overdose',
        // MEDCASES_TOXICOLOGIA_HIPOXIA_TOXICA_10_NEW_CASES_2026
        'intox_co2_espaco_confinado',
        'intox_cianeto',
        'intox_fumaca_co_cianeto',
        'metahemoglobinemia_adquirida',
        'metahemoglobinemia_dapsona',
        'metahemoglobinemia_nitrito_nitrato',
        'metahemoglobinemia_anestesico_local',
        'metahemoglobinemia_anilina_nitrobenzeno',
        'intox_sulfeto_hidrogenio',
        'intox_cloreto_metileno',
        // MEDCASES_TOXICOLOGIA_30_COMPLETE_2026
        'intox_salicilatos',
        'intox_bloqueadores_canal_calcio',
        'intox_digoxina_glicosideos',
        'intox_litio',
        'intox_valproato',
        'intox_ferro',
        'intox_isoniazida',
        'intox_cocaina_simpaticomimeticos',
        'sindrome_serotoninergica',
        'intox_anestesico_local_last',
        // MEDCASES_TOXICOLOGIA_LATAM_VENOMS_BOTULISM_10_NEW_CASES_2026
        'botulismo_neuroparalitico',
        'ofidismo_bothrops_alternatus_yarara',
        'ofidismo_bothrops_jararaca_jararacucu',
        'ofidismo_crotalus_durissus',
        'ofidismo_micrurus_coral',
        'escorpionismo_tityus_argentina',
        'escorpionismo_tityus_brasil',
        'araneismo_loxosceles',
        'araneismo_phoneutria',
        'araneismo_latrodectus',
      },
    ),
  ];

  // ── Categorias para sub-segmento "Fluxos Simulados" ──────────────────────
  // Classificação dinâmica por keywords no id — igual à lógica anterior
  @override
  @override
  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final dark = widget.dark;
    final isEs = widget.isEs;

    // MEDCASES_SIMULACAO_CANONICAL_DENSITY_V1_B_R0_R3
    // MEDCASES_SIMULACOES_UNIFIED_SINGLE_HUB_SPECIALTY_CARDS_V1_B_R0
    // A antiga divisão visual Simulações | Fluxos foi eliminada.
    // Ambos os conjuntos continuam usando ProtocolModel e a mesma rota.
    final seen = <String>{};
    final allDB = p.protocolsDB.where((item) => seen.add(item.id)).toList();

    return CustomScrollView(
      primary: false,
      slivers: _buildUnifiedHubSliver(allDB, dark, isEs, p),
    );
  }

  bool _isUnifiedToxicologyId(String id) {
    for (final group in _gruposSimulacao) {
      if (group.titlePt == 'Toxicologia' && group.ids.contains(id)) {
        return true;
      }
    }
    return false;
  }

  int _unifiedSimulationCategoryIndex(String rawId) {
    final id = rawId.toLowerCase();

    bool hasAny(List<String> keywords) =>
        keywords.any((keyword) => id.contains(keyword));

    // Toxicologia tem precedência absoluta para preservar os 40 casos,
    // inclusive botulismo, ofidismo, escorpionismo, araneísmo e LAST.
    if (_isUnifiedToxicologyId(id) ||
        hasAny(<String>[
          'intox',
          'intoxicacao',
          'metahemoglob',
          'botulismo',
          'ofidismo',
          'escorpionismo',
          'araneismo',
          'sindrome_serotoninergica',
        ])) {
      return 13;
    }

    final explicitCategory = _simulationSpecialtyOverrides[id];
    if (explicitCategory != null) return explicitCategory;

    if (hasAny(<String>[
      '_ped',
      'pcr_ped',
      'pediatr',
      'bronquiolite',
      'laringite',
    ])) {
      return 8;
    }

    if (hasAny(<String>[
      'eclamps',
      'hellp',
      'obstetr',
      'gineco',
      'gravidez',
      'gestacao',
      'gestación',
    ])) {
      return 9;
    }

    if (hasAny(<String>[
      'politrauma',
      'trauma',
      'queimadura',
      'apendicite',
      'cirurg',
    ])) {
      return 10;
    }

    if (id == 'choque' ||
        hasAny(<String>[
          'pcr_adulto',
          'anafilax',
          'sepse',
          'choque_sept',
          'intubacao',
          'intubação',
          'ventilacao',
          'ventilação',
        ])) {
      return 0;
    }

    if (hasAny(<String>[
      'iam',
      'stemi',
      'icc',
      'cardio',
      'fa_aguda',
      'tpsv',
      'hipertens',
      'arritm',
      'cardiogenico',
      'cardiogênico',
    ])) {
      return 1;
    }

    if (hasAny(<String>[
      'avc',
      'status_epilep',
      'enxaqueca',
      'convuls',
      'neurolog',
    ])) {
      return 2;
    }

    if (hasAny(<String>[
      'tep',
      'tromboembolismo_pulmonar',
      'asma',
      'dpoc',
      'pneum',
      'pac_',
      'respirat',
    ])) {
      return 3;
    }

    if (hasAny(<String>[
      'lesao_renal',
      'lesão_renal',
      'renal',
      'nefro',
      'hiperpotass',
      'hipopotass',
      'hiponatr',
      'hipernatr',
      'eletrol',
    ])) {
      return 7;
    }

    if (hasAny(<String>[
      'cad_shh',
      'cetoacidose',
      'hipoglic',
      'crise_adrenal',
      'tireotox',
      'endocr',
      'metabol',
    ])) {
      return 6;
    }

    if (hasAny(<String>[
      'hda',
      'hdb',
      'pancreat',
      'diverticul',
      'diarrea',
      'ascit',
      'hepatit',
      'hepato',
      'gastro',
    ])) {
      return 5;
    }

    if (hasAny(<String>[
      'coagulacao',
      'coagulação',
      'hemat',
      'neutropenia',
      'anemia',
    ])) {
      return 11;
    }

    if (hasAny(<String>['agitacao', 'agitação', 'psiqui', 'psicomot'])) {
      return 12;
    }

    if (hasAny(<String>[
      'meningite',
      'cistite',
      'itu_',
      'infect',
      'gripe',
      'influenza',
      'febril',
    ])) {
      return 4;
    }

    if (hasAny(<String>['rinosinus', 'faringit', 'otorr', 'orl'])) {
      return 14;
    }

    return 15;
  }

  // MEDCASES_SIMULACOES_UNIFIED_HUB_LEGACY_DEADCODE_CLEANUP_V1_B_R0
  // Dual-hub legacy removed; unified hub + topbar search are canonical.
  List<Widget> _buildUnifiedHubSliver(
    List<ProtocolModel> allDB,
    bool dark,
    bool isEs,
    AppProvider p,
  ) {
    // MEDCASES_SIMULACAO_ACTION_BAR_SAFE_MARGIN_V1_B_R0
    // Mesmo clearance móvel já homologado fisicamente na Avaliação:
    // conteúdo rolável termina acima do FloatingFooter + safe area real.
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // $1 PT, $2 ES, $3 icon, $4 surface, $5 border, $6 accent.
    final definitions = <(String, String, IconData, Color, Color, Color)>[
      (
        'Emergências',
        'Emergencias',
        Icons.emergency_rounded,
        const Color(0xFF201416),
        const Color(0xFF7F1D1D),
        const Color(0xFFF87171),
      ),
      (
        'Cardiologia',
        'Cardiología',
        Icons.favorite_outline_rounded,
        const Color(0xFF1F1419),
        const Color(0xFF7A2035),
        const Color(0xFFFC8181),
      ),
      (
        'Neurologia',
        'Neurología',
        Icons.psychology_outlined,
        const Color(0xFF1E1A2E),
        const Color(0xFF4A3880),
        const Color(0xFFA78BFA),
      ),
      (
        'Pneumologia',
        'Neumología',
        Icons.air_rounded,
        const Color(0xFF111E24),
        const Color(0xFF155E75),
        const Color(0xFF67E8F9),
      ),
      (
        'Infectologia',
        'Infectología',
        Icons.biotech_outlined,
        const Color(0xFF121F19),
        const Color(0xFF1A5E38),
        const Color(0xFF34D399),
      ),
      (
        'Gastroenterologia & Hepatologia',
        'Gastroenterología & Hepatología',
        Icons.local_hospital_outlined,
        const Color(0xFF1C1A14),
        const Color(0xFF6B5500),
        const Color(0xFFFBBF24),
      ),
      (
        'Endocrinologia & Metabólico',
        'Endocrinología & Metabólico',
        Icons.science_outlined,
        const Color(0xFF161A24),
        const Color(0xFF4338CA),
        const Color(0xFF818CF8),
      ),
      (
        'Nefrologia & Eletrólitos',
        'Nefrología & Electrolitos',
        Icons.water_drop_outlined,
        const Color(0xFF111D21),
        const Color(0xFF0E7490),
        const Color(0xFF22D3EE),
      ),
      (
        'Pediatria',
        'Pediatría',
        Icons.child_care_rounded,
        const Color(0xFF141A24),
        const Color(0xFF1D4ED8),
        const Color(0xFF60A5FA),
      ),
      (
        'Ginecologia & Obstetrícia',
        'Ginecología & Obstetricia',
        Icons.pregnant_woman_rounded,
        const Color(0xFF21151D),
        const Color(0xFF9D174D),
        const Color(0xFFF472B6),
      ),
      (
        'Trauma & Cirurgia',
        'Trauma & Cirugía',
        Icons.healing_rounded,
        const Color(0xFF201A14),
        const Color(0xFF92400E),
        const Color(0xFFFB923C),
      ),
      (
        'Hematologia',
        'Hematología',
        Icons.bloodtype_outlined,
        const Color(0xFF211416),
        const Color(0xFF991B1B),
        const Color(0xFFFCA5A5),
      ),
      (
        'Psiquiatria',
        'Psiquiatría',
        Icons.psychology_outlined,
        const Color(0xFF1D1725),
        const Color(0xFF6D28D9),
        const Color(0xFFC4B5FD),
      ),
      (
        'Toxicologia',
        'Toxicología',
        Icons.warning_amber_rounded,
        const Color(0xFF201E12),
        const Color(0xFF854D0E),
        const Color(0xFFFACC15),
      ),
      (
        'ORL & Medicina Geral',
        'ORL & Medicina General',
        Icons.hearing_outlined,
        const Color(0xFF141820),
        const Color(0xFF1E3A6E),
        const Color(0xFF60A5FA),
      ),
      (
        'Outros',
        'Otros',
        Icons.more_horiz_rounded,
        const Color(0xFF171923),
        const Color(0xFF475569),
        const Color(0xFF94A3B8),
      ),
    ];

    final buckets = List<Set<String>>.generate(
      definitions.length,
      (_) => <String>{},
    );

    for (final item in allDB) {
      final categoryIndex = _unifiedSimulationCategoryIndex(item.id);
      buckets[categoryIndex].add(item.id);
    }

    final groups = <_GrupoConfig>[
      for (var index = 0; index < definitions.length; index++)
        if (buckets[index].isNotEmpty)
          _GrupoConfig(
            icon: definitions[index].$3,
            titlePt: definitions[index].$1,
            titleEs: definitions[index].$2,
            color: definitions[index].$4,
            borderColor: definitions[index].$5,
            iconColor: definitions[index].$6,
            ids: buckets[index],
          ),
    ];

    if (allDB.isEmpty || groups.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _LibraryTabEmptyState(
            dark: dark,
            icon: Icons.cases_outlined,
            title: isEs
                ? 'Sin simulaciones disponibles'
                : 'Nenhuma simulação disponível',
            subtitle: isEs
                ? 'Las simulaciones aparecerán aquí cuando estén disponibles.'
                : 'As simulações aparecerão aqui quando estiverem disponíveis.',
          ),
        ),
      ];
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: _SimulationPlainHeader(
          dark: dark,
          title: isEs ? 'Elige una especialidad' : 'Escolha uma especialidade',
          countLabel: '${allDB.length} ${isEs ? "simulaciones" : "simulações"}',
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(0.7, 0, 0.7, 112 + safeBottom),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
            mainAxisExtent: 104,
          ),
          delegate: SliverChildBuilderDelegate((_, index) {
            final group = groups[index];
            return _GrupoCard(
              emoji: _simulationGroupSvgAsset(group.titlePt),
              titlePt: group.titlePt,
              titleEs: group.titleEs,
              ids: group.ids,
              allDB: allDB,
              isEs: isEs,
              p: p,
              dark: dark,
            );
          }, childCount: groups.length),
        ),
      ),
    ];
  }

  // ── Sub-segmento 0: Simulações (grupos de casos narrativos) ────────────────

  // ── Sub-segmento 1: Fluxos Simulados (todos os demais, com busca + filtro) ─
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÃO DE SUB-SEGMENTO
// ─────────────────────────────────────────────────────────────────────────────
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
  final String emoji;
  final String titlePt;
  final String titleEs;
  final Set<String> ids;
  final List<ProtocolModel> allDB;
  final bool isEs;
  final AppProvider p;
  final bool dark;

  const _GrupoCard({
    required this.emoji,
    required this.titlePt,
    required this.titleEs,
    required this.ids,
    required this.allDB,
    required this.isEs,
    required this.p,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final casos = allDB.where((item) => ids.contains(item.id)).toList();
    if (casos.isEmpty) return const SizedBox.shrink();

    final effectiveIsEs = p.lang == 'es' || isEs;
    final title = effectiveIsEs ? titleEs : titlePt;
    final palette = HomeV2Palette.resolve(dark);
    final caseLabel = casos.length == 1
        ? (effectiveIsEs ? 'caso clínico' : 'caso clínico')
        : (effectiveIsEs ? 'casos clínicos' : 'casos clínicos');

    return Semantics(
      button: true,
      label: '$title. ${casos.length} $caseLabel',
      child: HomeV2PressSurface(
        // MEDCASES_SIMULACAO_HOME_CARD_STANDARD_V1_B_R2
        // MEDCASES_SIMULACAO_HOME_GRID_CLEAN_V1_B_R6
        // MEDCASES_SIMULACAO_MIXED_GRID_LIST_SPACING_V1_B_R8
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
                  emoji: emoji,
                  casos: casos,
                ),
              ),
            ),
            child: SizedBox(
              height: 104,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 48,
                      child: Center(
                        child: SvgPicture.asset(
                          emoji,
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET — lista de simulações do grupo
// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA DO GRUPO — lista simples de simulações

class _SimulacoesGroupPage extends StatelessWidget {
  final String titlePt;
  final String titleEs;
  final String emoji;
  final List<ProtocolModel> casos;

  const _SimulacoesGroupPage({
    required this.titlePt,
    required this.titleEs,
    required this.emoji,
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
    final countLabel = '${casos.length} ${isEs ? "casos" : "casos"}';

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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                              ),
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
        body: Column(
          children: [
            _SimulationPlainHeader(
              dark: dark,
              title: isEs ? 'Elige un caso' : 'Escolha um caso',
              countLabel: countLabel,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: casos.length,
                itemBuilder: (_, index) {
                  final caso = casos[index];
                  final label = p.tDB(caso.title);
                  final severity = p.tDB(caso.severity);
                  final objective = _simulationLearningPreview(caso, isEs);
                  final semanticLabel = [
                    label,
                    severity,
                    objective,
                  ].where((value) => value.trim().isNotEmpty).join('. ');

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == casos.length - 1 ? 0 : 4,
                    ),
                    child: Semantics(
                      button: true,
                      label: semanticLabel,
                      child: HomeV2PressSurface(
                        // MEDCASES_SIMULATION_GROUP_FULL_PAGE_V1_B_R0
                        palette: palette,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              HomeV2SurfaceTokens.radius,
                            ),
                            overlayColor: palette.pressedOverlay,
                            onTap: () =>
                                openSimulationProtocolPage(context, caso),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Center(
                                        child: SvgPicture.asset(
                                          emoji,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.25,
                                          fontWeight: FontWeight.w700,
                                          color: palette.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: palette.textSecondary.withValues(
                                        alpha: 0.72,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTRO DE CATEGORIA (Guias PDF)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE GUIA PDF
// ─────────────────────────────────────────────────────────────────────────────

// MEDCASES_SIMULACOES_UNIFIED_SPECIALTY_TAXONOMY_REALIGN_V1_B_R0
// Shared by the hub and global search so specialty labels never diverge.
const Map<String, int> _simulationSpecialtyOverrides = <String, int>{
  'endocr_hiponatremia_sintomatica_grave_siad': 6,
  'neuro_porfiria_aguda_intermitente_crise': 2,
  'neuro_trombose_venosa_cerebral': 2,
  'infect_abscesso_epidural_espinhal': 2,
  'oftalmo_glaucoma_agudo_angulo_fechado': 14,
  'oftalmo_oclusao_arteria_central_retina': 14,
  'infect_celulite_orbitaria': 14,
  'pedi_corpo_estranho_via_aerea': 8,
  'pedi_cetoacidose_diabetica_edema_cerebral': 8,
  'pedi_kawasaki_choque': 8,
  'pedi_desidratacao_grave_choque': 8,
  'pedi_hiperbilirrubinemia_encefalopatia_aguda': 8,
  'neuro_guillain_barre_insuficiencia_respiratoria': 2,
  'neuro_hemorragia_subaracnoidea_aneurismatica': 2,
  'neuro_sindrome_cauda_equina': 2,
  'pedi_sepse_neonatal_choque': 8,
  'emerg_golpe_calor_hipertermia_grave': 0,
  'emerg_hipotermia_acidental_grave': 0,
  'neuro_miastenia_crise': 2,
  // Emergências
  'choque_hipovolemico': 0,

  // Cardiologia
  'edema_agudo_pulmao': 1,
  'insuficiencia_cardiaca_descomp': 1,
  'miocardite_aguda': 1,
  'pericardite_aguda': 1,
  'sindrome_coronariana_sem_st': 1,

  // Pneumologia
  'hemoptise_macica': 3,

  // Infectologia
  'celulite_erisipela': 4,
  'dengue_manejo': 4,
  'pielonefrite_aguda': 4,

  // Gastroenterologia & Hepatologia
  'colangite_aguda': 5,
  'colite_estercoral_impactacao_fecal': 5,
  'colite_isquemica': 5,
  'colite_ulcerativa_aguda_grave_2025': 5,
  'colite_ulcerativa_flare_2025': 5,
  'crohn_complicado_2025': 5,
  'crohn_flare_luminal_2025': 5,
  'doenca_ulcerosa_peptica_h_pylori_2024': 5,
  'encefalopatia_hepatica': 5,
  'hemorragia_digestiva_baixa': 5,
  'impactacao_alimentar_esofagica': 5,
  'megacolon_toxico': 5,
  'pbe_cirrose': 5,
  'pseudo_obstrucao_colonica_aguda_ogilvie': 5,

  // Endocrinologia & Metabólico
  'crise_adrenal': 6,

  // Nefrologia & Eletrólitos
  'colica_nefretica': 7,
  'hipercalemia_grave': 7,
  'hipocalcemia_grave': 7,
  'rabdomiolise_aguda': 7,

  // Ginecologia & Obstetrícia
  'descolamento_placenta': 9,
  'hemorragia_pos_parto': 9,

  // Trauma & Cirurgia
  'hemorragia_intra_abdominal': 10,
  'hernia_inguinal_femoral_complicada': 10,
  'hernia_ventral_umbilical_incisional_complicada': 10,
  'ileo_paralitico': 10,
  'isquemia_mesenterica_aguda_2022': 10,
  'obstrucao_adesiva_delgado_asbo': 10,
  'obstrucao_colorretal_aguda': 10,
  'obstrucao_intestinal': 10,
  'obstrucao_mecanica_alca_fechada_estrangulamento': 10,
  'obstrucao_saida_gastrica': 10,
  'perfuracao_esofagica_boerhaave': 10,
  'perfuracao_viscera_oca_peritonite_secundaria': 10,
  'sindrome_compartimental': 10,
  'ulcera_peptica_perfurada_2020': 10,
  'volvulo_cecal': 10,
  'volvulo_sigmoide': 10,

  // Psiquiatria
  'delirium_tremens': 12,
  'sindrome_abst_opioides': 12,

  // ORL & Medicina Geral
  'mastoidite_aguda': 14,
  'psiqui_tept': 12,
};

String _normalizeSimulationSearch(String value) {
  var out = value.toLowerCase().trim();
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  replacements.forEach((from, to) => out = out.replaceAll(from, to));
  return out.replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
}

int _simulationSearchCategoryIndex(String rawId) {
  final raw = rawId.toLowerCase().trim();
  final id = _normalizeSimulationSearch(raw);

  bool hasAny(List<String> values) =>
      values.any((value) => id.contains(_normalizeSimulationSearch(value)));

  if (hasAny(<String>[
    'intox',
    'intoxicacao',
    'metahemoglob',
    'botulismo',
    'ofidismo',
    'escorpionismo',
    'araneismo',
    'sindrome_serotoninergica',
  ])) {
    return 13;
  }

  final explicitCategory = _simulationSpecialtyOverrides[raw];
  if (explicitCategory != null) return explicitCategory;

  if (hasAny(<String>[
    '_ped',
    'pcr_ped',
    'pediatr',
    'bronquiolite',
    'laringite',
  ])) {
    return 8;
  }

  if (hasAny(<String>[
    'eclamps',
    'hellp',
    'obstetr',
    'gineco',
    'gravidez',
    'gestacao',
  ])) {
    return 9;
  }

  if (hasAny(<String>[
    'politrauma',
    'trauma',
    'queimadura',
    'apendicite',
    'cirurg',
  ])) {
    return 10;
  }

  if (id == 'choque' ||
      hasAny(<String>[
        'pcr adulto',
        'anafilax',
        'sepse',
        'choque sept',
        'intubacao',
        'ventilacao',
      ])) {
    return 0;
  }

  if (hasAny(<String>[
    'iam',
    'stemi',
    'icc',
    'cardio',
    'fa aguda',
    'tpsv',
    'hipertens',
    'arritm',
    'cardiogenico',
  ])) {
    return 1;
  }

  if (hasAny(<String>[
    'avc',
    'status epilep',
    'enxaqueca',
    'convuls',
    'neurolog',
  ])) {
    return 2;
  }

  if (hasAny(<String>[
    'tep',
    'tromboembolismo pulmonar',
    'asma',
    'dpoc',
    'pneum',
    'pac ',
    'respirat',
  ])) {
    return 3;
  }

  if (hasAny(<String>[
    'lesao renal',
    'renal',
    'nefro',
    'hiperpotass',
    'hipopotass',
    'hiponatr',
    'hipernatr',
    'eletrol',
  ])) {
    return 7;
  }

  if (hasAny(<String>[
    'cad shh',
    'cetoacidose',
    'hipoglic',
    'crise adrenal',
    'tireotox',
    'endocr',
    'metabol',
  ])) {
    return 6;
  }

  if (hasAny(<String>[
    'hda',
    'hdb',
    'pancreat',
    'diverticul',
    'diarrea',
    'ascit',
    'hepatit',
    'hepato',
    'gastro',
  ])) {
    return 5;
  }

  if (hasAny(<String>['coagulacao', 'hemat', 'neutropenia', 'anemia'])) {
    return 11;
  }

  if (hasAny(<String>['agitacao', 'psiqui', 'psicomot'])) {
    return 12;
  }

  if (hasAny(<String>[
    'meningite',
    'cistite',
    'itu ',
    'infect',
    'gripe',
    'influenza',
    'febril',
  ])) {
    return 4;
  }

  if (hasAny(<String>['rinosinus', 'faringit', 'otorr', 'orl'])) {
    return 14;
  }

  return 15;
}

String _simulationSearchCategoryLabel(String id, bool isEs) {
  const labels = <(String, String)>[
    ('Emergências', 'Emergencias'),
    ('Cardiologia', 'Cardiología'),
    ('Neurologia', 'Neurología'),
    ('Pneumologia', 'Neumología'),
    ('Infectologia', 'Infectología'),
    ('Gastroenterologia & Hepatologia', 'Gastroenterología & Hepatología'),
    ('Endocrinologia & Metabólico', 'Endocrinología & Metabólico'),
    ('Nefrologia & Eletrólitos', 'Nefrología & Electrolitos'),
    ('Pediatria', 'Pediatría'),
    ('Ginecologia & Obstetrícia', 'Ginecología & Obstetricia'),
    ('Trauma & Cirurgia', 'Trauma & Cirugía'),
    ('Hematologia', 'Hematología'),
    ('Psiquiatria', 'Psiquiatría'),
    ('Toxicologia', 'Toxicología'),
    ('ORL & Medicina Geral', 'ORL & Medicina General'),
    ('Outros', 'Otros'),
  ];

  final label = labels[_simulationSearchCategoryIndex(id)];
  return isEs ? label.$2 : label.$1;
}

class _SimulationPortalSearchDelegate extends SearchDelegate<ProtocolModel?> {
  _SimulationPortalSearchDelegate({required this.items, required this.isEs});

  final List<ProtocolModel> items;
  final bool isEs;

  String _title(ProtocolModel item, String lang) {
    final value = item.getField(item.title, lang).trim();
    if (value.isNotEmpty) return value;
    return item.id.replaceAll('_', ' ');
  }

  int _score(ProtocolModel item, String normalizedQuery) {
    final pt = _normalizeSimulationSearch(_title(item, 'pt'));
    final es = _normalizeSimulationSearch(_title(item, 'es'));
    final id = _normalizeSimulationSearch(item.id);
    final categoryPt = _normalizeSimulationSearch(
      _simulationSearchCategoryLabel(item.id, false),
    );
    final categoryEs = _normalizeSimulationSearch(
      _simulationSearchCategoryLabel(item.id, true),
    );

    if (pt == normalizedQuery || es == normalizedQuery) return 100;
    if (pt.startsWith(normalizedQuery) || es.startsWith(normalizedQuery)) {
      return 80;
    }
    if (id.startsWith(normalizedQuery)) return 70;
    if (pt.contains(normalizedQuery) || es.contains(normalizedQuery)) return 60;
    if (id.contains(normalizedQuery)) return 50;
    if (categoryPt.contains(normalizedQuery) ||
        categoryEs.contains(normalizedQuery)) {
      return 40;
    }
    return 0;
  }

  List<ProtocolModel> _filtered() {
    final normalizedQuery = _normalizeSimulationSearch(query);
    if (normalizedQuery.isEmpty) return const <ProtocolModel>[];

    final filtered =
        items.where((item) => _score(item, normalizedQuery) > 0).toList();

    filtered.sort((a, b) {
      final scoreA = _score(a, normalizedQuery);
      final scoreB = _score(b, normalizedQuery);
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);

      final titleA = _title(a, isEs ? 'es' : 'pt').toLowerCase();
      final titleB = _title(b, isEs ? 'es' : 'pt').toLowerCase();
      return titleA.compareTo(titleB);
    });

    return filtered;
  }

  @override
  String get searchFieldLabel =>
      isEs ? 'Buscar simulación...' : 'Buscar simulação...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return <Widget>[
      IconButton(
        tooltip: isEs ? 'Limpiar' : 'Limpar',
        onPressed: () => query = '',
        icon: const Icon(Icons.close_rounded),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: isEs ? 'Volver' : 'Voltar',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final divider = dark ? const Color(0xFF26303A) : const Color(0xFFE2E7EC);

    if (_normalizeSimulationSearch(query).isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            isEs
                ? 'Busca por diagnóstico, simulación o especialidad.'
                : 'Busque por diagnóstico, simulação ou especialidade.',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondary, fontSize: 13, height: 1.4),
          ),
        ),
      );
    }

    final filtered = _filtered();
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 34, color: secondary),
              const SizedBox(height: 10),
              Text(
                isEs ? 'Sin resultados' : 'Nenhum resultado',
                style: TextStyle(
                  color: primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: filtered.length,
      separatorBuilder: (_, __) =>
          Divider(height: 0.7, thickness: 0.7, color: divider),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final title = _title(item, isEs ? 'es' : 'pt');
        final category = _simulationSearchCategoryLabel(item.id, isEs);
        final preview = _simulationLearningPreview(item, isEs).trim();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: const Icon(
            Icons.cases_outlined,
            color: Color(0xFF10B981),
            size: 22,
          ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            preview.isEmpty ? category : '$category · $preview',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondary, fontSize: 11.5, height: 1.3),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: secondary,
            size: 20,
          ),
          onTap: () => close(context, item),
        );
      },
    );
  }
}

class _GuidePortalSearchDelegate extends SearchDelegate<GuideModel?> {
  _GuidePortalSearchDelegate({
    required this.guides,
    required this.isEs,
    required this.remoteSearch,
  });

  final List<GuideModel> guides;
  final bool isEs;
  final Future<List<GuideModel>> Function(String query) remoteSearch;

  @override
  String get searchFieldLabel =>
      isEs ? 'Buscar guía clínica' : 'Buscar guia clínico';

  String _normalize(String value) {
    var normalized = value.trim().toLowerCase();
    const from = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    for (var i = 0; i < from.length; i++) {
      normalized = normalized.replaceAll(from[i], to[i]);
    }
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<GuideModel> get _localMatches {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return guides;
    final tokens = normalized.split(' ').where((e) => e.length >= 3);

    final matches = guides.where((guide) {
      final haystack = _normalize(
        '${guide.title} ${guide.category} ${guide.description}',
      );
      return tokens.any(haystack.contains);
    }).toList(growable: false)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return matches;
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(
        tooltip: isEs ? 'Limpiar' : 'Limpar',
        onPressed: () => query = '',
        icon: const Icon(Icons.close_rounded),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: isEs ? 'Volver' : 'Voltar',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final local = _localMatches;
    if (query.trim().length < 3 || local.isNotEmpty) {
      return _resultsList(context, local);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isEs
              ? 'Pulsa buscar para consultar todo el catálogo.'
              : 'Toque em buscar para consultar todo o catálogo.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final normalized = _normalize(query);
    if (normalized.length < 3) {
      return Center(
        child: Text(
          isEs
              ? 'Escribe al menos 3 caracteres.'
              : 'Digite pelo menos 3 caracteres.',
        ),
      );
    }

    return FutureBuilder<List<GuideModel>>(
      future: remoteSearch(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return _resultsList(context, snapshot.data ?? const <GuideModel>[]);
      },
    );
  }

  Widget _resultsList(BuildContext context, List<GuideModel> results) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? const Color(0xFF9AA7B7) : const Color(0xFF64748B);

    if (results.isEmpty) {
      return Center(
        child: Text(
          isEs ? 'No se encontraron guías' : 'Nenhum guia encontrado',
          style: TextStyle(
            color: secondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final guide = results[index];
        return ListTile(
          onTap: () => close(context, guide),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: guide.coverUrl.trim().isEmpty
                  ? const ColoredBox(
                      color: Color(0xFF27313A),
                      child: Icon(
                        Icons.medical_information_outlined,
                        color: Color(0xFF94A3B8),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: guide.coverUrl.trim(),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0xFF27313A),
                        child: Icon(
                          Icons.medical_information_outlined,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
            ),
          ),
          title: Text(
            guide.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            guide.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        );
      },
    );
  }
}

class _GuideCard extends StatelessWidget {
  final GuideModel guide;
  final bool featured;
  final List<GuideModel> portalGuides;
  final ValueChanged<GuideModel> onOpenGuide;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;
  final bool dark;
  final VoidCallback onOpen;

  const _GuideCard({
    this.featured = false,
    this.portalGuides = const <GuideModel>[],
    required this.onOpenGuide,
    this.hasMore = false,
    this.loadingMore = false,
    required this.onLoadMore,
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
        border: Border.all(color: border, width: 0.7),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 9,
            top: 9,
            child: Container(width: 18, height: 2, color: accent),
          ),
          Center(child: Icon(Icons.menu_book_rounded, size: 27, color: accent)),
        ],
      ),
    );
  }

  // MEDCASES_GUIDE_PDF_SHARE_CARD_ACTION_V1_B_R1
  Future<void> _sharePdf(
    BuildContext context,
    bool isEs,
    GuideModel item,
  ) async {
    final pdfUrl = item.localizedPdfUrl(isEs).trim();

    if (!item.isPublished || pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isEs
                  ? 'PDF no disponible para compartir.'
                  : 'PDF não disponível para compartilhar.',
            ),
          ),
        );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 20),
          content: Text('Preparando PDF…'),
        ),
      );

    try {
      final uri = Uri.parse(pdfUrl);
      if (!uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw const FormatException('invalid_pdf_url');
      }

      final response = await http.get(uri).timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        throw const FormatException('guide_pdf_download_failed');
      }

      final bytes = response.bodyBytes;
      final isPdf = bytes.length >= 5 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46 &&
          bytes[4] == 0x2D;

      if (!isPdf) {
        throw const FormatException('guide_share_not_pdf');
      }

      final rawTitle = item.localizedTitle(isEs).trim();
      final safeTitle = rawTitle
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');

      final safeId = item.id
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_');

      final baseName = safeTitle.isNotEmpty
          ? safeTitle
          : (safeId.isNotEmpty ? safeId : 'guia_clinica');
      final fileName = '$baseName.pdf';

      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(
              bytes,
              mimeType: 'application/pdf',
            ),
          ],
          fileNameOverrides: <String>[fileName],
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isEs
                  ? 'No se pudo compartir el PDF. Inténtelo nuevamente.'
                  : 'Não foi possível compartilhar o PDF. Tente novamente.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!featured) {
      return const SizedBox.shrink();
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final isEs =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'es';
    final guides = portalGuides.isEmpty ? <GuideModel>[guide] : portalGuides;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = viewportWidth > 720 ? 620.0 : viewportWidth - 6.0;
    const railHeight = 356.0;

    Widget fallbackBackground() {
      return Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF17453D),
                  Color(0xFF263A4A),
                  Color(0xFF111827),
                ],
              ),
            ),
          ),
          Positioned(
            right: -34,
            top: -42,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0x2410B981),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -55,
            bottom: -70,
            child: Container(
              width: 210,
              height: 210,
              decoration: const BoxDecoration(
                color: Color(0x1FFFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.medical_information_outlined,
              size: 64,
              color: Color(0x6694A3B8),
            ),
          ),
        ],
      );
    }

    Widget backgroundFor(GuideModel item) {
      final imageUrl = item.coverUrl.trim();

      if (imageUrl.isEmpty) {
        return fallbackBackground();
      }

      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => fallbackBackground(),
        errorWidget: (_, __, ___) => fallbackBackground(),
      );
    }

    Widget portalCard(GuideModel item) {
      final category = item.category.trim().isEmpty
          ? (isEs ? 'General' : 'Geral')
          : item.category.trim();
      final description = item.description.trim();
      final byline = <String>[
        if (item.authors.trim().isNotEmpty) item.authors.trim(),
        if (item.year.trim().isNotEmpty) item.year.trim(),
      ].join(' · ');

      return SizedBox(
        width: cardWidth,
        child: Semantics(
          button: true,
          label: item.title,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onOpenGuide(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  backgroundFor(item),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.20, 0.54, 1.0],
                        colors: [
                          Color(0x08000000),
                          Color(0x66000000),
                          Color(0xF2000000),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 29,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xA6000000),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0x33FFFFFF),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5EE6B8),
                          fontSize: 10.5,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 14,
                    child: Semantics(
                      button: true,
                      label: isEs
                          ? 'Compartir PDF de ${item.title}'
                          : 'Compartilhar PDF de ${item.title}',
                      child: Material(
                        color: const Color(0xA6000000),
                        shape: const CircleBorder(
                          side: BorderSide(
                            color: Color(0x33FFFFFF),
                            width: 0.7,
                          ),
                        ),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _sharePdf(context, isEs, item),
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.ios_share_rounded,
                              size: 19,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 31,
                    right: 43,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            height: 1.10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.45,
                            shadows: [
                              Shadow(color: Color(0x99000000), blurRadius: 10),
                            ],
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE5E7EB),
                              fontSize: 13.5,
                              height: 1.38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (byline.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: Color(0xFFCBD5E1),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  byline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEs ? 'DESTACADOS' : 'DESTAQUES',
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFF334155),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (guides.length > 1)
                  Text(
                    isEs ? '${guides.length} guías' : '${guides.length} guias',
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                for (var index = 0; index < guides.length; index++) ...[
                  SizedBox(
                    height: railHeight,
                    child: portalCard(guides[index]),
                  ),
                  if (index != guides.length - 1) const SizedBox(height: 12),
                ],
                if (loadingMore) ...[
                  if (guides.isNotEmpty) const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: dark ? Colors.white70 : const Color(0xFF475569),
                      ),
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
            Icon(
              icon,
              size: 52,
              color: dark ? Colors.white12 : Colors.black.withOpacity(0.12),
            ),
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
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: dark
                  ? Colors.orangeAccent.withOpacity(0.7)
                  : Colors.redAccent,
            ),
            const SizedBox(height: 14),
            Text(
              isEs ? 'Error al cargar guías' : 'Erro ao carregar guias',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
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
  const _EmptyState({
    required this.dark,
    required this.isEs,
    this.hasSearch = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  color: dark ? Colors.white24 : Colors.black.withOpacity(0.12),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ...items.map(
              (item) => Container(
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
                child: Row(
                  children: [
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
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: text1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: text2,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _GenItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
