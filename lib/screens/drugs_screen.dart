import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/drug_model.dart';
import '../services/drug_interaction_service.dart';
import '../widgets/common_widgets.dart';

class DrugsScreen extends StatefulWidget {
  const DrugsScreen({super.key});
  @override
  State<DrugsScreen> createState() => _DrugsScreenState();
}

class _DrugsScreenState extends State<DrugsScreen> {
  final _searchCtrl = TextEditingController();
  DrugModel? _selected;
  // Grupos expandidos — por padrão todos fechados
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

    // Filtro global
    final allDrugs = p.drugsDB;
    final filtered = isSearching
        ? allDrugs.where((d) {
            return d.name.toLowerCase().contains(q) ||
                (d.className[p.lang] ?? '').toLowerCase().contains(q) ||
                (d.category[p.lang] ?? '').toLowerCase().contains(q) ||
                d.group.toLowerCase().contains(q) ||
                (d.warning?[p.lang] ?? '').toLowerCase().contains(q);
          }).toList()
        : allDrugs;

    // Deduplicar por id
    final seen = <String>{};
    final unique = filtered.where((d) => seen.add(d.id)).toList();

    // Ordenar: favoritos primeiro, depois alfabético
    unique.sort((a, b) {
      final aFav = p.favDrugs.contains(a.id) ? 0 : 1;
      final bFav = p.favDrugs.contains(b.id) ? 0 : 1;
      if (aFav != bFav) return aFav.compareTo(bFav);
      return a.name.compareTo(b.name);
    });

    final dark = p.darkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      child: Column(children: [

        // ── Header premium ────────────────────────────────────────────────────
        PremiumCard(
          child: SectionTitle(
            eyebrow: 'Knowledge Base',
            title: p.t('drugs'),
            subtitle: p.t('drugs_subtitle'),
            light: true,
          ),
        ),
        const SizedBox(height: 12),

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
    final headerBg = dark ? const Color(0xFF121F17) : const Color(0xFFF5F2EB);
    final headerBorder = dark ? const Color(0xFF1E3526) : const Color(0xFFDDD8CC);
    final titleColor = dark ? Colors.white : kDark;
    final countColor = dark ? Colors.white38 : const Color(0xFF999999);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [

          // ── Cabeçalho do grupo ──────────────────────────────────────────────
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border.all(color: headerBorder),
                borderRadius: isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(14))
                    : BorderRadius.circular(14),
              ),
              child: Row(children: [
                // Ícone do grupo
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF162B1E)
                        : const Color(0xFFECE9E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: iconData != null
                        ? Icon(iconData, size: 17,
                            color: iconColor ?? (dark ? const Color(0xFF9BE3BF) : kGreen))
                        : Text(icon, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                // Nome e contagem
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.lang == 'es'
                        ? '${drugs.length} ${drugs.length == 1 ? 'fármaco' : 'fármacos'}'
                        : '${drugs.length} ${drugs.length == 1 ? 'fármaco' : 'fármacos'}',
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

          // ── Lista de fármacos expandida ──────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF0F1C14) : Colors.white,
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
    final divColor = dark ? const Color(0xFF1E3526) : const Color(0xFFEEEAE0);
    final nameColor = dark ? Colors.white : kDark;
    final subColor = dark ? Colors.white38 : const Color(0xFF888888);
    final warnColor = dark ? Colors.white54 : const Color(0xFF777777);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
            GestureDetector(
              onTap: () => p.toggleFavDrug(drug.id),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  color: isFav ? kGold : const Color(0xFFCCCCCC),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kDark,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETALHE DO FÁRMACO — com campos locais editáveis para cálculo de dose
// ─────────────────────────────────────────────────────────────────────────────
class _DrugDetailView extends StatefulWidget {
  final DrugModel drug;
  final VoidCallback onBack;
  final AppProvider p;
  const _DrugDetailView({required this.drug, required this.onBack, required this.p});

  @override
  State<_DrugDetailView> createState() => _DrugDetailViewState();
}

class _DrugDetailViewState extends State<_DrugDetailView> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _creatCtrl;
  late String _sex;

  @override
  void initState() {
    super.initState();
    final pt = widget.p.patient;
    _weightCtrl = TextEditingController(text: pt.weight);
    _heightCtrl = TextEditingController(text: pt.height);
    _ageCtrl    = TextEditingController(text: pt.age);
    _creatCtrl  = TextEditingController(text: pt.creatinine);
    _sex        = pt.sex.isNotEmpty ? pt.sex : 'M';
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    _creatCtrl.dispose();
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
          ? 'Peso obligatorio para cálculo por kg o infusión.'
          : 'Peso obrigatório para cálculo por kg ou infusão.');
    }

    final renalAlert = drug.getField(drug.renalAlert, lang);
    if (clcrV != null && clcrV > 0 && clcrV < 50 && renalAlert.isNotEmpty &&
        !renalAlert.toLowerCase().contains('sem ajuste') &&
        !renalAlert.toLowerCase().contains('sin ajuste')) {
      alerts.add('Ajuste renal: ClCr ${_clcrLocal ?? '—'} mL/min. $renalAlert');
    }

    final elderlyAlert = drug.getField(drug.elderlyAlert, lang);
    if (a != null && a >= 65 && elderlyAlert.isNotEmpty) {
      alerts.add('${lang == 'es' ? 'Paciente anciano: ' : 'Paciente idoso: '}$elderlyAlert');
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
        detail: '${drug.mcgKgMinStart}–${drug.mcgKgMinMax} mcg/kg/min em bomba. '
                'Titular por resposta clínica.',
        alerts: alerts,
      );
    }
    return widget.p.calculateDose(drug);
  }

  @override
  Widget build(BuildContext context) {
    final p       = widget.p;
    final drug    = widget.drug;
    final dose    = _calcDose();
    final adverse = drug.getAdverse(p.lang);
    final isFav   = p.favDrugs.contains(drug.id);
    final dark    = p.darkMode;
    final cardBg  = dark ? const Color(0xFF121F17) : Colors.white;
    final border  = dark ? const Color(0xFF1E3526) : kBorder;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Voltar ──────────────────────────────────────────────────────────
        GestureDetector(
          onTap: widget.onBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
              color: cardBg,
            ),
            child: Row(children: [
              Icon(Icons.arrow_back_ios, size: 14,
                  color: dark ? Colors.white70 : kDark),
              const SizedBox(width: 4),
              Text(p.t('back_drugs'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                  color: dark ? Colors.white70 : kDark)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // ── Grupo pill ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: dark
                ? const Color(0xFF162B1E)
                : const Color(0xFFECE9E0),
          ),
          child: Text(
            '${DrugGroup.icon(drug.group)}  ${drug.group}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white54 : const Color(0xFF666666),
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Header premium ───────────────────────────────────────────────────
        PremiumCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.tDB(drug.category)} • ${drug.route}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                  color: Color(0xBFFFE8A6), letterSpacing: 1.4)),
              const SizedBox(height: 4),
              Text(drug.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 5),
              Text(p.tDB(drug.className),
                style: TextStyle(fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600)),
            ])),
            GestureDetector(
              onTap: () => p.toggleFavDrug(drug.id),
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

        // ── Card de dose — campos locais editáveis ───────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Text(p.t('calculated_dose'),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
                color: dark ? const Color(0xFFFFE8A6) : kDark)),
            const SizedBox(height: 2),
            Text(p.t('edit_to_recalc'),
              style: TextStyle(fontSize: 11,
                color: dark ? Colors.white38 : const Color(0xFF999999),
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),

            _FieldLabel(p.t('bio_sex')),
            const SizedBox(height: 6),
            Row(children: [
              _SexToggleBtn(label: p.t('male'),   active: _sex == 'M', dark: dark, onTap: () => setState(() => _sex = 'M')),
              const SizedBox(width: 8),
              _SexToggleBtn(label: p.t('female'), active: _sex == 'F', dark: dark, onTap: () => setState(() => _sex = 'F')),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: _LocalField(label: widget.p.lang == 'es' ? 'Peso (kg)' : 'Peso (kg)',    ctrl: _weightCtrl, dark: dark, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: _LocalField(label: widget.p.lang == 'es' ? 'Talla (cm)' : 'Altura (cm)',  ctrl: _heightCtrl, dark: dark, onChanged: (_) => setState(() {}))),
            ]),
            const SizedBox(height: 8),

            Row(children: [
              Expanded(child: _LocalField(label: widget.p.lang == 'es' ? 'Edad (años)' : 'Idade (anos)', ctrl: _ageCtrl,    dark: dark, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: _LocalField(label: 'Creatinina (mg/dL)', ctrl: _creatCtrl, dark: dark, onChanged: (_) => setState(() {}))),
            ]),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF0F1C14).withValues(alpha: 0.6)
                    : const Color(0xFFF5F2EC),
              ),
              child: Row(children: [
                _DerivedChip(label: 'IMC',  value: _bmiLocal,  unit: 'kg/m²',  dark: dark),
                Container(width: 1, height: 28,
                  color: dark ? Colors.white12 : const Color(0xFFDDD8CC),
                  margin: EdgeInsets.zero),
                _DerivedChip(label: 'ClCr', value: _clcrLocal, unit: 'mL/min', dark: dark),
              ]),
            ),
            const SizedBox(height: 14),

            _DoseCard(dose: dose, lang: p.lang),

            ClinicalAlertBox(messages: dose.alerts),
            const SizedBox(height: 14),

            GestureDetector(
              onTap: () => p.setActiveDrug(drug.id),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: kDark,
                  boxShadow: [BoxShadow(
                    color: kDark.withValues(alpha: 0.35),
                    blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: Text(p.t('use_in_cockpit'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                      color: kGoldLight)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Ficha técnica ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.t('drug_sheet'),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
                color: dark ? const Color(0xFFFFE8A6) : kDark)),
            const SizedBox(height: 14),
            InfoBlock(label: p.t('mechanism'),    text: p.tDB(drug.mechanism)),
            const SizedBox(height: 10),
            _Divider(dark: dark),
            const SizedBox(height: 10),
            InfoBlock(label: p.t('warning'),      text: p.tDB(drug.warning)),
            const SizedBox(height: 10),
            _Divider(dark: dark),
            const SizedBox(height: 10),
            InfoBlock(label: p.t('renal_alert'),  text: p.tDB(drug.renalAlert)),
            const SizedBox(height: 10),
            _Divider(dark: dark),
            const SizedBox(height: 10),
            InfoBlock(label: p.t('elderly_alert'), text: p.tDB(drug.elderlyAlert)),
            if (adverse.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Divider(dark: dark),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFFFF5F5),
                  border: Border.all(color: const Color(0xFFFFCCCC)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.t('adverse_events'),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                      letterSpacing: 1.4, color: Color(0xFFCC0000))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: adverse.map((a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4)],
                      ),
                      child: Text(a,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                          color: Color(0xFFCC0000))),
                    )).toList(),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Helpers locais ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
      color: Color(0xFF999999), letterSpacing: 0.5));
}

class _LocalField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool dark;
  final ValueChanged<String> onChanged;
  const _LocalField({
    required this.label, required this.ctrl,
    required this.dark,  required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = dark ? const Color(0xFF0F1C14) : const Color(0xFFF8F5EF);
    final border = dark ? const Color(0xFF1E3526) : const Color(0xFFDDD8CC);
    final text   = dark ? Colors.white : kDark;
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? kDark : (dark ? const Color(0xFF0F1C14) : const Color(0xFFF5F2EC)),
            border: Border.all(
              color: active ? kDark : (dark ? const Color(0xFF1E3526) : const Color(0xFFDDD8CC)),
            ),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: active ? kGoldLight
                    : (dark ? Colors.white38 : const Color(0xFF999999)),
              )),
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
    final textColor = dark ? Colors.white70 : kDark;
    final subColor  = dark ? Colors.white38 : const Color(0xFF888888);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
          color: subColor, letterSpacing: 0.8)),
      const SizedBox(height: 2),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value ?? '—',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
        if (value != null) ...[
          const SizedBox(width: 3),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(unit,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: subColor)),
          ),
        ],
      ]),
    ]);
  }
}

class _Divider extends StatelessWidget {
  final bool dark;
  const _Divider({required this.dark});
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEEEAE0),
  );
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
              ? GestureDetector(
                  onTap: () {
                    widget.controller.clear();
                    widget.onChanged('');
                    _removeOverlay();
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFFAAAAAA)),
                  ),
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
                            '${drug.group} · ${drug.route}',
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
