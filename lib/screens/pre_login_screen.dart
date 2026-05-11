// ── Tela de preview pré-login ─────────────────────────────────────────────────
// Extraído de main.dart para reduzir bundle e melhorar compilação incremental.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/legal_screen.dart';
import '../widgets/brand_mark.dart';

// ── Paleta local (espelha common_widgets.dart) ────────────────────────────────
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
  String _lang = 'es'; // padrão ES — sobrescrito pelo SharedPreferences no initState

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
        '1. Piperacilina-Tazobactam 4.5 g IV c/6h (infusión extendida 4h)',
        '2. Noradrenalina 0.05–0.3 mcg/kg/min IV (titular PAM ≥65 mmHg)',
        '3. SF 0.9% 30 mL/kg en 3h (reanimación inicial)',
        '4. Hidrocortisona 200 mg/día IV (shock refractario)',
        '5. Enoxaparina 40 mg SC/día (profilaxis TVP)',
        '6. Omeprazol 40 mg IV/día (gastroprotección)',
        '7. Control glucémico: glicemia 140–180 mg/dL',
      ],
      warning: 'Ajustar antibiótico según cultivo y antibiograma a las 48–72h.',
    ),
    _DemoRx(
      title: 'STEMI — Protocolo Post-Angioplastia',
      specialty: 'Cardiología · Urgencias',
      indication: 'IAM con elevación del ST — post ACTP primaria',
      items: [
        '1. AAS 100 mg VO/día (indefinido)',
        '2. Ticagrelor 90 mg VO c/12h por 12 meses',
        '3. Atorvastatina 80 mg VO/noche',
        '4. Metoprolol succinato 25–100 mg VO/día',
        '5. Ramipril 2.5 mg VO/día (titular hasta 10 mg)',
        '6. Heparina no fraccionada IV 24h post-ACTP',
        '7. Pantoprazol 40 mg VO/día (con doble antiagregación)',
      ],
      warning: 'Evitar AINEs. Contraindicado fibrinolítico post-ACTP. Ecocardiograma a los 30 días.',
    ),
    _DemoRx(
      title: 'Cetoacidosis Diabética (CAD)',
      specialty: 'Endocrinología · Emergencias',
      indication: 'CAD grave pH <7.2 con brecha aniónica >20',
      items: [
        '1. SF 0.9% 1000 mL IV en 1h → 500 mL/h × 2h → 250 mL/h',
        '2. KCl: si K⁺ <3.5 → 40 mEq/h antes de insulina',
        '3. Insulina regular 0.1 U/kg/h IV (iniciar con K⁺ >3.5)',
        '4. Dextrosa 5% al alcanzar glucosa <250 mg/dL',
        '5. Bicarbonato: solo si pH <6.9 (50 mEq en 1h)',
        '6. Control: glucosa/hora, electrolitos c/2h, GSA c/4h',
        '7. Transición a insulina SC cuando: pH >7.3, BI <18, V.O. tolerado',
      ],
      warning: 'Riesgo de edema cerebral con corrección rápida. No suspender insulina IV hasta 2h post-SC.',
    ),
    _DemoRx(
      title: 'Crisis Hipertensiva con Daño de Órgano',
      specialty: 'Cardiología · Medicina Interna',
      indication: 'PA >180/120 mmHg con encefalopatía o EAP',
      items: [
        '1. Nitroprusiato 0.3–10 mcg/kg/min IV (titular cada 5 min)',
        '2. Furosemida 40–80 mg IV (si EAP / sobrecarga)',
        '3. Labetalol 20 mg IV en 2 min (alternativa en disección)',
        '4. Meta inicial: reducir PAM 25% en 1h',
        '5. Monitoreo invasivo de PA (arteria radial)',
        '6. Amlodipino 5–10 mg VO (mantenimiento oral posterior)',
        '7. Enalaprilato 1.25 mg IV c/6h (alternativa oral no posible)',
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
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_kDark, Color(0xFF1B3D2A), _kGreen],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const BrandMark(small: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('VISTA PREVIA', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900,
                        color: Color(0xBFFFE8A6), letterSpacing: 2)),
                      const SizedBox(height: 1),
                      Text('Casos y Prescripciones',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85))),
                    ]),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _goLogin,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(colors: [Color(0xFFD4AF5A), _kGold]),
                          boxShadow: [
                            BoxShadow(color: _kGold.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: const Text('Entrar', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900, color: _kDark)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                // ── Tabs ──────────────────────────────────────────────────────
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.07),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(children: [
                    _DemoTab(
                      label: 'Casos Clínicos', icon: Icons.folder_special_rounded,
                      active: _demoTab == 0, onTap: () => setState(() => _demoTab = 0), gold: _kGoldL,
                    ),
                    _DemoTab(
                      label: 'Prescripciones', icon: Icons.medication_rounded,
                      active: _demoTab == 1, onTap: () => setState(() => _demoTab = 1), gold: _kGoldL,
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),

        // ── Banner informativo ─────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _kGold.withValues(alpha: 0.08),
            border: Border.all(color: _kGold.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.star_rounded, size: 18, color: _kGoldL),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
                  children: [
                    TextSpan(text: 'Contenido de muestra — ',
                      style: TextStyle(color: _kGoldL.withValues(alpha: 0.9), fontWeight: FontWeight.w800)),
                    TextSpan(text: 'inicia sesión para crear, guardar y compartir tus propios casos.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65))),
                  ],
                ),
              ),
            ),
          ]),
        ),

        // ── Conteúdo demo ─────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 100),
            children: _demoTab == 0
                ? _demoCases.map((c) => _DemoCaseCard(data: c, onTap: _goLogin)).toList()
                : _demoRx.map((r) => _DemoRxCard(data: r, onTap: _goLogin)).toList(),
          ),
        ),
      ]),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goLogin,
        backgroundColor: _kDark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _kGold.withValues(alpha: 0.55), width: 1.5),
        ),
        icon: const Icon(Icons.login_rounded, size: 18, color: _kGoldL),
        label: const Text('Iniciar sesión / Crear cuenta',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _kGoldL)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
// TAB SELECTOR
// ══════════════════════════════════════════════════════════════════════════════
class _DemoTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color gold;
  const _DemoTab({required this.label, required this.icon, required this.active,
    required this.onTap, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: active ? const Color(0xFF0F1C14) : Colors.transparent,
              border: active ? Border.all(color: gold.withValues(alpha: 0.3)) : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 13, color: active ? gold : Colors.white38),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                color: active ? gold : Colors.white38)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD DE CASO CLÍNICO
// ══════════════════════════════════════════════════════════════════════════════
class _DemoCaseCard extends StatelessWidget {
  final _DemoCase data;
  final VoidCallback onTap;
  const _DemoCaseCard({required this.data, required this.onTap});

  static const _kCardBg     = Color(0xFF111D15);
  static const _kCardBorder = Color(0xFF1E3526);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18), color: _kCardBg,
          border: Border.all(color: _kCardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kCardBorder))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _kDark),
                child: Text(data.category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _kGoldL)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: data.badgeColor.withValues(alpha: 0.15),
                  border: Border.all(color: data.badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(data.badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: data.badgeColor)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _kGold.withValues(alpha: 0.12),
                  border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.login_rounded, size: 10, color: _kGold),
                  SizedBox(width: 4),
                  Text('Ver completo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _kGold)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                color: Colors.white, height: 1.2, letterSpacing: -0.3), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(data.age, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.42))),
              const SizedBox(height: 10),
              if (data.dx.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF065F46).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF065F46).withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF6BCCA0)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Dx: ${data.dx}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6BCCA0), height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              const SizedBox(height: 10),
              Stack(children: [
                Text(data.excerpt, style: TextStyle(fontSize: 12, height: 1.5, fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.55)), maxLines: 3, overflow: TextOverflow.ellipsis),
                Positioned(bottom: 0, left: 0, right: 0,
                  child: Container(height: 24, decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [_kCardBg.withValues(alpha: 0), _kCardBg.withValues(alpha: 0.92)])))),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 4, children: data.tags.map((tag) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                    color: Colors.white.withValues(alpha: 0.05), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                  child: Text(tag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4))),
                ),
              ).toList()),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF4A7A5A)),
                const SizedBox(width: 5),
                Expanded(child: Text(data.author, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4A7A5A)), overflow: TextOverflow.ellipsis)),
                const Icon(Icons.lock_rounded, size: 10, color: Color(0xFF3A5A46)),
                const SizedBox(width: 4),
                Text('Iniciar sesión para leer todo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.22))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD DE PRESCRIÇÃO
// ══════════════════════════════════════════════════════════════════════════════
class _DemoRxCard extends StatelessWidget {
  final _DemoRx data;
  final VoidCallback onTap;
  const _DemoRxCard({required this.data, required this.onTap});

  static const _kCardBg     = Color(0xFF111D15);
  static const _kCardBorder = Color(0xFF1E3526);

  @override
  Widget build(BuildContext context) {
    final visibleItems = data.items.take(3).toList();
    final lockedCount  = data.items.length - visibleItems.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18), color: _kCardBg,
          border: Border.all(color: _kCardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0F1C14), Color(0xFF183024), Color(0xFF1A4A32)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _kGold.withValues(alpha: 0.15)),
                  child: const Icon(Icons.medication_rounded, size: 14, color: _kGoldL),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.specialty, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 1.5)),
                  const SizedBox(height: 1),
                  Text(data.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _kGold.withValues(alpha: 0.12), border: Border.all(color: _kGold.withValues(alpha: 0.3))),
                  child: const Text('Modelo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _kGold)),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white.withValues(alpha: 0.06), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 11, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(data.indication, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final item in visibleItems) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(margin: const EdgeInsets.only(top: 3, right: 8), width: 6, height: 6,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4ADE80))),
                    Expanded(child: Text(item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70, height: 1.4))),
                  ]),
                ),
              ],
              if (lockedCount > 0) ...[
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: _kGold.withValues(alpha: 0.08), border: Border.all(color: _kGold.withValues(alpha: 0.25))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.lock_rounded, size: 12, color: _kGold),
                      const SizedBox(width: 6),
                      Text('+$lockedCount ítems — Iniciar sesión para ver todo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGold)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF92400E).withValues(alpha: 0.12), border: Border.all(color: const Color(0xFF92400E).withValues(alpha: 0.35))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFFFB347)),
              const SizedBox(width: 7),
              Expanded(child: Text(data.warning, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFFFB347), height: 1.4))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: _kDark, border: Border.all(color: _kGold.withValues(alpha: 0.4), width: 1.5)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.login_rounded, size: 14, color: _kGoldL),
                  SizedBox(width: 7),
                  Text('Crear cuenta para guardar y usar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _kGoldL)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
