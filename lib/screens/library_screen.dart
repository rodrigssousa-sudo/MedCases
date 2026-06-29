import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/medcases_webview_screen.dart'; // BUILD 323 — MANDATO 2
import '../providers/app_provider.dart';
import '../main.dart' show MainShell; // SUPER ORDEM 313: pendingTab fallback
import '../services/firestore_service.dart';
import '../models/guide_model.dart';
import '../models/protocol_model.dart';
import '../widgets/common_widgets.dart' show MedBreakpoints;
import 'protocols_screen.dart' show showProtocolDetail;

// Paleta dark unificada — verde-escuro legacy removido (PR #65)
const _kDark  = Color(0xFF1A1D23); // preto/cinza neutro padrão
const _kGreen = Color(0xFF075f45); // mantido apenas para textos/acentos ativos
const _kGold  = Color(0xFFC5A365);
const _kGoldL = Color(0xFFFFE8A6);

// ─────────────────────────────────────────────────────────────────────────────
// LIBRARY SCREEN — Biblioteca Clínica
// 2 abas: Guias PDF · Casos de Estudo
// Apple App Store Compliance: terminologia estritamente educacional/pedagógica.
// Nenhuma aba ou string usa "Protocolo" como rótulo navegável.
// ─────────────────────────────────────────────────────────────────────────────
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  // 2 abas: índice 0 = Guias PDF, índice 1 = Casos de Estudo
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _search    = '';
  String _category  = 'Todos';

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
    _log('refresh start reason=$reason forceRemote=$forceRemote kIsWeb=$kIsWeb');
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
        _guidesError = (_guides.isEmpty && serviceError.isNotEmpty)
            ? serviceError
            : '';
        _syncCategoryWithData();
        _loading = false;
      });
      _log('refresh done reason=$reason count=${list.length} error="$serviceError"');
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
    _sub = FirestoreService.guidesStream()
        .timeout(
          const Duration(seconds: 25),
          onTimeout: (sink) {
            sink.addError(
              TimeoutException('Library guides stream timeout: no events in 25s'),
            );
          },
        )
        .listen((list) {
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
    await FirestoreService.clearPublishedGuidesCache(reason: 'manual-refresh-button');
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
        final cacheCleared = await FirestoreService.clearPublishedGuidesCacheOnFirstOpen();
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
    // SUPER ORDEM VISUAL 07: 2 abas — Guias PDF (0), Casos de Estudo (1). GENERAL extinta.
    _tabCtrl = TabController(length: 2, vsync: this);
    _initGuides();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _search = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GuideModel> get _filtered {
    return _guides.where((g) {
      final matchCat  = _category == 'Todos' || g.category == _category;
      final matchText = _search.isEmpty ||
          g.title.toLowerCase().contains(_search) ||
          g.description.toLowerCase().contains(_search) ||
          g.authors.toLowerCase().contains(_search) ||
          g.category.toLowerCase().contains(_search);
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
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFF7F8FA);
    final filtered = _filtered;
    final isDesktop = MedBreakpoints.of(context).isDesktop;

    return SafeArea(
      top: false,
      bottom: false,
      child: SizedBox.expand(
        child: ColoredBox(
          color: bg,
          child: Column(
            children: [
              // BUILD 331: Topbar unificada — desktop e mobile, geométrica 48px
              _LibraryTopbar(
                dark: dark,
                isEs: isEs,
                isDesktop: isDesktop,
                onRefreshGuides: isDesktop ? _handleManualRefresh : null,
                refreshing: isDesktop ? _loading : false,
              ),
              // BUILD 331: Seletor de abas desacoplado da Topbar — fica no corpo
              _LibTabRow(
                dark: dark,
                isEs: isEs,
                tabCtrl: _tabCtrl,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // Aba 0: Guias PDF
                    _GuidesTab(
                      dark: dark,
                      isEs: isEs,
                      loading: _loading,
                      filtered: filtered,
                      categories: _categories,
                      selectedCategory: _category,
                      searchCtrl: _searchCtrl,
                      errorMessage: _guidesError,
                      onCategorySelect: (c) => setState(() => _category = c),
                      onOpen: _openPdf,
                      onRetry: _handleManualRefresh,
                    ),
                    // Aba 1: Casos de Estudo
                    _CasosDeEstudoTab(dark: dark, isEs: isEs, p: p),
                  ],
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
// BUILD 331 — TOPBAR BIBLIOTECA
// Geometria estrita: PreferredSize 48px, SafeArea(bottom:false), SizedBox(48),
// padding h:12, fundo sólido adaptativo, border 0.5px, BoxShadow blur:6.
// Título "BIBLIOTECA" centralizado via Stack — sem desvio do botão de voltar.
// ─────────────────────────────────────────────────────────────────────────────
class _LibraryTopbar extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final bool isDesktop;
  final VoidCallback? onRefreshGuides;
  final bool refreshing;

  const _LibraryTopbar({
    required this.dark,
    required this.isEs,
    required this.isDesktop,
    this.onRefreshGuides,
    this.refreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // BUILD 331 BIBLIOTECA: gradiente idêntico ao card BIBLIOTECA da Home
        // topLeft #222D42 (slate escuro) → bottomRight #4B5E7F (azul acinzentado)
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF222D42), Color(0xFF4B5E7F)],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF334155), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Fix #4: topbar bleed — Builder lê topPad e dimensiona Container para
      // topPad+48, empurrando conteúdo interativo abaixo da Dynamic Island.
      child: Builder(
        builder: (ctx) {
          final topPad = MediaQuery.of(ctx).padding.top;
          return SizedBox(
            height: topPad + 48,
            child: Padding(
              padding: EdgeInsets.only(top: topPad),
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── CENTER: título BRANCO — contraste máximo sobre slate gray
                const Text(
                  'BIBLIOTECA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                // ── LEFT: botão de voltar BRANCO — SizedBox 36×36 ─────────
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
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // ── RIGHT: botão refresh (desktop only) ───────────────────
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
          ),
            ),
          );
        },
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
    required this.dark, required this.isEs, required this.loading,
    required this.filtered, required this.categories,
    required this.selectedCategory, required this.searchCtrl,
    required this.errorMessage, required this.onCategorySelect,
    required this.onOpen, required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final hasSearch = searchCtrl.text.isNotEmpty;
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
                    : _EmptyState(
                        dark: dark,
                        isEs: isEs,
                        hasSearch: hasSearch,
                      ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
      slivers: [
        if (categories.length > 1)
          SliverToBoxAdapter(
            child: _CategoryFilter(
              categories: categories,
              selected: selectedCategory,
              dark: dark,
              onSelect: onCategorySelect,
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: isEs ? 'Buscar guías...' : 'Buscar guias...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        bodySliver,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABA 1 — Casos de Estudo
// Fusão pedagógica: Casos Clínicos (simulações interativas) + Fluxos Simulados
// por Especialidade (conteúdo antes em "Protocolos"). Nomenclatura 100%
// educacional — sem qualquer rótulo de "Protocolo" visível ao usuário.
// ─────────────────────────────────────────────────────────────────────────────
class _CasosDeEstudoTab extends StatefulWidget {
  final bool dark;
  final bool isEs;
  final AppProvider p;
  const _CasosDeEstudoTab({required this.dark, required this.isEs, required this.p});

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
    'caso_stemi', 'caso_icc_descompensada', 'caso_tep_alto_risco', 'caso_pac_grave',
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
  static const List<_GrupoConfig> _gruposSimulacao = [
    _GrupoConfig(
      icon: Icons.psychology_outlined,
      titlePt: 'Neurologia',
      titleEs: 'Neurología',
      color: Color(0xFFF5F0FF),
      borderColor: Color(0xFFCCBBEE),
      iconColor: Color(0xFF5C2D91),
      ids: {'caso_enxaqueca_aura', 'caso_avc_isquemico', 'caso_status_epilepticus'},
    ),
    _GrupoConfig(
      icon: Icons.favorite_outline_rounded,
      titlePt: 'Cardiologia & Pneumologia',
      titleEs: 'Cardiología & Neumología',
      color: Color(0xFFFFF0F5),
      borderColor: Color(0xFFFFCCDD),
      iconColor: Color(0xFFAA1144),
      ids: {'caso_stemi', 'caso_icc_descompensada', 'caso_tep_alto_risco', 'caso_pac_grave'},
    ),
    _GrupoConfig(
      icon: Icons.biotech_outlined,
      titlePt: 'Infectologia, Emergência & Metabólico',
      titleEs: 'Infectología, Emergencia & Metabólico',
      color: Color(0xFFF0FFF4),
      borderColor: Color(0xFFBBE8CC),
      iconColor: Color(0xFF075F45),
      ids: {
        'caso_cistite_aguda', 'caso_itu_recorrente', 'caso_sepse_idoso',
        'caso_cetoacidose_diabetica', 'caso_anafilaxia_grave', 'caso_hda_varicosa',
      },
    ),
    _GrupoConfig(
      icon: Icons.local_hospital_outlined,
      titlePt: 'Gastroenterologia & Hepatologia',
      titleEs: 'Gastroenterología & Hepatología',
      color: Color(0xFFF5F5F0),
      borderColor: Color(0xFFD8D4C0),
      iconColor: Color(0xFF555544),
      ids: {
        'pancreatitis_aguda_005', 'diarrea_aguda_009', 'hda_ulcera_peptica_013',
        'hdb_sangrado_rectal_014', 'diverticulitis_aguda_015',
        'sindrome_ascitico_debut_016', 'sindrome_ascitico_edematoso_017',
      },
    ),
    _GrupoConfig(
      icon: Icons.science_outlined,
      titlePt: 'Hepatites Virais & Gripe',
      titleEs: 'Hepatitis Virales & Gripe',
      color: Color(0xFFFFF8EC),
      borderColor: Color(0xFFEED8A0),
      iconColor: Color(0xFF8B6000),
      ids: {
        'hepatitis_b_aguda_detallada_2026', 'hepatitis_c_cronica_detallada_2026',
        'gripe_influenza_010',
      },
    ),
    _GrupoConfig(
      icon: Icons.hearing_outlined,
      titlePt: 'ORL & Medicina Geral',
      titleEs: 'ORL & Medicina General',
      color: Color(0xFFF0F8FF),
      borderColor: Color(0xFFBBD6F0),
      iconColor: Color(0xFF1A5E8A),
      ids: {
        'rinosinusitis_aguda_007', 'faringitis_estreptococica_008',
        'faringitis_viral_011', 'faringitis_bacteriana_012',
      },
    ),
  ];

  // ── Categorias para sub-segmento "Fluxos Simulados" ──────────────────────
  // Classificação dinâmica por keywords no id — igual à lógica anterior
  static const _catDefs = [
    ('Todos',            'Todos',           Icons.apps_rounded,          <String>[]),
    ('Emergências',      'Emergencias',     Icons.emergency_rounded,      <String>[
      'pcr', 'anafilaxia', 'sepse', 'choque', 'tep_agudo', 'tromboembolismo_pulmonar',
      'politrauma', 'caso_anafilaxia', 'caso_tep', 'caso_stemi', 'caso_sepse',
    ]),
    ('Cardio / Neuro',   'Cardio / Neuro',  Icons.favorite_rounded,       <String>[
      'iam', 'fa_aguda', 'tpsv', 'hipertensiva',
      'avc', 'status_epilepticus',
      'caso_avc', 'caso_icc', 'caso_status_epilep', 'caso_enxaqueca',
    ]),
    ('Respiratório',     'Respiratorio',    Icons.air_rounded,            <String>[
      'asma', 'dpoc', 'pneumonia', 'bronquiolite', 'laringite', 'caso_pac',
    ]),
    ('Metabólico',       'Metabólico',      Icons.science_rounded,        <String>[
      'cad_shh', 'cetoacidose', 'hipoglicemia', 'hiperpotassemia',
      'lesao_renal', 'crise_adrenal', 'crise_tireotoxica', 'caso_cetoacidose',
    ]),
    ('Digestivo',        'Digestivo',       Icons.local_hospital_rounded, <String>[
      'hda', 'hdb', 'pancreatite', 'pancreatitis',
      'coagulacao_intravascular', 'diverticulitis', 'diarrea',
      'sindrome_ascitico', 'caso_hda',
    ]),
    ('Infecto',          'Infectología',    Icons.bug_report_rounded,     <String>[
      'meningite', 'neutropenia_febril', 'faringit', 'faringitis',
      'rinosinusitis', 'gripe', 'hepatitis', 'sepse_foco',
      'caso_cistite', 'caso_itu', 'caso_pac_grave',
    ]),
    ('Intoxicações',     'Intoxicaciones',  Icons.warning_rounded,        <String>[
      'intox', 'intoxicacao',
    ]),
    ('Outros',           'Otros',           Icons.more_horiz_rounded,     <String>[
      'eclampsia', 'agitacao', 'caso_',
    ]),
    ('Pediátrico',       'Pediátrico',      Icons.child_care_rounded,     <String>[
      '_ped', 'pcr_ped', 'bronquiolite', 'laringite',
    ]),
  ];

  int _fluxoCat = 0;
  final _searchFluxoCtrl = TextEditingController();
  String _queryFluxo = '';

  @override
  void initState() {
    super.initState();
    _searchFluxoCtrl.addListener(() {
      if (mounted) setState(() => _queryFluxo = _searchFluxoCtrl.text.toLowerCase().trim());
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

    // Conta total de itens de estudo (todos os IDs absorvidos)
    final totalItens = allDB.where((d) => _casoNarrativoIds.contains(d.id)).length
        + allDB.where((d) => !_casoNarrativoIds.contains(d.id)).length;

    return CustomScrollView(
      primary: false,
      slivers: [
        // ── Banner de cabeçalho da aba ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF252930) : const Color(0xFFEAF5EE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGreen.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.school_outlined, color: _kGreen, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isEs ? 'Casos de Estudio' : 'Casos de Estudo',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900,
                        color: dark ? Colors.white : const Color(0xFF0F1116),
                      ),
                    ),
                    Text(
                      isEs
                          ? '$totalItens casos simulados para fins educacionais'
                          : '$totalItens casos simulados para fins educacionais',
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.white54 : Colors.black.withOpacity(0.45),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),

        // ── Seletor de sub-segmento ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              _SegmentBtn(
                label: isEs ? 'Simulaciones' : 'Simulações',
                icon: Icons.cases_rounded,
                active: _segment == 0,
                dark: dark,
                onTap: () => setState(() => _segment = 0),
              ),
              const SizedBox(width: 8),
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
    List<ProtocolModel> allDB, bool dark, bool isEs, AppProvider p,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final group = groups[i];
              return Padding(
                padding: EdgeInsets.only(bottom: i == groups.length - 1 ? 0 : 10),
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
    List<ProtocolModel> allDB, bool dark, bool isEs,
  ) {
    final List<ProtocolModel> fluxos;
    if (_queryFluxo.isNotEmpty) {
      fluxos = allDB.where((pr) {
        final t = (pr.title[isEs ? 'es' : 'pt'] ?? pr.title['pt'] ?? '').toLowerCase();
        return t.contains(_queryFluxo);
      }).toList();
    } else if (_fluxoCat == 0) {
      fluxos = [...allDB]..sort((a, b) {
          final ta = (a.title[isEs ? 'es' : 'pt'] ?? a.title['pt'] ?? '').toLowerCase();
          final tb = (b.title[isEs ? 'es' : 'pt'] ?? b.title['pt'] ?? '').toLowerCase();
          return ta.compareTo(tb);
        });
    } else {
      fluxos = allDB
          .where((pr) => _catIndexForId(pr.id) == _fluxoCat)
          .toList()
        ..sort((a, b) {
            final ta = (a.title[isEs ? 'es' : 'pt'] ?? a.title['pt'] ?? '').toLowerCase();
            final tb = (b.title[isEs ? 'es' : 'pt'] ?? b.title['pt'] ?? '').toLowerCase();
            return ta.compareTo(tb);
          });
    }

    final cardBg = dark ? const Color(0xFF252930) : Colors.white;
    final borderC = dark ? const Color(0xFF374151) : const Color(0xFFDCEDDC);

    final bodySliver = fluxos.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: _LibraryTabEmptyState(
              dark: dark,
              icon: Icons.search_off_rounded,
              title: isEs ? 'Sin casos en esta categoría' : 'Nenhum caso nesta categoria',
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final item = fluxos[i];
                  final title = item.getField(item.title, isEs ? 'es' : 'pt');
                  final severity = item.getField(item.severity, isEs ? 'es' : 'pt');
                  final sevLow = severity.toLowerCase();
                  final Color sevColor;
                  if (sevLow.contains('crítico') || sevLow.contains('crítica') ||
                      sevLow.contains('grave') || sevLow.contains('alto')) {
                    sevColor = const Color(0xFFDC2626);
                  } else if (sevLow.contains('moderado') || sevLow.contains('médio') ||
                      sevLow.contains('urgência') || sevLow.contains('urgencia')) {
                    sevColor = const Color(0xFFD97706);
                  } else {
                    sevColor = const Color(0xFF16A34A);
                  }
                  return GestureDetector(
                    onTap: () => showProtocolDetail(context, item),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderC),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(dark ? 0.2 : 0.05),
                            blurRadius: 6, offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: sevColor.withOpacity(0.12),
                          ),
                          child: Icon(Icons.school_outlined, size: 18, color: sevColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(title,
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: dark ? Colors.white : const Color(0xFF1A1D23),
                                height: 1.3,
                              ),
                            ),
                            if (severity.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: sevColor.withOpacity(0.12),
                                ),
                                child: Text(severity,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sevColor)),
                              ),
                            ],
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 20,
                          color: dark ? Colors.white24 : Colors.black.withOpacity(0.20)),
                      ]),
                    ),
                  );
                },
                childCount: fluxos.length,
              ),
            ),
          );

    return [
      // Barra de busca (estilo escuro igual ao anterior)
      SliverToBoxAdapter(
        child: Container(
          color: _kDark,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _searchFluxoCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: isEs ? 'Buscar caso simulado…' : 'Buscar caso simulado…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _kGold, size: 18),
              suffixIcon: _queryFluxo.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _searchFluxoCtrl.clear(),
                      child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: _kGold),
              ),
            ),
          ),
        ),
      ),
      // Filtro de categoria (visível quando sem busca)
      if (_queryFluxo.isEmpty)
        SliverToBoxAdapter(
          child: Container(
            color: dark ? const Color(0xFF252930) : const Color(0xFFF2F8F2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_catDefs.length, (i) {
                  final active = _fluxoCat == i;
                  final ci = _catDefs[i];
                  final lbl = isEs ? ci.$2 : ci.$1;
                  final ico = ci.$3;
                  return GestureDetector(
                    onTap: () => setState(() => _fluxoCat = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: active ? _kGreen : Colors.transparent,
                        border: Border.all(
                          color: active
                              ? _kGreen
                              : (dark ? Colors.white24 : Colors.black.withOpacity(0.12)),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(ico, size: 12,
                          color: active ? Colors.white : (dark ? Colors.white54 : Colors.black.withOpacity(0.45))),
                        const SizedBox(width: 5),
                        Text(lbl, style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: active ? Colors.white : (dark ? Colors.white54 : Colors.black.withOpacity(0.54)),
                        )),
                      ]),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      // Contador de resultados durante busca
      if (_queryFluxo.isNotEmpty)
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            color: dark ? const Color(0xFF252930) : const Color(0xFFF2F8F2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '${fluxos.length} resultado(s) para "$_queryFluxo"',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: dark ? Colors.white54 : Colors.black.withOpacity(0.45),
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
    required this.label, required this.icon,
    required this.active, required this.dark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active
                ? _kGreen
                : (dark ? const Color(0xFF252930) : const Color(0xFFEAF5EE)),
            border: Border.all(
              color: active ? _kGreen : _kGreen.withOpacity(0.25),
            ),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14,
              color: active ? Colors.white : _kGreen.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800,
              color: active ? Colors.white : _kGreen.withOpacity(0.85),
            )),
          ]),
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

  const _GrupoCard({
    required this.icon, required this.titlePt, required this.titleEs,
    required this.color, required this.borderColor, required this.iconColor,
    required this.ids, required this.allDB, required this.isEs, required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final casos = allDB.where((d) => ids.contains(d.id)).toList();
    if (casos.isEmpty) return const SizedBox.shrink();
    final title = isEs ? titleEs : titlePt;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SimulacoesSheet(
          title: title, icon: icon,
          cardColor: color, borderColor: borderColor, iconColor: iconColor,
          casos: casos, p: p, isEs: isEs,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Icon(icon, size: 20, color: iconColor)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w900,
              color: iconColor, letterSpacing: -0.2,
            )),
            const SizedBox(height: 3),
            Text(
              // Bilíngue pedagógico: "casos de estudo" em vez de "casos clínicos"
              '${casos.length} ${casos.length == 1
                  ? (isEs ? "caso de estudio" : "caso de estudo")
                  : (isEs ? "casos de estudio" : "casos de estudo")}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: iconColor.withOpacity(0.55)),
            ),
          ])),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.chevron_right_rounded, size: 20,
              color: iconColor.withOpacity(0.8)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET — lista de simulações do grupo
// ─────────────────────────────────────────────────────────────────────────────
class _SimulacoesSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color cardColor;
  final Color borderColor;
  final Color iconColor;
  final List<ProtocolModel> casos;
  final AppProvider p;
  final bool isEs;

  const _SimulacoesSheet({
    required this.title, required this.icon,
    required this.cardColor, required this.borderColor, required this.iconColor,
    required this.casos, required this.p, required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.25),
              borderRadius: BorderRadius.circular(2),
            )),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: iconColor,
              ))),
              Text('${casos.length}', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: iconColor.withOpacity(0.6),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          Divider(color: borderColor, height: 1),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              itemCount: casos.length,
              itemBuilder: (_, i) {
                final caso = casos[i];
                final label = p.tDB(caso.title);
                final severity = p.tDB(caso.severity);
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    showProtocolDetail(context, caso);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.school_outlined, size: 18, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800,
                          color: Color(0xFF0F1116), height: 1.3,
                        )),
                        if (severity.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(severity, style: TextStyle(
                            fontSize: 11, color: iconColor.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ])),
                      Icon(Icons.arrow_forward_ios_rounded, size: 13,
                        color: iconColor.withOpacity(0.5)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
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
  final ValueChanged<String> onSelect;
  const _CategoryFilter({
    required this.categories, required this.selected,
    required this.dark, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat    = categories[i];
          final active = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active
                    ? _kGreen
                    : (dark ? const Color(0xFF2D3340) : Colors.white),
                border: Border.all(
                  color: active ? _kGreen : (dark ? Colors.white12 : Colors.black.withOpacity(0.12)),
                ),
              ),
              child: Text(cat, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? Colors.white : (dark ? Colors.white60 : Colors.black.withOpacity(0.54)),
              )),
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
  const _GuideCard({required this.guide, required this.dark, required this.onOpen});

  Color get _categoryColor {
    switch (guide.category) {
      case 'Emergência':         return const Color(0xFFEF4444);
      case 'Cardiologia':        return const Color(0xFFEC4899);
      case 'Infectologia':       return const Color(0xFF10B981);
      case 'Pediatria':          return const Color(0xFF3B82F6);
      case 'Neurologia':         return const Color(0xFF8B5CF6);
      case 'Pneumologia':        return const Color(0xFF06B6D4);
      case 'UTI / Intensivismo': return const Color(0xFFF97316);
      case 'Farmacologia':       return const Color(0xFFA855F7);
      default:                   return _kGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg   = dark ? const Color(0xFF252930) : Colors.white;
    final border   = dark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.06);
    final catColor = _categoryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.25 : 0.06),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Thumbnail dinâmico (Build 169) ─────────────────────────────
              // Se coverUrl preenchida → CachedNetworkImage com bordas arredondadas
              // Se vazia → fallback ao ícone clássico verde de PDF (retrocompat.)
              if (guide.coverUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: guide.coverUrl,
                    width: 56, height: 64,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 56, height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: catColor.withOpacity(0.12),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(catColor),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 56, height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: catColor.withOpacity(0.12),
                        border: Border.all(color: catColor.withOpacity(0.3)),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.picture_as_pdf_rounded, color: catColor, size: 24),
                        Text('PDF', style: TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w900, color: catColor)),
                      ]),
                    ),
                  ),
                )
              else
                Container(
                  width: 56, height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: catColor.withOpacity(0.12),
                    border: Border.all(color: catColor.withOpacity(0.3)),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.picture_as_pdf_rounded, color: catColor, size: 24),
                    Text('PDF', style: TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w900, color: catColor)),
                  ]),
                ),
              // ───────────────────────────────────────────────────────────────
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: catColor.withOpacity(0.12),
                  ),
                  child: Text(guide.category, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: catColor)),
                ),
                const SizedBox(height: 6),
                Text(guide.title, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : const Color(0xFF0F1116), height: 1.3,
                )),
                if (guide.authors.isNotEmpty || guide.year.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [if (guide.authors.isNotEmpty) guide.authors,
                     if (guide.year.isNotEmpty) guide.year].join(' • '),
                    style: TextStyle(fontSize: 11,
                      color: dark ? Colors.white38 : Colors.black.withOpacity(0.38)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (guide.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(guide.description, style: TextStyle(fontSize: 12,
                    color: dark ? Colors.white54 : Colors.black.withOpacity(0.54), height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  if (guide.fileSizeLabel.isNotEmpty)
                    _Chip(label: guide.fileSizeLabel, icon: Icons.storage_rounded, dark: dark),
                  if (guide.downloadCount > 0) ...[
                    const SizedBox(width: 6),
                    _Chip(label: '${guide.downloadCount}',
                      icon: Icons.download_rounded, dark: dark),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      // BUILD 277-CROMATICO: BorderRadius.circular(12)
                      borderRadius: BorderRadius.circular(12), color: _kGreen,
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 5),
                      Text('Abrir', style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                  ),
                ]),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool dark;
  const _Chip({required this.label, required this.icon, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: dark ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: dark ? Colors.white38 : Colors.black.withOpacity(0.38)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: dark ? Colors.white38 : Colors.black.withOpacity(0.38))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS VAZIOS / ERRO
// ─────────────────────────────────────────────────────────────────────────────
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
            Icon(icon, size: 52,
              color: dark ? Colors.white12 : Colors.black.withOpacity(0.12)),
            const SizedBox(height: 14),
            Text(title,
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: dark ? Colors.white54 : Colors.black.withOpacity(0.52),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(subtitle,
              style: TextStyle(
                fontSize: 12, height: 1.4,
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
            Icon(Icons.cloud_off_rounded, size: 56,
                color: dark ? Colors.orangeAccent.withOpacity(0.7) : Colors.redAccent),
            const SizedBox(height: 14),
            Text(
              isEs ? 'Error al cargar guías' : 'Erro ao carregar guias',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message,
              style: TextStyle(
                fontSize: 12, height: 1.4,
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
  const _EmptyState({required this.dark, required this.isEs, this.hasSearch = false});

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
                : (isEs ? 'Sin guías disponibles aún' : 'Nenhuma guia disponível ainda'),
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: dark ? Colors.white30 : Colors.black.withOpacity(0.26),
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            Text(
              isEs ? 'El administrador aún no subió guías'
                   : 'O administrador ainda não enviou guias',
              style: TextStyle(fontSize: 13,
                color: dark ? Colors.white24 : Colors.black.withOpacity(0.12)),
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
    final bg    = dark ? const Color(0xFF1A1D23) : const Color(0xFFF7F8FA);
    final card  = dark ? const Color(0xFF22262F) : Colors.white;
    final text1 = dark ? Colors.white          : const Color(0xFF0F1116);
    final text2 = dark ? Colors.white54        : Colors.black54;

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
              fontSize: 20, fontWeight: FontWeight.w800, color: text1,
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
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: item.color.withOpacity(dark ? 0.22 : 0.12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: text1)),
                  const SizedBox(height: 3),
                  Text(item.subtitle,
                    style: TextStyle(fontSize: 12, color: text2, height: 1.4)),
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
  const _GenItem({required this.icon, required this.color, required this.title, required this.subtitle});
}
