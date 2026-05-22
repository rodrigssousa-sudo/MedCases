// ── Tela de preview pré-login — layout v3 (Casos y Prescripciones) ────────────
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/legal_screen.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kBg         = Color(0xFFF5F6F8);
const _kCard       = Colors.white;
const _kDark       = Color(0xFF0F1C14);
const _kText       = Color(0xFF111111);
const _kTextMid    = Color(0xFF6B7280);
const _kTextLight  = Color(0xFF9CA3AF);
const _kGreenDark  = Color(0xFF0B4F2B);
const _kGreen      = Color(0xFF136A39);
const _kGreenMid   = Color(0xFF1D7A43);
const _kRed        = Color(0xFFC81E1E);
const _kRedDark    = Color(0xFFA50F0F);
const _kRedLight   = Color(0xFFFEE2E2);
const _kPurple     = Color(0xFF7B59FF);
const _kPurpleLight= Color(0xFFF4F0FF);
const _kGold       = Color(0xFFF2C86B);
const _kBorder     = Color(0xFFE7E9EE);
const _kShadow     = Color(0x14000000);

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
  String get _fabLabel => _isEs ? 'Crear cuenta gratis' : 'Criar conta grátis';

  // ── Dados "Más Visto" ─────────────────────────────────────────────────────
  static const _masVisto = [
    _RxItem(
      icon: Icons.medication_rounded,
      iconBg: _kGreenDark,
      specialty: 'Infectología • UCI',
      badge: 'NUEVO',
      badgeColor: _kGreen,
      title: 'Sepsis — Protocolo Antibiótico Empírico',
      subtitle: 'Sepsis de foco pulmonar adquirida en la comunidad',
      itemCount: 5,
    ),
    _RxItem(
      icon: Icons.monitor_heart_rounded,
      iconBg: _kGreenMid,
      specialty: 'Cardiología • Urgencias',
      badge: 'TOP',
      badgeColor: _kGreenDark,
      title: 'STEMI — Protocolo Post-Angioplastia',
      subtitle: 'IAM con elevación del ST — post ACTP primaria',
      itemCount: 5,
    ),
  ];

  // ── Dados "Más Grave" ─────────────────────────────────────────────────────
  static const _masGrave = [
    _GraveItem(
      icon: Icons.local_fire_department_rounded,
      specialty: 'Emergencias',
      title: 'Choque Séptico',
      subtitle: 'Falla circulatoria aguda por sepsis',
      severity: 'Alta',
    ),
    _GraveItem(
      icon: Icons.psychology_rounded,
      specialty: 'Neurología • UCI',
      title: 'ACV Isquémico Agudo',
      subtitle: 'Ventana terapéutica crítica',
      severity: 'Alta',
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

  void _onConsentAccepted() => setState(() => _hasConsented = true);
  void _goLogin()           => setState(() => _showLogin = true);
  void _backToPreview()     => setState(() => _showLogin = false);

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      if (_hasConsented == null) {
        return const Scaffold(
          backgroundColor: _kDark,
          body: Center(child: CircularProgressIndicator(color: _kGold)),
        );
      }
      if (!_hasConsented!) {
        return Stack(children: [
          LoginScreen(onBack: _backToPreview),
          Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.55))),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: ConsentModal(lang: _lang, onAccepted: _onConsentAccepted),
          ),
        ]);
      }
      return LoginScreen(onBack: _backToPreview);
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _Header(isEs: _isEs, onToggleLang: _toggleLang, onLogin: _goLogin),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // ── Más Visto ─────────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.remove_red_eye_rounded,
                iconColor: Colors.white,
                iconBg: _kGreen,
                title: _isEs ? 'MÁS VISTO' : 'MAIS VISTO',
                titleColor: _kText,
                subtitle: _isEs
                    ? 'Los protocolos más consultados'
                    : 'Os protocolos mais consultados',
                onVerTodos: _goLogin,
                isEs: _isEs,
              ),
              const SizedBox(height: 10),
              ..._masVisto.map((item) => _RxCard(
                    data: item, onTap: _goLogin, isEs: _isEs)),

              const SizedBox(height: 20),

              // ── Más Grave ─────────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.shield_rounded,
                iconColor: Colors.white,
                iconBg: _kRed,
                title: _isEs ? 'MÁS GRAVE' : 'MAIS GRAVE',
                titleColor: _kRed,
                subtitle: _isEs
                    ? 'Casos de mayor riesgo y gravedad'
                    : 'Casos de maior risco e gravidade',
                onVerTodos: _goLogin,
                isEs: _isEs,
                accentColor: _kRed,
              ),
              const SizedBox(height: 10),
              Row(children: _masGrave
                  .map((g) => Expanded(
                        child: _GraveCard(
                            data: g, onTap: _goLogin, isEs: _isEs),
                      ))
                  .toList()),

              const SizedBox(height: 20),

              // ── IA MedCases ───────────────────────────────────────────────
              _IaBlock(onTap: _goLogin, isEs: _isEs),
            ],
          ),
        ),
      ]),

      // ── CTA fixo na base ──────────────────────────────────────────────────
      floatingActionButton: _CtaButton(label: _fabLabel, onTap: _goLogin, isEs: _isEs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER — fundo branco, logo verde, botão dourado
// ══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final bool isEs;
  final VoidCallback onToggleLang, onLogin;
  const _Header({required this.isEs, required this.onToggleLang, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kCard,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder, width: 0.8)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            // Logo M+
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kGreenDark, _kGreen],
                ),
                boxShadow: [BoxShadow(
                  color: _kGreen.withValues(alpha: 0.35),
                  blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Center(
                child: Text('M+',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: _kGold, letterSpacing: -0.5)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isEs ? 'Casos y Prescripciones' : 'Casos e Prescrições',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: _kText, letterSpacing: -0.3),
                ),
                const SizedBox(height: 1),
                Text(
                  isEs ? 'Visualización de muestra' : 'Visualização de amostra',
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w400,
                    color: _kTextMid),
                ),
              ]),
            ),
            // Seletor idioma
            GestureDetector(
              onTap: onToggleLang,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _kCard,
                  border: Border.all(color: _kBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.language_rounded, size: 13, color: _kTextMid),
                  const SizedBox(width: 4),
                  Text(
                    isEs ? 'PT' : 'ES',
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _kText),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _kTextMid),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // Botão Entrar
            GestureDetector(
              onTap: onLogin,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _kGold,
                  boxShadow: [BoxShadow(
                    color: _kGold.withValues(alpha: 0.4),
                    blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    isEs ? 'Entrar' : 'Entrar',
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: _kDark),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: _kDark),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg, titleColor;
  final String title, subtitle;
  final VoidCallback onVerTodos;
  final bool isEs;
  final Color accentColor;

  const _SectionHeader({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.title, required this.titleColor, required this.subtitle,
    required this.onVerTodos, required this.isEs,
    this.accentColor = _kGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: titleColor, letterSpacing: 0.2)),
          Text(subtitle,
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w400,
              color: _kTextMid)),
        ]),
      ),
      GestureDetector(
        onTap: onVerTodos,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            isEs ? 'Ver todos' : 'Ver todos',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: accentColor)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_forward_rounded, size: 13, color: accentColor),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════════════════════════════
class _RxItem {
  final IconData icon;
  final Color iconBg;
  final String specialty, badge, title, subtitle;
  final Color badgeColor;
  final int itemCount;
  const _RxItem({
    required this.icon, required this.iconBg,
    required this.specialty, required this.badge, required this.badgeColor,
    required this.title, required this.subtitle, required this.itemCount,
  });
}

class _GraveItem {
  final IconData icon;
  final String specialty, title, subtitle, severity;
  const _GraveItem({
    required this.icon, required this.specialty,
    required this.title, required this.subtitle, required this.severity,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD MÁS VISTO — horizontal, fundo branco
// ══════════════════════════════════════════════════════════════════════════════
class _RxCard extends StatelessWidget {
  final _RxItem data;
  final VoidCallback onTap;
  final bool isEs;
  const _RxCard({required this.data, required this.onTap, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: const [BoxShadow(color: _kShadow, blurRadius: 8, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ícone
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [data.iconBg, Color.lerp(data.iconBg, _kGreenMid, 0.5)!]),
            ),
            child: Icon(data.icon, size: 26, color: _kGold),
          ),
          const SizedBox(width: 12),
          // Texto
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Especialidade + badge
              Row(children: [
                Text(data.specialty,
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: _kTextMid)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: data.badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(data.badge,
                    style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(data.title,
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: _kText, height: 1.2, letterSpacing: -0.2),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(data.subtitle,
                style: const TextStyle(
                  fontSize: 11, color: _kTextMid, fontWeight: FontWeight.w400),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              // Rodapé
              Row(children: [
                const Icon(Icons.description_outlined, size: 12, color: _kTextLight),
                const SizedBox(width: 4),
                Text('+${data.itemCount} ${isEs ? "ítems más" : "itens"}',
                  style: const TextStyle(
                    fontSize: 10, color: _kTextLight, fontWeight: FontWeight.w500)),
                const Spacer(),
                GestureDetector(
                  onTap: onTap,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(isEs ? 'Ver protocolo completo' : 'Ver protocolo completo',
                      style: const TextStyle(
                        fontSize: 10, color: _kGreen, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_rounded, size: 11, color: _kGreen),
                  ]),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 20, color: _kBorder),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD MÁS GRAVE — grid 2 colunas, vermelho
// ══════════════════════════════════════════════════════════════════════════════
class _GraveCard extends StatelessWidget {
  final _GraveItem data;
  final VoidCallback onTap;
  final bool isEs;
  const _GraveCard({required this.data, required this.onTap, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: const [BoxShadow(color: _kShadow, blurRadius: 8, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ícone vermelho
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [_kRed, _kRedDark]),
            ),
            child: Icon(data.icon, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(data.specialty,
            style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: _kRed, letterSpacing: 0.2),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(data.title,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: _kText, height: 1.2),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(data.subtitle,
            style: const TextStyle(
              fontSize: 10, color: _kTextMid, fontWeight: FontWeight.w400, height: 1.3),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          // Badge + dots
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _kRedLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(data.severity,
                style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800, color: _kRed)),
            ),
            const SizedBox(width: 6),
            ...List.generate(4, (i) => Container(
              width: 5, height: 5,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < 2 ? _kRed : _kBorder),
            )),
          ]),
          const SizedBox(height: 4),
          // Chevron direito alinhado
          Row(children: [
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 16, color: _kRed.withValues(alpha: 0.4)),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BLOCO IA MEDCASES
// ══════════════════════════════════════════════════════════════════════════════
class _IaBlock extends StatelessWidget {
  final VoidCallback onTap;
  final bool isEs;
  const _IaBlock({required this.onTap, required this.isEs});

  static const _chips = [
    (Icons.search_rounded,            'Buscar protocolos para insuficiencia respiratoria'),
    (Icons.description_outlined,      'Dosis de noradrenalina en shock séptico'),
    (Icons.favorite_border_rounded,   'Manejo inicial del IAM con elevación del ST'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: const [BoxShadow(color: _kShadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header da IA
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPurpleLight,
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: _kPurple),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('IA MedCases',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _kText)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kPurpleLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Beta',
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700, color: _kPurple)),
                ),
              ]),
              const Text('Tu asistente médico inteligente',
                style: TextStyle(
                  fontSize: 10, color: _kTextMid, fontWeight: FontWeight.w400)),
            ]),
          ),
          // Botão histórico
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPurpleLight,
            ),
            child: const Icon(Icons.history_rounded, size: 16, color: _kPurple),
          ),
        ]),

        const SizedBox(height: 14),

        // Balão de chat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kPurpleLight,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
          ),
          child: Text(
            isEs
                ? '¡Hola! Soy IA MedCases.\n¿En qué puedo ayudarte hoy?'
                : 'Olá! Sou IA MedCases.\nComo posso te ajudar hoje?',
            style: const TextStyle(
              fontSize: 13, color: _kPurple,
              fontWeight: FontWeight.w600, height: 1.4),
          ),
        ),

        const SizedBox(height: 12),

        // Chips de sugestão — scroll horizontal
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _chips.map((chip) => GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kPurple.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(chip.$1, size: 12, color: _kPurple),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(chip.$2,
                    style: const TextStyle(
                      fontSize: 10, color: _kPurple,
                      fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          )).toList()),
        ),

        const SizedBox(height: 12),

        // Campo de input fake
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: Text(
                  isEs ? 'Escribe tu pregunta...' : 'Escreva sua pergunta...',
                  style: const TextStyle(
                    fontSize: 13, color: _kTextLight)),
              ),
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kPurple,
                ),
                child: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CTA INFERIOR — pill dourado
// ══════════════════════════════════════════════════════════════════════════════
class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isEs;
  const _CtaButton({required this.label, required this.onTap, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: _kGold,
            boxShadow: [BoxShadow(
              color: _kGold.withValues(alpha: 0.5),
              blurRadius: 16, offset: const Offset(0, 5))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.person_add_alt_1_rounded, size: 18, color: _kDark),
            const SizedBox(width: 8),
            Text(label,
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _kDark)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 16, color: _kDark),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        isEs ? 'Guarda protocolos y favoritos' : 'Salva protocolos e favoritos',
        style: const TextStyle(
          fontSize: 10, color: _kTextMid, fontWeight: FontWeight.w400),
      ),
    ]);
  }
}
