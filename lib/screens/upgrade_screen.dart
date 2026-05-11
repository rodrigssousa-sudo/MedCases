// ── Tela de Upgrade / Paywall Premium ────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _kDark  = Color(0xFF0F1C14);
const _kGreen = Color(0xFF075f45);
const _kGold  = Color(0xFFC5A365);
const _kGoldL = Color(0xFFFFE8A6);

class UpgradeScreen extends StatefulWidget {
  /// Se true, exibe botão "Fechar" (usado como bottom sheet / modal).
  final bool showClose;
  const UpgradeScreen({super.key, this.showClose = false});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPlan = 1; // 0=mensal, 1=anual (padrão)
  late AnimationController _anim;
  late Animation<double> _fadeIn;

  // ── Links de pagamento — trocar pela URL real (Stripe / Hotmart / etc.) ─────
  static const _linkMensal = 'https://medcasespro.com/planos/mensal';
  static const _linkAnual  = 'https://medcasespro.com/planos/anual';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    final url = _selectedPlan == 0 ? _linkMensal : _linkAnual;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(children: [
          // ── Fundo gradiente decorativo ──────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _BgPainter()),
          ),

          // ── Conteúdo principal ─────────────────────────────────────────
          SafeArea(
            child: Column(children: [
              // Botão fechar (modal)
              if (widget.showClose)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 16, 0),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                      ),
                    ),
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Hero ─────────────────────────────────────────────
                      _buildHero(),
                      const SizedBox(height: 28),

                      // ── Benefícios ────────────────────────────────────────
                      _buildBenefits(),
                      const SizedBox(height: 24),

                      // ── Seletor de planos ─────────────────────────────────
                      _buildPlanSelector(),
                      const SizedBox(height: 20),

                      // ── CTA principal ────────────────────────────────────
                      _buildCta(),
                      const SizedBox(height: 14),

                      // ── Garantia ──────────────────────────────────────────
                      _buildGuarantee(),
                      const SizedBox(height: 20),

                      // ── Social proof ─────────────────────────────────────
                      _buildSocialProof(),
                      const SizedBox(height: 16),

                      // ── Disclaimer ────────────────────────────────────────
                      Text(
                        'Cancela en cualquier momento. Sin compromisos. Facturación segura.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3), height: 1.5),
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
  Widget _buildHero() {
    return Column(children: [
      // Badge topo
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
          const Text('MEDCASES PRO PREMIUM',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _kGoldL, letterSpacing: 1.2)),
        ]),
      ),
      const SizedBox(height: 18),

      // Ícone central com glow
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1F4030), Color(0xFF0A1610)],
          ),
          border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: _kGold.withValues(alpha: 0.25), blurRadius: 32, spreadRadius: 4),
            BoxShadow(color: _kGreen.withValues(alpha: 0.3), blurRadius: 48, spreadRadius: 2),
          ],
        ),
        child: const Icon(Icons.workspace_premium_rounded, size: 38, color: _kGoldL),
      ),
      const SizedBox(height: 18),

      const Text(
        'Acesso completo ao\nconhecimento clínico',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900,
          color: Colors.white, height: 1.15, letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '500+ casos clínicos reales · Protocolos actualizados\nPrescrições modelo · IA Clínica ilimitada',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13, color: Colors.white.withValues(alpha: 0.55),
          height: 1.6, fontWeight: FontWeight.w500,
        ),
      ),
    ]);
  }

  // ── Benefícios ──────────────────────────────────────────────────────────────
  Widget _buildBenefits() {
    final items = [
      (Icons.folder_special_rounded,    _kGoldL,              'Casos clínicos ilimitados',        'UCI, Cardiología, Neurología, Emergencias y más'),
      (Icons.medication_rounded,         const Color(0xFF6BCCA0), 'Prescrições modelo completas',    'Protocolos atualizados por especialistas'),
      (Icons.psychology_rounded,         const Color(0xFF93C5FD), 'IA Clínica sem restrições',       'Análise de casos e apoio à decisão 24/7'),
      (Icons.emergency_rounded,          const Color(0xFFFF9580), 'Protocolos de emergência',        'STEMI, Sepsis, ACV, CAD e muito mais'),
      (Icons.calculate_rounded,          const Color(0xFFD9B8FF), 'Calculadoras clínicas avançadas', 'Escore NEWS, SOFA, Wells, CURB-65…'),
      (Icons.cloud_download_rounded,     _kGoldL,              'Acesso offline completo',          'Funciona sem internet em plantões'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: items.map((item) {
          final (icon, color, title, sub) = item;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
                Text(sub, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45), height: 1.3)),
              ])),
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF4ADE80)),
            ]),
          );
        }).toList()
          ..removeLast(), // remove padding extra do último
      ),
    );
  }

  // ── Seletor de planos ───────────────────────────────────────────────────────
  Widget _buildPlanSelector() {
    return Column(children: [
      const Text('Elija su plan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _PlanCard(
          label: 'Mensal',
          price: 'R\$ 29',
          period: '/mês',
          saving: null,
          selected: _selectedPlan == 0,
          onTap: () => setState(() => _selectedPlan = 0),
        )),
        const SizedBox(width: 10),
        Expanded(child: _PlanCard(
          label: 'Anual',
          price: 'R\$ 19',
          period: '/mês',
          saving: 'Economize 34%',
          selected: _selectedPlan == 1,
          onTap: () => setState(() => _selectedPlan = 1),
        )),
      ]),
      if (_selectedPlan == 1) ...[
        const SizedBox(height: 8),
        Text(
          'Cobrado como R\$ 228/ano — equivale a R\$ 19/mês',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w500),
        ),
      ],
    ]);
  }

  // ── CTA principal ───────────────────────────────────────────────────────────
  Widget _buildCta() {
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
            BoxShadow(color: _kGold.withValues(alpha: 0.55), blurRadius: 20, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.workspace_premium_rounded, size: 20, color: _kDark),
          const SizedBox(width: 10),
          Text(
            _selectedPlan == 0 ? 'Assinar — R\$ 29/mês' : 'Assinar — R\$ 19/mês (anual)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kDark, letterSpacing: 0.2),
          ),
        ]),
      ),
    );
  }

  // ── Garantia ────────────────────────────────────────────────────────────────
  Widget _buildGuarantee() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF065F46).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFF065F46).withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.verified_user_rounded, size: 22, color: Color(0xFF4ADE80)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Garantia de 7 dias', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('Se não ficar satisfeito, devolvemos 100% do valor.',
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55), height: 1.4)),
        ])),
      ]),
    );
  }

  // ── Social proof ────────────────────────────────────────────────────────────
  Widget _buildSocialProof() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _StatChip(icon: Icons.people_rounded,          label: '+2.800',  sub: 'médicos'),
      const SizedBox(width: 8),
      _StatChip(icon: Icons.star_rounded,             label: '4.9★',   sub: 'avaliação'),
      const SizedBox(width: 8),
      _StatChip(icon: Icons.folder_special_rounded,   label: '500+',   sub: 'casos'),
    ]);
  }
}

// ── Plan Card ────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final String label, price, period;
  final String? saving;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({
    required this.label, required this.price, required this.period,
    required this.saving, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? _kGold.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected ? _kGold : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: _kGold.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Badge "Mais popular"
          if (saving != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _kGold.withValues(alpha: 0.18),
                border: Border.all(color: _kGold.withValues(alpha: 0.5)),
              ),
              child: Text(saving!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _kGoldL)),
            ),
            const SizedBox(height: 8),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: selected ? _kGoldL : Colors.white.withValues(alpha: 0.55))),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6))),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(period, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4))),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 14, color: selected ? _kGold : Colors.white.withValues(alpha: 0.25)),
            const SizedBox(width: 5),
            Text(selected ? 'Selecionado' : 'Selecionar',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: selected ? _kGold : Colors.white.withValues(alpha: 0.3))),
          ]),
        ]),
      ),
    );
  }
}

// ── Stat Chip ────────────────────────────────────────────────────────────────
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(sub, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.38))),
      ]),
    );
  }
}

// ── Fundo decorativo ─────────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Glow verde no topo
    paint.color = const Color(0xFF075f45).withValues(alpha: 0.08);
    canvas.drawCircle(Offset(size.width * 0.8, 0), size.width * 0.6, paint);

    // Glow dourado no centro
    paint.color = const Color(0xFFC5A365).withValues(alpha: 0.05);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.45), size.width * 0.5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Helper para abrir a tela de upgrade ──────────────────────────────────────
void showUpgradeScreen(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: const UpgradeScreen(showClose: true),
      ),
    ),
  );
}
