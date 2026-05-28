// ── Tela de preview pré-login — REDESIGN v4 (dark imersivo) ─────────────────
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/legal_screen.dart';

// ── Paleta MedixAI Premium (dark neon / glassmorphism médico) ─────────────────
const _kBg          = Color(0xFF06110C);   // fundo — preto-verde profundo (MedixAI)
const _kBgCard      = Color(0xFF0E1A14);   // card escuro MedixAI
const _kGreen       = Color(0xFF0E7C52);   // verde principal
const _kGreenMid    = Color(0xFF13A06A);   // verde médio
const _kGreenLight  = Color(0xFF1DBF7B);   // verde claro acento
const _kNeon        = Color(0xFF33FF88);   // neon verde MedixAI
const _kNeonGlow    = Color(0xFF2AF07A);   // cor do glow neon
const _kGold        = Color(0xFFD4A853);   // dourado — CTA
const _kText        = Color(0xFFEAF6EF);   // texto principal MedixAI (quase branco)
const _kTextMid     = Color(0xFF9FB4A6);   // texto secundário MedixAI
const _kTextDim     = Color(0xFF3D6B52);   // texto suave
const _kBorder      = Color(0xFF1A3828);   // bordas MedixAI
const _kRed         = Color(0xFFE05252);   // vermelho acento
const _kRedDark     = Color(0xFFC13030);

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
  String get _ctaLabel => _isEs ? 'Crear mi cuenta gratuita' : 'Criar minha conta gratuita';

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

  void _onConsentAccepted() => setState(() => _hasConsented = true);
  void _goLogin()           => setState(() => _showLogin = true);
  void _backToPreview()     => setState(() => _showLogin = false);

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
            color: Colors.black.withValues(alpha: 0.55))),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: ConsentModal(lang: _lang, onAccepted: _onConsentAccepted),
          ),
        ]);
      }
      return LoginScreen(onBack: _backToPreview);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF06110C),   // MedixAI dark bg
      body: Column(children: [
        // ── Header ────────────────────────────────────────────────────────────────
        _DarkHeader(isEs: _isEs, onToggleLang: _toggleLang, onLogin: _goLogin),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 130),
            children: [
              // ── Título da seção — estilo radicalmente diferente ─────────
              _SectionTitle(
                label: _isEs ? 'PROTOCOLOS CLÍNICOS' : 'PROTOCOLOS CLÍNICOS',
                sub: _isEs
                    ? 'Actualizados con evidencia reciente'
                    : 'Atualizados com evidência recente',
                accentColor: _kGreenLight,
                iconData: Icons.science_outlined,
              ),
              const SizedBox(height: 12),

              // ── Cards de protocolos — novo estilo dark horizontal ───────
              ..._protocols.map((p) => _ProtoCard(
                data: p, onTap: _goLogin, isEs: _isEs)),

              const SizedBox(height: 24),

              // ── Seção crítica — grid horizontal 2 colunas ───────────────
              _SectionTitle(
                label: _isEs ? 'ALTA GRAVIDADE' : 'ALTA GRAVIDADE',
                sub: _isEs
                    ? 'Casos de máxima urgencia clínica'
                    : 'Casos de máxima urgência clínica',
                accentColor: _kRed,
                iconData: Icons.emergency_rounded,
              ),
              const SizedBox(height: 12),
              Row(children: _critical
                  .map((c) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: c == _critical.last ? 0 : 8),
                      child: _CritCard(data: c, onTap: _goLogin, isEs: _isEs),
                    ),
                  ))
                  .toList()),

              const SizedBox(height: 24),

              // ── Bloco IA — estilo dark, não violeta ─────────────────────
              _IaBlockDark(onTap: _goLogin, isEs: _isEs),

              const SizedBox(height: 24),

              // ── Métricas rápidas — novo componente (não existia antes) ──
              _MetricsRow(isEs: _isEs),
            ],
          ),
        ),
      ]),

      // ── CTA inferior — novo estilo verde sólido (não dourado pill) ───────
      bottomNavigationBar: _CtaDark(
        label: _ctaLabel, onTap: _goLogin, isEs: _isEs),
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
      color: const Color(0xFF060F0A),
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _kNeonGlow.withValues(alpha: 0.12), width: 0.8)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            // Logo quadrado com borda — diferente do arredondado anterior
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kGreen.withValues(alpha: 0.55)),
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MedCases Pro',
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: _kText, letterSpacing: -0.2)),
                Text(
                  isEs ? 'Acceso de muestra' : 'Acesso demonstrativo',
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w400,
                    color: _kTextMid)),
              ]),
            ),
            // Seletor idioma — estilo diferente (tag arredondada)
            GestureDetector(
              onTap: onToggleLang,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _kBgCard,
                  border: Border.all(color: _kBorder),
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
                  borderRadius: BorderRadius.circular(6),
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          // Acento lateral verde (linha vertical esquerda)
          Container(
            width: 3, height: 70,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(10)),
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
                color: _kGreen.withValues(alpha: 0.15),
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
                      color: tagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: tagColor.withValues(alpha: 0.35)),
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kRed.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _kRed.withValues(alpha: 0.12),
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
// BLOCO IA — MedixAI Premium: neon glow + radial gradient + glassmorphism
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
          // ── RadialGradient sutil para profundidade (MedixAI) ─────────────
          gradient: const RadialGradient(
            center: Alignment(-0.6, -0.7),
            radius: 1.2,
            colors: [
              Color(0xFF112B1A),   // centro levemente mais claro
              Color(0xFF0E1A14),   // _kBgCard
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          // ── Borda verde neon sutil ────────────────────────────────────────
          border: Border.all(
            color: _kNeonGlow.withValues(alpha: 0.20),
            width: 1.0,
          ),
          // ── Neon glow 2 camadas (inner glow + outer diffuse) ─────────────
          boxShadow: [
            BoxShadow(
              color: _kNeonGlow.withValues(alpha: 0.22),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: _kNeonGlow.withValues(alpha: 0.10),
              blurRadius: 55,
              spreadRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header IA — ícone neon + badge AI POWERED ────────────────────
          Row(children: [
            // Ícone circular com glow sutil
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kNeonGlow.withValues(alpha: 0.10),
                border: Border.all(
                  color: _kNeonGlow.withValues(alpha: 0.30), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: _kNeonGlow.withValues(alpha: 0.18),
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
                    isEs ? 'Asistente IA Clínico' : 'Assistente IA Clínico',
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
            // Badge AI POWERED — estilo MedixAI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _kNeonGlow.withValues(alpha: 0.10),
                border: Border.all(
                  color: _kNeonGlow.withValues(alpha: 0.28), width: 0.8),
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
              color: const Color(0xFF0B1710),
              border: Border.all(
                color: _kNeonGlow.withValues(alpha: 0.12), width: 0.8),
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

          // ── Chips sugestão — estilo MedixAI ─────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _prompts.map((p) => GestureDetector(
                onTap: onTap,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1710),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _kNeonGlow.withValues(alpha: 0.15), width: 0.8),
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

          // ── Input fake — neon border verde ───────────────────────────────
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1710),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _kNeonGlow.withValues(alpha: 0.30), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: _kNeonGlow.withValues(alpha: 0.08),
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
                // Botão send neon
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF13A06A), Color(0xFF0E7C52)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kNeonGlow.withValues(alpha: 0.25),
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
// MÉTRICAS RÁPIDAS — MedixAI Premium: 2 cards lado a lado, ícone circular neon
// ══════════════════════════════════════════════════════════════════════════════
class _MetricsRow extends StatelessWidget {
  final bool isEs;
  const _MetricsRow({required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // ── Card 1: +2.400 Condutas ─────────────────────────────────────────
      Expanded(
        child: _MetricCard(
          icon: Icons.menu_book_rounded,
          iconBg: const Color(0xFF0D2018),
          stat: '+2.400',
          title: isEs ? 'Condutas Médicas' : 'Condutas Médicas',
          subtitle: isEs ? 'Guiadas por IA' : 'Guiadas por IA',
          trailingIcon: Icons.trending_up_rounded,
        ),
      ),
      const SizedBox(width: 10),
      // ── Card 2: Atualização Contínua ─────────────────────────────────────
      Expanded(
        child: _MetricCard(
          icon: Icons.verified_rounded,
          iconBg: const Color(0xFF0D2018),
          stat: isEs ? '100%' : '100%',
          title: isEs ? 'Actualización' : 'Atualização',
          subtitle: isEs ? 'Por comité experto' : 'Contínua por experts',
          trailingIcon: Icons.shield_rounded,
        ),
      ),
    ]);
  }
}

// ── Card de métrica individual — MedixAI style ──────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String stat;
  final String title;
  final String subtitle;
  final IconData trailingIcon;

  const _MetricCard({
    required this.icon,
    required this.iconBg,
    required this.stat,
    required this.title,
    required this.subtitle,
    required this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _kNeonGlow.withValues(alpha: 0.15), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: _kNeonGlow.withValues(alpha: 0.10),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ícone circular medallion ─────────────────────────────────────
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBg,
              border: Border.all(
                color: _kNeonGlow.withValues(alpha: 0.22), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: _kNeonGlow.withValues(alpha: 0.14),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: _kNeon),
          ),
          const SizedBox(height: 12),
          // ── Número em destaque neon ───────────────────────────────────────
          Text(stat,
            style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: _kNeon, letterSpacing: -0.5,
              height: 1.0,
            )),
          const SizedBox(height: 4),
          // ── Título ───────────────────────────────────────────────────────
          Text(title,
            style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kText, height: 1.2),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          // ── Subtítulo + ícone trailing ────────────────────────────────────
          Row(children: [
            Expanded(
              child: Text(subtitle,
                style: const TextStyle(
                  fontSize: 10, color: _kTextMid,
                  fontWeight: FontWeight.w400, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 13,
              color: _kNeonGlow.withValues(alpha: 0.55)),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CTA INFERIOR DARK — verde sólido + subtítulo (diferente do dourado pill)
// ══════════════════════════════════════════════════════════════════════════════
class _CtaDark extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isEs;
  const _CtaDark({required this.label, required this.onTap, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF061A12),
      padding: EdgeInsets.fromLTRB(
        20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreenMid,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.person_add_alt_1_rounded,
                size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(label,
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.white)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isEs
            ? 'Acceso gratuito · Aprobado por administrador'
            : 'Acesso gratuito · Aprovado pelo administrador',
          style: const TextStyle(
            fontSize: 10, color: _kTextMid,
            fontWeight: FontWeight.w400),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
