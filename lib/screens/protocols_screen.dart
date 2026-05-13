import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/protocol_model.dart';
import '../widgets/common_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FUNÇÃO GLOBAL — abre detalhe de protocolo como bottom sheet
// Pode ser chamada de qualquer tela do app (cockpit, chips, lista)
// ─────────────────────────────────────────────────────────────────────────────
void showProtocolDetail(BuildContext context, ProtocolModel protocol) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProtocolDetailSheet(protocol: protocol),
  );
}

// Busca protocolo por ID no provider e abre o detalhe direto
void openProtocolById(BuildContext context, String id) {
  final p = context.read<AppProvider>();
  try {
    final found = p.protocolsDB.firstWhere((x) => x.id == id);
    showProtocolDetail(context, found);
  } catch (_) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// TELA DE PROTOCOLOS — lista por grupos (acordeão)
// ─────────────────────────────────────────────────────────────────────────────
class ProtocolsScreen extends StatefulWidget {
  const ProtocolsScreen({super.key});

  @override
  State<ProtocolsScreen> createState() => _ProtocolsScreenState();
}

class _ProtocolsScreenState extends State<ProtocolsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final isEs = p.lang == 'es';

    final q           = _searchCtrl.text.toLowerCase().trim();
    final isSearching = q.isNotEmpty;

    // ── Lista completa de protocolos (deduplicada por id) ──────────────────
    final seen  = <String>{};
    final allDB = p.protocolsDB.where((x) => seen.add(x.id)).toList();

    // ── Filtro de busca ────────────────────────────────────────────────────
    final filtered = isSearching
        ? allDB.where((proto) {
            return p.tDB(proto.title).toLowerCase().contains(q) ||
                p.tDB(proto.severity).toLowerCase().contains(q) ||
                p.tDB(proto.recognize).toLowerCase().contains(q) ||
                proto.getActions(p.lang).any((a) => a.toLowerCase().contains(q));
          }).toList()
        : allDB;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      child: Column(children: [

        // ── Header premium ─────────────────────────────────────────────────
        PremiumCard(child: SectionTitle(
          eyebrow: 'Clinical Flow',
          title: p.t('protocols'),
          subtitle: p.t('protocols_subtitle'),
          light: true,
        )),
        const SizedBox(height: 12),

        // ── Busca ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MedInput(
              controller: _searchCtrl,
              hintText: p.t('search_protocol_hint'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              '${filtered.length} ${p.t("protocols_found")}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF888888)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Modo busca: lista flat ─────────────────────────────────────────
        if (isSearching) ...[
          ...filtered.map((proto) => _ProtocolListTile(
            proto: proto,
            p: p,
            isLast: proto == filtered.last,
            onTap: () => showProtocolDetail(context, proto),
          )),
        ]

        // ── Modo normal: acordeão por sistema clínico ──────────────────────
        else ...[

          // Favoritos no topo
          if (p.favProtocols.isNotEmpty) ...[
            _ProtocolGroupAccordion(
              groupKey: '__fav__',
              icon: '',
              iconData: Icons.star_rounded,
              titlePt: 'Favoritos',
              titleEs: 'Favoritos',
              color: const Color(0xFFFFFBF0),
              borderColor: const Color(0xFFE8D8A0),
              iconColor: const Color(0xFFC5A365),
              protocols: allDB.where((d) => p.favProtocols.contains(d.id)).toList(),
              isEs: isEs,
              p: p,
              onSelect: (proto) => showProtocolDetail(context, proto),
            ),
            const SizedBox(height: 8),
          ],

          // ── Reanimação & Choque ──────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'reanimacao',
            icon: '',
            iconData: Icons.emergency_rounded,
            titlePt: 'Reanimação & Choque',
            titleEs: 'Reanimación & Shock',
            color: const Color(0xFFFFF5F5),
            borderColor: const Color(0xFFFFCCCC),
            iconColor: const Color(0xFFCC2222),
            protocols: allDB.where((d) => {
              'pcr_adulto', 'pcr_pediatrica', 'parada_respiratoria',
              'anafilaxia', 'anafilaxia_refrataria',
              'choque_cardiogenico', 'choque_septico_avancado', 'choque_hipovolemico',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Cardiovascular ───────────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'cardio',
            icon: '',
            iconData: Icons.favorite_outline_rounded,
            titlePt: 'Cardiovascular',
            titleEs: 'Cardiovascular',
            color: const Color(0xFFFFF0F5),
            borderColor: const Color(0xFFFFCCDD),
            iconColor: const Color(0xFFAA1144),
            protocols: allDB.where((d) => {
              'iam_congestao', 'sindrome_coronariana_sem_st',
              'insuficiencia_cardiaca_descomp', 'edema_agudo_pulmao',
              'tpsv', 'fa_aguda', 'bradiarritmia_grave',
              'crise_hipertensiva', 'miocardite_aguda', 'pericardite_aguda',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Respiratório ─────────────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'resp',
            icon: '',
            iconData: Icons.air_rounded,
            titlePt: 'Respiratório',
            titleEs: 'Respiratorio',
            color: const Color(0xFFF0F8FF),
            borderColor: const Color(0xFFBBD6F0),
            iconColor: const Color(0xFF1A5E8A),
            protocols: allDB.where((d) => {
              'asma_grave', 'crise_asmatica_quase_fatal',
              'dpoc_exacerbacao',
              'tep_agudo', 'tromboembolismo_pulmonar',
              'pneumonia_grave', 'pneumonia_aspirativa',
              'hemoptise_macica',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Neurológico & Psiquiátrico ───────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'neuro',
            icon: '',
            iconData: Icons.psychology_outlined,
            titlePt: 'Neurológico & Psiquiátrico',
            titleEs: 'Neurológico & Psiquiátrico',
            color: const Color(0xFFF5F0FF),
            borderColor: const Color(0xFFCCBBEE),
            iconColor: const Color(0xFF5C2D91),
            protocols: allDB.where((d) => {
              'avc_isquemico', 'avc_hemorragico',
              'status_epilepticus',
              'meningite_bacteriana',
              'agitacao_psicomotora', 'delirium_tremens',
              'encefalopatia_hepatica',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Infeccioso & Sepse ───────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'infec',
            icon: '',
            iconData: Icons.biotech_outlined,
            titlePt: 'Infeccioso & Sepse',
            titleEs: 'Infeccioso & Sepsis',
            color: const Color(0xFFF0FFF4),
            borderColor: const Color(0xFFBBE8CC),
            iconColor: const Color(0xFF075F45),
            protocols: allDB.where((d) => {
              'sepse', 'sepse_foco_urinario',
              'neutropenia_febril',
              'pielonefrite_aguda', 'celulite_erisipela',
              'dengue_manejo', 'colangite_aguda',
              'pbe_cirrose',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Metabólico & Endócrino ───────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'metab',
            icon: '',
            iconData: Icons.balance_outlined,
            titlePt: 'Metabólico & Endócrino',
            titleEs: 'Metabólico & Endócrino',
            color: const Color(0xFFFFF8EC),
            borderColor: const Color(0xFFEED8A0),
            iconColor: const Color(0xFF8B6000),
            protocols: allDB.where((d) => {
              'cad_shh', 'cetoacidose_diabetica',
              'hipoglicemia_grave',
              'hipercalemia_grave', 'hiperpotassemia_grave',
              'hipocalcemia_grave', 'hiponatremia_grave', 'hipernatremia_grave',
              'crise_adrenal', 'crise_tireotoxica',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Gastro, Trauma & Cirúrgico ───────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'gastro',
            icon: '',
            iconData: Icons.local_hospital_outlined,
            titlePt: 'Gastro, Trauma & Cirúrgico',
            titleEs: 'Gastro, Trauma & Quirúrgico',
            color: const Color(0xFFF5F5F0),
            borderColor: const Color(0xFFD8D4C0),
            iconColor: const Color(0xFF555544),
            protocols: allDB.where((d) => {
              'hda_varizeal', 'hda_nao_varicosa', 'hemorragia_digestiva_baixa',
              'pancreatite_aguda', 'pancreatite_aguda_grave',
              'apendicite_aguda', 'obstrucao_intestinal',
              'hemorragia_intra_abdominal',
              'politrauma_atls', 'sindrome_compartimental',
              'colica_nefretica',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Nefrologia, Hemato & Obstetrícia ─────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'outros',
            icon: '',
            iconData: Icons.science_outlined,
            titlePt: 'Nefrologia, Hemato & Obstetrícia',
            titleEs: 'Nefrología, Hemato & Obstetricia',
            color: const Color(0xFFF0F5FF),
            borderColor: const Color(0xFFBBCCEE),
            iconColor: const Color(0xFF1A3A7A),
            protocols: allDB.where((d) => {
              'lesao_renal_aguda', 'rabdomiolise_aguda',
              'coagulacao_intravascular',
              'crise_de_anemia_falciforme',
              'eclampsia_hellp', 'hemorragia_pos_parto', 'descolamento_placenta',
              'tromboembolismo_venoso_ped',
              'crise_gota', 'priapismo_emergencia',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Intoxicações ─────────────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'intox',
            icon: '',
            iconData: Icons.warning_amber_rounded,
            titlePt: 'Intoxicações & Overdose',
            titleEs: 'Intoxicaciones & Sobredosis',
            color: const Color(0xFFF8F0FF),
            borderColor: const Color(0xFFDDBBFF),
            iconColor: const Color(0xFF6A0DAD),
            protocols: allDB.where((d) => {
              'intoxicacao_exogena',
              'intox_opioides', 'intox_benzodiazepinas',
              'intox_paracetamol', 'intox_organofosforados',
              'intox_triciclicos', 'intox_betabloqueadores',
              'intox_metanol_etilenoglicol', 'intox_monoxido_carbono',
              'sindrome_abst_opioides', 'delirium_tremens',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Pediatria ────────────────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'ped',
            icon: '',
            iconData: Icons.child_care_rounded,
            titlePt: 'Pediatria',
            titleEs: 'Pediatría',
            color: const Color(0xFFF0FFFA),
            borderColor: const Color(0xFFAADDCC),
            iconColor: const Color(0xFF0A7060),
            protocols: allDB.where((d) => {
              'pcr_pediatrica',
              'anafilaxia_ped',
              'crise_asmatica_ped', 'mal_asmatico_ped',
              'bronquiolite_aguda', 'laringite_estridulosa',
              'convulsao_febril_ped',
              'meningite_pediatrica',
              'crise_hipertensiva_ped',
              'sinusite_bacteriana_ped', 'faringite_estrep',
              'mastoidite_aguda',
              'tromboembolismo_venoso_ped',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Casos Clínicos — Neurologia ──────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'casos_neuro',
            icon: '',
            iconData: Icons.psychology_outlined,
            titlePt: 'Casos Clínicos — Neurologia',
            titleEs: 'Casos Clínicos — Neurología',
            color: const Color(0xFFF5F0FF),
            borderColor: const Color(0xFFCCBBEE),
            iconColor: const Color(0xFF5C2D91),
            protocols: allDB.where((d) => {
              'caso_enxaqueca_aura',
              'caso_avc_isquemico',
              'caso_status_epilepticus',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Casos Clínicos — Cardiologia & Pneumologia ───────────────────
          _ProtocolGroupAccordion(
            groupKey: 'casos_cardio',
            icon: '',
            iconData: Icons.favorite_outline_rounded,
            titlePt: 'Casos Clínicos — Cardiologia & Pneumologia',
            titleEs: 'Casos Clínicos — Cardiología & Neumología',
            color: const Color(0xFFFFF0F5),
            borderColor: const Color(0xFFFFCCDD),
            iconColor: const Color(0xFFAA1144),
            protocols: allDB.where((d) => {
              'caso_stemi',
              'caso_icc_descompensada',
              'caso_tep_alto_risco',
              'caso_pac_grave',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Casos Clínicos — Infectologia, Emergência & Metabólico ───────
          _ProtocolGroupAccordion(
            groupKey: 'casos_infec',
            icon: '',
            iconData: Icons.biotech_outlined,
            titlePt: 'Casos Clínicos — Infectologia, Emergência & Metabólico',
            titleEs: 'Casos Clínicos — Infectología, Emergencia & Metabólico',
            color: const Color(0xFFF0FFF4),
            borderColor: const Color(0xFFBBE8CC),
            iconColor: const Color(0xFF075F45),
            protocols: allDB.where((d) => {
              'caso_cistite_aguda',
              'caso_itu_recorrente',
              'caso_sepse_idoso',
              'caso_cetoacidose_diabetica',
              'caso_anafilaxia_grave',
              'caso_hda_varicosa',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Casos Clínicos — Gastroenterologia ──────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'casos_gastro',
            icon: '',
            iconData: Icons.local_hospital_outlined,
            titlePt: 'Casos Clínicos — Gastroenterologia & Hepatologia',
            titleEs: 'Casos Clínicos — Gastroenterología & Hepatología',
            color: const Color(0xFFF5F5F0),
            borderColor: const Color(0xFFD8D4C0),
            iconColor: const Color(0xFF555544),
            protocols: allDB.where((d) => {
              'pancreatitis_aguda_005',
              'diarrea_aguda_009',
              'hda_ulcera_peptica_013',
              'hdb_sangrado_rectal_014',
              'diverticulitis_aguda_015',
              'sindrome_ascitico_debut_016',
              'sindrome_ascitico_edematoso_017',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Casos Clínicos — Infectologia & Hepatologia Viral ────────────
          _ProtocolGroupAccordion(
            groupKey: 'casos_hepato_viral',
            icon: '',
            iconData: Icons.science_outlined,
            titlePt: 'Casos Clínicos — Hepatites Virais & Gripe',
            titleEs: 'Casos Clínicos — Hepatitis Virales & Gripe',
            color: const Color(0xFFFFF8EC),
            borderColor: const Color(0xFFEED8A0),
            iconColor: const Color(0xFF8B6000),
            protocols: allDB.where((d) => {
              'hepatitis_b_aguda_detallada_2026',
              'hepatitis_c_cronica_detallada_2026',
              'gripe_influenza_010',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Casos Clínicos — ORL & Medicina Geral ───────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'casos_orl',
            icon: '',
            iconData: Icons.hearing_outlined,
            titlePt: 'Casos Clínicos — ORL & Medicina Geral',
            titleEs: 'Casos Clínicos — ORL & Medicina General',
            color: const Color(0xFFF0F8FF),
            borderColor: const Color(0xFFBBD6F0),
            iconColor: const Color(0xFF1A5E8A),
            protocols: allDB.where((d) => {
              'rinosinusitis_aguda_007',
              'faringitis_estreptococica_008',
              'faringitis_viral_011',
              'faringitis_bacteriana_012',
            }.contains(d.id)).toList(),
            p: p, isEs: isEs,
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE GRUPO — fechado, abre bottom sheet temático ao clicar
// ─────────────────────────────────────────────────────────────────────────────
class _ProtocolGroupAccordion extends StatelessWidget {
  final String groupKey;
  final String icon;
  final IconData? iconData;
  final String titlePt;
  final String titleEs;
  final Color color;
  final Color borderColor;
  final Color iconColor;
  final List<ProtocolModel> protocols;
  final bool isEs;
  final AppProvider p;
  final ValueChanged<ProtocolModel> onSelect;

  const _ProtocolGroupAccordion({
    required this.groupKey,
    required this.icon,
    this.iconData,
    required this.titlePt,
    required this.titleEs,
    required this.color,
    required this.borderColor,
    required this.iconColor,
    required this.protocols,
    required this.isEs,
    required this.p,
    required this.onSelect,
  });

  void _openSheet(BuildContext context) {
    final title = isEs ? titleEs : titlePt;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupSheet(
        title: title,
        iconData: iconData,
        icon: icon,
        cardColor: color,
        borderColor: borderColor,
        iconColor: iconColor,
        protocols: protocols,
        p: p,
        isEs: isEs,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (protocols.isEmpty) return const SizedBox.shrink();
    final title = isEs ? titleEs : titlePt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _openSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            // Ícone
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: iconData != null
                    ? Icon(iconData, size: 20, color: iconColor)
                    : Text(icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            // Título + contagem
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w900,
                  color: iconColor, letterSpacing: -0.2)),
              const SizedBox(height: 3),
              Text(
                '${protocols.length} ${protocols.length == 1
                    ? (isEs ? 'protocolo' : 'protocolo')
                    : (isEs ? 'protocolos' : 'protocolos')}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: iconColor.withValues(alpha: 0.55))),
            ])),
            // Seta de abertura
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.chevron_right_rounded,
                size: 20, color: iconColor.withValues(alpha: 0.8)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET TEMÁTICO — lista de protocolos com cor do grupo
// ─────────────────────────────────────────────────────────────────────────────
class _GroupSheet extends StatelessWidget {
  final String title;
  final String icon;
  final IconData? iconData;
  final Color cardColor;
  final Color borderColor;
  final Color iconColor;
  final List<ProtocolModel> protocols;
  final AppProvider p;
  final bool isEs;
  final ValueChanged<ProtocolModel> onSelect;

  const _GroupSheet({
    required this.title,
    required this.icon,
    this.iconData,
    required this.cardColor,
    required this.borderColor,
    required this.iconColor,
    required this.protocols,
    required this.p,
    required this.isEs,
    required this.onSelect,
  });

  // Gera versão levemente mais escura da cor do card para o fundo do sheet
  Color get _sheetBg {
    final r = (cardColor.red * 0.97).round().clamp(0, 255);
    final g = (cardColor.green * 0.97).round().clamp(0, 255);
    final b = (cardColor.blue * 0.97).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  // Cor dos tiles — levemente mais clara que o fundo
  Color get _tileBg {
    final r = (cardColor.red + (255 - cardColor.red) * 0.55).round().clamp(0, 255);
    final g = (cardColor.green + (255 - cardColor.green) * 0.55).round().clamp(0, 255);
    final b = (cardColor.blue + (255 - cardColor.blue) * 0.55).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  Color get _severityColor {
    // Cor de severidade adaptada ao tema
    return iconColor;
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;

    return Container(
      height: maxH,
      decoration: BoxDecoration(
        color: _sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [

        // ── Alça de arraste ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 0),
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // ── Header do grupo (igual ao card) ───────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: iconData != null
                    ? Icon(iconData, size: 20, color: iconColor)
                    : Text(icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: iconColor, letterSpacing: -0.2)),
              const SizedBox(height: 3),
              Text(
                '${protocols.length} ${isEs ? 'protocolos disponibles' : 'protocolos disponíveis'}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: iconColor.withValues(alpha: 0.55))),
            ])),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Lista de protocolos ────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: protocols.length,
            itemBuilder: (context, index) {
              final proto = protocols[index];
              final isLast = index == protocols.length - 1;
              final isFav = p.favProtocols.contains(proto.id);
              final sevText = p.tDB(proto.severity);

              // Cor do badge de severidade
              Color sevColor;
              final sevLower = sevText.toLowerCase();
              if (sevLower.contains('crít') || sevLower.contains('crít')) {
                sevColor = const Color(0xFFCC2222);
              } else if (sevLower.contains('alto')) {
                sevColor = const Color(0xFFE07000);
              } else {
                sevColor = iconColor;
              }

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(proto);
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: _tileBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // Severidade + favorito
                      Row(children: [
                        if (isFav)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: Icon(Icons.star_rounded, size: 12, color: kGold),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sevColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(sevText,
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900,
                              color: sevColor, letterSpacing: 1.2)),
                        ),
                      ]),
                      const SizedBox(height: 5),

                      // Título
                      Text(p.tDB(proto.title),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                          color: iconColor),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2),
                      const SizedBox(height: 4),

                      // Preview
                      Text(p.tDB(proto.recognize),
                        style: TextStyle(fontSize: 11.5,
                          color: iconColor.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w500, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ])),

                    const SizedBox(width: 10),

                    // Ações: favorito + seta
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      GestureDetector(
                        onTap: () => p.toggleFavProtocol(proto.id),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isFav ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 20,
                            color: isFav ? kGold : iconColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.arrow_forward_ios_rounded,
                          size: 13, color: iconColor.withValues(alpha: 0.8)),
                      ),
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),

        // ── Botão fechar ───────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16,
            MediaQuery.of(context).padding.bottom + 12),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: borderColor.withValues(alpha: 0.35),
                border: Border.all(color: borderColor),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  isEs ? 'Cerrar' : 'Fechar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    color: iconColor),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TILE DE PROTOCOLO — clique em qualquer área abre o detalhe diretamente
// ─────────────────────────────────────────────────────────────────────────────
class _ProtocolListTile extends StatelessWidget {
  final ProtocolModel proto;
  final AppProvider p;
  final bool isLast;
  final VoidCallback onTap;

  const _ProtocolListTile({
    required this.proto,
    required this.p,
    this.isLast = false,
    required this.onTap,
  });

  // Cor do badge de severidade
  Color _severityColor(String sev) {
    final lower = sev.toLowerCase();
    if (lower.contains('crít') || lower.contains('crít')) return const Color(0xFFCC2222);
    if (lower.contains('alto') || lower.contains('alto')) return const Color(0xFFE07000);
    return kGold;
  }

  @override
  Widget build(BuildContext context) {
    final isFav    = p.favProtocols.contains(proto.id);
    final sevText  = p.tDB(proto.severity);
    final sevColor = _severityColor(sevText);

    return GestureDetector(
      onTap: onTap,   // clique em qualquer área → abre o detalhe direto
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: AppColors.of(context).border, width: 0.8)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Severidade + favorito
            Row(children: [
              if (isFav)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Icon(Icons.star_rounded, size: 12, color: kGold),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(sevText,
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900,
                    color: sevColor, letterSpacing: 1.2)),
              ),
            ]),
            const SizedBox(height: 5),

            // Título
            Text(p.tDB(proto.title),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                color: AppColors.of(context).textPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
            const SizedBox(height: 4),

            // Reconhecer — preview resumido
            Text(p.tDB(proto.recognize),
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF777777),
                fontWeight: FontWeight.w500, height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),

          const SizedBox(width: 10),

          // Ações: favorito + seta de abertura
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: () => p.toggleFavProtocol(proto.id),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  color: isFav ? kGold : const Color(0xFFCCCCCC),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.of(context).darkBtn,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: kGoldLight),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET — detalhe completo do protocolo
// Abre a partir de qualquer ponto do app via showProtocolDetail()
// ─────────────────────────────────────────────────────────────────────────────
class _ProtocolDetailSheet extends StatelessWidget {
  final ProtocolModel protocol;
  const _ProtocolDetailSheet({required this.protocol});

  @override
  Widget build(BuildContext context) {
    final p       = context.watch<AppProvider>();
    final actions = protocol.getActions(p.lang);
    final isFav   = p.favProtocols.contains(protocol.id);
    final avoidTxt = p.tDB(protocol.avoid);
    final drugs   = protocol.drugs;
    final maxH = MediaQuery.of(context).size.height * 0.92;

    return Container(
      height: maxH,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [

        // ── Alça de arraste ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // ── Conteúdo scrollável ────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Header premium ───────────────────────────────────────────
              PremiumCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.tDB(protocol.severity),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                        color: Color(0xBFFFE8A6), letterSpacing: 1.4)),
                    const SizedBox(height: 4),
                    Text(p.tDB(protocol.title),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.5, height: 1.2)),
                  ])),
                  // Favorito
                  GestureDetector(
                    onTap: () => p.toggleFavProtocol(protocol.id),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        isFav ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 22,
                        color: isFav ? const Color(0xFFFFE8A6) : Colors.white54,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Reconhecer ───────────────────────────────────────────────
              _RecognizeCard(text: p.tDB(protocol.recognize), p: p),
              const SizedBox(height: 10),

              // ── Conduta imediata ─────────────────────────────────────────
              _ActionsCard(actions: actions, p: p),
              const SizedBox(height: 10),

              // ── Evitar ───────────────────────────────────────────────────
              if (avoidTxt.isNotEmpty) ...[
                _AvoidCard(text: avoidTxt, p: p),
                const SizedBox(height: 10),
              ],

              // ── Fármacos relacionados ────────────────────────────────────
              if (drugs.isNotEmpty) ...[
                _DrugsChipsCard(drugs: drugs, p: p),
                const SizedBox(height: 10),
              ],

              // ── Botão fechar ─────────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDDD8CC)),
                    color: AppColors.of(context).cardBg,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.of(context).textPrimary),
                    const SizedBox(width: 6),
                    Text(
                      p.lang == 'es' ? 'Cerrar' : 'Fechar',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.of(context).textPrimary),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: RECONHECER
// ─────────────────────────────────────────────────────────────────────────────
class _RecognizeCard extends StatelessWidget {
  final String text;
  final AppProvider p;
  const _RecognizeCard({required this.text, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFFBF0),
        border: Border.all(color: const Color(0xFFE8D8A0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFC5A365).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(p.t('recognize').toUpperCase(),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                color: Color(0xFF8B6914), letterSpacing: 1.8)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
            color: Color(0xFF3D2E00), height: 1.55)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: CONDUTA — com badge numerado + linha conectora + labels semânticos
// ─────────────────────────────────────────────────────────────────────────────
class _ActionsCard extends StatelessWidget {
  final List<String> actions;
  final AppProvider p;
  const _ActionsCard({required this.actions, required this.p});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().darkMode;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Header da seção ─────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: const Color(0xFF4ADE80),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            p.t('actions').toUpperCase(),
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ]),
      ),

      // ── Passos individuais ───────────────────────────────────────────────
      ...List.generate(actions.length, (i) => _ActionStepRow(
        index: i,
        text: actions[i],
        isLast: i == actions.length - 1,
        p: p,
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LINHA DE PASSO — badge + linha conectora + classificação semântica
// ─────────────────────────────────────────────────────────────────────────────
class _ActionStepRow extends StatelessWidget {
  final int index;
  final String text;
  final bool isLast;
  final AppProvider p;

  const _ActionStepRow({
    required this.index,
    required this.text,
    required this.isLast,
    required this.p,
  });

  // ── Classificação semântica do passo ──────────────────────────────────────
  _StepType _classify(String t) {
    final lower = t.toLowerCase();

    // Urgência / Reperfusão / Cirurgia emergencial
    if (lower.contains('urgente') || lower.contains('emergência') ||
        lower.contains('cirurgia') || lower.contains('reperfusão') ||
        lower.contains('reperfusión') || lower.contains('icp') ||
        lower.contains('fibrinólise') || lower.contains('fibrinolisis') ||
        lower.contains('rcp') || lower.contains('desfibril') ||
        lower.contains('cardiovers') || lower.contains('intubação') ||
        lower.contains('intubación') || lower.contains('cricotireot') ||
        lower.contains('toracostomia') || lower.contains('pericardiocentese')) {
      return _StepType.urgent;
    }

    // Evitar / Contraindicação inline
    if (lower.contains('evitar') || lower.contains('não usar') ||
        lower.contains('no usar') || lower.contains('contraindicado') ||
        lower.contains('contraindicad') || lower.contains('cuidado com') ||
        lower.contains('cautela')) {
      return _StepType.avoid;
    }

    // Monitorização / Reavaliação
    if (lower.contains('monitor') || lower.contains('reavaliar') ||
        lower.contains('reevaluar') || lower.contains('controlar') ||
        lower.contains('acompanhar') || lower.contains('verificar') ||
        lower.contains('checar') || lower.contains('ecg') ||
        lower.contains('spo2') || lower.contains('pa ') ||
        lower.contains('diurese') || lower.contains('lactato')) {
      return _StepType.monitor;
    }

    // Acesso / Via / Preparação
    if (lower.contains('acesso venoso') || lower.contains('acesso iv') ||
        lower.contains('acesso vv') || lower.contains('via aérea') ||
        lower.contains('vía aérea') || lower.contains('posicionar') ||
        lower.contains('exames') || lower.contains('gasometria') ||
        lower.contains('hemograma') || lower.contains('colher') ||
        lower.contains('solicitar') || lower.contains('chamar') ||
        lower.contains('notificar') || lower.contains('acionar')) {
      return _StepType.prepare;
    }

    // Primeiro passo — destaque máximo
    if (index == 0) return _StepType.primary;

    return _StepType.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().darkMode;
    final type = _classify(text);
    final cfg  = _config(type);

    // Divide texto em parte principal e sub-detalhe (entre parênteses)
    final parenMatch = RegExp(r'^(.*?)\s*\(([^)]+)\)\s*(.*)$').firstMatch(text);
    final hasParen   = parenMatch != null;
    final mainText   = hasParen
        ? '${parenMatch.group(1)!.trim()}${parenMatch.group(3)!.trim()}'.trim()
        : text;
    final subText    = hasParen ? parenMatch.group(2)! : null;

    // Cores adaptativas dark/light
    final cardBg     = dark ? cfg.cardBgDark     : cfg.cardBgLight;
    final cardBorder = dark ? cfg.cardBorderDark : cfg.cardBorderLight;
    final textMain   = dark ? cfg.textDark        : cfg.textLight;
    final textSub    = dark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Badge numérico + linha conectora ──────────────────────────────
        SizedBox(
          width: 32,
          child: Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: cfg.badgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: cfg.badgeBorder, width: 1.5),
              ),
              child: Center(
                child: cfg.badgeIcon != null
                    ? Icon(cfg.badgeIcon, size: 13, color: cfg.badgeFg)
                    : Text('${index + 1}',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900,
                          color: cfg.badgeFg)),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 8,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
              ),
          ]),
        ),

        const SizedBox(width: 10),

        // ── Card do passo ─────────────────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 0),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: cardBg,
              border: Border.all(color: cardBorder, width: 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Label semântico
              if (cfg.label != null) ...[
                Text(cfg.label!,
                  style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w900,
                    color: cfg.labelColor, letterSpacing: 1.8)),
                const SizedBox(height: 4),
              ],

              // Texto principal
              Text(mainText,
                style: TextStyle(
                  fontSize: cfg.fontSize,
                  fontWeight: cfg.fontWeight,
                  color: textMain,
                  height: 1.45,
                  letterSpacing: -0.1)),

              // Sub-detalhe entre parênteses
              if (subText != null) ...[
                const SizedBox(height: 5),
                Text(subText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textSub,
                    height: 1.4,
                    fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  _StepCfg _config(_StepType t) {
    switch (t) {
      case _StepType.primary:
        return const _StepCfg(
          label: null,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          textDark: Colors.white,
          textLight: Color(0xFF0F172A),
          cardBgDark: Color(0xFF1A2E1F),
          cardBgLight: Color(0xFFECFDF5),
          cardBorderDark: Color(0xFF22543D),
          cardBorderLight: Color(0xFF86EFAC),
          badgeBg: Color(0x40FFE8A6),
          badgeBorder: Color(0xB3FFE8A6),
          badgeFg: Color(0xFFFFE8A6),
        );
      case _StepType.urgent:
        return _StepCfg(
          label: p.lang == 'es' ? 'URGENTE' : 'URGENTE',
          labelColor: const Color(0xFFEF4444),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          textDark: const Color(0xFFFFCCCC),
          textLight: const Color(0xFF7F1D1D),
          cardBgDark: const Color(0xFF2A1515),
          cardBgLight: const Color(0xFFFFF0F0),
          cardBorderDark: const Color(0xFF6B2020),
          cardBorderLight: const Color(0xFFFCA5A5),
          badgeBg: const Color(0x33FF6B6B),
          badgeBorder: const Color(0x8CFF6B6B),
          badgeFg: const Color(0xFFFF9090),
          badgeIcon: Icons.priority_high_rounded,
        );
      case _StepType.avoid:
        return _StepCfg(
          label: p.lang == 'es' ? 'PRECAUCIÓN' : 'ATENÇÃO',
          labelColor: const Color(0xFFF59E0B),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textDark: const Color(0xFFFFD59A),
          textLight: const Color(0xFF78350F),
          cardBgDark: const Color(0xFF271C0A),
          cardBgLight: const Color(0xFFFFFBEB),
          cardBorderDark: const Color(0xFF5C3D0A),
          cardBorderLight: const Color(0xFFFCD34D),
          badgeBg: const Color(0x26FFB347),
          badgeBorder: const Color(0x73FFB347),
          badgeFg: const Color(0xFFFFB347),
          badgeIcon: Icons.warning_amber_rounded,
        );
      case _StepType.monitor:
        return _StepCfg(
          label: p.lang == 'es' ? 'MONITORIZAR' : 'MONITORAR',
          labelColor: const Color(0xFF0EA5E9),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textDark: const Color(0xFFBAE6FD),
          textLight: const Color(0xFF0C4A6E),
          cardBgDark: const Color(0xFF0C1E2A),
          cardBgLight: const Color(0xFFF0F9FF),
          cardBorderDark: const Color(0xFF0E3A52),
          cardBorderLight: const Color(0xFF7DD3FC),
          badgeBg: const Color(0x2690CDD9),
          badgeBorder: const Color(0x7390CDD9),
          badgeFg: const Color(0xFF90CDD9),
          badgeIcon: Icons.monitor_heart_outlined,
        );
      case _StepType.prepare:
        return _StepCfg(
          label: p.lang == 'es' ? 'PREPARAR' : 'PREPARAR',
          labelColor: const Color(0xFF818CF8),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textDark: const Color(0xFFC7D2FE),
          textLight: const Color(0xFF312E81),
          cardBgDark: const Color(0xFF131628),
          cardBgLight: const Color(0xFFF5F3FF),
          cardBorderDark: const Color(0xFF1E2A5E),
          cardBorderLight: const Color(0xFFA5B4FC),
          badgeBg: const Color(0x1FB0C4FF),
          badgeBorder: const Color(0x59B0C4FF),
          badgeFg: const Color(0xFFB0C4FF),
          badgeIcon: Icons.playlist_add_check_rounded,
        );
      case _StepType.secondary:
        return const _StepCfg(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          textDark: Color(0xFFE2E8F0),
          textLight: Color(0xFF334155),
          cardBgDark: Color(0xFF1C1C1C),
          cardBgLight: Color(0xFFF8FAFC),
          cardBorderDark: Color(0xFF2D2D2D),
          cardBorderLight: Color(0xFFE2E8F0),
          badgeBg: Color(0x14FFFFFF),
          badgeBorder: Color(0x33FFFFFF),
          badgeFg: Color(0x8CFFFFFF),
        );
    }
  }
}

enum _StepType { primary, urgent, avoid, monitor, prepare, secondary }

class _StepCfg {
  final String? label;
  final Color labelColor;
  final double fontSize;
  final FontWeight fontWeight;
  // Texto adaptativo
  final Color textDark;
  final Color textLight;
  // Card bg/border adaptativo
  final Color cardBgDark;
  final Color cardBgLight;
  final Color cardBorderDark;
  final Color cardBorderLight;
  // Badge
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeFg;
  final IconData? badgeIcon;

  const _StepCfg({
    this.label,
    this.labelColor = Colors.white,
    required this.fontSize,
    required this.fontWeight,
    required this.textDark,
    required this.textLight,
    required this.cardBgDark,
    required this.cardBgLight,
    required this.cardBorderDark,
    required this.cardBorderLight,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeFg,
    this.badgeIcon,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: EVITAR
// ─────────────────────────────────────────────────────────────────────────────
class _AvoidCard extends StatelessWidget {
  final String text;
  final AppProvider p;
  const _AvoidCard({required this.text, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFF5F5),
        border: Border.all(color: const Color(0xFFFFCCCC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.block_rounded, size: 13, color: Color(0xFFCC2222)),
          const SizedBox(width: 6),
          Text(p.t('avoid').toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
              letterSpacing: 1.8, color: Color(0xFFCC2222))),
        ]),
        const SizedBox(height: 8),
        Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: Color(0xFF8B0000), height: 1.5)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: FÁRMACOS RELACIONADOS
// ─────────────────────────────────────────────────────────────────────────────
class _DrugsChipsCard extends StatelessWidget {
  final List<String> drugs;
  final AppProvider p;
  const _DrugsChipsCard({required this.drugs, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF5F2EB),
        border: Border.all(color: const Color(0xFFDDD8CC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.medication_rounded, size: 13, color: kGold),
          const SizedBox(width: 6),
          Text(p.lang == 'es' ? 'FÁRMACOS CLAVE' : 'FÁRMACOS CHAVE',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
              letterSpacing: 1.8, color: kGold)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: drugs.map((d) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDDD8CC)),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Text(d,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: kDark)),
          )).toList(),
        ),
      ]),
    );
  }
}
