// ── Tela de preview pré-login ─────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/legal_screen.dart';
import '../screens/upgrade_screen.dart';
import '../widgets/brand_mark.dart';

// ── Paleta local ──────────────────────────────────────────────────────────────
const _kDark  = Color(0xFF0F1C14);
const _kGreen = Color(0xFF1F6B48);
const _kGold  = Color(0xFFC5A365);
const _kGoldL = Color(0xFFFFE8A6);

// ══════════════════════════════════════════════════════════════════════════════
// TELA DE PREVIEW PRÉ-LOGIN
// ══════════════════════════════════════════════════════════════════════════════
class PreLoginPreview extends StatefulWidget {
  const PreLoginPreview({super.key});

  @override
  State<PreLoginPreview> createState() => _PreLoginPreviewState();
}

class _PreLoginPreviewState extends State<PreLoginPreview> {
  bool _showLogin = false;
  bool? _hasConsented;
  int _demoTab = 0;
  String _lang = 'es';

  bool get _isEs => _lang == 'es';
  String get _tabCases => _isEs ? 'Casos Clínicos' : 'Casos Clínicos';
  String get _tabRx    => _isEs ? 'Prescripciones' : 'Prescrições';
  String get _fabLabel => _isEs ? 'Crear cuenta gratis' : 'Criar conta grátis';

  static const _demoCases = [
    _DemoCase(
      category: 'Urgencias', badge: 'Alta', badgeColor: Color(0xFF065F46),
      title: 'Dolor torácico con elevación del ST',
      age: '58 años • Masculino',
      dx: 'IAM con elevación del ST (STEMI) — TpI 4.2 ng/mL',
      hipotese: '',
      excerpt: 'Paciente con dolor retroesternal irradiado al brazo izquierdo, diaforesis y disnea de 40 min de evolución. ECG: elevación del ST en V1–V4. Activación del código infarto, angioplastia primaria exitosa.',
      author: 'Dr. Alejandro Ramírez',
      tags: ['Cardiología', 'STEMI', 'Código Infarto'],
    ),
    _DemoCase(
      category: 'UCI', badge: 'Internado', badgeColor: Color(0xFFC5A365),
      title: 'Sepsis de foco pulmonar con shock',
      age: '72 años • Femenino',
      dx: 'Sepsis grave — SOFA 9 — Klebsiella pneumoniae',
      hipotese: '',
      excerpt: 'Fiebre 39.8°C, PA 80/50, FC 128, FR 32, SatO₂ 86%. Inicio de antibioticoterapia empírica (Piperacilina-Tazobactam), soporte vasopresor con Noradrenalina 0.18 mcg/kg/min. VM protectora.',
      author: 'Dra. Carmen Villanueva',
      tags: ['Infectología', 'UCI', 'Sepsis'],
    ),
    _DemoCase(
      category: 'Neurología', badge: 'Alta', badgeColor: Color(0xFF065F46),
      title: 'ACV isquémico agudo — ventana trombolítica',
      age: '64 años • Masculino',
      dx: 'Accidente cerebrovascular isquémico — NIHSS 12',
      hipotese: '',
      excerpt: 'Hemiparesia derecha de inicio brusco, afasia motora. TC sin hemorragia. Dentro de ventana de 3h. tPA iv 0.9 mg/kg administrado. NIHSS post-trombólisis: 4. Alta con antiagregación dual.',
      author: 'Dr. Miguel Ángel Torres',
      tags: ['Neurología', 'ACV', 'Trombólisis'],
    ),
    _DemoCase(
      category: 'Clínica Médica', badge: 'Internado', badgeColor: Color(0xFFC5A365),
      title: 'Cetoacidosis diabética grave',
      age: '27 años • Femenino',
      dx: 'CAD grave — pH 7.14 — Glucosa 520 mg/dL',
      hipotese: '',
      excerpt: 'Debut diabético con náuseas, vómitos y dolor abdominal. K⁺ 2.9 mEq/L. Protocolo CAD: hidratación agresiva, reposición de potasio, insulina regular en infusión continua. Cierre de brecha aniónica a 18h.',
      author: 'Dra. Sofía Mendoza',
      tags: ['Endocrinología', 'CAD', 'Diabetes'],
    ),
  ];

  static const _demoRx = [
    _DemoRx(
      title: 'Sepsis — Protocolo Antibiótico Empírico',
      specialty: 'Infectología · UCI',
      indication: 'Sepsis de foco pulmonar adquirida en la comunidad',
      items: [
        'Piperacilina-Tazobactam 4.5 g IV c/6h (infusión extendida 4h)',
        'Noradrenalina 0.05–0.3 mcg/kg/min IV (titular PAM ≥65 mmHg)',
        'SF 0.9% 30 mL/kg en 3h (reanimación inicial)',
        'Hidrocortisona 200 mg/día IV (shock refractario)',
        'Enoxaparina 40 mg SC/día (profilaxis TVP)',
        'Omeprazol 40 mg IV/día (gastroprotección)',
        'Control glucémico: glicemia 140–180 mg/dL',
      ],
      warning: 'Ajustar antibiótico según cultivo y antibiograma a las 48–72h.',
    ),
    _DemoRx(
      title: 'STEMI — Protocolo Post-Angioplastia',
      specialty: 'Cardiología · Urgencias',
      indication: 'IAM con elevación del ST — post ACTP primaria',
      items: [
        'AAS 100 mg VO/día (indefinido)',
        'Ticagrelor 90 mg VO c/12h por 12 meses',
        'Atorvastatina 80 mg VO/noche',
        'Metoprolol succinato 25–100 mg VO/día',
        'Ramipril 2.5 mg VO/día (titular hasta 10 mg)',
        'Heparina no fraccionada IV 24h post-ACTP',
        'Pantoprazol 40 mg VO/día (con doble antiagregación)',
      ],
      warning: 'Evitar AINEs. Contraindicado fibrinolítico post-ACTP. Ecocardiograma a los 30 días.',
    ),
    _DemoRx(
      title: 'Cetoacidosis Diabética (CAD)',
      specialty: 'Endocrinología · Emergencias',
      indication: 'CAD grave pH <7.2 con brecha aniónica >20',
      items: [
        'SF 0.9% 1000 mL IV en 1h → 500 mL/h × 2h → 250 mL/h',
        'KCl: si K⁺ <3.5 → 40 mEq/h antes de insulina',
        'Insulina regular 0.1 U/kg/h IV (iniciar con K⁺ >3.5)',
        'Dextrosa 5% al alcanzar glucosa <250 mg/dL',
        'Bicarbonato: solo si pH <6.9 (50 mEq en 1h)',
        'Control: glucosa/hora, electrolitos c/2h, GSA c/4h',
        'Transición a insulina SC cuando: pH >7.3, BI <18, V.O. tolerado',
      ],
      warning: 'Riesgo de edema cerebral con corrección rápida. No suspender insulina IV hasta 2h post-SC.',
    ),
    _DemoRx(
      title: 'Crisis Hipertensiva con Daño de Órgano',
      specialty: 'Cardiología · Medicina Interna',
      indication: 'PA >180/120 mmHg con encefalopatía o EAP',
      items: [
        'Nitroprusiato 0.3–10 mcg/kg/min IV (titular cada 5 min)',
        'Furosemida 40–80 mg IV (si EAP / sobrecarga)',
        'Labetalol 20 mg IV en 2 min (alternativa en disección)',
        'Meta inicial: reducir PAM 25% en 1h',
        'Monitoreo invasivo de PA (arteria radial)',
        'Amlodipino 5–10 mg VO (mantenimiento oral posterior)',
        'Enalaprilato 1.25 mg IV c/6h (alternativa oral no posible)',
      ],
      warning: 'Reducción brusca de PA aumenta riesgo de ACV isquémico. Meta: 160/100 en 6h, no normalizar en urgencia.',
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
  void _goLogin() => setState(() => _showLogin = true);
  void _backToPreview() => setState(() => _showLogin = false);

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      if (_hasConsented == null) {
        return const Scaffold(
          backgroundColor: Color(0xFF0F1C14),
          body: Center(child: CircularProgressIndicator(color: Color(0xFFD4A96A))),
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
      backgroundColor: _kDark,
      body: Column(children: [
        // ── Header limpo ─────────────────────────────────────────────────────
        _PreviewHeader(
          isEs: _isEs,
          onToggleLang: _toggleLang,
          onLogin: _goLogin,
        ),

        // ── Tab selector compacto ─────────────────────────────────────────
        _TabBar(
          isEs: _isEs,
          activeTab: _demoTab,
          tabCases: _tabCases,
          tabRx: _tabRx,
          onTap: (i) => setState(() => _demoTab = i),
        ),

        // ── Lista de cards ────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: _demoTab == 0
                ? _demoCases.map((c) => _DemoCaseCard(
                    data: c, onTap: _goLogin, isEs: _isEs)).toList()
                : _demoRx.map((r) => _DemoRxCard(
                    data: r, onTap: _goLogin, isEs: _isEs)).toList(),
          ),
        ),
      ]),

      // ── CTA único na base ─────────────────────────────────────────────────
      floatingActionButton: _PrimaryFab(label: _fabLabel, onTap: _goLogin),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _PreviewHeader extends StatelessWidget {
  final bool isEs;
  final VoidCallback onToggleLang;
  final VoidCallback onLogin;
  const _PreviewHeader({
    required this.isEs,
    required this.onToggleLang,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_kDark, Color(0xFF1B3D2A), _kGreen],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            const BrandMark(small: true),
            const SizedBox(width: 12),
            // Título
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isEs ? 'Casos y Prescripciones' : 'Casos e Prescrições',
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.2),
                ),
                const SizedBox(height: 2),
                Text(
                  isEs
                      ? 'Visualización de muestra'
                      : 'Visualização de amostra',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.45)),
                ),
              ]),
            ),
            // Toggle idioma — discreto
            GestureDetector(
              onTap: onToggleLang,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.language_rounded, size: 11, color: _kGoldL),
                  const SizedBox(width: 4),
                  Text(
                    isEs ? 'PT' : 'ES',
                    style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900, color: _kGoldL),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // Entrar — botão dourado
            GestureDetector(
              onTap: onLogin,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF5A), _kGold]),
                  boxShadow: [
                    BoxShadow(
                      color: _kGold.withValues(alpha: 0.35),
                      blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(
                  isEs ? 'Entrar' : 'Entrar',
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900, color: _kDark),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB BAR
// ══════════════════════════════════════════════════════════════════════════════
class _TabBar extends StatelessWidget {
  final bool isEs;
  final int activeTab;
  final String tabCases, tabRx;
  final ValueChanged<int> onTap;
  const _TabBar({
    required this.isEs, required this.activeTab,
    required this.tabCases, required this.tabRx,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kDark,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          _Tab(
            label: tabCases,
            icon: Icons.folder_special_rounded,
            active: activeTab == 0,
            onTap: () => onTap(0),
          ),
          _Tab(
            label: tabRx,
            icon: Icons.medication_rounded,
            active: activeTab == 1,
            onTap: () => onTap(1),
          ),
        ]),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _Tab({
    required this.label, required this.icon,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: active ? _kDark : Colors.transparent,
            border: active
                ? Border.all(color: _kGoldL.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 13,
              color: active ? _kGoldL : Colors.white38),
            const SizedBox(width: 5),
            Text(label,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: active ? _kGoldL : Colors.white38)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FAB PRIMÁRIO
// ══════════════════════════════════════════════════════════════════════════════
class _PrimaryFab extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryFab({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF5A), _kGold]),
          boxShadow: [
            BoxShadow(
              color: _kGold.withValues(alpha: 0.45),
              blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.person_add_rounded, size: 18, color: _kDark),
          const SizedBox(width: 8),
          Text(label,
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, color: _kDark)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════════════════════════════
class _DemoCase {
  final String category, badge, title, age, dx, hipotese, excerpt, author;
  final Color badgeColor;
  final List<String> tags;
  const _DemoCase({
    required this.category, required this.badge, required this.badgeColor,
    required this.title, required this.age, required this.dx,
    required this.hipotese, required this.excerpt,
    required this.author, required this.tags,
  });
}

class _DemoRx {
  final String title, specialty, indication, warning;
  final List<String> items;
  const _DemoRx({
    required this.title, required this.specialty, required this.indication,
    required this.items, required this.warning,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD DE CASO CLÍNICO — clean
// ══════════════════════════════════════════════════════════════════════════════
class _DemoCaseCard extends StatelessWidget {
  final _DemoCase data;
  final VoidCallback onTap;
  final bool isEs;
  const _DemoCaseCard({
    required this.data, required this.onTap, required this.isEs});

  static const _bg     = Color(0xFF111D15);
  static const _border = Color(0xFF1E3526);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _bg,
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Topo: badges ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              _Chip(label: data.category, color: _kGold.withValues(alpha: 0.15),
                textColor: _kGoldL, border: _kGold.withValues(alpha: 0.25)),
              const SizedBox(width: 6),
              _Chip(
                label: data.badge,
                color: data.badgeColor.withValues(alpha: 0.15),
                textColor: data.badgeColor == const Color(0xFF065F46)
                    ? const Color(0xFF6BCCA0) : _kGoldL,
                border: data.badgeColor.withValues(alpha: 0.35),
              ),
            ]),
          ),

          // ── Título ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(data.title,
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900,
                color: Colors.white, height: 1.25, letterSpacing: -0.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),

          // ── Subtítulo — idade ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Text(data.age,
              style: TextStyle(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.38),
                fontWeight: FontWeight.w500)),
          ),

          // ── Dx box ───────────────────────────────────────────────────────
          if (data.dx.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF065F46).withValues(alpha: 0.12),
                border: Border.all(
                  color: const Color(0xFF065F46).withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline_rounded,
                  size: 12, color: Color(0xFF6BCCA0)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Dx: ${data.dx}',
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Color(0xFF6BCCA0), height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),

          // ── Excerpt com fade ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Stack(children: [
              Text(data.excerpt,
                style: TextStyle(
                  fontSize: 12, height: 1.5, fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5)),
                maxLines: 3, overflow: TextOverflow.ellipsis),
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [_bg.withValues(alpha: 0), _bg])))),
            ]),
          ),

          // ── Rodapé: autor + lock ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              const Icon(Icons.person_outline_rounded,
                size: 12, color: Color(0xFF4A7A5A)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(data.author,
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: Color(0xFF4A7A5A)),
                  overflow: TextOverflow.ellipsis),
              ),
              Icon(Icons.lock_rounded,
                size: 10, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(width: 4),
              Text(isEs ? 'Ver caso completo' : 'Ver caso completo',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.2))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD DE PRESCRIÇÃO — clean
// ══════════════════════════════════════════════════════════════════════════════
class _DemoRxCard extends StatelessWidget {
  final _DemoRx data;
  final VoidCallback onTap;
  final bool isEs;
  const _DemoRxCard({
    required this.data, required this.onTap, required this.isEs});

  static const _bg     = Color(0xFF111D15);
  static const _border = Color(0xFF1E3526);

  @override
  Widget build(BuildContext context) {
    // Mostra apenas 2 itens — suficiente para demonstrar valor sem sobrecarregar
    final visibleItems = data.items.take(2).toList();
    final lockedCount  = data.items.length - visibleItems.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _bg,
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Topo ─────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0F1C14), Color(0xFF183024), Color(0xFF1A4A32)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _kGold.withValues(alpha: 0.12)),
                child: const Icon(Icons.medication_rounded,
                  size: 16, color: _kGoldL),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.specialty,
                    style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: Color(0xBFFFE8A6), letterSpacing: 1.2)),
                  const SizedBox(height: 3),
                  Text(data.title,
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(data.indication,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),

          // ── Itens visíveis ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final item in visibleItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5, right: 9),
                      width: 5, height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4ADE80)),
                    ),
                    Expanded(
                      child: Text(item,
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: Colors.white70, height: 1.4)),
                    ),
                  ]),
                ),
            ]),
          ),

          // ── Lock row — único CTA interno ─────────────────────────────────
          if (lockedCount > 0)
            GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _kGold.withValues(alpha: 0.07),
                  border: Border.all(color: _kGold.withValues(alpha: 0.22)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.lock_rounded, size: 13, color: _kGold),
                  const SizedBox(width: 7),
                  Text(
                    '+$lockedCount ${isEs
                        ? "ítems más — ver protocolo completo"
                        : "itens — ver protocolo completo"}',
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _kGold)),
                ]),
              ),
            )
          else
            const SizedBox(height: 14),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHIP HELPER
// ══════════════════════════════════════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final String label;
  final Color color, textColor, border;
  const _Chip({
    required this.label, required this.color,
    required this.textColor, required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color,
        border: Border.all(color: border),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w800, color: textColor)),
    );
  }
}
