// MEDCASES_R25A_ENTITLEMENT_SINGLE_OWNER_PAYWALL_CONTRACT_V1
// Paywall presents the plan contract; EntitlementService owns access.
// Billing remains unchanged by this entitlement-only macrobuild.
// ── Tela de Upgrade / Paywall Premium ────────────────────────────────────────
// Totalmente bilíngue ES/PT — idioma inicial via parâmetro `initialLang`.
// Botão de toggle muda idioma localmente sem afetar o AppProvider.
import 'package:flutter/material.dart';
import '../services/entitlement_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'revenuecat_purchase_sheet.dart';

const _kDark = Color(0xFF0F1116);
const _kGreen = Color(0xFF075f45);
const _kGold = Color(0xFFC5A365);
const _kGoldL = Color(0xFFFFE8A6);

// ─────────────────────────────────────────────────────────────────────────────
// Strings bilíngues — centralizado, sem literais fora desta classe
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final bool es;
  const _S(this.es);

  String get badge => 'MEDCASES PREMIUM';
  String get heroTitle => es
      ? 'Acceso completo al\nconocimiento clínico'
      : 'Acesso completo ao\nconhecimento clínico';
  String get heroSub => es
      ? 'Guías educativas · Casos clínicos · Fármacos y calculadoras\nAsistente de estudio con IA para formación médica'
      : 'Guias educativos · Casos clínicos · Fármacos e calculadoras\nAssistente de estudo com IA para formação médica';

  String get choosePlan => es ? 'Tu acceso Premium' : 'Seu acesso Premium';

  // ── Planes / Planos ───────────────────────────────────────────────────────
  String get freeLabel => es ? 'GRATIS' : 'GRÁTIS';
  String get freePrice => 'US\$ 0';
  String get freeIntro => es
      ? 'Todo lo esencial para conocer MedCases y empezar a usarlo hoy.'
      : 'Tudo o que você precisa para conhecer o MedCases e começar a usar hoje.';
  String get includesLabel => es ? 'INCLUYE' : 'INCLUI';
  String get freeLimitNote => es
      ? 'Funciones seleccionadas sujetas a límites de uso en el plan gratuito.'
      : 'Funções selecionadas estão sujeitas a limites de uso no plano gratuito.';
  String get freeCta => es ? 'Empezar gratis' : 'Começar grátis';

  String get premiumLabel => 'MEDCASES PREMIUM';
  String get premiumPlanSummary => es
      ? 'Consulta los precios y las condiciones disponibles en la tienda antes de confirmar.'
      : 'Consulte os preços e as condições disponíveis na loja antes de confirmar.';
  String get premiumAfter =>
      es ? 'Plan anual disponible' : 'Plano anual disponível';
  String get premiumCancel =>
      es ? 'Cancela cuando quieras.' : 'Cancele quando quiser.';
  String get premiumIncludesTitle =>
      es ? 'INCLUYE TODO LO DE GRATIS, MÁS:' : 'INCLUI TUDO DO GRÁTIS, MAIS:';

  // ── CTA ───────────────────────────────────────────────────────────────────
  String ctaLabel(int plan) => es ? 'Ver planes Premium' : 'Ver planos Premium';

  // ── Card ──────────────────────────────────────────────────────────────────
  String get selected => es ? 'Seleccionado' : 'Selecionado';
  String get select => es ? 'Seleccionar' : 'Selecionar';

  // ── Garantia — removido por compliance Apple 3.1.1 ────────────────────────
  // (reembolso via App Store é gerido exclusivamente pela Apple)
  String get guaranteeTitle => '';
  String get guaranteeSub => '';

  // ── Social proof — dados removidos por compliance Apple 2.3 ───────────────
  // (estatísticas não verificáveis não podem ser exibidas no binário)
  String get spDoctors => '';
  String get spRating => '';
  String get spCases => '';

  // ── Disclaimer paywall ───────────────────────────────────────────────────
  String get disclaimer => es
      ? 'Cancela en cualquier momento desde la configuración de tu cuenta.'
      : 'Cancele a qualquer momento nas configurações da sua conta.';

  // ── Toggle de idioma ──────────────────────────────────────────────────────
  String get toggleLang => es ? 'Ver em Português' : 'Ver en Español';

  // ── Benefícios / Beneficios ──────────────────────────────────────────────
  List<String> get freeItems => es
      ? [
          'Guías clínicas completas',
          'Scores clínicos completos',
          'Biblioteca esencial de fármacos',
          'IA para consultas clínicas',
          'Acceso a Modo Guardia',
          'Grabación de audio',
          'Transcripción de audio',
          'Historias clínicas',
        ]
      : [
          'Guias clínicas completas',
          'Scores clínicos completos',
          'Biblioteca essencial de fármacos',
          'IA para consultas clínicas',
          'Acesso ao Modo Guardia',
          'Gravação de áudio',
          'Transcrição de áudio',
          'Histórias clínicas',
        ];

  List<String> get premiumItems => es
      ? [
          'Biblioteca completa de fármacos auditados y actualizados',
          'Cálculo de dosis por peso auditado',
          'Ajuste y evaluación de función renal',
          'Modo Guardia con acceso Premium',
          'Resúmenes completos con IA',
          'Grabaciones de larga duración',
          'Transcripciones ampliadas',
          'Historia clínica por voz',
          'Historias clínicas ilimitadas',
        ]
      : [
          'Biblioteca completa de fármacos auditados e atualizados',
          'Cálculo de dose por peso auditado',
          'Ajuste e avaliação da função renal',
          'Modo Guardia com acesso Premium',
          'Resumos completos com IA',
          'Gravações de longa duração',
          'Transcrições ampliadas',
          'História clínica por voz',
          'Histórias clínicas ilimitadas',
        ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────
class UpgradeScreen extends StatefulWidget {
  final bool showClose;
  final String initialLang; // 'es' ou 'pt'

  const UpgradeScreen({
    super.key,
    this.showClose = false,
    this.initialLang = 'es',
  });

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPlan = 0; // R1 UI-only: Premium mensal é a única oferta visível
  bool _purchaseOpen = false;
  late bool _isEs;
  late AnimationController _anim;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    EntitlementService.instance.addListener(_entitlementChanged);
    _isEs = widget.initialLang == 'es';
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    EntitlementService.instance.removeListener(_entitlementChanged);
    _anim.dispose();
    super.dispose();
  }

  void _entitlementChanged() { if (mounted) setState(() {}); }

  void _toggleLang() => setState(() => _isEs = !_isEs);

  Future<void> _subscribe() async {
    if (!mounted || _purchaseOpen || EntitlementService.instance.isPremium) return;
    _purchaseOpen = true;
    try {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => RevenueCatPurchaseSheet(isEs: _isEs),
      );
      if (!mounted) return;
      // A sheet result never grants access. Revalidate the sovereign state.
      await EntitlementService.instance.refreshAuthoritativeTier(force: true);
      if (mounted && EntitlementService.instance.isPremium &&
          ModalRoute.of(context)?.isCurrent == true) {
        await Navigator.maybePop(context);
      }
    } finally {
      _purchaseOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _S(_isEs);
    if (EntitlementService.instance.isPremium) {
      return Scaffold(
        body: SafeArea(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_isEs ? 'Premium activo' : 'Premium ativo'),
          TextButton(onPressed: () => Navigator.maybePop(context),
            child: Text(_isEs ? 'Volver' : 'Voltar')),
        ]))),
      );
    }
    return Scaffold(
      backgroundColor: _kDark,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Opacity(
                opacity: 0.72,
                child: SvgPicture.asset(
                  'assets/images/medcases-bg.svg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x8A0F1116),
                    Color(0xB80F1116),
                    Color(0xEC0F1116),
                  ],
                  stops: [0.0, 0.46, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _BgPainter())),
          SafeArea(
            child: Column(children: [
              // ── Barra topo: toggle idioma + fechar ────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(children: [
                  _LangToggle(label: s.toggleLang, onTap: _toggleLang),
                  const Spacer(),
                  if (widget.showClose)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withOpacity(0.08),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.white70),
                      ),
                    ),
                ]),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHero(s),
                      const SizedBox(height: 24),
                      _buildPlanSelector(s),
                      const SizedBox(height: 20),
                      _buildFeatures(s),
                      const SizedBox(height: 20),
                      _buildCta(s),
                      const SizedBox(height: 14),
                      _buildGuarantee(s),
                      const SizedBox(height: 18),
                      _buildSocialProof(s),
                      const SizedBox(height: 14),
                      Text(
                        s.disclaimer,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.3),
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────────
  Widget _buildHero(_S s) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _kGold.withOpacity(0.12),
          border: Border.all(color: _kGold.withOpacity(0.45)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome_rounded, size: 13, color: _kGoldL),
          const SizedBox(width: 6),
          Text(s.badge,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: _kGoldL,
                  letterSpacing: 1.2)),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F4030), Color(0xFF1A1D23)],
          ),
          border: Border.all(color: _kGold.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: _kGold.withOpacity(0.25),
                blurRadius: 32,
                spreadRadius: 4),
            BoxShadow(
                color: _kGreen.withOpacity(0.3),
                blurRadius: 48,
                spreadRadius: 2),
          ],
        ),
        child: const Icon(Icons.workspace_premium_rounded,
            size: 36, color: _kGoldL),
      ),
      const SizedBox(height: 16),
      Text(s.heroTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -0.5)),
      const SizedBox(height: 8),
      Text(s.heroSub,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
              height: 1.6,
              fontWeight: FontWeight.w500)),
    ]);
  }

  // ── Plano grátis ──────────────────────────────────────────────────────────
  Widget _buildPlanSelector(_S s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.035),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.freeLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white70,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.freePrice,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.freeIntro,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            s.includesLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.55),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ...s.freeItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Color(0xFF86EFAC),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            s.freeLimitNote,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.35,
              color: Colors.white.withOpacity(0.34),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.22)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                s.freeCta,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plano Premium ─────────────────────────────────────────────────────────
  Widget _buildFeatures(_S s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kGold.withOpacity(0.16),
            Colors.white.withOpacity(0.035),
          ],
        ),
        border: Border.all(color: _kGold.withOpacity(0.38), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _kGold.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.premiumLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _kGoldL,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.premiumPlanSummary,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            s.premiumAfter,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.60),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.premiumCancel,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.40),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.premiumIncludesTitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: _kGoldL,
              letterSpacing: 0.65,
            ),
          ),
          const SizedBox(height: 11),
          ...s.premiumItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: _kGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA ─────────────────────────────────────────────────────────────────────
  Widget _buildCta(_S s) {
    return GestureDetector(
      onTap: _subscribe,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD4AF5A), Color(0xFFC5A365), Color(0xFF8B6914)],
          ),
          boxShadow: [
            BoxShadow(
                color: _kGold.withOpacity(0.55),
                blurRadius: 20,
                offset: const Offset(0, 6)),
            BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.workspace_premium_rounded, size: 20, color: _kDark),
          const SizedBox(width: 10),
          Text(s.ctaLabel(_selectedPlan),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _kDark,
                  letterSpacing: 0.2)),
        ]),
      ),
    );
  }

  // ── Garantia — widget ocultado por compliance Apple 3.1.1 ─────────────────
  // Reembolsos são processados exclusivamente pela Apple via App Store.
  Widget _buildGuarantee(_S s) => const SizedBox.shrink();

  // ── Social proof — ocultado por compliance Apple 2.3 ──────────────────────
  // Estatísticas não verificáveis removidas do binário.
  Widget _buildSocialProof(_S s) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _LangToggle extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LangToggle({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _kGold.withOpacity(0.10),
          border: Border.all(color: _kGold.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language_rounded, size: 13, color: _kGoldL),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: _kGoldL)),
        ]),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFF075f45).withOpacity(0.08);
    canvas.drawCircle(Offset(size.width * 0.8, 0), size.width * 0.6, paint);
    paint.color = const Color(0xFFC5A365).withOpacity(0.05);
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.45), size.width * 0.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper — abre o paywall como bottom sheet passando o idioma atual
//
// 🔒 PAYWALL BLOQUEADO — desativar antes do lançamento oficial
// Para reativar: remover o bloco "if (_kPaywallLocked)" abaixo.
//
// ── isReviewMode — Apple App Store Review bypass ─────────────────────────────
// Quando `kIsReviewMode = true`, toda a UI de assinatura/paywall/VIP é ocultada.
// O revisor da Apple terá acesso livre a todo o conteúdo do app sem paywall.
// IMPORTANTE: altere para `false` antes do lançamento oficial ao público.
// ─────────────────────────────────────────────────────────────────────────────

/// Feature flag de modo de revisão — Apple App Store Review.
/// `true`  → oculta todo paywall/premium; revisor tem acesso livre.
/// `false` → comportamento normal de produção (paywall ativo).
const bool kIsReviewMode = false;

/// Mude para `false` para liberar o paywall no lançamento oficial.
const bool _kPaywallLocked = false;

// MEDCASES_APPLE_PRERELEASE_PAYWALL_WEBVIEW_INPUT_LOCK_V1_B_R0
/// Owns one presentation, including its closing transition and child sheets.
/// Acquisition happens synchronously, before the presenter can yield.
class PaywallPresentationGuard {
  bool _active = false;
  bool get active => _active;

  Future<void> run(
    Future<void> Function() present, {
    VoidCallback? onChanged,
  }) async {
    if (_active) return;
    _active = true;
    try {
      onChanged?.call();
      await present();
    } finally {
      _active = false;
      onChanged?.call();
    }
  }
}

final _upgradePresentationGuard = PaywallPresentationGuard();

Future<void> showUpgradeScreen(BuildContext context, {String lang = 'es'}) {
  if (kIsReviewMode || _kPaywallLocked || EntitlementService.instance.isPremium) return Future<void>.value();

  return _upgradePresentationGuard.run(() async {
    await EntitlementService.instance.refreshAuthoritativeTier();
    if (!context.mounted || EntitlementService.instance.isPremium) return;
    final navigator = Navigator.of(context);
    final localizations = MaterialLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.92;
    // Equivalent modal defaults to showModalBottomSheet, but retain the route
    // so callers remain locked until its overlay has actually been removed.
    final route = ModalBottomSheetRoute<void>(
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: UpgradeScreen(showClose: true, initialLang: lang),
        ),
      ),
    );
    // The popped future may stay pending when the Navigator is disposed.
    // completed also covers disposal, as well as the reverse transition.
    navigator.push<void>(route);
    await route.completed;
  });
}
