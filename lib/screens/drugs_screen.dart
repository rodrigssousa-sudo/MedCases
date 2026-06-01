import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/drug_model.dart';
import '../services/drug_interaction_service.dart';
import '../widgets/common_widgets.dart';
import '../services/activity_service.dart';

// Recentes delegados ao AppProvider (chave prefixada por uid)
Future<void> _registerDrugRecent(BuildContext ctx, String id, String name, DateTime openedAt) async {
  final elapsed = DateTime.now().difference(openedAt);
  if (elapsed.inSeconds < 5) return;
  try {
    final p = ctx.read<AppProvider>();
    await p.registerRecent('drug', id, name);
  } catch (_) {}
}

/// Abre o detalhe de um fármaco como bottom sheet standalone.
void showDrugDetailSheet(BuildContext context, DrugModel drug) {
  final p = context.read<AppProvider>();
  final openedAt = DateTime.now();
  // Registra no histórico de atividades recentes
  final lang = p.lang;
  ActivityService.log(
    type:     ActivityType.farmaco,
    title:    drug.name,
    subtitle: drug.className[lang] ?? drug.group,
  );
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DrugDetailSheetWrapper(drug: drug, p: p),
  ).then((_) => _registerDrugRecent(context, drug.id, drug.name, openedAt));
}

class _DrugDetailSheetWrapper extends StatelessWidget {
  final DrugModel drug;
  final AppProvider p;
  const _DrugDetailSheetWrapper({required this.drug, required this.p});

  @override
  Widget build(BuildContext context) {
    final dark = p.darkMode;
    final sheetBg = dark ? const Color(0xFF1A1A1A) : Colors.white;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _DrugDetailView(
          drug: drug,
          onBack: () => Navigator.of(context).pop(),
          p: p,
          scrollController: sc,
        ),
      ),
    );
  }
}

class DrugsScreen extends StatefulWidget {
  final bool hideHeader;
  const DrugsScreen({super.key, this.hideHeader = false});
  @override
  State<DrugsScreen> createState() => _DrugsScreenState();
}

class _DrugsScreenState extends State<DrugsScreen> {
  final _searchCtrl = TextEditingController();
  DrugModel? _selected;
  // Grupos expandidos — por padrão todos fechados
  final Set<String> _expanded = {};

  // ── Cache de lista pré-processada (calculada uma vez, não a cada build) ──
  List<DrugModel>? _cachedUnique;
  Set<String>? _cachedFavDrugs;
  String? _cachedLang;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Retorna lista deduplicada + ordenada, usando cache quando os dados não mudaram
  List<DrugModel> _getUnique(AppProvider p, String q) {
    final isSearching = q.isNotEmpty;

    // Sempre recomputa ao buscar (lista pequena, rápido)
    if (isSearching) {
      final allDrugs = p.drugsDB;
      final filtered = allDrugs.where((d) {
        return d.name.toLowerCase().contains(q) ||
            (d.className[p.lang] ?? '').toLowerCase().contains(q) ||
            (d.category[p.lang] ?? '').toLowerCase().contains(q) ||
            d.group.toLowerCase().contains(q) ||
            (d.warning?[p.lang] ?? '').toLowerCase().contains(q);
      }).toList();
      final seen = <String>{};
      final unique = filtered.where((d) => seen.add(d.id)).toList();
      unique.sort((a, b) {
        final aFav = p.favDrugs.contains(a.id) ? 0 : 1;
        final bFav = p.favDrugs.contains(b.id) ? 0 : 1;
        if (aFav != bFav) return aFav.compareTo(bFav);
        return a.name.compareTo(b.name);
      });
      return unique;
    }

    // Sem busca: usa cache — recalcula só se favDrugs ou lang mudou
    if (_cachedUnique != null &&
        _cachedFavDrugs == p.favDrugs &&
        _cachedLang == p.lang) {
      return _cachedUnique!;
    }

    final allDrugs = p.drugsDB; // já cacheado no provider
    final seen = <String>{};
    final unique = allDrugs.where((d) => seen.add(d.id)).toList();
    unique.sort((a, b) {
      final aFav = p.favDrugs.contains(a.id) ? 0 : 1;
      final bFav = p.favDrugs.contains(b.id) ? 0 : 1;
      if (aFav != bFav) return aFav.compareTo(bFav);
      return a.name.compareTo(b.name);
    });

    _cachedUnique    = unique;
    _cachedFavDrugs  = Set.from(p.favDrugs);
    _cachedLang      = p.lang;
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    if (_selected != null) {
      return _DrugDetailView(
        drug: _selected!,
        onBack: () => setState(() => _selected = null),
        p: p,
      );
    }

    final q = _searchCtrl.text.toLowerCase().trim();
    final isSearching = q.isNotEmpty;
    final unique = _getUnique(p, q);
    final dark = p.darkMode;

    return RepaintBoundary(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
        child: Column(children: [

          // ── Header premium (oculto quando embutido em shell) ─────────────────
          if (!widget.hideHeader) ...[
            PremiumCard(
              child: SectionTitle(
                eyebrow: 'Knowledge Base',
                title: p.t('drugs'),
                subtitle: p.t('drugs_subtitle'),
                light: true,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Busca com autocomplete ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _DrugSearchAutocomplete(
                controller: _searchCtrl,
                hintText: p.t('drugs_search_hint'),
                allDrugs: p.drugsDB,
                onChanged: (_) => setState(() {}),
                onDrugSelected: (drug) => setState(() => _selected = drug),
              ),
              const SizedBox(height: 8),
              Text(
                '${unique.length} ${p.t('drugs_found')}',
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF888888),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Modo busca: lista flat ────────────────────────────────────────────
          if (isSearching)
            ...unique.map((drug) => _DrugListTile(
              drug: drug,
              p: p,
              dark: dark,
              onTap: () => setState(() => _selected = drug),
            ))

          // ── Modo normal: acordeão por grupo ──────────────────────────────────
          else ...[
            // Favoritos no topo (se existirem)
            if (p.favDrugs.isNotEmpty) ...[
              _GroupAccordion(
                groupName: p.lang == 'es' ? 'Favoritos' : 'Favoritos',
                icon: '',
                iconData: Icons.star_rounded,
                iconColor: kGold,
                drugs: unique.where((d) => p.favDrugs.contains(d.id)).toList(),
                isExpanded: _expanded.contains('__fav__'),
                dark: dark,
                p: p,
                onToggle: () => setState(() {
                  if (_expanded.contains('__fav__')) {
                    _expanded.remove('__fav__');
                  } else {
                    _expanded.add('__fav__');
                  }
                }),
                onSelect: (drug) => setState(() => _selected = drug),
              ),
              const SizedBox(height: 4),
            ],

            // Grupos clínicos em ordem definida em DrugGroup.all
            ...DrugGroup.all.map((groupName) {
              final drugsInGroup = unique
                  .where((d) => d.group == groupName)
                  .toList();
              if (drugsInGroup.isEmpty) return const SizedBox.shrink();
              final isExp = _expanded.contains(groupName);
              return Column(children: [
                _GroupAccordion(
                  groupName: groupName,
                  icon: '',
                  iconData: DrugGroup.iconData(groupName),
                  drugs: drugsInGroup,
                  isExpanded: isExp,
                  dark: dark,
                  p: p,
                  onToggle: () => setState(() {
                    if (isExp) {
                      _expanded.remove(groupName);
                    } else {
                      _expanded.add(groupName);
                    }
                  }),
                  onSelect: (drug) => setState(() => _selected = drug),
                ),
                const SizedBox(height: 4),
              ]);
            }),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACORDEÃO DE GRUPO
// ─────────────────────────────────────────────────────────────────────────────
class _GroupAccordion extends StatelessWidget {
  final String groupName;
  final String icon;
  final IconData? iconData;
  final Color? iconColor;
  final List<DrugModel> drugs;
  final bool isExpanded;
  final bool dark;
  final AppProvider p;
  final VoidCallback onToggle;
  final ValueChanged<DrugModel> onSelect;

  const _GroupAccordion({
    required this.groupName,
    required this.icon,
    this.iconData,
    this.iconColor,
    required this.drugs,
    required this.isExpanded,
    required this.dark,
    required this.p,
    required this.onToggle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final headerBg = c.cardBg2;
    final headerBorder = c.border;
    final titleColor = c.textPrimary;
    final countColor = c.textHint;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [

          // ── Cabeçalho do grupo ──────────────────────────────────────────────
          Material(
            color: headerBg,
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onToggle();
              },
              borderRadius: isExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(14))
                  : BorderRadius.circular(14),
              splashColor: (iconColor ?? c.green).withValues(alpha: 0.12),
              highlightColor: (iconColor ?? c.green).withValues(alpha: 0.06),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: headerBorder),
                  borderRadius: isExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(14))
                      : BorderRadius.circular(14),
                ),
                child: Row(children: [
                  // Ícone do grupo — maior e mais impactante
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (iconColor ?? c.green).withValues(alpha: 0.18),
                          (iconColor ?? c.green).withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (iconColor ?? c.green).withValues(alpha: 0.20),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: iconData != null
                          ? Icon(iconData, size: 20,
                              color: iconColor ?? c.green)
                          : Text(icon, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nome e contagem
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DrugGroup.label(groupName, isEs: p.lang == 'es'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${drugs.length} ${drugs.length == 1 ? 'fármaco' : 'fármacos'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: countColor,
                        ),
                      ),
                    ],
                  )),
                  // Chevron animado
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: countColor,
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Lista de fármacos expandida ──────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              decoration: BoxDecoration(
                color: c.cardBg,
                border: Border(
                  left: BorderSide(color: headerBorder),
                  right: BorderSide(color: headerBorder),
                  bottom: BorderSide(color: headerBorder),
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Column(
                children: drugs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final drug = entry.value;
                  final isLast = idx == drugs.length - 1;
                  return _DrugListTile(
                    drug: drug,
                    p: p,
                    dark: dark,
                    isLast: isLast,
                    onTap: () => onSelect(drug),
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
// TILE DE FÁRMACO (usado em ambos os modos)
// ─────────────────────────────────────────────────────────────────────────────
class _DrugListTile extends StatelessWidget {
  final DrugModel drug;
  final AppProvider p;
  final bool dark;
  final bool isLast;
  final VoidCallback onTap;

  const _DrugListTile({
    required this.drug,
    required this.p,
    required this.dark,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFav = p.favDrugs.contains(drug.id);
    final c = AppColors.of(context);
    final divColor = c.border;
    final nameColor = c.textPrimary;
    final subColor = c.textSecondary;
    final warnColor = c.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        splashColor: c.green.withValues(alpha: 0.10),
        highlightColor: c.green.withValues(alpha: 0.05),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: divColor, width: 0.8)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (isFav)
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(Icons.star_rounded, size: 12, color: kGold),
                ),
              Flexible(
                child: Text(
                  drug.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: nameColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              '${p.tDB(drug.className)} • ${drug.route}',
              style: TextStyle(
                fontSize: 11,
                color: subColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              p.tDB(drug.warning),
              style: TextStyle(
                fontSize: 11,
                color: warnColor,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ])),
          const SizedBox(width: 10),
          Column(children: [
            // Estrela favorito com touch target adequado
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  p.toggleFavDrug(drug.id);
                },
                borderRadius: BorderRadius.circular(20),
                splashColor: kGold.withValues(alpha: 0.18),
                highlightColor: kGold.withValues(alpha: 0.08),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: isFav ? kGold : const Color(0xFFCCCCCC),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.darkBtn,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                p.t('open'),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: kGoldLight,
                ),
              ),
            ),
          ]),
        ]),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE EVIDÊNCIA — dados por fármaco (Apple 1.4.1 / 1.4.2)
// ─────────────────────────────────────────────────────────────────────────────
class _DrugEvidence {
  final String guidelineSource;
  final String evidenceLevel;     // 'Classe I', 'Nível A', etc.
  final String recommendation;    // 'Alta', 'Moderada', 'Baixa'
  final String lastReviewed;
  final List<_EvidenceRef> references;
  final List<_OfficialLink> links;
  final List<String> indications;
  final List<String> contraindications;
  final List<String> interactions;
  final List<String> sideEffects;
  final List<_DosageTable> dosageTables;
  final List<String> badges;      // ['Adulto','Pediatria','Emergência','UTI']
  final String atcCode;
  final String? pkOnset;
  final String? pkDuration;
  final String? pkHalfLife;
  final String? pkDistribution;
  final String? pkElimination;
  final String? pkProteinBinding;
  final String? renalAdjustment;

  const _DrugEvidence({
    required this.guidelineSource,
    required this.evidenceLevel,
    required this.recommendation,
    required this.lastReviewed,
    required this.references,
    required this.links,
    required this.indications,
    required this.contraindications,
    required this.interactions,
    required this.sideEffects,
    required this.dosageTables,
    required this.badges,
    this.atcCode = '',
    this.pkOnset,
    this.pkDuration,
    this.pkHalfLife,
    this.pkDistribution,
    this.pkElimination,
    this.pkProteinBinding,
    this.renalAdjustment,
  });
}

class _EvidenceRef {
  final int num;
  final String title;
  final String source;
  final String year;
  final String type; // 'Diretriz' | 'Base de Dados' | 'Estudo' | 'Protocolo'
  final String? doi;
  const _EvidenceRef({
    required this.num, required this.title, required this.source,
    required this.year, required this.type, this.doi,
  });
}

class _OfficialLink {
  final String label;
  final String url;
  final IconData icon;
  const _OfficialLink({required this.label, required this.url, required this.icon});
}

class _DosageTable {
  final String population; // 'Adulto', 'Pediatria', 'Renal', 'Hepático'
  final List<_DosageRow> rows;
  const _DosageTable({required this.population, required this.rows});
}

class _DosageRow {
  final String label;
  final String dose;
  final String? doseKg;
  final String? maxDose;
  final String? note;
  const _DosageRow({
    required this.label, required this.dose,
    this.doseKg, this.maxDose, this.note,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// BASE DE EVIDÊNCIAS — referências específicas por fármaco
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, _DrugEvidence> _kDrugEvidenceDB = {

  'adenosina': _DrugEvidence(
    guidelineSource: 'AHA ACLS 2020 / ESC SVT 2019',
    evidenceLevel: 'Classe I',
    recommendation: 'Alta',
    lastReviewed: 'Jan 2025',
    badges: ['Adulto', 'Pediatria', 'Emergência'],
    atcCode: 'C01EB12',
    pkOnset: '< 10 segundos',
    pkDuration: '10–20 segundos',
    pkHalfLife: '< 10 s',
    pkElimination: 'Eritrócitos / células endoteliais',
    indications: [
      'Taquicardia supraventricular (TSV) estável regular',
      'Diagnóstico diferencial de taquicardia de complexo regular',
      'TSV por reentrada nodal AV e reentrada AV',
    ],
    contraindications: [
      'Bloqueio AV de 2º/3º grau sem marcapasso',
      'Disfunção do nó sinusal',
      'Broncoespasmo grave / asma ativa',
      'Hipersensibilidade conhecida à adenosina',
    ],
    interactions: [
      'Cafeína / teofilina: antagonistas — diminuem efeito',
      'Dipiridamol: potencia efeito (reduzir dose 50%)',
      'Carbamazepina: potencia bloqueio AV',
      'Digitálicos: risco aumentado de bloqueio AV',
    ],
    sideEffects: [
      'Rubor facial', 'Dispneia transitória', 'Dor torácica',
      'Broncoespasmo', 'Bradicardia / pausa sinusal',
    ],
    dosageTables: [
      _DosageTable(population: 'Adulto', rows: [
        _DosageRow(label: '1ª dose', dose: '6 mg IV', note: 'Bolus rápido + flush 20 mL SF'),
        _DosageRow(label: '2ª dose', dose: '12 mg IV', note: 'Se sem resposta em 1–2 min'),
        _DosageRow(label: 'Dose máx.', dose: '30 mg', note: 'Total acumulado'),
      ]),
      _DosageTable(population: 'Pediatria', rows: [
        _DosageRow(label: '1ª dose', dose: '0,1 mg/kg', maxDose: 'máx. 6 mg', doseKg: 'mg/kg'),
        _DosageRow(label: '2ª dose', dose: '0,2 mg/kg', maxDose: 'máx. 12 mg', doseKg: 'mg/kg'),
      ]),
    ],
    references: [
      _EvidenceRef(num: 1, title: 'PALS Provider Manual', source: 'American Heart Association', year: '2020', type: 'Diretriz'),
      _EvidenceRef(num: 2, title: 'Adenosine: Drug Information', source: 'UpToDate', year: '2024', type: 'Base de Dados'),
      _EvidenceRef(num: 3, title: 'Adenosine Injection', source: 'Micromedex®', year: '2024', type: 'Base de Dados'),
      _EvidenceRef(num: 4, title: 'SVT Guideline 2019', source: 'ESC — European Society of Cardiology', year: '2019', type: 'Diretriz'),
    ],
    links: [
      _OfficialLink(label: 'AHA ACLS Guidelines', url: 'https://www.heart.org/en/cpr', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'ESC SVT Guideline', url: 'https://www.escardio.org/Guidelines/Clinical-Practice-Guidelines/Supraventricular-Tachycardia', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'FDA Label', url: 'https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm', icon: Icons.open_in_new_rounded),
    ],
    renalAdjustment: 'Sem ajuste necessário — eliminação extrarrenal',
  ),

  'amiodarona': _DrugEvidence(
    guidelineSource: 'AHA ACLS 2020 / ESC Arrhythmia 2022',
    evidenceLevel: 'Classe IIb',
    recommendation: 'Moderada–Alta',
    lastReviewed: 'Jan 2025',
    badges: ['Adulto', 'Emergência', 'UTI'],
    atcCode: 'C01BD01',
    pkOnset: '1–3 dias (oral) / imediato (IV)',
    pkDuration: 'Semanas a meses',
    pkHalfLife: '40–55 dias',
    pkElimination: 'Hepática (CYP2D6/3A4)',
    pkProteinBinding: '> 96%',
    indications: [
      'FV/TV sem pulso refratária a choque',
      'TV hemodinamicamente estável',
      'FA com alta resposta ventricular na insuficiência cardíaca',
      'Profilaxia de FA pós-operatória',
    ],
    contraindications: [
      'Bradicardia sinusal grave sem marcapasso',
      'Bloqueio sinoatrial / AV de 2º ou 3º grau',
      'Disfunção tireoidiana grave',
      'Hipersensibilidade ao iodo ou à amiodarona',
      'QT longo congênito',
    ],
    interactions: [
      'Varfarina: aumenta INR significativamente (reduzir dose 30–50%)',
      'Digoxina: aumenta concentração sérica (reduzir dose 50%)',
      'Estatinas (sinvastatina): risco de miopatia (não exceder 20 mg/dia)',
      'QT-prolonging drugs: risco de Torsades de Pointes',
    ],
    sideEffects: [
      'Fotossensibilidade', 'Hipotireoidismo/hipertireoidismo',
      'Pneumonite intersticial', 'Hepatotoxicidade',
      'Neuropatia periférica', 'Depósitos na córnea',
    ],
    dosageTables: [
      _DosageTable(population: 'Adulto — PCR', rows: [
        _DosageRow(label: 'Dose PCR', dose: '300 mg IV', note: 'Bolus em 1–2 min. Repetir 150 mg após 3–5 min'),
        _DosageRow(label: 'Dose máx. PCR', dose: '2,2 g/24h'),
      ]),
      _DosageTable(population: 'Adulto — TV/FA estável', rows: [
        _DosageRow(label: 'Ataque', dose: '150 mg IV', note: 'Em 10 minutos'),
        _DosageRow(label: 'Manutenção', dose: '1 mg/min × 6h', note: 'Depois 0,5 mg/min × 18h'),
        _DosageRow(label: 'Oral (fase crônica)', dose: '200–400 mg/dia'),
      ]),
    ],
    references: [
      _EvidenceRef(num: 1, title: 'ACLS Provider Manual', source: 'American Heart Association', year: '2020', type: 'Diretriz'),
      _EvidenceRef(num: 2, title: 'Ventricular Arrhythmias and SCD Prevention', source: 'ESC', year: '2022', type: 'Diretriz'),
      _EvidenceRef(num: 3, title: 'Amiodarone: Drug Information', source: 'Lexicomp®', year: '2024', type: 'Base de Dados'),
      _EvidenceRef(num: 4, title: 'Amiodarone', source: 'Micromedex®', year: '2024', type: 'Base de Dados'),
    ],
    links: [
      _OfficialLink(label: 'AHA ACLS Guidelines', url: 'https://www.heart.org/en/cpr', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'ESC Arrhythmia Guideline', url: 'https://www.escardio.org', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'FDA Label', url: 'https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm', icon: Icons.open_in_new_rounded),
    ],
    renalAdjustment: 'Sem ajuste necessário',
  ),

  'noradrenalina': _DrugEvidence(
    guidelineSource: 'SSC 2021 / SCCM Guidelines',
    evidenceLevel: 'Forte',
    recommendation: 'Alta',
    lastReviewed: 'Mar 2025',
    badges: ['Adulto', 'UTI', 'Emergência'],
    atcCode: 'C01CA03',
    pkOnset: '1–2 minutos',
    pkDuration: '1–2 minutos após suspensão',
    pkHalfLife: '2,5 minutos',
    pkElimination: 'MAO / COMT (neuronal/extraneuronal)',
    indications: [
      'Choque séptico — vasopressor de 1ª linha (SSC 2021)',
      'Choque vasoplégico pós-operatório',
      'Hipotensão arterial grave refratária',
    ],
    contraindications: [
      'Hipovolemia não corrigida (relativa)',
      'Trombose vascular periférica',
      'Hipersensibilidade',
    ],
    interactions: [
      'IMAO: crise hipertensiva grave (contraindicado)',
      'Antidepressivos tricíclicos: potenciação adrenérgica',
      'Halogenados: sensibilização miocárdica',
    ],
    sideEffects: [
      'Hipertensão', 'Bradicardia reflexa', 'Isquemia periférica',
      'Extravasamento: necrose tecidual',
    ],
    dosageTables: [
      _DosageTable(population: 'Adulto (sepse)', rows: [
        _DosageRow(label: 'Início', dose: '0,01–0,1 mcg/kg/min', note: 'Titular por alvo de PAM ≥ 65 mmHg'),
        _DosageRow(label: 'Usual', dose: '0,1–0,5 mcg/kg/min'),
        _DosageRow(label: 'Refrátária', dose: 'até 3 mcg/kg/min', note: 'Com corticoides se necessário'),
      ]),
    ],
    references: [
      _EvidenceRef(num: 1, title: 'Surviving Sepsis Campaign 2021', source: 'SSC / SCCM', year: '2021', type: 'Diretriz'),
      _EvidenceRef(num: 2, title: 'Norepinephrine: Drug Information', source: 'UpToDate', year: '2024', type: 'Base de Dados'),
      _EvidenceRef(num: 3, title: 'Norepinephrine', source: 'Micromedex®', year: '2024', type: 'Base de Dados'),
      _EvidenceRef(num: 4, title: 'Critical Care Vasopressors', source: 'Lexicomp®', year: '2024', type: 'Base de Dados'),
    ],
    links: [
      _OfficialLink(label: 'Surviving Sepsis Campaign', url: 'https://www.survivingsepsis.org', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'SCCM Guidelines', url: 'https://www.sccm.org', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'FDA Label', url: 'https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm', icon: Icons.open_in_new_rounded),
    ],
    renalAdjustment: 'Sem dados clínicos relevantes — usar com cautela',
  ),

  'adrenalina': _DrugEvidence(
    guidelineSource: 'AHA ACLS 2020 / ERC 2021',
    evidenceLevel: 'Classe I',
    recommendation: 'Alta',
    lastReviewed: 'Jan 2025',
    badges: ['Adulto', 'Pediatria', 'Emergência', 'UTI'],
    atcCode: 'C01CA24',
    pkOnset: 'Imediato (IV)',
    pkDuration: '5–10 minutos',
    pkHalfLife: '2 minutos',
    pkElimination: 'MAO / COMT',
    indications: [
      'Parada cardiorrespiratória (FV/TV/AESP/Assistolia)',
      'Anafilaxia grave (1ª linha)',
      'Bradicardia sintomática refratária à atropina',
      'Choque anafilático',
    ],
    contraindications: [
      'Arritmias por halogenados (relativa)',
      'Hipertireoidismo grave',
      'Isquemia miocárdica em doses altas (relativa)',
    ],
    interactions: [
      'IMAO: potenciação grave (hipertensão)',
      'Betabloqueadores: bloqueio parcial de efeito beta',
      'Digitálicos: risco de arritmias ventriculares',
    ],
    sideEffects: [
      'Taquicardia', 'Arritmias ventriculares', 'Hipertensão',
      'Palidez cutânea', 'Cefaleia', 'Tremores',
    ],
    dosageTables: [
      _DosageTable(population: 'Adulto — PCR', rows: [
        _DosageRow(label: 'Dose PCR', dose: '1 mg IV/IO', note: 'A cada 3–5 min. Bolus + flush 20 mL'),
      ]),
      _DosageTable(population: 'Adulto — Anafilaxia', rows: [
        _DosageRow(label: '1ª linha', dose: '0,3–0,5 mg IM', note: 'Face anterolateral da coxa'),
        _DosageRow(label: 'IV (grave)', dose: '0,1–0,5 mg IV', note: 'Diluído, monitorado'),
      ]),
      _DosageTable(population: 'Pediatria', rows: [
        _DosageRow(label: 'PCR', dose: '0,01 mg/kg IV/IO', maxDose: 'máx. 1 mg', doseKg: 'mg/kg'),
        _DosageRow(label: 'Anafilaxia IM', dose: '0,01 mg/kg IM', maxDose: 'máx. 0,5 mg'),
      ]),
    ],
    references: [
      _EvidenceRef(num: 1, title: 'ACLS Provider Manual', source: 'American Heart Association', year: '2020', type: 'Diretriz'),
      _EvidenceRef(num: 2, title: 'European Resuscitation Council Guidelines', source: 'ERC', year: '2021', type: 'Diretriz'),
      _EvidenceRef(num: 3, title: 'Epinephrine: Drug Information', source: 'UpToDate', year: '2024', type: 'Base de Dados'),
      _EvidenceRef(num: 4, title: 'Epinephrine Injection', source: 'Micromedex®', year: '2024', type: 'Base de Dados'),
    ],
    links: [
      _OfficialLink(label: 'AHA ACLS Guidelines', url: 'https://www.heart.org/en/cpr', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'ERC Guidelines 2021', url: 'https://www.erc.edu/guidelines', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'FDA Label', url: 'https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm', icon: Icons.open_in_new_rounded),
    ],
    renalAdjustment: 'Sem ajuste na emergência',
  ),

  'atropina': _DrugEvidence(
    guidelineSource: 'AHA ACLS 2020',
    evidenceLevel: 'Classe IIa',
    recommendation: 'Moderada',
    lastReviewed: 'Jan 2025',
    badges: ['Adulto', 'Emergência'],
    atcCode: 'A03BA01',
    pkOnset: '1–2 minutos',
    pkDuration: '4 horas',
    pkHalfLife: '2–3 horas',
    pkElimination: 'Renal (60–70% inalterada)',
    indications: [
      'Bradicardia sintomática hemodinamicamente instável',
      'Bloqueio AV de 1º grau e 2º grau tipo Mobitz I sintomático',
      'Intoxicação por organofosforados / anticolinesterásicos',
    ],
    contraindications: [
      'Glaucoma de ângulo fechado',
      'Hipertrofia prostática grave',
      'Taquiarritmias',
      'Febre alta (inibe sudorese)',
    ],
    interactions: [
      'Anticolinérgicos: efeitos aditivos (xerostomia, retenção urinária)',
      'Fenotiazinas: redução da eficácia anticolinérgica',
    ],
    sideEffects: [
      'Xerostomia', 'Taquicardia', 'Visão turva',
      'Retenção urinária', 'Constipação', 'Confusão mental (idosos)',
    ],
    dosageTables: [
      _DosageTable(population: 'Adulto', rows: [
        _DosageRow(label: 'Bradicardia', dose: '0,5 mg IV', note: 'Repetir a cada 3–5 min. Máx. 3 mg'),
        _DosageRow(label: 'Dose máx.', dose: '3 mg IV total'),
        _DosageRow(label: 'Organofosf.', dose: '2–4 mg IV', note: 'Repetir a cada 5–10 min até atropinização'),
      ]),
    ],
    references: [
      _EvidenceRef(num: 1, title: 'ACLS Provider Manual', source: 'American Heart Association', year: '2020', type: 'Diretriz'),
      _EvidenceRef(num: 2, title: 'Atropine: Drug Information', source: 'Lexicomp®', year: '2024', type: 'Base de Dados'),
      _EvidenceRef(num: 3, title: 'Atropine Sulfate Injection', source: 'Micromedex®', year: '2024', type: 'Base de Dados'),
    ],
    links: [
      _OfficialLink(label: 'AHA ACLS Guidelines', url: 'https://www.heart.org/en/cpr', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'FDA Label', url: 'https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm', icon: Icons.open_in_new_rounded),
    ],
    renalAdjustment: 'Reduzir dose se ClCr < 30 mL/min (acumulação)',
  ),

  'morfina': _DrugEvidence(
    guidelineSource: 'WHO Pain Ladder / INCA 2022',
    evidenceLevel: 'Forte',
    recommendation: 'Alta',
    lastReviewed: 'Fev 2025',
    badges: ['Adulto', 'Pediatria', 'UTI'],
    atcCode: 'N02AA01',
    pkOnset: '5–10 min (IV), 20–30 min (IM)',
    pkDuration: '4–6 horas',
    pkHalfLife: '2–3 horas (metabólito ativo M6G: 2–3 dias com IRA)',
    pkElimination: 'Renal (metabólitos)',
    pkProteinBinding: '35%',
    indications: [
      'Dor moderada a grave — 1ª linha WHO Escada Analgésica',
      'Dor aguda pós-operatória',
      'Analgesia em UTI / ventilação mecânica',
      'Dispneia em cuidados paliativos',
    ],
    contraindications: [
      'Depressão respiratória grave sem suporte ventilatório',
      'Íleo paralítico (relativa)',
      'Hipertensão intracraniana grave',
      'Hipersensibilidade a opióides',
    ],
    interactions: [
      'BZD / outros depressores SNC: depressão respiratória aditiva',
      'IMAO: risco de síndrome serotoninérgica',
      'Naloxona: antagonismo — ter disponível',
    ],
    sideEffects: [
      'Constipação', 'Náuseas/vômitos', 'Sedação',
      'Depressão respiratória (dose-dependente)',
      'Prurido (liberação histamina)', 'Retenção urinária',
    ],
    dosageTables: [
      _DosageTable(population: 'Adulto (dor aguda)', rows: [
        _DosageRow(label: 'IV', dose: '2–5 mg IV', note: 'Repetir a cada 5–15 min. Titular por resposta'),
        _DosageRow(label: 'SC/IM', dose: '5–10 mg', note: 'A cada 4 horas'),
        _DosageRow(label: 'Infusão contínua', dose: '1–5 mg/h IV', note: 'UTI: titular conforme escala de dor'),
      ]),
      _DosageTable(population: 'Pediatria', rows: [
        _DosageRow(label: 'IV', dose: '0,05–0,1 mg/kg', maxDose: 'máx. 5 mg/dose', note: 'A cada 4–6h; titular'),
      ]),
    ],
    references: [
      _EvidenceRef(num: 1, title: 'WHO Pain Ladder — Cancer Pain Relief', source: 'World Health Organization', year: '2019', type: 'Diretriz'),
      _EvidenceRef(num: 2, title: 'Morphine: Drug Information', source: 'UpToDate', year: '2024', type: 'Base de Dados'),
      _EvidenceRef(num: 3, title: 'Morphine Sulfate', source: 'Micromedex®', year: '2024', type: 'Base de Dados'),
      _EvidenceRef(num: 4, title: 'Manual de Cuidados Paliativos 2022', source: 'INCA — Instituto Nacional de Câncer', year: '2022', type: 'Protocolo'),
    ],
    links: [
      _OfficialLink(label: 'WHO Pain Ladder', url: 'https://www.who.int/cancer/palliative/painladder/en/', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'INCA Cuidados Paliativos', url: 'https://www.inca.gov.br', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'FDA Label', url: 'https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm', icon: Icons.open_in_new_rounded),
    ],
    renalAdjustment: 'ClCr 10–50: reduzir 25–50%. ClCr < 10: evitar (acúmulo M6G)',
  ),

  'metoprolol': _DrugEvidence(
    guidelineSource: 'AHA/ACC HF 2022 / ESC HF 2021',
    evidenceLevel: 'Classe I',
    recommendation: 'Alta',
    lastReviewed: 'Mar 2025',
    badges: ['Adulto', 'UTI'],
    atcCode: 'C07AB02',
    pkOnset: '20 min (oral), 5 min (IV)',
    pkDuration: '6–12 h (tartarato), 24 h (succinato)',
    pkHalfLife: '3–7 horas',
    pkElimination: 'Hepática (CYP2D6)',
    pkProteinBinding: '10–12%',
    indications: [
      'Insuficiência cardíaca com FEVE reduzida (≤ 40%)',
      'Hipertensão arterial sistêmica',
      'Angina estável',
      'FA com alta resposta ventricular (controle de frequência)',
      'Pós-IAM para redução de mortalidade',
    ],
    contraindications: [
      'Bradicardia < 60 bpm sintomática',
      'BAV de 2º/3º grau sem marcapasso',
      'Asma brônquica grave',
      'Insuficiência cardíaca descompensada (uso IV relativa)',
      'Hipotensão (PAS < 90 mmHg)',
    ],
    interactions: [
      'Verapamil / diltiazem IV: bradicardia grave / assistolia (evitar)',
      'Clonidina: risco de hipertensão de rebote na suspensão',
      'IMAO: potenciação adrenérgica',
    ],
    sideEffects: [
      'Fadiga', 'Bradicardia', 'Broncoespasmo',
      'Disfunção erétil', 'Hipotensão', 'Depressão',
    ],
    dosageTables: [
      _DosageTable(population: 'Adulto', rows: [
        _DosageRow(label: 'HAS (oral)', dose: '25–100 mg 2×/dia', note: 'Tartarato; titular lentamente'),
        _DosageRow(label: 'ICC (oral)', dose: '12,5–200 mg/dia', note: 'Succinato (XL). Iniciar baixo, titular'),
        _DosageRow(label: 'FA (IV)', dose: '2,5–5 mg IV', note: 'Repetir a cada 5 min. Máx. 15 mg'),
      ]),
    ],
    references: [
      _EvidenceRef(num: 1, title: '2022 AHA/ACC HF Guideline', source: 'American Heart Association / ACC', year: '2022', type: 'Diretriz'),
      _EvidenceRef(num: 2, title: 'ESC Heart Failure Guideline 2021', source: 'European Society of Cardiology', year: '2021', type: 'Diretriz'),
      _EvidenceRef(num: 3, title: 'Metoprolol: Drug Information', source: 'Lexicomp®', year: '2024', type: 'Base de Dados'),
    ],
    links: [
      _OfficialLink(label: 'AHA/ACC HF 2022', url: 'https://www.ahajournals.org/doi/10.1161/CIR.0000000000001063', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'ESC HF Guideline', url: 'https://www.escardio.org/Guidelines/Clinical-Practice-Guidelines/Acute-and-Chronic-Heart-Failure', icon: Icons.open_in_new_rounded),
      _OfficialLink(label: 'FDA Label', url: 'https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm', icon: Icons.open_in_new_rounded),
    ],
    renalAdjustment: 'Sem ajuste necessário',
  ),
};

/// Retorna evidência do banco para um fármaco, buscando por nome normalizado.
_DrugEvidence? _getEvidence(String drugName) {
  final key = drugName.toLowerCase()
    .replaceAll('é', 'e').replaceAll('á', 'a').replaceAll('ó', 'o')
    .replaceAll('í', 'i').replaceAll('ú', 'u').replaceAll('ñ', 'n')
    .replaceAll('adrenalina (epinefrina)', 'adrenalina')
    .replaceAll('noradrenalina (norepinefrina)', 'noradrenalina')
    .split(' ')[0];
  return _kDrugEvidenceDB[key];
}

// ─────────────────────────────────────────────────────────────────────────────
// DETALHE DO FÁRMACO — Layout Premium estilo Amboss/UpToDate/Medscape
// ─────────────────────────────────────────────────────────────────────────────
class _DrugDetailView extends StatefulWidget {
  final DrugModel drug;
  final VoidCallback onBack;
  final AppProvider p;
  final ScrollController? scrollController;
  const _DrugDetailView({
    required this.drug,
    required this.onBack,
    required this.p,
    this.scrollController,
  });

  @override
  State<_DrugDetailView> createState() => _DrugDetailViewState();
}

class _DrugDetailViewState extends State<_DrugDetailView>
    with SingleTickerProviderStateMixin {

  // ── Calculadora ────────────────────────────────────────────────────────────
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _creatCtrl;
  late String _sex;

  // ── Tab clínica ────────────────────────────────────────────────────────────
  late TabController _tabCtrl;
  static const _tabs = [
    'Informação Clínica',
    'Uso Clínico',
    'Efeitos Adversos',
    'Contraindicações',
    'Farmacocinética',
  ];

  // ── Panels expansíveis ─────────────────────────────────────────────────────
  bool _linksExpanded = false;

  @override
  void initState() {
    super.initState();
    final pt = widget.p.patient;
    _weightCtrl = TextEditingController(text: pt.weight);
    _heightCtrl = TextEditingController(text: pt.height);
    _ageCtrl    = TextEditingController(text: pt.age);
    _creatCtrl  = TextEditingController(text: pt.creatinine);
    _sex        = pt.sex.isNotEmpty ? pt.sex : 'M';
    _tabCtrl    = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    _creatCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  double? get _w  => double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
  double? get _h  => double.tryParse(_heightCtrl.text.replaceAll(',', '.'));
  double? get _a  => double.tryParse(_ageCtrl.text.replaceAll(',', '.'));
  double? get _cr => double.tryParse(_creatCtrl.text.replaceAll(',', '.'));

  String? get _bmiLocal {
    final w = _w; final h = _h;
    if (w == null || h == null || h == 0) return null;
    final hm = h / 100;
    return (w / (hm * hm)).toStringAsFixed(1);
  }

  String? get _clcrLocal {
    final cr = _cr; final a = _a; final w = _w;
    if (cr == null || a == null || w == null || cr == 0) return null;
    double v = (140 - a) * w / (72 * cr);
    if (_sex == 'F') v *= 0.85;
    return v.toStringAsFixed(1);
  }

  DoseInfo _calcDose() {
    final drug  = widget.drug;
    final lang  = widget.p.lang;
    final w     = _w;
    final a     = _a;
    final clcrV = double.tryParse(_clcrLocal ?? '');
    final alerts = <String>[];

    if ((drug.doseType == 'weight' || drug.doseType == 'infusion') && w == null) {
      alerts.add(lang == 'es'
          ? 'Ingrese el peso del paciente para calcular la dosis exacta en mg/kg.'
          : 'Informe o peso do paciente para calcular a dose exata em mg/kg.');
    }

    final renalAlert = drug.getField(drug.renalAlert, lang);
    if (clcrV != null && clcrV > 0 && clcrV < 50 && renalAlert.isNotEmpty &&
        !renalAlert.toLowerCase().contains('sem ajuste') &&
        !renalAlert.toLowerCase().contains('sin ajuste')) {
      alerts.add('⚠ Ajuste renal: ClCr ${_clcrLocal ?? '—'} mL/min. $renalAlert');
    }

    final elderlyAlert = drug.getField(drug.elderlyAlert, lang);
    if (a != null && a >= 65 && elderlyAlert.isNotEmpty) {
      alerts.add('⚠ ${lang == 'es' ? 'Paciente anciano: ' : 'Paciente idoso: '}$elderlyAlert');
    }

    if (drug.doseType == 'weight' && w != null && drug.mgKg != null) {
      return DoseInfo(
        main: '${(w * drug.mgKg!).toStringAsFixed(1)} mg/dose',
        detail: '${drug.mgKg} mg/kg. ${drug.getField(drug.frequency, lang)}',
        alerts: alerts,
      );
    }
    if (drug.doseType == 'infusion' && w != null &&
        drug.mcgKgMinStart != null && drug.mcgKgMinMax != null) {
      return DoseInfo(
        main: '${(w * drug.mcgKgMinStart!).toStringAsFixed(1)}–'
              '${(w * drug.mcgKgMinMax!).toStringAsFixed(1)} mcg/min',
        detail: '${drug.mcgKgMinStart}–${drug.mcgKgMinMax} mcg/kg/min em bomba. Titular por resposta.',
        alerts: alerts,
      );
    }
    return widget.p.calculateDose(drug);
  }

  @override
  Widget build(BuildContext context) {
    final p      = widget.p;
    final drug   = widget.drug;
    final dose   = _calcDose();
    final isFav  = p.favDrugs.contains(drug.id);
    final dark   = p.darkMode;
    final c      = AppColors.of(context);
    final ev     = _getEvidence(drug.name);

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ═══════════════════════════════════════════════════════════════════
        // 1. CLINICAL HEADER — gradient premium
        // ═══════════════════════════════════════════════════════════════════
        _ClinicalHeader(
          drug: drug, p: p, isFav: isFav, c: c, dark: dark, ev: ev,
          onBack: widget.onBack,
          onFav: () { HapticFeedback.mediumImpact(); p.toggleFavDrug(drug.id); },
          onCockpit: () { HapticFeedback.mediumImpact(); p.setActiveDrug(drug.id); },
        ),

        const SizedBox(height: 16),

        // ═══════════════════════════════════════════════════════════════════
        // 2. DOSE RECOMENDADA — tabelas por população
        // ═══════════════════════════════════════════════════════════════════
        if (ev != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _DrugSectionTitle(
              icon: Icons.medication_liquid_outlined,
              label: 'DOSES RECOMENDADAS',
              c: c, dark: dark,
            ),
          ),
          const SizedBox(height: 8),
          ...ev.dosageTables.map((table) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: _DosageTableCard(table: table, c: c, dark: dark),
          )),
          const SizedBox(height: 8),
        ],

        // ═══════════════════════════════════════════════════════════════════
        // 3. CALCULADORA DE DOSE PREMIUM
        // ═══════════════════════════════════════════════════════════════════
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _DrugSectionTitle(
            icon: Icons.calculate_outlined,
            label: 'CALCULADORA DE DOSE',
            c: c, dark: dark,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _DoseCalculatorCard(
            drug: drug, p: p, dose: dose, c: c, dark: dark,
            weightCtrl: _weightCtrl, heightCtrl: _heightCtrl,
            ageCtrl: _ageCtrl, creatCtrl: _creatCtrl,
            sex: _sex, bmi: _bmiLocal, clcr: _clcrLocal,
            onSexChange: (s) => setState(() => _sex = s),
            onFieldChange: () => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),

        // ═══════════════════════════════════════════════════════════════════
        // 4. TABS CLÍNICAS — Info / Uso Clínico / Adversos / Contra / PK
        // ═══════════════════════════════════════════════════════════════════
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _DrugSectionTitle(
            icon: Icons.fact_check_outlined,
            label: 'INFORMAÇÃO CLÍNICA',
            c: c, dark: dark,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _ClinicalTabCard(
            drug: drug, p: p, c: c, dark: dark, ev: ev,
            tabCtrl: _tabCtrl, tabs: _tabs,
          ),
        ),
        const SizedBox(height: 16),

        // ═══════════════════════════════════════════════════════════════════
        // 5. EVIDÊNCIA E REFERÊNCIAS (painel direito Amboss-style)
        // ═══════════════════════════════════════════════════════════════════
        if (ev != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _DrugSectionTitle(
              icon: Icons.library_books_outlined,
              label: 'REFERÊNCIAS E EVIDÊNCIA',
              c: c, dark: dark,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _EvidencePanelCard(ev: ev, c: c, dark: dark),
          ),
          const SizedBox(height: 8),
          // ── Links oficiais colapsíveis ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _OfficialLinksCard(
              ev: ev, c: c, dark: dark,
              expanded: _linksExpanded,
              onToggle: () => setState(() => _linksExpanded = !_linksExpanded),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          // Fallback sem dados no banco
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _GenericReferencesCard(c: c, dark: dark),
          ),
          const SizedBox(height: 16),
        ],

        // ═══════════════════════════════════════════════════════════════════
        // 6. AVISO REGULATÓRIO — Apple 1.4.1 compliance
        // ═══════════════════════════════════════════════════════════════════
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _RegulatoryDisclaimerCard(c: c, dark: dark, p: p),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CLINICAL HEADER
// ═════════════════════════════════════════════════════════════════════════════
class _ClinicalHeader extends StatelessWidget {
  final DrugModel drug;
  final AppProvider p;
  final bool isFav;
  final AppColors c;
  final bool dark;
  final _DrugEvidence? ev;
  final VoidCallback onBack;
  final VoidCallback onFav;
  final VoidCallback onCockpit;

  const _ClinicalHeader({
    required this.drug, required this.p, required this.isFav,
    required this.c, required this.dark, required this.ev,
    required this.onBack, required this.onFav, required this.onCockpit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF06100C), Color(0xFF0D2B1E), Color(0xFF075f45)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Barra de navegação ──────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              // Botão voltar
              Material(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(10),
                  splashColor: Colors.white.withValues(alpha: 0.15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.arrow_back_ios_rounded, size: 12, color: Colors.white.withValues(alpha: 0.85)),
                      const SizedBox(width: 4),
                      Text(p.t('back_drugs'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85))),
                    ]),
                  ),
                ),
              ),
              const Spacer(),
              // Favoritar
              Material(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onFav,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Icon(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 18,
                      color: isFav ? const Color(0xFFFFE8A6) : Colors.white54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Usar no cockpit
              Material(
                color: const Color(0xFFFFE8A6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onCockpit,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFE8A6).withValues(alpha: 0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.science_rounded, size: 13, color: Color(0xFFFFE8A6)),
                      const SizedBox(width: 5),
                      Text(p.t('use_in_cockpit'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                          color: Color(0xFFFFE8A6))),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 16),

        // ── Info principal ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Ícone do grupo
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Center(
                child: Icon(DrugGroup.iconData(drug.group), size: 26,
                  color: const Color(0xFFFFE8A6)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Categoria + rota
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8A6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFE8A6).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    p.tDB(drug.category).toUpperCase(),
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900,
                      color: Color(0xFFFFE8A6), letterSpacing: 0.8),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    drug.route,
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              // Nome do fármaco
              Text(drug.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -0.5, height: 1.1)),
              const SizedBox(height: 4),
              // Classe farmacológica
              Text(p.tDB(drug.className),
                style: TextStyle(fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500)),
            ])),
          ]),
        ),

        const SizedBox(height: 14),

        // ── ATC + Status revisado ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            if (ev?.atcCode.isNotEmpty == true) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text('Código ATC: ${ev!.atcCode}',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5))),
              ),
              const SizedBox(width: 8),
            ],
            // Via de administração
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text('Via: ${drug.route}',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.5))),
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Badges: Adulto / Pediatria / Emergência / UTI ───────────────────
        if (ev != null) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            ...ev!.badges.map((b) => _ContextBadge(label: b)),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Linha: Evidência status ─────────────────────────────────────────
        if (ev != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF34D399)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conteúdo Baseado em Evidências  ·  ${ev!.guidelineSource}  ·  Atualizado ${ev!.lastReviewed}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: Color(0xFF86EFAC)),
                ),
              ),
            ]),
          ),

        const SizedBox(height: 16),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BADGE DE CONTEXTO CLÍNICO
// ═════════════════════════════════════════════════════════════════════════════
class _ContextBadge extends StatelessWidget {
  final String label;
  const _ContextBadge({required this.label});

  Color get _bg {
    switch (label) {
      case 'Emergência': return const Color(0xFFDC2626).withValues(alpha: 0.25);
      case 'UTI':        return const Color(0xFF9333EA).withValues(alpha: 0.25);
      case 'Pediatria':  return const Color(0xFF0EA5E9).withValues(alpha: 0.25);
      default:           return Colors.white.withValues(alpha: 0.12);
    }
  }
  Color get _fg {
    switch (label) {
      case 'Emergência': return const Color(0xFFFCA5A5);
      case 'UTI':        return const Color(0xFFD8B4FE);
      case 'Pediatria':  return const Color(0xFF7DD3FC);
      default:           return Colors.white.withValues(alpha: 0.85);
    }
  }
  Color get _border {
    switch (label) {
      case 'Emergência': return const Color(0xFFEF4444).withValues(alpha: 0.4);
      case 'UTI':        return const Color(0xFFA855F7).withValues(alpha: 0.4);
      case 'Pediatria':  return const Color(0xFF38BDF8).withValues(alpha: 0.4);
      default:           return Colors.white.withValues(alpha: 0.15);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _fg)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SEÇÃO TITLE
// ═════════════════════════════════════════════════════════════════════════════
class _DrugSectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors c;
  final bool dark;
  const _DrugSectionTitle({
    required this.icon, required this.label,
    required this.c, required this.dark,
  });
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14,
        color: dark ? const Color(0xFFFFE8A6) : const Color(0xFF075f45)),
      const SizedBox(width: 7),
      Text(label, style: TextStyle(
        fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.6,
        color: dark ? const Color(0xFFFFE8A6) : const Color(0xFF075f45),
      )),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TABELA DE DOSAGEM — por população
// ═════════════════════════════════════════════════════════════════════════════
class _DosageTableCard extends StatelessWidget {
  final _DosageTable table;
  final AppColors c;
  final bool dark;
  const _DosageTableCard({required this.table, required this.c, required this.dark});

  @override
  Widget build(BuildContext context) {
    final popColor = _popColor(table.population);
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header população
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: popColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(children: [
            Container(width: 4, height: 14,
              decoration: BoxDecoration(color: popColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(table.population.toUpperCase(),
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900,
                letterSpacing: 1.4, color: popColor)),
          ]),
        ),
        // Linhas
        ...table.rows.asMap().entries.map((e) {
          final idx = e.key; final row = e.value;
          final isLast = idx == table.rows.length - 1;
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Label
              SizedBox(
                width: 96,
                child: Text(row.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: c.textSecondary)),
              ),
              const SizedBox(width: 8),
              // Dose
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row.dose,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                    color: c.textPrimary)),
                if (row.maxDose != null) ...[
                  const SizedBox(height: 2),
                  Text(row.maxDose!,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626))),
                ],
                if (row.note != null) ...[
                  const SizedBox(height: 3),
                  Text(row.note!,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500,
                      color: c.textHint, height: 1.35)),
                ],
              ])),
            ]),
          );
        }),
      ]),
    );
  }

  Color _popColor(String pop) {
    if (pop.contains('Pediatria')) return const Color(0xFF0EA5E9);
    if (pop.contains('PCR') || pop.contains('emergência')) return const Color(0xFFDC2626);
    if (pop.contains('Renal')) return const Color(0xFFF59E0B);
    return const Color(0xFF059669);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CALCULADORA DE DOSE PREMIUM
// ═════════════════════════════════════════════════════════════════════════════
class _DoseCalculatorCard extends StatelessWidget {
  final DrugModel drug;
  final AppProvider p;
  final DoseInfo dose;
  final AppColors c;
  final bool dark;
  final TextEditingController weightCtrl, heightCtrl, ageCtrl, creatCtrl;
  final String sex;
  final String? bmi, clcr;
  final ValueChanged<String> onSexChange;
  final VoidCallback onFieldChange;

  const _DoseCalculatorCard({
    required this.drug, required this.p, required this.dose,
    required this.c, required this.dark,
    required this.weightCtrl, required this.heightCtrl,
    required this.ageCtrl, required this.creatCtrl,
    required this.sex, required this.bmi, required this.clcr,
    required this.onSexChange, required this.onFieldChange,
  });

  @override
  Widget build(BuildContext context) {
    final w = double.tryParse(weightCtrl.text.replaceAll(',', '.'));

    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(children: [
            const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF075f45)),
            const SizedBox(width: 8),
            Text('DADOS DO PACIENTE',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900,
                letterSpacing: 1.4, color: c.textPrimary)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Sexo
            Text('Sexo biológico',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                color: c.textHint, letterSpacing: 0.3)),
            const SizedBox(height: 6),
            Row(children: [
              _SexToggleBtn(label: p.t('male'),   active: sex == 'M', dark: dark, onTap: () => onSexChange('M')),
              const SizedBox(width: 8),
              _SexToggleBtn(label: p.t('female'), active: sex == 'F', dark: dark, onTap: () => onSexChange('F')),
            ]),
            const SizedBox(height: 12),

            // Peso e altura
            Row(children: [
              Expanded(child: _LocalField(
                label: 'Peso (kg)', hintText: 'ex: 70',
                ctrl: weightCtrl, dark: dark, onChanged: (_) => onFieldChange())),
              const SizedBox(width: 8),
              Expanded(child: _LocalField(
                label: p.lang == 'es' ? 'Talla (cm)' : 'Altura (cm)',
                hintText: 'ex: 170',
                ctrl: heightCtrl, dark: dark, onChanged: (_) => onFieldChange())),
            ]),
            const SizedBox(height: 8),

            // Idade e creatinina
            Row(children: [
              Expanded(child: _LocalField(
                label: p.lang == 'es' ? 'Edad (años)' : 'Idade (anos)',
                hintText: 'ex: 40',
                ctrl: ageCtrl, dark: dark, onChanged: (_) => onFieldChange())),
              const SizedBox(width: 8),
              Expanded(child: _LocalField(
                label: 'Creatinina (mg/dL)', hintText: 'ex: 1,0',
                ctrl: creatCtrl, dark: dark, onChanged: (_) => onFieldChange())),
            ]),
            const SizedBox(height: 10),

            // IMC e ClCr
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Row(children: [
                Expanded(child: _DerivedChip(label: 'IMC',  value: bmi,  unit: 'kg/m²',  dark: dark)),
                Container(width: 1, height: 28, color: c.border),
                Expanded(child: _DerivedChip(label: 'ClCr', value: clcr, unit: 'mL/min', dark: dark)),
              ]),
            ),
          ]),
        ),

        // ── Resultado da dose calculada ─────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(children: [

            // Header resultado
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF06100C), Color(0xFF0D2B1E), Color(0xFF075f45)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8A6).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('DOSE CALCULADA',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900,
                      color: Color(0xFFFFE8A6), letterSpacing: 1.8)),
                ),
                const Spacer(),
                if (w != null)
                  Text('Paciente: ${weightCtrl.text} kg',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55))),
              ]),
            ),

            // Dose principal
            _DoseCard(dose: dose, lang: p.lang),

            // Alertas
            ClinicalAlertBox(messages: dose.alerts),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TABS CLÍNICAS
// ═════════════════════════════════════════════════════════════════════════════
class _ClinicalTabCard extends StatelessWidget {
  final DrugModel drug;
  final AppProvider p;
  final AppColors c;
  final bool dark;
  final _DrugEvidence? ev;
  final TabController tabCtrl;
  final List<String> tabs;

  const _ClinicalTabCard({
    required this.drug, required this.p, required this.c,
    required this.dark, required this.ev,
    required this.tabCtrl, required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final adverse = drug.getAdverse(p.lang);
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Sub-tab bar underline ───────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: TabBar(
            controller: tabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFF4ADE80),
            indicatorWeight: 2.5,
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
            dividerColor: c.border,
            labelColor: c.textPrimary,
            unselectedLabelColor: c.textHint,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tabs: tabs.map((t) => Tab(
              text: t,
              height: 40,
            )).toList(),
          ),
        ),

        // ── Conteúdo das tabs ───────────────────────────────────────────────
        SizedBox(
          height: 260,
          child: TabBarView(
            controller: tabCtrl,
            physics: const ClampingScrollPhysics(),
            children: [

              // TAB 0: Informação Clínica
              _TabContent(children: [
                _ClinInfoBlock(
                  icon: Icons.memory_outlined,
                  title: p.t('mechanism'),
                  content: p.tDB(drug.mechanism),
                  color: const Color(0xFF059669), c: c,
                ),
                const SizedBox(height: 10),
                _ClinInfoBlock(
                  icon: Icons.warning_amber_rounded,
                  title: p.t('warning'),
                  content: p.tDB(drug.warning),
                  color: const Color(0xFFF59E0B), c: c,
                ),
                const SizedBox(height: 10),
                if (ev?.renalAdjustment != null)
                  _ClinInfoBlock(
                    icon: Icons.water_drop_outlined,
                    title: p.t('renal_alert'),
                    content: ev!.renalAdjustment!,
                    color: const Color(0xFF0EA5E9), c: c,
                  )
                else
                  _ClinInfoBlock(
                    icon: Icons.water_drop_outlined,
                    title: p.t('renal_alert'),
                    content: p.tDB(drug.renalAlert),
                    color: const Color(0xFF0EA5E9), c: c,
                  ),
                const SizedBox(height: 10),
                _ClinInfoBlock(
                  icon: Icons.elderly_outlined,
                  title: p.t('elderly_alert'),
                  content: p.tDB(drug.elderlyAlert),
                  color: const Color(0xFF8B5CF6), c: c,
                ),
              ]),

              // TAB 1: Uso Clínico (indicações)
              _TabContent(children: [
                if (ev?.indications.isNotEmpty == true) ...[
                  _ClinListBlock(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'INDICAÇÕES PRINCIPAIS',
                    items: ev!.indications,
                    color: const Color(0xFF059669), c: c,
                  ),
                ] else
                  _EmptyTabMsg(msg: 'Indicações não disponíveis para este fármaco.', c: c),
              ]),

              // TAB 2: Efeitos Adversos
              _TabContent(children: [
                if (ev?.sideEffects.isNotEmpty == true) ...[
                  _ClinChipBlock(
                    icon: Icons.report_problem_outlined,
                    title: 'EFEITOS ADVERSOS',
                    items: ev!.sideEffects,
                    color: const Color(0xFFDC2626), c: c, dark: dark,
                  ),
                ] else if (adverse.isNotEmpty) ...[
                  _ClinChipBlock(
                    icon: Icons.report_problem_outlined,
                    title: 'EFEITOS ADVERSOS',
                    items: adverse,
                    color: const Color(0xFFDC2626), c: c, dark: dark,
                  ),
                ] else
                  _EmptyTabMsg(msg: 'Dados de efeitos adversos não disponíveis.', c: c),
              ]),

              // TAB 3: Contraindicações
              _TabContent(children: [
                if (ev?.contraindications.isNotEmpty == true) ...[
                  _ClinListBlock(
                    icon: Icons.block_rounded,
                    title: 'CONTRAINDICAÇÕES',
                    items: ev!.contraindications,
                    color: const Color(0xFFDC2626), c: c,
                  ),
                  if (ev?.interactions.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    _ClinListBlock(
                      icon: Icons.swap_horiz_rounded,
                      title: 'INTERAÇÕES IMPORTANTES',
                      items: ev!.interactions,
                      color: const Color(0xFFF59E0B), c: c,
                    ),
                  ],
                ] else
                  _EmptyTabMsg(msg: 'Dados de contraindicações não disponíveis.', c: c),
              ]),

              // TAB 4: Farmacocinética
              _TabContent(children: [
                if (ev != null) ...[
                  _PKGrid(ev: ev!, c: c, dark: dark),
                ] else
                  _EmptyTabMsg(msg: 'Dados farmacocinéticos não disponíveis.', c: c),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _TabContent extends StatelessWidget {
  final List<Widget> children;
  const _TabContent({required this.children});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _ClinInfoBlock extends StatelessWidget {
  final IconData icon;
  final String title, content;
  final Color color;
  final AppColors c;
  const _ClinInfoBlock({
    required this.icon, required this.title, required this.content,
    required this.color, required this.c,
  });
  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(title.toUpperCase(),
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900,
              letterSpacing: 1.2, color: color)),
        ]),
        const SizedBox(height: 6),
        Text(content,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: c.textPrimary, height: 1.5)),
      ]),
    );
  }
}

class _ClinListBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;
  final AppColors c;
  const _ClinListBlock({
    required this.icon, required this.title, required this.items,
    required this.color, required this.c,
  });
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(title.toUpperCase(),
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900,
            letterSpacing: 1.2, color: color)),
      ]),
      const SizedBox(height: 8),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(item,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: c.textPrimary, height: 1.4)),
          ),
        ]),
      )),
    ]);
  }
}

class _ClinChipBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;
  final AppColors c;
  final bool dark;
  const _ClinChipBlock({
    required this.icon, required this.title, required this.items,
    required this.color, required this.c, required this.dark,
  });
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(title.toUpperCase(),
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900,
            letterSpacing: 1.2, color: color)),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: items.map((a) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(a,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      ).toList()),
    ]);
  }
}

class _PKGrid extends StatelessWidget {
  final _DrugEvidence ev;
  final AppColors c;
  final bool dark;
  const _PKGrid({required this.ev, required this.c, required this.dark});

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, String?>>[
      {'label': 'Início de Ação', 'value': ev.pkOnset},
      {'label': 'Duração', 'value': ev.pkDuration},
      {'label': 'Meia-vida (t½)', 'value': ev.pkHalfLife},
      {'label': 'Distribuição', 'value': ev.pkDistribution},
      {'label': 'Eliminação', 'value': ev.pkElimination},
      {'label': 'Ligação Proteica', 'value': ev.pkProteinBinding},
    ].where((e) => e['value'] != null).toList();

    return Wrap(
      spacing: 8, runSpacing: 8,
      children: items.map((item) => SizedBox(
        width: (MediaQuery.of(context).size.width - 64) / 2,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['label']!,
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800,
                color: c.textHint, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(item['value']!,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                color: c.textPrimary, height: 1.35)),
          ]),
        ),
      )).toList(),
    );
  }
}

class _EmptyTabMsg extends StatelessWidget {
  final String msg;
  final AppColors c;
  const _EmptyTabMsg({required this.msg, required this.c});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(msg,
      style: TextStyle(fontSize: 12, color: c.textHint, fontStyle: FontStyle.italic)),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// PAINEL DE EVIDÊNCIA E REFERÊNCIAS (Amboss / UpToDate style)
// ═════════════════════════════════════════════════════════════════════════════
class _EvidencePanelCard extends StatelessWidget {
  final _DrugEvidence ev;
  final AppColors c;
  final bool dark;
  const _EvidencePanelCard({required this.ev, required this.c, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header com metadados ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF059669)),
              const SizedBox(width: 7),
              Text('EVIDÊNCIA CIENTÍFICA',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900,
                  letterSpacing: 1.4, color: c.textPrimary)),
            ]),
            const SizedBox(height: 10),
            // Linha de metadados
            Wrap(spacing: 8, runSpacing: 6, children: [
              _EvidMetaChip(label: 'Fonte Principal', value: ev.guidelineSource,
                color: const Color(0xFF059669), c: c),
              _EvidMetaChip(label: 'Nível de Evidência', value: ev.evidenceLevel,
                color: const Color(0xFF0EA5E9), c: c),
              _EvidMetaChip(label: 'Força da Recomendação', value: ev.recommendation,
                color: const Color(0xFF8B5CF6), c: c),
              _EvidMetaChip(label: 'Última Atualização', value: ev.lastReviewed,
                color: const Color(0xFFF59E0B), c: c),
            ]),
          ]),
        ),

        // ── Referências numeradas ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: ev.references.map((ref) =>
            _ReferenceRow(ref: ref, c: c, dark: dark),
          ).toList()),
        ),
      ]),
    );
  }
}

class _EvidMetaChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final AppColors c;
  const _EvidMetaChip({
    required this.label, required this.value, required this.color, required this.c,
  });
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
        style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800,
          letterSpacing: 0.8, color: c.textHint)),
      const SizedBox(height: 2),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(value,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      ),
    ]);
  }
}

class _ReferenceRow extends StatelessWidget {
  final _EvidenceRef ref;
  final AppColors c;
  final bool dark;
  const _ReferenceRow({required this.ref, required this.c, required this.dark});

  Color get _typeColor {
    switch (ref.type) {
      case 'Diretriz':    return const Color(0xFF059669);
      case 'Base de Dados': return const Color(0xFF0EA5E9);
      case 'Estudo':      return const Color(0xFF8B5CF6);
      default:            return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Número
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: _typeColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: _typeColor.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: Text('${ref.num}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _typeColor)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(ref.type.toUpperCase(),
                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900,
                  letterSpacing: 0.6, color: _typeColor)),
            ),
            const SizedBox(width: 6),
            Text(ref.year,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c.textHint)),
          ]),
          const SizedBox(height: 3),
          Text(ref.title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 1),
          Text(ref.source,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: c.textSecondary)),
          if (ref.doi != null) ...[
            const SizedBox(height: 2),
            Text('DOI: ${ref.doi}',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500,
                color: Color(0xFF0EA5E9))),
          ],
        ])),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LINKS OFICIAIS COLAPSÍVEIS
// ═════════════════════════════════════════════════════════════════════════════
class _OfficialLinksCard extends StatelessWidget {
  final _DrugEvidence ev;
  final AppColors c;
  final bool dark;
  final bool expanded;
  final VoidCallback onToggle;
  const _OfficialLinksCard({
    required this.ev, required this.c, required this.dark,
    required this.expanded, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(children: [
        // Header colapsível
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: () { HapticFeedback.lightImpact(); onToggle(); },
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(children: [
                Icon(Icons.link_rounded, size: 15,
                  color: dark ? const Color(0xFFFFE8A6) : const Color(0xFF075f45)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('DOCUMENTOS OFICIAIS',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900,
                      letterSpacing: 1.4, color: c.textPrimary)),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: c.textHint),
                ),
              ]),
            ),
          ),
        ),
        // Links expansíveis
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Column(children: [
              const SizedBox(height: 10),
              ...ev.links.map((link) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Material(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () {}, // url_launcher pode ser adicionado
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.open_in_new_rounded, size: 13,
                          color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(link.label,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: Color(0xFF0EA5E9))),
                        ),
                        Text('Abrir', style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w600, color: c.textHint)),
                      ]),
                    ),
                  ),
                ),
              )),
            ]),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

// Fallback quando não há dados no banco
class _GenericReferencesCard extends StatelessWidget {
  final AppColors c;
  final bool dark;
  const _GenericReferencesCard({required this.c, required this.dark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5E9).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.library_books_outlined, size: 13, color: Color(0xFF0EA5E9)),
          SizedBox(width: 7),
          Text('REFERÊNCIAS E EVIDÊNCIAS',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900,
              letterSpacing: 1.3, color: Color(0xFF0EA5E9))),
        ]),
        const SizedBox(height: 10),
        Text(
          'As informações deste fármaco são baseadas em diretrizes clínicas reconhecidas (AHA, ESC, WHO, SSC), '
          'bases de dados farmacológicas (Micromedex®, Lexicomp®, UpToDate) e protocolos nacionais e internacionais. '
          'Consulte as fontes originais para verificação.',
          style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.5),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// AVISO REGULATÓRIO — Apple App Store 1.4.1 / 1.4.2 compliance
// ═════════════════════════════════════════════════════════════════════════════
class _RegulatoryDisclaimerCard extends StatelessWidget {
  final AppColors c;
  final bool dark;
  final AppProvider p;
  const _RegulatoryDisclaimerCard({required this.c, required this.dark, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1510) : const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark ? const Color(0xFF4A3820) : const Color(0xFFE8D8A0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.gavel_rounded, size: 13, color: Color(0xFFC5A365)),
          const SizedBox(width: 7),
          Text('IMPORTANTE — AVISO REGULATÓRIO',
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900,
              letterSpacing: 1.2, color: Color(0xFFC5A365))),
        ]),
        const SizedBox(height: 10),
        Text(
          'Esta ferramenta tem finalidade educacional e de apoio à decisão clínica. '
          'A prescrição, administração e monitorização dos medicamentos são de responsabilidade '
          'exclusiva do profissional de saúde habilitado.',
          style: TextStyle(fontSize: 11.5, color: c.textPrimary, height: 1.55,
            fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'O MedCases Pro não substitui o julgamento clínico, protocolos institucionais '
          'ou a avaliação médica individual do paciente. Doses e posologias devem ser '
          'confirmadas nas bulas oficiais e diretrizes vigentes antes de qualquer prescrição.',
          style: TextStyle(fontSize: 11.5, color: c.textSecondary, height: 1.55,
            fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFC5A365).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.verified_user_outlined, size: 11, color: Color(0xFFC5A365)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Conteúdo elaborado com base em diretrizes AHA, ESC, WHO, SSC, Lexicomp® e Micromedex® '
                '(${DateTime.now().year}). Atualizado periodicamente pelo Comitê Médico MedCases.',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600,
                  color: Color(0xFFC5A365)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Helpers locais ────────────────────────────────────────────────────────────

class _LocalField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController ctrl;
  final bool dark;
  final ValueChanged<String> onChanged;
  const _LocalField({
    required this.label, required this.ctrl,
    required this.dark,  required this.onChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bg     = c.inputBg;
    final border = c.border;
    final text   = c.textPrimary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
          color: Color(0xFF999999), letterSpacing: 0.4)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: text),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: bg,
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF999999).withValues(alpha: 0.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kGreen, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}

class _SexToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final bool dark;
  final VoidCallback onTap;
  const _SexToggleBtn({
    required this.label, required this.active,
    required this.dark,  required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Material(
        color: active ? c.darkBtn : c.inputBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          splashColor: kGoldLight.withValues(alpha: 0.15),
          highlightColor: kGoldLight.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? c.darkBtn : c.border),
            ),
            child: Center(
              child: Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                  color: active ? kGoldLight : c.textHint)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DerivedChip extends StatelessWidget {
  final String label;
  final String? value;
  final String unit;
  final bool dark;
  const _DerivedChip({
    required this.label, required this.value,
    required this.unit,  required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
            color: c.textHint, letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value ?? '—',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary)),
          if (value != null) ...[
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(unit,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c.textHint)),
            ),
          ],
        ]),
      ]),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Card de dose com hierarquia visual
// ─────────────────────────────────────────────────────────────────────────────
class _DoseCard extends StatelessWidget {
  final DoseInfo dose;
  final String lang;
  const _DoseCard({required this.dose, required this.lang});

  /// Quebra o texto da dose em segmentos lógicos.
  /// Suporta os 3 padrões do banco:
  ///   1. " | "  → fármacos novos (dabigatrana, ticagrelor, etc.)
  ///   2. ". "   → fármacos antigos (adenosina, amiodarona, etc.)
  ///   3. "; "   → fármacos com ponto-e-vírgula (valproato, lítio, etc.)
  List<String> _parseSegments(String text) {
    List<String> parts;

    // 1. Pipe tem prioridade — padrão explícito dos fármacos mais recentes
    if (text.contains(' | ')) {
      parts = text.split(' | ');
    }
    // 2. Ponto final + espaço + letra maiúscula ou dígito
    else if (RegExp(r'\.\s+[A-ZÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÜÇ0-9]').hasMatch(text)) {
      parts = text.split(RegExp(r'\.\s+(?=[A-ZÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÜÇ0-9])'));
    }
    // 3. Ponto-e-vírgula + espaço (qualquer conteúdo após)
    else if (text.contains('; ')) {
      parts = text.split(RegExp(r';\s+'));
    }
    // 4. Dose simples — exibe como bloco único
    else {
      parts = [text];
    }

    return parts.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Classifica o segmento para determinar o estilo visual.
  /// Cobre os 3 padrões do banco: pipe " | ", ponto ". " e ponto-e-vírgula "; ".
  _SegmentType _classifySegment(String seg, int index) {
    final lower = seg.toLowerCase();

    // ── Dose máxima / limite absoluto ──────────────────────────────────────
    if (lower.startsWith('máx') || lower.startsWith('max') ||
        lower.contains('máx.') || lower.contains('máximo') ||
        lower.contains('dose máx') || lower.contains('dosis máx') ||
        lower.contains('não ultrapassar') || lower.contains('no exceder') ||
        lower.contains('limite') || lower.contains('teto')) {
      return _SegmentType.max;
    }

    // ── Manutenção / infusão / titular ─────────────────────────────────────
    if (lower.startsWith('manutenção') || lower.startsWith('mantenimiento') ||
        lower.startsWith('manutenção:') || lower.startsWith('mantenimiento:') ||
        lower.startsWith('infusão') || lower.startsWith('infusión') ||
        lower.startsWith('infusão contínua') || lower.startsWith('infusión continua') ||
        lower.startsWith('titular') || lower.startsWith('manutenção') ||
        lower.contains('em bomba') || lower.contains('contínua:') ||
        lower.contains('contínuo:') || lower.contains('manutenção:')) {
      return _SegmentType.maintenance;
    }

    // ── Repetição / segunda dose / sem resposta ────────────────────────────
    if (lower.startsWith('repetir') || lower.startsWith('2ª dose') ||
        lower.startsWith('se sem resposta') || lower.startsWith('sin respuesta') ||
        lower.startsWith('se necessário') || lower.startsWith('si necesario') ||
        lower.contains('sem resposta') || lower.contains('sin respuesta') ||
        lower.contains('repetir') || lower.contains('2ª dose') ||
        lower.contains('segunda dose') || lower.contains('segunda dosis')) {
      return _SegmentType.repeat;
    }

    // ── Primeiro segmento sempre = destaque primário ───────────────────────
    if (index == 0) return _SegmentType.primary;

    // ── Demais segmentos = secundário ──────────────────────────────────────
    return _SegmentType.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(dose.main);
    final isSingleLine = segments.length == 1;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kDark, Color(0xFF1B3D2A), kGreen],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header label ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8A6).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('DOSE',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                  color: Color(0xFFFFE8A6), letterSpacing: 2.0)),
            ),
          ]),
        ),

        const SizedBox(height: 10),

        // ── Segmentos da dose ─────────────────────────────────────────────
        if (isSingleLine)
          // Dose simples: exibe grande sem numeração
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(segments.first,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: -0.5, height: 1.2)),
          )
        else
          // Dose multi-etapa: linha por linha com hierarquia
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(segments.length, (i) {
                final seg = segments[i];
                final type = _classifySegment(seg, i);
                return _DoseSegmentRow(
                  index: i,
                  text: seg,
                  type: type,
                  isLast: i == segments.length - 1,
                  lang: lang,
                );
              }),
            ),
          ),

        // ── Linha separadora + detalhe ────────────────────────────────────
        if (dose.detail.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 13,
                color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(dose.detail,
                  style: TextStyle(fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500, height: 1.55)),
              ),
            ]),
          ),
        ] else
          const SizedBox(height: 14),

      ]),
    );
  }
}

enum _SegmentType { primary, secondary, repeat, maintenance, max }

class _DoseSegmentRow extends StatelessWidget {
  final int index;
  final String text;
  final _SegmentType type;
  final bool isLast;
  final String lang;

  const _DoseSegmentRow({
    required this.index,
    required this.text,
    required this.type,
    required this.isLast,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    // Configurações visuais por tipo
    final cfg = _segmentConfig(type, lang);

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Linha vertical conectora + badge
        Column(children: [
          // Badge numerado
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: cfg.badgeBg,
              shape: BoxShape.circle,
              border: Border.all(color: cfg.badgeBorder, width: 1.5),
            ),
            child: Center(
              child: cfg.badgeIcon != null
                ? Icon(cfg.badgeIcon, size: 11, color: cfg.badgeFg)
                : Text('${index + 1}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                      color: cfg.badgeFg)),
            ),
          ),
          // Linha vertical (exceto último)
          if (!isLast)
            Expanded(
              child: Container(
                width: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          if (isLast) const SizedBox(height: 12),
        ]),

        const SizedBox(width: 10),

        // Conteúdo do segmento
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Label da etapa
              if (cfg.label != null) ...[
                Text(cfg.label!,
                  style: TextStyle(
                    fontSize: 8.5, fontWeight: FontWeight.w800,
                    color: cfg.labelColor, letterSpacing: 1.4)),
                const SizedBox(height: 2),
              ],
              // Texto da dose
              Text(text,
                style: TextStyle(
                  fontSize: cfg.fontSize,
                  fontWeight: cfg.fontWeight,
                  color: cfg.textColor,
                  height: 1.3,
                  letterSpacing: -0.2)),
              const SizedBox(height: 10),
            ]),
          ),
        ),
      ]),
    );
  }

  _SegCfg _segmentConfig(_SegmentType t, String lang) {
    switch (t) {
      case _SegmentType.primary:
        return _SegCfg(
          label: lang == 'es' ? 'DOSIS INICIAL' : 'DOSE INICIAL',
          labelColor: const Color(0xFFFFE8A6),
          fontSize: 19,
          fontWeight: FontWeight.w900,
          textColor: Colors.white,
          badgeBg: const Color(0xFFFFE8A6).withValues(alpha: 0.25),
          badgeBorder: const Color(0xFFFFE8A6).withValues(alpha: 0.7),
          badgeFg: const Color(0xFFFFE8A6),
        );
      case _SegmentType.repeat:
        return _SegCfg(
          label: lang == 'es' ? 'SIN RESPUESTA' : 'SE SEM RESPOSTA',
          labelColor: const Color(0xFF90CDD9),
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          textColor: Colors.white.withValues(alpha: 0.92),
          badgeBg: const Color(0xFF90CDD9).withValues(alpha: 0.15),
          badgeBorder: const Color(0xFF90CDD9).withValues(alpha: 0.5),
          badgeFg: const Color(0xFF90CDD9),
        );
      case _SegmentType.maintenance:
        return _SegCfg(
          label: lang == 'es' ? 'MANTENIMIENTO' : 'MANUTENÇÃO',
          labelColor: const Color(0xFF90CDD9),
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          textColor: Colors.white.withValues(alpha: 0.92),
          badgeBg: const Color(0xFF90CDD9).withValues(alpha: 0.15),
          badgeBorder: const Color(0xFF90CDD9).withValues(alpha: 0.5),
          badgeFg: const Color(0xFF90CDD9),
        );
      case _SegmentType.max:
        return _SegCfg(
          label: lang == 'es' ? 'DOSIS MÁXIMA' : 'DOSE MÁXIMA',
          labelColor: const Color(0xFFFFB3B3),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textColor: const Color(0xFFFFB3B3),
          badgeBg: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
          badgeBorder: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
          badgeFg: const Color(0xFFFFB3B3),
          badgeIcon: Icons.block_rounded,
        );
      case _SegmentType.secondary:
        return _SegCfg(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          textColor: Colors.white.withValues(alpha: 0.80),
          badgeBg: Colors.white.withValues(alpha: 0.08),
          badgeBorder: Colors.white.withValues(alpha: 0.20),
          badgeFg: Colors.white.withValues(alpha: 0.6),
        );
    }
  }
}

class _SegCfg {
  final String? label;
  final Color labelColor;
  final double fontSize;
  final FontWeight fontWeight;
  final Color textColor;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeFg;
  final IconData? badgeIcon;

  const _SegCfg({
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
// CAMPO DE BUSCA COM AUTOCOMPLETE — DrugsScreen
// Após digitar a 3ª letra, exibe dropdown com fármacos correspondentes.
// Clicar numa sugestão navega direto para o detalhe do fármaco.
// Também aceita termos do _termMap (nomes comerciais, genéricos, inglês).
// ─────────────────────────────────────────────────────────────────────────────
class _DrugSearchAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final List<DrugModel> allDrugs;
  final ValueChanged<String> onChanged;
  final ValueChanged<DrugModel> onDrugSelected;

  const _DrugSearchAutocomplete({
    required this.controller,
    required this.hintText,
    required this.allDrugs,
    required this.onChanged,
    required this.onDrugSelected,
  });

  @override
  State<_DrugSearchAutocomplete> createState() =>
      _DrugSearchAutocompleteState();
}

class _DrugSearchAutocompleteState extends State<_DrugSearchAutocomplete> {
  // Nomes canônicos do banco de interações (para o overlay de sugestões)
  static final List<String> _allTerms =
      DrugInteractionService.getAllDrugNames();

  OverlayEntry? _overlay;
  final LayerLink _layerLink = LayerLink();

  // Sugestões actuais: fármacos da DB cujo nome/classe bate com o token
  List<DrugModel> _drugSuggestions = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    super.dispose();
  }

  // ── Lógica ────────────────────────────────────────────────────────────────
  void _onTextChanged() {
    final q = widget.controller.text.toLowerCase().trim();

    // Só ativa a partir do 3º caractere
    if (q.length < 3) {
      _removeOverlay();
      return;
    }

    // 1. Busca fármacos na DB pelo nome, classe ou grupo
    final byName = widget.allDrugs.where((d) {
      return d.name.toLowerCase().contains(q);
    }).toList();

    // 2. Busca por termos do _termMap (nomes comerciais, siglas, inglês)
    //    Encontra os canonical names e mapeia de volta para DrugModel
    final termMatches = _allTerms
        .where((t) => t.toLowerCase().contains(q))
        .toList();

    // Para cada termo, tenta encontrar um DrugModel com nome similar
    final Set<String> seenIds = byName.map((d) => d.id).toSet();
    for (final term in termMatches) {
      final match = widget.allDrugs.where((d) {
        return d.name.toLowerCase().contains(term.toLowerCase()) &&
            !seenIds.contains(d.id);
      });
      for (final d in match) {
        byName.add(d);
        seenIds.add(d.id);
      }
    }

    // Deduplica e limita
    final seen2 = <String>{};
    final unique = byName.where((d) => seen2.add(d.id)).take(8).toList();

    if (unique.isEmpty) {
      _removeOverlay();
      return;
    }

    _drugSuggestions = unique;

    if (_overlay == null) {
      _showOverlay();
    } else {
      _overlay!.markNeedsBuild();
    }
  }

  // ── Overlay ───────────────────────────────────────────────────────────────
  void _showOverlay() {
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(builder: (_) => _buildOverlay());
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    _drugSuggestions = [];
  }

  void _selectDrug(DrugModel drug) {
    // Preenche o campo com o nome do fármaco selecionado
    widget.controller.text = drug.name;
    widget.controller.selection = TextSelection.collapsed(
      offset: drug.name.length,
    );
    widget.onChanged(drug.name);
    _removeOverlay();
    // Navega para o detalhe
    widget.onDrugSelected(drug);
  }

  Widget _buildOverlay() {
    return Positioned(
      width: 0,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 48), // altura do TextField
        child: Align(
          alignment: Alignment.topLeft,
          child: _DrugSuggestionDropdown(
            suggestions: _drugSuggestions,
            query: widget.controller.text.toLowerCase().trim(),
            onSelect: _selectDrug,
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        onChanged: (v) {
          widget.onChanged(v);
          // Fecha overlay se o usuário apagou tudo
          if (v.trim().length < 3) _removeOverlay();
        },
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: kDark,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle:
              TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.search_rounded, size: 20, color: Color(0xFF888888)),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          // Botão de limpar campo
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.controller.clear();
                    widget.onChanged('');
                    _removeOverlay();
                  },
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFFAAAAAA)),
                  splashRadius: 18,
                  padding: const EdgeInsets.only(right: 4),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kGold, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DROPDOWN DE SUGESTÕES — DrugsScreen
// Lista clicável com nome + grupo + rota de cada fármaco sugerido.
// ─────────────────────────────────────────────────────────────────────────────
class _DrugSuggestionDropdown extends StatelessWidget {
  final List<DrugModel> suggestions;
  final String query;
  final ValueChanged<DrugModel> onSelect;

  const _DrugSuggestionDropdown({
    required this.suggestions,
    required this.query,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const maxVisible = 6;
    const itemH = 52.0;
    final count = suggestions.length.clamp(1, maxVisible);
    final boxH = count * itemH + 8.0;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: boxH,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 14,
              endIndent: 14,
              color: Color(0xFFF0EEE8),
            ),
            itemBuilder: (_, i) {
              final drug = suggestions[i];
              // Realça parte que bate com o query no nome
              return InkWell(
                onTap: () => onSelect(drug),
                splashColor: const Color(0xFFECFDF5),
                highlightColor: const Color(0xFFF0FFF8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(children: [
                    // Ícone de grupo
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          DrugGroup.iconData(drug.group),
                          size: 15,
                          color: kGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nome com realce do trecho buscado
                          _HighlightText(
                            text: drug.name,
                            query: query,
                            baseStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: kDark,
                            ),
                            highlightStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: kGreen,
                              backgroundColor: Color(0xFFD1FAE5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DrugGroup.label(drug.group, isEs: context.read<AppProvider>().lang == "es")} · ${drug.route}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF888888),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Color(0xFFCCCCCC),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — realça o trecho buscado dentro de um texto
// ─────────────────────────────────────────────────────────────────────────────
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;
  final TextStyle highlightStyle;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.baseStyle,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final idx = lowerText.indexOf(lowerQuery);

    if (idx < 0) {
      return Text(text, style: baseStyle, overflow: TextOverflow.ellipsis);
    }

    final before = text.substring(0, idx);
    final match = text.substring(idx, idx + query.length);
    final after = text.substring(idx + query.length);

    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(text: match, style: highlightStyle),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }
}
