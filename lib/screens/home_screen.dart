import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../data/drugs_database.dart';
import '../services/drug_interaction_service.dart';
import 'cockpit_screen.dart';
import 'drugs_screen.dart';
import 'tools_screen.dart' show PediatricsTabContent, ToolsScreen;
import 'prescripciones_screen.dart';
import 'drug_interactions_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN — layout moderno light theme
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onTabChange;
  final ValueChanged<int> onSubTabChange;
  final Function(String) openProtocol;

  const HomeScreen({
    super.key,
    required this.onTabChange,
    required this.onSubTabChange,
    required this.openProtocol,
  });

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    final bgColor = dark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F6FA);

    return Container(
      color: bgColor,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ───────────────────────────────────────────────────────
          _HomeHeader(dark: dark, isEs: isEs),

          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: _SearchBar(dark: dark, isEs: isEs),
          ),

          // ── Seção MÓDULOS ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: _SectionLabel(
              label: isEs ? 'MÓDULOS' : 'MÓDULOS',
              dark: dark,
            ),
          ),

          // Cards de módulos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(children: [
              _ModuleCard(
                icon: Icons.description_rounded,
                iconBgColor: const Color(0xFF6C2BD9),
                label: isEs ? 'PRESCRIPCIONES' : 'PRESCRIÇÕES',
                subtitle: isEs
                    ? 'Modelos · Emergencias · Guardia'
                    : 'Modelos · Emergências · Plantão',
                dark: dark,
                onTap: () => Navigator.of(context).push(
                  _slideRoute(const _PrescripcionesShell()),
                ),
              ),
              _ModuleCard(
                icon: Icons.medication_rounded,
                iconBgColor: const Color(0xFFFF8A00),
                label: 'FÁRMACOS',
                subtitle: isEs
                    ? '${drugsDatabase.length} fármacos · Interacciones'
                    : '${drugsDatabase.length} fármacos · Interações',
                dark: dark,
                onTap: () => Navigator.of(context).push(
                  _slideRoute(const _FarmacosShell()),
                ),
              ),
              _ModuleCard(
                icon: Icons.compare_arrows_rounded,
                iconBgColor: const Color(0xFF1F78FF),
                label: isEs ? 'INTERACCIONES' : 'INTERAÇÕES',
                subtitle: isEs
                    ? '${DrugInteractionService.totalInteractions} pares · Severidad'
                    : '${DrugInteractionService.totalInteractions} pares · Severidade',
                dark: dark,
                onTap: () => Navigator.of(context).push(
                  _slideRoute(const DrugInteractionsScreen()),
                ),
              ),
              _ModuleCard(
                icon: Icons.child_care_rounded,
                iconBgColor: const Color(0xFF16B8C8),
                label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
                subtitle: isEs
                    ? 'Biometría · PEWS · Dosis · Schwartz'
                    : 'Biometria · PEWS · Doses · Schwartz',
                dark: dark,
                onTap: () => Navigator.of(context).push(
                  _slideRoute(const _PediatricsShell()),
                ),
              ),
              _ModuleCard(
                icon: Icons.person_rounded,
                iconBgColor: const Color(0xFF2FA84F),
                label: 'ADULTO',
                subtitle: isEs
                    ? 'Paciente · Dosis · Protocolos'
                    : 'Paciente · Doses · Protocolos',
                dark: dark,
                isLast: true,
                onTap: () => Navigator.of(context).push(
                  _slideRoute(_AdultoShell(openProtocol: openProtocol)),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Seção ACCESOS RÁPIDOS ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: _SectionLabel(
              label: isEs ? 'ACCESOS RÁPIDOS' : 'ACESSOS RÁPIDOS',
              dark: dark,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _QuickAccess(
              dark: dark,
              isEs: isEs,
              openProtocol: openProtocol,
              onTabChange: onTabChange,
            ),
          ),

          const SizedBox(height: 24),

          // ── Seção EMERGENCIAS RÁPIDAS ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: _SectionLabel(
              label: isEs ? 'EMERGENCIAS RÁPIDAS' : 'EMERGÊNCIAS RÁPIDAS',
              dark: dark,
              accentColor: const Color(0xFFCC2222),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: _QuickEmergencies(
              p: p,
              dark: dark,
              isEs: isEs,
              openProtocol: openProtocol,
            ),
          ),

          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  static Route _slideRoute(Widget page) {
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
// HEADER — logo, título, sino de notificação, menu
// ─────────────────────────────────────────────────────────────────────────────
class _HomeHeader extends StatelessWidget {
  final bool dark;
  final bool isEs;
  const _HomeHeader({required this.dark, required this.isEs});

  @override
  Widget build(BuildContext context) {
    final bgTop = dark ? const Color(0xFF1A1A2E) : Colors.white;
    final shadow = dark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: bgTop,
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 16, 16),
          child: Row(children: [
            // Logo — quadrado arredondado com cruz
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A2BD9), Color(0xFF1F78FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A2BD9).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),

            // Título + subtítulo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF4A2BD9), Color(0xFF1F78FF)],
                    ).createShader(bounds),
                    child: const Text(
                      'MedCases Pro',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    isEs
                        ? 'Decisiones clínicas seguras'
                        : 'Decisões clínicas seguras',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: dark
                          ? Colors.white.withValues(alpha: 0.45)
                          : const Color(0xFF8A94A6),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),

            // Sino de notificação
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: dark
                        ? Colors.white.withValues(alpha: 0.07)
                        : const Color(0xFFF0F2F8),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 20,
                    color: dark ? Colors.white70 : const Color(0xFF4A5568),
                  ),
                ),
                // Badge vermelho
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53E3E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: dark ? const Color(0xFF1A1A2E) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),

            // Menu hamburger
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: dark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFFF0F2F8),
              ),
              child: Icon(
                Icons.menu_rounded,
                size: 20,
                color: dark ? Colors.white70 : const Color(0xFF4A5568),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR — barra de pesquisa pill shape
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final bool dark;
  final bool isEs;
  const _SearchBar({required this.dark, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: dark ? const Color(0xFF252535) : Colors.white,
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        Icon(
          Icons.search_rounded,
          size: 20,
          color: dark ? Colors.white38 : const Color(0xFFA0AEC0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isEs
                ? 'Buscar fármaco, protocolo…'
                : 'Buscar fármaco, protocolo…',
            style: TextStyle(
              fontSize: 14,
              color: dark ? Colors.white30 : const Color(0xFFB0BAC9),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(right: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: const LinearGradient(
              colors: [Color(0xFF4A2BD9), Color(0xFF1F78FF)],
            ),
          ),
          child: const Icon(
            Icons.document_scanner_outlined,
            size: 16,
            color: Colors.white,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL — rótulo de seção uppercase
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final bool dark;
  final Color? accentColor;
  const _SectionLabel({
    required this.label,
    required this.dark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ??
        (dark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF8A94A6));
    return Row(children: [
      Container(
        width: 3,
        height: 13,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: accentColor ?? const Color(0xFF4A2BD9),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: color,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODULE CARD — card de módulo light bg com caixa de ícone colorida
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleCard extends StatefulWidget {
  final IconData icon;
  final Color iconBgColor;
  final String label;
  final String subtitle;
  final bool dark;
  final bool isLast;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.iconBgColor,
    required this.label,
    required this.subtitle,
    required this.dark,
    required this.onTap,
    this.isLast = false,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
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
    final cardBg = widget.dark ? const Color(0xFF1E1E2E) : Colors.white;
    final divColor = widget.dark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFEDF0F7);

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isLast ? 16 : 4),
              bottomRight: Radius.circular(widget.isLast ? 16 : 4),
            ),
            boxShadow: widget.dark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  // Caixa de ícone colorida
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: widget.iconBgColor,
                      boxShadow: [
                        BoxShadow(
                          color: widget.iconBgColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Textos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: widget.iconBgColor,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: widget.dark
                                ? Colors.white38
                                : const Color(0xFF8A94A6),
                            letterSpacing: 0.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: widget.dark
                        ? Colors.white24
                        : const Color(0xFFCBD5E0),
                  ),
                ]),
              ),
              // Divisor (exceto no último)
              if (!widget.isLast)
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 76),
                  color: divColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCESOS RÁPIDOS — 4 mini-cards horizontais
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAccess extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final Function(String) openProtocol;
  final ValueChanged<int> onTabChange;

  const _QuickAccess({
    required this.dark,
    required this.isEs,
    required this.openProtocol,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _QAItem(
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFE53E3E),
        bgColor: dark ? const Color(0xFF2D1515) : const Color(0xFFFFF5F5),
        borderColor: dark
            ? const Color(0xFF6B1A1A).withValues(alpha: 0.5)
            : const Color(0xFFFED7D7),
        label: isEs ? 'Emergencias\nRápidas' : 'Emergências\nRápidas',
        onTap: () => openProtocol('anafilaxia'),
      ),
      _QAItem(
        icon: Icons.favorite_rounded,
        iconColor: const Color(0xFFE53E3E),
        bgColor: dark ? const Color(0xFF2D1515) : const Color(0xFFFFF5F5),
        borderColor: dark
            ? const Color(0xFF6B1A1A).withValues(alpha: 0.5)
            : const Color(0xFFFED7D7),
        label: isEs ? 'Protocolos\nCríticos' : 'Protocolos\nCríticos',
        onTap: () => openProtocol('pcr_adulto'),
      ),
      _QAItem(
        icon: Icons.bookmark_rounded,
        iconColor: const Color(0xFF6C2BD9),
        bgColor: dark ? const Color(0xFF1E1530) : const Color(0xFFF5F0FF),
        borderColor: dark
            ? const Color(0xFF4A2BD9).withValues(alpha: 0.4)
            : const Color(0xFFE9D8FD),
        label: isEs ? 'Favoritos' : 'Favoritos',
        onTap: () {},
      ),
      _QAItem(
        icon: Icons.sticky_note_2_rounded,
        iconColor: const Color(0xFFFF8A00),
        bgColor: dark ? const Color(0xFF2D1E00) : const Color(0xFFFFFAF0),
        borderColor: dark
            ? const Color(0xFF8A4A00).withValues(alpha: 0.5)
            : const Color(0xFFFEEBC8),
        label: isEs ? 'Mis Notas' : 'Minhas Notas',
        onTap: () {},
      ),
    ];

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: item == items.last ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: item.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: item.bgColor,
                      border: Border.all(color: item.borderColor, width: 1),
                      boxShadow: dark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 24, color: item.iconColor),
                        const SizedBox(height: 7),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: dark
                                ? Colors.white.withValues(alpha: 0.75)
                                : const Color(0xFF4A5568),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QAItem {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String label;
  final VoidCallback onTap;
  const _QAItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.label,
    required this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// EMERGÊNCIAS RÁPIDAS — grid 4 colunas
// ─────────────────────────────────────────────────────────────────────────────
class _QuickEmergencies extends StatelessWidget {
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

  static const _protocols = [
    ('anafilaxia',            'Anafilaxia',     Icons.warning_amber_rounded),
    ('sepse',                 'Sepse/Choque',   Icons.emergency_rounded),
    ('tpsv',                  'TPSV',           Icons.favorite_rounded),
    ('hiperpotassemia_grave', 'K⁺ alto',        Icons.science_rounded),
    ('avc_isquemico',         'AVC/ACV',        Icons.bolt_rounded),
    ('pcr_adulto',            'PCR',            Icons.monitor_heart_rounded),
    ('choque_cardiogenico',   'Choque Card.',   Icons.heart_broken_rounded),
    ('fa_aguda',              'FA Aguda',       Icons.electric_bolt_rounded),
    ('asma_grave',            'Asma Grave',     Icons.air_rounded),
    ('crise_hipertensiva',    'Crise HAS',      Icons.speed_rounded),
    ('tep_agudo',             'TEP',            Icons.bloodtype_rounded),
    ('status_epilepticus',    'Status Epil.',   Icons.psychology_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.0,
      children: _protocols.map((proto) {
        final id    = proto.$1;
        final label = proto.$2;
        final icon  = proto.$3;
        return GestureDetector(
          onTap: () => openProtocol(id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: dark
                  ? const Color(0xFF2A0A0A)
                  : const Color(0xFFFFF5F5),
              border: Border.all(
                color: dark
                    ? const Color(0xFF6B1A1A).withValues(alpha: 0.6)
                    : const Color(0xFFFED7D7),
              ),
              boxShadow: dark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: const Color(0xFFE53E3E)),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: dark
                          ? const Color(0xFFFF8888)
                          : const Color(0xFFCC2222),
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PEDIATRICS SHELL — wrapper com AppBar para o tab Pediatria
// Apresenta o _PediatricsTab como tela standalone com back button
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
        // Header com gradiente igual ao ToolsScreen
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1830), Color(0xFF0F2648), Color(0xFF1D5F8A)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 16, 0),
              child: Row(children: [
                // Botão voltar
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      size: 18, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Ícone
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  child: const Icon(Icons.child_care_rounded,
                      size: 20, color: Color(0xFF60A5FA)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEs ? 'Herramientas Pediátricas' : 'Ferramentas Pediátricas',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        isEs
                            ? 'Biometría · PEWS · Schwartz · Dosis'
                            : 'Biometria · PEWS · Schwartz · Doses',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        // Conteúdo — reutiliza o PediatricsTabContent do ToolsScreen
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
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F1C14), Color(0xFF1B3D2A), Color(0xFF1F6B48)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 16, 12),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  child: const Icon(Icons.person_rounded, size: 20, color: Color(0xFF4ADE80)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isEs ? 'Paciente Adulto' : 'Paciente Adulto',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.3),
                  ),
                  Text(
                    isEs ? 'Dosis · Protocolos · Calculadora' : 'Doses · Protocolos · Calculadora',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ])),
              ]),
            ),
          ),
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
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1000), Color(0xFF3D2000), Color(0xFF6B3A00)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 16, 12),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  child: const Icon(Icons.medication_rounded, size: 20, color: Color(0xFFFBBF24)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isEs ? 'Fármacos' : 'Fármacos',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.3),
                  ),
                  Text(
                    isEs ? '${drugsDatabase.length} fármacos · Interacciones · Protocolos'
                         : '${drugsDatabase.length} fármacos · Interações · Protocolos',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ])),
              ]),
            ),
          ),
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
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A0F2E), Color(0xFF2D1B5A), Color(0xFF4A2D8A)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 16, 12),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  child: const Icon(Icons.calculate_rounded, size: 20, color: Color(0xFFA78BFA)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isEs ? 'Calculadoras Clínicas' : 'Calculadoras Clínicas',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.3),
                  ),
                  Text(
                    isEs ? 'Scores · Cardio · Electrolitos · Infusión'
                         : 'Scores · Cardio · Eletrólitos · Infusão',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ])),
              ]),
            ),
          ),
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
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF120A1E), Color(0xFF2A1245), Color(0xFF4A2080)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 16, 12),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  child: const Icon(Icons.description_rounded, size: 20, color: Color(0xFFD8B4FE)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isEs ? 'Ejemplos de Prescripción' : 'Exemplos de Prescrição',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.3),
                  ),
                  Text(
                    isEs
                        ? 'Modelos educativos · Emergencias · Guardia'
                        : 'Modelos educacionais · Emergências · Plantão',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ])),
              ]),
            ),
          ),
        ),
        const Expanded(child: PrescripcionesScreen()),
      ]),
    );
  }
}
