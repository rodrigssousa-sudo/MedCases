// ── FontesScreen — Tela de Fontes e Diretrizes ────────────────────────────────
// Task 6: Apple App Store Guideline 1.4.1 — Sistema de Referências em 3 Níveis
//
// Nível 1: Esta tela — lista completa de diretrizes/fontes primárias
// Nível 2: ReferenceFooterWidget (dose_calculator_widget.dart) — rodapé inline
// Nível 3: Prompt da IA (ai_service.dart) — rodapé forçado nas respostas
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../widgets/medcases_webview_screen.dart'; // BUILD 323 — MANDATO 2: in-app WebView

// ── Paleta ────────────────────────────────────────────────────────────────────
const _kDark      = Color(0xFF0F1C14);
const _kGreen     = Color(0xFF075f45);
const _kGreenMid  = Color(0xFF0E7C52);
const _kGreenLight= Color(0xFF13A06A);
const _kGold      = Color(0xFFC5A365);
const _kGoldL     = Color(0xFFFFE8A6);
const _kBg        = Color(0xFFF4F7F5);
const _kCard      = Colors.white;
const _kBorder    = Color(0xFFE2E6EA);
const _kTextDark  = Color(0xFF0D2B1E);
const _kTextMid   = Color(0xFF4A6B58);

// ── Modelo de fonte bibliográfica ─────────────────────────────────────────────
class _Source {
  final IconData icon;
  final Color color;
  final String org;
  final String fullName;
  final String edition;
  final String category;
  final String url;
  final bool isPrimary;

  const _Source({
    required this.icon,
    required this.color,
    required this.org,
    required this.fullName,
    required this.edition,
    required this.category,
    required this.url,
    this.isPrimary = false,
  });
}

// ── Base de dados de fontes ───────────────────────────────────────────────────
const _sources = <_Source>[
  // ── Clínica Geral ──────────────────────────────────────────────────────────
  _Source(
    icon: Icons.auto_stories_rounded, color: Color(0xFF1565C0),
    org: 'Harrison', isPrimary: true,
    fullName: 'Harrison Principles of Internal Medicine',
    edition: '21ª Ed. · 2025',
    category: 'Clínica Geral',
    url: 'https://accessmedicine.mhmedical.com',
  ),
  _Source(
    icon: Icons.science_rounded, color: Color(0xFF6A1B9A),
    org: 'UpToDate',
    fullName: 'UpToDate — Evidence-Based Clinical Decision Support',
    edition: 'Atualização contínua · Wolters Kluwer',
    category: 'Clínica Geral',
    url: 'https://www.uptodate.com',
  ),
  _Source(
    icon: Icons.local_hospital_rounded, color: Color(0xFF1B5E20),
    org: 'Medscape',
    fullName: 'Medscape Clinical Reference',
    edition: 'WebMD · Atualização contínua',
    category: 'Clínica Geral',
    url: 'https://reference.medscape.com',
  ),

  // ── Cardiologia ────────────────────────────────────────────────────────────
  _Source(
    icon: Icons.favorite_rounded, color: Color(0xFFC62828),
    org: 'AHA/ACC', isPrimary: true,
    fullName: 'American Heart Association / American College of Cardiology',
    edition: 'Guidelines 2023–2025',
    category: 'Cardiologia',
    url: 'https://www.ahajournals.org',
  ),
  _Source(
    icon: Icons.monitor_heart_rounded, color: Color(0xFF0D47A1),
    org: 'ESC',
    fullName: 'European Society of Cardiology — Clinical Practice Guidelines',
    edition: 'ESC 2023–2024',
    category: 'Cardiologia',
    url: 'https://www.escardio.org/Guidelines',
  ),
  _Source(
    icon: Icons.favorite_border_rounded, color: Color(0xFF880E4F),
    org: 'SBC',
    fullName: 'Sociedade Brasileira de Cardiologia — Diretrizes',
    edition: 'Arq Bras Cardiol · 2022–2024',
    category: 'Cardiologia',
    url: 'https://publicacoes.cardiol.br',
  ),

  // ── Infectologia / Antimicrobianos ─────────────────────────────────────────
  _Source(
    icon: Icons.coronavirus_rounded, color: Color(0xFF2E7D32),
    org: 'IDSA', isPrimary: true,
    fullName: 'Infectious Diseases Society of America',
    edition: 'Clinical Practice Guidelines 2022–2025',
    category: 'Infectologia',
    url: 'https://www.idsociety.org/practice-guideline',
  ),
  _Source(
    icon: Icons.medication_rounded, color: Color(0xFF01579B),
    org: 'Sanford Guide',
    fullName: 'Sanford Guide to Antimicrobial Therapy',
    edition: '55ª Ed. · 2025',
    category: 'Infectologia',
    url: 'https://www.sanfordguide.com',
  ),

  // ── UTI / Emergências ──────────────────────────────────────────────────────
  _Source(
    icon: Icons.emergency_rounded, color: Color(0xFFBF360C),
    org: 'SCCM',
    fullName: 'Society of Critical Care Medicine — Surviving Sepsis Campaign',
    edition: 'SSC 2021 · Atualização 2024',
    category: 'UTI / Emergências',
    url: 'https://www.sccm.org/SurvivingSepsisCampaign',
  ),
  _Source(
    icon: Icons.air_rounded, color: Color(0xFF1565C0),
    org: 'ATS/ERS',
    fullName: 'American Thoracic Society / European Respiratory Society',
    edition: 'Clinical Practice Guidelines 2022–2024',
    category: 'UTI / Emergências',
    url: 'https://www.thoracic.org/statements',
  ),

  // ── Farmacologia / Cálculos ────────────────────────────────────────────────
  _Source(
    icon: Icons.calculate_rounded, color: Color(0xFF4A148C),
    org: 'MDCalc',
    fullName: 'MDCalc — Clinical Decision Support',
    edition: 'Referência de escores clínicos · 2024',
    category: 'Calculadoras',
    url: 'https://www.mdcalc.com',
  ),
  _Source(
    icon: Icons.biotech_rounded, color: Color(0xFF004D40),
    org: 'PubMed',
    fullName: 'PubMed — MEDLINE Database (NLM/NIH)',
    edition: 'National Library of Medicine · Atualização contínua',
    category: 'Pesquisa',
    url: 'https://pubmed.ncbi.nlm.nih.gov',
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
// FontesScreen — Widget principal
// ══════════════════════════════════════════════════════════════════════════════
class FontesScreen extends StatefulWidget {
  final bool showClose;
  final bool isEs;
  const FontesScreen({super.key, this.showClose = false, this.isEs = false});

  @override
  State<FontesScreen> createState() => _FontesScreenState();
}

class _FontesScreenState extends State<FontesScreen> {
  String? _activeCategory;

  List<String> get _categories {
    final cats = <String>{};
    for (final s in _sources) cats.add(s.category);
    return cats.toList();
  }

  List<_Source> get _filtered {
    if (_activeCategory == null) return _sources;
    return _sources.where((s) => s.category == _activeCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEs ? 'Fuentes y Directrices' : 'Fontes e Diretrizes',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            Text(
              isEs
                  ? 'Base bibliográfica del contenido clínico'
                  : 'Base bibliográfica do conteúdo clínico',
              style: TextStyle(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.55)),
            ),
          ],
        ),
        leading: widget.showClose
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Column(
        children: [
          // ── Aviso CDS / ferramenta educacional ──────────────────────────
          _CdsDisclaimer(isEs: isEs),

          // ── Filtro por categoria ─────────────────────────────────────────
          _CategoryFilter(
            categories: _categories,
            active: _activeCategory,
            onSelect: (c) => setState(() =>
                _activeCategory = _activeCategory == c ? null : c),
          ),

          // ── Lista de fontes ──────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SourceCard(
                source: _filtered[i],
                isEs: isEs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner CDS Disclaimer ─────────────────────────────────────────────────────
class _CdsDisclaimer extends StatelessWidget {
  final bool isEs;
  const _CdsDisclaimer({required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: _kGreen.withValues(alpha: 0.18))),
      ),
      child: Row(children: [
        const Icon(Icons.school_rounded, size: 16, color: _kGreenMid),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            isEs
                ? 'MedCases Pro es una herramienta de Clinical Decision Support (CDS) para '
                  'profesionales de salud — categoría MDCalc / Medscape / UpToDate. '
                  'No realiza diagnósticos autónomos.'
                : 'MedCases Pro é uma ferramenta de Clinical Decision Support (CDS) para '
                  'profissionais de saúde — categoria MDCalc / Medscape / UpToDate. '
                  'Não realiza diagnósticos autônomos.',
            style: const TextStyle(
              fontSize: 10, color: _kTextMid,
              fontWeight: FontWeight.w500, height: 1.45),
          ),
        ),
      ]),
    );
  }
}

// ── Filtro por categoria ──────────────────────────────────────────────────────
class _CategoryFilter extends StatelessWidget {
  final List<String> categories;
  final String? active;
  final ValueChanged<String> onSelect;

  const _CategoryFilter({
    required this.categories,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        children: categories.map((c) {
          final selected = active == c;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selected
                    ? _kGreen
                    : _kGreen.withValues(alpha: 0.07),
                border: Border.all(
                  color: selected
                      ? _kGreen
                      : _kGreen.withValues(alpha: 0.20)),
              ),
              child: Text(c,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _kGreenMid)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Card de fonte ─────────────────────────────────────────────────────────────
class _SourceCard extends StatelessWidget {
  final _Source source;
  final bool isEs;
  const _SourceCard({required this.source, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: source.isPrimary
              ? _kGold.withValues(alpha: 0.55)
              : _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // BUILD 323 — MANDATO 2: in-app WebView em vez de launchUrl externo.
          // MANDATO 1: título semântico visível (source.org), URL encapsulada e invisível.
          onTap: () => openAcademicSourceSecurely(
            context,
            source.fullName,
            source.url,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Ícone
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: source.color.withValues(alpha: 0.10),
                  border: Border.all(
                    color: source.color.withValues(alpha: 0.25)),
                ),
                child: Icon(source.icon, size: 22, color: source.color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(source.org,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900,
                          color: _kTextDark)),
                      if (source.isPrimary) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: _kGold.withValues(alpha: 0.12),
                            border: Border.all(
                              color: _kGold.withValues(alpha: 0.45)),
                          ),
                          child: const Text('PRIMÁRIA',
                            style: TextStyle(
                              fontSize: 8, fontWeight: FontWeight.w900,
                              color: _kGold, letterSpacing: 0.5)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(source.fullName,
                      style: const TextStyle(
                        fontSize: 11, color: _kTextMid,
                        fontWeight: FontWeight.w500, height: 1.3)),
                    const SizedBox(height: 3),
                    Text(source.edition,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: _kTextMid.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new_rounded,
                  size: 15,
                  color: _kTextMid.withValues(alpha: 0.40)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Helper: abre FontesScreen como bottom sheet ───────────────────────────────
void showFontesScreen(BuildContext context, {bool isEs = false}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: FontesScreen(showClose: true, isEs: isEs),
      ),
    ),
  );
}
