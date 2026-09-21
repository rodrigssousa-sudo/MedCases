import '../testimonials/testimonial_intent.dart';
// ── Tela de preview pré-login — MedCases Pro V2 (dark institucional) ─────────
// MEDCASES_PRE_LOGIN_ONBOARDING_UI_V2_B_R1
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/login_screen.dart';
import '../widgets/public_landing/public_landing.dart';
import '../screens/legal_screen.dart';

// ── Paleta MedCases Pro (dark premium clínico institucional) ─────────────────
const _kBg          = Color(0xFF1A1D23);   // fundo — preto-verde profundo (MedCases Pro)
const _kBgCard      = Color(0xFF252930);   // card escuro MedCases Pro
const _kGreen       = Color(0xFF0D6B57);   // verde principal
const _kGreenMid    = Color(0xFF0D6B57);   // verde médio
const _kGreenLight  = Color(0xFF0D6B57);   // verde claro acento
const _kNeon        = Color(0xFF0D6B57);   // acento institucional MedCases Pro
const _kNeonGlow    = Color(0xFF0D6B57);   // acento de profundidade
const _kGold        = Color(0xFFC5A365);   // dourado — CTA
const _kText        = Color(0xFFF1F5F9);   // texto principal MedCases Pro (quase branco)
const _kTextMid     = Color(0xFF94A3B8);   // texto secundário MedCases Pro
const _kTextDim     = Color(0xFF7C8797);   // texto suave
const _kBorder      = Color(0xFF374151);   // bordas MedCases Pro
const _kRed         = Color(0xFFCC3333);   // vermelho acento

const String _kAppStoreUrl = String.fromEnvironment(
  'MEDCASES_APP_STORE_URL',
  defaultValue: '',
);

// ══════════════════════════════════════════════════════════════════════════════
class PreLoginPreview extends StatefulWidget {
  const PreLoginPreview({super.key});
  @override
  State<PreLoginPreview> createState() => _PreLoginPreviewState();
}

class _PreLoginPreviewState extends State<PreLoginPreview> {
  bool _showLogin  = false;
  bool? _hasConsented;
  String _lang     = 'es';

  bool   get _isEs     => _lang == 'es';

  // ── Dados protocolos — mesmos dados, novo layout visual ──────────────────
  static const _protocols = [
    _ProtoItem(
      icon: Icons.medication_rounded,
      category: 'Infectología',
      tag: 'NUEVO',
      tagIsGreen: true,
      title: 'Sepsis — Protocolo Antibiótico Empírico',
      subtitle: 'Sepsis de foco pulmonar comunitaria',
      items: 5,
    ),
    _ProtoItem(
      icon: Icons.monitor_heart_rounded,
      category: 'Cardiología',
      tag: 'TOP',
      tagIsGreen: false,
      title: 'STEMI — Protocolo Post-Angioplastia',
      subtitle: 'IAM con elevación del ST',
      items: 5,
    ),
  ];

  static const _critical = [
    _CritItem(
      icon: Icons.local_fire_department_rounded,
      area: 'Emergencias',
      title: 'Choque Séptico',
      sub: 'Falla circulatoria aguda',
    ),
    _CritItem(
      icon: Icons.psychology_rounded,
      area: 'Neurología',
      title: 'ACV Isquémico',
      sub: 'Ventana terapéutica crítica',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLangAndConsent();
  }

  Future<void> _loadLangAndConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final lang  = prefs.getString('lang') ?? 'es';
    final ok    = await ConsentGate.hasConsented();
    if (mounted) setState(() { _lang = lang; _hasConsented = ok; });
  }

  Future<void> _toggleLang() async {
    final newLang = _isEs ? 'pt' : 'es';
    final prefs   = await SharedPreferences.getInstance();
    await prefs.setString('lang', newLang);
    if (mounted) setState(() => _lang = newLang);
  }

  Future<void> _openAppStore() async {
    final raw = _kAppStoreUrl.trim();

    if (raw.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEs
                ? 'El enlace de App Store se conectará antes de publicar.'
                : 'O link da App Store será conectado antes da publicação.',
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(raw);

    if (uri == null) return;

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  void _onConsentAccepted() => setState(() => _hasConsented = true);
  void _goLogin()           => setState(() => _showLogin = true);
  void _backToPreview() {
    TestimonialIntent.clear();
    setState(() => _showLogin = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      if (_hasConsented == null) {
        return const Scaffold(
          backgroundColor: _kBg,
          body: Center(child: CircularProgressIndicator(color: _kGreenLight)),
        );
      }
      if (!_hasConsented!) {
        return Stack(children: [
          LoginScreen(onBack: _backToPreview),
          Positioned.fill(child: ColoredBox(
            color: Colors.black.withOpacity(0.55))),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: ConsentModal(lang: _lang, onAccepted: _onConsentAccepted),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4, left: 8,
            child: IconButton(
              onPressed: _backToPreview,
              tooltip: _isEs ? 'Volver a la página' : 'Voltar à página',
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ]);
      }
      return LoginScreen(onBack: _backToPreview);
    }

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: _kBg,
        body: PublicLanding(
          language: _lang,
          onTestimonial: (language) async {
            await TestimonialIntent.request();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('lang', language);
            if (!mounted) return;
            setState(() { _lang = language; _showLogin = true; });
          },
          onLogin: (language) async {
            await TestimonialIntent.clear();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('lang', language);
            if (!mounted) return;
            setState(() { _lang = language; _showLogin = true; });
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        // ── Header ────────────────────────────────────────────────────────────────
        _R77Header(isEs: _isEs, onToggleLang: _toggleLang, onLogin: _goLogin),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 130),
            children: [
                _R77Landing(
                  isEs: _isEs,
                  onCreateAccount: _goLogin,
                  onAppStore: _openAppStore,
                ),
              ],
          ),
        ),
      ]),

      // ── CTA inferior — novo estilo verde sólido (não dourado pill) ───────
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER DARK — radicalmente diferente do branco anterior
// ══════════════════════════════════════════════════════════════════════════════
class _DarkHeader extends StatelessWidget {
  final bool isEs;
  final VoidCallback onToggleLang, onLogin;
  const _DarkHeader({
    required this.isEs,
    required this.onToggleLang,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _kNeonGlow.withOpacity(0.07), width: 0.8)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            // Logo quadrado com borda — diferente do arredondado anterior
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder, width: 0.8),
                color: _kBgCard,
              ),
              child: Center(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 24, height: 24, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'MedCases Pro',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            // Seletor idioma — estilo diferente (tag arredondada)
            GestureDetector(
              onTap: onToggleLang,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _kBgCard,
                  border: Border.all(color: _kBorder, width: 0.8),
                ),
                child: Text(
                  isEs ? 'PT' : 'ES',
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _kGreenLight, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(width: 8),
            // Botão entrar — verde sólido (não dourado)
            GestureDetector(
              onTap: onLogin,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _kGreen,
                ),
                child: Text(
                  isEs ? 'Entrar' : 'Entrar',
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION TITLE — estilo dark, diferente do anterior (círculo colorido)
// ══════════════════════════════════════════════════════════════════════════════
class _HeroConversion extends StatelessWidget {
  final bool isEs;
  final VoidCallback onAppStore;
  final VoidCallback onWebTrial;

  const _HeroConversion({
    required this.isEs,
    required this.onAppStore,
    required this.onWebTrial,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final copy = _PremiumHeroCopy(
          isEs: isEs,
          onAppStore: onAppStore,
          onWebTrial: onWebTrial,
        );

        final product = _PremiumProductVisual(
          isEs: isEs,
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isWide ? 24 : 4,
            isWide ? 54 : 30,
            isWide ? 24 : 4,
            isWide ? 54 : 26,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              isWide ? 30 : 22,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF171B20),
                const Color(0xFF15191E),
                _kGreen.withValues(alpha: 0.035),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.045,
              ),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: isWide ? 40 : -70,
                top: isWide ? 20 : 210,
                child: IgnorePointer(
                  child: Container(
                    width: isWide ? 360 : 260,
                    height: isWide ? 360 : 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kGreen.withValues(
                            alpha: 0.11,
                          ),
                          blurRadius: 130,
                          spreadRadius: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isWide)
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 10,
                      child: copy,
                    ),
                    const SizedBox(width: 48),
                    Expanded(
                      flex: 11,
                      child: product,
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    copy,
                    const SizedBox(height: 34),
                    product,
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PremiumHeroCopy extends StatelessWidget {
  final bool isEs;
  final VoidCallback onAppStore;
  final VoidCallback onWebTrial;

  const _PremiumHeroCopy({
    required this.isEs,
    required this.onAppStore,
    required this.onWebTrial,
  });

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width;

    final mobile = width < 600;

    return Column(
      crossAxisAlignment: mobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: _kGreen.withValues(
              alpha: 0.075,
            ),
            borderRadius:
                BorderRadius.circular(999),
            border: Border.all(
              color: _kGreen.withValues(
                alpha: 0.20,
              ),
            ),
          ),
          child: Text(
            'MEDCASES PRO',
            style: const TextStyle(
              color: _kGreenLight,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          isEs
              ? 'Estudia. Consulta.\nEncuentra lo importante.'
              : 'Estude. Consulte.\nEncontre o que importa.',
          textAlign: mobile
              ? TextAlign.center
              : TextAlign.left,
          style: TextStyle(
            fontSize: mobile ? 34 : 46,
            height: 1.02,
            fontWeight: FontWeight.w800,
            letterSpacing: mobile
                ? -1.15
                : -1.65,
            color: _kText,
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
          ),
          child: Text(
            isEs
                ? 'Guías actualizadas, fármacos, calculadoras y asistencia con IA para estudiar y consultar medicina en un solo lugar.'
                : 'Guias atualizadas, fármacos, calculadoras e assistência com IA para estudar e consultar medicina em um só lugar.',
            textAlign: mobile
                ? TextAlign.center
                : TextAlign.left,
            style: const TextStyle(
              fontSize: 15,
              height: 1.52,
              fontWeight: FontWeight.w400,
              color: _kTextMid,
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (mobile)
          Column(
            children: [
              _PremiumPrimaryCta(
                isEs: isEs,
                onTap: onAppStore,
              ),
              const SizedBox(height: 10),
              _PremiumSecondaryCta(
                isEs: isEs,
                onTap: onWebTrial,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _PremiumPrimaryCta(
                  isEs: isEs,
                  onTap: onAppStore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PremiumSecondaryCta(
                  isEs: isEs,
                  onTap: onWebTrial,
                ),
              ),
            ],
          ),
        const SizedBox(height: 18),
        Wrap(
          alignment: mobile
              ? WrapAlignment.center
              : WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: [
            _PremiumProofPill(
              label: isEs
                  ? 'Guías 2026'
                  : 'Guias 2026',
            ),
            const _PremiumProofPill(
              label: 'Fármacos',
            ),
            _PremiumProofPill(
              label: isEs
                  ? 'Calculadoras'
                  : 'Calculadoras',
            ),
            const _PremiumProofPill(
              label: 'ES · PT',
            ),
          ],
        ),
      ],
    );
  }
}

class _PremiumPrimaryCta
    extends StatelessWidget {
  final bool isEs;
  final VoidCallback onTap;

  const _PremiumPrimaryCta({
    required this.isEs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _kText,
          foregroundColor: _kBg,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_outward_rounded,
              size: 18,
            ),
            const SizedBox(width: 9),
            Text(
              isEs
                  ? 'Ver en App Store'
                  : 'Ver na App Store',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSecondaryCta
    extends StatelessWidget {
  final bool isEs;
  final VoidCallback onTap;

  const _PremiumSecondaryCta({
    required this.isEs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kText,
          side: BorderSide(
            color: Colors.white.withValues(
              alpha: 0.11,
            ),
          ),
          backgroundColor:
              Colors.white.withValues(
            alpha: 0.025,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
        child: Text(
          isEs
              ? 'Probar en la web'
              : 'Testar na web',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PremiumProofPill
    extends StatelessWidget {
  final String label;

  const _PremiumProofPill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(999),
        color: Colors.white.withValues(
          alpha: 0.025,
        ),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _kTextDim,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PremiumProductVisual extends StatelessWidget {
  final bool isEs;

  const _PremiumProductVisual({
    required this.isEs,
  });

  static const _mainImage =
      '/landing/medcases_appstore_1242x2688.jpg';

  static const _drugsImage =
      '/landing/medcases_farmacos_1242x2688.jpg';

  static const _aiImage =
      '/landing/medcases_ia_1242x2688.jpg';

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 440;

        final mainWidth =
            wide ? 244.0 : 226.0;

        return SizedBox(
          width: double.infinity,
          height: wide ? 540 : 510,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                top: wide ? 70 : 82,
                child: IgnorePointer(
                  child: Container(
                    width: wide ? 330 : 285,
                    height: wide ? 330 : 285,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kGreen.withValues(
                            alpha: 0.16,
                          ),
                          blurRadius: 125,
                          spreadRadius: 34,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (wide)
                Positioned(
                  left: 8,
                  top: 82,
                  child: Transform.rotate(
                    angle: -0.075,
                    child: Opacity(
                      opacity: 0.34,
                      child: _PremiumPhoneShot(
                        imagePath: _drugsImage,
                        width: 174,
                        shadowOpacity: 0.20,
                      ),
                    ),
                  ),
                ),

              if (wide)
                Positioned(
                  right: 8,
                  top: 92,
                  child: Transform.rotate(
                    angle: 0.07,
                    child: Opacity(
                      opacity: 0.30,
                      child: _PremiumPhoneShot(
                        imagePath: _aiImage,
                        width: 168,
                        shadowOpacity: 0.18,
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: wide ? 30 : 20,
                child: Transform.rotate(
                  angle: wide ? -0.012 : 0,
                  child: _PremiumPhoneShot(
                    imagePath: _mainImage,
                    width: mainWidth,
                    shadowOpacity: 0.50,
                    primary: true,
                  ),
                ),
              ),

              Positioned(
                left: wide ? 0 : 4,
                top: wide ? 80 : 88,
                child: _PremiumFloatingLabel(
                  icon: Icons.menu_book_outlined,
                  label: isEs
                      ? 'Guías 2026'
                      : 'Guias 2026',
                ),
              ),

              Positioned(
                right: wide ? 0 : 4,
                top: wide ? 178 : 190,
                child: const _PremiumFloatingLabel(
                  icon: Icons.medication_outlined,
                  label: 'Fármacos',
                ),
              ),

              Positioned(
                left: wide ? 14 : 6,
                bottom: wide ? 78 : 52,
                child: _PremiumFloatingLabel(
                  icon: Icons.auto_awesome_outlined,
                  label: isEs
                      ? 'IA de apoyo'
                      : 'IA de apoio',
                ),
              ),

              Positioned(
                right: wide ? 18 : 6,
                bottom: wide ? 42 : 24,
                child: const _PremiumFloatingLabel(
                  icon: Icons.calculate_outlined,
                  label: 'Scores',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PremiumPhoneShot extends StatelessWidget {
  final String imagePath;
  final double width;
  final double shadowOpacity;
  final bool primary;

  const _PremiumPhoneShot({
    required this.imagePath,
    required this.width,
    required this.shadowOpacity,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius =
        primary ? 38.0 : 32.0;

    return Container(
      width: width,
      padding: EdgeInsets.all(
        primary ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF06080A),
        borderRadius:
            BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: primary ? 0.14 : 0.08,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: shadowOpacity,
            ),
            blurRadius:
                primary ? 58 : 34,
            offset: Offset(
              0,
              primary ? 28 : 18,
            ),
          ),
          if (primary)
            BoxShadow(
              color: _kGreen.withValues(
                alpha: 0.07,
              ),
              blurRadius: 70,
              spreadRadius: 4,
            ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1242 / 2688,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(
            radius - 10,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imagePath,
                fit: BoxFit.cover,
                alignment:
                    Alignment.topCenter,
                filterQuality:
                    FilterQuality.high,
              ),
              Align(
                alignment:
                    Alignment.topCenter,
                child: Container(
                  margin:
                      const EdgeInsets.only(
                    top: 7,
                  ),
                  width: primary ? 56 : 44,
                  height: primary ? 15 : 12,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF050607),
                    borderRadius:
                        BorderRadius.circular(
                      999,
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment.center,
                      colors: [
                        Colors.white
                            .withValues(
                          alpha:
                              primary
                                  ? 0.055
                                  : 0.025,
                        ),
                        Colors.transparent,
                      ],
                    ),
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

class _PremiumFloatingLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PremiumFloatingLabel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xE8171C21),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.085,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.34,
            ),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: _kGreenLight,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: _kText,
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label, sub;
  final Color accentColor;
  final IconData iconData;
  const _SectionTitle({
    required this.label,
    required this.sub,
    required this.accentColor,
    required this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(iconData, size: 14, color: accentColor),
      const SizedBox(width: 7),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: accentColor, letterSpacing: 1.0)),
          Text(sub,
            style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w400,
              color: _kTextMid)),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════════════════════════════
class _ProtoItem {
  final IconData icon;
  final String category, tag, title, subtitle;
  final bool tagIsGreen;
  final int items;
  const _ProtoItem({
    required this.icon, required this.category,
    required this.tag, required this.tagIsGreen,
    required this.title, required this.subtitle, required this.items,
  });
}

class _CritItem {
  final IconData icon;
  final String area, title, sub;
  const _CritItem({
    required this.icon, required this.area,
    required this.title, required this.sub,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD PROTOCOLO — dark, sem bordas brancas, acento esquerdo verde
// ══════════════════════════════════════════════════════════════════════════════
class _ProtoCard extends StatelessWidget {
  final _ProtoItem data;
  final VoidCallback onTap;
  final bool isEs;
  const _ProtoCard({required this.data, required this.onTap, required this.isEs});

  @override
  Widget build(BuildContext context) {
    final tagColor = data.tagIsGreen ? _kGreenLight : _kGold;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _kBgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          // Acento lateral verde (linha vertical esquerda)
          Container(
            width: 3, height: 70,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12)),
              color: data.tagIsGreen ? _kGreenMid : _kGold,
            ),
          ),
          // Ícone
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _kGreen.withOpacity(0.15),
              ),
              child: Icon(data.icon, size: 22, color: _kGreenLight),
            ),
          ),
          // Conteúdo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(data.category,
                    style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: _kTextMid)),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tagColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: tagColor.withOpacity(0.35)),
                    ),
                    child: Text(data.tag,
                      style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: tagColor)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(data.title,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _kText, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(data.subtitle,
                  style: const TextStyle(
                    fontSize: 11, color: _kTextMid),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.chevron_right_rounded,
              size: 18, color: _kTextDim),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD CRÍTICO — dark, compacto
// ══════════════════════════════════════════════════════════════════════════════
class _CritCard extends StatelessWidget {
  final _CritItem data;
  final VoidCallback onTap;
  final bool isEs;
  const _CritCard({required this.data, required this.onTap, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kBgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kRed.withOpacity(0.25)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _kRed.withOpacity(0.12),
            ),
            child: Icon(data.icon, size: 18, color: _kRed),
          ),
          const SizedBox(height: 8),
          Text(data.area,
            style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: _kRed, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(data.title,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: _kText, height: 1.2),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(data.sub,
            style: const TextStyle(
              fontSize: 10, color: _kTextMid, height: 1.3),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle, color: _kRed),
            ),
            const SizedBox(width: 5),
            const Text('Urgente',
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _kRed)),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BLOCO IA — MedCases Pro: profundidade sutil + radial gradient + glassmorphism
// ══════════════════════════════════════════════════════════════════════════════
class _IaBlockDark extends StatelessWidget {
  final VoidCallback onTap;
  final bool isEs;
  const _IaBlockDark({required this.onTap, required this.isEs});

  static const _prompts = [
    'Dosis de noradrenalina en choque séptico',
    'Protocolo de sepsis en UCI',
    'Manejo inicial de STEMI',
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // ── RadialGradient sutil para profundidade (MedCases Pro) ─────────────
          gradient: const RadialGradient(
            center: Alignment(-0.6, -0.7),
            radius: 1.2,
            colors: [
              Color(0xFF2A3038),   // centro levemente mais claro
              Color(0xFF252930),   // _kBgCard
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          // ── Borda verde neon sutil ────────────────────────────────────────
          border: Border.all(
            color: _kNeonGlow.withOpacity(0.12),
            width: 1.0,
          ),
          // ── Profundidade sutil 2 camadas (inner glow + outer diffuse) ─────────────
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header IA — ícone MedCases + badge AI POWERED ────────────────────
          Row(children: [
            // Ícone circular com glow sutil
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kNeonGlow.withOpacity(0.06),
                border: Border.all(
                  color: _kNeonGlow.withOpacity(0.18), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: _kNeonGlow.withOpacity(0.10),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_outlined, size: 18, color: _kNeon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'IA de apoyo médico' : 'IA de apoio médico',
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: _kText, letterSpacing: -0.2)),
                  Text(
                    isEs
                        ? 'Respuestas basadas en evidencia'
                        : 'Respostas baseadas em evidências',
                    style: const TextStyle(
                      fontSize: 10.5, color: _kTextMid)),
                ],
              ),
            ),
            // Badge AI POWERED — estilo MedCases Pro
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _kNeonGlow.withOpacity(0.06),
                border: Border.all(
                  color: _kNeonGlow.withOpacity(0.16), width: 0.8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: _kNeon),
                ),
                const SizedBox(width: 5),
                const Text('AI',
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: _kNeon, letterSpacing: 0.5)),
              ]),
            ),
          ]),

          const SizedBox(height: 14),

          // ── Resposta IA — glassmorphism interno ──────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF20242B),
              border: Border.all(
                color: _kNeonGlow.withOpacity(0.07), width: 0.8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: _kNeon),
                ),
                const SizedBox(width: 6),
                Text(
                  isEs ? 'IA MedCases responde:' : 'IA MedCases responde:',
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: _kNeon)),
              ]),
              const SizedBox(height: 7),
              Text(
                isEs
                  ? 'Noradrenalina 0,1–0,2 μg/kg/min IV em bomba. Titular conforme PAM ≥ 65 mmHg. Acesso venoso central preferencial...'
                  : 'Noradrenalina 0,1–0,2 μg/kg/min IV em bomba. Titular conforme PAM ≥ 65 mmHg. Acesso venoso central preferencialmente...',
                style: const TextStyle(
                  fontSize: 12, color: _kText,
                  fontWeight: FontWeight.w400, height: 1.55),
                maxLines: 3, overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Chips sugestão — estilo MedCases Pro ─────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _prompts.map((p) => GestureDetector(
                onTap: onTap,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20242B),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _kNeonGlow.withOpacity(0.09), width: 0.8),
                  ),
                  child: Text(p,
                    style: const TextStyle(
                      fontSize: 10, color: _kTextMid,
                      fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Input fake — borda de foco MedCases ───────────────────────────────
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF20242B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _kNeonGlow.withOpacity(0.18), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: _kNeonGlow.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                const Icon(Icons.search_rounded,
                  size: 16, color: _kTextMid),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEs ? 'Consultar caso clínico...' : 'Consultar caso clínico...',
                    style: const TextStyle(
                      fontSize: 12, color: _kTextDim)),
                ),
                // Botão send MedCases
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D6B57), Color(0xFF0D6B57)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kNeonGlow.withOpacity(0.14),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded,
                    size: 13, color: Colors.white),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MÉTRICAS RÁPIDAS — MedCases Pro: 2 cards lado a lado, ícone circular
// ══════════════════════════════════════════════════════════════════════════════
class _MetricsRow extends StatelessWidget {
  final bool isEs;

  const _MetricsRow({required this.isEs});

  Widget _benefit({
    required IconData icon,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: _kNeon,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kText,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _benefit(
        icon: Icons.menu_book_rounded,
        label: isEs
            ? 'Contenido clínico actualizado'
            : 'Conteúdo clínico atualizado',
      ),
      _benefit(
        icon: Icons.medication_outlined,
        label: 'Fármacos',
      ),
      _benefit(
        icon: Icons.calculate_outlined,
        label: isEs
            ? 'Calculadoras y scores'
            : 'Calculadoras e scores',
      ),
      _benefit(
        icon: Icons.psychology_outlined,
        label: isEs
            ? 'IA de apoyo médico'
            : 'IA de apoio médico',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 24,
      ),
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: _kTextDim.withValues(alpha: 0.16),
            width: 1,
          ),
          bottom: BorderSide(
            color: _kTextDim.withValues(alpha: 0.16),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            isEs
                ? 'Todo lo que necesitas.'
                : 'Tudo o que você precisa.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _kText,
              letterSpacing: -0.35,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 22),

          LayoutBuilder(
            builder: (context, constraints) {
              final singleColumn = constraints.maxWidth < 340;
              final itemWidth = singleColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 22) / 2;

              return Wrap(
                spacing: 22,
                runSpacing: 18,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: itemWidth,
                      child: item,
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          Text(
            isEs ? 'ES · PT' : 'PT · ES',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kTextMid,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de métrica individual — MedCases Pro style ──────────────────────────────


// ══════════════════════════════════════════════════════════════════════════════
// CTA INFERIOR DARK — verde sólido + subtítulo (diferente do dourado pill)
// ══════════════════════════════════════════════════════════════════════════════
class _R73FinalHeader extends StatelessWidget {
  final bool isEs;
  final VoidCallback onLogin;
  final VoidCallback onToggleLang;

  const _R73FinalHeader({
    required this.isEs,
    required this.onLogin,
    required this.onToggleLang,
  });

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width;

    final mobile = width < 700;

    return Container(
      height: mobile ? 72 : 78,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 18 : 34,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1115),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF252B32),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const _R74BrandLockup(),
          const Spacer(),
          InkWell(
            onTap: onToggleLang,
            borderRadius:
                BorderRadius.circular(12),
            child: Container(
              height: mobile ? 42 : 44,
              constraints: BoxConstraints(
                minWidth: mobile ? 50 : 54,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 13,
              ),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF141A20),
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color:
                      const Color(0xFF343D47),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                isEs ? 'ES' : 'PT',
                style: const TextStyle(
                  color: Color(0xFFF2F4F5),
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!mobile) ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: onLogin,
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      const Color(0xFFECEFF1),
                  side: const BorderSide(
                    color:
                        Color(0xFF343D47),
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                child: const Text(
                  'Entrar',
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          SizedBox(
            height: mobile ? 42 : 44,
            child: ElevatedButton(
              onPressed: onLogin,
              style:
                  ElevatedButton.styleFrom(
                elevation: 0,
                shadowColor:
                    Colors.transparent,
                backgroundColor:
                    const Color(0xFF00A876),
                foregroundColor:
                    Colors.white,
                padding:
                    EdgeInsets.symmetric(
                  horizontal:
                      mobile ? 15 : 22,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              child: Text(
                isEs
                    ? 'Crear cuenta gratis'
                    : 'Criar conta grátis',
                style: TextStyle(
                  fontSize:
                      mobile ? 10.5 : 13,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _R74BrandLockup
    extends StatelessWidget {
  const _R74BrandLockup();

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < 700;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: mobile ? 34 : 38,
          height: mobile ? 34 : 38,
          decoration: BoxDecoration(
            color:
                const Color(0xFF14191E),
            borderRadius:
                BorderRadius.circular(11),
            border: Border.all(
              color:
                  const Color(0xFF3A424B),
            ),
            boxShadow: const [
              BoxShadow(
                color:
                    Color(0x24000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                color:
                    const Color(0xFFF4F5F6),
                size: mobile ? 21 : 23,
              ),
              Positioned(
                right: mobile ? 5 : 6,
                top: mobile ? 5 : 6,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration:
                      const BoxDecoration(
                    color:
                        Color(0xFF00A876),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: mobile ? 9 : 11,
        ),
        Text(
          'MedCases',
          style: TextStyle(
            color:
                const Color(0xFFF5F6F7),
            fontSize:
                mobile ? 16.5 : 19,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -0.55,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'PRO',
          style: TextStyle(
            color:
                const Color(0xFF00A876),
            fontSize:
                mobile ? 16.5 : 19,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _R73FinalLanding extends StatelessWidget {
  final bool isEs;
  final VoidCallback onCreateAccount;
  final VoidCallback onAppStore;

  const _R73FinalLanding({
    required this.isEs,
    required this.onCreateAccount,
    required this.onAppStore,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final wide =
            constraints.maxWidth >= 900;

        return Column(
          children: [
            _R73FinalHero(
              isEs: isEs,
              wide: wide,
              onCreateAccount:
                  onCreateAccount,
              onAppStore:
                  onAppStore,
            ),
            _R73FinalFeatureStrip(
              isEs: isEs,
              wide: wide,
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _R73FinalHero extends StatelessWidget {
  final bool isEs;
  final bool wide;
  final VoidCallback onCreateAccount;
  final VoidCallback onAppStore;

  const _R73FinalHero({
    required this.isEs,
    required this.wide,
    required this.onCreateAccount,
    required this.onAppStore,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.sizeOf(context).width;

    return SizedBox(
      width: double.infinity,
      height: wide ? 690 : 1035,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: wide ? 650 : 610,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  '/landing/medcases-hero-clinicians.png',
                  fit: BoxFit.cover,
                  alignment:
                      Alignment.center,
                  filterQuality:
                      FilterQuality.high,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin:
                          Alignment.centerLeft,
                      end:
                          Alignment.centerRight,
                      colors: [
                        Color(0xF2101317),
                        Color(0xBC101317),
                        Color(0x52101317),
                        Color(0x0B101317),
                      ],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      stops: [
                        0,
                        0.50,
                        1,
                      ],
                      colors: [
                        Color(0x45101317),
                        Color(0x10101317),
                        Color(0xFF101317),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  width:
                      wide ? 290 : 180,
                  height: 65,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient:
                          LinearGradient(
                        begin:
                            Alignment.centerLeft,
                        end:
                            Alignment.centerRight,
                        colors: [
                          Color(0xFF101317),
                          Color(0xE8101317),
                          Color(0x00101317),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  width:
                      wide ? 170 : 110,
                  height: 78,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient:
                          LinearGradient(
                        begin:
                            Alignment.centerRight,
                        end:
                            Alignment.centerLeft,
                        colors: [
                          Color(0xFF101317),
                          Color(0xD9101317),
                          Color(0x00101317),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  width:
                      wide ? 420 : 220,
                  height: 115,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient:
                          LinearGradient(
                        begin:
                            Alignment.bottomRight,
                        end:
                            Alignment.topLeft,
                        colors: [
                          Color(0xFF101317),
                          Color(0xE6101317),
                          Color(0x00101317),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (wide) ...[
            Positioned(
              left:
                  screenWidth * 0.065,
              top: 72,
              width: 680,
              child:
                  _R73FinalHeroCopy(
                isEs: isEs,
                wide: true,
                onCreateAccount:
                    onCreateAccount,
                onAppStore:
                    onAppStore,
              ),
            ),
            Positioned(
              right:
                  screenWidth * 0.055,
              top: 205,
              child:
                  const _R73RealPhone(
                width: 310,
                tilt: -0.045,
              ),
            ),
          ] else ...[
            Positioned(
              left: 22,
              right: 22,
              top: 15,
              child:
                  _R73FinalHeroCopy(
                isEs: isEs,
                wide: false,
                onCreateAccount:
                    onCreateAccount,
                onAppStore:
                    onAppStore,
              ),
            ),
            const Positioned(
              top: 540,
              left: 0,
              right: 0,
              child: Center(
                child:
                    _R73RealPhone(
                  width: 270,
                  tilt: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _R73FinalHeroCopy
    extends StatelessWidget {
  final bool isEs;
  final bool wide;
  final VoidCallback onCreateAccount;
  final VoidCallback onAppStore;

  const _R73FinalHeroCopy({
    required this.isEs,
    required this.wide,
    required this.onCreateAccount,
    required this.onAppStore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          wide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
      children: [
        Text(
          isEs
              ? 'TU ALIADO EN LA PRÁCTICA CLÍNICA'
              : 'SEU ALIADO NA PRÁTICA CLÍNICA',
          textAlign:
              wide
                  ? TextAlign.left
                  : TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFC0C4C9),
            fontSize: 9.5,
            fontWeight:
                FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 11),
        Text(
          isEs
              ? 'IA clínica con respaldo bibliográfico para estudiar, consultar y actuar con más seguridad.'
              : 'IA clínica com referências bibliográficas para estudar, consultar e agir com mais segurança.',
          textAlign:
              wide
                  ? TextAlign.left
                  : TextAlign.center,
          style: TextStyle(
            color:
                const Color(0xFFF7F8F9),
            fontSize:
                wide ? 49 : 29.5,
            height: 1.04,
            fontWeight:
                FontWeight.w800,
            letterSpacing:
                wide ? -1.7 : -1.0,
            shadows: const [
              Shadow(
                color:
                    Color(0x99000000),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 21),
        _R73FinalBenefits(
          isEs: isEs,
          wide: wide,
        ),
        const SizedBox(height: 27),
        if (wide)
          Row(
            children: [
              _R73PrimaryCta(
                isEs: isEs,
                onTap:
                    onCreateAccount,
                width: 255,
              ),
              const SizedBox(width: 14),
              _R73SecondaryCta(
                isEs: isEs,
                onTap: onAppStore,
                width: 226,
              ),
            ],
          )
        else
          Column(
            children: [
              _R73PrimaryCta(
                isEs: isEs,
                onTap:
                    onCreateAccount,
                width:
                    double.infinity,
              ),
              const SizedBox(height: 10),
              _R73SecondaryCta(
                isEs: isEs,
                onTap: onAppStore,
                width:
                    double.infinity,
              ),
            ],
          ),
      ],
    );
  }
}

class _R73FinalBenefits
    extends StatelessWidget {
  final bool isEs;
  final bool wide;

  const _R73FinalBenefits({
    required this.isEs,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        Icons.menu_book_outlined,
        isEs
            ? 'Guías actualizadas'
            : 'Guias atualizadas',
      ),
      (
        Icons.medication_outlined,
        isEs
            ? 'Fármacos y dosis'
            : 'Fármacos e doses',
      ),
      (
        Icons.calculate_outlined,
        isEs
            ? 'Calculadoras y scores'
            : 'Calculadoras e scores',
      ),
      (
        Icons.description_outlined,
        isEs
            ? 'Respaldo bibliográfico'
            : 'Referências bibliográficas',
      ),
    ];

    return Wrap(
      alignment:
          wide
              ? WrapAlignment.start
              : WrapAlignment.center,
      spacing: wide ? 28 : 10,
      runSpacing: 12,
      children: values.map(
        (value) {
          return SizedBox(
            width:
                wide ? 248 : 166,
            child: Row(
              children: [
                Icon(
                  value.$1,
                  size: 21,
                  color:
                      const Color(
                    0xFFF0F1F3,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value.$2,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFFE3E6E9,
                      ),
                      fontSize: 12.2,
                      height: 1.25,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }
}

class _R73PrimaryCta
    extends StatelessWidget {
  final bool isEs;
  final VoidCallback onTap;
  final double width;

  const _R73PrimaryCta({
    required this.isEs,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style:
            ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              const Color(
            0xFF00A876,
          ),
          foregroundColor:
              Colors.white,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Text(
              isEs
                  ? 'Crear cuenta gratis'
                  : 'Criar conta grátis',
              style:
                  const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _R73SecondaryCta
    extends StatelessWidget {
  final bool isEs;
  final VoidCallback onTap;
  final double width;

  const _R73SecondaryCta({
    required this.isEs,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 55,
      child: OutlinedButton(
        onPressed: onTap,
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              const Color(
            0xFFF2F4F5,
          ),
          backgroundColor:
              const Color(
            0xCC15191E,
          ),
          side: const BorderSide(
            color:
                Color(
              0xFF626A74,
            ),
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.apple,
              size: 21,
            ),
            const SizedBox(width: 8),
            Text(
              isEs
                  ? 'Ver en App Store'
                  : 'Ver na App Store',
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _R73RealPhone
    extends StatelessWidget {
  final double width;
  final double tilt;

  const _R73RealPhone({
    required this.width,
    required this.tilt,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: width,
        padding:
            const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color:
              const Color(
            0xFF050607,
          ),
          borderRadius:
              BorderRadius.circular(
            39,
          ),
          border: Border.all(
            color:
                const Color(
              0xFF89919B,
            ),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color:
                  Color(
                0x79000000,
              ),
              blurRadius: 52,
              offset:
                  Offset(0, 28),
            ),
            BoxShadow(
              color:
                  Color(
                0x20FFFFFF,
              ),
              blurRadius: 16,
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio:
              941 / 2048,
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(
              31,
            ),
            child: Image.network(
              '/landing/medcases-app-current.png',
              fit: BoxFit.cover,
              alignment:
                  Alignment.topCenter,
              filterQuality:
                  FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _R73FinalFeatureStrip
    extends StatelessWidget {
  final bool isEs;
  final bool wide;

  const _R73FinalFeatureStrip({
    required this.isEs,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.menu_book_outlined,
        isEs
            ? 'Guías\nactualizadas'
            : 'Guias\natualizadas',
      ),
      (
        Icons.medication_outlined,
        'Fármacos',
      ),
      (
        Icons.calculate_outlined,
        isEs
            ? 'Calculadoras\ny scores'
            : 'Calculadoras\ne scores',
      ),
      (
        Icons.psychology_outlined,
        isEs
            ? 'IA de apoyo\nmédico'
            : 'IA de apoio\nmédico',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 60 : 18,
        vertical: wide ? 28 : 24,
      ),
      decoration:
          const BoxDecoration(
        color:
            Color(0xFF0D1013),
        border: Border(
          top: BorderSide(
            color:
                Color(
              0x18FFFFFF,
            ),
          ),
          bottom: BorderSide(
            color:
                Color(
              0x12FFFFFF,
            ),
          ),
        ),
      ),
      child: Wrap(
        alignment:
            WrapAlignment.center,
        spacing: wide ? 80 : 12,
        runSpacing: 22,
        children: items.map(
          (item) {
            return SizedBox(
              width:
                  wide ? 170 : 155,
              child: Column(
                children: [
                  Icon(
                    item.$1,
                    size: 28,
                    color:
                        const Color(
                      0xFFE6E9EC,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    item.$2,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFFE6E9EC,
                      ),
                      fontSize: 12,
                      height: 1.25,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ).toList(),
      ),
    );
  }
}
class _R75ReferenceHeader extends StatelessWidget {
  final bool isEs;
  final VoidCallback onLogin;
  final VoidCallback onToggleLang;

  const _R75ReferenceHeader({
    required this.isEs,
    required this.onLogin,
    required this.onToggleLang,
  });

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < 700;

    return Container(
      height: mobile ? 56 : 62,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 14 : 26,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F13),
        border: Border(
          bottom: BorderSide(
            color: Color(0x12FFFFFF),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: mobile ? 36 : 40,
            height: mobile ? 36 : 40,
            child: Image.asset(
              'assets/icon/splash_mplus_premium.png',
              fit: BoxFit.contain,
              filterQuality:
                  FilterQuality.high,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onToggleLang,
            borderRadius:
                BorderRadius.circular(4),
            child: const Padding(
              padding:
                  EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 8,
              ),
              child: Text(
                'ES / PT',
                style: TextStyle(
                  color:
                      Color(0xFFC8CDD2),
                  fontSize: 11.5,
                  fontWeight:
                      FontWeight.w500,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
          SizedBox(
            width: mobile ? 13 : 17,
          ),
          SizedBox(
            height: mobile ? 33 : 35,
            child: OutlinedButton(
              onPressed: onLogin,
              style:
                  OutlinedButton.styleFrom(
                elevation: 0,
                foregroundColor:
                    const Color(
                  0xFFE9ECEF,
                ),
                backgroundColor:
                    Colors.transparent,
                side: const BorderSide(
                  color:
                      Color(
                    0x38FFFFFF,
                  ),
                  width: 1,
                ),
                padding:
                    EdgeInsets.symmetric(
                  horizontal:
                      mobile ? 12 : 15,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
              ),
              child: Text(
                isEs
                    ? 'Acceso gratis'
                    : 'Acesso grátis',
                style: TextStyle(
                  fontSize:
                      mobile ? 10.4 : 11.3,
                  fontWeight:
                      FontWeight.w600,
                  letterSpacing: -0.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _R75Brand extends StatelessWidget {
  const _R75Brand();

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < 700;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: mobile ? 35 : 40,
          height: mobile ? 38 : 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: mobile ? 29 : 33,
                color: const Color(0xFFE8ECEF),
              ),
              Positioned(
                left: mobile ? 8 : 9,
                bottom: mobile ? 4 : 4,
                child: Icon(
                  Icons.monitor_heart_outlined,
                  size: mobile ? 21 : 23,
                  color: const Color(0xFF00A876),
                ),
              ),
              Positioned(
                right: mobile ? 3 : 3,
                top: mobile ? 3 : 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00A876),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: mobile ? 7 : 9,
        ),
        Text(
          'MedCases',
          style: TextStyle(
            color: const Color(0xFFF5F6F7),
            fontSize: mobile ? 16.5 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.65,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'PRO',
          style: TextStyle(
            color: const Color(0xFF00A876),
            fontSize: mobile ? 16.5 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.55,
          ),
        ),
      ],
    );
  }
}

class _R75ReferenceLanding extends StatelessWidget {
  final bool isEs;
  final VoidCallback onCreateAccount;
  final VoidCallback onAppStore;

  const _R75ReferenceLanding({
    required this.isEs,
    required this.onCreateAccount,
    required this.onAppStore,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final wide =
            constraints.maxWidth >= 900;

        return _R75ReferenceHero(
          isEs: isEs,
          wide: wide,
        );
      },
    );
  }
}

class _R75ReferenceHero extends StatelessWidget {
  final bool isEs;
  final bool wide;

  const _R75ReferenceHero({
    required this.isEs,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width;

    if (wide) {
      return _R75DesktopHero(
        isEs: isEs,
        width: width,
      );
    }

    return _R75MobileHero(
      isEs: isEs,
    );
  }
}

class _R75MobileHero extends StatelessWidget {
  final bool isEs;

  const _R75MobileHero({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.sizeOf(context).width;

    final phoneWidth =
        screenWidth < 390 ? 258.0 : 276.0;

    return SizedBox(
      width: double.infinity,
      height: 1490,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0C1115),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 980,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  '/landing/medcases-hero-clinicians.png',
                  fit: BoxFit.cover,
                  alignment:
                      const Alignment(0.22, -0.12),
                  filterQuality:
                      FilterQuality.high,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: [
                        0,
                        0.46,
                        0.78,
                        1,
                      ],
                      colors: [
                        Color(0xF50B1014),
                        Color(0xCC0B1014),
                        Color(0x4A0B1014),
                        Color(0x150B1014),
                      ],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [
                        0,
                        0.44,
                        0.76,
                        1,
                      ],
                      colors: [
                        Color(0x240B1014),
                        Color(0x160B1014),
                        Color(0x9E0B1014),
                        Color(0xFF0B1014),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 15,
            child: _R75HeroCopy(
              isEs: isEs,
              mobile: true,
            ),
          ),
          Positioned(
            top: 495,
            left: 0,
            right: 0,
            child: Center(
              child: _R75Phone(
                width: phoneWidth,
              ),
            ),
          ),
          Positioned(
            left: 22,
            top: 680,
            width: 76,
            child: _R75SideMessage(
              isEs: isEs,
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 34,
            child: _R75Disclaimer(
              isEs: isEs,
            ),
          ),
        ],
      ),
    );
  }
}

class _R75DesktopHero extends StatelessWidget {
  final bool isEs;
  final double width;

  const _R75DesktopHero({
    required this.isEs,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 790,
      child: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  '/landing/medcases-hero-clinicians.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality:
                      FilterQuality.high,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xF20B1014),
                        Color(0xC70B1014),
                        Color(0x450B1014),
                        Color(0x130B1014),
                      ],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x120B1014),
                        Color(0x360B1014),
                        Color(0xFF0B1014),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: width * 0.055,
            top: 28,
            width: 660,
            child: _R75HeroCopy(
              isEs: isEs,
              mobile: false,
            ),
          ),
          Positioned(
            right: width * 0.075,
            top: 205,
            child: const _R75Phone(
              width: 310,
            ),
          ),
          Positioned(
            left: width * 0.055,
            bottom: 90,
            width: 145,
            child: _R75SideMessage(
              isEs: isEs,
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            bottom: 24,
            child: _R75Disclaimer(
              isEs: isEs,
            ),
          ),
        ],
      ),
    );
  }
}

class _R75HeroCopy extends StatelessWidget {
  final bool isEs;
  final bool mobile;

  const _R75HeroCopy({
    required this.isEs,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          isEs
              ? 'TU ALIADO EN LA PRÁCTICA CLÍNICA'
              : 'SEU ALIADO NA PRÁTICA CLÍNICA',
          style: TextStyle(
            color: const Color(0xFFC4C8CC),
            fontSize: mobile ? 9 : 10,
            fontWeight: FontWeight.w600,
            letterSpacing:
                mobile ? 2.2 : 2.6,
          ),
        ),
        SizedBox(
          height: mobile ? 12 : 17,
        ),
        Text(
          isEs
              ? 'IA clínica con respaldo bibliográfico para estudiar, consultar y actuar con más seguridad.'
              : 'IA clínica com referências bibliográficas para estudar, consultar e agir com mais segurança.',
          style: TextStyle(
            color: const Color(0xFFF4F5F6),
            fontSize: mobile ? 29 : 48,
            height: 1.04,
            fontWeight: FontWeight.w800,
            letterSpacing:
                mobile ? -1.05 : -1.7,
            shadows: const [
              Shadow(
                color: Color(0xA8000000),
                blurRadius: 22,
              ),
            ],
          ),
        ),
        SizedBox(
          height: mobile ? 24 : 30,
        ),
        _R75BenefitGrid(
          isEs: isEs,
          mobile: mobile,
        ),
      ],
    );
  }
}

class _R75BenefitGrid extends StatelessWidget {
  final bool isEs;
  final bool mobile;

  const _R75BenefitGrid({
    required this.isEs,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      (
        Icons.menu_book_outlined,
        isEs
            ? 'Guías actualizadas'
            : 'Guias atualizadas',
      ),
      (
        Icons.medication_outlined,
        isEs
            ? 'Fármacos y dosis'
            : 'Fármacos e doses',
      ),
      (
        Icons.calculate_outlined,
        isEs
            ? 'Calculadoras y scores'
            : 'Calculadoras e scores',
      ),
      (
        Icons.description_outlined,
        isEs
            ? 'Respaldo bibliográfico'
            : 'Referências bibliográficas',
      ),
    ];

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final itemWidth =
            mobile
                ? (constraints.maxWidth - 12) / 2
                : 250.0;

        return Wrap(
          spacing: mobile ? 12 : 30,
          runSpacing: mobile ? 18 : 17,
          children: values.map(
            (value) {
              return SizedBox(
                width: itemWidth,
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: mobile ? 30 : 34,
                      child: Icon(
                        value.$1,
                        size: mobile ? 24 : 27,
                        color:
                            const Color(0xFFF1F3F4),
                      ),
                    ),
                    SizedBox(
                      width: mobile ? 8 : 10,
                    ),
                    Expanded(
                      child: Text(
                        value.$2,
                        style: TextStyle(
                          color:
                              const Color(0xFFE7E9EB),
                          fontSize:
                              mobile ? 11.6 : 13,
                          height: 1.18,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),
        );
      },
    );
  }
}

class _R75Phone extends StatelessWidget {
  final double width;

  const _R75Phone({
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF050607),
        borderRadius:
            BorderRadius.circular(39),
        border: Border.all(
          color: const Color(0xFF9299A1),
          width: 1.25,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xA3000000),
            blurRadius: 52,
            offset: Offset(0, 28),
          ),
          BoxShadow(
            color: Color(0x1FFFFFFF),
            blurRadius: 16,
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 941 / 2048,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(32),
          child: Image.network(
            '/landing/medcases-app-current.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality:
                FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _R75SideMessage extends StatelessWidget {
  final bool isEs;

  const _R75SideMessage({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 2,
          color: const Color(0xFF00A876),
        ),
        const SizedBox(height: 12),
        Text(
          isEs
              ? 'MEJOR\nCONOCIMIENTO\nMEJORES\nDECISIONES\nMÁS VIDAS'
              : 'MAIS\nCONHECIMENTO\nMELHORES\nDECISÕES\nMAIS VIDAS',
          style: const TextStyle(
            color: Color(0xFFC7CBD0),
            fontSize: 8,
            height: 1.55,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.7,
          ),
        ),
      ],
    );
  }
}

class _R75Disclaimer extends StatelessWidget {
  final bool isEs;

  const _R75Disclaimer({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Divider(
                color: Color(0xFF00A876),
                thickness: 1,
                endIndent: 15,
              ),
            ),
            Text(
              isEs
                  ? 'HERRAMIENTA EDUCATIVA DE APOYO CLÍNICO'
                  : 'FERRAMENTA EDUCATIVA DE APOIO CLÍNICO',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD8DCE0),
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
            const Expanded(
              child: Divider(
                color: Color(0xFF00A876),
                thickness: 1,
                indent: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          isEs
              ? 'La decisión y verificación de dosis son responsabilidad exclusiva del médico asistente.'
              : 'A decisão e a verificação das doses são responsabilidade exclusiva do médico assistente.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9FA5AB),
            fontSize: 9,
            height: 1.35,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
class _R77Header extends StatelessWidget {
  final bool isEs;
  final VoidCallback onLogin;
  final VoidCallback onToggleLang;

  const _R77Header({
    required this.isEs,
    required this.onLogin,
    required this.onToggleLang,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    final mobile =
        MediaQuery.sizeOf(context).width < 700;

    return Container(
      height: mobile ? 58 : 66,
      decoration: const BoxDecoration(
        color: Color(0xFF080D11),
        border: Border(
          bottom: BorderSide(
            color: Color(0x22FFFFFF),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 1100,
          ),
          child: Padding(
            padding:
                EdgeInsets.symmetric(
              horizontal:
                  mobile ? 14 : 28,
            ),
            child: Row(
              children: [
                SizedBox(
                  width:
                      mobile ? 34 : 39,
                  height:
                      mobile ? 34 : 39,
                  child: Image.asset(
                    'assets/icon/splash_mplus_premium.png',
                    fit: BoxFit.contain,
                    filterQuality:
                        FilterQuality.high,
                  ),
                ),
                SizedBox(
                  width:
                      mobile ? 7 : 10,
                ),
                Text(
                  'MedCases',
                  style:
                      theme.titleMedium
                          ?.copyWith(
                    color:
                        const Color(
                      0xFFF2F3F4,
                    ),
                    fontSize:
                        mobile
                            ? 15.5
                            : 19,
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing:
                        -0.35,
                  ),
                ),
                const SizedBox(
                  width: 5,
                ),
                Text(
                  'PRO',
                  style:
                      theme.titleMedium
                          ?.copyWith(
                    color:
                        const Color(
                      0xFF00B978,
                    ),
                    fontSize:
                        mobile
                            ? 15.5
                            : 19,
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing:
                        -0.25,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onToggleLang,
                  borderRadius:
                      BorderRadius.circular(
                    4,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 3,
                      vertical: 8,
                    ),
                    child: Text(
                      'ES / PT',
                      style:
                          theme.labelMedium
                              ?.copyWith(
                        color:
                            const Color(
                          0xFFC7CCD1,
                        ),
                        fontSize:
                            mobile
                                ? 10.5
                                : 11.5,
                        fontWeight:
                            FontWeight.w500,
                        letterSpacing:
                            0.15,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width:
                      mobile ? 11 : 16,
                ),
                SizedBox(
                  height:
                      mobile ? 33 : 36,
                  child:
                      OutlinedButton(
                    onPressed: onLogin,
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          const Color(
                        0xFFF0F2F3,
                      ),
                      backgroundColor:
                          Colors
                              .transparent,
                      side:
                          const BorderSide(
                        color:
                            Color(
                          0x9900B978,
                        ),
                        width: 1,
                      ),
                      padding:
                          EdgeInsets
                              .symmetric(
                        horizontal:
                            mobile
                                ? 11
                                : 15,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          9,
                        ),
                      ),
                    ),
                    child: Text(
                      isEs
                          ? 'Acceso gratis'
                          : 'Acesso grátis',
                      style:
                          theme.labelLarge
                              ?.copyWith(
                        fontSize:
                            mobile
                                ? 10.1
                                : 11.2,
                        fontWeight:
                            FontWeight.w600,
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

class _R77Landing extends StatelessWidget {
  final bool isEs;
  final VoidCallback onCreateAccount;
  final VoidCallback onAppStore;

  const _R77Landing({
    required this.isEs,
    required this.onCreateAccount,
    required this.onAppStore,
  });

  @override
  Widget build(BuildContext context) {
    final viewportWidth =
        MediaQuery.sizeOf(context).width;

    return UnconstrainedBox(
      alignment: Alignment.topCenter,
      constrainedAxis: Axis.vertical,
      child: SizedBox(
        width: viewportWidth,
        child: _R717PremiumPosterHero(
          isEs: isEs,
          width: viewportWidth,
        ),
      ),
    );
  }
}

class _R717PremiumPosterHero
    extends StatelessWidget {
  final bool isEs;
  final double width;

  const _R717PremiumPosterHero({
    required this.isEs,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = width < 700;
    final tablet =
        width >= 700 && width < 1100;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color:
                const Color(
              0xFF071016,
            ),
            borderRadius:
                BorderRadius.zero,
            border: mobile
                ? null
                : Border.all(
                    color:
                        const Color(
                      0xFF172B34,
                    ),
                  ),
            boxShadow: mobile
                ? null
                : const [
                    BoxShadow(
                      color:
                          Color(
                        0x2400C98B,
                      ),
                      blurRadius: 38,
                      spreadRadius: 1,
                      offset:
                          Offset(
                        0,
                        12,
                      ),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  mobile
                          ? '/landing/medcases-bg-mobile.png'
                          : '/landing/medcases-bg-desktop.png',
                  fit: BoxFit.cover,
                  alignment: mobile
                      ? const Alignment(0.62, 0.0)
                      : const Alignment(0.18, 0.0),
                  filterQuality:
                      FilterQuality.high,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.centerLeft,
                      end:
                          Alignment.centerRight,
                      colors: mobile
                          ? const [
                              Color(
                                0xF5071016,
                              ),
                              Color(
                                0xDE071016,
                              ),
                              Color(
                                0x7204100D,
                              ),
                            ]
                          : const [
                              Color(
                                0xFC071016,
                              ),
                              Color(
                                0xF1071016,
                              ),
                              Color(
                                0xA2081713,
                              ),
                              Color(
                                0x46000C09,
                              ),
                            ],
                      stops: mobile
                          ? const [
                              0,
                              0.60,
                              1,
                            ]
                          : const [
                              0,
                              0.38,
                              0.69,
                              1,
                            ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration:
                      const BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      stops: [
                        0,
                        0.73,
                        1,
                      ],
                      colors: [
                        Color(
                          0x08000000,
                        ),
                        Color(
                          0x28000000,
                        ),
                        Color(
                          0xFF071016,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.fromLTRB(
                  mobile ? 20 : 48,
                  mobile ? 36 : 54,
                  mobile ? 20 : 48,
                  mobile ? 24 : 42,
                ),
                child: mobile
                    ? Column(
                        children: [
                          _R721R3PremiumCopy(
                            isEs: isEs,
                            mobile: true,
                          ),
                          const SizedBox(
                            height: 26,
                          ),
                          _R717DeviceStage(
                            mobile: true,
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Expanded(
                            flex:
                                tablet
                                    ? 10
                                    : 9,
                            child:
                                _R721R3PremiumCopy(
                              isEs: isEs,
                            ),
                          ),
                          const SizedBox(
                            width: 28,
                          ),
                          Expanded(
                            flex:
                                tablet
                                    ? 9
                                    : 10,
                            child:
                                const _R717DeviceStage(
                              mobile: false,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: mobile ? 20 : 28,
        ),
        _R710StoreButtons(
          isEs: isEs,
        ),
        SizedBox(
          height: mobile ? 30 : 44,
        ),
        _R717PlansIntro(
          isEs: isEs,
          mobile: mobile,
        ),
        SizedBox(
          height: mobile ? 20 : 28,
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal:
                mobile ? 12 : 62,
          ),
          child:
              _R719PricingSection(
            isEs: isEs,
          ),
        ),
        SizedBox(
          height: mobile ? 24 : 34,
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal:
                mobile ? 18 : 90,
          ),
          child: _R77Disclaimer(
            isEs: isEs,
          ),
        ),
        SizedBox(
          height: mobile ? 28 : 40,
        ),
      ],
    );
  }
}

class _R717DeviceStage
    extends StatelessWidget {
  final bool mobile;

  const _R717DeviceStage({
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final available =
            constraints.maxWidth;

        final homeWidth = mobile
            ? 224.0
            : (available * 0.53)
                .clamp(
                  240.0,
                  310.0,
                )
                .toDouble();

        final aiWidth = mobile
            ? 158.0
            : (available * 0.36)
                .clamp(
                  170.0,
                  220.0,
                )
                .toDouble();

        final stageHeight =
            mobile ? 650.0 : 815.0;

        return SizedBox(
          height: stageHeight,
          child: Stack(
            clipBehavior:
                Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom:
                    mobile ? 10 : 18,
                child:
                    IgnorePointer(
                  child: Center(
                    child: Container(
                      width:
                          mobile
                              ? 280
                              : 370,
                      height: 28,
                      decoration:
                          const BoxDecoration(
                        borderRadius:
                            BorderRadius.all(
                          Radius.elliptical(
                            185,
                            24,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Color(
                              0x6500C98B,
                            ),
                            blurRadius: 46,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right:
                    mobile ? 0 : 4,
                top:
                    mobile ? 35 : 42,
                child:
                    Transform.rotate(
                  angle:
                      mobile
                          ? 0.025
                          : 0.020,
                  child:
                      _R713AiPhone(
                    width: aiWidth,
                  ),
                ),
              ),
              Positioned(
                left:
                    mobile ? 4 : 0,
                top:
                    mobile ? 115 : 92,
                child:
                    _R79ScrollPhone(
                  width: homeWidth,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _R717PlansIntro
    extends StatelessWidget {
  final bool isEs;
  final bool mobile;

  const _R717PlansIntro({
    required this.isEs,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Padding(
      padding:
          EdgeInsets.symmetric(
        horizontal:
            mobile ? 22 : 40,
      ),
      child: Column(
        children: [
          Text(
            isEs
                ? 'PLANES'
                : 'PLANOS',
            style:
                theme.labelSmall
                    ?.copyWith(
              color:
                  const Color(
                0xFF87949E,
              ),
              fontSize: 9,
              fontWeight:
                  FontWeight.w700,
              letterSpacing: 3.5,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            textAlign:
                TextAlign.center,
            text: TextSpan(
              style:
                  theme.headlineMedium
                      ?.copyWith(
                color:
                    const Color(
                  0xFFF1F3F4,
                ),
                fontSize:
                    mobile ? 26 : 34,
                height: 1.05,
                fontWeight:
                    FontWeight.w800,
                letterSpacing: -0.9,
              ),
              children: [
                TextSpan(
                  text: isEs
                      ? 'Conocimiento médico para llegar '
                      : 'Conhecimento médico para chegar ',
                ),
                const TextSpan(
                  text: 'más lejos',
                  style: TextStyle(
                    color:
                        Color(
                      0xFF28D5A0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isEs
                ? 'Elige el acceso que mejor acompaña tu formación y tu práctica.'
                : 'Escolha o acesso que melhor acompanha sua formação e sua prática.',
            textAlign:
                TextAlign.center,
            style:
                theme.bodyMedium
                    ?.copyWith(
              color:
                  const Color(
                0xFFA9B3BA,
              ),
              fontSize:
                  mobile ? 11.5 : 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _R77PosterHero extends StatelessWidget {
  final bool isEs;
  final double width;

  const _R77PosterHero({
    required this.isEs,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = width < 700;
    final tablet =
        width >= 700 && width < 1050;

    final theme =
        Theme.of(context).textTheme;

    final heroHeight =
        mobile
            ? 950.0
            : tablet
                ? 720.0
                : 690.0;

    final primaryPhoneWidth =
        mobile
            ? 214.0
            : tablet
                ? 245.0
                : 290.0;

    final secondaryPhoneWidth =
        mobile
            ? 150.0
            : tablet
                ? 180.0
                : 205.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: heroHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.network(
                  '/landing/medcases-hero-clinicians.png',
                  fit: BoxFit.cover,
                  alignment:
                      mobile
                          ? const Alignment(
                              0.32,
                              0,
                            )
                          : Alignment.centerRight,
                  filterQuality:
                      FilterQuality.high,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.centerLeft,
                      end:
                          Alignment.centerRight,
                      stops:
                          mobile
                              ? const [
                                  0,
                                  0.50,
                                  1,
                                ]
                              : const [
                                  0,
                                  0.44,
                                  0.72,
                                  1,
                                ],
                      colors:
                          mobile
                              ? const [
                                  Color(
                                    0xF2080D11,
                                  ),
                                  Color(
                                    0xD8080D11,
                                  ),
                                  Color(
                                    0x7A07130F,
                                  ),
                                ]
                              : const [
                                  Color(
                                    0xFA080D11,
                                  ),
                                  Color(
                                    0xE7080D11,
                                  ),
                                  Color(
                                    0x6A07130F,
                                  ),
                                  Color(
                                    0x32000E0B,
                                  ),
                                ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration:
                      const BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      stops: [
                        0,
                        0.70,
                        1,
                      ],
                      colors: [
                        Color(
                          0x12000000,
                        ),
                        Color(
                          0x24000000,
                        ),
                        Color(
                          0xFF080D11,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!mobile) ...[
                Positioned(
                  left:
                      tablet ? 36 : 72,
                  top: tablet ? 56 : 70,
                  width:
                      tablet ? 300 : 410,
                  child:
                      _R713PremiumCopy(
                    isEs: isEs,
                  ),
                ),
                Positioned(
                  right:
                      tablet ? 164 : 245,
                  top:
                      tablet ? 78 : 52,
                  child: Transform.rotate(
                    angle: -0.035,
                    child:
                        _R79ScrollPhone(
                      width:
                          primaryPhoneWidth,
                    ),
                  ),
                ),
                Positioned(
                  right:
                      tablet ? 20 : 54,
                  top:
                      tablet ? 185 : 155,
                  child: Transform.rotate(
                    angle: 0.026,
                    child:
                        _R713AiPhone(
                      width:
                          secondaryPhoneWidth,
                    ),
                  ),
                ),
              ] else ...[
                Positioned(
                  top: 38,
                  left: 20,
                  right: 20,
                  child:
                      _R713PremiumCopy(
                    isEs: isEs,
                    mobile: true,
                  ),
                ),
                Positioned(
                  top: 485,
                  left: 38,
                  child: Transform.rotate(
                    angle: -0.025,
                    child:
                        _R79ScrollPhone(
                      width:
                          primaryPhoneWidth,
                    ),
                  ),
                ),
                Positioned(
                  top: 558,
                  right: 26,
                  child: Transform.rotate(
                    angle: 0.022,
                    child:
                        _R713AiPhone(
                      width:
                          secondaryPhoneWidth,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _R713SectionKicker(
          titleEs: 'DISPONIBLE EN',
          titlePt: 'DISPONÍVEL EM',
        ),
        const SizedBox(height: 12),
        _R710StoreButtons(
          isEs: isEs,
        ),
        SizedBox(
          height: mobile ? 28 : 36,
        ),
        Text(
          isEs
              ? 'Elige tu camino'
              : 'Escolha seu caminho',
          textAlign: TextAlign.center,
          style:
              theme.headlineSmall
                  ?.copyWith(
            color:
                const Color(
              0xFFF3F5F5,
            ),
            fontSize:
                mobile ? 25 : 32,
            height: 1,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 9),
        Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal:
                mobile ? 20 : 40,
          ),
          child: Text(
            isEs
                ? 'Todo lo que necesitas para llevar tu conocimiento al siguiente nivel.'
                : 'Tudo o que você precisa para levar seu conhecimento ao próximo nível.',
            textAlign:
                TextAlign.center,
            style:
                theme.bodyMedium
                    ?.copyWith(
              color:
                  const Color(
                0xFFADB4BA,
              ),
              fontSize:
                  mobile
                      ? 11.5
                      : 13.5,
              height: 1.35,
              fontWeight:
                  FontWeight.w400,
            ),
          ),
        ),
        SizedBox(
          height: mobile ? 20 : 26,
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal:
                mobile ? 12 : 72,
          ),
          child:
              _R711PricingSection(
            isEs: isEs,
          ),
        ),
        SizedBox(
          height: mobile ? 22 : 30,
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal:
                mobile ? 18 : 110,
          ),
          child: _R77Disclaimer(
            isEs: isEs,
          ),
        ),
        SizedBox(
          height: mobile ? 24 : 34,
        ),
      ],
    );
  }
}

class _R721R3PremiumCopy
    extends StatelessWidget {
  final bool isEs;
  final bool mobile;

  const _R721R3PremiumCopy({
    required this.isEs,
    this.mobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final features = isEs
        ? const <_R721R3FeatureSpec>[
            _R721R3FeatureSpec(
              icon: Icons.psychology_alt_outlined,
              title: 'IA para consultas clínicas',
              subtitle: 'Respuestas rápidas para casos y dudas.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.medication_outlined,
              title: 'Fármacos auditados y actualizados',
              subtitle: 'Biblioteca completa para consulta rápida.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.calculate_outlined,
              title: 'Cálculo de dosis por peso',
              subtitle: 'Herramientas para cálculos más ágiles.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.local_hospital_outlined,
              title: 'Modo Guardia',
              subtitle: 'Acceso rápido durante tus turnos.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.mic_none_outlined,
              title: 'Transcripción clínica',
              subtitle: 'Convierte audio en texto organizado.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.description_outlined,
              title: 'Historia clínica por voz',
              subtitle: 'Documenta mientras realizas la consulta.',
            ),
          ]
        : const <_R721R3FeatureSpec>[
            _R721R3FeatureSpec(
              icon: Icons.psychology_alt_outlined,
              title: 'IA para consultas clínicas',
              subtitle: 'Respostas rápidas para casos e dúvidas.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.medication_outlined,
              title: 'Fármacos auditados e atualizados',
              subtitle: 'Biblioteca completa para consulta rápida.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.calculate_outlined,
              title: 'Cálculo de doses por peso',
              subtitle: 'Ferramentas para cálculos mais ágeis.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.local_hospital_outlined,
              title: 'Modo Plantão',
              subtitle: 'Acesso rápido durante seus plantões.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.mic_none_outlined,
              title: 'Transcrição clínica',
              subtitle: 'Transforme áudio em texto organizado.',
            ),
            _R721R3FeatureSpec(
              icon: Icons.description_outlined,
              title: 'História clínica por voz',
              subtitle: 'Documente enquanto realiza a consulta.',
            ),
          ];

    return Column(
      crossAxisAlignment: mobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          isEs
              ? 'CONOCIMIENTO REAL'
              : 'CONHECIMENTO REAL',
          textAlign: mobile
              ? TextAlign.center
              : TextAlign.left,
          style: TextStyle(
            color: const Color(
              0xFFB7C2CB,
            ),
            fontSize: mobile
                ? 10
                : 11,
            fontWeight:
                FontWeight.w700,
            letterSpacing: 3.8,
          ),
        ),
        SizedBox(
          height: mobile
              ? 15
              : 17,
        ),
        RichText(
          textAlign: mobile
              ? TextAlign.center
              : TextAlign.left,
          text: TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile
                  ? 34
                  : 52,
              height: 1.02,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -1.1,
            ),
            children: [
              TextSpan(
                text: isEs
                    ? 'Mejores médicos'
                    : 'Melhores médicos',
              ),
              TextSpan(
                text: isEs
                    ? '\nempiezan aquí'
                    : '\ncomeçam aqui',
                style:
                    const TextStyle(
                  color: Color(
                    0xFF00D084,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: mobile
              ? 16
              : 18,
        ),
        ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 540,
          ),
          child: Text(
            isEs
                ? 'Casos clínicos, herramientas e IA para aprender, consultar y trabajar con más agilidad.'
                : 'Casos clínicos, ferramentas e IA para aprender, consultar e trabalhar com mais agilidade.',
            textAlign: mobile
                ? TextAlign.center
                : TextAlign.left,
            style: TextStyle(
              color: const Color(
                0xFFD3DDE4,
              ),
              fontSize: mobile
                  ? 14.5
                  : 17,
              height: 1.45,
            ),
          ),
        ),
        SizedBox(
          height: mobile
              ? 22
              : 27,
        ),
        _R721R3FeatureGrid(
          mobile: mobile,
          features: features,
        ),
      ],
    );
  }
}

class _R721R3FeatureGrid
    extends StatelessWidget {
  final bool mobile;
  final List<_R721R3FeatureSpec> features;

  const _R721R3FeatureGrid({
    required this.mobile,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing:
            mobile ? 10 : 12,
        mainAxisSpacing:
            mobile ? 10 : 12,
        mainAxisExtent:
            mobile ? 108 : 116,
      ),
      itemBuilder: (
        context,
        index,
      ) {
        return _R721R3FeatureCard(
          mobile: mobile,
          feature: features[index],
        );
      },
    );
  }
}

class _R721R3FeatureSpec {
  final IconData icon;
  final String title;
  final String subtitle;

  const _R721R3FeatureSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _R721R3FeatureCard
    extends StatelessWidget {
  final bool mobile;
  final _R721R3FeatureSpec feature;

  const _R721R3FeatureCard({
    required this.mobile,
    required this.feature,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        mobile ? 11 : 13,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xB50A151D,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: const Color(
            0x4000CB91,
          ),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(
              0x1600CB91,
            ),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: mobile
                ? 31
                : 34,
            height: mobile
                ? 31
                : 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0x1900CB91,
              ),
              border: Border.all(
                color: const Color(
                  0x6500D49A,
                ),
              ),
            ),
            child: Icon(
              feature.icon,
              size: mobile
                  ? 16
                  : 18,
              color: const Color(
                0xFF29D6A0,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: mobile
                        ? 11.5
                        : 13,
                    height: 1.08,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Expanded(
                  child: Text(
                    feature.subtitle,
                    maxLines: 3,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(
                        0xFF9FADB7,
                      ),
                      fontSize: mobile
                          ? 9.4
                          : 10.3,
                      height: 1.22,
                    ),
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

class _R713PremiumCopy
    extends StatelessWidget {
  final bool isEs;
  final bool mobile;

  const _R713PremiumCopy({
    required this.isEs,
    this.mobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment:
          mobile
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      children: [
        Text(
          isEs
              ? 'CONOCIMIENTO REAL'
              : 'CONHECIMENTO REAL',
          textAlign:
              mobile
                  ? TextAlign.center
                  : TextAlign.left,
          style:
              theme.labelSmall
                  ?.copyWith(
            color:
                const Color(
              0xFFB7BDC2,
            ),
            fontSize:
                mobile ? 8.1 : 9.2,
            fontWeight:
                FontWeight.w500,
            letterSpacing:
                mobile ? 2.4 : 3.1,
          ),
        ),
        SizedBox(
          height: mobile ? 12 : 16,
        ),
        RichText(
          textAlign:
              mobile
                  ? TextAlign.center
                  : TextAlign.left,
          text: TextSpan(
            style:
                theme.headlineLarge
                    ?.copyWith(
              color:
                  const Color(
                0xFFF4F5F6,
              ),
              fontSize:
                  mobile ? 34 : 48,
              height: 1.02,
              fontWeight:
                  FontWeight.w800,
              letterSpacing:
                  mobile
                      ? -1.1
                      : -1.7,
            ),
            children: [
              TextSpan(
                text:
                    isEs
                        ? 'Mejores médicos\n'
                        : 'Melhores médicos\n',
              ),
              TextSpan(
                text:
                    isEs
                        ? 'empiezan aquí'
                        : 'começam aqui',
                style: const TextStyle(
                  color:
                      Color(
                    0xFF00BE80,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: mobile ? 15 : 20,
        ),
        Text(
          isEs
              ? 'Casos clínicos, herramientas y simulación con IA para un aprendizaje más práctico, rápido y efectivo.'
              : 'Casos clínicos, ferramentas e simulação com IA para um aprendizado mais prático, rápido e efetivo.',
          textAlign:
              mobile
                  ? TextAlign.center
                  : TextAlign.left,
          style:
              theme.bodyLarge
                  ?.copyWith(
            color:
                const Color(
              0xFFD0D4D7,
            ),
            fontSize:
                mobile ? 11.8 : 15,
            height: 1.42,
            fontWeight:
                FontWeight.w400,
          ),
        ),
        SizedBox(
          height: mobile ? 18 : 26,
        ),
        _R713Feature(
          icon:
              Icons.school_outlined,
          title:
              isEs
                  ? 'Casos clínicos reales'
                  : 'Casos clínicos reais',
          subtitle:
              isEs
                  ? 'Aprende con la práctica'
                  : 'Aprenda com a prática',
          mobile: mobile,
        ),
        SizedBox(
          height: mobile ? 10 : 15,
        ),
        _R713Feature(
          icon:
              Icons.psychology_outlined,
          title:
              isEs
                  ? 'IA especializada'
                  : 'IA especializada',
          subtitle:
              isEs
                  ? 'Responde tus dudas al instante'
                  : 'Responde suas dúvidas na hora',
          mobile: mobile,
        ),
        SizedBox(
          height: mobile ? 10 : 15,
        ),
        _R713Feature(
          icon:
              Icons.insights_outlined,
          title:
              isEs
                  ? 'Simulación interactiva'
                  : 'Simulação interativa',
          subtitle:
              isEs
                  ? 'Pon a prueba tus conocimientos'
                  : 'Coloque seu conhecimento à prova',
          mobile: mobile,
        ),
      ],
    );
  }
}

class _R713Feature
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool mobile;

  const _R713Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Row(
      mainAxisSize:
          mobile
              ? MainAxisSize.min
              : MainAxisSize.max,
      mainAxisAlignment:
          mobile
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
      children: [
        Container(
          width: mobile ? 37 : 44,
          height: mobile ? 37 : 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                const Color(
              0x1000BE80,
            ),
            border: Border.all(
              color:
                  const Color(
                0x9900BE80,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: mobile ? 19 : 22,
            color:
                const Color(
              0xFF53E0B3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    theme.titleSmall
                        ?.copyWith(
                  color:
                      const Color(
                    0xFFF0F2F3,
                  ),
                  fontSize:
                      mobile
                          ? 11
                          : 13.5,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style:
                    theme.bodySmall
                        ?.copyWith(
                  color:
                      const Color(
                    0xFFABB2B7,
                  ),
                  fontSize:
                      mobile
                          ? 9
                          : 11.2,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _R713AiPhone
    extends StatelessWidget {
  final double width;

  const _R713AiPhone({
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    Widget currentFallback() {
      return Image.network(
        '/landing/medcases-app-current.png',
        fit: BoxFit.cover,
        alignment:
            Alignment.topCenter,
        filterQuality:
            FilterQuality.high,
      );
    }

    return Container(
      width: width,
      padding:
          const EdgeInsets.all(4.5),
      decoration: BoxDecoration(
        color:
            const Color(
          0xFF030506,
        ),
        borderRadius:
            BorderRadius.circular(34),
        border: Border.all(
          color:
              const Color(
            0xFF747C82,
          ),
          width: 1.1,
        ),
        boxShadow: const [
          BoxShadow(
            color:
                Color(
              0x4C00BE80,
            ),
            blurRadius: 34,
            spreadRadius: 1,
          ),
          BoxShadow(
            color:
                Color(
              0xA6000000,
            ),
            blurRadius: 38,
            offset:
                Offset(
              0,
              22,
            ),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 941 / 2048,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(
            29,
          ),
          child: Image.network(
            '/landing/medcases-ai-current.png',
            fit: BoxFit.cover,
            alignment:
                Alignment.topCenter,
            filterQuality:
                FilterQuality.high,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return currentFallback();
            },
          ),
        ),
      ),
    );
  }
}

class _R713SectionKicker
    extends StatelessWidget {
  final String titleEs;
  final String titlePt;

  const _R713SectionKicker({
    required this.titleEs,
    required this.titlePt,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Text(
      titleEs,
      style:
          theme.labelSmall?.copyWith(
        color:
            const Color(
          0xFF818A91,
        ),
        fontSize: 8.5,
        fontWeight:
            FontWeight.w500,
        letterSpacing: 2.5,
      ),
    );
  }
}

class _R77HeroCopy extends StatelessWidget {
  final bool isEs;
  final bool mobile;

  const _R77HeroCopy({
    required this.isEs,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          isEs
              ? 'TU ALIADO EN LA PRÁCTICA CLÍNICA'
              : 'SEU ALIADO NA PRÁTICA CLÍNICA',
          textAlign:
              TextAlign.center,
          style:
              theme.labelSmall
                  ?.copyWith(
            color:
                const Color(
              0xFFC1C6CA,
            ),
            fontSize:
                mobile ? 8.6 : 10,
            fontWeight:
                FontWeight.w500,
            letterSpacing:
                mobile ? 2.1 : 2.6,
          ),
        ),
        SizedBox(
          height:
              mobile ? 12 : 17,
        ),
        Text(
          isEs
              ? 'IA clínica con respaldo bibliográfico para estudiar, consultar y actuar con más seguridad.'
              : 'IA clínica com referências bibliográficas para estudar, consultar e agir com mais segurança.',
          textAlign:
              TextAlign.center,
          style:
              theme.headlineMedium
                  ?.copyWith(
            color:
                const Color(
              0xFFF2F3F4,
            ),
            fontSize:
                mobile ? 27 : 43,
            height: 1.05,
            fontWeight:
                FontWeight.w700,
            letterSpacing:
                mobile
                    ? -0.85
                    : -1.35,
            shadows: const [
              Shadow(
                color:
                    Color(
                  0xA6000000,
                ),
                blurRadius: 22,
              ),
            ],
          ),
        ),
        SizedBox(
          height:
              mobile ? 52 : 58,
        ),
        _R77BenefitGrid(
          isEs: isEs,
          mobile: mobile,
        ),
      ],
    );
  }
}

class _R77BenefitGrid extends StatelessWidget {
  final bool isEs;
  final bool mobile;

  const _R77BenefitGrid({
    required this.isEs,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final itemWidth =
        mobile
            ? 168.0
            : 250.0;

    return Wrap(
      alignment:
          WrapAlignment.center,
      spacing:
          mobile ? 16 : 46,
      runSpacing:
          mobile ? 20 : 24,
      children: [
        _R77Benefit(
          width: itemWidth,
          icon:
              Icons.menu_book_outlined,
          text:
              isEs
                  ? 'Guías actualizadas'
                  : 'Guias atualizadas',
        ),
        _R77Benefit(
          width: itemWidth,
          icon:
              Icons.medication_outlined,
          text:
              isEs
                  ? 'Fármacos y dosis'
                  : 'Fármacos e doses',
        ),
        _R77Benefit(
          width: itemWidth,
          icon:
              Icons.calculate_outlined,
          text:
              isEs
                  ? 'Calculadoras y scores'
                  : 'Calculadoras e scores',
        ),
        _R77Benefit(
          width: itemWidth,
          icon:
              Icons.description_outlined,
          text:
              isEs
                  ? 'Respaldo bibliográfico'
                  : 'Referências bibliográficas',
        ),
      ],
    );
  }
}

class _R77Benefit extends StatelessWidget {
  final double width;
  final IconData icon;
  final String text;

  const _R77Benefit({
    required this.width,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color:
                const Color(
              0xFFF0F2F3,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              text,
              style:
                  theme.bodyMedium
                      ?.copyWith(
                color:
                    const Color(
                  0xFFE4E7E9,
                ),
                fontSize: 11.8,
                height: 1.18,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _R79ScrollPhone extends StatefulWidget {
  final double width;

  const _R79ScrollPhone({
    required this.width,
  });

  @override
  State<_R79ScrollPhone> createState() =>
      _R79ScrollPhoneState();
}

class _R79ScrollPhoneState
    extends State<_R79ScrollPhone> {
  ScrollPosition? _position;
  double _pixels = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final next =
        Scrollable.maybeOf(context)?.position;

    if (identical(
      next,
      _position,
    )) {
      return;
    }

    _position?.removeListener(
      _handleScroll,
    );

    _position = next;

    _pixels =
        _position?.pixels ?? 0;

    _position?.addListener(
      _handleScroll,
    );
  }

  void _handleScroll() {
    if (!mounted) {
      return;
    }

    final next =
        _position?.pixels ?? 0;

    if ((next - _pixels).abs() < 0.4) {
      return;
    }

    setState(() {
      _pixels = next;
    });
  }

  @override
  void dispose() {
    _position?.removeListener(
      _handleScroll,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePixels =
        _pixels < 0 ? 0.0 : _pixels;

    final travel =
        (safePixels * 0.10)
            .clamp(
              0.0,
              42.0,
            )
            .toDouble();

    final scaleBoost =
        (safePixels / 1400.0)
            .clamp(
              0.0,
              0.025,
            )
            .toDouble();

    final progress =
        (safePixels / 900.0)
            .clamp(
              0.0,
              1.0,
            )
            .toDouble();

    final phase =
        (safePixels % 320.0) /
        320.0;

    final tilt =
        (phase - 0.5) * 0.008;

    return RepaintBoundary(
      child: Transform.translate(
        offset: Offset(
          0,
          -travel,
        ),
        child: Transform.rotate(
          angle: tilt,
          alignment:
              Alignment.topCenter,
          child: Transform.scale(
            scale:
                1.0 + scaleBoost,
            alignment:
                Alignment.topCenter,
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  42,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(
                      0x3600B978,
                    ),
                    blurRadius:
                        28 +
                        (progress * 22),
                    spreadRadius:
                        1 +
                        (progress * 3),
                  ),
                  const BoxShadow(
                    color:
                        Color(
                      0x85000000,
                    ),
                    blurRadius: 42,
                    offset:
                        Offset(
                      0,
                      22,
                    ),
                  ),
                ],
              ),
              child: _R77Phone(
                width: widget.width,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _R77Phone extends StatelessWidget {
  final double width;

  const _R77Phone({
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding:
          const EdgeInsets.all(5),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFF050607,
        ),
        borderRadius:
            BorderRadius.circular(
          34,
        ),
        border: Border.all(
          color:
              const Color(
            0xFF899097,
          ),
          width: 1.15,
        ),
        boxShadow: const [
          BoxShadow(
            color:
                Color(
              0xB0000000,
            ),
            blurRadius: 42,
            offset:
                Offset(
              0,
              23,
            ),
          ),
          BoxShadow(
            color:
                Color(
              0x1400D491,
            ),
            blurRadius: 30,
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio:
            941 / 2048,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(
            29,
          ),
          child: Image.network(
            '/landing/medcases-app-current.png',
            fit: BoxFit.cover,
            alignment:
                Alignment.topCenter,
            filterQuality:
                FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _R77ArrowCallout
    extends StatelessWidget {
  final bool leftSide;
  final String title;
  final String body;

  const _R77ArrowCallout({
    required this.leftSide,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    final text = Expanded(
      child: Column(
        crossAxisAlignment:
            leftSide
                ? CrossAxisAlignment
                    .end
                : CrossAxisAlignment
                    .start,
        children: [
          Text(
            title,
            textAlign:
                leftSide
                    ? TextAlign.right
                    : TextAlign.left,
            style:
                theme.labelMedium
                    ?.copyWith(
              color:
                  const Color(
                0xFFF0F2F3,
              ),
              fontSize: 9.6,
              height: 1.15,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            body,
            textAlign:
                leftSide
                    ? TextAlign.right
                    : TextAlign.left,
            style:
                theme.bodySmall
                    ?.copyWith(
              color:
                  const Color(
                0xFFADB4BA,
              ),
              fontSize: 8.2,
              height: 1.27,
              fontWeight:
                  FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    final arrow = Icon(
      leftSide
          ? Icons
              .arrow_forward_rounded
          : Icons
              .arrow_back_rounded,
      color:
          const Color(
        0xFFF3F4F5,
      ),
      size: 26,
    );

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children:
          leftSide
              ? [
                  text,
                  const SizedBox(
                    width: 5,
                  ),
                  arrow,
                ]
              : [
                  arrow,
                  const SizedBox(
                    width: 5,
                  ),
                  text,
                ],
    );
  }
}

const String _r722AppStoreUrl = 'https://apps.apple.com/mx/app/medcases-pro/id6771750300#information';

class _R710StoreButtons extends StatelessWidget {
  final bool isEs;

  const _R710StoreButtons({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    final width =
        MediaQuery.sizeOf(context).width;

    final mobile = width < 700;

    return SizedBox(
      width: mobile ? 388 : 470,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _R710StoreButton(
                  type: _R710StoreType.apple,
                  eyebrow:
                      isEs
                          ? 'Descargar en'
                          : 'Baixar na',
                  title: 'App Store',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _R710StoreButton(
                  type:
                      _R710StoreType.googlePlay,
                  eyebrow:
                      isEs
                          ? 'Disponible en'
                          : 'Disponível no',
                  title: 'Google Play',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isEs
                ? 'Prueba gratis 30 días'
                : 'Teste grátis por 30 dias',
            textAlign: TextAlign.center,
            style:
                theme.bodyMedium?.copyWith(
              color:
                  const Color(0xFFC2C7CC),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

enum _R710StoreType {
  apple,
  googlePlay,
}

class _R710StoreButton extends StatelessWidget {
  final _R710StoreType type;
  final String eyebrow;
  final String title;

  const _R710StoreButton({
    required this.type,
    required this.eyebrow,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    final apple =
        type == _R710StoreType.apple;

    final _r722Button = Container(
      height: 61,
      decoration: BoxDecoration(
        color: const Color(0xFF050607),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              const Color(0xFF6A7076),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 34,
            child: apple
                ? const Icon(
                    Icons.apple,
                    size: 30,
                    color: Colors.white,
                  )
                : const CustomPaint(
                    painter:
                        _R711GooglePlayPainter(),
                  ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.labelSmall
                          ?.copyWith(
                    color:
                        const Color(
                      0xFFD1D3D5,
                    ),
                    fontSize: 8.8,
                    height: 1,
                    fontWeight:
                        FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      theme.titleSmall
                          ?.copyWith(
                    color: Colors.white,
                    fontSize: 14.2,
                    height: 1,
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing: -0.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final _r722IsAppStore =
        type == _R710StoreType.apple;

    if (!_r722IsAppStore) {
      return _r722Button;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await launchUrl(
            Uri.parse(_r722AppStoreUrl),
            webOnlyWindowName: '_blank',
          );
        },
        child: _r722Button,
      ),
    );

  }
}

class _R711GooglePlayPainter
    extends CustomPainter {
  const _R711GooglePlayPainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final w = size.width;
    final h = size.height;

    final left = Offset(
      w * 0.10,
      h * 0.08,
    );

    final topRight = Offset(
      w * 0.89,
      h * 0.50,
    );

    final bottomLeft = Offset(
      w * 0.10,
      h * 0.92,
    );

    final center = Offset(
      w * 0.54,
      h * 0.50,
    );

    final top = Path()
      ..moveTo(
        left.dx,
        left.dy,
      )
      ..lineTo(
        center.dx,
        center.dy,
      )
      ..lineTo(
        w * 0.69,
        h * 0.35,
      )
      ..close();

    canvas.drawPath(
      top,
      Paint()
        ..color =
            const Color(0xFF00D7FF),
    );

    final bottom = Path()
      ..moveTo(
        left.dx,
        left.dy,
      )
      ..lineTo(
        bottomLeft.dx,
        bottomLeft.dy,
      )
      ..lineTo(
        center.dx,
        center.dy,
      )
      ..close();

    canvas.drawPath(
      bottom,
      Paint()
        ..color =
            const Color(0xFF00D26A),
    );

    final rightTop = Path()
      ..moveTo(
        center.dx,
        center.dy,
      )
      ..lineTo(
        w * 0.69,
        h * 0.35,
      )
      ..lineTo(
        topRight.dx,
        topRight.dy,
      )
      ..close();

    canvas.drawPath(
      rightTop,
      Paint()
        ..color =
            const Color(0xFFFFD400),
    );

    final rightBottom = Path()
      ..moveTo(
        center.dx,
        center.dy,
      )
      ..lineTo(
        topRight.dx,
        topRight.dy,
      )
      ..lineTo(
        w * 0.68,
        h * 0.66,
      )
      ..close();

    canvas.drawPath(
      rightBottom,
      Paint()
        ..color =
            const Color(0xFFFF3956),
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}

class _R711PricingSection
    extends StatelessWidget {
  final bool isEs;

  const _R711PricingSection({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < 700;

    final cards = mobile
        ? Column(
            children: [
              _R711PlanCard(
                premium: false,
                isEs: isEs,
              ),
              const SizedBox(height: 14),
              _R711PlanCard(
                premium: true,
                isEs: isEs,
              ),
            ],
          )
        : Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _R711PlanCard(
                  premium: false,
                  isEs: isEs,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _R711PlanCard(
                  premium: true,
                  isEs: isEs,
                ),
              ),
            ],
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        cards,
        SizedBox(
          height: mobile ? 18 : 24,
        ),
        _R716TrustStrip(
          isEs: isEs,
          mobile: mobile,
        ),
      ],
    );
  }
}

class _R711PlanCard extends StatelessWidget {
  final bool premium;
  final bool isEs;

  const _R711PlanCard({
    required this.premium,
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    final mobile =
        MediaQuery.sizeOf(context).width < 700;

    final accent = premium
        ? const Color(0xFF20D3A0)
        : const Color(0xFF6F7C86);

    final body = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        mobile ? 17 : 22,
        premium ? 30 : 24,
        mobile ? 17 : 22,
        mobile ? 17 : 20,
      ),
      decoration: BoxDecoration(
        color: premium
            ? const Color(0xF208211B)
            : const Color(0xF20E151A),
        borderRadius:
            BorderRadius.circular(
          mobile ? 22 : 24,
        ),
        border: Border.all(
          color: premium
              ? const Color(0xFF20D3A0)
              : const Color(0xFF394650),
          width: premium ? 1.35 : 1,
        ),
        boxShadow: premium
            ? const [
                BoxShadow(
                  color:
                      Color(0x3820D3A0),
                  blurRadius: 34,
                  spreadRadius: 1,
                  offset:
                      Offset(0, 12),
                ),
              ]
            : const [
                BoxShadow(
                  color:
                      Color(0x24000000),
                  blurRadius: 20,
                  offset:
                      Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: mobile ? 48 : 54,
            height: mobile ? 48 : 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: premium
                  ? const Color(
                      0x1620D3A0,
                    )
                  : const Color(
                      0x183D4952,
                    ),
              border: Border.all(
                color: premium
                    ? const Color(
                        0x7720D3A0,
                      )
                    : const Color(
                        0x553D4952,
                      ),
              ),
            ),
            child: Icon(
              premium
                  ? Icons
                      .workspace_premium_outlined
                  : Icons.school_outlined,
              color: accent,
              size: mobile ? 24 : 27,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            premium
                ? 'MEDCASES PREMIUM'
                : 'GRATIS',
            textAlign: TextAlign.center,
            style:
                theme.titleLarge?.copyWith(
              color:
                  const Color(
                0xFFF2F4F4,
              ),
              fontSize:
                  mobile ? 19 : 22,
              height: 1.05,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (!premium) ...[
            const SizedBox(height: 8),
            Text(
              'US\$ 0',
              style:
                  theme.headlineSmall
                      ?.copyWith(
                color:
                    const Color(
                  0xFFB5BEC4,
                ),
                fontSize:
                    mobile ? 20 : 24,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              isEs
                  ? 'Empieza a explorar MedCases con acceso a funciones esenciales.'
                  : 'Comece a explorar o MedCases com acesso às funções essenciais.',
              textAlign: TextAlign.center,
              style:
                  theme.bodySmall
                      ?.copyWith(
                color:
                    const Color(
                  0xFF9EA8AE,
                ),
                fontSize:
                    mobile
                        ? 10.5
                        : 11.5,
                height: 1.35,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            _R716PremiumPrice(
              isEs: isEs,
              mobile: mobile,
            ),
          ],
          SizedBox(
            height: premium ? 20 : 22,
          ),
          Divider(
            height: 1,
            color: premium
                ? const Color(
                    0x5520D3A0,
                  )
                : const Color(
                    0x443A454D,
                  ),
          ),
          const SizedBox(height: 18),
          _R716FeatureLine(
            premium: premium,
            text: premium
                ? (
                    isEs
                        ? 'Todo lo de Gratis'
                        : 'Tudo do plano Grátis'
                  )
                : (
                    isEs
                        ? 'Funciones esenciales'
                        : 'Funções essenciais'
                  ),
          ),
          const SizedBox(height: 12),
          _R716FeatureLine(
            premium: premium,
            text: premium
                ? (
                    isEs
                        ? 'Funciones avanzadas'
                        : 'Funções avançadas'
                  )
                : (
                    isEs
                        ? 'Guías y calculadoras'
                        : 'Guias e calculadoras'
                  ),
          ),
          const SizedBox(height: 12),
          _R716FeatureLine(
            premium: premium,
            text: premium
                ? (
                    isEs
                        ? 'Más herramientas'
                        : 'Mais ferramentas'
                  )
                : (
                    isEs
                        ? 'Acceso educativo'
                        : 'Acesso educativo'
                  ),
          ),
          if (premium) ...[
            const SizedBox(height: 12),
            _R716FeatureLine(
              premium: true,
              text: isEs
                  ? 'Acceso completo'
                  : 'Acesso completo',
            ),
          ],
          SizedBox(
            height: premium ? 24 : 28,
          ),
          Container(
            width: double.infinity,
            height: mobile ? 50 : 54,
            decoration: BoxDecoration(
              color: premium
                  ? const Color(
                      0xFF29D4A5,
                    )
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(15),
              border: premium
                  ? null
                  : Border.all(
                      color:
                          const Color(
                        0xFF46545F,
                      ),
                      width: 1,
                    ),
              boxShadow: premium
                  ? const [
                      BoxShadow(
                        color:
                            Color(
                          0x3320D3A0,
                        ),
                        blurRadius: 20,
                        offset:
                            Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  premium
                      ? (
                          isEs
                              ? 'Probar 30 días gratis'
                              : 'Testar 30 dias grátis'
                        )
                      : (
                          isEs
                              ? 'Comenzar gratis'
                              : 'Começar grátis'
                        ),
                  style:
                      theme.labelLarge
                          ?.copyWith(
                    color: premium
                        ? const Color(
                            0xFF03120D,
                          )
                        : Colors.white,
                    fontSize:
                        mobile
                            ? 12.3
                            : 13.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                if (premium) ...[
                  const SizedBox(width: 9),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color:
                        Color(
                      0xFF03120D,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!premium) {
      return body;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        Positioned(
          top: -11,
          right: mobile ? 12 : 16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color:
                  const Color(
                0xFF0B211B,
              ),
              borderRadius:
                  BorderRadius.circular(30),
              border: Border.all(
                color:
                    const Color(
                  0xFF20D3A0,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color:
                      Color(
                    0x3320D3A0,
                  ),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons
                      .workspace_premium_rounded,
                  size: 13,
                  color:
                      Color(
                    0xFFFFD76A,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isEs
                      ? 'MÁS POPULAR'
                      : 'MAIS POPULAR',
                  style:
                      theme.labelSmall
                          ?.copyWith(
                    color:
                        const Color(
                      0xFF74E6C2,
                    ),
                    fontSize: 8.5,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _R715PremiumPriceBlock
    extends StatelessWidget {
  final bool isEs;

  const _R715PremiumPriceBlock({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          isEs
              ? '30 días gratis'
              : '30 dias grátis',
          textAlign: TextAlign.center,
          style:
              theme.labelMedium?.copyWith(
            color:
                const Color(
              0xFF67E0B8,
            ),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'US\$ 19,99',
          textAlign: TextAlign.center,
          style:
              theme.bodyMedium?.copyWith(
            color:
                const Color(
              0xFF788188,
            ),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            decoration:
                TextDecoration.lineThrough,
            decorationColor:
                const Color(
              0xFF788188,
            ),
            decorationThickness: 1.4,
          ),
        ),
        const SizedBox(height: 3),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'US\$ 14,99',
                style:
                    theme.headlineSmall?.copyWith(
                  color:
                      const Color(
                    0xFF67E0B8,
                  ),
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              TextSpan(
                text:
                    isEs
                        ? '/mes'
                        : '/mês',
                style:
                    theme.bodyMedium?.copyWith(
                  color:
                      const Color(
                    0xFFC8D0CD,
                  ),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color:
                const Color(
              0x1600C98B,
            ),
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color:
                  const Color(
                0x5500C98B,
              ),
            ),
          ),
          child: Text(
            isEs
                ? 'Precio promocional de lanzamiento'
                : 'Preço promocional de lançamento',
            textAlign: TextAlign.center,
            style:
                theme.labelSmall?.copyWith(
              color:
                  const Color(
                0xFF90E6C8,
              ),
              fontSize: 8.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isEs
              ? 'por 3 meses'
              : 'por 3 meses',
          textAlign: TextAlign.center,
          style:
              theme.bodySmall?.copyWith(
            color:
                const Color(
              0xFFB9C0C4,
            ),
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isEs
              ? 'Después US\$ 19,99/mes.'
              : 'Depois US\$ 19,99/mês.',
          textAlign: TextAlign.center,
          style:
              theme.bodySmall?.copyWith(
            color:
                const Color(
              0xFFD2D7D9,
            ),
            fontSize: 9.3,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          isEs
              ? 'Cancela cuando quieras.'
              : 'Cancele quando quiser.',
          textAlign: TextAlign.center,
          style:
              theme.bodySmall?.copyWith(
            color:
                const Color(
              0xFF91999F,
            ),
            fontSize: 8.8,
            height: 1.2,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _R711PlanFeature
    extends StatelessWidget {
  final bool premium;
  final String text;

  const _R711PlanFeature({
    required this.premium,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: premium
                ? const Color(
                    0xFF20C995,
                  )
                : const Color(
                    0xFF414B54,
                  ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 13,
            color: premium
                ? const Color(
                    0xFF03100C,
                  )
                : const Color(
                    0xFFD7DBDE,
                  ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style:
                theme.bodySmall?.copyWith(
              color: premium
                  ? const Color(
                      0xFFDAE6E2,
                    )
                  : const Color(
                      0xFFB5BDC3,
                    ),
              fontSize: 9.1,
              height: 1.22,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _R716PremiumPrice
    extends StatelessWidget {
  final bool isEs;
  final bool mobile;

  const _R716PremiumPrice({
    required this.isEs,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isEs
              ? '30 días gratis'
              : '30 dias grátis',
          style:
              theme.labelLarge?.copyWith(
            color:
                const Color(
              0xFF6BE6BF,
            ),
            fontSize:
                mobile ? 10.5 : 11.5,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(height: 11),
        Text(
          'US\$ 19,99',
          style:
              theme.bodyMedium?.copyWith(
            color:
                const Color(
              0xFF6F797F,
            ),
            fontSize:
                mobile ? 11.5 : 12.5,
            decoration:
                TextDecoration.lineThrough,
            decorationColor:
                const Color(
              0xFF6F797F,
            ),
            decorationThickness: 1.3,
          ),
        ),
        const SizedBox(height: 3),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'US\$ 14,99',
                style:
                    theme.headlineMedium
                        ?.copyWith(
                  color:
                      const Color(
                    0xFF69E4BD,
                  ),
                  fontSize:
                      mobile ? 27 : 32,
                  height: 1,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text:
                    isEs ? '/mes' : '/mês',
                style:
                    theme.bodyMedium
                        ?.copyWith(
                  color:
                      const Color(
                    0xFFD7DFDC,
                  ),
                  fontSize:
                      mobile ? 10 : 11.5,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color:
                const Color(
              0x1220D3A0,
            ),
            borderRadius:
                BorderRadius.circular(30),
            border: Border.all(
              color:
                  const Color(
                0x7720D3A0,
              ),
            ),
          ),
          child: Text(
            isEs
                ? 'Precio promocional de lanzamiento'
                : 'Preço promocional de lançamento',
            textAlign: TextAlign.center,
            style:
                theme.labelSmall?.copyWith(
              color:
                  const Color(
                0xFF8DE7CB,
              ),
              fontSize:
                  mobile ? 8.2 : 9,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          isEs
              ? 'por 3 meses'
              : 'por 3 meses',
          style:
              theme.bodySmall?.copyWith(
            color:
                const Color(
              0xFFABB4B8,
            ),
            fontSize:
                mobile ? 9 : 9.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isEs
              ? 'Después US\$ 19,99/mes.'
              : 'Depois US\$ 19,99/mês.',
          textAlign: TextAlign.center,
          style:
              theme.bodySmall?.copyWith(
            color:
                const Color(
              0xFFDCE1DF,
            ),
            fontSize:
                mobile ? 9.2 : 10,
            fontWeight:
                FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          isEs
              ? 'Cancela cuando quieras.'
              : 'Cancele quando quiser.',
          style:
              theme.bodySmall?.copyWith(
            color:
                const Color(
              0xFF90999E,
            ),
            fontSize:
                mobile ? 8.7 : 9.4,
          ),
        ),
      ],
    );
  }
}

class _R716FeatureLine
    extends StatelessWidget {
  final bool premium;
  final String text;

  const _R716FeatureLine({
    required this.premium,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: premium
                ? const Color(
                    0xFF2AD4A6,
                  )
                : const Color(
                    0xFF52606A,
                  ),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: premium
                ? const Color(
                    0xFF03110D,
                  )
                : const Color(
                    0xFFDCE1E3,
                  ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style:
                theme.bodySmall?.copyWith(
              color: premium
                  ? const Color(
                      0xFFDCE7E3,
                    )
                  : const Color(
                      0xFFB4BDC2,
                    ),
              fontSize: 10.2,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _R716TrustStrip
    extends StatelessWidget {
  final bool isEs;
  final bool mobile;

  const _R716TrustStrip({
    required this.isEs,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.calendar_month_outlined,
        isEs
            ? '30 días gratis'
            : '30 dias grátis',
      ),
      (
        Icons.local_offer_outlined,
        isEs
            ? 'Precio de lanzamiento'
            : 'Preço de lançamento',
      ),
      (
        Icons.restart_alt_rounded,
        isEs
            ? 'Cancela cuando quieras'
            : 'Cancele quando quiser',
      ),
    ];

    if (mobile) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: items
            .map(
              (item) => _R716TrustItem(
                icon: item.$1,
                text: item.$2,
              ),
            )
            .toList(),
      );
    }

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        for (
          var i = 0;
          i < items.length;
          i++
        ) ...[
          Flexible(
            child: _R716TrustItem(
              icon: items[i].$1,
              text: items[i].$2,
            ),
          ),
          if (i != items.length - 1)
            Container(
              width: 1,
              height: 28,
              margin:
                  const EdgeInsets.symmetric(
                horizontal: 22,
              ),
              color:
                  const Color(
                0x333E4A51,
              ),
            ),
        ],
      ],
    );
  }
}

class _R716TrustItem
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _R716TrustItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color:
                Color(
              0x1620D3A0,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color:
                const Color(
              0xFF4FDFB3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style:
                theme.bodySmall?.copyWith(
              color:
                  const Color(
                0xFFADB6BB,
              ),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _R718PricingSection
    extends StatelessWidget {
  final bool isEs;

  const _R718PricingSection({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final stacked =
            constraints.maxWidth < 820;

        if (stacked) {
          return Column(
            children: [
              _R718PlanCard(
                premium: false,
                isEs: isEs,
              ),
              const SizedBox(
                height: 16,
              ),
              _R718PlanCard(
                premium: true,
                isEs: isEs,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _R718PlanCard(
                premium: false,
                isEs: isEs,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _R718PlanCard(
                premium: true,
                isEs: isEs,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _R718PlanCard
    extends StatelessWidget {
  final bool premium;
  final bool isEs;

  const _R718PlanCard({
    required this.premium,
    required this.isEs,
  });

  List<String> get features {
    if (premium) {
      return isEs
          ? const [
              'Biblioteca farmacológica completa',
              'Cálculo de dosis por peso',
              'Función renal',
              'IA Modo Guardia',
              'Resúmenes con IA',
              'Grabación hasta 240 min',
              'Transcripción hasta 90 min',
              'Historia clínica por voz',
              'Historias clínicas ilimitadas',
            ]
          : const [
              'Biblioteca farmacológica completa',
              'Cálculo de dose por peso',
              'Função renal',
              'IA Modo Plantão',
              'Resumos com IA',
              'Gravação até 240 min',
              'Transcrição até 90 min',
              'História clínica por voz',
              'Histórias clínicas ilimitadas',
            ];
    }

    return isEs
        ? const [
            'Guías clínicas · acceso completo',
            'Scores · acceso completo',
            '400 fármacos · sin cálculo por peso',
            'IA general · 5 consultas/día',
            'IA Modo Guardia · 1 consulta',
            'Audio · 15 min/mes',
            'Transcripción · 30 min/mes',
            'Historias clínicas · 3/mes',
          ]
        : const [
            'Guias clínicas · acesso completo',
            'Scores · acesso completo',
            '400 fármacos · sem cálculo por peso',
            'IA geral · 5 consultas/dia',
            'IA Modo Plantão · 1 consulta',
            'Áudio · 15 min/mês',
            'Transcrição · 30 min/mês',
            'Histórias clínicas · 3/mês',
          ];
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        22,
        24,
        22,
        22,
      ),
      decoration: BoxDecoration(
        color: premium
            ? const Color(
                0xF207211A,
              )
            : const Color(
                0xF20C141B,
              ),
        borderRadius:
            BorderRadius.circular(26),
        border: Border.all(
          color: premium
              ? const Color(
                  0xFF20D3A0,
                )
              : const Color(
                  0xFF344550,
                ),
          width: premium ? 1.35 : 1,
        ),
        boxShadow: premium
            ? const [
                BoxShadow(
                  color:
                      Color(
                    0x3220D3A0,
                  ),
                  blurRadius: 34,
                  spreadRadius: 1,
                  offset:
                      Offset(
                    0,
                    12,
                  ),
                ),
              ]
            : const [
                BoxShadow(
                  color:
                      Color(
                    0x26000000,
                  ),
                  blurRadius: 24,
                  offset:
                      Offset(
                    0,
                    12,
                  ),
                ),
              ],
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          if (premium)
            Align(
              alignment:
                  Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(
                    0x1520D3A0,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                  border: Border.all(
                    color:
                        const Color(
                      0x7720D3A0,
                    ),
                  ),
                ),
                child: Text(
                  isEs
                      ? 'MÁS POPULAR'
                      : 'MAIS POPULAR',
                  style:
                      theme.labelSmall
                          ?.copyWith(
                    color:
                        const Color(
                      0xFF76E7C4,
                    ),
                    fontSize: 8.5,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          if (premium)
            const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: premium
                      ? const Color(
                          0x1420D3A0,
                        )
                      : const Color(
                          0x163E4B55,
                        ),
                  border: Border.all(
                    color: premium
                        ? const Color(
                            0x6620D3A0,
                          )
                        : const Color(
                            0x443E4B55,
                          ),
                  ),
                ),
                child: Icon(
                  premium
                      ? Icons
                          .workspace_premium_outlined
                      : Icons
                          .school_outlined,
                  color: premium
                      ? const Color(
                          0xFF4AE0AF,
                        )
                      : const Color(
                          0xFF9EABB4,
                        ),
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      premium
                          ? 'MEDCASES PREMIUM'
                          : 'GRATIS',
                      style:
                          theme.titleLarge
                              ?.copyWith(
                        color:
                            Colors.white,
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      premium
                          ? (
                              isEs
                                  ? '30 días gratis'
                                  : '30 dias grátis'
                            )
                          : 'US\$ 0',
                      style:
                          theme.bodyMedium
                              ?.copyWith(
                        color: premium
                            ? const Color(
                                0xFF68E4BD,
                              )
                            : const Color(
                                0xFFADB7BE,
                              ),
                        fontSize: 11.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (premium) ...[
            const SizedBox(height: 17),
            const _R718PremiumPrice(),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              isEs
                  ? 'Acceso esencial para empezar a usar MedCases.'
                  : 'Acesso essencial para começar a usar o MedCases.',
              style:
                  theme.bodySmall
                      ?.copyWith(
                color:
                    const Color(
                  0xFF9CA8AF,
                ),
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 19),
          Divider(
            height: 1,
            color: premium
                ? const Color(
                    0x4420D3A0,
                  )
                : const Color(
                    0x4436434C,
                  ),
          ),
          const SizedBox(height: 18),
          Text(
            isEs
                ? 'INCLUYE'
                : 'INCLUI',
            style:
                theme.labelSmall
                    ?.copyWith(
              color:
                  const Color(
                0xFF808D95,
              ),
              fontSize: 8.5,
              fontWeight:
                  FontWeight.w700,
              letterSpacing: 2.1,
            ),
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (
              context,
              box,
            ) {
              final twoColumns =
                  box.maxWidth >= 460;

              final itemWidth =
                  twoColumns
                      ? (
                          box.maxWidth -
                          12
                        ) /
                        2
                      : box.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (
                    final feature
                    in features
                  )
                    SizedBox(
                      width: itemWidth,
                      child:
                          _R718PlanFeature(
                        premium:
                            premium,
                        text: feature,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Container(
            height: 52,
            alignment:
                Alignment.center,
            decoration: BoxDecoration(
              color: premium
                  ? const Color(
                      0xFF2BD3A4,
                    )
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              border: premium
                  ? null
                  : Border.all(
                      color:
                          const Color(
                        0xFF465660,
                      ),
                    ),
              boxShadow: premium
                  ? const [
                      BoxShadow(
                        color:
                            Color(
                          0x3020D3A0,
                        ),
                        blurRadius: 18,
                        offset:
                            Offset(
                          0,
                          8,
                        ),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              premium
                  ? (
                      isEs
                          ? 'Probar 30 días gratis'
                          : 'Testar 30 dias grátis'
                    )
                  : (
                      isEs
                          ? 'Comenzar gratis'
                          : 'Começar grátis'
                    ),
              style:
                  theme.labelLarge
                      ?.copyWith(
                color: premium
                    ? const Color(
                        0xFF03110D,
                      )
                    : Colors.white,
                fontSize: 12.5,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _R718PremiumPrice
    extends StatelessWidget {
  const _R718PremiumPrice();

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            const Color(
          0xAA071B16,
        ),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(
            0x4420D3A0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'US\$ 19,99',
            style:
                theme.bodyMedium
                    ?.copyWith(
              color:
                  const Color(
                0xFF717C82,
              ),
              fontSize: 11.5,
              decoration:
                  TextDecoration
                      .lineThrough,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'US\$ 14,99',
                  style:
                      theme.headlineMedium
                          ?.copyWith(
                    color:
                        const Color(
                      0xFF69E4BD,
                    ),
                    fontSize: 28,
                    height: 1,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                TextSpan(
                  text: '/mês',
                  style:
                      theme.bodyMedium
                          ?.copyWith(
                    color:
                        const Color(
                      0xFFD8DFDC,
                    ),
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Preço promocional de lançamento',
            style:
                theme.labelSmall
                    ?.copyWith(
              color:
                  const Color(
                0xFF7BE3C1,
              ),
              fontSize: 9.2,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'por 3 meses',
            style:
                theme.bodySmall
                    ?.copyWith(
              color:
                  const Color(
                0xFFB5BFC3,
              ),
              fontSize: 9.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Depois US\$ 19,99/mês.',
            style:
                theme.bodySmall
                    ?.copyWith(
              color:
                  const Color(
                0xFFDCE1DF,
              ),
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Cancele quando quiser.',
            style:
                theme.bodySmall
                    ?.copyWith(
              color:
                  const Color(
                0xFF929CA1,
              ),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _R718PlanFeature
    extends StatelessWidget {
  final bool premium;
  final String text;

  const _R718PlanFeature({
    required this.premium,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: premium
                ? const Color(
                    0xFF28D3A3,
                  )
                : const Color(
                    0xFF53616B,
                  ),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 13,
            color: premium
                ? const Color(
                    0xFF03110D,
                  )
                : const Color(
                    0xFFE0E4E6,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style:
                theme.bodySmall
                    ?.copyWith(
              color: premium
                  ? const Color(
                      0xFFDDE7E3,
                    )
                  : const Color(
                      0xFFB7C0C5,
                    ),
              fontSize: 9.6,
              height: 1.25,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _R719PricingSection
    extends StatelessWidget {
  final bool isEs;

  const _R719PricingSection({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final stacked =
            constraints.maxWidth < 840;

        if (stacked) {
          return Column(
            children: [
              _R719PlanCard(
                premium: false,
                isEs: isEs,
              ),
              const SizedBox(
                height: 18,
              ),
              _R719PlanCard(
                premium: true,
                isEs: isEs,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _R719PlanCard(
                premium: false,
                isEs: isEs,
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: _R719PlanCard(
                premium: true,
                isEs: isEs,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _R719PlanCard
    extends StatelessWidget {
  final bool premium;
  final bool isEs;

  const _R719PlanCard({
    required this.premium,
    required this.isEs,
  });

  List<String> get features {
    if (premium) {
      return isEs
          ? const [
              'Biblioteca completa de fármacos auditados y actualizados',
              'Cálculo de dosis por peso',
              'Ajuste y evaluación de función renal',
              'Modo Guardia con acceso Premium',
              'Resúmenes completos con IA',
              'Grabaciones de larga duración',
              'Transcripciones ampliadas',
              'Historia clínica por voz',
              'Historias clínicas ilimitadas',
            ]
          : const [
              'Biblioteca completa de fármacos auditados e atualizados',
              'Cálculo de dose por peso',
              'Ajuste e avaliação da função renal',
              'Modo Plantão com acesso Premium',
              'Resumos completos com IA',
              'Gravações de longa duração',
              'Transcrições ampliadas',
              'História clínica por voz',
              'Histórias clínicas ilimitadas',
            ];
    }

    return isEs
        ? const [
            'Guías clínicas completas',
            'Scores clínicos completos',
            'Biblioteca esencial de fármacos',
            'IA para consultas clínicas',
            'Acceso a Modo Guardia',
            'Grabación de audio',
            'Transcripción de audio',
            'Historias clínicas',
          ]
        : const [
            'Guias clínicas completas',
            'Scores clínicos completos',
            'Biblioteca essencial de fármacos',
            'IA para consultas clínicas',
            'Acesso ao Modo Plantão',
            'Gravação de áudio',
            'Transcrição de áudio',
            'Histórias clínicas',
          ];
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        23,
        24,
        23,
        22,
      ),
      decoration: BoxDecoration(
        color: premium
            ? const Color(
                0xF207211A,
              )
            : const Color(
                0xF20C141B,
              ),
        borderRadius:
            BorderRadius.circular(27),
        border: Border.all(
          color: premium
              ? const Color(
                  0xFF20D3A0,
                )
              : const Color(
                  0xFF354650,
                ),
          width: premium ? 1.35 : 1,
        ),
        boxShadow: premium
            ? const [
                BoxShadow(
                  color:
                      Color(
                    0x3320D3A0,
                  ),
                  blurRadius: 36,
                  spreadRadius: 1,
                  offset:
                      Offset(
                    0,
                    14,
                  ),
                ),
              ]
            : const [
                BoxShadow(
                  color:
                      Color(
                    0x26000000,
                  ),
                  blurRadius: 24,
                  offset:
                      Offset(
                    0,
                    12,
                  ),
                ),
              ],
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          if (premium)
            Align(
              alignment:
                  Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(
                    0x1620D3A0,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                  border: Border.all(
                    color:
                        const Color(
                      0x7720D3A0,
                    ),
                  ),
                ),
                child: Text(
                  isEs
                      ? 'MÁS POPULAR'
                      : 'MAIS POPULAR',
                  style:
                      theme.labelSmall
                          ?.copyWith(
                    color:
                        const Color(
                      0xFF79E9C6,
                    ),
                    fontSize: 8.6,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          if (premium)
            const SizedBox(height: 11),
          Row(
            children: [
              Container(
                width: 51,
                height: 51,
                decoration:
                    BoxDecoration(
                  shape: BoxShape.circle,
                  color: premium
                      ? const Color(
                          0x1420D3A0,
                        )
                      : const Color(
                          0x163F4B55,
                        ),
                  border: Border.all(
                    color: premium
                        ? const Color(
                            0x6620D3A0,
                          )
                        : const Color(
                            0x443F4B55,
                          ),
                  ),
                ),
                child: Icon(
                  premium
                      ? Icons
                          .workspace_premium_outlined
                      : Icons
                          .school_outlined,
                  color: premium
                      ? const Color(
                          0xFF4AE0AF,
                        )
                      : const Color(
                          0xFFA4B0B8,
                        ),
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      premium
                          ? 'MEDCASES PREMIUM'
                          : 'GRATIS',
                      style:
                          theme.titleLarge
                              ?.copyWith(
                        color:
                            Colors.white,
                        fontSize: 19.5,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (!premium)
                      Text(
                        'US\$ 0',
                        style:
                            theme.bodyMedium
                                ?.copyWith(
                          color:
                              const Color(
                            0xFFB1BBC2,
                          ),
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          if (premium)
            _R719PremiumPrice(
              isEs: isEs,
            )
          else
            Text(
              isEs
                  ? 'Todo lo esencial para conocer MedCases y empezar a usarlo hoy.'
                  : 'Tudo o que é essencial para conhecer o MedCases e começar a usar hoje.',
              style:
                  theme.bodyMedium
                      ?.copyWith(
                color:
                    const Color(
                  0xFFD6DDE1,
                ),
                fontSize: 12.2,
                height: 1.42,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          const SizedBox(height: 20),
          Divider(
            height: 1,
            color: premium
                ? const Color(
                    0x4420D3A0,
                  )
                : const Color(
                    0x4437434C,
                  ),
          ),
          const SizedBox(height: 18),
          Text(
            premium
                ? (
                    isEs
                        ? 'INCLUYE TODO LO DE GRATIS, MÁS:'
                        : 'INCLUI TUDO DO GRÁTIS, MAIS:'
                  )
                : (
                    isEs
                        ? 'INCLUYE'
                        : 'INCLUI'
                  ),
            style:
                theme.labelSmall
                    ?.copyWith(
              color:
                  premium
                      ? const Color(
                          0xFF7CE3C3,
                        )
                      : const Color(
                          0xFF818E96,
                        ),
              fontSize: 8.7,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 15),
          for (
            var i = 0;
            i < features.length;
            i++
          ) ...[
            _R719PlanFeature(
              premium: premium,
              text: features[i],
            ),
            if (
              i !=
                  features.length - 1
            )
              const SizedBox(
                height: 10,
              ),
          ],
          if (!premium) ...[
            const SizedBox(height: 17),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF101920,
                ),
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                border: Border.all(
                  color:
                      const Color(
                    0xFF263742,
                  ),
                ),
              ),
              child: Text(
                isEs
                    ? 'Funciones seleccionadas sujetas a límites de uso en el plan gratuito.'
                    : 'Funções selecionadas sujeitas a limites de uso no plano gratuito.',
                textAlign:
                    TextAlign.center,
                style:
                    theme.bodySmall
                        ?.copyWith(
                  color:
                      const Color(
                    0xFF8E9AA2,
                  ),
                  fontSize: 8.8,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 23),
          Container(
            height: 54,
            alignment:
                Alignment.center,
            decoration: BoxDecoration(
              color: premium
                  ? const Color(
                      0xFF2BD3A4,
                    )
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              border: premium
                  ? null
                  : Border.all(
                      color:
                          const Color(
                        0xFF465761,
                      ),
                    ),
              boxShadow: premium
                  ? const [
                      BoxShadow(
                        color:
                            Color(
                          0x3320D3A0,
                        ),
                        blurRadius: 20,
                        offset:
                            Offset(
                          0,
                          8,
                        ),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Text(
                premium
                    ? (
                        isEs
                            ? 'Probar Premium gratis por 30 días'
                            : 'Testar Premium grátis por 30 dias'
                      )
                    : (
                        isEs
                            ? 'Empezar gratis'
                            : 'Começar grátis'
                      ),
                textAlign:
                    TextAlign.center,
                style:
                    theme.labelLarge
                        ?.copyWith(
                  color: premium
                      ? const Color(
                          0xFF03110D,
                        )
                      : Colors.white,
                  fontSize: 12.5,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _R719PremiumPrice
    extends StatelessWidget {
  final bool isEs;

  const _R719PremiumPrice({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        15,
        14,
        15,
        14,
      ),
      decoration: BoxDecoration(
        color:
            const Color(
          0xAA071B16,
        ),
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color:
              const Color(
            0x4420D3A0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            isEs
                ? '30 días gratis'
                : '30 dias grátis',
            style:
                theme.labelLarge
                    ?.copyWith(
              color:
                  const Color(
                0xFF69E4BD,
              ),
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            'US\$ 19,99',
            style:
                theme.bodyMedium
                    ?.copyWith(
              color:
                  const Color(
                0xFF717C82,
              ),
              fontSize: 11.5,
              decoration:
                  TextDecoration
                      .lineThrough,
              decorationColor:
                  const Color(
                0xFF717C82,
              ),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'US\$ 14,99',
                  style:
                      theme.headlineMedium
                          ?.copyWith(
                    color:
                        const Color(
                      0xFF69E4BD,
                    ),
                    fontSize: 29,
                    height: 1,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -0.9,
                  ),
                ),
                TextSpan(
                  text: isEs
                      ? '/mes'
                      : '/mês',
                  style:
                      theme.bodyMedium
                          ?.copyWith(
                    color:
                        const Color(
                      0xFFD8DFDC,
                    ),
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Text(
            isEs
                ? 'Precio especial de lanzamiento'
                : 'Preço especial de lançamento',
            style:
                theme.labelMedium
                    ?.copyWith(
              color:
                  const Color(
                0xFF7BE3C1,
              ),
              fontSize: 10,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEs
                ? 'Durante los primeros 3 meses'
                : 'Durante os primeiros 3 meses',
            style:
                theme.bodySmall
                    ?.copyWith(
              color:
                  const Color(
                0xFFB5BFC3,
              ),
              fontSize: 9.5,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            isEs
                ? 'Después US\$ 19,99/mes'
                : 'Depois US\$ 19,99/mês',
            style:
                theme.bodySmall
                    ?.copyWith(
              color:
                  const Color(
                0xFFDDE2DF,
              ),
              fontSize: 9.7,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isEs
                ? 'Cancela cuando quieras.'
                : 'Cancele quando quiser.',
            style:
                theme.bodySmall
                    ?.copyWith(
              color:
                  const Color(
                0xFF929CA1,
              ),
              fontSize: 9.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _R719PlanFeature
    extends StatelessWidget {
  final bool premium;
  final String text;

  const _R719PlanFeature({
    required this.premium,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: premium
                ? const Color(
                    0xFF29D3A3,
                  )
                : const Color(
                    0xFF53616B,
                  ),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 13.5,
            color: premium
                ? const Color(
                    0xFF03110D,
                  )
                : const Color(
                    0xFFE0E4E6,
                  ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style:
                theme.bodySmall
                    ?.copyWith(
              color: premium
                  ? const Color(
                      0xFFE0E9E5,
                    )
                  : const Color(
                      0xFFBBC3C8,
                    ),
              fontSize: 9.8,
              height: 1.27,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _R77Disclaimer
    extends StatelessWidget {
  final bool isEs;

  const _R77Disclaimer({
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          isEs
              ? 'HERRAMIENTA EDUCATIVA DE APOYO CLÍNICO'
              : 'FERRAMENTA EDUCATIVA DE APOIO CLÍNICO',
          textAlign:
              TextAlign.center,
          style:
              theme.labelSmall
                  ?.copyWith(
            color:
                const Color(
              0xFFD3D7DA,
            ),
            fontSize: 8.5,
            fontWeight:
                FontWeight.w500,
            letterSpacing: 1.9,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          isEs
              ? 'La decisión y verificación de dosis son responsabilidad exclusiva del médico asistente.'
              : 'A decisão e a verificação das doses são responsabilidade exclusiva do médico assistente.',
          textAlign:
              TextAlign.center,
          style:
              theme.bodySmall
                  ?.copyWith(
            color:
                const Color(
              0xFF9DA4AA,
            ),
            fontSize: 8.8,
            height: 1.35,
            fontWeight:
                FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
