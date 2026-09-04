import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// MEDCASES_SIDEBAR_REFERENCES_CANONICAL_REFRESH_V1_B_R2
// Display-only bibliography owner. Clinical resolver, treatment logic and
// machine-native registries remain untouched.
class FontesScreen extends StatefulWidget {
  const FontesScreen(
    this.routeContext, {
    super.key,
    required this.isEs,
  });

  // Compatibility-only positional argument retained because the current
  // sidebar route calls FontesScreen(context, isEs: ...). The screen never
  // uses this context for navigation or state.
  final BuildContext routeContext;
  final bool isEs;

  @override
  State<FontesScreen> createState() => _FontesScreenState();
}

class _FontesScreenState extends State<FontesScreen> {
  static const Color _brand = Color(0xFF009C3B);
  static const Color _lightBackground = Color(0xFFECF0F4);
  static const Color _darkBackground = Color(0xFF0B1117);
  static const Color _darkSurface = Color(0xFF131C24);
  static const Color _lightDivider = Color(0xFFE2E7EC);
  static const Color _darkDivider = Color(0xFF374151);

  String _query = '';
  String? _category;

  static const List<_ReferenceEntry> _references = <_ReferenceEntry>[
    _ReferenceEntry(
      nameEs: "AHA / ACC",
      namePt: "AHA / ACC",
      categoryEs: "Cardiología",
      categoryPt: "Cardiologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2025–2026",
      descriptionEs:
          "Guías cardiovasculares, síndromes coronarios, hipertensión, tromboembolismo y emergencias cardiovasculares.",
      descriptionPt:
          "Diretrizes cardiovasculares, síndromes coronarianas, hipertensão, tromboembolismo e emergências cardiovasculares.",
      url: "https://professional.heart.org/en/guidelines-and-statements",
    ),
    _ReferenceEntry(
      nameEs: "ESC",
      namePt: "ESC",
      categoryEs: "Cardiología",
      categoryPt: "Cardiologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2024–2026",
      descriptionEs:
          "Guías europeas de cardiología: arritmias, insuficiencia cardíaca, aorta, valvulopatías y enfermedad vascular.",
      descriptionPt:
          "Diretrizes europeias de cardiologia: arritmias, insuficiência cardíaca, aorta, valvopatias e doença vascular.",
      url: "https://www.escardio.org/Guidelines",
    ),
    _ReferenceEntry(
      nameEs: "CHEST / ACCP",
      namePt: "CHEST / ACCP",
      categoryEs: "Cardiología",
      categoryPt: "Cardiologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "Continua",
      descriptionEs:
          "Antitrombóticos, trombosis venosa y enfermedad tromboembólica.",
      descriptionPt:
          "Antitrombóticos, trombose venosa e doença tromboembólica.",
      url:
          "https://www.chestnet.org/Guidelines-and-Topic-Collections/Guidelines",
    ),
    _ReferenceEntry(
      nameEs: "ATS",
      namePt: "ATS",
      categoryEs: "Neumología",
      categoryPt: "Pneumologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2025–2026",
      descriptionEs:
          "Neumonía, enfermedad pulmonar, procedimientos y estándares respiratorios.",
      descriptionPt:
          "Pneumonia, doença pulmonar, procedimentos e padrões respiratórios.",
      url: "https://www.thoracic.org/statements/",
    ),
    _ReferenceEntry(
      nameEs: "ERS",
      namePt: "ERS",
      categoryEs: "Neumología",
      categoryPt: "Pneumologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2024–2026",
      descriptionEs:
          "Guías respiratorias europeas y consensos multidisciplinarios.",
      descriptionPt:
          "Diretrizes respiratórias europeias e consensos multidisciplinares.",
      url: "https://www.ersnet.org/guidelines/",
    ),
    _ReferenceEntry(
      nameEs: "GINA",
      namePt: "GINA",
      categoryEs: "Neumología",
      categoryPt: "Pneumologia",
      typeEs: "Referencia continua",
      typePt: "Referência contínua",
      year: "2026",
      descriptionEs:
          "Estrategia global para diagnóstico, prevención y tratamiento del asma.",
      descriptionPt:
          "Estratégia global para diagnóstico, prevenção e tratamento da asma.",
      url: "https://ginasthma.org/reports/",
    ),
    _ReferenceEntry(
      nameEs: "GOLD",
      namePt: "GOLD",
      categoryEs: "Neumología",
      categoryPt: "Pneumologia",
      typeEs: "Referencia continua",
      typePt: "Referência contínua",
      year: "2026",
      descriptionEs:
          "Estrategia global para prevención, diagnóstico y manejo de EPOC.",
      descriptionPt:
          "Estratégia global para prevenção, diagnóstico e manejo da DPOC.",
      url: "https://goldcopd.org/",
    ),
    _ReferenceEntry(
      nameEs: "IDSA",
      namePt: "IDSA",
      categoryEs: "Infectología",
      categoryPt: "Infectologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "Continua",
      descriptionEs:
          "Guías de enfermedades infecciosas, antimicrobianos, meningitis, neumonía e infecciones urinarias.",
      descriptionPt:
          "Diretrizes de doenças infecciosas, antimicrobianos, meningite, pneumonia e infecções urinárias.",
      url: "https://www.idsociety.org/practice-guideline/",
    ),
    _ReferenceEntry(
      nameEs: "CDC",
      namePt: "CDC",
      categoryEs: "Infectología",
      categoryPt: "Infectologia",
      typeEs: "Referencia continua",
      typePt: "Referência contínua",
      year: "Continua",
      descriptionEs:
          "Recomendaciones de salud pública, infecciones, vacunas y enfermedades transmisibles.",
      descriptionPt:
          "Recomendações de saúde pública, infecções, vacinas e doenças transmissíveis.",
      url: "https://www.cdc.gov/",
    ),
    _ReferenceEntry(
      nameEs: "WHO / OMS",
      namePt: "WHO / OMS",
      categoryEs: "Infectología",
      categoryPt: "Infectologia",
      typeEs: "Base clínica",
      typePt: "Base clínica",
      year: "Continua",
      descriptionEs:
          "Normas globales, enfermedades transmisibles, vacunación, emergencias y salud pública.",
      descriptionPt:
          "Normas globais, doenças transmissíveis, vacinação, emergências e saúde pública.",
      url: "https://www.who.int/publications/i",
    ),
    _ReferenceEntry(
      nameEs: "SCCM / Surviving Sepsis Campaign",
      namePt: "SCCM / Surviving Sepsis Campaign",
      categoryEs: "Emergencias",
      categoryPt: "Emergências",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2026",
      descriptionEs: "Sepsis, shock séptico y cuidados del paciente crítico.",
      descriptionPt: "Sepse, choque séptico e cuidados do paciente crítico.",
      url:
          "https://www.sccm.org/survivingsepsiscampaign/guidelines-and-resources",
    ),
    _ReferenceEntry(
      nameEs: "KDIGO",
      namePt: "KDIGO",
      categoryEs: "Nefrología",
      categoryPt: "Nefrologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2024–2026",
      descriptionEs:
          "Enfermedad renal crónica, glomerulopatías, nefritis lúpica y trastornos renales.",
      descriptionPt:
          "Doença renal crônica, glomerulopatias, nefrite lúpica e distúrbios renais.",
      url: "https://kdigo.org/guidelines/",
    ),
    _ReferenceEntry(
      nameEs: "EAU",
      namePt: "EAU",
      categoryEs: "Nefrología",
      categoryPt: "Nefrologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2026",
      descriptionEs:
          "Infecciones urológicas, urolitiasis y práctica urológica basada en evidencia.",
      descriptionPt:
          "Infecções urológicas, urolitíase e prática urológica baseada em evidências.",
      url: "https://uroweb.org/guidelines",
    ),
    _ReferenceEntry(
      nameEs: "ADA",
      namePt: "ADA",
      categoryEs: "Endocrinología",
      categoryPt: "Endocrinologia",
      typeEs: "Referencia continua",
      typePt: "Referência contínua",
      year: "2026",
      descriptionEs:
          "Standards of Care in Diabetes y manejo de crisis hiperglucémicas.",
      descriptionPt:
          "Standards of Care in Diabetes e manejo de crises hiperglicêmicas.",
      url: "https://diabetesjournals.org/care/issue/49/Supplement_1",
    ),
    _ReferenceEntry(
      nameEs: "Endocrine Society",
      namePt: "Endocrine Society",
      categoryEs: "Endocrinología",
      categoryPt: "Endocrinologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "Continua",
      descriptionEs:
          "Patología suprarrenal, metabolismo mineral, osteoporosis y endocrinología clínica.",
      descriptionPt:
          "Patologia adrenal, metabolismo mineral, osteoporose e endocrinologia clínica.",
      url: "https://www.endocrine.org/clinical-practice-guidelines",
    ),
    _ReferenceEntry(
      nameEs: "ACG",
      namePt: "ACG",
      categoryEs: "Gastroenterología",
      categoryPt: "Gastroenterologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2024–2026",
      descriptionEs:
          "Gastroenterología, hepatología clínica, sangrado digestivo, pancreatitis y enfermedad inflamatoria intestinal.",
      descriptionPt:
          "Gastroenterologia, hepatologia clínica, sangramento digestivo, pancreatite e doença inflamatória intestinal.",
      url: "https://gi.org/guidelines/",
    ),
    _ReferenceEntry(
      nameEs: "AGA",
      namePt: "AGA",
      categoryEs: "Gastroenterología",
      categoryPt: "Gastroenterologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "Continua",
      descriptionEs:
          "Actualizaciones de práctica clínica y guías de gastroenterología.",
      descriptionPt:
          "Atualizações de prática clínica e diretrizes de gastroenterologia.",
      url: "https://gastro.org/clinical-guidance/",
    ),
    _ReferenceEntry(
      nameEs: "AASLD",
      namePt: "AASLD",
      categoryEs: "Gastroenterología",
      categoryPt: "Gastroenterologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "Continua",
      descriptionEs:
          "Hepatitis, cirrosis, hipertensión portal, hepatocarcinoma y enfermedades hepáticas.",
      descriptionPt:
          "Hepatites, cirrose, hipertensão portal, hepatocarcinoma e doenças hepáticas.",
      url: "https://www.aasld.org/practice-guidelines",
    ),
    _ReferenceEntry(
      nameEs: "EASL",
      namePt: "EASL",
      categoryEs: "Gastroenterología",
      categoryPt: "Gastroenterologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "Continua",
      descriptionEs: "Guías europeas de hepatología y enfermedad hepática.",
      descriptionPt: "Diretrizes europeias de hepatologia e doença hepática.",
      url: "https://easl.eu/publications/clinical-practice-guidelines/",
    ),
    _ReferenceEntry(
      nameEs: "ACR",
      namePt: "ACR",
      categoryEs: "Reumatología",
      categoryPt: "Reumatologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2024–2026",
      descriptionEs:
          "Lupus, nefritis lúpica, artritis, vasculitis y enfermedades reumatológicas.",
      descriptionPt:
          "Lúpus, nefrite lúpica, artrite, vasculites e doenças reumatológicas.",
      url: "https://rheumatology.org/clinical-practice-guidelines",
    ),
    _ReferenceEntry(
      nameEs: "EULAR",
      namePt: "EULAR",
      categoryEs: "Reumatología",
      categoryPt: "Reumatologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2024–2026",
      descriptionEs:
          "Recomendaciones europeas para enfermedades autoinmunes y musculoesqueléticas.",
      descriptionPt:
          "Recomendações europeias para doenças autoimunes e musculoesqueléticas.",
      url: "https://www.eular.org/recommendations-home",
    ),
    _ReferenceEntry(
      nameEs: "ASH",
      namePt: "ASH",
      categoryEs: "Hematología",
      categoryPt: "Hematologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "Continua",
      descriptionEs: "Trombosis, anticoagulación y enfermedades hematológicas.",
      descriptionPt: "Trombose, anticoagulação e doenças hematológicas.",
      url:
          "https://www.hematology.org/education/clinicians/guidelines-and-quality-care",
    ),
    _ReferenceEntry(
      nameEs: "AHA / ASA Stroke",
      namePt: "AHA / ASA AVC",
      categoryEs: "Neurología",
      categoryPt: "Neurologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2026",
      descriptionEs: "Prevención y manejo agudo del accidente cerebrovascular.",
      descriptionPt: "Prevenção e manejo agudo do acidente vascular cerebral.",
      url: "https://professional.heart.org/en/guidelines-and-statements",
    ),
    _ReferenceEntry(
      nameEs: "AAN",
      namePt: "AAN",
      categoryEs: "Neurología",
      categoryPt: "Neurologia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "Continua",
      descriptionEs:
          "Guías de neurología, epilepsia y enfermedades neuromusculares.",
      descriptionPt:
          "Diretrizes de neurologia, epilepsia e doenças neuromusculares.",
      url: "https://www.aan.com/Guidelines/home",
    ),
    _ReferenceEntry(
      nameEs: "ACOG",
      namePt: "ACOG",
      categoryEs: "Ginecología y obstetricia",
      categoryPt: "Ginecologia e obstetrícia",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "Continua",
      descriptionEs: "Obstetricia, ginecología, embarazo y urgencias maternas.",
      descriptionPt: "Obstetrícia, ginecologia, gestação e urgências maternas.",
      url: "https://www.acog.org/clinical",
    ),
    _ReferenceEntry(
      nameEs: "AAP",
      namePt: "AAP",
      categoryEs: "Pediatría",
      categoryPt: "Pediatria",
      typeEs: "Directriz",
      typePt: "Diretriz",
      year: "2025–2026",
      descriptionEs:
          "Pediatría, reanimación, infecciones respiratorias y cuidado infantil.",
      descriptionPt:
          "Pediatria, reanimação, infecções respiratórias e cuidado infantil.",
      url:
          "https://publications.aap.org/pediatrics/pages/clinical-practice-guidelines",
    ),
    _ReferenceEntry(
      nameEs: "NICE",
      namePt: "NICE",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Base clínica",
      typePt: "Base clínica",
      year: "Continua",
      descriptionEs:
          "Guías clínicas multidisciplinarias con recomendaciones diagnósticas y terapéuticas.",
      descriptionPt:
          "Diretrizes clínicas multidisciplinares com recomendações diagnósticas e terapêuticas.",
      url: "https://www.nice.org.uk/guidance",
    ),
    _ReferenceEntry(
      nameEs: "PubMed / NLM",
      namePt: "PubMed / NLM",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Base bibliográfica",
      typePt: "Base bibliográfica",
      year: "Continua",
      descriptionEs:
          "Indexación biomédica utilizada para rastrear publicaciones, consensos y DOI.",
      descriptionPt:
          "Indexação biomédica usada para rastrear publicações, consensos e DOI.",
      url: "https://pubmed.ncbi.nlm.nih.gov/",
    ),
    _ReferenceEntry(
      nameEs: "accessmedicine.mhmedical.com",
      namePt: "accessmedicine.mhmedical.com",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://accessmedicine.mhmedical.com",
    ),
    _ReferenceEntry(
      nameEs: "uptodate.com",
      namePt: "uptodate.com",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://www.uptodate.com",
    ),
    _ReferenceEntry(
      nameEs: "reference.medscape.com",
      namePt: "reference.medscape.com",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://reference.medscape.com",
    ),
    _ReferenceEntry(
      nameEs: "ahajournals.org",
      namePt: "ahajournals.org",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://www.ahajournals.org",
    ),
    _ReferenceEntry(
      nameEs: "publicacoes.cardiol.br",
      namePt: "publicacoes.cardiol.br",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://publicacoes.cardiol.br",
    ),
    _ReferenceEntry(
      nameEs: "idsociety.org",
      namePt: "idsociety.org",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://www.idsociety.org/practice-guideline",
    ),
    _ReferenceEntry(
      nameEs: "sanfordguide.com",
      namePt: "sanfordguide.com",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://www.sanfordguide.com",
    ),
    _ReferenceEntry(
      nameEs: "sccm.org",
      namePt: "sccm.org",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://www.sccm.org/SurvivingSepsisCampaign",
    ),
    _ReferenceEntry(
      nameEs: "thoracic.org",
      namePt: "thoracic.org",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://www.thoracic.org/statements",
    ),
    _ReferenceEntry(
      nameEs: "mdcalc.com",
      namePt: "mdcalc.com",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://www.mdcalc.com",
    ),
    _ReferenceEntry(
      nameEs: "pubmed.ncbi.nlm.nih.gov",
      namePt: "pubmed.ncbi.nlm.nih.gov",
      categoryEs: "General",
      categoryPt: "Geral",
      typeEs: "Referencia existente",
      typePt: "Referência existente",
      year: "—",
      descriptionEs: "Enlace preservado de la pantalla bibliográfica anterior.",
      descriptionPt: "Link preservado da tela bibliográfica anterior.",
      url: "https://pubmed.ncbi.nlm.nih.gov",
    ),
  ];

  List<_ReferenceEntry> _filtered(bool isEs) {
    final normalized = _query.trim().toLowerCase();
    return _references.where((item) {
      final category = isEs ? item.categoryEs : item.categoryPt;
      if (_category != null && category != _category) return false;
      if (normalized.isEmpty) return true;
      final haystack = <String>[
        item.nameEs,
        item.namePt,
        item.categoryEs,
        item.categoryPt,
        item.typeEs,
        item.typePt,
        item.descriptionEs,
        item.descriptionPt,
        item.year,
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList(growable: false);
  }

  List<String> _categories(bool isEs) {
    final values = _references
        .map((item) => isEs ? item.categoryEs : item.categoryPt)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  Future<void> _openReference(_ReferenceEntry item, bool isEs) async {
    final uri = Uri.parse(item.url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEs
                ? 'No fue posible abrir esta fuente.'
                : 'Não foi possível abrir esta fonte.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? _darkBackground : _lightBackground;
    final surface = dark ? _darkSurface : Colors.white;
    final primaryText = dark ? Colors.white : const Color(0xFF111827);
    final secondaryText =
        dark ? const Color(0xFFB6C0CA) : const Color(0xFF667085);
    final divider = dark ? _darkDivider : _lightDivider;
    final visible = _filtered(isEs);
    final categories = _categories(isEs);
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _CanonicalTopBar(
              dark: dark,
              divider: divider,
              title: isEs ? 'Fuentes y directrices' : 'Fontes e diretrizes',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + safeBottom),
                children: <Widget>[
                  _BibliographyIntro(
                    dark: dark,
                    surface: surface,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    isEs: isEs,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: isEs
                          ? 'Buscar fuente, sociedad o especialidad'
                          : 'Buscar fonte, sociedade ou especialidade',
                      hintStyle: TextStyle(color: secondaryText, fontSize: 13),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: secondaryText,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: divider, width: 0.8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _brand, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final value = index == 0 ? null : categories[index - 1];
                        final selected = value == _category;
                        return ChoiceChip(
                          selected: selected,
                          onSelected: (_) => setState(() => _category = value),
                          label: Text(
                            value ?? 'Todas',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                          selectedColor: _brand.withOpacity(dark ? 0.24 : 0.12),
                          backgroundColor: surface,
                          side: BorderSide(
                            color: selected ? _brand : divider,
                            width: 0.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          visualDensity: VisualDensity.compact,
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          isEs ? 'BASES Y SOCIEDADES' : 'BASES E SOCIEDADES',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      Text(
                        '${visible.length}',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (visible.isEmpty)
                    _EmptyReferences(
                      dark: dark,
                      surface: surface,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      isEs: isEs,
                    )
                  else
                    ...visible.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _ReferenceCard(
                          item: item,
                          dark: dark,
                          surface: surface,
                          divider: divider,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          isEs: isEs,
                          onTap: () => _openReference(item, isEs),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanonicalTopBar extends StatelessWidget {
  const _CanonicalTopBar({
    required this.dark,
    required this.divider,
    required this.title,
    required this.onBack,
  });

  final bool dark;
  final Color divider;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0F171F) : Colors.white,
        border: Border(bottom: BorderSide(color: divider, width: 0.7)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: dark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 54),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dark ? Colors.white : const Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BibliographyIntro extends StatelessWidget {
  const _BibliographyIntro({
    required this.dark,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
    required this.isEs,
  });

  final bool dark;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;
  final bool isEs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark ? const Color(0xFF26323D) : const Color(0xFFE2E7EC),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _FontesScreenState._brand.withOpacity(
                    dark ? 0.20 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 20,
                  color: _FontesScreenState._brand,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Base bibliográfica clínica',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isEs
                          ? 'El contenido clínico de MedCases se apoya en guías oficiales, consensos, sociedades médicas y literatura biomédica curada. Esta pantalla resume las principales autoridades del catálogo.'
                          : 'O conteúdo clínico do MedCases se apoia em diretrizes oficiais, consensos, sociedades médicas e literatura biomédica curada. Esta tela resume as principais autoridades do catálogo.',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _MetricPill(
                label: isEs ? '200+ temas clínicos' : '200+ temas clínicos',
                dark: dark,
              ),
              _MetricPill(
                label: isEs
                    ? '600+ referencias curadas'
                    : '600+ referências curadas',
                dark: dark,
              ),
              _MetricPill(
                label: isEs ? 'Actualización 2026' : 'Atualização 2026',
                dark: dark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _FontesScreenState._brand.withOpacity(dark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _FontesScreenState._brand,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    required this.item,
    required this.dark,
    required this.surface,
    required this.divider,
    required this.primaryText,
    required this.secondaryText,
    required this.isEs,
    required this.onTap,
  });

  final _ReferenceEntry item;
  final bool dark;
  final Color surface;
  final Color divider;
  final Color primaryText;
  final Color secondaryText;
  final bool isEs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = isEs ? item.nameEs : item.namePt;
    final description = isEs ? item.descriptionEs : item.descriptionPt;
    final type = isEs ? item.typeEs : item.typePt;
    final category = isEs ? item.categoryEs : item.categoryPt;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: divider, width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 4,
                height: 42,
                margin: const EdgeInsets.only(top: 1, right: 11),
                decoration: BoxDecoration(
                  color: _FontesScreenState._brand,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.42,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: <Widget>[
                        _MetaTag(label: category, dark: dark),
                        _MetaTag(label: type, dark: dark),
                        if (item.year != '—')
                          _MetaTag(label: item.year, dark: dark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1D2832) : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? const Color(0xFFC5CED6) : const Color(0xFF667085),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyReferences extends StatelessWidget {
  const _EmptyReferences({
    required this.dark,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
    required this.isEs,
  });

  final bool dark;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;
  final bool isEs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? const Color(0xFF26323D) : const Color(0xFFE2E7EC),
          width: 0.8,
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.search_off_rounded, color: secondaryText, size: 24),
          const SizedBox(height: 8),
          Text(
            isEs ? 'Sin resultados' : 'Sem resultados',
            style: TextStyle(
              color: primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEs
                ? 'Prueba otra fuente o especialidad.'
                : 'Tente outra fonte ou especialidade.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceEntry {
  const _ReferenceEntry({
    required this.nameEs,
    required this.namePt,
    required this.categoryEs,
    required this.categoryPt,
    required this.typeEs,
    required this.typePt,
    required this.year,
    required this.descriptionEs,
    required this.descriptionPt,
    required this.url,
  });

  final String nameEs;
  final String namePt;
  final String categoryEs;
  final String categoryPt;
  final String typeEs;
  final String typePt;
  final String year;
  final String descriptionEs;
  final String descriptionPt;
  final String url;
}

// MEDCASES_FONTES_ROUTE_COMPATIBILITY_BRIDGE_PRE_PHYSICAL_V1
// Compatibility owner for the existing AppDrawer call. The canonical
// FontesScreen remains the visual owner; this bridge only restores navigation
// after the bibliography screen refresh removed the historical top-level helper.
void showFontesScreen(BuildContext context, {bool isEs = false}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FontesScreen(context, isEs: isEs),
    ),
  );
}
