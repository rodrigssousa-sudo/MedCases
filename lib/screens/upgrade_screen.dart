// ── Tela de Upgrade / Paywall Premium ────────────────────────────────────────
// Totalmente bilíngue ES/PT — idioma inicial via parâmetro `initialLang`.
// Botão de toggle muda idioma localmente sem afetar o AppProvider.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';

const _kDark  = Color(0xFF0F1C14);
const _kGreen = Color(0xFF075f45);
const _kGold  = Color(0xFFC5A365);
const _kGoldL = Color(0xFFFFE8A6);

// ─────────────────────────────────────────────────────────────────────────────
// Strings bilíngues — centralizado, sem literais fora desta classe
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final bool es;
  const _S(this.es);

  String get badge           => 'MEDCASES PRO PREMIUM';
  String get heroTitle       => es
      ? 'Acceso completo al\nconocimiento clínico'
      : 'Acesso completo ao\nconhecimento clínico';
  String get heroSub         => es
      ? '500+ casos clínicos reales · Protocolos actualizados\nPrescripciones modelo · IA Clínica ilimitada'
      : '500+ casos clínicos reais · Protocolos atualizados\nPrescrições modelo · IA Clínica ilimitada';

  String get choosePlan      => es ? 'Elige tu plan'        : 'Escolha seu plano';

  // ── Plano Mensal / Mensual ─────────────────────────────────────────────────
  String get planBasicLbl    => es ? 'Mensual'              : 'Mensal';
  String get planBasicPrice  => es ? '\$9.900'              : 'R\$ 29,90';
  String get planBasicPeriod => es ? '/mes'                 : '/mês';
  String get planBasicSub    => es
      ? 'Cobrado mensualmente'
      : 'Cobrado mensalmente';

  // ── Plano Anual ───────────────────────────────────────────────────────────
  String get planProLbl      => es ? 'Anual'                : 'Anual';
  String get planProPrice    => es ? '\$5.900'              : 'R\$ 19,90';
  String get planProPeriod   => es ? '/mes'                 : '/mês';
  String get planProSaving   => es ? 'Ahorra 40%'           : 'Economize 34%';
  String get planProSub      => es
      ? 'Cobrado como \$70.800/año — equiv. \$5.900/mes'
      : 'Cobrado como R\$ 238,80/ano — equiv. R\$ 19,90/mês';

  // ── CTA ───────────────────────────────────────────────────────────────────
  String ctaLabel(int plan)  => es
      ? (plan == 0 ? 'Suscribir — Plan Mensual'   : 'Suscribir — Plan Anual')
      : (plan == 0 ? 'Assinar — Plano Mensal'     : 'Assinar — Plano Anual');

  // ── Card ──────────────────────────────────────────────────────────────────
  String get selected        => es ? 'Seleccionado'         : 'Selecionado';
  String get select          => es ? 'Seleccionar'          : 'Selecionar';

  // ── Garantia — removido por compliance Apple 3.1.1 ────────────────────────
  // (reembolso via App Store é gerido exclusivamente pela Apple)
  String get guaranteeTitle  => '';
  String get guaranteeSub    => '';

  // ── Social proof — dados removidos por compliance Apple 2.3 ───────────────
  // (estatísticas não verificáveis não podem ser exibidas no binário)
  String get spDoctors       => '';
  String get spRating        => '';
  String get spCases         => '';

  // ── Disclaimer paywall ───────────────────────────────────────────────────
  String get disclaimer      => es
      ? 'Cancela en cualquier momento desde la configuración de tu cuenta.'
      : 'Cancele a qualquer momento nas configurações da sua conta.';

  // ── Toggle de idioma ──────────────────────────────────────────────────────
  String get toggleLang      => es ? 'Ver em Português'     : 'Ver en Español';

  // ── Features ──────────────────────────────────────────────────────────────
  String get featuresTitle   => es
      ? 'Qué incluye cada plan'
      : 'O que cada plano inclui';
  String get includedInBoth  => es ? 'Mensual y Anual'      : 'Mensal e Anual';
  String get onlyPro         => es ? 'Solo Anual'           : 'Só Anual';

  /// (ícone, cor, título, subtítulo, incluidoNoMensal)
  List<(IconData, Color, String, String, bool)> get features => [
    (
      Icons.folder_special_rounded, _kGoldL,
      es ? 'Casos clínicos ilimitados'             : 'Casos clínicos ilimitados',
      es ? 'UCI, Cardiología, Neurología, Emergencias y más'
         : 'UTI, Cardiologia, Neurologia, Emergências e mais',
      true,
    ),
    (
      Icons.medication_rounded, const Color(0xFF6BCCA0),
      es ? 'Prescripciones modelo completas'       : 'Prescrições modelo completas',
      es ? 'Protocolos actualizados por especialistas'
         : 'Protocolos atualizados por especialistas',
      true,
    ),
    (
      Icons.psychology_rounded, const Color(0xFF93C5FD),
      es ? 'IA Clínica sin restricciones'          : 'IA Clínica sem restrições',
      es ? 'Análisis de casos y apoyo a la decisión 24/7'
         : 'Análise de casos e apoio à decisão 24/7',
      true,
    ),
    (
      Icons.emergency_rounded, const Color(0xFFFF9580),
      es ? 'Protocolos de emergencia'              : 'Protocolos de emergência',
      es ? 'STEMI, Sepsis, ACV, CAD y más'         : 'STEMI, Sepsis, AVC, CAD e muito mais',
      true,
    ),
    (
      Icons.calculate_rounded, const Color(0xFFD9B8FF),
      es ? 'Calculadoras clínicas avanzadas'       : 'Calculadoras clínicas avançadas',
      es ? 'Escore NEWS, SOFA, Wells, CURB-65…'    : 'Escore NEWS, SOFA, Wells, CURB-65…',
      true,
    ),
    (
      Icons.cloud_download_rounded, _kGoldL,
      es ? 'Acceso offline completo'               : 'Acesso offline completo',
      es ? 'Funciona sin internet en guardias'     : 'Funciona sem internet em plantões',
      false, // apenas plano Anual
    ),
    (
      Icons.history_edu_rounded, const Color(0xFF86EFAC),
      es ? 'Historial clínico ilimitado'           : 'Histórico clínico ilimitado',
      es ? 'Guarda y revisa todos tus casos'       : 'Salva e revisa todos os seus casos',
      false, // apenas plano Anual
    ),
    (
      Icons.support_agent_rounded, const Color(0xFFFCA5A5),
      es ? 'Soporte prioritario'                   : 'Suporte prioritário',
      es ? 'Respuesta en menos de 24h'             : 'Resposta em menos de 24h',
      false, // apenas plano Anual
    ),
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
  int _selectedPlan = 1; // 0 = mensal, 1 = anual (padrão)
  late bool _isEs;
  late AnimationController _anim;
  late Animation<double> _fadeIn;

  // Links de pagamento — URL institucional única (Apple 3.1.1 compliance)
  static const _linkMensalPt = 'https://medcasespro.com';
  static const _linkAnualPt  = 'https://medcasespro.com';
  static const _linkMensalEs = 'https://medcasespro.com';
  static const _linkAnualEs  = 'https://medcasespro.com';

  @override
  void initState() {
    super.initState();
    _isEs = widget.initialLang == 'es';
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggleLang() => setState(() => _isEs = !_isEs);

  Future<void> _subscribe() async {
    // ── iOS: Apple Guideline 3.1.1 — pagamentos via App Store apenas ──────────
    // O sistema de IAP (In-App Purchase) será integrado em release futuro.
    // Por ora, em iOS, abrimos apenas o site institucional sem menção a preços.
    final bool isIOS = !kIsWeb && Platform.isIOS;
    if (isIOS) {
      final uri = Uri.parse('https://medcasespro.com');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return;
    }

    // ── Web / Android: abre URL diretamente ─────────────────────────────────
    final url = _isEs
        ? (_selectedPlan == 0 ? _linkMensalEs : _linkAnualEs)
        : (_selectedPlan == 0 ? _linkMensalPt : _linkAnualPt);
    final uri = Uri.parse(url);
    try {
      final ok = await canLaunchUrl(uri);
      if (ok) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEs
                    ? 'No se pudo abrir el link de pago. Intenta de nuevo.'
                    : 'Não foi possível abrir o link de pagamento. Tente novamente.',
              ),
              backgroundColor: const Color(0xFF1a2e24),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEs ? 'Error al abrir el pago.' : 'Erro ao abrir o pagamento.',
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _S(_isEs);
    return Scaffold(
      backgroundColor: _kDark,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(children: [
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
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
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
                            color: Colors.white.withValues(alpha: 0.3),
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
          color: _kGold.withValues(alpha: 0.12),
          border: Border.all(color: _kGold.withValues(alpha: 0.45)),
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
        width: 76, height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1F4030), Color(0xFF0A1610)],
          ),
          border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: _kGold.withValues(alpha: 0.25),
                blurRadius: 32, spreadRadius: 4),
            BoxShadow(
                color: _kGreen.withValues(alpha: 0.3),
                blurRadius: 48, spreadRadius: 2),
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
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.6,
              fontWeight: FontWeight.w500)),
    ]);
  }

  // ── Seletor de planos ───────────────────────────────────────────────────────
  Widget _buildPlanSelector(_S s) {
    return Column(children: [
      Text(s.choosePlan,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _PlanCard(
            label: s.planBasicLbl,
            price: s.planBasicPrice,
            period: s.planBasicPeriod,
            saving: null,
            sublabel: s.planBasicSub,
            selected: _selectedPlan == 0,
            onTap: () => setState(() => _selectedPlan = 0),
            selectedTxt: s.selected,
            selectTxt: s.select,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlanCard(
            label: s.planProLbl,
            price: s.planProPrice,
            period: s.planProPeriod,
            saving: s.planProSaving,
            sublabel: s.planProSub,
            selected: _selectedPlan == 1,
            onTap: () => setState(() => _selectedPlan = 1),
            selectedTxt: s.selected,
            selectTxt: s.select,
          ),
        ),
      ]),
    ]);
  }

  // ── Features por plano ──────────────────────────────────────────────────────
  Widget _buildFeatures(_S s) {
    final features = s.features;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Cabeçalho com legenda de colunas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Expanded(
              child: Text(s.featuresTitle,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
            _FeaturePill(
                label: s.planBasicLbl,
                color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 6),
            _FeaturePill(label: s.planProLbl, color: _kGold),
          ]),
        ),
        const Divider(height: 1, color: Color(0x14FFFFFF)),

        // Linhas de features
        ...features.asMap().entries.map((entry) {
          final idx = entry.key;
          final f   = entry.value;
          final (icon, color, title, sub, inBasic) = f;
          return _FeatureRow(
            icon: icon,
            color: color,
            title: title,
            subtitle: sub,
            inBasic: inBasic,
            isLast: idx == features.length - 1,
            highlight: _selectedPlan == 1 && !inBasic,
          );
        }),

        // Legenda de rodapé
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(children: [
            _LegendDot(color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 6),
            Text(s.includedInBoth,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 14),
            const _LegendDot(color: _kGold),
            const SizedBox(width: 6),
            const Text('+ ',
                style: TextStyle(
                    fontSize: 10,
                    color: _kGold,
                    fontWeight: FontWeight.w600)),
            Text(s.onlyPro,
                style: const TextStyle(
                    fontSize: 10,
                    color: _kGold,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
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
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFD4AF5A), Color(0xFFC5A365), Color(0xFF8B6914)],
          ),
          boxShadow: [
            BoxShadow(
                color: _kGold.withValues(alpha: 0.55),
                blurRadius: 20, offset: const Offset(0, 6)),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10, offset: const Offset(0, 4)),
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
          color: _kGold.withValues(alpha: 0.10),
          border: Border.all(color: _kGold.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language_rounded, size: 13, color: _kGoldL),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _kGoldL)),
        ]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label, price, period, sublabel;
  final String? saving;
  final bool selected;
  final VoidCallback onTap;
  final String selectedTxt, selectTxt;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.period,
    required this.saving,
    required this.sublabel,
    required this.selected,
    required this.onTap,
    required this.selectedTxt,
    required this.selectTxt,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? _kGold.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected ? _kGold : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: _kGold.withValues(alpha: 0.2),
                  blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (saving != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _kGold.withValues(alpha: 0.18),
                border: Border.all(color: _kGold.withValues(alpha: 0.5)),
              ),
              child: Text(saving!,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: _kGoldL)),
            ),
            const SizedBox(height: 7),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? _kGoldL
                      : Colors.white.withValues(alpha: 0.55))),
          const SizedBox(height: 3),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(
              child: Text(price,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6))),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(period,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.4))),
            ),
          ]),
          const SizedBox(height: 4),
          Text(sublabel,
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.35),
                  height: 1.3)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 13,
              color: selected ? _kGold : Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 4),
            Text(
              selected ? selectedTxt : selectTxt,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? _kGold
                      : Colors.white.withValues(alpha: 0.3)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final bool inBasic;
  final bool isLast;
  final bool highlight;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.inBasic,
    required this.isLast,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlight ? _kGold.withValues(alpha: 0.04) : Colors.transparent,
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.4),
                    height: 1.3)),
          ]),
        ),
        const SizedBox(width: 8),
        // Check Mensal
        _CheckCell(checked: inBasic, gold: false),
        const SizedBox(width: 10),
        // Check Anual — sempre incluso
        const _CheckCell(checked: true, gold: true),
      ]),
    );
  }
}

class _CheckCell extends StatelessWidget {
  final bool checked;
  final bool gold;
  const _CheckCell({required this.checked, required this.gold});

  @override
  Widget build(BuildContext context) {
    if (checked) {
      return Icon(Icons.check_circle_rounded,
          size: 18, color: gold ? _kGold : const Color(0xFF4ADE80));
    }
    return Icon(Icons.remove_circle_outline_rounded,
        size: 18, color: Colors.white.withValues(alpha: 0.15));
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  final Color color;
  const _FeaturePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  const _StatChip({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: [
        Icon(icon, size: 14, color: _kGoldL),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(sub,
            style: TextStyle(
                fontSize: 9, color: Colors.white.withValues(alpha: 0.38))),
      ]),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFF075f45).withValues(alpha: 0.08);
    canvas.drawCircle(Offset(size.width * 0.8, 0), size.width * 0.6, paint);
    paint.color = const Color(0xFFC5A365).withValues(alpha: 0.05);
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
const bool kIsReviewMode = true;

/// Mude para `false` para liberar o paywall no lançamento oficial.
const bool _kPaywallLocked = true;

void showUpgradeScreen(BuildContext context, {String lang = 'es'}) {
  // Em modo de revisão Apple: nunca exibe paywall
  if (kIsReviewMode) return;
  if (_kPaywallLocked) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        child: UpgradeScreen(showClose: true, initialLang: lang),
      ),
    ),
  );
}
