import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/common_widgets.dart';
import '../data/drugs_database.dart';
import '../models/drug_model.dart';
import '../services/drug_interaction_service.dart';
import '../services/notification_service.dart';
import 'cockpit_screen.dart';
import 'internacion/internacion_screen.dart';
import 'internacion/services/internacion_persistence.dart' show PacienteSession;
import 'drugs_screen.dart' show DrugsScreen, showDrugDetailSheet;
import 'prescripciones_screen.dart' show PrescripcionesScreen, prescriptionModels;
import 'tools_screen.dart' show PediatricsTabContent, ToolsScreen, toolsScreenTabNotifier;
import 'calculadora_screen.dart' show CalculadoraScreen;
import 'prescripciones_screen.dart';
import 'drug_interactions_screen.dart';
import 'protocols_screen.dart' show openProtocolById, showProtocolDetail;
import '../models/protocol_model.dart';
import 'avaliacao_screen.dart';
import '../widgets/meu_plantao_dashboard.dart';
import 'ai_screen.dart' show AiScreen;
import 'package:flutter_markdown/flutter_markdown.dart';

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
    // ── NULL-SAFETY GUARD — trava de segurança contra tela branca ─────────────
    // Em flutter clean / primeiro boot, o AppProvider pode estar em estado de
    // inicialização incompleta. context.select/read jamais deve crashar silenciosamente.
    // Se qualquer exceção escapar aqui (NPE, StateError, LookupError), o Flutter
    // exibe uma tela BRANCA em release mode — o try/catch captura isso e exibe
    // um skeleton seguro enquanto o provider termina de carregar.
    bool dark;
    bool isEs;
    AppProvider p;
    try {
      dark = context.select<AppProvider, bool>((p) => p.darkMode);
      isEs = context.select<AppProvider, bool>((p) => p.lang == 'es');
      p    = context.read<AppProvider>();
    } catch (e, st) {
      debugPrint('ERRO CRÍTICO HOME [build/provider-read]: $e\n$st');
      // Fallback seguro: mostra spinner centralizado enquanto provider carrega.
      // O framework vai reconstruir este widget quando o provider estiver pronto.
      return const _HomeSafeLoadingShell();
    }

    // ── LayoutBuilder: breakpoint switch responsivo ───────────────────────────
    // MOTIVO: MediaQuery.of(context).size pode ser stale no Flutter Web durante
    // redimensionamento do browser ou ao activar o emulador mobile do Chrome
    // DevTools (F12 → device toolbar). LayoutBuilder usa BoxConstraints do
    // parent imediato e reage frame-a-frame — sem cache, sem stale reads.
    //
    // BREAKPOINTS:
    //   < 1024 px → layout mobile (idêntico ao app iOS/Android)
    //   ≥ 1024 px → layout desktop (2 colunas + painel lateral)
    //
    // IMPORTANTE: kIsWeb foi REMOVIDO da condição de desktop.
    // Motivo: kIsWeb=true também no Chrome DevTools mobile emulator, o que
    // bloqueava a entrada no branch mobile e forçava desktop mesmo em 375px.
    // Com a remoção, a decisão é puramente dimensional — funciona corretamente
    // em todos os contextos: browser desktop, DevTools emulator e app nativo.
    try {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Desktop: layout em 2 colunas — EXCLUSIVO para Web ≥ 1024 px.
          // Nativo (iOS/Android/iPad): sempre usa _buildMobileLayout, mesmo em
          // landscape com largura ≥ 1024 px — os cards estão por trás de
          // guard `if (kIsWeb)` no desktop layout e ficariam invisíveis.
          // Fix B143: kIsWeb garante que iPad nativo nunca entra aqui.
          if (width >= 1024 && kIsWeb) {
            // MedBreakpoints.fromWidth para não ler MediaQuery (evita stale)
            final bp = MedBreakpoints.fromWidth(width);
            return _buildDesktopLayout(context, dark, isEs, p, bp);
          }
          // Mobile / tablet / iPad nativo — layout nativo com max-width no tablet
          return _buildMobileLayout(context, dark, isEs, p, availableWidth: width);
        },
      );
    } catch (e, st) {
      debugPrint('ERRO CRÍTICO HOME [build/layout]: $e\n$st');
      return const _HomeSafeLoadingShell();
    }
  }

  Widget _buildDesktopLayout(BuildContext context, bool dark, bool isEs, AppProvider p, MedBreakpoints bp) {
    final hPad = bp.hPadding;

    // Helpers de navegação inline para o desktop
    void push(Widget page) => Navigator.of(context).push(_HomeScreenState._slide(page));

    // Definição dos cards principais para o grid desktop
    // Build 138: FÁRMACOS/INTERACCIONES removidos como cards independentes.
    // Nova ordem: ADULTO → PEDIATRIA → BIBLIOTECA → H.CLÍNICA → SIMULAÇÕES
    // B141: paleta atualizada — mesma dos cards mobile
    final mainCards = [
      _HomeCardData(
        icon: Icons.person_rounded,
        label: 'ADULTO',
        subtitle: isEs ? 'Explorar caso clínico' : 'Explorar caso clínico',
        // B141: Emerald Green #059669 → #10b981
        gradientColors: const [Color(0xFF022c22), Color(0xFF059669), Color(0xFF10b981)],
        accentColor: const Color(0xFF6ee7b7),
        onTap: () => push(_AdultoShell(openProtocol: widget.openProtocol)),
      ),
      _HomeCardData(
        icon: Icons.child_care_rounded,
        label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
        subtitle: isEs ? 'Casos clínicos de referencia' : 'Casos clínicos de referência',
        // B144: Azul Petróleo — dark teal elegante, nunca chega ao ciano
        gradientColors: const [Color(0xFF042f2e), Color(0xFF0f766e), Color(0xFF134e4a)],
        accentColor: const Color(0xFFccfbf1),
        onTap: () => push(const _PediatricsShell()),
      ),
      _HomeCardData(
        icon: Icons.menu_book_rounded,
        label: 'BIBLIOTECA',
        subtitle: isEs ? 'Referencias clínicas' : 'Referências clínicas',
        // B141: Elegant Gray #475569 → #64748b
        gradientColors: const [Color(0xFF1e293b), Color(0xFF475569), Color(0xFF64748b)],
        accentColor: const Color(0xFFe2e8f0),
        onTap: () => widget.onTabChange(5),
      ),
      _HomeCardData(
        icon: Icons.assignment_ind_outlined,
        label: 'H. CLÍNICA',
        subtitle: isEs ? 'Historial del paciente' : 'Histórico do paciente',
        // B141: Orange Vibrant #ea580c → #fb923c
        gradientColors: const [Color(0xFF431407), Color(0xFFea580c), Color(0xFFfb923c)],
        accentColor: const Color(0xFFfed7aa),
        onTap: () => widget.onTabChange(3),
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
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Linha superior: pesquisa ──────────────────────────────────────
        _HomeSearchBar(dark: dark, isEs: isEs),
        const SizedBox(height: 14),

        // ── IA MedCases Chat — expansão vertical dinâmica (desktop) ─────────
        // Build 100+: sem SizedBox de altura fixa — mesma lógica do mobile.
        _HomeInlineChat(
          dark: dark,
          isEs: isEs,
          onNavigateToAi: widget.onTabChange,
        ),
        const SizedBox(height: 14),

        // ── Timer Rápido de Plantão ───────────────────────────────────────
        _ShiftTimerBar(dark: dark, isEs: isEs),
        const SizedBox(height: 24),

        // ── Build 138: CALCULADORA E FÁRMACOS — card unificado full-width ─
        if (kIsWeb) ...[
          _HomeCalculadoraFarmacosCard(dark: dark, isEs: isEs),
          const SizedBox(height: 12),  // ORDEM 43: 16→12 gap vertical compacto
        ],

        // ── Grid de cards principais — 3 colunas no desktop ─────────────
        // BUILD 93: apenas Web exibe ferramentas clínicas (Apple 1.4.1)
        if (kIsWeb) LayoutBuilder(builder: (context, constraints) {
          const cols   = 3;
          const gap    = 12.0;  // ORDEM 43: 14→12 crossAxisSpacing premium
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

        // BUILD 93: seção 2 colunas (Plantão + Emergências) web-only
        if (kIsWeb) ...[
          const SizedBox(height: 12),  // ORDEM 43: 24→12 vertical gap compacto
          _HomeDivider(dark: dark),
          const SizedBox(height: 12),  // ORDEM 43: 20→12 vertical gap compacto

          // ── Layout de 2 colunas: Shortcuts + Emergências ───────────────
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
                    // ══════════════════════════════════════════════════════════
                    // BUILD 281 — ISOLAMENTO DE ESCOPO: Meu Plantão (desktop)
                    // OCULTO para submissão App Store / Google Play.
                    // REVERSÃO: remover /* e */ para reativar o Consumer abaixo.
                    // Estrutura: lib/widgets/meu_plantao_dashboard.dart (intacta)
                    // ══════════════════════════════════════════════════════════
                    /*
                    Consumer<AppProvider>(
                      builder: (ctx, _, __) => MeuPlantaoDashboard(
                        onOpenDrug: (drug) => showDrugDetailSheet(ctx, drug),
                        onOpenCalc: (calcId) {
                          const calcTabMap = {
                            'calc_biometria':   0,
                            'calc_scores':      1,
                            'calc_cardio':      2,
                            'calc_eletrólitos': 3,
                            'calc_infusao':     0,
                            'calc_referencia':  4,
                            'calc_prescricoes': 0,
                            'calc_pediatria':   5,
                          };
                          toolsScreenTabNotifier.value = calcTabMap[calcId] ?? 0;
                          widget.onTabChange(4);
                        },
                        onManageTap: () => showPlantaoManageSheet(ctx),
                        onOpenInternacion: (session) => Navigator.of(ctx).push(
                          HomeScreen.slideRoute(
                            _AdultoShell(
                              openProtocol: widget.openProtocol,
                              initialSession: session,
                            ),
                          ),
                        ),
                      ),
                    ),
                    */
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
        ],
      ]),
    );
  }

  // ── HOME V2 — layout mobile ───────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context, bool dark, bool isEs, AppProvider p, {double availableWidth = 0}) {
    // ── NULL-SAFETY: valida estado do provider antes de renderizar ────────────
    // Após flutter clean, SharedPreferences pode não ter retornado ainda.
    // Se isLoadingPublic (dados remotos carregando) → mostra skeleton sem crash.
    try {
      // Leitura defensiva: qualquer acesso a p.* que lance ProviderException
      // ou NPE deve cair no catch e exibir o loading shell.
      // ignore: unnecessary_statements
      p.lang; // força acesso rápido para checar se o provider está vivo
    } catch (e, st) {
      debugPrint('ERRO CRÍTICO HOME [_buildMobileLayout/provider-check]: $e\n$st');
      return const _HomeSafeLoadingShell();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // BUILD 138 — "Cockpit de Emergência" — Redesign completo da Home Screen
    //
    // NOVA ORDEM (mobile):
    //   1. IA INLINE CHAT  — hero (chat real, streaming) — azul MedCases IA
    //   2. LINHA 1 (full)  — CALCULADORA E FÁRMACOS (card unificado)
    //   3. LINHA 2         — [ADULTO] + [PEDIATRÍA] lado a lado
    //   4. LINHA 3         — [BIBLIOTECA] + [H. CLÍNICA] lado a lado
    //   5. QUICK ACCESS BAR — BUSCAR | NOTAS | RECIENTES | FAVORITOS | EVALUACIÓN
    //   6. MI GUARDIA      — bloco de gerenciamento de plantão
    //
    // REMOVIDOS como blocos independentes (lógica preservada):
    //   • FÁRMACOS card standalone  → integrado em CALCULADORA E FÁRMACOS (Linha 1)
    //   • INTERACCIONES card standalone → acessível via BUSCAR / Ferramentas
    //
    // ITENS OCULTOS PARA REVISÃO APPLE (lógica preservada, UI invisível):
    //   • Simulaciones / Simulações  → Apple Guideline 1.4.1
    //   • Mi Guardia / Meu Plantão   → Apple Guideline 1.4.2
    //   • Emergências Rápidas        → Apple Guideline 1.4.1
    //
    // Versão Web mantém todos os elementos via guard kIsWeb.
    // ══════════════════════════════════════════════════════════════════════════

    // B143 — iPad/tablet nativo em landscape: centraliza o conteúdo com
    // maxWidth de 800 px para evitar cards muito esticados, mantendo todos
    // os módulos visíveis (Calculadora, Adulto, Pediatria, etc.).
    // Em iPhone / tela estreita: availableWidth < 600 → sem restrição.
    final bool isTabletLandscape = !kIsWeb && availableWidth >= 600;
    final double contentMaxWidth = isTabletLandscape ? 800.0 : double.infinity;

    // BUILD 281 — bottomPad reajustado: módulo Meu Plantão isolado do layout.
    // Footer overlay (48px nav + 22px legal) + safe area do dispositivo + 24px margem.
    // Sem o painel MiGuardia, não há necessidade do clamp 160px anterior.
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    // kIsWeb: footer no fluxo normal — 24px fixo.
    // Mobile: nav(48) + legal(22) + safeArea + 24 margem = confortável sem excesso.
    final double bottomPad  = kIsWeb ? 24.0 : (safeBottom + 24.0).clamp(24.0, 86.0);

    Widget mobileContent = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isTabletLandscape ? 20 : 16,  // ORDEM 43: 12→16 margem lateral premium
          6,  // ORDEM 12: compactado (era 8)
          isTabletLandscape ? 20 : 16,  // ORDEM 43: 12→16 margem lateral premium
          bottomPad,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── BLOCO 1: IA INLINE CHAT — expansão vertical dinâmica ────────────
          // Azul MedCases IA após Build 138. O chat cresce naturalmente com
          // cada turno, empurrando os cards abaixo no scroll.
          _HomeInlineChat(
            dark: dark,
            isEs: isEs,
            onNavigateToAi: widget.onTabChange,
          ),
          const SizedBox(height: 8),  // ORDEM 12: compactado

          // ── LINHA 1: CALCULADORA E FÁRMACOS — card unificado full-width ─────
          _HomeCalculadoraFarmacosCard(dark: dark, isEs: isEs),
          const SizedBox(height: 12),  // ORDEM 43: 8→12 gap vertical premium

          // ── LINHA 2: ADULTO + PEDIATRÍA — dois cards paralelos ──────────────
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
          const SizedBox(height: 12),  // ORDEM 43: 8→12 gap vertical premium

          // ── LINHA 3: BIBLIOTECA + H. CLÍNICA — dois cards paralelos ─────────
          _HomeBibliotecaHClinicaRow(
            dark: dark,
            isEs: isEs,
            onTabChange: widget.onTabChange,
          ),
          const SizedBox(height: 12),  // ORDEM 43: 8→12 gap vertical premium

          // ── QUICK ACCESS BAR — BUSCAR | NOTAS | RECIENTES | FAVORITOS | EVAL ─
          _HistorialCompactCard(
            dark: dark,
            isEs: isEs,
            openProtocol: widget.openProtocol,
            onOpenNotes: widget.onOpenNotes,
            onCheckUpdate: widget.onCheckUpdate,
          ),
          const SizedBox(height: 6),  // ORDEM 12: trailer slim

          // ══════════════════════════════════════════════════════════════════
          // BUILD 281 — ISOLAMENTO DE ESCOPO: Meu Plantão / Mi Guardia
          // Módulo OCULTO para submissão App Store / Google Play.
          // REVERSÃO: remover os comentários /* e */ abaixo para reativar.
          // Estrutura interna intacta em: lib/widgets/meu_plantao_dashboard.dart
          // ══════════════════════════════════════════════════════════════════
          // ORDEM 37 M1: Mi Guardia / Meu Plantão restaurado
          _HomeMiGuardiaSection(
            dark: dark,
            isEs: isEs,
            onOpenDrug: (drug) => showDrugDetailSheet(context, drug),
            onOpenCalc: (calcId) {
              const calcTabMap = {
                'calc_biometria': 0, 'calc_scores': 1, 'calc_cardio': 2,
                'calc_eletrólitos': 3, 'calc_infusao': 0,
                'calc_referencia': 4, 'calc_prescricoes': 0,
                'calc_pediatria': 5,
              };
              toolsScreenTabNotifier.value = calcTabMap[calcId] ?? 0;
              widget.onTabChange(4);
            },
            onManageTap: () => showPlantaoManageSheet(context),
            onOpenInternacion: (session) => Navigator.of(context).push(
              HomeScreen.slideRoute(
                _AdultoShell(
                  openProtocol: widget.openProtocol,
                  initialSession: session,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── BLOCO WEB-ONLY — EMERGÊNCIAS RÁPIDAS ────────────────────────────
          if (kIsWeb) ...[
            _QuickEmergencies(p: p, dark: dark, isEs: isEs, openProtocol: widget.openProtocol),
          ],

          // ── ITENS PRESERVADOS MAS OCULTOS (Apple review) ─────────────────────
          // Fármacos standalone, Interacciones, Simulaciones, Herramientas:
          // Código e lógica 100% intactos. Apenas removidos da árvore de widgets.
          // (see: _FarmacosShell, DrugInteractionsScreen, _PrescripcionesShell,
          //       _CalculadorasShell, ToolsScreen, _HomeMiGuardiaSection)
        ]),
      );

    // B143: tablet/iPad nativo em landscape → centraliza com maxWidth 800 px
    if (isTabletLandscape) {
      mobileContent = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: mobileContent,
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: mobileContent,
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
// _HomeSafeLoadingShell — esqueleto seguro para tela branca
// ─────────────────────────────────────────────────────────────────────────────
// Exibido quando o build() da Home lança exceção (NPE, provider não pronto,
// dados ainda carregando após flutter clean). Garante que o usuário veja
// algo razoável em vez de uma tela branca ou vermelha de erro.
// O framework reconstrói a Home automaticamente assim que o provider notificar.
class _HomeSafeLoadingShell extends StatelessWidget {
  const _HomeSafeLoadingShell();

  @override
  Widget build(BuildContext context) {
    // Detecta dark mode via Brightness do tema — sem ler o AppProvider
    // (que pode estar em estado inválido, por isso chegamos aqui).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF);
    final spinnerColor = isDark ? const Color(0xFF10B981) : const Color(0xFF075f45);

    return Container(
      color: bg,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
          strokeWidth: 2.5,
        ),
      ),
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
            colors: [Color(0xFF10B981), Color(0xFF0F1116)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
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
          color: dark ? const Color(0xFF252930) : const Color(0xFFEFF1F7),
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
              isEs ? 'Buscar fármaco, protocolo…' : 'Buscar medicamento, protocolo…',
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

    final sheetBg  = dark ? const Color(0xFF1A1D23) : Colors.white;
    final inputBg  = dark ? const Color(0xFF252930) : const Color(0xFFF2F4F8);
    final textMain = dark ? Colors.white : const Color(0xFF1A202C);
    final textSub  = dark ? Colors.white54 : const Color(0xFF718096);
    final divColor = dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEDF0F7);

    // ── Resultados ────────────────────────────────────────────────────────
    // BUILD 93 — Apple 1.4.1/1.4.2: Fármacos e Protocolos clínicos
    // são indexados APENAS na versão Web. No mobile/iOS apenas conteúdo
    // educacional (Simulações Acadêmicas) aparece na busca.
    final q = _q.toLowerCase().trim();

    // Fármacos — visível apenas na Web
    final drugs = (q.isEmpty || !kIsWeb)
        ? <DrugModel>[]
        : p.drugsDB
            .where((d) =>
                d.name.toLowerCase().contains(q) ||
                (d.className[isEs ? 'es' : 'pt'] ?? '').toLowerCase().contains(q) ||
                (d.category[isEs ? 'es' : 'pt'] ?? '').toLowerCase().contains(q))
            .take(8)
            .toList();

    // Protocolos — visível apenas na Web
    final protocols = (q.isEmpty || !kIsWeb)
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
                          // BUILD 93 — hint educacional (Apple 1.4.1)
                          hintText: isEs
                              ? 'Caso clínico, simulación, pregunta académica…'
                              : 'Caso clínico, simulação, pergunta acadêmica…',
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
                              ? (kIsWeb ? 'Busca fármacos, protocolos\ny prescrições' : 'Busca fármacos, protocolos\ny casos clínicos')
                              : (kIsWeb ? 'Busque fármacos, protocolos\ne prescrições' : 'Busque fármacos, protocolos\ne casos clínicos'),
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
                                label: isEs ? 'PROTOCOLOS' : 'PROTOCOLOS', dark: dark), // técnico
                            ...protocols.map((pr) {
                              final lang  = isEs ? 'es' : 'pt';
                              final title = pr.title[lang] ?? pr.title['pt'] ?? '';
                              return _SearchResultTile(
                                leading: Icons.emergency_rounded,
                                leadingColor: const Color(0xFFCC2222),
                                title: title,
                                subtitle: isEs ? 'Protocolo clínico' : 'Protocolo clínico', // igual // igual
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
          onTap: () { AppHaptics.selection(context); onTap(); },
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
// HOME INLINE CHAT — chat real embutido na Home sem trocar de aba.
// Streaming via AppProvider.sendAiMessage (RAG + GeminiServiceV2 completo).
// Mostra última Q&A inline; botão "Ver completo" abre aba IA.
// ═══════════════════════════════════════════════════════════════════════════════
class _HomeInlineChat extends StatefulWidget {
  final bool dark;
  final bool isEs;
  final ValueChanged<int> onNavigateToAi;

  const _HomeInlineChat({
    required this.dark,
    required this.isEs,
    required this.onNavigateToAi,
  });

  @override
  State<_HomeInlineChat> createState() => _HomeInlineChatState();
}

class _HomeInlineChatState extends State<_HomeInlineChat> {
  final _ctrl       = TextEditingController();
  // autofocus: false é obrigatório — o FocusNode NUNCA deve adquirir foco
  // automaticamente. Sem isso, o teclado abre sozinho ao retornar para a Home
  // (o IndexedStack preserva o widget mas o FocusNode pode ser re-attached).
  final _focus      = FocusNode();
  final _scrollCtrl = ScrollController();

  // MedCases IA Official Blue palette — Build 138
  static const _kAiBlue     = Color(0xFF1B6FD8);
  static const _kAiBlueBg   = Color(0xFF252930);
  static const _kAiBlueBord = Color(0xFF60A5FA);

  // ── Histórico de mensagens (multi-turn inline) ────────────────────────────
  // Cada item: {'role': 'user'|'ai', 'text': '...', 'isError': bool}
  final List<Map<String, dynamic>> _messages = [];
  String _streaming = '';
  bool   _thinking  = false;

  // ── Auto-persist session tracking ────────────────────────────────────────
  // ID estável da sessão inline — gerado na primeira mensagem enviada e
  // reutilizado em todas as atualizações da mesma conversa (evita duplicatas
  // no Firestore / SharedPreferences ao salvar turno a turno).
  String? _sessionId;
  // Chave SharedPreferences espelhando a convenção de ai_screen.dart
  static const _kHistKey = 'medcases_ia_chat_history_v1';

  @override
  void initState() {
    super.initState();
    // ── LOG DE DIAGNÓSTICO — captura falhas de inicialização do InlineChat ────
    // Se o provider não estiver disponível ao montar, o erro aparecerá aqui.
    // Visível no Xcode Console / flutter logs (apenas debug mode).
    try {
      debugPrint('[HomeInlineChat] initState — montando mini-chat inline');
      // Garante que o FocusNode nunca está focado ao montar/remontar o widget.
      // Previne teclado automático ao retornar para a Home via IndexedStack.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.unfocus();
      });
    } catch (e, st) {
      debugPrint('ERRO CRÍTICO HOME [InlineChat/initState]: $e\n$st');
    }
  }

  @override
  void didUpdateWidget(_HomeInlineChat old) {
    super.didUpdateWidget(old);
    // Se qualquer prop mudou (dark/isEs/etc) e o widget foi reconstruído,
    // certificar que o foco não é reclamado automaticamente.
    // Não chama _focus.unfocus() aqui para não interferir com digitação ativa.
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Rola o ListView até o final após setState.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTO-PERSIST: dual-write após cada turno completo (user + AI)
  //
  // Espelha a lógica de _saveCurrentSessionToHistory() do AiScreenState
  // mas funciona de forma autônoma no mini-chat da Home:
  //   1. Gera um _sessionId estável na primeira chamada (ISO8601 timestamp)
  //      → evita duplicatas no Firestore ao salvar turno a turno
  //   2. Constrói o payload do mesmo formato de _ChatSession.toJson()
  //      → compatível com o histórico de ai_screen.dart / _ChatHistorySheet
  //   3. Dual-write: Firestore (primário) + SharedPreferences (offline cache)
  //      → chave uid_medcases_ia_chat_history_v1 — mesma convenção da IA Tab
  //
  // Chamado em onDone (sucesso) e onError (erro da IA) após setState,
  // garantindo que cada resposta é gravada assim que chega.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _homePersistTurn() async {
    if (!mounted) return;
    final p = context.read<AppProvider>();

    // Filtra apenas mensagens reais (sem erros de API) para não poluir o histórico
    final validMsgs = _messages
        .where((m) => m['isError'] != true)
        .toList();
    if (validMsgs.isEmpty) return;

    // Garante que a última mensagem é do tipo 'ai' (turno completo)
    if (validMsgs.last['role'] != 'ai') return;

    // Inicializa o ID estável da sessão na primeira persistência
    _sessionId ??= DateTime.now().toIso8601String();

    final firstUserMsg = validMsgs
        .firstWhere((m) => m['role'] == 'user', orElse: () => validMsgs.first);
    final summary = (firstUserMsg['text'] as String?) ?? '';

    // Serializa mensagens no formato de _ChatMsg.toJson()
    final msgsPayload = validMsgs.map((m) => {
      'id':   '${m['role']}_${DateTime.now().microsecondsSinceEpoch}',
      'role': m['role'] as String,
      'text': m['text'] as String,
    }).toList();

    final session = {
      'id':       _sessionId!,
      'savedAt':  DateTime.now().toIso8601String(),
      'summary':  summary.length > 100 ? summary.substring(0, 100) : summary,
      'messages': msgsPayload,
    };

    // ── Write 1: Firestore (fire-and-forget, sem bloquear a UI) ─────────────
    final uid = p.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      FirestoreService.saveAiSession(uid, session).catchError((_) {});
    }

    // ── Write 2: SharedPreferences (offline cache, mesma chave da IA Tab) ───
    try {
      final prefs = await SharedPreferences.getInstance();
      final histKey = '${uid ?? 'anon'}_$_kHistKey';
      final existing = prefs.getString(histKey);
      List<dynamic> histList = [];
      if (existing != null && existing.isNotEmpty) {
        try { histList = jsonDecode(existing) as List; } catch (_) {}
      }
      // Remove entrada antiga com o mesmo ID (atualização incremental)
      histList.removeWhere((e) => e is Map && e['id'] == _sessionId);
      // Insere no topo (mais recente primeiro)
      histList.insert(0, session);
      // Mantém apenas as 10 sessões mais recentes (mesmo limite da IA Tab)
      if (histList.length > 10) histList = histList.sublist(0, 10);
      await prefs.setString(histKey, jsonEncode(histList));
    } catch (_) {}
  }

  /// Botão enviar — comportamento inteligente:
  ///   campo VAZIO + sem histórico  → navegação direta para tela cheia de IA
  ///   campo VAZIO + com histórico  → navega para IA tab carregando APENAS a
  ///                                   primeira query do fluxo Home (limpa histórico anterior da IA tab)
  ///   campo CHEIO  → dispara stream do mini-chat inline
  void _onSendPressed() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      if (_messages.isNotEmpty) {
        // B144: hasHistory + campo vazio → IA tab com apenas a query original
        // Extrai a primeira mensagem do usuário que iniciou o fluxo na Home.
        // pendingQuery substitui qualquer histórico anterior aberto na IA tab.
        final firstUserMsg = _messages
            .firstWhere(
              (m) => m['role'] == 'user',
              orElse: () => <String, dynamic>{},
            )['text'] as String? ?? '';
        if (firstUserMsg.isNotEmpty) {
          // Limpa histórico pendente e define apenas a primeira query
          AiScreen.pendingHistory.value = [];          // limpa histórico anterior da IA tab
          AiScreen.pendingQuery.value   = firstUserMsg;
        }
      }
      widget.onNavigateToAi(2);
      return;
    }
    _send(text);
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _thinking) return;
    _ctrl.clear();
    _focus.unfocus();
    setState(() {
      _messages.add({'role': 'user', 'text': text, 'isError': false});
      _streaming = '';
      _thinking  = true;
    });
    _scrollToBottom();
    final p = context.read<AppProvider>();
    try {
      await p.sendAiMessage(
        text,
        onChunk: (acc) {
          if (mounted) {
            // CAMADA 1 — Stream sanitizer: expurga metadados de cabeçalho antes
            // de exibir o texto parcial. Idêntico ao pipeline de ai_screen.dart.
            final cleaned = _homeStripMetadataHeaders(acc);
            setState(() => _streaming = cleaned);
            _scrollToBottom();
          }
        },
        onDone: (fin) {
          if (mounted) {
            // CAMADA 1 + 2 — Strip cabeçalhos E limpeza profunda de CoT/tags
            // na resposta final. Idêntico ao tratamento de ai_screen.dart.
            final cleanFin = _cleanHomeAiText(_homeStripMetadataHeaders(fin));
            setState(() {
              _messages.add({'role': 'ai', 'text': cleanFin, 'isError': false});
              _streaming = '';
              _thinking  = false;
            });
            _scrollToBottom();
            // AUTO-PERSIST: grava o turno completo (user+AI) no histórico
            // dual-write (Firestore + SharedPreferences) fire-and-forget.
            _homePersistTurn();
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _messages.add({'role': 'ai', 'text': err, 'isError': true});
              _streaming = '';
              _thinking  = false;
            });
            _scrollToBottom();
            // AUTO-PERSIST: mesmo em erro — salva o turno do usuário para
            // que o histórico mostre a tentativa no _ChatHistorySheet.
            _homePersistTurn();
          }
        },
      );
    } catch (e) {
      // Captura exceções não tratadas (ex: TimeoutException, SocketException)
      // que possam escapar do onError — garante limpeza total do estado.
      if (mounted) {
        setState(() {
          _streaming = '';
          _thinking  = false;
          // Adiciona bolha de erro genérico se não houver resposta AI ainda
          if (_messages.isEmpty || _messages.last['role'] != 'ai') {
            _messages.add({'role': 'ai', 'text': '⚠️ Erro de conexão. Tente novamente.', 'isError': true});
          }
        });
      }
    }
  }

  /// Navega para a aba de IA (tab 2).
  ///
  /// [q] → query opcional para disparar como nova mensagem (chips de atalho).
  /// [withHistory] → true quando chamado por "Ver más"/"Ver resposta completa"
  ///   — injeta o histórico completo do mini-chat no AiScreen para continuar
  ///   a conversa de onde parou.
  void _goToAiTab([String? q, bool withHistory = false]) {
    if (q != null && q.isNotEmpty) {
      // Chip de atalho ou campo preenchido: dispara nova query na tela de IA
      AiScreen.pendingQuery.value = q;
    } else if (withHistory) {
      // Build 1556 Fix: escopo local do _HomeInlineChatState corrigido.
      //
      // PROBLEMA ANTERIOR: a guard `_messages.isNotEmpty` bloqueava a injeção
      // quando o usuário clicava "Ver resposta completa" durante streaming ativo
      // (_thinking=true) — nesse estado _messages ainda pode estar vazio porque a
      // resposta AI ainda não foi commitada pelo onDone. O resultado era AiScreen
      // abrir completamente em branco.
      //
      // CORREÇÃO: avaliar _messages E _streaming de forma independente.
      // Se _messages vazio mas _streaming não vazio → ainda há conteúdo local.
      // Só pula a injeção se AMBOS estiverem vazios.
      //
      // ESCOPO: _messages e _streaming pertencem exclusivamente a
      // _HomeInlineChatState (definidos nas linhas 1078-1079 desta classe).
      // Não há acesso a nenhuma lista global da HomeScreen pai.

      // Snapshot das mensagens commitadas (sem erros)
      final clean = _messages.where((m) => m['isError'] != true).toList();
      final pairs = clean
          .map((m) => {'role': m['role'] as String, 'text': m['text'] as String})
          .toList();

      // Snapshot do streaming em vôo (race condition: onDone ainda não disparou)
      final streamingSnapshot = _streaming.trim();
      if (streamingSnapshot.isNotEmpty) {
        pairs.add({'role': 'ai', 'text': streamingSnapshot});
      }

      // Injeta somente se há conteúdo real — evita AiScreen em branco
      if (pairs.isNotEmpty) {
        AiScreen.pendingHistory.value = pairs;
      }
      // Se pairs ainda vazio (edge case: clique antes da primeira palavra AI),
      // navega mesmo assim — AiScreen exibirá saudação padrão normalmente.
    }
    widget.onNavigateToAi(2);
  }

  @override
  Widget build(BuildContext context) {
    // ── NULL-SAFETY: wrap total do build do InlineChat ───────────────────────
    // Se qualquer filho lançar exceção, o mini-chat é substituído por um
    // container vazio com a cor de fundo correta — nunca tela branca.
    try {
      return _buildChatContent(context);
    } catch (e, st) {
      debugPrint('ERRO CRÍTICO HOME [InlineChat/build]: $e\n$st');
      final isDark = widget.dark;
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252930) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : const Color(0xFFE4EEE9),
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? const Color(0xFF10B981) : const Color(0xFF075f45),
            ),
            strokeWidth: 2,
          ),
        ),
      );
    }
  }

  Widget _buildChatContent(BuildContext context) {
    final dark  = widget.dark;
    final isEs  = widget.isEs;

    // SUPER ORDEM 11: sempre Dark Graphite — paridade total com AiScreen
    const cardBg      = Color(0xFF1A1D23);
    const borderColor = Color(0xFF2A2D35);
    const fieldBg     = Color(0xFF252930);
    final fieldBorder = Colors.white.withValues(alpha: 0.10);
    const textColor   = Colors.white;
    final hintColor   = Colors.white.withValues(alpha: 0.35);
    const subText     = Color(0xFF6B8ABE);

    final hasHistory  = _messages.isNotEmpty;
    final hasStream   = _thinking && _streaming.isNotEmpty;
    final hasThinking = _thinking && _streaming.isEmpty;

    // ── Constrói a lista de bolhas como widgets ────────────────────────────
    // shrinkWrap: true + NeverScrollableScrollPhysics() permite que o chat
    // cresça verticalmente dentro do SingleChildScrollView externo (home),
    // empurrando FÁRMACOS/INTERACCIONES para baixo naturalmente.
    // O ScrollController ainda é mantido para _scrollToBottom() funcionar
    // via jumpTo / animateTo no parent scroll controller (noop quando
    // NeverScrollableScrollPhysics está ativa — mas a animação do parent
    // SingleChildScrollView cuida do scroll).
    Widget conversationArea;
    if (hasHistory || hasStream || hasThinking) {
      final itemCount = _messages.length + (_thinking ? 1 : 0);
      conversationArea = ListView.builder(
        controller: _scrollCtrl,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          // Último item artificial = estado de streaming / thinking dots
          if (i == _messages.length && _thinking) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _streaming.isNotEmpty
                  // Streaming em andamento — bolha IA parcial
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _AiBubbleAvatar(dark: dark),
                      Expanded(child: _AiBubble(
                        text: _streaming,
                        isError: false,
                        isStreaming: true,
                        dark: dark,
                        isEs: isEs,
                        onExpand: () => _goToAiTab(null, true),
                      )),
                    ])
                  // Aguardando primeira palavra — dots animados
                  : Row(children: [
                      _AiBubbleAvatar(dark: dark),
                      _ThinkingDots(dark: dark),
                    ]),
            );
          }

          final msg     = _messages[i];
          final isUser  = msg['role'] == 'user';
          final text    = msg['text'] as String;
          final isError = msg['isError'] == true;
          final isLast  = i == _messages.length - 1;

          if (isUser) {
            return Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2340),  // SUPER ORDEM 11: dark imersivo sempre
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14), topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14), bottomRight: Radius.circular(4),
                  ),
                  border: Border.all(color: _kAiBlueBord.withValues(alpha: 0.25)),
                ),
                child: Text(text,
                  style: TextStyle(fontSize: 13, color: textColor, height: 1.45)),
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _AiBubbleAvatar(dark: dark),
                Expanded(child: _AiBubble(
                  text: text,
                  isError: isError,
                  isStreaming: false,
                  dark: dark,
                  isEs: isEs,
                  // "Ver resposta completa" só no último AI bubble
                  onExpand: isLast ? () => _goToAiTab(null, true) : null,
                )),
              ]),
            );
          }
        },
      );
    } else {
      // Estado inicial — placeholder elegante com mínimo de 120px para o card
      // não ser pequeno demais quando ainda não há histórico.
      conversationArea = SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology_rounded, size: 32,
                color: _kAiBlue.withValues(alpha: 0.25)),
              const SizedBox(height: 8),
              Text(
                isEs
                    ? 'Haz tu pregunta clínica\no toca para abrir el chat completo'
                    : 'Faça sua pergunta clínica\nou toque para abrir o chat completo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: subText, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    // SUPER ORDEM 11: Dark Graphite imersivo — paridade total com AiScreen
    return Container(
      decoration: const BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        border: Border(
          top:    BorderSide(color: borderColor, width: 1.2),
          right:  BorderSide(color: borderColor, width: 1.2),
          bottom: BorderSide(color: borderColor, width: 1.2),
          left:   BorderSide(color: borderColor, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header premium: ícone + MEDCASES IA + botão fechar + expandir ──
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E2330),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2D35), width: 0.5),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(Icons.psychology_rounded, size: 15, color: Color(0xFF00E5FF)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'MEDCASES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        TextSpan(
                          text: ' IA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD4AF37),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ORDEM 34 — BOTÃO HISTÓRICO (era: fechar/limpar)
                // Sempre visível — abre histórico de sessões na aba IA.
                GestureDetector(
                  onTap: () {
                    AppHaptics.light(context);
                    // Navega para a aba IA e dispara o callback de histórico
                    // após o frame em que o AiScreen já está montado.
                    widget.onNavigateToAi(2);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      AiScreen.openHistoryCallback.value?.call();
                    });
                  },
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(Icons.history_rounded, size: 13,
                      color: Colors.white.withValues(alpha: 0.45)),
                  ),
                ),
                const SizedBox(width: 6),
                // ORDEM 34 — BOTÃO NOVO CHAT / HARD RESET (era: expandir)
                // Limpa o mini-chat local e reseta o AiScreen para novo caso.
                GestureDetector(
                  onTap: _thinking ? null : () {
                    AppHaptics.light(context);
                    // Reset local do mini-chat inline
                    setState(() {
                      _messages.clear();
                      _streaming = '';
                      _thinking  = false;
                      _sessionId = null;
                      _ctrl.clear();
                    });
                    _focus.unfocus();
                    // Propaga HARD RESET para o AiScreen (amnésia retrógrada)
                    AiScreen.clearChatCallback.value?.call();
                  },
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(Icons.add_rounded, size: 14,
                      color: Colors.white.withValues(alpha: 0.45)),
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo: conversa + input
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

          // ── Área de conversa — cresce dinamicamente com as mensagens ──────
          conversationArea,

          const SizedBox(height: 10),

          // ── Campo de entrada dark style ───────────────────────────────────
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _ctrl,
            builder: (_, val, __) {
              final isEmpty = val.text.trim().isEmpty;
              return TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: false, // CRÍTICO — nunca abrir teclado automaticamente
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                autocorrect: true,
                enableSuggestions: true,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: textColor, height: 1.5),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: isEs
                      ? 'Sintomas, fármaco, protocolo…'
                      : 'Sintomas, fármaco, protocolo…',
                  hintStyle: TextStyle(fontSize: 14, color: hintColor),
                  // Espaço à esquerda do texto / à direita antes do botão
                  contentPadding: const EdgeInsets.fromLTRB(18, 14, 6, 14),
                  // Borda arredondada estilo Gemini
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: fieldBorder, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: Color(0xFF00E5FF),  // cyan MedCases IA on focus
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: fieldBg,
                  // ── Botão embutido — círculo colorido com ícone ────────────
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: _thinking ? null : () {
                        AppHaptics.light(context);
                        _onSendPressed();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _thinking
                              ? const Color(0xFF1A2335)  // dark send disabled
                              : isEmpty
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : const Color(0xFF008CA4),  // teal MedCases IA
                        ),
                        child: _thinking
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(_kAiBlue),
                                ),
                              )
                            : Icon(
                                // Vazio → "abrir chat completo" / Cheio → enviar
                                isEmpty
                                    ? Icons.open_in_full_rounded
                                    : Icons.arrow_upward_rounded,
                                color: isEmpty
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : Colors.white,
                                size: 17,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
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
// STREAM SANITIZER (Home inline chat) — porta idêntica de ai_screen.dart
//
// Camada 1 — chamada em cada onChunk (texto acumulado parcial):
//   Remove linhas de metadados internos que o modelo às vezes vaza como
//   primeira linha antes da resposta clínica.
//   Exemplos reais:
//     "Confianza Clínica: Alta — El usuario solicita..."
//     "| Confiança Clínica: Alta — O usuário solicita..."
//     "[DATOS_VERIFICADOS_BASE_LOCAL] CONTEXTO_INTERNO [nao exibir ao usuario]"
//
// Camada 2 — _cleanHomeAiText() chamada ao montar o _AiBubble:
//   Expurga chain-of-thought, tags XML, planning interno, metadados residuais.
// ─────────────────────────────────────────────────────────────────────────────

/// CAMADA 1 — Leve, aplicada a cada chunk acumulado durante o streaming.
/// Elimina metadados de cabeçalho antes de exibir texto parcial.
String _homeStripMetadataHeaders(String accumulated) {
  if (accumulated.isEmpty) return accumulated;

  // Regex 1: catch-all bilíngue — qualquer linha com "Confian[za|ça]" + Clínica
  String result = accumulated.replaceAll(
    RegExp(
      r'^.*Confian[zç]a\s*(?:Cl[íi]nica)?.*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Regex 2: padrões complementares de abertura de linha (3ª pessoa / metadados)
  result = result.replaceAll(
    RegExp(
      r'^[|\s]*(?:'
      r'Cl[íi]nica\s*[:–—]'
      r'|Clinical\s+Confidence\s*:'
      r'|Nivel\s+de\s+Confianza\s*:'
      r'|N[íi]vel\s+de\s+Confian[çc]a\s*:'
      r'|El\s+usuario\s+(?:solicita|proporciona|pregunta|pide|quiere|busca|ha\s+(?:pedido|indicado)|solicit[oó])'
      r'|O\s+usu[aá]rio\s+(?:solicita|fornece|pergunta|pede|quer|busca|indicou|solicitou|informou|forneceu|est[aá]\s+perguntando)'
      r'|The\s+user\s+(?:is\s+asking|asks|wants|requests|provides|has\s+indicated|has\s+asked)'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|pide|quiere|ha\s+(?:pedido|indicado))'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pede|quer|solicitou)'
      r'|Para\s+proporcionar\s+una\s+respuesta'
      r'|Para\s+fornecer\s+uma\s+resposta'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?(?:no\s+)?(?:contiene|tiene|posee)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem)'
      r'|Por\s+lo\s+tanto,\s+(?:la\s+mejor|el\s+mejor)'
      r'|Portanto,\s+a\s+melhor\s+abordagem'
      r'|(?:El|La)\s+prompt\s+(?:es|parece)\s+(?:vago|incompleto|ambiguo)'
      r'|O\s+prompt\s+(?:é|parece)\s+(?:vago|incompleto|ambiguo)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé]|describir[eé])'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento|fornecerei)'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicita|que\s+(?:o|foi))'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Regex 3: tags bracket de contexto interno que o modelo vaza literalmente
  // Ex: "[DADOS_VERIFICADOS_BASE_LOCAL]", "[CONTEXTO_INTERNO]", "[nao exibir ao usuario]"
  result = result.replaceAll(
    RegExp(
      r'^\s*\[(?:DADOS?_VERIFICADOS?[^\]\n]*|DATOS?_VERIFICADOS?[^\]\n]*'
      r'|CONTEXTO_INTERNO[^\]\n]*|FIM_DADOS?[^\]\n]*|FIN_DATOS?[^\]\n]*'
      r'|nao\s+exibir[^\]\n]*|no\s+mostrar[^\]\n]*'
      r'|INTERNAL[^\]\n]*|BASE_LOCAL[^\]\n]*)\]\s*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  return result.trimLeft();
}

/// CAMADA 2 — Limpeza profunda aplicada ao texto final antes de renderizar.
/// Espelha _cleanAiText() de ai_screen.dart para resultado idêntico.
String _cleanHomeAiText(String raw) {
  String s = raw;

  // 1. Blocos XML de raciocínio (CoT tags)
  s = s.replaceAll(
    RegExp(
      r'<(thinking|scratchpad|internal|clinical_thinking|reasoning|planning|reflection|analysis|chain_of_thought|cot|thought|inner_monologue)>.*?<\/\1>',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );
  // Tags órfãs
  s = s.replaceAll(
    RegExp(
      r'<\/?(?:thinking|scratchpad|internal|clinical_thinking|reasoning|planning|reflection|analysis|chain_of_thought|cot|thought|inner_monologue)[^>]*>',
      caseSensitive: false,
    ),
    '',
  );

  // 2. Blocos de revisão interna [REVISAO_INTERNA...]
  s = s.replaceAll(
    RegExp(
      r'\[(?:REVISAO_INTERNA|REVISION_INTERNA|FIM_REVISAO_INTERNA|FIN_REVISION_INTERNA|INTERNAL_REVIEW)[^\]]*\]',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(
    RegExp(
      r'^\[(?:REVISAO|REVISION|FIM|FIN|INTERNAL|CHECKING|REVIEW)[^\]\n]*\]\s*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // 3. Tags bracket de contexto que o modelo vaza
  s = s.replaceAll(
    RegExp(
      r'^\s*\[(?:DADOS?_VERIFICADOS?[^\]\n]*|DATOS?_VERIFICADOS?[^\]\n]*'
      r'|CONTEXTO_INTERNO[^\]\n]*|FIM_DADOS?[^\]\n]*|FIN_DATOS?[^\]\n]*'
      r'|nao\s+exibir[^\]\n]*|no\s+mostrar[^\]\n]*'
      r'|INTERNAL[^\]\n]*|BASE_LOCAL[^\]\n]*)\]\s*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // 4. Prefixos de planning/CoT vazados
  s = s.replaceAll(
    RegExp(
      r"^(My response should|I will structure|I need to|Let me think|I'll organize|"
      r"I should focus|I'm going to|Para responder|Vou estruturar|Devo focar|"
      r"Mi respuesta debe|Voy a estructurar|Estructurando|Pensando en|"
      r"Analizando el caso|Analisando o caso|Antes de responder|Before responding|"
      r"Step \d+:|Paso \d+:|Etapa \d+:|Planning:|Reasoning:|Chain of thought:).*",
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // 5. Linhas de meta-comentário
  s = s.replaceAll(
    RegExp(
      r'^(Agora vou|Now I will|I will now|Vou agora|Ahora voy a|'
      r'Deixe-me|Let me|Permíteme|Deixa eu pensar|'
      r'Thinking\.\.\.|Analyzing\.\.\.|Processing\.\.\.).*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // 5b. PURGA PROFUNDA — Monólogo em 3ª pessoa (espelho de ai_screen.dart 4c)
  // Padrão PT — linhas inteiras com meta-raciocínio em 3ª pessoa
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'O\s+usu[aá]rio\s+(?:solicitou|pediu|informou|forneceu|indicou|est[aá])'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pediu|quer|solicitou)'
      r'|Para\s+fornecer\s+uma\s+resposta\s+(?:[uú]til|adequada|completa)'
      r'|Para\s+(?:poder\s+)?(?:dar|fornecer|oferecer)\s+(?:uma\s+)?(?:resposta|conduta|informa)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem|encontrou)'
      r'|Portanto,?\s+a\s+melhor\s+(?:abordagem|estrategia|opcao)'
      r'|O\s+prompt\s+(?:[eé]|parece|est[aá])\s+(?:muito\s+)?(?:vago|incompleto|ambiguo|curto|insuficiente)'
      r'|N[aã]o\s+(?:encontrei|tenho|possuo)\s+(?:dados|informacoes|contexto)\s+suficientes'
      r'|Precisaria\s+de\s+mais\s+(?:informacoes|dados|contexto|detalhes)'
      r'|Com\s+base\s+no\s+que\s+o\s+usu[aá]rio'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicitacao|que\s+foi)'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento|fornecerei)'
      r'|O\s+(?:pedido|contexto|prompt|input)\s+(?:[eé]|est[aá]|foi|parece)'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // Padrão ES — equivalente espanhol
  s = s.replaceAll(
    RegExp(
      r'^(?:'
      r'El\s+usuario\s+(?:solicit[oó]|pidi[oó]|indic[oó]|ha\s+(?:pedido|indicado|solicitado))'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|ha\s+pedido|quiere)'
      r'|Para\s+proporcionar\s+una\s+respuesta\s+(?:[uú]til|adecuada|completa)'
      r'|Para\s+(?:poder\s+)?(?:dar|proporcionar|ofrecer)\s+(?:una\s+)?(?:respuesta|conducta|informa)'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?no\s+(?:contiene|tiene|posee|encontr[oó])'
      r'|Por\s+lo\s+tanto,?\s+la\s+mejor\s+(?:estrategia|opci[oó]n|abordaje|aproximaci[oó]n)'
      r'|El\s+prompt\s+(?:es|parece|est[aá])\s+(?:muy\s+)?(?:vago|incompleto|ambiguo|corto|insuficiente)'
      r'|No\s+(?:encontr[eé]|tengo|poseo)\s+(?:datos|informaci[oó]n|contexto)\s+suficientes?'
      r'|Necesitar[ií]a\s+(?:m[aá]s\s+)?(?:informaci[oó]n|datos|contexto|detalles)'
      r'|Con\s+base\s+en\s+(?:lo\s+que\s+el\s+usuario|la\s+solicitud)'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé]|describir[eé]|proporcionar[eé])'
      r'|La\s+(?:pregunta|solicitud|consulta|query)\s+(?:es|parece|est[aá]|resulta)'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // 6. Catch-all Confianza/Confiança Clínica (CAMADA 2)
  s = s.replaceAll(
    RegExp(
      r'^.*Confian[zç]a\s*(?:Cl[íi]nica)?.*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );
  s = s.replaceAll(
    RegExp(
      r'^[|\s]*(?:'
      r'Confianza\s*[:–—]'
      r'|Confiança\s*[:–—]'
      r'|Clinical\s+Confidence\s*:'
      r'|Nivel\s+de\s+Confianza\s*:'
      r'|N[íi]vel\s+de\s+Confian[çc]a\s*:'
      r'|El\s+usuario\s+(?:solicita|proporciona|pregunta|pide|quiere|busca|ha\s+(?:indicado|pedido)|solicit[oó])'
      r'|O\s+usu[aá]rio\s+(?:solicita|fornece|pergunta|pede|quer|busca|indicou|solicitou|informou|est[aá]\s+perguntando)'
      r'|The\s+user\s+(?:is\s+asking|asks|wants|requests|provides|has\s+indicated|has\s+asked)'
      r'|El\s+usuario\s+ha\s+pedido'
      r'|El\s+m[eé]dico\s+(?:solicita|pregunta|pide|ha\s+pedido)'
      r'|O\s+m[eé]dico\s+(?:solicita|pergunta|pede|solicitou)'
      r'|Baseado\s+(?:no|na|em)\s+(?:contexto|conversa|solicita|que\s+(?:o|foi))'
      r'|Basado\s+en\s+(?:el\s+contexto|la\s+conversaci[oó]n|la\s+solicitud|lo\s+que)'
      r'|Para\s+proporcionar\s+una\s+respuesta'
      r'|Para\s+fornecer\s+uma\s+resposta'
      r'|La\s+base\s+de\s+datos\s+(?:local\s+)?no\s+(?:contiene|tiene|posee)'
      r'|A\s+base\s+de\s+dados\s+(?:local\s+)?n[aã]o\s+(?:possui|cont[eé]m|tem)'
      r'|Por\s+lo\s+tanto,\s+(?:la\s+mejor|el\s+mejor)'
      r'|Portanto,\s+a\s+melhor\s+abordagem'
      r'|(?:El|La)\s+prompt\s+(?:es|parece)\s+(?:vago|incompleto)'
      r'|O\s+prompt\s+(?:é|parece)\s+(?:vago|incompleto)'
      r'|A\s+seguir\s+(?:apresentarei|descrevo|apresento)'
      r'|A\s+continuaci[oó]n\s+(?:presento|presentar[eé])'
      r').*$',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );

  // 7. Sanitização final de formatação
  s = s
      .replaceAll(RegExp(r'^#{1,3}\s*', multiLine: true), '') // ## ### → plain
      .replaceAll('---', '')
      .replaceAll('--', '')
      .replaceAll(RegExp(r'\*{3,}'), ''); // *** ou mais → remove

  // 8. Normaliza linhas em branco excessivas
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return s.trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDEM 13: Helpers inline _homeIsListItem / _homeStripBulletPrefix /
//   _homeInlineSpans / _homeBuildLine removidos — substituídos por MarkdownBody.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS INTERNOS — bolha de resposta IA + avatar
// ─────────────────────────────────────────────────────────────────────────────
class _AiBubbleAvatar extends StatelessWidget {
  final bool dark;
  const _AiBubbleAvatar({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      margin: const EdgeInsets.only(right: 8, top: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dark ? const Color(0xFF162A1C) : const Color(0xFFE6F7EF),
      ),
      child: Center(
        child: Icon(
          Icons.psychology_alt_rounded,
          size: 14,
          color: dark ? const Color(0xFF00E5FF) : const Color(0xFF0A7C4E),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDEM 13: Sanitizador de markdown parcial para streaming (home mini-chat).
// Idêntico ao _sanitizePartialMarkdown do ai_screen.dart, portado aqui para
// garantir que tokens incompletos (**sem fechar) não apareçam como asteriscos
// crús na UI enquanto o stream ainda está chegando.
// ─────────────────────────────────────────────────────────────────────────────
String _homeCleanPartialMd(String text) {
  if (text.isEmpty) return text;
  final lines   = text.split('\n');
  final lastIdx = lines.length - 1;
  String last   = lines[lastIdx];

  // Retira o cursor ▌ temporariamente para analisar conteúdo real
  final hasCursor = last.endsWith('\u258c');
  if (hasCursor) last = last.substring(0, last.length - 1);

  final trimmedLast = last.trimLeft();

  // Marcador de lista sozinho sem texto → suprime para não gerar bullet vazio
  if (RegExp(r'^[\*\-•]\s*$').hasMatch(trimmedLast)) {
    last = '';
  }
  // Cabeçalho markdown vazio ("## " ou "### " sem título ainda)
  else if (RegExp(r'^#{1,3}\s*$').hasMatch(trimmedLast)) {
    last = '';
  }
  // Negrito não fechado: conta pares de "**" — se ímpar, fecha provisoriamente
  // para que o MarkdownBody não renderize os asteriscos crús.
  else {
    final pairs = RegExp(r'\*\*').allMatches(last).length;
    if (pairs.isOdd) {
      last = '$last**';
    }
  }

  if (hasCursor) last = '$last\u258c';
  lines[lastIdx] = last;
  return lines.join('\n');
}

// ─────────────────────────────────────────────────────────────────────────────
// _AiBubble — ORDEM 13: renderizador migrado para MarkdownBody (flutter_markdown)
//
// Antes: parser linha a linha (_homeBuildLine / _homeInlineSpans) — asteriscos
//   crús apareciam durante streaming quando ** não estava fechado.
// Agora: MarkdownBody com stylesheet idêntico ao ai_screen.dart — negrito real,
//   listas nativas, h2/h3 com cor vibrante, sem asteriscos visíveis.
//
// Streaming safety: _homeCleanPartialMd() fecha ** ímpares antes de passar
//   para o MarkdownBody — elimina artefatos de tokens incompletos.
// ─────────────────────────────────────────────────────────────────────────────
class _AiBubble extends StatelessWidget {
  final String text;
  final bool isError;
  final bool isStreaming;
  final bool dark;
  final bool isEs;
  final VoidCallback? onExpand;

  const _AiBubble({
    required this.text,
    required this.isError,
    required this.isStreaming,
    required this.dark,
    required this.isEs,
    this.onExpand,
  });

  static const _kGreen     = Color(0xFF0D7A55);
  static const _kCyan      = Color(0xFF00E5FF);
  static const _kTeal      = Color(0xFF008CA4);
  static const _kFerrari   = Color(0xFFFF2400);

  @override
  Widget build(BuildContext context) {
    final bubbleBg = dark ? const Color(0xFF161616) : const Color(0xFFF9F9F9);
    final bubbleBorder = isError
        ? Colors.red.withValues(alpha: 0.3)
        : (dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0));
    final textCol = isError
        ? Colors.red.shade400
        : (dark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1A202C));

    // CAMADA 2 (render-time) — limpa metadados, CoT e tags internas.
    // Para streaming: também aplica sanitização de markdown parcial.
    String displayText = isError ? text : _cleanHomeAiText(text);
    if (isStreaming && !isError) {
      displayText = _homeCleanPartialMd(displayText);
    }
    // Remove cursor ▌ do texto antes de passar ao MarkdownBody
    final mdText = displayText.replaceAll('\u258c', '');

    // ── MarkdownBody com stylesheet clínico premium ──────────────────────────
    Widget buildBody() {
      if (isError) {
        return Text(
          mdText,
          style: TextStyle(fontSize: 13, color: textCol, height: 1.5),
        );
      }

      // Limite de linhas durante streaming para performance
      // (garante que MarkdownBody não re-layout todo o texto a cada chunk)
      final String renderText;
      if (isStreaming) {
        final lines = mdText.split('\n');
        renderText = lines.length > 22
            ? lines.sublist(0, 22).join('\n')
            : mdText;
      } else {
        renderText = mdText;
      }

      return MarkdownBody(
        data: renderText,
        selectable: false,
        softLineBreak: true,
        styleSheet: MarkdownStyleSheet(
          // Parágrafo base: mesma fonte, espaçamento respiro
          p: TextStyle(
            fontSize: 13.5,
            color: textCol,
            height: 1.55,
          ),
          // Negrito (**...***) — cor vibrante exclusiva para fármacos e condutas
          // Dark: cyan médico / Light: vermelho Ferrari (contraste ≥ 5:1)
          strong: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: dark ? _kCyan : _kFerrari,
          ),
          // Itálico: neutro — sem destaque de cor
          em: TextStyle(
            fontSize: 13.5,
            color: textCol,
            fontStyle: FontStyle.italic,
          ),
          // Marcadores de lista — cor discreta, indentação precisa
          listBullet: TextStyle(
            fontSize: 13.5,
            color: dark ? _kCyan.withValues(alpha: 0.70) : _kTeal,
          ),
          // Títulos — h2 Vermelho Ferrari negrito, h3 cyan/teal
          h2: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: dark ? _kCyan : _kFerrari,
            letterSpacing: 0.1,
            height: 1.3,
          ),
          h3: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: dark ? _kCyan : _kTeal,
            height: 1.3,
          ),
          // Blocos de código — fundo transparente (sem caixas brancas)
          codeblockDecoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          blockquote: TextStyle(
            fontSize: 13,
            color: textCol.withValues(alpha: 0.78),
          ),
          blockquoteDecoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              left: BorderSide(
                color: dark ? Colors.white24 : Colors.black26,
                width: 3,
              ),
            ),
          ),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: dark ? Colors.white12 : Colors.black12,
                width: 1,
              ),
            ),
          ),
          blockSpacing: 5,
          listIndent: 16,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bubbleBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4), topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14),
        ),
        border: Border.all(color: bubbleBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        buildBody(),
        // "Ver respuesta completa" / "Ver resposta completa" — só quando fornecido
        if (!isStreaming && !isError && onExpand != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onExpand,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                isEs ? 'Ver respuesta completa' : 'Ver resposta completa',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kGreen,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.arrow_forward_rounded, size: 11, color: _kTeal),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THINKING DOTS — animação de "pensando" para o inline chat da Home
// ─────────────────────────────────────────────────────────────────────────────
class _ThinkingDots extends StatefulWidget {
  final bool dark;
  const _ThinkingDots({required this.dark});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.dark ? const Color(0xFF00E5FF) : const Color(0xFF008CA4);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay   = i / 3.0;
          final t       = (_ctrl.value - delay).clamp(0.0, 1.0);
          final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.only(right: 4),
            width: 7, height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor.withValues(alpha: opacity)),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME V2 — IA MEDCASES CARD (item 1 da Home) — LEGADO, mantido para web
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
  // BUILD 93 — chips educacionais (Apple 1.4.1: sem referência a Simulações/doses/emergências)
  static const _chipsEs = ['Caso clínico', 'Diagnóstico dif.', 'Farmacología', 'Razonamiento', 'Educación'];
  static const _chipsPt = ['Caso clínico', 'Diagnóstico dif.', 'Farmacologia', 'Raciocínio', 'Educação'];

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

    final cardBg = dark ? const Color(0xFF252930) : Colors.white;
    final borderColor = dark
        ? _kGreenBord.withValues(alpha: 0.35)
        : _kGreenBord.withValues(alpha: 0.22);
    final fieldBg = dark
        ? const Color(0xFF162A1C)
        : const Color(0xFFF4FAF7);
    final fieldBorder = dark
        ? _kGreenBord.withValues(alpha: 0.22)
        : _kGreenBord.withValues(alpha: 0.18);
    final textColor = dark ? Colors.white : const Color(0xFF0F1116);
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
        ? const Color(0xFF10B981)
        : _kGreen;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: const Color(0xFF252930).withValues(alpha: 0.55),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.06),
                  blurRadius: 28,
                  offset: const Offset(0, 0),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF008CA4).withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10, bottom: -10,
            child: Opacity(
              opacity: 0.045,
              child: const Icon(
                Icons.psychology_alt_rounded,
                size: 110,
                color: Color(0xFF00E5FF),
              ),
            ),
          ),
          Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header: logo ConnectMind + título + badge IA ──────────────────
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF252930), Color(0xFF252930), Color(0xFF374151)],
                  ),
                  border: Border.all(
                    color: Color(0xFF00E5FF).withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.psychology_alt_rounded,
                    size: 21, color: Color(0xFF00E5FF)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'MedCases IA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: dark ? const Color(0xFF00E5FF) : const Color(0xFF252930),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF008CA4), Color(0xFF252930)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'IA',
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
                          ? 'Conexión Cognitiva Avanzada'
                          : 'Conexão Cognitiva Avançada',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: dark
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.60)
                            : const Color(0xFF008CA4),
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
                        keyboardType: TextInputType.multiline,
                        autocorrect: true,
                        enableSuggestions: true,
                        textCapitalization: TextCapitalization.sentences,
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
                  onTap: () { AppHaptics.light(context); _navigate(); },
                  child: Container(
                    width: 38, height: 38,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark
                          ? const Color(0xFF252930)
                          : const Color(0xFFE0F7FA),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: dark ? 0.45 : 0.50),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Color(0xFF008CA4),
                      size: 18,
                    ),
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
                  onTap: () { AppHaptics.selection(context); _navigate(chip); },
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
        ],
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
      // B141: Emerald Green — #059669 → #10b981
      Expanded(child: _AgeCard(
        icon: Icons.person_rounded,
        // chore(home): renomeado ADULTO → PACIENTE (BUILD 238 PARTE 6)
        label: 'PACIENTE',
        subtitle: 'Explorar caso clínico',
        gradientColors: const [Color(0xFF022c22), Color(0xFF059669), Color(0xFF10b981)],
        accentColor: const Color(0xFF6ee7b7),
        dark: dark,
        onTap: onTapAdulto,
      )),
      const SizedBox(width: 12),  // ORDEM 43: 10→12 gap horizontal cards
      // B144: Azul Petróleo — dark teal elegante, nunca chega ao ciano
      Expanded(child: _AgeCard(
        icon: Icons.child_care_rounded,
        label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
        subtitle: isEs ? 'Casos clínicos de referencia' : 'Casos clínicos de referência',
        gradientColors: const [Color(0xFF042f2e), Color(0xFF0f766e), Color(0xFF134e4a)],
        accentColor: const Color(0xFFccfbf1),
        dark: dark,
        onTap: onTapPediatria,
      )),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HOME V2 — CALCULADORA (card full-width premium)
// Build 102: novo acesso direto à CalculadorasShell (ToolsScreen encapsulada)
// ═══════════════════════════════════════════════════════════════════════════════
class _HomeCalculadoraCard extends StatefulWidget {
  final bool dark;
  final bool isEs;
  const _HomeCalculadoraCard({required this.dark, required this.isEs});
  @override
  State<_HomeCalculadoraCard> createState() => _HomeCalculadoraCardState();
}

class _HomeCalculadoraCardState extends State<_HomeCalculadoraCard>
    with SingleTickerProviderStateMixin {
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

  void _handleTap() {
    AppHaptics.light(context);
    // PR #73: abre CalculadoraScreen (WebView → promedcases.com + User-Agent MedCasesApp/6.1.0)
    // rootNavigator: true → coloca a tela ACIMA do shell (bottom nav bar).
    // Sem isso, o Navigator do shell impõe constraints de altura reduzida
    // e deixa uma faixa escura abaixo da WebView.
    Navigator.of(context, rootNavigator: true).push(
      _HomeScreenState._slide(const CalculadoraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gradientColors = [
      Color(0xFF1A0F2E),
      Color(0xFF2D1B5A),
      Color(0xFF4A2D8A),
    ];
    const accentColor = Color(0xFFA78BFA);

    return GestureDetector(
      onTapDown:   (_) { _ctrl.forward(); AppHaptics.light(context); },
      onTapUp:     (_) { _ctrl.reverse(); _handleTap(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(children: [
            // ── Ícone ──────────────────────────────────────────────────────
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.calculate_rounded,
                  size: 26, color: accentColor),
            ),
            const SizedBox(width: 16),
            // ── Texto ──────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.isEs ? 'CALCULADORA CLÍNICA' : 'CALCULADORA CLÍNICA',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isEs
                        ? 'Cálculos y Fórmulas de Referencia'
                        : 'Scores · Cardio · Eletrólitos · Referência',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: accentColor.withValues(alpha: 0.85),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // ── Chevron ────────────────────────────────────────────────────
            Icon(Icons.chevron_right_rounded,
                size: 26, color: accentColor.withValues(alpha: 0.70)),
          ]),
        ),
      ),
    );
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
      onTapDown:    (_) { _ctrl.forward(); AppHaptics.light(context); },
      onTapUp:      (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel:  ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 92,  // ORDEM 43: +10% altura premium (84×1.10=92.4→92)
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: g,
            ),
            borderRadius: BorderRadius.circular(16),  // ORDEM 12: radius slim (era 18)
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),  // ORDEM 12: slim
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, size: 22, color: widget.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        // B144: sempre branco puro para máximo contraste
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUILD 138 — CALCULADORA E FÁRMACOS (Linha 1 — card unificado full-width)
// Substitui os antigos cards independentes de FÁRMACOS e CALCULADORA.
// Gradiente purple-royal com acesso direto a CalculadoraScreen.
// Sub-chip de FÁRMACOS permite acesso rápido a _FarmacosShell.
// ═══════════════════════════════════════════════════════════════════════════════
class _HomeCalculadoraFarmacosCard extends StatefulWidget {
  final bool dark;
  final bool isEs;
  const _HomeCalculadoraFarmacosCard({required this.dark, required this.isEs});
  @override
  State<_HomeCalculadoraFarmacosCard> createState() => _HomeCalculadoraFarmacosCardState();
}

class _HomeCalculadoraFarmacosCardState extends State<_HomeCalculadoraFarmacosCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _openCalc() {
    AppHaptics.light(context);
    Navigator.of(context, rootNavigator: true).push(
      _HomeScreenState._slide(const CalculadoraScreen()),
    );
  }

  void _openFarmacos() {
    AppHaptics.light(context);
    Navigator.of(context).push(
      _HomeScreenState._slide(const _FarmacosShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // B141: Vibrant Purple — #7e22ce → #a855f7
    const gradientColors = [Color(0xFF3B0764), Color(0xFF7e22ce), Color(0xFFa855f7)];
    const accentColor = Color(0xFFe9d5ff);

    return GestureDetector(
      onTapDown:   (_) { _ctrl.forward(); AppHaptics.light(context); },
      onTapUp:     (_) { _ctrl.reverse(); _openCalc(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),  // ORDEM 43: 14→16 (+14% impacto visual ≈ 108%)
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),  // ORDEM 12: radius slim
          ),
          // B139: sub-chip FÁRMACOS removido — card limpo com apenas a linha principal
          child: Row(children: [
            Container(
              width: 48, height: 48,  // ORDEM 12: ícone slim (era 52)
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.calculate_rounded, size: 26, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.isEs ? 'CALCULADORA Y FÁRMACOS' : 'CALCULADORA E FÁRMACOS',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.isEs
                        ? 'Cálculos · Fórmulas · Fármacos'
                        : 'Cálculos · Fórmulas · Fármacos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.80),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 24, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUILD 138 — BIBLIOTECA + H. CLÍNICA (Linha 3 — dois cards paralelos)
// Biblioteca → tab 5 (LibraryScreen) / H. Clínica → tab 3 (HistoryScreen)
// ═══════════════════════════════════════════════════════════════════════════════
class _HomeBibliotecaHClinicaRow extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final Function(int) onTabChange;

  const _HomeBibliotecaHClinicaRow({
    required this.dark,
    required this.isEs,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // ── BIBLIOTECA — B141: Elegant Gray #475569 → #64748b ───────────────
      Expanded(child: _AgeCard(
        icon: Icons.menu_book_rounded,
        label: 'BIBLIOTECA',
        subtitle: isEs ? 'Referencias clínicas' : 'Referências clínicas',
        gradientColors: const [Color(0xFF1e293b), Color(0xFF475569), Color(0xFF64748b)],
        accentColor: const Color(0xFFe2e8f0),
        dark: dark,
        onTap: () => onTabChange(5),
      )),
      const SizedBox(width: 12),  // ORDEM 43: 10→12 gap horizontal cards
      // ── H. CLÍNICA — B141: Orange Vibrant #ea580c → #fb923c ─────────────
      Expanded(child: _AgeCard(
        icon: Icons.assignment_ind_outlined,
        label: 'H. CLÍNICA',
        subtitle: isEs ? 'Historial del paciente' : 'Histórico do paciente',
        gradientColors: const [Color(0xFF431407), Color(0xFFea580c), Color(0xFFfb923c)],
        accentColor: const Color(0xFFfed7aa),
        dark: dark,
        onTap: () => onTabChange(3),
      )),
    ]);
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
  // Build 195: passa PacienteSession para pr\u00e9-carregar ao navegar para InternacionScreen
  final void Function(PacienteSession session)? onOpenInternacion;

  const _HomeMiGuardiaSection({
    required this.dark,
    required this.isEs,
    required this.onOpenDrug,
    required this.onOpenCalc,
    required this.onManageTap,
    this.onOpenInternacion,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = dark ? const Color(0xFF252930) : Colors.white;
    // Acento dourado na borda esquerda para sinalizar "item especial"
    final leftAccent = dark ? const Color(0xFFC5A365) : const Color(0xFFB8954E);
    final border = dark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE4EEE9);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 3, color: leftAccent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: MeuPlantaoDashboard(
                  onOpenDrug:  onOpenDrug,
                  onOpenCalc:  onOpenCalc,
                  onManageTap: onManageTap,
                  onOpenInternacion: onOpenInternacion,
                ),
              ),
            ),
          ],
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
// HOME SECTION HEADER — título de seção com ícone e linha decorativa
// Usado em: HISTORIAL CLÍNICO (bloco 3 do mobile layout Build 93)
// ─────────────────────────────────────────────────────────────────────────────
class _HomeSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;

  const _HomeSectionHeader({
    required this.icon,
    required this.label,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor  = dark ? const Color(0xFF10B981) : const Color(0xFF0A7C4E);
    final textColor  = dark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF374151);
    final lineColor  = dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);

    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: iconColor.withValues(alpha: 0.12),
        ),
        child: Icon(icon, size: 15, color: iconColor),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: textColor,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(height: 1, color: lineColor),
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
      onTapDown:   (_) { _ctrl.forward(); AppHaptics.light(context); },
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
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

    final bg     = dark ? const Color(0xFF2D3340) : const Color(0xFFECFDF5);
    final border = dark
        ? const Color(0xFF10B981).withValues(alpha: 0.35)
        : const Color(0xFF10B981).withValues(alpha: 0.25);
    final accent = const Color(0xFF10B981);
    final textC  = dark ? Colors.white : const Color(0xFF1A1D23);
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
              color: _active ? const Color(0xFF10B981) : accent,
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
    final bg    = dark ? const Color(0xFF1A1D23) : Colors.white;
    final textC = dark ? Colors.white : const Color(0xFF1A1D23);
    final subC  = dark ? Colors.white38 : Colors.black38;
    final divC  = dark ? Colors.white10 : const Color(0xFFEEEEEE);
    final accent = const Color(0xFF10B981);
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
                  color: sel ? accent : (dark ? const Color(0xFF252930) : const Color(0xFFF3F4F6)),
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
            Text(isEs ? 'Horas' : 'Horas', // igual nos dois idiomas
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
            Text(isEs ? 'Minutos' : 'Minutos', // igual nos dois idiomas
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
            color: dark ? const Color(0xFF252930) : const Color(0xFFF5F7FA),
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
              isEs ? 'Iniciar timer' : 'Iniciar timer', // igual nos dois idiomas
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
// HISTORIAL COMPACTO — card horizontal único, meia-altura, largura total
// Build 95: substitui _HomeSectionHeader + _QuickShortcuts por card integrado
// ─────────────────────────────────────────────────────────────────────────────
class _HistorialCompactCard extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final Function(String) openProtocol;
  final VoidCallback onOpenNotes;
  final VoidCallback? onCheckUpdate;

  const _HistorialCompactCard({
    required this.dark,
    required this.isEs,
    required this.openProtocol,
    required this.onOpenNotes,
    this.onCheckUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg      = dark ? const Color(0xFF1A1D23) : Colors.white;
    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8ECF5);
    final labelColor  = dark
        ? Colors.white.withValues(alpha: 0.38)
        : const Color(0xFF9CA3AF);
    final dividerColor = dark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFECEFF7);
    final shadow = dark
        ? <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ];

    // BUILD 283 ORDEM 9: 5 colunas simétricas — Avaliação|Notas|Buscar|Favoritos|Recentes
    // Buscar integrado como coluna uniforme (sem container destacado), dividers 1px entre todas.
    final kGreen = dark ? const Color(0xFF10B981) : const Color(0xFF0A7C4E);

    // Helpers para construir cada coluna de forma idêntica
    Widget _col({
      required IconData icon,
      required Color color,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: () { AppHaptics.selection(context); onTap(); },
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: dark
                      ? Colors.white.withValues(alpha: 0.55)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _div() => Container(width: 1, height: 34, color: dividerColor);

    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cardBg,
        boxShadow: shadow,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // [1] EVALUACIÓN — vermelho #DC2626
          _col(
            icon: Icons.assignment_ind_rounded,
            color: const Color(0xFFDC2626),
            label: isEs ? 'Evaluación' : 'Avaliação',
            onTap: () => HomeScreen._openAvaliacao(context),
          ),
          _div(),
          // [2] NOTAS — laranja #FF8A00
          _col(
            icon: Icons.sticky_note_2_rounded,
            color: const Color(0xFFFF8A00),
            label: isEs ? 'Notas' : 'Notas',
            onTap: onOpenNotes,
          ),
          _div(),
          // [3] BUSCAR — verde (posição central, coluna uniforme)
          _col(
            icon: Icons.search_rounded,
            color: kGreen,
            label: isEs ? 'Buscar' : 'Buscar',
            onTap: () { AppHaptics.light(context); showGlobalSearch(context); },
          ),
          _div(),
          // [4] FAVORITOS — roxo #6C2BD9
          _col(
            icon: Icons.bookmark_rounded,
            color: const Color(0xFF6C2BD9),
            label: isEs ? 'Favoritos' : 'Favoritos',
            onTap: () {
              final p = context.read<AppProvider>();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _FavoritosSheet(dark: dark, isEs: isEs, p: p),
              );
            },
          ),
          _div(),
          // [5] RECIENTES — azul #1F78FF
          _col(
            icon: Icons.history_rounded,
            color: const Color(0xFF1F78FF),
            label: isEs ? 'Recientes' : 'Recentes',
            onTap: () {
              final p = context.read<AppProvider>();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _RecentesSheet(dark: dark, isEs: isEs, p: p),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK SHORTCUTS — Notas · Recentes · Favoritos (web desktop column)
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
    final cardBg = dark ? const Color(0xFF252930) : Colors.white;
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
        label: isEs ? 'Notas' : 'Notas', // igual nos dois idiomas
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
        label: isEs ? 'Favoritos' : 'Favoritos', // igual nos dois idiomas
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
              onTap: () { AppHaptics.selection(context); item.onTap(); },
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
    final sheetBg = dark ? const Color(0xFF1A1D23) : Colors.white;
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
                              AppHaptics.selection(context);
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
    final sheetBg = dark ? const Color(0xFF1A1D23) : Colors.white;
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
                isEs ? 'Favoritos' : 'Favoritos', // igual nos dois idiomas
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

                      // BUILD 93 — Prescrições/Simulações favoritas OCULTAS (Apple 1.4.1)
                      // Reativar com In-App Browser após aprovação da Apple.
                      // Código 100% preservado — apenas removido da árvore de widgets.
                      // if (favPrescs.isNotEmpty) ...[
                      //   Padding(...)  → label 'SIMULACIONES'
                      //   ...favPrescs.map(...)  → ListTile → _PrescripcionesShell
                      // ],

                      // Protocolos favoritos
                      if (favProtos.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            isEs ? 'PROTOCOLOS' : 'PROTOCOLOS', // técnico
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
                                  isEs ? 'Protocolo clínico' : 'Protocolo clínico', // igual
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
                            isEs ? 'CASOS CLÍNICOS' : 'CASOS CLÍNICOS', // igual
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
// ORDEM 12: _HomeAiNavigatorCard REMOVIDO (BUILD 278 → deprecated)
// Motivo: card duplicado de acesso à IA — risco Apple Guideline 1.4.1.
// O mini-chat _HomeInlineChat já fornece acesso completo ao assistente IA.
// ─────────────────────────────────────────────────────────────────────────────

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
      onTapDown:    (_) { _ctrl.forward(); AppHaptics.light(context); },
      onTapUp:      (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel:  ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 101,  // ORDEM 43: 92→101 (+10% proporção premium)
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
                color: widget.gradientColors.last.withValues(alpha: 0.40),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.20),
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              // Ícone
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.accentColor.withValues(alpha: 0.15),
                ),
                child: Icon(
                  widget.icon,
                  size: 22,
                  color: widget.accentColor,
                ),
              ),
              const SizedBox(width: 12),

              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // FittedBox garante que textos longos nunca quebrem
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          // Build 138: dark mode → branco puro para máximo contraste
                          color: widget.dark ? Colors.white : widget.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        // Build 138: dark mode → branco puro para máximo contraste
                        color: widget.dark
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.70),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Seta
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: widget.accentColor.withValues(alpha: 0.65),
              ),
            ]),
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
                        ? (isEs ? 'menos' : 'menos') // igual nos dois idiomas
                        : (isEs ? 'ver +' : 'ver +'), // igual nos dois idiomas
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

          // ── Grid 4 colunas ────────────────────────────────────────────
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.10,
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
  // BUILD 282 ORDEM 4: showIcon=false oculta o card-ícone lateral
  // (usado na Pediatria para seguir o design canônico sem ícone no header).
  final bool showIcon;

  const _ShellHeader({
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
    required this.label,
    required this.subtitle,
    this.showIcon = true,
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
                // BUILD 282 ORDEM 2/3: arrow_back_ios_new (canônico, size:20)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      size: 20, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                // BUILD 282 ORDEM 4: ícone condicional (showIcon=false na Pediatria)
                if (showIcon) ...[
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
                ],
                // Textos — BUILD 282: tipografia canônica (w700/20px, ouro fosco)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD4AF37), // ouro fosco canônico
                          letterSpacing: 1.2,
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
      backgroundColor: dark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF),
      body: Column(children: [
        // BUILD 282 ORDEM 4: header sem ícone lateral, subtitle = MEDCASES PRO
        // Gradiente verde esmeralda topLeft→bottomRight (sincronizado com pill bar)
        _ShellHeader(
          gradientColors: const [Color(0xFF042F2E), Color(0xFF0F766E), Color(0xFF134E4A)],
          accentColor:    const Color(0xFFCCFBF1),
          icon:    Icons.child_care_rounded, // mantido para futura reativação
          label:   isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
          subtitle: 'MEDCASES PRO', // BUILD 282: assinatura canônica ouro fosco
          showIcon: false,          // BUILD 282 ORDEM 4: ícone removido da árvore
        ),
        const Expanded(child: PediatricsTabContent()),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADULTO SHELL
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Build 159 — _AdultoShell pivotado para InternacionScreen
// Substitui CockpitScreen (emergência) pelo motor SOAP de internação.
// O Scaffold agora é gerenciado internamente pelo InternacionScreen
// (AppBar próprio com título "INTERNACIÓN Y EVOLUCIÓN").
// ─────────────────────────────────────────────────────────────────────────────
class _AdultoShell extends StatelessWidget {
  // openProtocol mantido para compatibilidade com assinatura existente
  final Function(String) openProtocol;
  // Build 195: sessão pré-selecionada ao abrir via card Mi Guardia
  final PacienteSession? initialSession;

  const _AdultoShell({
    required this.openProtocol,
    this.initialSession,
  });

  @override
  Widget build(BuildContext context) {
    // InternacionScreen tem seu próprio Scaffold + AppBar
    return InternacionScreen(initialSession: initialSession);
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
      backgroundColor: dark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF),
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
    final bg = dark ? const Color(0xFF252930) : const Color(0xFFEEEEEE);
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
      backgroundColor: dark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF),
      body: Column(children: [
        // BUILD 282-CROMATICO: Gradiente idêntico ao card da Home (topLeft→bottomRight)
        // 3B0764→7E22CE→A855F7 — mesmo cromatismo, continuidade visual perfeita.
        _ShellHeader(
          gradientColors: const [Color(0xFF3B0764), Color(0xFF7E22CE), Color(0xFFA855F7)],
          accentColor:    const Color(0xFFE9D5FF), // lilás claro — consistente com home card
          icon:    Icons.calculate_rounded,
          label:   'CALCULADORA CLÍNICA',
          subtitle: isEs
              ? 'Scores · Cardio · Electrolitos · Referencia'
              : 'Scores · Cardio · Eletrólitos · Referência',
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
      backgroundColor: dark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF),
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
          subtitle: isEs ? 'Protocolo clínico' : 'Protocolo clínico', // igual
          data:     proto,
        ));
        protoCount++;
      }
    }

    // ── 3. Prescrições ─────────────────────────────────────────────────────
    // BUILD 93 — Prescrições/Simulações OCULTADAS (Apple 1.4.1)
    // Reativar com In-App Browser após aprovação da Apple.
    // int prescCount = 0;
    // for (final presc in prescriptionModels(isEs)) { ... }

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
        // BUILD 93 — OCULTADO (Apple 1.4.1). Reativar após aprovação.
        // Navigator.of(context).push(
        //   MaterialPageRoute(builder: (_) => const _PrescripcionesShell()),
        // );
        break;
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
                            ? 'Fármacos, protocolos, casos clínicos...'
                            : 'Fármacos, protocolos, casos clínicos...',
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
                    color: const Color(0xFF10B981), dark: dark),
                const SizedBox(width: 6),
                // BUILD 93 — chip 'Simulaciones/Simulações' ocultado (Apple 1.4.1)
                // Reativar após aprovação com In-App Browser
                // _CatChip(label: isEs ? 'Simulaciones' : 'Simulações',
                //     color: const Color(0xFFA78BFA), dark: dark),
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
    _SearchCat.protocol     => const Color(0xFF10B981),
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
