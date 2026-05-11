import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Grupos expandidos por padrão — todos fechados
  final Set<String> _expanded = {};

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
              icon: '⭐',
              titlePt: 'Favoritos',
              titleEs: 'Favoritos',
              color: const Color(0xFFFFFBF0),
              borderColor: const Color(0xFFE8D8A0),
              iconColor: const Color(0xFFC5A365),
              protocols: allDB.where((d) => p.favProtocols.contains(d.id)).toList(),
              isExpanded: _expanded.contains('__fav__'),
              p: p,
              isEs: isEs,
              onToggle: () => setState(() {
                _expanded.contains('__fav__')
                    ? _expanded.remove('__fav__')
                    : _expanded.add('__fav__');
              }),
              onSelect: (proto) => showProtocolDetail(context, proto),
            ),
            const SizedBox(height: 8),
          ],

          // ── Reanimação & Choque ──────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'reanimacao',
            icon: '🔴',
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
            isExpanded: _expanded.contains('reanimacao'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('reanimacao')
                  ? _expanded.remove('reanimacao')
                  : _expanded.add('reanimacao');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Cardiovascular ───────────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'cardio',
            icon: '🫀',
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
            isExpanded: _expanded.contains('cardio'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('cardio')
                  ? _expanded.remove('cardio')
                  : _expanded.add('cardio');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Respiratório ─────────────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'resp',
            icon: '🫁',
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
            isExpanded: _expanded.contains('resp'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('resp')
                  ? _expanded.remove('resp')
                  : _expanded.add('resp');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Neurológico & Psiquiátrico ───────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'neuro',
            icon: '🧠',
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
            isExpanded: _expanded.contains('neuro'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('neuro')
                  ? _expanded.remove('neuro')
                  : _expanded.add('neuro');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Infeccioso & Sepse ───────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'infec',
            icon: '🦠',
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
            isExpanded: _expanded.contains('infec'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('infec')
                  ? _expanded.remove('infec')
                  : _expanded.add('infec');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Metabólico & Endócrino ───────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'metab',
            icon: '⚗️',
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
            isExpanded: _expanded.contains('metab'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('metab')
                  ? _expanded.remove('metab')
                  : _expanded.add('metab');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Gastro, Trauma & Cirúrgico ───────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'gastro',
            icon: '🏥',
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
            isExpanded: _expanded.contains('gastro'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('gastro')
                  ? _expanded.remove('gastro')
                  : _expanded.add('gastro');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Nefrologia, Hemato & Obstetrícia ─────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'outros',
            icon: '🧬',
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
            isExpanded: _expanded.contains('outros'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('outros')
                  ? _expanded.remove('outros')
                  : _expanded.add('outros');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Intoxicações ─────────────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'intox',
            icon: '☠️',
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
            isExpanded: _expanded.contains('intox'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('intox')
                  ? _expanded.remove('intox')
                  : _expanded.add('intox');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Pediatria ────────────────────────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'ped',
            icon: '👶',
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
            isExpanded: _expanded.contains('ped'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('ped')
                  ? _expanded.remove('ped')
                  : _expanded.add('ped');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Casos Clínicos — Neurologia ──────────────────────────────────
          _ProtocolGroupAccordion(
            groupKey: 'casos_neuro',
            icon: '🧠',
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
            isExpanded: _expanded.contains('casos_neuro'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('casos_neuro')
                  ? _expanded.remove('casos_neuro')
                  : _expanded.add('casos_neuro');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Casos Clínicos — Cardiologia & Pneumologia ───────────────────
          _ProtocolGroupAccordion(
            groupKey: 'casos_cardio',
            icon: '🫀',
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
            isExpanded: _expanded.contains('casos_cardio'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('casos_cardio')
                  ? _expanded.remove('casos_cardio')
                  : _expanded.add('casos_cardio');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),

          // ── Casos Clínicos — Infectologia, Emergência & Metabólico ───────
          _ProtocolGroupAccordion(
            groupKey: 'casos_infec',
            icon: '🦠',
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
            isExpanded: _expanded.contains('casos_infec'),
            p: p, isEs: isEs,
            onToggle: () => setState(() {
              _expanded.contains('casos_infec')
                  ? _expanded.remove('casos_infec')
                  : _expanded.add('casos_infec');
            }),
            onSelect: (proto) => showProtocolDetail(context, proto),
          ),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACORDEÃO DE GRUPO DE PROTOCOLOS
// ─────────────────────────────────────────────────────────────────────────────
class _ProtocolGroupAccordion extends StatelessWidget {
  final String groupKey;
  final String icon;
  final String titlePt;
  final String titleEs;
  final Color color;
  final Color borderColor;
  final Color iconColor;
  final List<ProtocolModel> protocols;
  final bool isExpanded;
  final bool isEs;
  final AppProvider p;
  final VoidCallback onToggle;
  final ValueChanged<ProtocolModel> onSelect;

  const _ProtocolGroupAccordion({
    required this.groupKey,
    required this.icon,
    required this.titlePt,
    required this.titleEs,
    required this.color,
    required this.borderColor,
    required this.iconColor,
    required this.protocols,
    required this.isExpanded,
    required this.isEs,
    required this.p,
    required this.onToggle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (protocols.isEmpty) return const SizedBox.shrink();
    final title = isEs ? titleEs : titlePt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [

          // ── Cabeçalho do grupo ───────────────────────────────────────────
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: borderColor),
                borderRadius: isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(14))
                    : BorderRadius.circular(14),
              ),
              child: Row(children: [
                // Ícone
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 19))),
                ),
                const SizedBox(width: 12),
                // Título + contagem
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900,
                      color: iconColor, letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(
                    '${protocols.length} ${protocols.length == 1
                        ? (isEs ? 'protocolo' : 'protocolo')
                        : (isEs ? 'protocolos' : 'protocolos')}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: iconColor.withValues(alpha: 0.55))),
                ])),
                // Chevron animado
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 22, color: iconColor.withValues(alpha: 0.55)),
                ),
              ]),
            ),
          ),

          // ── Lista expandida ──────────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  left: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                  bottom: BorderSide(color: borderColor),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                children: protocols.asMap().entries.map((entry) {
                  final isLast = entry.key == protocols.length - 1;
                  return _ProtocolListTile(
                    proto: entry.value,
                    p: p,
                    isLast: isLast,
                    onTap: () => onSelect(entry.value),
                  );
                }).toList(),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ]),
      ),
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
              : const Border(bottom: BorderSide(color: Color(0xFFEEEAE0), width: 0.8)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Severidade + favorito
            Row(children: [
              if (isFav)
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Text('⭐', style: TextStyle(fontSize: 10)),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                color: kDark),
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
                child: Text(isFav ? '⭐' : '☆',
                  style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: kDark,
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
class _ProtocolDetailSheet extends StatefulWidget {
  final ProtocolModel protocol;
  const _ProtocolDetailSheet({required this.protocol});

  @override
  State<_ProtocolDetailSheet> createState() => _ProtocolDetailSheetState();
}

class _ProtocolDetailSheetState extends State<_ProtocolDetailSheet> {
  // ── Estado do formulário de paciente ──────────────────────────────────────
  String _sex = '';                          // '' = não informado
  final _ageCtrl    = TextEditingController();
  final _weightCtrl = TextEditingController();

  // ── Estado da IA ──────────────────────────────────────────────────────────
  bool    _aiLoading  = false;
  String? _aiAnswer;
  String? _aiError;

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // ── Constrói o prompt rico com contexto do protocolo + dados do paciente ──
  String _buildPrompt(AppProvider p) {
    final lang     = p.lang;
    final isEs     = lang == 'es';
    final title    = p.tDB(widget.protocol.title);
    final recognize = p.tDB(widget.protocol.recognize);
    final actions  = widget.protocol.getActions(lang).join('\n');
    final avoid    = p.tDB(widget.protocol.avoid);
    final drugs    = widget.protocol.drugs.join(', ');

    final age    = _ageCtrl.text.trim();
    final weight = _weightCtrl.text.trim();
    final sex    = _sex;

    // Linha de paciente
    String patientLine = '';
    final parts = <String>[];
    if (sex.isNotEmpty) parts.add(isEs ? 'Sexo: $sex' : 'Sexo: $sex');
    if (age.isNotEmpty) parts.add(isEs ? 'Edad: $age años' : 'Idade: $age anos');
    if (weight.isNotEmpty) parts.add(isEs ? 'Peso: $weight kg' : 'Peso: $weight kg');
    if (parts.isNotEmpty) patientLine = parts.join(' | ');

    if (isEs) {
      return '''PROTOCOLO CLÍNICO: $title

${patientLine.isNotEmpty ? 'DATOS DEL PACIENTE: $patientLine\n\n' : ''}RECONOCER / PRESENTACIÓN:
$recognize

CONDUCTA INMEDIATA:
$actions

${avoid.isNotEmpty ? 'EVITAR:\n$avoid\n\n' : ''}${drugs.isNotEmpty ? 'FÁRMACOS DEL PROTOCOLO: $drugs\n\n' : ''}Con base en este protocolo${patientLine.isNotEmpty ? ' y los datos específicos del paciente' : ''}, analiza el tratamiento recomendado, las dosis ajustadas${age.isNotEmpty || weight.isNotEmpty ? ' por edad y peso' : ''}, los fármacos más apropiados${age.isNotEmpty ? ' para esta franja etaria' : ''}, posibles interacciones y consideraciones clínicas especiales. Sé preciso y práctico.''';
    } else {
      return '''PROTOCOLO CLÍNICO: $title

${patientLine.isNotEmpty ? 'DADOS DO PACIENTE: $patientLine\n\n' : ''}RECONHECER / APRESENTAÇÃO:
$recognize

CONDUTA IMEDIATA:
$actions

${avoid.isNotEmpty ? 'EVITAR:\n$avoid\n\n' : ''}${drugs.isNotEmpty ? 'FÁRMACOS DO PROTOCOLO: $drugs\n\n' : ''}Com base neste protocolo${patientLine.isNotEmpty ? ' e nos dados específicos do paciente' : ''}, analise o tratamento recomendado, as doses ajustadas${age.isNotEmpty || weight.isNotEmpty ? ' por idade e peso' : ''}, os fármacos mais apropriados${age.isNotEmpty ? ' para esta faixa etária' : ''}, possíveis interações e considerações clínicas especiais. Seja preciso e prático.''';
    }
  }

  Future<void> _consultarIA(AppProvider p) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _aiLoading = true;
      _aiAnswer  = null;
      _aiError   = null;
    });
    try {
      final prompt = _buildPrompt(p);
      final answer = await p.buildAIAnswer(prompt);
      if (mounted) setState(() { _aiAnswer = answer; _aiLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _aiError = e.toString(); _aiLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p        = context.watch<AppProvider>();
    final isEs     = p.lang == 'es';
    final actions  = widget.protocol.getActions(p.lang);
    final isFav    = p.favProtocols.contains(widget.protocol.id);
    final avoidTxt = p.tDB(widget.protocol.avoid);
    final drugs    = widget.protocol.drugs;
    final maxH     = MediaQuery.of(context).size.height * 0.92;

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
                    Text(p.tDB(widget.protocol.severity),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                        color: Color(0xBFFFE8A6), letterSpacing: 1.4)),
                    const SizedBox(height: 4),
                    Text(p.tDB(widget.protocol.title),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.5, height: 1.2)),
                  ])),
                  // Favorito
                  GestureDetector(
                    onTap: () => p.toggleFavProtocol(widget.protocol.id),
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
              _RecognizeCard(text: p.tDB(widget.protocol.recognize), p: p),
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

              // ── Card: Consultar IA ───────────────────────────────────────
              _PatientAiCard(
                isEs: isEs,
                sex: _sex,
                ageCtrl: _ageCtrl,
                weightCtrl: _weightCtrl,
                aiLoading: _aiLoading,
                aiAnswer: _aiAnswer,
                aiError: _aiError,
                onSexChanged: (v) => setState(() => _sex = v ?? ''),
                onConsultar: () => _consultarIA(p),
                onClearAnswer: () => setState(() {
                  _aiAnswer = null;
                  _aiError  = null;
                }),
              ),
              const SizedBox(height: 10),

              // ── Botão fechar ─────────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDDD8CC)),
                    color: Colors.white,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kDark),
                    const SizedBox(width: 6),
                    Text(
                      isEs ? 'Cerrar' : 'Fechar',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kDark),
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
// CARD: CONSULTAR IA — formulário de paciente + botão + painel de resposta
// ─────────────────────────────────────────────────────────────────────────────
class _PatientAiCard extends StatelessWidget {
  final bool isEs;
  final String sex;
  final TextEditingController ageCtrl;
  final TextEditingController weightCtrl;
  final bool aiLoading;
  final String? aiAnswer;
  final String? aiError;
  final ValueChanged<String?> onSexChanged;
  final VoidCallback onConsultar;
  final VoidCallback onClearAnswer;

  const _PatientAiCard({
    required this.isEs,
    required this.sex,
    required this.ageCtrl,
    required this.weightCtrl,
    required this.aiLoading,
    required this.aiAnswer,
    required this.aiError,
    required this.onSexChanged,
    required this.onConsultar,
    required this.onClearAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final hasAnswer = aiAnswer != null || aiError != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2118), Color(0xFF0D2E1E), Color(0xFF071A10)],
        ),
        border: Border.all(color: kGold.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: kGreen.withValues(alpha: 0.18),
            blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header do card ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: kGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGold.withValues(alpha: 0.35)),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 17)),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isEs ? 'Consultar IA' : 'Consultar IA',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                  color: kGoldLight, letterSpacing: -0.3),
              ),
              Text(
                isEs
                    ? 'Análisis personalizado por paciente'
                    : 'Análise personalizada por paciente',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.50)),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 14),
        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        const SizedBox(height: 14),

        // ── Formulário do paciente ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Label
            Text(
              isEs ? 'DATOS DEL PACIENTE (OPCIONAL)' : 'DADOS DO PACIENTE (OPCIONAL)',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.45), letterSpacing: 1.5),
            ),
            const SizedBox(height: 10),

            // Sexo + Idade + Peso em linha
            Row(children: [

              // Sexo — dropdown compacto
              Expanded(
                flex: 5,
                child: _PatientDropdown(
                  isEs: isEs,
                  value: sex.isEmpty ? null : sex,
                  hint: isEs ? 'Sexo' : 'Sexo',
                  items: isEs
                      ? const ['Masculino', 'Femenino', 'Otro']
                      : const ['Masculino', 'Feminino', 'Outro'],
                  onChanged: onSexChanged,
                ),
              ),
              const SizedBox(width: 8),

              // Idade
              Expanded(
                flex: 4,
                child: _PatientNumberField(
                  controller: ageCtrl,
                  hint: isEs ? 'Edad' : 'Idade',
                  suffix: isEs ? 'años' : 'anos',
                  maxLength: 3,
                ),
              ),
              const SizedBox(width: 8),

              // Peso
              Expanded(
                flex: 4,
                child: _PatientNumberField(
                  controller: weightCtrl,
                  hint: isEs ? 'Peso' : 'Peso',
                  suffix: 'kg',
                  maxLength: 3,
                  decimal: true,
                ),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Botão principal ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GestureDetector(
            onTap: aiLoading ? null : onConsultar,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: aiLoading
                    ? const LinearGradient(
                        colors: [Color(0xFF2A4A3A), Color(0xFF1E3A2E)])
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kGreen, Color(0xFF0A7A50), Color(0xFF075F40)]),
                boxShadow: aiLoading ? [] : [
                  BoxShadow(
                    color: kGreen.withValues(alpha: 0.40),
                    blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (aiLoading) ...[
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(kGoldLight),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEs ? 'Analizando...' : 'Analisando...',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: kGoldLight),
                  ),
                ] else ...[
                  const Icon(Icons.psychology_rounded, size: 18, color: kGoldLight),
                  const SizedBox(width: 8),
                  Text(
                    isEs ? 'Consultar IA sobre este Protocolo' : 'Consultar IA sobre este Protocolo',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: kGoldLight),
                  ),
                ],
              ]),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Painel de resposta ───────────────────────────────────────────
        if (hasAnswer) ...[
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          _AiAnswerPanel(
            isEs: isEs,
            answer: aiAnswer,
            error: aiError,
            onClear: onClearAnswer,
          ),
        ],

        if (!hasAnswer) const SizedBox(height: 2),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DROPDOWN COMPACTO — sexo do paciente
// ─────────────────────────────────────────────────────────────────────────────
class _PatientDropdown extends StatelessWidget {
  final bool isEs;
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _PatientDropdown({
    required this.isEs,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.40),
              fontWeight: FontWeight.w600)),
          dropdownColor: const Color(0xFF0F2A1C),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: Colors.white),
          icon: Icon(Icons.arrow_drop_down_rounded,
            size: 18, color: Colors.white.withValues(alpha: 0.50)),
          isExpanded: true,
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(isEs ? 'Limpiar' : 'Limpar',
                style: TextStyle(fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45))),
            ),
            ...items.map((s) => DropdownMenuItem<String>(
              value: s,
              child: Text(s, style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: Colors.white)),
            )),
          ],
          onChanged: (v) => onChanged(v == '' ? null : v),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMPO NUMÉRICO COMPACTO — idade / peso
// ─────────────────────────────────────────────────────────────────────────────
class _PatientNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final int maxLength;
  final bool decimal;

  const _PatientNumberField({
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.maxLength,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxLength),
          if (decimal)
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
          color: Colors.white),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.40),
            fontWeight: FontWeight.w600),
          suffixText: suffix,
          suffixStyle: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.50),
            fontWeight: FontWeight.w700),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          isDense: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINEL DE RESPOSTA DA IA
// ─────────────────────────────────────────────────────────────────────────────
class _AiAnswerPanel extends StatelessWidget {
  final bool isEs;
  final String? answer;
  final String? error;
  final VoidCallback onClear;

  const _AiAnswerPanel({
    required this.isEs,
    required this.answer,
    required this.error,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isError = error != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Cabeçalho da resposta ────────────────────────────────────────
        Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
            size: 14,
            color: isError ? const Color(0xFFFF8080) : kGold,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isError
                  ? (isEs ? 'Error al consultar IA' : 'Erro ao consultar IA')
                  : (isEs ? 'Análisis de la IA' : 'Análise da IA'),
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900,
                color: isError ? const Color(0xFFFF8080) : kGold,
                letterSpacing: 0.5),
            ),
          ),
          // Botão copiar (só quando há resposta)
          if (!isError && answer != null)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: answer!));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEs ? 'Copiado al portapapeles' : 'Copiado para área de transferência',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  backgroundColor: kGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kGold.withValues(alpha: 0.30)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.copy_rounded, size: 12, color: kGold),
                  const SizedBox(width: 4),
                  Text(isEs ? 'Copiar' : 'Copiar',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: kGold)),
                ]),
              ),
            ),
          const SizedBox(width: 8),
          // Botão limpar
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close_rounded, size: 16,
              color: Colors.white.withValues(alpha: 0.40)),
          ),
        ]),

        const SizedBox(height: 10),

        // ── Texto da resposta ────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isError
                  ? const Color(0xFFFF8080).withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.10)),
          ),
          child: SelectableText(
            isError ? error! : answer!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isError
                  ? const Color(0xFFFFAAAA)
                  : Colors.white.withValues(alpha: 0.90),
              height: 1.55,
            ),
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kDark, Color(0xFF0D2218), Color(0xFF0A3020)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8A6).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(p.t('actions').toUpperCase(),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                  color: Color(0xFFFFE8A6), letterSpacing: 2.0)),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // Passos com hierarquia visual
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(actions.length, (i) {
              return _ActionStepRow(
                index: i,
                text: actions[i],
                isLast: i == actions.length - 1,
                p: p,
              );
            }),
          ),
        ),
      ]),
    );
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
    final type = _classify(text);
    final cfg  = _config(type);

    // Divide o texto em parte principal e sub-detalhe (entre parênteses)
    final parenMatch = RegExp(r'^(.*?)\s*\(([^)]+)\)\s*(.*)$').firstMatch(text);
    final hasParen   = parenMatch != null;
    final mainText   = hasParen
        ? '${parenMatch.group(1)!.trim()}${parenMatch.group(3)!.trim()}'.trim()
        : text;
    final subText    = hasParen ? parenMatch.group(2)! : null;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Coluna esquerda: badge + linha conectora ─────────────────────────
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: cfg.badgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: cfg.badgeBorder, width: 1.5),
              ),
              child: Center(
                child: cfg.badgeIcon != null
                    ? Icon(cfg.badgeIcon, size: 12, color: cfg.badgeFg)
                    : Text('${index + 1}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                          color: cfg.badgeFg)),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            if (isLast) const SizedBox(height: 14),
          ]),
        ),

        const SizedBox(width: 10),

        // ── Coluna direita: label + texto + sub ──────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Label semântico (ex: URGENTE, EVITAR, MONITORAR)
              if (cfg.label != null) ...[
                Text(cfg.label!,
                  style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w900,
                    color: cfg.labelColor, letterSpacing: 1.6)),
                const SizedBox(height: 2),
              ],

              // Texto principal
              Text(mainText,
                style: TextStyle(
                  fontSize: cfg.fontSize,
                  fontWeight: cfg.fontWeight,
                  color: cfg.textColor,
                  height: 1.4,
                  letterSpacing: -0.1)),

              // Sub-detalhe entre parênteses — menor, mais suave
              if (subText != null) ...[
                const SizedBox(height: 3),
                Text('($subText)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.35,
                    fontStyle: FontStyle.italic)),
              ],

              const SizedBox(height: 10),
            ]),
          ),
        ),
      ]),
    );
  }

  _StepCfg _config(_StepType t) {
    switch (t) {
      case _StepType.primary:
        return _StepCfg(
          label: null,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          textColor: Colors.white,
          badgeBg: const Color(0xFFFFE8A6).withValues(alpha: 0.25),
          badgeBorder: const Color(0xFFFFE8A6).withValues(alpha: 0.7),
          badgeFg: const Color(0xFFFFE8A6),
        );
      case _StepType.urgent:
        return _StepCfg(
          label: p.lang == 'es' ? 'URGENTE' : 'URGENTE',
          labelColor: const Color(0xFFFF8080),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          textColor: const Color(0xFFFFCCCC),
          badgeBg: const Color(0xFFFF6B6B).withValues(alpha: 0.20),
          badgeBorder: const Color(0xFFFF6B6B).withValues(alpha: 0.55),
          badgeFg: const Color(0xFFFF9090),
          badgeIcon: Icons.priority_high_rounded,
        );
      case _StepType.avoid:
        return _StepCfg(
          label: p.lang == 'es' ? 'PRECAUCIÓN' : 'ATENÇÃO',
          labelColor: const Color(0xFFFFB347),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textColor: const Color(0xFFFFD59A),
          badgeBg: const Color(0xFFFFB347).withValues(alpha: 0.15),
          badgeBorder: const Color(0xFFFFB347).withValues(alpha: 0.45),
          badgeFg: const Color(0xFFFFB347),
          badgeIcon: Icons.warning_amber_rounded,
        );
      case _StepType.monitor:
        return _StepCfg(
          label: p.lang == 'es' ? 'MONITORIZAR' : 'MONITORAR',
          labelColor: const Color(0xFF90CDD9),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textColor: Colors.white.withValues(alpha: 0.88),
          badgeBg: const Color(0xFF90CDD9).withValues(alpha: 0.15),
          badgeBorder: const Color(0xFF90CDD9).withValues(alpha: 0.45),
          badgeFg: const Color(0xFF90CDD9),
          badgeIcon: Icons.monitor_heart_outlined,
        );
      case _StepType.prepare:
        return _StepCfg(
          label: p.lang == 'es' ? 'PREPARAR' : 'PREPARAR',
          labelColor: const Color(0xFFB0C4FF),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textColor: Colors.white.withValues(alpha: 0.85),
          badgeBg: const Color(0xFFB0C4FF).withValues(alpha: 0.12),
          badgeBorder: const Color(0xFFB0C4FF).withValues(alpha: 0.35),
          badgeFg: const Color(0xFFB0C4FF),
          badgeIcon: Icons.playlist_add_check_rounded,
        );
      case _StepType.secondary:
        return _StepCfg(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          textColor: Colors.white.withValues(alpha: 0.82),
          badgeBg: Colors.white.withValues(alpha: 0.08),
          badgeBorder: Colors.white.withValues(alpha: 0.20),
          badgeFg: Colors.white.withValues(alpha: 0.55),
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
  final Color textColor;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeFg;
  final IconData? badgeIcon;

  const _StepCfg({
    this.label,
    this.labelColor = Colors.white,
    required this.fontSize,
    required this.fontWeight,
    required this.textColor,
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
