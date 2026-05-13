import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import 'cockpit_screen.dart';
import 'drugs_screen.dart';
import 'tools_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN — 4 cards de navegação principal
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  /// Callback para trocar de tab na MainShell (usado pelo card Adulto,
  /// Fármacos e Calculadora que apenas mudam a tab ativa do shell).
  final ValueChanged<int> onTabChange;
  final Function(String) openProtocol;

  const HomeScreen({
    super.key,
    required this.onTabChange,
    required this.openProtocol,
  });

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Saudação ──────────────────────────────────────────────────────
        _Greeting(p: p, dark: dark, isEs: isEs),
        const SizedBox(height: 24),

        // ── Cards principais ──────────────────────────────────────────────
        _HomeCard(
          icon: Icons.person_rounded,
          label: isEs ? 'ADULTO' : 'ADULTO',
          subtitle: isEs
              ? 'Paciente · Doses · Protocolos'
              : 'Paciente · Doses · Protocolos',
          gradientColors: const [Color(0xFF0F2318), Color(0xFF1B4A2E), Color(0xFF1F6B48)],
          accentColor: const Color(0xFF4ADE80),
          dark: dark,
          onTap: () => onTabChange(0),
        ),
        const SizedBox(height: 14),

        _HomeCard(
          icon: Icons.child_care_rounded,
          label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
          subtitle: isEs
              ? 'Biometria · PEWS · Doses · Schwartz'
              : 'Biometria · PEWS · Doses · Schwartz',
          gradientColors: const [Color(0xFF0F1E30), Color(0xFF1A3A58), Color(0xFF1D5F8A)],
          accentColor: const Color(0xFF60A5FA),
          dark: dark,
          onTap: () => Navigator.of(context).push(
            _slideRoute(const _PediatricsShell()),
          ),
        ),
        const SizedBox(height: 14),

        _HomeCard(
          icon: Icons.medication_rounded,
          label: isEs ? 'FÁRMACOS' : 'FÁRMACOS',
          subtitle: isEs
              ? '337 fármacos · Interacciones · Protocolos'
              : '337 fármacos · Interações · Protocolos',
          gradientColors: const [Color(0xFF1E1000), Color(0xFF3D2000), Color(0xFF6B3A00)],
          accentColor: const Color(0xFFFBBF24),
          dark: dark,
          onTap: () => onTabChange(1),
        ),
        const SizedBox(height: 14),

        _HomeCard(
          icon: Icons.calculate_rounded,
          label: isEs ? 'CALCULADORAS' : 'CALCULADORAS',
          subtitle: isEs
              ? 'Scores · Cardio · Eletrólitos · Infusão'
              : 'Scores · Cardio · Eletrólitos · Infusão',
          gradientColors: const [Color(0xFF1A0F2E), Color(0xFF2D1B5A), Color(0xFF4A2D8A)],
          accentColor: const Color(0xFFA78BFA),
          dark: dark,
          onTap: () => onTabChange(4),
        ),

        const SizedBox(height: 28),

        // ── Acesso rápido — Emergências ───────────────────────────────────
        _QuickEmergencies(p: p, dark: dark, isEs: isEs, openProtocol: openProtocol),
      ]),
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
    ('anafilaxia',  'Anafilaxia',  Icons.warning_amber_rounded),
    ('sepsis',      'Choque/Sepse',Icons.emergency_rounded),
    ('tpsv',        'TPSV',        Icons.favorite_rounded),
    ('hiperk',      'K⁺ alto',     Icons.science_rounded),
    ('acv',         'AVC/ACV',     Icons.bolt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Título da seção
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Row(children: [
          Container(
            width: 3,
            height: 14,
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
        ]),
      ),

      // Chips
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _protocols.map((proto) {
          final id    = proto.$1;
          final label = proto.$2;
          final icon  = proto.$3;
          return GestureDetector(
            onTap: () => openProtocol(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: dark
                    ? const Color(0xFF2A0A0A)
                    : const Color(0xFFFFF0F0),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF6B1A1A).withValues(alpha: 0.6)
                      : const Color(0xFFFFCCCC),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 12, color: const Color(0xFFCC2222)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCC2222),
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
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
