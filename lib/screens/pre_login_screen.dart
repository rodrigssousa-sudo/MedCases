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
   // card escuro MedCases Pro
   // verde principal
   // verde médio
const _kGreenLight  = Color(0xFF0D6B57);   // verde claro acento
   // acento institucional MedCases Pro
   // acento de profundidade
   // dourado — CTA
   // texto principal MedCases Pro (quase branco)
   // texto secundário MedCases Pro
   // texto suave
   // bordas MedCases Pro
   // vermelho acento

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


// ══════════════════════════════════════════════════════════════════════════════
// SECTION TITLE — estilo dark, diferente do anterior (círculo colorido)
// ══════════════════════════════════════════════════════════════════════════════


















// ══════════════════════════════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════════════════════════════




// ══════════════════════════════════════════════════════════════════════════════
// CARD PROTOCOLO — dark, sem bordas brancas, acento esquerdo verde
// ══════════════════════════════════════════════════════════════════════════════


// ══════════════════════════════════════════════════════════════════════════════
// CARD CRÍTICO — dark, compacto
// ══════════════════════════════════════════════════════════════════════════════


// ══════════════════════════════════════════════════════════════════════════════
// BLOCO IA — MedCases Pro: profundidade sutil + radial gradient + glassmorphism
// ══════════════════════════════════════════════════════════════════════════════


// ══════════════════════════════════════════════════════════════════════════════
// MÉTRICAS RÁPIDAS — MedCases Pro: 2 cards lado a lado, ícone circular
// ══════════════════════════════════════════════════════════════════════════════


// ── Card de métrica individual — MedCases Pro style ──────────────────────────────


// ══════════════════════════════════════════════════════════════════════════════
// CTA INFERIOR DARK — verde sólido + subtítulo (diferente do dourado pill)
// ══════════════════════════════════════════════════════════════════════════════








































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
