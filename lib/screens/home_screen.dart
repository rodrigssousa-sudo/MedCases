import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../data/drugs_database.dart';
import '../models/drug_model.dart';
import '../services/drug_interaction_service.dart';
import 'cockpit_screen.dart';
import 'drugs_screen.dart' show DrugsScreen, showDrugDetailSheet;
import 'prescripciones_screen.dart' show PrescripcionesScreen, prescriptionModels;
import 'tools_screen.dart' show PediatricsTabContent, ToolsScreen;
import 'prescripciones_screen.dart';
import 'drug_interactions_screen.dart';
import 'protocols_screen.dart' show openProtocolById, showProtocolDetail;

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN — 4 cards de navegação principal
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Barra de pesquisa ─────────────────────────────────────────────
        _HomeSearchBar(dark: dark, isEs: isEs),
        const SizedBox(height: 18),

        // ── Divisor ───────────────────────────────────────────────────────
        _HomeDivider(dark: dark),
        const SizedBox(height: 16),

        // 1 — Prescripciones (card largo)
        _HomeCard(
          icon: Icons.description_rounded,
          label: isEs ? 'PRESCRIPCIONES' : 'PRESCRIÇÕES',
          subtitle: isEs
              ? 'Modelos · Emergencias · Guardia · Clínica'
              : 'Modelos · Emergências · Plantão · Clínica',
          gradientColors: const [Color(0xFF2A0B52), Color(0xFF3D1280), Color(0xFF5B21B6)],
          accentColor: const Color(0xFFA78BFA),
          dark: dark,
          onTap: () => Navigator.of(context).push(
            _slideRoute(const _PrescripcionesShell()),
          ),
        ),
        const SizedBox(height: 12),

        // 2 — Fármacos (card largo)
        _HomeCard(
          icon: Icons.medication_rounded,
          label: 'FÁRMACOS',
          subtitle: isEs
              ? '${uniqueDrugsCount} fármacos · Interacciones · Protocolos'
              : '${uniqueDrugsCount} fármacos · Interações · Protocolos',
          gradientColors: const [Color(0xFF3B2200), Color(0xFF6B3A00), Color(0xFF9A5B00)],
          accentColor: const Color(0xFFFBBF24),
          dark: dark,
          onTap: () => Navigator.of(context).push(
            _slideRoute(const _FarmacosShell()),
          ),
        ),
        const SizedBox(height: 12),

        // 3 — Interacciones (card largo)
        _HomeCard(
          icon: Icons.compare_arrows_rounded,
          label: isEs ? 'INTERACCIONES' : 'INTERAÇÕES',
          subtitle: isEs
              ? '${DrugInteractionService.totalInteractions} pares · Severidad · Manejo clínico'
              : '${DrugInteractionService.totalInteractions} pares · Severidade · Manejo clínico',
          gradientColors: const [Color(0xFF3B0A1E), Color(0xFF5E1234), Color(0xFF8B1E4F)],
          accentColor: const Color(0xFFFF6BA0),
          dark: dark,
          onTap: () => Navigator.of(context).push(
            _slideRoute(const DrugInteractionsScreen()),
          ),
        ),
        const SizedBox(height: 12),

        // 4 — Adulto + Pediatría (lado a lado, metade da largura)
        Row(children: [
          Expanded(
            child: _HomeCardHalf(
              icon: Icons.person_rounded,
              label: 'ADULTO',
              gradientColors: const [Color(0xFF052E1A), Color(0xFF0A5C2E), Color(0xFF15803D)],
              accentColor: const Color(0xFF4ADE80),
              dark: dark,
              onTap: () => Navigator.of(context).push(
                _slideRoute(_AdultoShell(openProtocol: openProtocol)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _HomeCardHalf(
              icon: Icons.child_care_rounded,
              label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
              gradientColors: const [Color(0xFF0A2540), Color(0xFF103D70), Color(0xFF2563EB)],
              accentColor: const Color(0xFF93C5FD),
              dark: dark,
              onTap: () => Navigator.of(context).push(
                _slideRoute(const _PediatricsShell()),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        // ── Divisor ───────────────────────────────────────────────────────
        _HomeDivider(dark: dark),
        const SizedBox(height: 16),

        // ── Notas · Recentes · Favoritos · Novidades ──────────────────────
        _QuickShortcuts(
          dark: dark,
          isEs: isEs,
          openProtocol: openProtocol,
          onOpenNotes: onOpenNotes,
          onCheckUpdate: onCheckUpdate,
        ),

        const SizedBox(height: 16),

        // ── Divisor ───────────────────────────────────────────────────────
        _HomeDivider(dark: dark),
        const SizedBox(height: 16),

        // ── Emergências (4 cards + ver mais) ──────────────────────────────
        _QuickEmergencies(p: p, dark: dark, isEs: isEs, openProtocol: openProtocol),
      ]),
    );
  }

  static Route _slideRoute(Widget page) => _slide(page);

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

  @override
  void dispose() {
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
                        onChanged: (v) => setState(() => _q = v),
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
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF1F6B48),
        label: isEs ? 'Novedades' : 'Novidades',
        onTap: onCheckUpdate ?? () {},
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
                                    HomeScreen._slide(const _FarmacosShell()),
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
                            isEs ? 'PRESCRIPCIONES' : 'PRESCRIÇÕES',
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

// ─────────────────────────────────────────────────────────────────────────────
// ACESSO RÁPIDO — EMERGÊNCIAS
// ─────────────────────────────────────────────────────────────────────────────
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

  static const _protocols = [
    ('anafilaxia',            'Anafilaxia',     Icons.warning_amber_rounded),
    ('sepse',                 'Sepse/Choque',   Icons.emergency_rounded),
    ('tpsv',                  'TPSV',           Icons.favorite_rounded),
    ('pcr_adulto',            'PCR',            Icons.monitor_heart_rounded),
    // extras (visíveis ao expandir)
    ('hiperpotassemia_grave', 'K⁺ alto',        Icons.science_rounded),
    ('avc_isquemico',         'AVC/ACV',        Icons.bolt_rounded),
    ('choque_cardiogenico',   'Choque Card.',   Icons.heart_broken_rounded),
    ('fa_aguda',              'FA Aguda',       Icons.electric_bolt_rounded),
    ('asma_grave',            'Asma Grave',     Icons.air_rounded),
    ('crise_hipertensiva',    'Crise HAS',      Icons.speed_rounded),
    ('tep_agudo',             'TEP',            Icons.bloodtype_rounded),
    ('status_epilepticus',    'Status Epil.',   Icons.psychology_rounded),
  ];

  Widget _buildCard(String id, String label, IconData icon) {
    final dark = widget.dark;
    return GestureDetector(
      onTap: () => widget.openProtocol(id),
      child: Container(
        // Cards mais baixos — altura ~68 via aspectRatio 1.55 na grid
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: dark
              ? const Color(0xFF2A0A0A)
              : const Color(0xFFFFF0F0),
          border: Border.all(
            color: dark
                ? const Color(0xFF6B1A1A).withValues(alpha: 0.6)
                : const Color(0xFFFFCCCC),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFCC2222)),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: dark
                      ? const Color(0xFFFF8888)
                      : const Color(0xFFCC2222),
                  height: 1.2,
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
    final c    = AppColors.of(context);
    final dark = widget.dark;
    final isEs = widget.isEs;

    // visíveis: sempre 4 primeiros; expandido = todos 12
    final visible = _expanded ? _protocols : _protocols.sublist(0, 4);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Cabeçalho da seção + botão ver mais/menos
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Row(children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: const Color(0xFFCC2222),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isEs ? 'EMERGENCIAS RÁPIDAS' : 'EMERGÊNCIAS RÁPIDAS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: c.textHint,
            ),
          ),
          const Spacer(),
          // Botão "ver +" / "ver menos"
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: dark
                    ? const Color(0xFF2A0A0A)
                    : const Color(0xFFFFF0F0),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF6B1A1A).withValues(alpha: 0.5)
                      : const Color(0xFFFFCCCC),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  _expanded
                      ? (isEs ? 'ver menos' : 'ver menos')
                      : (isEs ? 'ver +' : 'ver +'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: dark
                        ? const Color(0xFFFF8888)
                        : const Color(0xFFCC2222),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 13,
                  color: dark
                      ? const Color(0xFFFF8888)
                      : const Color(0xFFCC2222),
                ),
              ]),
            ),
          ),
        ]),
      ),

      // Grid 4 colunas — cards mais baixos (aspect ratio 1.6)
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.55,
        children: visible.map((proto) =>
            _buildCard(proto.$1, proto.$2, proto.$3)).toList(),
      ),
    ]);
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
class _FarmacosShell extends StatelessWidget {
  const _FarmacosShell();

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
              ? '${uniqueDrugsCount} fármacos · Interacciones · Protocolos'
              : '${uniqueDrugsCount} fármacos · Interações · Protocolos',
        ),
        const Expanded(child: DrugsScreen(hideHeader: true)),
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
          label:   isEs ? 'PRESCRIPCIONES' : 'PRESCRIÇÕES',
          subtitle: isEs
              ? 'Modelos · Emergencias · Guardia · Clínica'
              : 'Modelos · Emergências · Plantão · Clínica',
        ),
        const Expanded(child: PrescripcionesScreen()),
      ]),
    );
  }
}
