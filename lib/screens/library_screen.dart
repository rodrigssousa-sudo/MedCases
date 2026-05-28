import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../models/guide_model.dart';
import '../models/protocol_model.dart';
import 'protocols_screen.dart' show showProtocolDetail;

const _kDark  = Color(0xFF07110d);
const _kGreen = Color(0xFF075f45);
const _kGold  = Color(0xFFC5A365);
const _kGoldL = Color(0xFFFFE8A6);

// ─────────────────────────────────────────────────────────────────────────────
// LIBRARY SCREEN — Biblioteca Clínica (PDFs / Guias + Casos Clínicos)
// ─────────────────────────────────────────────────────────────────────────────
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
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
      final cacheCleared = await FirestoreService.clearPublishedGuidesCacheOnFirstOpen();
      _log('init first-open cacheCleared=$cacheCleared');
      final cached = await FirestoreService.loadCachedPublishedGuides().timeout(
        const Duration(seconds: 4),
        onTimeout: () => const <GuideModel>[],
      );
      if (!mounted) return;

      if (cached.isNotEmpty) {
        setState(() {
          _guides = cached;
          _guidesError = '';
          _syncCategoryWithData();
          _loading = false;
        });
        _log('init cache preload count=${cached.length}');
      }

      await _refreshGuides(forceRemote: true, reason: 'init');
      if (!mounted) return;
      _subscribeGuidesStream();
    } catch (e) {
      _log('init failed error=$e');
      if (!mounted) return;
      setState(() {
        _guidesError = e.toString();
        _loading = false;
      });
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
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

  Future<void> _openPdf(GuideModel g) async {
    final uri = Uri.tryParse(g.pdfUrl);
    if (uri == null || g.pdfUrl.isEmpty) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      FirestoreService.incrementGuideDownload(g.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';
    final bg = dark ? const Color(0xFF0A130E) : const Color(0xFFF7F8FA);
    final filtered = _filtered;

    return SafeArea(
      top: false,
      bottom: false,
      child: SizedBox.expand(
        child: ColoredBox(
          color: bg,
          child: Column(
            children: [
              _LibraryHeader(
                dark: dark,
                isEs: isEs,
                tabCtrl: _tabCtrl,
                onRefreshGuides: _handleManualRefresh,
                refreshing: _loading,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
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
                    _CasosClinicosTab(dark: dark, isEs: isEs, p: p),
                    _ProtocolsTab(dark: dark, isEs: isEs, p: p),
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
// HEADER com TabBar embutida
// ─────────────────────────────────────────────────────────────────────────────
class _LibraryHeader extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final TabController tabCtrl;
  final VoidCallback onRefreshGuides;
  final bool refreshing;
  const _LibraryHeader({
    required this.dark,
    required this.isEs,
    required this.tabCtrl,
    required this.onRefreshGuides,
    required this.refreshing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kDark,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ← CRÍTICO: não expande além do necessário
        children: [
          // Título — sem SafeArea: o Scaffold pai (shell) já gerencia o inset
          // do status bar. SafeArea duplo causava padding extra no desktop e
          // layout incorreto no mobile com AppBar.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _kGreen.withValues(alpha: 0.3),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.menu_book_rounded, color: _kGoldL, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isEs ? 'Biblioteca Clínica' : 'Biblioteca Clínica',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  Text(
                    isEs ? 'Guías • Casos • Artículos' : 'Guias • Casos • Artigos',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: isEs ? 'Actualizar guías' : 'Atualizar guias',
                child: InkWell(
                  onTap: refreshing ? null : onRefreshGuides,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _kGreen.withValues(alpha: 0.22),
                      border: Border.all(color: _kGreen.withValues(alpha: 0.45)),
                    ),
                    child: refreshing
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_kGoldL),
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            color: _kGoldL,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ]),
          ),
          // TabBar
          TabBar(
            controller: tabCtrl,
            indicatorColor: _kGold,
            indicatorWeight: 2.5,
            labelColor: _kGold,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: isEs ? 'Guías PDF' : 'Guias PDF'),
              Tab(text: isEs ? 'Casos Clínicos' : 'Casos Clínicos'),
              Tab(text: isEs ? 'Protocolos' : 'Protocolos'),
            ],
          ),
        ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABA 0 — Guias PDF
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
// ABA 1 — Casos Clínicos (migrados de protocols_screen)
// ─────────────────────────────────────────────────────────────────────────────
class _CasosClinicosTab extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final AppProvider p;
  const _CasosClinicosTab({required this.dark, required this.isEs, required this.p});

  @override
  Widget build(BuildContext context) {
    final seen  = <String>{};
    final allDB = p.protocolsDB.where((x) => seen.add(x.id)).toList();

    // IDs de todos os casos clínicos
    const allCasoIds = {
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
    };

    final totalCasos = allDB.where((d) => allCasoIds.contains(d.id)).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Banner informativo ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0D1F16) : const Color(0xFFEAF5EE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Icons.cases_rounded, color: _kGreen, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isEs ? 'Casos Clínicos' : 'Casos Clínicos',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : const Color(0xFF0F1C14),
                ),
              ),
              Text(
                isEs
                    ? '$totalCasos casos organizados por especialidad'
                    : '$totalCasos casos organizados por especialidade',
                style: TextStyle(fontSize: 12, color: dark ? Colors.white54 : Colors.black.withValues(alpha: 0.45)),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Neurologia ───────────────────────────────────────────────────────
        _CasoGroup(
          icon: Icons.psychology_outlined,
          titlePt: 'Neurologia', titleEs: 'Neurología',
          color: const Color(0xFFF5F0FF), borderColor: const Color(0xFFCCBBEE),
          iconColor: const Color(0xFF5C2D91),
          ids: const {'caso_enxaqueca_aura','caso_avc_isquemico','caso_status_epilepticus'},
          allDB: allDB, isEs: isEs, p: p,
        ),
        const SizedBox(height: 10),

        // ── Cardiologia & Pneumologia ────────────────────────────────────────
        _CasoGroup(
          icon: Icons.favorite_outline_rounded,
          titlePt: 'Cardiologia & Pneumologia', titleEs: 'Cardiología & Neumología',
          color: const Color(0xFFFFF0F5), borderColor: const Color(0xFFFFCCDD),
          iconColor: const Color(0xFFAA1144),
          ids: const {'caso_stemi','caso_icc_descompensada','caso_tep_alto_risco','caso_pac_grave'},
          allDB: allDB, isEs: isEs, p: p,
        ),
        const SizedBox(height: 10),

        // ── Infectologia, Emergência & Metabólico ────────────────────────────
        _CasoGroup(
          icon: Icons.biotech_outlined,
          titlePt: 'Infectologia, Emergência & Metabólico',
          titleEs: 'Infectología, Emergencia & Metabólico',
          color: const Color(0xFFF0FFF4), borderColor: const Color(0xFFBBE8CC),
          iconColor: const Color(0xFF075F45),
          ids: const {
            'caso_cistite_aguda','caso_itu_recorrente','caso_sepse_idoso',
            'caso_cetoacidose_diabetica','caso_anafilaxia_grave','caso_hda_varicosa',
          },
          allDB: allDB, isEs: isEs, p: p,
        ),
        const SizedBox(height: 10),

        // ── Gastroenterologia & Hepatologia ─────────────────────────────────
        _CasoGroup(
          icon: Icons.local_hospital_outlined,
          titlePt: 'Gastroenterologia & Hepatologia',
          titleEs: 'Gastroenterología & Hepatología',
          color: const Color(0xFFF5F5F0), borderColor: const Color(0xFFD8D4C0),
          iconColor: const Color(0xFF555544),
          ids: const {
            'pancreatitis_aguda_005','diarrea_aguda_009','hda_ulcera_peptica_013',
            'hdb_sangrado_rectal_014','diverticulitis_aguda_015',
            'sindrome_ascitico_debut_016','sindrome_ascitico_edematoso_017',
          },
          allDB: allDB, isEs: isEs, p: p,
        ),
        const SizedBox(height: 10),

        // ── Hepatites Virais & Gripe ─────────────────────────────────────────
        _CasoGroup(
          icon: Icons.science_outlined,
          titlePt: 'Hepatites Virais & Gripe', titleEs: 'Hepatitis Virales & Gripe',
          color: const Color(0xFFFFF8EC), borderColor: const Color(0xFFEED8A0),
          iconColor: const Color(0xFF8B6000),
          ids: const {
            'hepatitis_b_aguda_detallada_2026','hepatitis_c_cronica_detallada_2026',
            'gripe_influenza_010',
          },
          allDB: allDB, isEs: isEs, p: p,
        ),
        const SizedBox(height: 10),

        // ── ORL & Medicina Geral ─────────────────────────────────────────────
        _CasoGroup(
          icon: Icons.hearing_outlined,
          titlePt: 'ORL & Medicina Geral', titleEs: 'ORL & Medicina General',
          color: const Color(0xFFF0F8FF), borderColor: const Color(0xFFBBD6F0),
          iconColor: const Color(0xFF1A5E8A),
          ids: const {
            'rinosinusitis_aguda_007','faringitis_estreptococica_008',
            'faringitis_viral_011','faringitis_bacteriana_012',
          },
          allDB: allDB, isEs: isEs, p: p,
        ),
        const SizedBox(height: 10),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRUPO DE CASO CLÍNICO — card que abre bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CasoGroup extends StatelessWidget {
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

  const _CasoGroup({
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
        builder: (_) => _CasosSheet(
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
              color: borderColor.withValues(alpha: 0.55),
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
              '${casos.length} ${casos.length == 1 ? "caso clínico" : "casos clínicos"}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: iconColor.withValues(alpha: 0.55)),
            ),
          ])),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.chevron_right_rounded, size: 20,
              color: iconColor.withValues(alpha: 0.8)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET — lista de casos do grupo
// ─────────────────────────────────────────────────────────────────────────────
class _CasosSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color cardColor;
  final Color borderColor;
  final Color iconColor;
  final List<ProtocolModel> casos;
  final AppProvider p;
  final bool isEs;

  const _CasosSheet({
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
          // Handle
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          // Header
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
                color: iconColor.withValues(alpha: 0.6),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          Divider(color: borderColor, height: 1),
          // Lista de casos
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
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.cases_outlined, size: 18, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F1C14), height: 1.3,
                        )),
                        if (severity.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(severity, style: TextStyle(
                            fontSize: 11, color: iconColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ])),
                      Icon(Icons.arrow_forward_ios_rounded, size: 13,
                        color: iconColor.withValues(alpha: 0.5)),
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
// FILTRO DE CATEGORIA
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
                    : (dark ? const Color(0xFF1A2820) : Colors.white),
                border: Border.all(
                  color: active ? _kGreen : (dark ? Colors.white12 : Colors.black.withValues(alpha: 0.12)),
                ),
              ),
              child: Text(cat, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? Colors.white : (dark ? Colors.white60 : Colors.black.withValues(alpha: 0.54)),
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
    final cardBg   = dark ? const Color(0xFF111C15) : Colors.white;
    final border   = dark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06);
    final catColor = _categoryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
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
              Container(
                width: 48, height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: catColor.withValues(alpha: 0.12),
                  border: Border.all(color: catColor.withValues(alpha: 0.3)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.picture_as_pdf_rounded, color: catColor, size: 24),
                  Text('PDF', style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w900, color: catColor)),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: catColor.withValues(alpha: 0.12),
                  ),
                  child: Text(guide.category, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: catColor)),
                ),
                const SizedBox(height: 6),
                Text(guide.title, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : const Color(0xFF0F1C14), height: 1.3,
                )),
                if (guide.authors.isNotEmpty || guide.year.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [if (guide.authors.isNotEmpty) guide.authors,
                     if (guide.year.isNotEmpty) guide.year].join(' • '),
                    style: TextStyle(fontSize: 11,
                      color: dark ? Colors.white38 : Colors.black.withValues(alpha: 0.38)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (guide.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(guide.description, style: TextStyle(fontSize: 12,
                    color: dark ? Colors.white54 : Colors.black.withValues(alpha: 0.54), height: 1.4),
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
                      borderRadius: BorderRadius.circular(20), color: _kGreen,
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
        color: dark ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: dark ? Colors.white38 : Colors.black.withValues(alpha: 0.38)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: dark ? Colors.white38 : Colors.black.withValues(alpha: 0.38))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABA 2 — Protocolos Clínicos
// ─────────────────────────────────────────────────────────────────────────────
class _ProtocolsTab extends StatefulWidget {
  final bool dark;
  final bool isEs;
  final dynamic p;
  const _ProtocolsTab({required this.dark, required this.isEs, required this.p});

  @override
  State<_ProtocolsTab> createState() => _ProtocolsTabState();
}

class _ProtocolsTabState extends State<_ProtocolsTab> {
  int _cat = 0;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // ── Categorias: (labelPt, labelEs, icon, keywords_no_id)
  // index 0 = "Todos" (sem keywords → mostra tudo)
  // A classificação é dinâmica: cada protocolo pertence à PRIMEIRA categoria
  // cujas keywords aparecem no seu id. Se nenhuma bater → categoria "Outros".
  static const _catDefs = [
    ('Todos',            'Todos',           Icons.apps_rounded,          <String>[]),
    ('Emergências',      'Emergencias',     Icons.emergency_rounded,      <String>[
      'pcr', 'anafilaxia', 'sepse', 'choque', 'tep_agudo', 'tromboembolismo_pulmonar',
      'parada_respiratoria', 'politrauma', 'hemorragia_intra', 'caso_anafilaxia',
      'caso_tep', 'caso_stemi', 'caso_sepse',
    ]),
    ('Cardio / Neuro',   'Cardio / Neuro',  Icons.favorite_rounded,       <String>[
      'iam', 'coronariana', 'fa_aguda', 'tpsv', 'bradiarritmia', 'hipertensiva',
      'avc', 'status_epilepticus', 'insuficiencia_cardiaca', 'edema_agudo_pulmao',
      'pericardite', 'miocardite', 'caso_avc', 'caso_icc', 'caso_status_epilep',
      'caso_enxaqueca',
    ]),
    ('Respiratório',     'Respiratorio',    Icons.air_rounded,            <String>[
      'asma', 'dpoc', 'pneumonia', 'hemoptise', 'bronquiolite', 'laringite',
      'sindrome_compartimental', 'caso_pac',
    ]),
    ('Metabólico',       'Metabólico',      Icons.science_rounded,        <String>[
      'cad_shh', 'cetoacidose', 'hipoglicemia', 'hiperpotassemia', 'hipercalemia',
      'hipernatremia', 'hiponatremia', 'hipocalcemia', 'lesao_renal', 'encefalopatia',
      'crise_adrenal', 'crise_tireotoxica', 'rabdomiolise', 'caso_cetoacidose',
    ]),
    ('Digestivo',        'Digestivo',       Icons.local_hospital_rounded, <String>[
      'hda', 'hdb', 'hemorragia_digestiva', 'pancreatite', 'pancreatitis',
      'coagulacao_intravascular', 'pbe_cirrose', 'obstrucao_intestinal',
      'apendicite', 'colica_nefretica', 'colangite', 'diverticulitis', 'diarrea',
      'sindrome_ascitico', 'caso_hda',
    ]),
    ('Infecto',          'Infectologia',    Icons.bug_report_rounded,     <String>[
      'meningite', 'neutropenia_febril', 'dengue', 'celulite', 'erisipela',
      'faringit', 'faringitis', 'rinosinusitis', 'gripe', 'influenza',
      'mastoidite', 'pielonefrite', 'itu', 'cistite', 'hepatitis', 'sepse_foco',
      'caso_cistite', 'caso_itu', 'caso_pac_grave',
    ]),
    ('Intoxicações',     'Intoxicaciones',  Icons.warning_rounded,        <String>[
      'intox', 'intoxicacao', 'delirium_tremens',
    ]),
    ('Outros',           'Otros',           Icons.more_horiz_rounded,     <String>[
      'eclampsia', 'hemorragia_pos_parto', 'agitacao', 'priapismo',
      'crise_gota', 'descolamento', 'sindrome_abst', 'caso_',
    ]),
    ('Pediátrico',       'Pediátrico',      Icons.child_care_rounded,     <String>[
      '_ped', 'convulsao_febril', 'anemia_falciforme',
    ]),
  ];

  /// Retorna o índice da categoria (1-based excluindo "Todos") para um protocolo.
  /// Se nenhuma keyword bater, retorna o índice da última categoria ("Outros").
  int _catIndexForId(String id) {
    // começa em 1 para pular "Todos" (index 0), para antes da última ("Outros" = last)
    for (int ci = 1; ci < _catDefs.length - 1; ci++) {
      final keywords = _catDefs[ci].$4;
      if (keywords.any((kw) => id.contains(kw))) return ci;
    }
    return _catDefs.length - 1; // "Outros"
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _query = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = widget.dark;
    final isEs = widget.isEs;

    // Busca global: se há query, ignora categoria e busca em todos
    final List<ProtocolModel> protos;
    if (_query.isNotEmpty) {
      protos = p.protocolsDB.where((pr) {
        final t = (pr.title[isEs ? 'es' : 'pt'] ?? pr.title['pt'] ?? '').toLowerCase();
        return t.contains(_query);
      }).toList();
    } else if (_cat == 0) {
      // "Todos" → lista completa ordenada por título
      protos = [...p.protocolsDB]..sort((a, b) {
          final ta = (a.title[isEs ? 'es' : 'pt'] ?? a.title['pt'] ?? '').toLowerCase();
          final tb = (b.title[isEs ? 'es' : 'pt'] ?? b.title['pt'] ?? '').toLowerCase();
          return ta.compareTo(tb);
        });
    } else {
      // Categoria específica: classifica dinamicamente por keyword no ID
      protos = p.protocolsDB
          .where((pr) => _catIndexForId(pr.id) == _cat)
          .toList()
        ..sort((a, b) {
            final ta = (a.title[isEs ? 'es' : 'pt'] ?? a.title['pt'] ?? '').toLowerCase();
            final tb = (b.title[isEs ? 'es' : 'pt'] ?? b.title['pt'] ?? '').toLowerCase();
            return ta.compareTo(tb);
          });
    }

    final cardBg    = dark ? const Color(0xFF111C17) : Colors.white;
    final borderC   = dark ? const Color(0xFF1F3328) : const Color(0xFFDCEDDC);
    const green     = _kGreen;

    return Column(children: [
      // ── Barra de busca ────────────────────────────────────────────────────
      Container(
        color: _kDark,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: isEs ? 'Buscar protocolo…' : 'Buscar protocolo…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _kGold, size: 18),
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
                    onTap: () => _searchCtrl.clear(),
                    child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGold),
            ),
          ),
        ),
      ),

      // ── Chips de categoria (oculto durante busca) ─────────────────────────
      if (_query.isEmpty)
        Container(
          color: dark ? const Color(0xFF0D1A12) : const Color(0xFFF2F8F2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_catDefs.length, (i) {
                final active = _cat == i;
                final ci  = _catDefs[i];
                final lbl = isEs ? ci.$2 : ci.$1;
                final ico = ci.$3;
                return GestureDetector(
                  onTap: () => setState(() => _cat = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: active ? green : Colors.transparent,
                      border: Border.all(
                        color: active
                            ? green
                            : (dark ? Colors.white24 : Colors.black.withValues(alpha: 0.12))),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(ico, size: 12,
                        color: active
                            ? Colors.white
                            : (dark ? Colors.white54 : Colors.black.withValues(alpha: 0.45))),
                      const SizedBox(width: 5),
                      Text(lbl,
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : (dark ? Colors.white54 : Colors.black.withValues(alpha: 0.54)))),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ),

      // ── Contador de resultados ─────────────────────────────────────────────
      if (_query.isNotEmpty)
        Container(
          width: double.infinity,
          color: dark ? const Color(0xFF0D1A12) : const Color(0xFFF2F8F2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            isEs
                ? '${protos.length} resultado(s) para "$_query"'
                : '${protos.length} resultado(s) para "$_query"',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: dark ? Colors.white54 : Colors.black.withValues(alpha: 0.45)),
          ),
        ),

      // ── Lista de protocolos ───────────────────────────────────────────────
      Expanded(
        child: protos.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.search_off_rounded, size: 48,
                      color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.12)),
                    const SizedBox(height: 12),
                    Text(
                      isEs ? 'Sin protocolos en esta categoría'
                           : 'Nenhum protocolo nesta categoria',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: dark ? Colors.white30 : Colors.black.withValues(alpha: 0.26)),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: protos.length,
                itemBuilder: (ctx, i) {
                  final proto    = protos[i];
                  final title    = proto.getField(proto.title,    isEs ? 'es' : 'pt');
                  final severity = proto.getField(proto.severity, isEs ? 'es' : 'pt');

                  final sevLow = severity.toLowerCase();
                  final Color sevColor;
                  if (sevLow.contains('crítico') || sevLow.contains('crítica') ||
                      sevLow.contains('grave')    || sevLow.contains('alto')) {
                    sevColor = const Color(0xFFDC2626);
                  } else if (sevLow.contains('moderado') || sevLow.contains('médio') ||
                             sevLow.contains('urgência')  || sevLow.contains('urgencia')) {
                    sevColor = const Color(0xFFD97706);
                  } else {
                    sevColor = const Color(0xFF16A34A);
                  }

                  return GestureDetector(
                    onTap: () => showProtocolDetail(context, proto),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderC),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: dark ? 0.2 : 0.05),
                            blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: sevColor.withValues(alpha: 0.12),
                          ),
                          child: Icon(Icons.article_rounded,
                            size: 18, color: sevColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: dark ? Colors.white : const Color(0xFF1A1A1A),
                                height: 1.3)),
                            if (severity.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: sevColor.withValues(alpha: 0.12),
                                ),
                                child: Text(
                                  severity,
                                  style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: sevColor)),
                              ),
                            ],
                          ],
                        )),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded,
                          size: 20,
                          color: dark ? Colors.white24 : Colors.black.withValues(alpha: 0.20)),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO VAZIO
// ─────────────────────────────────────────────────────────────────────────────
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
                color: dark ? Colors.orangeAccent.withValues(alpha: 0.7) : Colors.redAccent),
            const SizedBox(height: 14),
            Text(
              isEs ? 'Error al cargar guías' : 'Erro ao carregar guias',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: dark ? Colors.white54 : Colors.black.withValues(alpha: 0.62),
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
            color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? (isEs ? 'Sin resultados' : 'Nenhum resultado')
                : (isEs ? 'Sin guías disponibles aún' : 'Nenhuma guia disponível ainda'),
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: dark ? Colors.white30 : Colors.black.withValues(alpha: 0.26),
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            Text(
              isEs ? 'El administrador aún no subió guías'
                   : 'O administrador ainda não enviou guias',
              style: TextStyle(fontSize: 13,
                color: dark ? Colors.white24 : Colors.black.withValues(alpha: 0.12)),
              textAlign: TextAlign.center,
            ),
          ],
        ]),
      ),
    );
  }
}
