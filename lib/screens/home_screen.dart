import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../data/drugs_database.dart';
import '../models/drug_model.dart';
import '../services/drug_interaction_service.dart';
import '../services/notification_service.dart';
import 'cockpit_screen.dart';
import 'drugs_screen.dart' show DrugsScreen, showDrugDetailSheet;
import 'prescripciones_screen.dart' show PrescripcionesScreen, prescriptionModels;
import 'tools_screen.dart' show PediatricsTabContent, ToolsScreen, toolsScreenTabNotifier;
import 'prescripciones_screen.dart';
import 'drug_interactions_screen.dart';
import 'protocols_screen.dart' show openProtocolById, showProtocolDetail;
import '../models/protocol_model.dart';
import 'avaliacao_screen.dart';
import '../widgets/meu_plantao_dashboard.dart';
import 'ai_screen.dart' show AiScreen;

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN — 4 cards de navegação principal
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onTabChange;
  final ValueChanged<int> onSubTabChange;
  final Function(String) openProtocol;
  final VoidCallback onOpenNotes;
  final VoidCallback? onCheckUpdate;

  const HomeScreen({
    super.key,
    required this.onTabChange,
    required this.onSubTabChange,
    required this.openProtocol,
    required this.onOpenNotes,
    this.onCheckUpdate,
  });

  static void _openAvaliacao(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const AvaliacaoScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 320),
    ));
  }

  // Método estático de rota — acessível de qualquer lugar sem instância
  static Route slideRoute(Widget page) => _HomeScreenState._slide(page);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // context.select — rebuilt APENAS quando darkMode ou lang muda,
    // não a cada notifyListeners() geral do AppProvider
    final dark = context.select<AppProvider, bool>((p) => p.darkMode);
    final isEs = context.select<AppProvider, bool>((p) => p.lang == 'es');
    // p via read para campos que não disparam rebuild por si só
    final p  = context.read<AppProvider>();
    final bp = MedBreakpoints.of(context);

    // Desktop: layout em 2 colunas
    if (bp.isDesktop) {
      return _buildDesktopLayout(context, dark, isEs, p, bp);
    }
    // Mobile/Tablet: layout original em coluna única
    return _buildMobileLayout(context, dark, isEs, p);
  }

  Widget _buildDesktopLayout(BuildContext context, bool dark, bool isEs, AppProvider p, MedBreakpoints bp) {
    final hPad = bp.hPadding;

    // Helpers de navegação inline para o desktop
    void push(Widget page) => Navigator.of(context).push(_HomeScreenState._slide(page));

    // Definição dos cards principais para o grid desktop
    // Ordem: FÁRMACOS → INTERAÇÕES → SIMULAÇÕES → PEDIATRIA → ADULTO
    final mainCards = [
      _HomeCardData(
        icon: Icons.medication_rounded,
        label: 'FÁRMACOS',
        subtitle: isEs
            ? 'Actualizados en 2026'
            : 'Atualizados em 2026',
        gradientColors: const [Color(0xFF3B2200), Color(0xFF6B3A00), Color(0xFF9A5B00)],
        accentColor: const Color(0xFFFBBF24),
        onTap: () => push(const _FarmacosShell()),
      ),
      _HomeCardData(
        icon: Icons.compare_arrows_rounded,
        label: isEs ? 'INTERACCIONES' : 'INTERAÇÕES',
        subtitle: isEs
            ? '+${DrugInteractionService.totalInteractions} pares con evidencia'
            : '+${DrugInteractionService.totalInteractions} pares com evidência',
        gradientColors: const [Color(0xFF3B0A1E), Color(0xFF5E1234), Color(0xFF8B1E4F)],
        accentColor: const Color(0xFFFF6BA0),
        onTap: () => push(const DrugInteractionsScreen()),
      ),
      _HomeCardData(
        icon: Icons.description_rounded,
        label: isEs ? 'SIMULACIONES' : 'SIMULAÇÕES',
        subtitle: isEs
            ? '${prescriptionModels(true).length} ejemplos'
            : '${prescriptionModels(false).length} exemplos',
        gradientColors: const [Color(0xFF2A0B52), Color(0xFF3D1280), Color(0xFF5B21B6)],
        accentColor: const Color(0xFFA78BFA),
        onTap: () => push(const _PrescripcionesShell()),
      ),
      _HomeCardData(
        icon: Icons.child_care_rounded,
        label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
        subtitle: isEs ? 'Protocolos pediátricos' : 'Protocolos pediátricos',
        gradientColors: const [Color(0xFF0A2540), Color(0xFF103D70), Color(0xFF2563EB)],
        accentColor: const Color(0xFF93C5FD),
        onTap: () => push(const _PediatricsShell()),
      ),
      _HomeCardData(
        icon: Icons.person_rounded,
        label: 'ADULTO',
        subtitle: isEs ? 'Crear un protocolo adulto' : 'Criar um protocolo adulto',
        gradientColors: const [Color(0xFF052E1A), Color(0xFF0A5C2E), Color(0xFF15803D)],
        accentColor: const Color(0xFF4ADE80),
        onTap: () => push(_AdultoShell(openProtocol: widget.openProtocol)),
      ),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Linha superior: pesquisa ──────────────────────────────────────
        _HomeSearchBar(dark: dark, isEs: isEs),
        const SizedBox(height: 14),

        // ── Timer Rápido de Plantão ───────────────────────────────────────
        _ShiftTimerBar(dark: dark, isEs: isEs),
        const SizedBox(height: 24),

        // ── Grid de cards principais — 3 colunas no desktop ───────────────
        LayoutBuilder(builder: (context, constraints) {
          const cols   = 3;
          const gap    = 14.0;
          final width  = (constraints.maxWidth - gap * (cols - 1)) / cols;
          final rows   = (mainCards.length / cols).ceil();

          return Column(
            children: List.generate(rows, (rowIdx) {
              final start = rowIdx * cols;
              final end   = (start + cols).clamp(0, mainCards.length);
              final rowItems = mainCards.sublist(start, end);

              return Padding(
                padding: EdgeInsets.only(bottom: rowIdx < rows - 1 ? gap : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < rowItems.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: width,
                        child: _HomeCard(
                          icon:           rowItems[i].icon,
                          label:          rowItems[i].label,
                          subtitle:       rowItems[i].subtitle,
                          gradientColors: rowItems[i].gradientColors,
                          accentColor:    rowItems[i].accentColor,
                          dark:           dark,
                          onTap:          rowItems[i].onTap,
                        ),
                      ),
                    ],
                    // Preenche colunas vazias na última linha
                    for (int i = rowItems.length; i < cols; i++) ...[
                      if (i > 0 || rowItems.isNotEmpty) const SizedBox(width: gap),
                      SizedBox(width: width),
                    ],
                  ],
                ),
              );
            }),
          );
        }),

        const SizedBox(height: 24),
        _HomeDivider(dark: dark),
        const SizedBox(height: 20),

        // ── Layout de 2 colunas: Shortcuts + Emergências ─────────────────
        LayoutBuilder(builder: (context, constraints) {
          final half = (constraints.maxWidth - 20) / 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna 1: Atalhos + Plantão
              SizedBox(
                width: half,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _QuickShortcuts(
                    dark: dark,
                    isEs: isEs,
                    openProtocol: widget.openProtocol,
                    onOpenNotes: widget.onOpenNotes,
                    onCheckUpdate: widget.onCheckUpdate,
                  ),
                  const SizedBox(height: 20),
                  _HomeDivider(dark: dark),
                  const SizedBox(height: 20),
                  MeuPlantaoDashboard(
                    onOpenDrug: (drug) => showDrugDetailSheet(context, drug),
                    onOpenCalc: (calcId) {
                      const calcTabMap = {
                        'calc_biometria':   0,
                        'calc_scores':      1,
                        'calc_cardio':      2,
                        'calc_eletrólitos': 3,
                        'calc_infusao':     4,
                        'calc_referencia':  5,
                        'calc_prescricoes': 6,
                        'calc_pediatria':   7,
                      };
                      // Define a aba ANTES de mudar de tela para que o listener
                      // do ToolsScreen já receba ao montar/ativar.
                      toolsScreenTabNotifier.value = calcTabMap[calcId] ?? 0;
                      widget.onTabChange(4);
                    },
                    onManageTap: () => showPlantaoManageSheet(context),
                  ),
                ]),
              ),

              const SizedBox(width: 20),

              // Coluna 2: Emergências
              SizedBox(
                width: half,
                child: _QuickEmergencies(
                  p: p,
                  dark: dark,
                  isEs: isEs,
                  openProtocol: widget.openProtocol,
                ),
              ),
            ],
          );
        }),
      ]),
    );
  }

  // ── HOME V2 — layout mobile ───────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, bool dark, bool isEs, AppProvider p) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 1. IA MEDCASES — destaque principal ──────────────────────────
        _HomeIaCard(
          dark: dark,
          isEs: isEs,
          onNavigateToAi: widget.onTabChange,
        ),
        const SizedBox(height: 14),

        // ── 2. FÁRMACOS ──────────────────────────────────────────────────
        _HomeCard(
          icon: Icons.medication_rounded,
          label: 'FÁRMACOS',
          subtitle: isEs
              ? 'Actualizados en 2026'
              : 'Atualizados em 2026',
          gradientColors: const [Color(0xFF3B2200), Color(0xFF6B3A00), Color(0xFF9A5B00)],
          accentColor: const Color(0xFFFBBF24),
          dark: dark,
          onTap: () => Navigator.of(context).push(
            _HomeScreenState._slide(const _FarmacosShell()),
          ),
        ),
        const SizedBox(height: 10),

        // ── 3. INTERAÇÕES ────────────────────────────────────────────────
        _HomeCard(
          icon: Icons.compare_arrows_rounded,
          label: isEs ? 'INTERACCIONES' : 'INTERAÇÕES',
          subtitle: isEs
              ? '+${DrugInteractionService.totalInteractions} pares con evidencia'
              : '+${DrugInteractionService.totalInteractions} pares com evidência',
          gradientColors: const [Color(0xFF3B0A1E), Color(0xFF5E1234), Color(0xFF8B1E4F)],
          accentColor: const Color(0xFFFF6BA0),
          dark: dark,
          onTap: () => Navigator.of(context).push(
            _HomeScreenState._slide(const DrugInteractionsScreen()),
          ),
        ),
        const SizedBox(height: 10),

        // ── 4. SIMULAÇÕES ────────────────────────────────────────────────
        _HomeCard(
          icon: Icons.description_rounded,
          label: isEs ? 'SIMULACIONES' : 'SIMULAÇÕES',
          subtitle: isEs
              ? '${prescriptionModels(true).length} ejemplos'
              : '${prescriptionModels(false).length} exemplos',
          gradientColors: const [Color(0xFF2A0B52), Color(0xFF3D1280), Color(0xFF5B21B6)],
          accentColor: const Color(0xFFA78BFA),
          dark: dark,
          onTap: () => Navigator.of(context).push(
            _HomeScreenState._slide(const _PrescripcionesShell()),
          ),
        ),
        const SizedBox(height: 10),

        // ── 5. PEDIATRIA + ADULTO — cards compactos lado a lado ──────────
        _HomeAdultoPediatriaRow(
          dark: dark,
          isEs: isEs,
          onTapAdulto: () => Navigator.of(context).push(
            _HomeScreenState._slide(_AdultoShell(openProtocol: widget.openProtocol)),
          ),
          onTapPediatria: () => Navigator.of(context).push(
            _HomeScreenState._slide(const _PediatricsShell()),
          ),
        ),
        const SizedBox(height: 16),

        // ── 6. MIGUARDIA — dashboard personalizado ───────────────────────
        _HomeMiGuardiaSection(
          dark: dark,
          isEs: isEs,
          onOpenDrug:  (drug) => showDrugDetailSheet(context, drug),
          onOpenCalc:  (calcId) {
            const calcTabMap = {
              'calc_biometria': 0, 'calc_scores': 1, 'calc_cardio': 2,
              'calc_eletrólitos': 3, 'calc_infusao': 4, 'calc_referencia': 5,
              'calc_prescricoes': 6, 'calc_pediatria': 7,
            };
            toolsScreenTabNotifier.value = calcTabMap[calcId] ?? 0;
            widget.onTabChange(4);
          },
          onManageTap: () => showPlantaoManageSheet(context),
        ),
        const SizedBox(height: 16),

        // ── 7. EMERGÊNCIAS RÁPIDAS ────────────────────────────────────────
        _QuickEmergencies(p: p, dark: dark, isEs: isEs, openProtocol: widget.openProtocol),
      ]),
    );
  }

  static Route _slide(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GREETING — boas-vindas com nome do usuário
// ─────────────────────────────────────────────────────────────────────────────
class _Greeting extends StatelessWidget {
  final AppProvider p;
  final bool dark;
  final bool isEs;
  const _Greeting({required this.p, required this.dark, required this.isEs});

  @override
  Widget build(BuildContext context) {
    final c    = AppColors.of(context);
    final name = p.currentUser?.displayName ?? '';
    final first = name.isNotEmpty ? name.split(' ').first : '';

    return Row(children: [
      // Avatar
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6B48), Color(0xFF0F1C14)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            first.isNotEmpty ? first[0].toUpperCase() : 'M',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFE8A6),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isEs ? 'Bienvenido' : 'Bem-vindo',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textHint,
              letterSpacing: 0.3,
            ),
          ),
          if (first.isNotEmpty)
            Text(
              first,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: c.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          Text(
            isEs ? 'Apoyo clínico educativo' : 'Apoio clínico educativo',
            style: TextStyle(
              fontSize: 11,
              color: c.textHint,
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR — abre bottom sheet de busca unificada
// ─────────────────────────────────────────────────────────────────────────────
class _HomeSearchBar extends StatelessWidget {
  final bool dark;
  final bool isEs;
  const _HomeSearchBar({required this.dark, required this.isEs});

  void _openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(dark: dark, isEs: isEs),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSearch(context),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          color: dark ? const Color(0xFF252525) : const Color(0xFFEFF1F7),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFDDE1EC),
          ),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            size: 19,
            color: dark ? Colors.white38 : const Color(0xFF9AA3B4),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isEs ? 'Buscar fármaco, protocolo…' : 'Buscar fármaco, protocolo…',
              style: TextStyle(
                fontSize: 13.5,
                color: dark ? Colors.white24 : const Color(0xFFAAB2C4),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFD8DDEF),
            ),
            child: Icon(
              Icons.search_rounded,
              size: 15,
              color: dark ? Colors.white38 : const Color(0xFF7B85A0),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET DE BUSCA UNIFICADA
// ─────────────────────────────────────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final bool dark;
  final bool isEs;
  const _SearchSheet({required this.dark, required this.isEs});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _ctrl = TextEditingController();
  String _q = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final isEs = widget.isEs;
    final p    = context.watch<AppProvider>();

    final sheetBg  = dark ? const Color(0xFF1A1A1A) : Colors.white;
    final inputBg  = dark ? const Color(0xFF252525) : const Color(0xFFF2F4F8);
    final textMain = dark ? Colors.white : const Color(0xFF1A202C);
    final textSub  = dark ? Colors.white54 : const Color(0xFF718096);
    final divColor = dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEDF0F7);

    // ── Resultados ────────────────────────────────────────────────────────
    final q = _q.toLowerCase().trim();

    // Fármacos — usa p.drugsDB (deduplicado)
    final drugs = q.isEmpty
        ? <DrugModel>[]
        : p.drugsDB
            .where((d) =>
                d.name.toLowerCase().contains(q) ||
                (d.className[isEs ? 'es' : 'pt'] ?? '').toLowerCase().contains(q) ||
                (d.category[isEs ? 'es' : 'pt'] ?? '').toLowerCase().contains(q))
            .take(8)
            .toList();

    // Protocolos
    final protocols = q.isEmpty
        ? <dynamic>[]
        : p.protocolsDB
            .where((pr) {
              final t = pr.title[isEs ? 'es' : 'pt'] ?? pr.title['pt'] ?? '';
              return t.toLowerCase().contains(q);
            })
            .take(8)
            .toList();

    final hasResults = drugs.isNotEmpty || protocols.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: dark ? Colors.white24 : const Color(0xFFCBD5E0),
            ),
          ),

          // Campo de busca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(23),
                    color: inputBg,
                  ),
                  child: Row(children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search_rounded, size: 19,
                        color: dark ? Colors.white38 : const Color(0xFF9AA3B4)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 15,
                          color: textMain,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: isEs
                              ? 'Fármaco, protocolo, prescrição…'
                              : 'Fármaco, protocolo, prescrição…',
                          hintStyle: TextStyle(
                            color: dark ? Colors.white30 : const Color(0xFFADB5C7),
                            fontSize: 14,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 300), () {
                            if (mounted) setState(() => _q = v);
                          });
                        },
                      ),
                    ),
                    if (_q.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _ctrl.clear();
                          setState(() => _q = '');
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(Icons.close_rounded, size: 18,
                              color: dark ? Colors.white38 : const Color(0xFF9AA3B4)),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  isEs ? 'Cerrar' : 'Fechar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6C2BD9),
                  ),
                ),
              ),
            ]),
          ),

          // Resultados
          Expanded(
            child: q.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 48,
                            color: dark ? Colors.white12 : const Color(0xFFCBD5E0)),
                        const SizedBox(height: 12),
                        Text(
                          isEs
                              ? 'Busca fármacos, protocolos\ny prescrições'
                              : 'Busque fármacos, protocolos\ne prescrições',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: textSub),
                        ),
                      ],
                    ),
                  )
                : !hasResults
                    ? Center(
                        child: Text(
                          isEs ? 'Sin resultados' : 'Sem resultados',
                          style: TextStyle(fontSize: 14, color: textSub),
                        ),
                      )
                    : ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // ── Fármacos ─────────────────────────────────
                          if (drugs.isNotEmpty) ...[
                            _SearchSectionLabel(
                                label: isEs ? 'FÁRMACOS' : 'FÁRMACOS', dark: dark),
                            ...drugs.map((d) => _SearchResultTile(
                              leading: Icons.medication_rounded,
                              leadingColor: const Color(0xFFFF8A00),
                              title: d.name,
                              subtitle: (d.className[isEs ? 'es' : 'pt'] ?? ''),
                              dark: dark,
                              divColor: divColor,
                              onTap: () async {
                                Navigator.pop(context);
                                // Registra como recente imediatamente
                                await homeRegisterRecent('drug', d.id, d.name, p: context.read<AppProvider>());
                                if (context.mounted) {
                                  showDrugDetailSheet(context, d);
                                }
                              },
                            )),
                            const SizedBox(height: 8),
                          ],

                          // ── Protocolos ───────────────────────────────
                          if (protocols.isNotEmpty) ...[
                            _SearchSectionLabel(
                                label: isEs ? 'PROTOCOLOS' : 'PROTOCOLOS', dark: dark),
                            ...protocols.map((pr) {
                              final lang  = isEs ? 'es' : 'pt';
                              final title = pr.title[lang] ?? pr.title['pt'] ?? '';
                              return _SearchResultTile(
                                leading: Icons.emergency_rounded,
                                leadingColor: const Color(0xFFCC2222),
                                title: title,
                                subtitle: isEs ? 'Protocolo clínico' : 'Protocolo clínico',
                                dark: dark,
                                divColor: divColor,
                                onTap: () async {
                                  Navigator.pop(context);
                                  // Registra como recente imediatamente
                                  await homeRegisterRecent('protocol', pr.id, title, p: context.read<AppProvider>());
                                  if (context.mounted) {
                                    showProtocolDetail(context, pr);
                                  }
                                },
                              );
                            }),
                          ],
                        ],
                      ),
          ),
        ]),
      ),
    );
  }
}

class _SearchSectionLabel extends StatelessWidget {
  final String label;
  final bool dark;
  const _SearchSectionLabel({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: dark ? Colors.white38 : const Color(0xFF8A94A6),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final IconData leading;
  final Color leadingColor;
  final String title;
  final String subtitle;
  final bool dark;
  final Color divColor;
  final VoidCallback onTap;
  const _SearchResultTile({
    required this.leading,
    required this.leadingColor,
    required this.title,
    required this.subtitle,
    required this.dark,
    required this.divColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: leadingColor.withValues(alpha: 0.12),
                ),
                child: Icon(leading, size: 18, color: leadingColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: dark ? Colors.white : const Color(0xFF1A202C),
                      )),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: dark ? Colors.white38 : const Color(0xFF8A94A6),
                        )),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, size: 18,
                  color: dark ? Colors.white24 : const Color(0xFFCBD5E0)),
            ]),
          ),
        ),
        Container(height: 1, color: divColor),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME V2 — IA MEDCASES CARD (item 1 da Home)
// Card premium branco/escuro com campo de pergunta, chips rápidos e botão enviar.
// Ao clicar/enviar: seta AiScreen.pendingQuery e navega para aba 2 (IA).
// ═══════════════════════════════════════════════════════════════════════════════
class _HomeIaCard extends StatefulWidget {
  final bool dark;
  final bool isEs;
  final ValueChanged<int> onNavigateToAi; // callback para mudar aba → IA (tab 2)

  const _HomeIaCard({
    required this.dark,
    required this.isEs,
    required this.onNavigateToAi,
  });

  @override
  State<_HomeIaCard> createState() => _HomeIaCardState();
}

class _HomeIaCardState extends State<_HomeIaCard> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  static const _kGreen     = Color(0xFF0D7A55);
  static const _kGreenBg   = Color(0xFF0D7A55);
  static const _kGreenBord = Color(0xFF0D9E6E);

  // Chips de exemplo bilíngues
  static const _chipsEs = ['Choque séptico', 'Noradrenalina', 'ECG FA', 'Hipercalemia', 'Cetoacidosis'];
  static const _chipsPt = ['Choque séptico', 'Noradrenalina', 'ECG FA', 'Hipercalemia', 'Cetoacidose'];

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _navigate([String? query]) {
    final q = (query ?? _ctrl.text).trim();
    if (q.isNotEmpty) {
      AiScreen.pendingQuery.value = q;
    }
    _ctrl.clear();
    _focus.unfocus();
    widget.onNavigateToAi(2); // navega para aba 2 (IA)
  }

  @override
  Widget build(BuildContext context) {
    final dark   = widget.dark;
    final isEs   = widget.isEs;
    final chips  = isEs ? _chipsEs : _chipsPt;

    final cardBg = dark ? const Color(0xFF0E1A12) : Colors.white;
    final borderColor = dark
        ? _kGreenBord.withValues(alpha: 0.35)
        : _kGreenBord.withValues(alpha: 0.22);
    final fieldBg = dark
        ? const Color(0xFF162A1C)
        : const Color(0xFFF4FAF7);
    final fieldBorder = dark
        ? _kGreenBord.withValues(alpha: 0.22)
        : _kGreenBord.withValues(alpha: 0.18);
    final textColor = dark ? Colors.white : const Color(0xFF0F1C14);
    final hintColor = dark
        ? Colors.white.withValues(alpha: 0.38)
        : const Color(0xFF7A9E8E);
    final chipBg = dark
        ? const Color(0xFF162A1C)
        : _kGreen.withValues(alpha: 0.07);
    final chipBorder = dark
        ? _kGreenBord.withValues(alpha: 0.25)
        : _kGreenBord.withValues(alpha: 0.22);
    final chipText = dark
        ? const Color(0xFF4ADE80)
        : _kGreen;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: _kGreenBg.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: _kGreen.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header: ícone + título + badge NOVO ──────────────────────
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F9E6A), Color(0xFF064D32)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kGreenBg.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.psychology_rounded,
                    size: 22, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'IA MEDCASES',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D7A55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'NOVO',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEs
                          ? 'Asistente clínico educativo'
                          : 'Assistente clínico educativo',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: dark
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFF4A7A63),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 18),

            // ── Campo de texto + botão enviar ────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _focus.requestFocus(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 18),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: fieldBorder, width: 1.2),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        minLines: 3,
                        maxLines: 5,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: textColor,
                          height: 1.55,
                        ),
                        decoration: InputDecoration.collapsed(
                          hintText: isEs
                              ? 'Escribe tu pregunta clínica…'
                              : 'Digite sua pergunta clínica…',
                          hintStyle: TextStyle(
                            fontSize: 14.5,
                            color: hintColor,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _navigate(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _navigate(),
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F9E6A), Color(0xFF064D32)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kGreenBg.withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Chips de exemplos rápidos ─────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: chips.map((chip) => GestureDetector(
                  onTap: () => _navigate(chip),
                  child: Container(
                    margin: const EdgeInsets.only(right: 7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: chipBorder),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: chipText,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME V2 — ADULTO / PEDIATRIA (item 5) — row de 2 cards compactos modernos
// ═══════════════════════════════════════════════════════════════════════════════
class _HomeAdultoPediatriaRow extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final VoidCallback onTapAdulto;
  final VoidCallback onTapPediatria;

  const _HomeAdultoPediatriaRow({
    required this.dark,
    required this.isEs,
    required this.onTapAdulto,
    required this.onTapPediatria,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _AgeCard(
        icon: Icons.person_rounded,
        label: 'ADULTO',
        subtitle: isEs ? 'Crear un protocolo adulto' : 'Criar um protocolo adulto',
        gradientColors: const [Color(0xFF052E1A), Color(0xFF0A5C2E), Color(0xFF15803D)],
        accentColor: const Color(0xFF4ADE80),
        dark: dark,
        onTap: onTapAdulto,
      )),
      const SizedBox(width: 10),
      Expanded(child: _AgeCard(
        icon: Icons.child_care_rounded,
        label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
        subtitle: isEs ? 'Protocolos pediátricos' : 'Protocolos pediátricos',
        gradientColors: const [Color(0xFF0A2540), Color(0xFF103D70), Color(0xFF2563EB)],
        accentColor: const Color(0xFF93C5FD),
        dark: dark,
        onTap: onTapPediatria,
      )),
    ]);
  }
}

class _AgeCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final Color accentColor;
  final bool dark;
  final VoidCallback onTap;

  const _AgeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.accentColor,
    required this.dark,
    required this.onTap,
  });

  @override
  State<_AgeCard> createState() => _AgeCardState();
}

class _AgeCardState extends State<_AgeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final g = widget.gradientColors;
    return GestureDetector(
      onTapDown:    (_) => _ctrl.forward(),
      onTapUp:      (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel:  ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: g,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: g.last.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 18, color: widget.accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: widget.accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 16,
                  color: widget.accentColor.withValues(alpha: 0.6)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME V2 — MIGUARDIA SECTION (item 6)
// Wrapper da seção MiGuardia — card limpo com padding interno.
// ═══════════════════════════════════════════════════════════════════════════════
class _HomeMiGuardiaSection extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final Function(dynamic) onOpenDrug;
  final Function(String) onOpenCalc;
  final VoidCallback onManageTap;

  const _HomeMiGuardiaSection({
    required this.dark,
    required this.isEs,
    required this.onOpenDrug,
    required this.onOpenCalc,
    required this.onManageTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = dark ? const Color(0xFF0E1A12) : Colors.white;
    // Acento dourado na borda esquerda para sinalizar "item especial"
    final leftAccent = dark ? const Color(0xFFC5A365) : const Color(0xFFB8954E);
    final border = dark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE4EEE9);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
        boxShadow: dark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra dourada à esquerda
              Container(width: 3, color: leftAccent),
              // Conteúdo principal
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: MeuPlantaoDashboard(
                    onOpenDrug:  onOpenDrug,
                    onOpenCalc:  onOpenCalc,
                    onManageTap: onManageTap,
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
// DIVISOR DECORATIVO
// ─────────────────────────────────────────────────────────────────────────────
class _HomeDivider extends StatelessWidget {
  final bool dark;
  const _HomeDivider({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFCDD1DC),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD METADE — Adulto / Pediatría (lado a lado)
// ─────────────────────────────────────────────────────────────────────────────
class _HomeCardHalf extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final Color accentColor;
  final bool dark;
  final VoidCallback onTap;

  const _HomeCardHalf({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.accentColor,
    required this.dark,
    required this.onTap,
  });

  @override
  State<_HomeCardHalf> createState() => _HomeCardHalfState();
}

class _HomeCardHalfState extends State<_HomeCardHalf>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.dark
                  ? [
                      widget.gradientColors[0].withValues(alpha: 0.85),
                      widget.gradientColors[1].withValues(alpha: 0.90),
                      widget.gradientColors[2].withValues(alpha: 0.95),
                    ]
                  : widget.gradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[2].withValues(alpha: 0.38),
                blurRadius: 16,
                offset: const Offset(0, 7),
                spreadRadius: -2,
              ),
            ],
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.18),
              width: 1.0,
            ),
          ),
          child: Stack(children: [
            // Círculo decorativo
            Positioned(
              right: -16,
              top: -16,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Conteúdo centrado
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: widget.accentColor.withValues(alpha: 0.14),
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.22),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: widget.accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.95),
                        letterSpacing: -0.2,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIFT TIMER BAR — Timer Rápido de Plantão (barra compacta + bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _ShiftTimerBar extends StatefulWidget {
  final bool dark;
  final bool isEs;
  const _ShiftTimerBar({required this.dark, required this.isEs});

  @override
  State<_ShiftTimerBar> createState() => _ShiftTimerBarState();
}

class _ShiftTimerBarState extends State<_ShiftTimerBar> {
  int    _notifId        = -1;    // ID da notificação agendada
  bool   _active         = false; // timer ativo?
  int    _remainingSecs  = 0;     // segundos restantes (atualizado a cada 1s)
  Timer? _ticker;
  String _label          = '';    // descrição do timer ativo

  @override
  void dispose() {
    _ticker?.cancel();
    if (_notifId >= 0) NotificationService.cancel(_notifId);
    super.dispose();
  }

  void _start(int seconds, String description) {
    // Cancela timer anterior
    _ticker?.cancel();
    if (_notifId >= 0) NotificationService.cancel(_notifId);

    final label = description.trim().isNotEmpty
        ? description.trim()
        : (widget.isEs ? 'Recordatorio de Guardia' : 'Lembrete de Plantão');

    setState(() {
      _active        = true;
      _remainingSecs = seconds;
      _label         = label;
    });

    // Tick a cada segundo para atualizar o contador na UI
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _remainingSecs--;
        if (_remainingSecs <= 0) {
          _remainingSecs = 0;
          _active = false;
          t.cancel();
        }
      });
    });

    // Agenda notificação nativa e registra callback de parada
    NotificationService.scheduleTimer(
      seconds: seconds,
      title:   'MedCases Pro',
      body:    label,
      payload: 'shift_timer',
    ).then((id) {
      if (!mounted) return;
      _notifId = id;
      // Quando o pop-up tocar "Parar", o _cancel() desta barra é chamado
      NotificationService.registerStopCallback(id, _cancel);
    });
  }

  void _cancel() {
    _ticker?.cancel();
    if (_notifId >= 0) {
      NotificationService.cancel(_notifId);
      _notifId = -1;
    }
    if (mounted) setState(() { _active = false; _remainingSecs = 0; _label = ''; });
  }

  String get _timeLabel {
    if (_remainingSecs <= 0) return '0s';
    final h = _remainingSecs ~/ 3600;
    final m = (_remainingSecs % 3600) ~/ 60;
    final s = _remainingSecs % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2,'0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2,'0')}s';
    return '${s}s';
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShiftTimerSheet(
        dark: widget.dark,
        isEs: widget.isEs,
        onStart: _start,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final isEs = widget.isEs;

    final bg     = dark ? const Color(0xFF1A2820) : const Color(0xFFECFDF5);
    final border = dark
        ? const Color(0xFF1F6B48).withValues(alpha: 0.35)
        : const Color(0xFF1F6B48).withValues(alpha: 0.25);
    final accent = const Color(0xFF1F6B48);
    final textC  = dark ? Colors.white : const Color(0xFF0D2218);
    final subC   = dark ? Colors.white54 : const Color(0xFF4B7A62);

    return GestureDetector(
      onTap: _active ? null : _openSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: bg,
          border: Border.all(color: border),
        ),
        child: Row(children: [
          // Ícone
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: _active ? 0.18 : 0.10),
            ),
            child: Icon(
              _active ? Icons.alarm_on_rounded : Icons.alarm_add_rounded,
              color: _active ? const Color(0xFF4ADE80) : accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          // Texto
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _active
                    ? (_label.isNotEmpty ? _label
                        : (isEs ? 'Recordatorio de Guardia' : 'Lembrete de Plantão'))
                    : (isEs ? 'Timer Rápido de Guardia' : 'Timer Rápido de Plantão'),
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: textC, letterSpacing: -0.2),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              Text(
                _active
                    ? _timeLabel
                    : (isEs ? 'Toca para iniciar un recordatorio' : 'Toque para iniciar um lembrete'),
                style: TextStyle(fontSize: 11, color: subC),
              ),
            ],
          )),
          // Botão cancelar (quando ativo) ou seta
          if (_active)
            GestureDetector(
              onTap: _cancel,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                ),
                child: const Icon(Icons.close_rounded,
                  size: 16, color: Color(0xFFEF4444)),
              ),
            )
          else
            Icon(Icons.chevron_right_rounded, color: subC, size: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIFT TIMER SHEET — bottom sheet para configurar o timer
// ─────────────────────────────────────────────────────────────────────────────
class _ShiftTimerSheet extends StatefulWidget {
  final bool dark;
  final bool isEs;
  final void Function(int seconds, String description) onStart;

  const _ShiftTimerSheet({
    required this.dark,
    required this.isEs,
    required this.onStart,
  });

  @override
  State<_ShiftTimerSheet> createState() => _ShiftTimerSheetState();
}

class _ShiftTimerSheetState extends State<_ShiftTimerSheet> {
  // Seletor: horas + minutos separados
  int _hours   = 0;
  int _minutes = 5;

  final _descCtrl = TextEditingController();

  // Presets rápidos: (label, hours, minutes)
  static const _presets = [
    ('5 min',  0,  5),
    ('10 min', 0, 10),
    ('15 min', 0, 15),
    ('30 min', 0, 30),
    ('1 h',    1,  0),
    ('2 h',    2,  0),
    ('4 h',    4,  0),
    ('6 h',    6,  0),
  ];

  int get _totalSeconds => (_hours * 60 + _minutes) * 60;

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  void _confirm() {
    if (_totalSeconds <= 0) return;
    Navigator.of(context).pop();
    widget.onStart(_totalSeconds, _descCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final dark  = widget.dark;
    final isEs  = widget.isEs;
    final bg    = dark ? const Color(0xFF1A1A1A) : Colors.white;
    final textC = dark ? Colors.white : const Color(0xFF0D2218);
    final subC  = dark ? Colors.white38 : Colors.black38;
    final divC  = dark ? Colors.white10 : const Color(0xFFEEEEEE);
    final accent = const Color(0xFF1F6B48);
    final kb    = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, kb + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: dark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2)),
          )),
        ),

        // Título
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.alarm_add_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isEs ? 'Timer Rápido de Guardia' : 'Timer Rápido de Plantão',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textC),
              ),
              Text(
                isEs ? 'Recibe una notificación cuando el tiempo acabe'
                     : 'Receba uma notificação quando o tempo acabar',
                style: TextStyle(fontSize: 11, color: subC),
              ),
            ])),
          ]),
        ),

        // Presets rápidos
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _presets.map((p) {
            final sel = _hours == p.$2 && _minutes == p.$3;
            return GestureDetector(
              onTap: () => setState(() { _hours = p.$2; _minutes = p.$3; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: sel ? accent : (dark ? const Color(0xFF252525) : const Color(0xFFF3F4F6)),
                  border: Border.all(
                    color: sel ? accent : (dark ? Colors.white12 : const Color(0xFFE0E0E0))),
                ),
                child: Text(p.$1, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: sel ? Colors.white : textC,
                )),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),
        Divider(color: divC, height: 1),
        const SizedBox(height: 16),

        // Seletor manual: horas e minutos
        Row(children: [
          // Horas
          Expanded(child: Column(children: [
            Text(isEs ? 'Horas' : 'Horas',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: subC, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _StepBtn(
                icon: Icons.remove,
                onTap: () { if (_hours > 0) setState(() => _hours--); },
                dark: dark,
              ),
              SizedBox(width: 48, child: Center(
                child: Text('$_hours', style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: textC)),
              )),
              _StepBtn(
                icon: Icons.add,
                onTap: () { if (_hours < 12) setState(() => _hours++); },
                dark: dark,
              ),
            ]),
          ])),
          Container(width: 1, height: 48, color: divC),
          // Minutos
          Expanded(child: Column(children: [
            Text(isEs ? 'Minutos' : 'Minutos',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: subC, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _StepBtn(
                icon: Icons.remove,
                onTap: () { if (_minutes > 0) setState(() => _minutes--); else if (_hours > 0) { _hours--; _minutes = 59; setState((){}); } },
                dark: dark,
              ),
              SizedBox(width: 48, child: Center(
                child: Text(_minutes.toString().padLeft(2,'0'), style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: textC)),
              )),
              _StepBtn(
                icon: Icons.add,
                onTap: () { if (_minutes < 59) setState(() => _minutes++); else { _hours++; _minutes = 0; setState((){}); } },
                dark: dark,
              ),
            ]),
          ])),
        ]),

        const SizedBox(height: 18),
        Divider(color: divC, height: 1),
        const SizedBox(height: 14),

        // Campo de descrição
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: dark ? const Color(0xFF252525) : const Color(0xFFF5F7FA),
            border: Border.all(color: divC),
          ),
          child: TextField(
            controller: _descCtrl,
            style: TextStyle(fontSize: 13.5, color: textC),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: isEs
                  ? 'Descripción (ej: Ver resultado lab cama 4)…'
                  : 'Descrição (ex: Ver exame do Leito 4)…',
              hintStyle: TextStyle(fontSize: 13, color: subC),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: Icon(Icons.edit_note_rounded, color: subC, size: 18),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Botão confirmar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _totalSeconds > 0 ? _confirm : null,
            icon: const Icon(Icons.alarm_on_rounded, size: 18),
            label: Text(
              isEs ? 'Iniciar Timer' : 'Iniciar Timer',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: accent.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }
}

// Botão de incremento/decremento do seletor de tempo
class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  const _StepBtn({required this.icon, required this.onTap, required this.dark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEFF2F7),
        ),
        child: Icon(icon, size: 16,
          color: dark ? Colors.white70 : const Color(0xFF334155)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK SHORTCUTS — Notas · Recentes · Favoritos
// ─────────────────────────────────────────────────────────────────────────────
class _QuickShortcuts extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final Function(String) openProtocol;
  final VoidCallback onOpenNotes;
  final VoidCallback? onCheckUpdate;
  const _QuickShortcuts({
    required this.dark,
    required this.isEs,
    required this.openProtocol,
    required this.onOpenNotes,
    this.onCheckUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = dark ? const Color(0xFF1E1E1E) : Colors.white;
    final shadow = dark
        ? <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ];

    final items = [
      _ShortcutItem(
        icon: Icons.sticky_note_2_rounded,
        color: const Color(0xFFFF8A00),
        label: isEs ? 'Notas' : 'Notas',
        onTap: onOpenNotes,
      ),
      _ShortcutItem(
        icon: Icons.history_rounded,
        color: const Color(0xFF1F78FF),
        label: isEs ? 'Recientes' : 'Recentes',
        onTap: () => _openRecentes(context),
      ),
      _ShortcutItem(
        icon: Icons.bookmark_rounded,
        color: const Color(0xFF6C2BD9),
        label: isEs ? 'Favoritos' : 'Favoritos',
        onTap: () => _openFavoritos(context),
      ),
      _ShortcutItem(
        icon: Icons.assignment_ind_rounded,
        color: const Color(0xFFDC2626),
        label: isEs ? 'Evaluación' : 'Avaliação',
        onTap: () => HomeScreen._openAvaliacao(context),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cardBg,
        boxShadow: shadow,
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE8ECF5),
        ),
      ),
      child: Row(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(
              width: 1,
              height: 56,
              color: dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : const Color(0xFFECEFF7),
            );
          }
          final item = items[i ~/ 2];
          return Expanded(
            child: GestureDetector(
              onTap: item.onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: item.color.withValues(alpha: 0.12),
                      ),
                      child: Icon(item.icon, size: 18, color: item.color),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: dark
                            ? Colors.white.withValues(alpha: 0.70)
                            : const Color(0xFF4A5568),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _openRecentes(BuildContext context) {
    final p    = context.read<AppProvider>();
    final dark = this.dark;
    final isEs = this.isEs;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecentesSheet(dark: dark, isEs: isEs, p: p),
    );
  }

  void _openFavoritos(BuildContext context) {
    final p    = context.read<AppProvider>();
    final dark = this.dark;
    final isEs = this.isEs;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FavoritosSheet(dark: dark, isEs: isEs, p: p),
    );
  }
}

class _ShortcutItem {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ShortcutItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENTES — itens abertos recentemente (SharedPreferences)
// ─────────────────────────────────────────────────────────────────────────────

/// Chave SharedPreferences para recentes
// homeRegisterRecent — delega ao AppProvider (chave prefixada por uid)
Future<void> homeRegisterRecent(String type, String id, String title, {required AppProvider p}) async {
  await p.registerRecent(type, id, title);
}

class _RecentesSheet extends StatefulWidget {
  final bool dark;
  final bool isEs;
  final AppProvider p;
  const _RecentesSheet({required this.dark, required this.isEs, required this.p});

  @override
  State<_RecentesSheet> createState() => _RecentesSheetState();
}

class _RecentesSheetState extends State<_RecentesSheet> {
  List<Map<String, String>> _items = [];
  bool _loading = true;
  bool _hasLoaded = false; // trava — garante fetch Firestore apenas uma vez

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_hasLoaded) return; // bloqueia re-entrada em caso de rebuild
    _hasLoaded = true;
    try {
      final items = await widget.p.loadRecents();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final isEs = widget.isEs;
    final sheetBg = dark ? const Color(0xFF1A1A1A) : Colors.white;
    final textMain = dark ? Colors.white : const Color(0xFF1A202C);
    final textSub  = dark ? Colors.white54 : const Color(0xFF718096);
    final divColor = dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEDF0F7);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      expand: false,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: dark ? Colors.white24 : const Color(0xFFCBD5E0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Row(children: [
              Icon(Icons.history_rounded, size: 20, color: const Color(0xFF1F78FF)),
              const SizedBox(width: 8),
              Text(
                isEs ? 'Recientes' : 'Recentes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
            ]),
          ),
          Container(height: 1, color: divColor),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.history_rounded, size: 48,
                              color: dark ? Colors.white12 : const Color(0xFFCBD5E0)),
                          const SizedBox(height: 12),
                          Text(
                            isEs ? 'Sin elementos recientes' : 'Nenhum item recente',
                            style: TextStyle(fontSize: 14, color: textSub),
                          ),
                        ]),
                      )
                    : ListView.separated(
                        controller: sc,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            Container(height: 1, color: divColor),
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          final type = item['type'] ?? '';
                          final id   = item['id'] ?? '';
                          final title = item['title'] ?? '';
                          final isProtocol = type == 'protocol';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 4),
                            leading: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: (isProtocol
                                    ? const Color(0xFFCC2222)
                                    : const Color(0xFFFF8A00))
                                    .withValues(alpha: 0.12),
                              ),
                              child: Icon(
                                isProtocol
                                    ? Icons.emergency_rounded
                                    : Icons.medication_rounded,
                                size: 18,
                                color: isProtocol
                                    ? const Color(0xFFCC2222)
                                    : const Color(0xFFFF8A00),
                              ),
                            ),
                            title: Text(title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textMain,
                                )),
                            subtitle: Text(
                              isProtocol
                                  ? (isEs ? 'Protocolo' : 'Protocolo')
                                  : (isEs ? 'Fármaco' : 'Fármaco'),
                              style: TextStyle(fontSize: 11, color: textSub),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded,
                                size: 18,
                                color: dark ? Colors.white24 : const Color(0xFFCBD5E0)),
                            onTap: () {
                              Navigator.pop(context);
                              if (isProtocol) {
                                openProtocolById(ctx, id);
                              } else {
                                // Abre direto o fármaco pelo ID
                                final p = ctx.read<AppProvider>();
                                try {
                                  final drug = p.drugsDB.firstWhere((d) => d.id == id);
                                  showDrugDetailSheet(ctx, drug);
                                } catch (_) {
                                  Navigator.of(ctx).push(
                                    _HomeScreenState._slide(const _FarmacosShell()),
                                  );
                                }
                              }
                            },
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
// FAVORITOS — fármacos e protocolos favoritados
// ─────────────────────────────────────────────────────────────────────────────
class _FavoritosSheet extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final AppProvider p;
  const _FavoritosSheet({required this.dark, required this.isEs, required this.p});

  @override
  Widget build(BuildContext context) {
    final sheetBg = dark ? const Color(0xFF1A1A1A) : Colors.white;
    final textMain = dark ? Colors.white : const Color(0xFF1A202C);
    final textSub  = dark ? Colors.white54 : const Color(0xFF718096);
    final divColor = dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEDF0F7);

    // Fármacos favoritos
    final favDrugs = p.drugsDB
        .where((d) => p.favDrugs.contains(d.id))
        .toList();

    // Protocolos favoritos
    final favProtos = p.protocolsDB
        .where((pr) => p.favProtocols.contains(pr.id))
        .toList();

    // Prescrições favoritas
    final allPrescriptions = prescriptionModels(isEs);
    final favPrescs = allPrescriptions
        .where((m) => p.favPrescriptions.contains(m.id))
        .toList();

    // Casos clínicos favoritos
    final favClinical = p.casesDB
        .where((c) => p.favCases.contains(c.id))
        .toList();

    final hasAny = favDrugs.isNotEmpty || favProtos.isNotEmpty ||
                   favPrescs.isNotEmpty || favClinical.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      expand: false,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: dark ? Colors.white24 : const Color(0xFFCBD5E0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Row(children: [
              Icon(Icons.bookmark_rounded, size: 20, color: const Color(0xFF6C2BD9)),
              const SizedBox(width: 8),
              Text(
                isEs ? 'Favoritos' : 'Favoritos',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
            ]),
          ),
          Container(height: 1, color: divColor),
          Expanded(
            child: !hasAny
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bookmark_border_rounded, size: 48,
                          color: dark ? Colors.white12 : const Color(0xFFCBD5E0)),
                      const SizedBox(height: 12),
                      Text(
                        isEs ? 'Sin favoritos aún' : 'Nenhum favorito ainda',
                        style: TextStyle(fontSize: 14, color: textSub),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEs
                            ? 'Guarda fármacos y protocolos\ndesde sus pantallas'
                            : 'Salve fármacos e protocolos\nnascidas suas telas',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: textSub),
                      ),
                    ]),
                  )
                : ListView(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    children: [
                      // Fármacos favoritos
                      if (favDrugs.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            isEs ? 'FÁRMACOS' : 'FÁRMACOS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              color: dark ? Colors.white38 : const Color(0xFF8A94A6),
                            ),
                          ),
                        ),
                        ...favDrugs.map((d) => Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 2, horizontal: 4),
                              leading: Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
                                ),
                                child: const Icon(Icons.medication_rounded,
                                    size: 18, color: Color(0xFFFF8A00)),
                              ),
                              title: Text(d.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textMain,
                                  )),
                              subtitle: Text(
                                d.className[isEs ? 'es' : 'pt'] ?? '',
                                style: TextStyle(fontSize: 11, color: textSub),
                              ),
                              trailing: Icon(Icons.chevron_right_rounded, size: 18,
                                  color: dark ? Colors.white24 : const Color(0xFFCBD5E0)),
                              onTap: () {
                                Navigator.pop(context);
                                showDrugDetailSheet(context, d);
                              },
                            ),
                            Container(height: 1, color: divColor),
                          ],
                        )),
                      ],

                      // Prescrições favoritas
                      if (favPrescs.isNotEmpty) ...[               
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            isEs ? 'SIMULACIONES' : 'SIMULAÇÕES',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              color: dark ? Colors.white38 : const Color(0xFF8A94A6),
                            ),
                          ),
                        ),
                        ...favPrescs.map((m) => Column(children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            leading: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFD8B4FE).withValues(alpha: 0.15),
                              ),
                              child: Icon(m.icon, size: 18, color: const Color(0xFFD8B4FE)),
                            ),
                            title: Text(m.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain)),
                            subtitle: Text(m.category, style: TextStyle(fontSize: 11, color: textSub)),
                            trailing: Icon(Icons.chevron_right_rounded, size: 18, color: dark ? Colors.white24 : const Color(0xFFCBD5E0)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const _PrescripcionesShell()));
                            },
                          ),
                          Container(height: 1, color: divColor),
                        ])),
                      ],

                      // Protocolos favoritos
                      if (favProtos.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            isEs ? 'PROTOCOLOS' : 'PROTOCOLOS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              color: dark ? Colors.white38 : const Color(0xFF8A94A6),
                            ),
                          ),
                        ),
                        ...favProtos.map((pr) {
                          final title = pr.title[isEs ? 'es' : 'pt'] ?? pr.title['pt'] ?? '';
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 2, horizontal: 4),
                                leading: Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: const Color(0xFFCC2222).withValues(alpha: 0.12),
                                  ),
                                  child: const Icon(Icons.emergency_rounded,
                                      size: 18, color: Color(0xFFCC2222)),
                                ),
                                title: Text(title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textMain,
                                    )),
                                subtitle: Text(
                                  isEs ? 'Protocolo clínico' : 'Protocolo clínico',
                                  style: TextStyle(fontSize: 11, color: textSub),
                                ),
                                trailing: Icon(Icons.chevron_right_rounded, size: 18,
                                    color: dark ? Colors.white24 : const Color(0xFFCBD5E0)),
                                onTap: () {
                                  Navigator.pop(context);
                                  openProtocolById(context, pr.id);
                                },
                              ),
                              Container(height: 1, color: divColor),
                            ],
                          );
                        }),
                      ],

                      // Casos clínicos favoritos
                      if (favClinical.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            isEs ? 'CASOS CLÍNICOS' : 'CASOS CLÍNICOS',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              color: dark ? Colors.white38 : const Color(0xFF8A94A6),
                            ),
                          ),
                        ),
                        ...favClinical.map((c) => Column(children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            leading: Container(
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                              ),
                              child: const Icon(Icons.cases_rounded, size: 18, color: Color(0xFFFBBF24)),
                            ),
                            title: Text(c.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain)),
                            subtitle: Text(c.category.isNotEmpty ? c.category : (isEs ? 'Caso clínico' : 'Caso clínico'),
                                style: TextStyle(fontSize: 11, color: textSub)),
                            trailing: Icon(Icons.chevron_right_rounded, size: 18, color: dark ? Colors.white24 : const Color(0xFFCBD5E0)),
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                          Container(height: 1, color: divColor),
                        ])),
                      ],
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class para lista de cards (usado no layout desktop)
class _HomeCardData {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final Color accentColor;
  final VoidCallback onTap;
  const _HomeCardData({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.accentColor,
    required this.onTap,
  });
}

// CARD PRINCIPAL DE NAVEGAÇÃO
// ─────────────────────────────────────────────────────────────────────────────
class _HomeCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final Color accentColor;
  final bool dark;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.accentColor,
    required this.dark,
    required this.onTap,
  });

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:    (_) => _ctrl.forward(),
      onTapUp:      (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel:  ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.dark
                  ? [
                      widget.gradientColors[0].withValues(alpha: 0.85),
                      widget.gradientColors[1].withValues(alpha: 0.90),
                      widget.gradientColors[2].withValues(alpha: 0.95),
                    ]
                  : widget.gradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[2].withValues(alpha: 0.40),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.18),
              width: 1.0,
            ),
          ),
          child: Stack(
            children: [
              // Fundo decorativo — círculo de luz
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accentColor.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accentColor.withValues(alpha: 0.04),
                  ),
                ),
              ),

              // Conteúdo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(children: [
                  // Ícone
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: widget.accentColor.withValues(alpha: 0.14),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.25),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Textos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.97),
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Seta
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.30),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME V2 — EMERGÊNCIAS RÁPIDAS (item 7)
// 10 protocolos críticos definidos na especificação + expandir para todos.
// Cards com estrutura: Reconhecer → Conduta → Fármacos → Monitorização.
// ═══════════════════════════════════════════════════════════════════════════════
class _QuickEmergencies extends StatefulWidget {
  final AppProvider p;
  final bool dark;
  final bool isEs;
  final Function(String) openProtocol;

  const _QuickEmergencies({
    required this.p,
    required this.dark,
    required this.isEs,
    required this.openProtocol,
  });

  @override
  State<_QuickEmergencies> createState() => _QuickEmergenciesState();
}

class _QuickEmergenciesState extends State<_QuickEmergencies> {
  bool _expanded = false;

  // ── 10 protocolos principais (visíveis por padrão) ─────────────────────
  static const _mainProtocols = [
    ('iam_supra',             'IAM',              Icons.favorite_border_rounded),
    ('avc_isquemico',         'AVC',              Icons.bolt_rounded),
    ('sepse',                 'Sepse',            Icons.emergency_rounded),
    ('choque_septico_avancado', 'Choque Séptico',  Icons.warning_amber_rounded),
    ('anafilaxia',            'Anafilaxia',       Icons.warning_rounded),
    ('hiperpotassemia_grave', 'Hipercalemia',     Icons.science_rounded),
    ('tep_agudo',             'TEP Instável',     Icons.bloodtype_rounded),
    ('tpsv',                  'TPSV',             Icons.favorite_rounded),
    ('cetoacidose_diabetica',  'Cetoacidose',      Icons.water_drop_rounded),
    ('asma_grave',            'Crise Asmática',   Icons.air_rounded),
  ];

  // ── Extras (visíveis ao expandir) ──────────────────────────────────────
  static const _extraProtocols = [
    ('pcr_adulto',            'PCR',              Icons.monitor_heart_rounded),
    ('fa_aguda',              'FA Aguda',         Icons.electric_bolt_rounded),
    ('choque_cardiogenico',   'Choque Card.',     Icons.heart_broken_rounded),
    ('crise_hipertensiva',    'Crise HAS',        Icons.speed_rounded),
    ('edema_agudo_pulmao',    'EAP',              Icons.waves_rounded),
    ('status_epilepticus',    'Status Epil.',     Icons.psychology_rounded),
  ];

  static const _kRed        = Color(0xFFCC2222);
  static const _kRedDark    = Color(0xFFFF8888);
  static const _kRedBg      = Color(0xFFFFF0F0);
  static const _kRedBgDark  = Color(0xFF2A0A0A);
  static const _kRedBord    = Color(0xFFFFCCCC);
  static const _kRedBordDark = Color(0xFF6B1A1A);

  Widget _buildCard(String id, String label, IconData icon) {
    final dark = widget.dark;
    return GestureDetector(
      onTap: () => widget.openProtocol(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: dark ? _kRedBgDark : _kRedBg,
          border: Border.all(
            color: dark
                ? _kRedBordDark.withValues(alpha: 0.55)
                : _kRedBord,
            width: 1,
          ),
          boxShadow: dark
              ? []
              : [
                  BoxShadow(
                    color: _kRed.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: dark
                    ? _kRed.withValues(alpha: 0.15)
                    : _kRed.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15,
                  color: dark ? _kRedDark : _kRed),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: dark ? _kRedDark : _kRed,
                  height: 1.2,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final isEs = widget.isEs;
    final cardBg = dark ? const Color(0xFF0E1210) : Colors.white;
    final borderColor = dark
        ? _kRedBordDark.withValues(alpha: 0.20)
        : _kRedBord.withValues(alpha: 0.60);

    final allProtos = _expanded
        ? [..._mainProtocols, ..._extraProtocols]
        : _mainProtocols;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: dark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Cabeçalho ────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: dark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.emergency_rounded, size: 17,
                  color: dark ? _kRedDark : _kRed),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'EMERGENCIAS RÁPIDAS' : 'EMERGÊNCIAS RÁPIDAS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: dark ? _kRedDark : _kRed,
                    ),
                  ),
                  Text(
                    isEs
                        ? 'Protocolos críticos para consulta inmediata en el turno'
                        : 'Protocolos críticos para consulta imediata durante o plantão',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: dark
                          ? Colors.white.withValues(alpha: 0.40)
                          : const Color(0xFF886666),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Botão expandir/recolher
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: dark ? _kRedBgDark : _kRedBg,
                  border: Border.all(
                    color: dark
                        ? _kRedBordDark.withValues(alpha: 0.40)
                        : _kRedBord,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _expanded
                        ? (isEs ? 'menos' : 'menos')
                        : (isEs ? 'ver +' : 'ver +'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: dark ? _kRedDark : _kRed,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 13,
                    color: dark ? _kRedDark : _kRed,
                  ),
                ]),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Grid 5 colunas nos primeiros 10, 3 extras ─────────────────
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: allProtos.map((proto) =>
                _buildCard(proto.$1, proto.$2, proto.$3)).toList(),
          ),

          // ── Dica visual de fluxo ──────────────────────────────────────
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _EmergStep(isEs ? 'Reconocer' : 'Reconhecer', dark),
              _EmergArrow(dark),
              _EmergStep(isEs ? 'Conducta' : 'Conduta', dark),
              _EmergArrow(dark),
              _EmergStep(isEs ? 'Fármacos' : 'Fármacos', dark),
              _EmergArrow(dark),
              _EmergStep(isEs ? 'Monitor.' : 'Monitor.', dark),
            ],
          ),
        ]),
      ),
    );
  }
}

class _EmergStep extends StatelessWidget {
  final String label;
  final bool dark;
  const _EmergStep(this.label, this.dark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFCC2222).withValues(alpha: dark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: dark
              ? const Color(0xFFFF8888)
              : const Color(0xFFCC2222),
        ),
      ),
    );
  }
}

class _EmergArrow extends StatelessWidget {
  final bool dark;
  const _EmergArrow(this.dark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 11,
        color: dark
            ? const Color(0xFFFF8888).withValues(alpha: 0.5)
            : const Color(0xFFCC2222).withValues(alpha: 0.4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHELL HEADER — cabeçalho idêntico ao _HomeCard (mesmo padrão visual)
// ─────────────────────────────────────────────────────────────────────────────
class _ShellHeader extends StatelessWidget {
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;
  final String label;
  final String subtitle;

  const _ShellHeader({
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Círculo decorativo grande (canto direito superior)
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.07),
                ),
              ),
            ),
            // Círculo decorativo pequeno (canto direito inferior)
            Positioned(
              right: 16,
              bottom: -28,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Conteúdo
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 20, 14),
              child: Row(children: [
                // Botão voltar — mesmo estilo dos cards
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      size: 18, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Ícone container — idêntico ao _HomeCard
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accentColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(icon, size: 24, color: accentColor),
                ),
                const SizedBox(width: 14),
                // Textos — mesmas fontes do _HomeCard
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.97),
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.55),
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PEDIATRICS SHELL
// ─────────────────────────────────────────────────────────────────────────────
class _PediatricsShell extends StatelessWidget {
  const _PediatricsShell();

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF141414) : const Color(0xFFF7F8FA),
      body: Column(children: [
        _ShellHeader(
          gradientColors: const [Color(0xFF0A2540), Color(0xFF103D70), Color(0xFF2563EB)],
          accentColor:    const Color(0xFF93C5FD),
          icon:    Icons.child_care_rounded,
          label:   isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
          subtitle: isEs
              ? 'Biometría · PEWS · Schwartz · Dosis'
              : 'Biometria · PEWS · Schwartz · Doses',
        ),
        const Expanded(child: PediatricsTabContent()),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADULTO SHELL
// ─────────────────────────────────────────────────────────────────────────────
class _AdultoShell extends StatelessWidget {
  final Function(String) openProtocol;
  const _AdultoShell({required this.openProtocol});

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF141414) : const Color(0xFFF7F8FA),
      body: Column(children: [
        _ShellHeader(
          gradientColors: const [Color(0xFF052E1A), Color(0xFF0A5C2E), Color(0xFF15803D)],
          accentColor:    const Color(0xFF4ADE80),
          icon:    Icons.person_rounded,
          label:   'ADULTO',
          subtitle: isEs
              ? 'Dosis · Protocolos · Calculadora'
              : 'Doses · Protocolos · Calculadora',
        ),
        Expanded(child: CockpitScreen(openProtocol: openProtocol)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FÁRMACOS SHELL
// ─────────────────────────────────────────────────────────────────────────────
class _FarmacosShell extends StatefulWidget {
  const _FarmacosShell();

  @override
  State<_FarmacosShell> createState() => _FarmacosShellState();
}

class _FarmacosShellState extends State<_FarmacosShell> {
  // Adia a construção pesada do DrugsScreen para depois da animação de entrada
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Aguarda a animação de slide terminar (~280ms) antes de montar o DrugsScreen
    Future.delayed(const Duration(milliseconds: 290), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF141414) : const Color(0xFFF7F8FA),
      body: Column(children: [
        _ShellHeader(
          gradientColors: const [Color(0xFF3B2200), Color(0xFF6B3A00), Color(0xFF9A5B00)],
          accentColor:    const Color(0xFFFBBF24),
          icon:    Icons.medication_rounded,
          label:   'FÁRMACOS',
          subtitle: isEs
              ? 'Actualizados en 2026'
              : 'Atualizados em 2026',
        ),
        Expanded(
          child: _ready
              ? const RepaintBoundary(child: DrugsScreen(hideHeader: true))
              : _buildSkeleton(dark),
        ),
      ]),
    );
  }

  // Placeholder leve exibido durante a animação de entrada (~280ms)
  Widget _buildSkeleton(bool dark) {
    final bg = dark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEE);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(children: [
        // Barra de busca skeleton
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        const SizedBox(height: 20),
        // Linhas de grupo skeleton
        ...List.generate(6, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CALCULADORAS SHELL
// ─────────────────────────────────────────────────────────────────────────────
class _CalculadorasShell extends StatelessWidget {
  const _CalculadorasShell();

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF141414) : const Color(0xFFF7F8FA),
      body: Column(children: [
        _ShellHeader(
          gradientColors: const [Color(0xFF1A0F2E), Color(0xFF2D1B5A), Color(0xFF4A2D8A)],
          accentColor:    const Color(0xFFA78BFA),
          icon:    Icons.calculate_rounded,
          label:   isEs ? 'CALCULADORAS' : 'CALCULADORAS',
          subtitle: isEs
              ? 'Scores · Cardio · Electrolitos · Infusión'
              : 'Scores · Cardio · Eletrólitos · Infusão',
        ),
        const Expanded(child: ToolsScreen(hideHeader: true)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRESCRIPCIONES SHELL
// ─────────────────────────────────────────────────────────────────────────────
class _PrescripcionesShell extends StatelessWidget {
  const _PrescripcionesShell();

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF141414) : const Color(0xFFF7F8FA),
      body: Column(children: [
        _ShellHeader(
          gradientColors: const [Color(0xFF2A0B52), Color(0xFF3D1280), Color(0xFF5B21B6)],
          accentColor:    const Color(0xFFA78BFA),
          icon:    Icons.description_rounded,
          label:   isEs ? 'SIMULACIONES' : 'SIMULAÇÕES',
          subtitle: isEs
              ? '${prescriptionModels(true).length} ejemplos'
              : '${prescriptionModels(false).length} exemplos',
        ),
        const Expanded(child: PrescripcionesScreen()),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLOBAL SEARCH — lupa da bottom nav
// Pesquisa simultânea em: Fármacos, Protocolos, Prescrições, Interações
// Abre via showGlobalSearch(context) — chamado pelo botão central da nav.
// ─────────────────────────────────────────────────────────────────────────────

/// Abre o modal de busca global. Chame este método do botão lupa da bottom nav.
void showGlobalSearch(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _GlobalSearchModal(),
  );
}

// ── Categorias de resultado ────────────────────────────────────────────────
enum _SearchCat { drug, protocol, prescription, interaction }

class _SearchResult {
  final _SearchCat cat;
  final String     title;
  final String     subtitle;
  final dynamic    data;      // DrugModel | ProtocolModel | PrescriptionModel | String

  const _SearchResult({
    required this.cat,
    required this.title,
    required this.subtitle,
    required this.data,
  });
}

// ── Modal ──────────────────────────────────────────────────────────────────
class _GlobalSearchModal extends StatefulWidget {
  const _GlobalSearchModal();

  @override
  State<_GlobalSearchModal> createState() => _GlobalSearchModalState();
}

class _GlobalSearchModalState extends State<_GlobalSearchModal> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  List<_SearchResult> _results = [];
  bool _searched = false;

  static const _maxPerCat = 6;

  @override
  void initState() {
    super.initState();
    // Teclado abre automático
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    final query = q.trim().toLowerCase();
    if (query.length < 2) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    _runSearch(query);
  }

  void _runSearch(String q) {
    final p    = context.read<AppProvider>();
    final isEs = p.lang == 'es';
    final res  = <_SearchResult>[];

    // ── 1. Fármacos ────────────────────────────────────────────────────────
    int drugCount = 0;
    for (final drug in drugsDatabase) {
      if (drugCount >= _maxPerCat) break;
      final name  = drug.name.toLowerCase();
      final grp   = drug.group.toLowerCase();
      if (name.contains(q) || grp.contains(q)) {
        res.add(_SearchResult(
          cat:      _SearchCat.drug,
          title:    drug.nameL10n(p.lang),
          subtitle: drug.group,
          data:     drug,
        ));
        drugCount++;
      }
    }

    // ── 2. Protocolos ──────────────────────────────────────────────────────
    int protoCount = 0;
    final lang = p.lang;
    for (final proto in p.protocolsDB) {
      if (protoCount >= _maxPerCat) break;
      final titleText = (proto.title[lang] ?? proto.title['pt'] ?? '').toLowerCase();
      if (titleText.contains(q)) {
        res.add(_SearchResult(
          cat:      _SearchCat.protocol,
          title:    proto.title[lang] ?? proto.title['pt'] ?? '',
          subtitle: isEs ? 'Protocolo clínico' : 'Protocolo clínico',
          data:     proto,
        ));
        protoCount++;
      }
    }

    // ── 3. Prescrições ─────────────────────────────────────────────────────
    int prescCount = 0;
    for (final presc in prescriptionModels(isEs)) {
      if (prescCount >= _maxPerCat) break;
      final t = presc.title.toLowerCase();
      final c = presc.category.toLowerCase();
      if (t.contains(q) || c.contains(q)) {
        res.add(_SearchResult(
          cat:      _SearchCat.prescription,
          title:    presc.title,
          subtitle: presc.category,
          data:     presc,
        ));
        prescCount++;
      }
    }

    // ── 4. Interações (nomes dos pares) ────────────────────────────────────
    int interCount = 0;
    final allNames = DrugInteractionService.getAllDrugNames();
    for (final name in allNames) {
      if (interCount >= _maxPerCat) break;
      if (name.toLowerCase().contains(q)) {
        res.add(_SearchResult(
          cat:      _SearchCat.interaction,
          title:    name,
          subtitle: isEs ? 'Ver interacciones' : 'Ver interações',
          data:     name,
        ));
        interCount++;
      }
    }

    setState(() { _results = res; _searched = true; });
  }

  // ── Navegar ao resultado ────────────────────────────────────────────────
  void _open(_SearchResult r) {
    Navigator.pop(context); // fecha modal
    switch (r.cat) {
      case _SearchCat.drug:
        showDrugDetailSheet(context, r.data as DrugModel);
      case _SearchCat.protocol:
        showProtocolDetail(context, r.data as dynamic);
      case _SearchCat.prescription:
        // Navega para a tela de prescrições — a própria tela já abre o detalhe
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _PrescripcionesShell()),
        );
      case _SearchCat.interaction:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DrugInteractionsScreen()),
        );
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    final bg      = dark ? const Color(0xFF111714) : const Color(0xFFFFFFFF);
    final surface = dark ? const Color(0xFF1A211D) : const Color(0xFFF4F6F5);
    final border  = dark ? const Color(0x1AFFFFFF) : const Color(0x14000000);
    final textPri = dark ? const Color(0xFFEEF2EE) : const Color(0xFF101C14);
    final textSec = dark ? const Color(0xFF7A9486) : const Color(0xFF6B8272);
    final green   = const Color(0xFF46E28C);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: green, size: 22),
                const SizedBox(width: 10),
                Text(
                  isEs ? 'Buscar en MedCases' : 'Pesquisar no MedCases',
                  style: TextStyle(
                    color: textPri,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Campo de busca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Icon(Icons.search_rounded,
                        color: Color(0xFF7A9486), size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      onChanged: _onChanged,
                      style: TextStyle(color: textPri, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: isEs
                            ? 'Fármacos, protocolos, simulaciones...'
                            : 'Fármacos, protocolos, simulações...',
                        hintStyle: TextStyle(color: textSec, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() { _results = []; _searched = false; });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(Icons.close_rounded,
                            color: textSec, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Chips de categoria (legenda)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _CatChip(label: isEs ? 'Fármacos' : 'Fármacos',
                    color: const Color(0xFFFBBF24), dark: dark),
                const SizedBox(width: 6),
                _CatChip(label: 'Protocolos',
                    color: const Color(0xFF4ADE80), dark: dark),
                const SizedBox(width: 6),
                _CatChip(label: isEs ? 'Simulaciones' : 'Simulações',
                    color: const Color(0xFFA78BFA), dark: dark),
                const SizedBox(width: 6),
                _CatChip(label: isEs ? 'Interacciones' : 'Interações',
                    color: const Color(0xFFFF6BA0), dark: dark),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Resultados
          Expanded(
            child: _searched && _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            color: textSec, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          isEs ? 'Sin resultados' : 'Nenhum resultado',
                          style: TextStyle(color: textSec, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : !_searched
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEs
                                  ? 'Escribe al menos 2 letras para buscar en todo el contenido del app.'
                                  : 'Digite ao menos 2 letras para pesquisar em todo o conteúdo do app.',
                              style: TextStyle(
                                  color: textSec, fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: border),
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          return _GlobalSearchResultTile(
                            result: r,
                            dark: dark,
                            textPri: textPri,
                            textSec: textSec,
                            onTap: () => _open(r),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Category chip ──────────────────────────────────────────────────────────
class _CatChip extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   dark;
  const _CatChip({required this.label, required this.color, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Result tile ────────────────────────────────────────────────────────────
class _GlobalSearchResultTile extends StatelessWidget {
  final _SearchResult result;
  final bool          dark;
  final Color         textPri;
  final Color         textSec;
  final VoidCallback  onTap;

  const _GlobalSearchResultTile({
    required this.result,
    required this.dark,
    required this.textPri,
    required this.textSec,
    required this.onTap,
  });

  static IconData _icon(_SearchCat c) => switch (c) {
    _SearchCat.drug         => Icons.medication_rounded,
    _SearchCat.protocol     => Icons.assignment_rounded,
    _SearchCat.prescription => Icons.description_rounded,
    _SearchCat.interaction  => Icons.compare_arrows_rounded,
  };

  static Color _color(_SearchCat c) => switch (c) {
    _SearchCat.drug         => const Color(0xFFFBBF24),
    _SearchCat.protocol     => const Color(0xFF4ADE80),
    _SearchCat.prescription => const Color(0xFFA78BFA),
    _SearchCat.interaction  => const Color(0xFFFF6BA0),
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(result.cat);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon(result.cat), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.title,
                    style: TextStyle(
                        color: textPri,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(result.subtitle,
                    style: TextStyle(color: textSec, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textSec, size: 18),
        ]),
      ),
    );
  }
}
