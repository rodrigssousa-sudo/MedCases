import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/drug_model.dart';
import '../widgets/common_widgets.dart';

class DrugsScreen extends StatefulWidget {
  const DrugsScreen({super.key});
  @override
  State<DrugsScreen> createState() => _DrugsScreenState();
}

class _DrugsScreenState extends State<DrugsScreen> {
  final _searchCtrl = TextEditingController();
  DrugModel? _selected;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    if (_selected != null) {
      return _DrugDetailView(drug: _selected!, onBack: () => setState(() => _selected = null), p: p);
    }

    final q = _searchCtrl.text.toLowerCase();
    final filtered = p.drugsDB.where((d) {
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          (d.className[p.lang] ?? '').toLowerCase().contains(q) ||
          (d.category[p.lang] ?? '').toLowerCase().contains(q) ||
          (d.warning?[p.lang] ?? '').toLowerCase().contains(q);
    }).toList();

    filtered.sort((a, b) {
      final aFav = p.favDrugs.contains(a.id) ? 0 : 1;
      final bFav = p.favDrugs.contains(b.id) ? 0 : 1;
      return aFav.compareTo(bFav);
    });

    // Deduplicate by id (furosemida appears twice in DB)
    final seen = <String>{};
    final unique = filtered.where((d) => seen.add(d.id)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      child: Column(children: [
        PremiumCard(child: SectionTitle(eyebrow: 'Knowledge Base', title: p.t('drugs'), subtitle: p.t('drugs_subtitle'), light: true)),
        const SizedBox(height: 12),
        StandardCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MedInput(
              controller: _searchCtrl,
              hintText: p.t('drugs_search_hint'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('${unique.length} ${p.t('drugs_found')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
          ]),
        ),
        const SizedBox(height: 12),
        ...unique.map((drug) {
          final isFav = p.favDrugs.contains(drug.id);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: GestureDetector(
              onTap: () => setState(() => _selected = drug),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (isFav) const Padding(padding: EdgeInsets.only(right: 4), child: Text('⭐', style: TextStyle(fontSize: 11))),
                      Flexible(child: Text(drug.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kDark), overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 3),
                    Text('${p.tDB(drug.className)} • ${drug.route}', style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(p.tDB(drug.warning), style: const TextStyle(fontSize: 12, color: Color(0xFF777777), fontWeight: FontWeight.w600, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 8),
                  Column(children: [
                    GestureDetector(
                      onTap: () => p.toggleFavDrug(drug.id),
                      child: Padding(padding: const EdgeInsets.all(4), child: Text(isFav ? '⭐' : '☆', style: const TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(20)), child: Text(p.t('open'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight))),
                  ]),
                ]),
              ),
            ),
          );
        }),
      ]),
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
  // Controladores locais — inicializados com dados do Cockpit
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _creatCtrl;
  late String _sex;

  @override
  void initState() {
    super.initState();
    final pt = widget.p.patient;
    _weightCtrl  = TextEditingController(text: pt.weight);
    _heightCtrl  = TextEditingController(text: pt.height);
    _ageCtrl     = TextEditingController(text: pt.age);
    _creatCtrl   = TextEditingController(text: pt.creatinine);
    _sex         = pt.sex.isNotEmpty ? pt.sex : 'M';
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    _creatCtrl.dispose();
    super.dispose();
  }

  // Cálculo local de IMC e ClCr com os dados deste card
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

  // Cálculo de dose com dados locais (sem depender do Cockpit)
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
    if (drug.doseType == 'infusion' && w != null && drug.mcgKgMinStart != null && drug.mcgKgMinMax != null) {
      return DoseInfo(
        main: '${(w * drug.mcgKgMinStart!).toStringAsFixed(1)}–${(w * drug.mcgKgMinMax!).toStringAsFixed(1)} mcg/min',
        detail: '${drug.mcgKgMinStart}–${drug.mcgKgMinMax} mcg/kg/min em bomba. Titular por resposta clínica.',
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
    final cardBg  = dark ? const Color(0xFF0E1A14) : Colors.white;
    final border  = dark ? const Color(0xFF1A2E20) : kBorder;

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
              Icon(Icons.arrow_back_ios, size: 14, color: dark ? Colors.white70 : kDark),
              const SizedBox(width: 4),
              Text(p.t('back_drugs'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                  color: dark ? Colors.white70 : kDark)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

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
                  color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w600)),
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

            // Título da seção
            Text(p.t('calculated_dose'),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                letterSpacing: 1.8, color: dark ? const Color(0xFFFFE8A6) : kDark)),
            const SizedBox(height: 2),
            Text(p.t('edit_to_recalc'),
              style: TextStyle(fontSize: 11,
                color: dark ? Colors.white38 : const Color(0xFF999999),
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),

            // ── Linha 1: Sexo toggle ────────────────────────────────────────
            _FieldLabel(p.t('bio_sex')),
            const SizedBox(height: 6),
            Row(children: [
              _SexToggleBtn(
                label: p.t('male'),
                active: _sex == 'M',
                dark: dark,
                onTap: () => setState(() => _sex = 'M'),
              ),
              const SizedBox(width: 8),
              _SexToggleBtn(
                label: p.t('female'),
                active: _sex == 'F',
                dark: dark,
                onTap: () => setState(() => _sex = 'F'),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Linha 2: Peso + Altura ──────────────────────────────────────
            Row(children: [
              Expanded(child: _LocalField(
                label: 'Peso (kg)',
                ctrl: _weightCtrl,
                dark: dark,
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 8),
              Expanded(child: _LocalField(
                label: 'Altura (cm)',
                ctrl: _heightCtrl,
                dark: dark,
                onChanged: (_) => setState(() {}),
              )),
            ]),
            const SizedBox(height: 8),

            // ── Linha 3: Idade + Creatinina ─────────────────────────────────
            Row(children: [
              Expanded(child: _LocalField(
                label: 'Idade (anos)',
                ctrl: _ageCtrl,
                dark: dark,
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 8),
              Expanded(child: _LocalField(
                label: 'Creatinina (mg/dL)',
                ctrl: _creatCtrl,
                dark: dark,
                onChanged: (_) => setState(() {}),
              )),
            ]),
            const SizedBox(height: 12),

            // ── Valores derivados (IMC + ClCr) — empilhados ─────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: dark
                  ? const Color(0xFF07110d).withValues(alpha: 0.6)
                  : const Color(0xFFF5F2EC),
              ),
              child: Row(children: [
                _DerivedChip(label: 'IMC', value: _bmiLocal, unit: 'kg/m²', dark: dark),
                Container(width: 1, height: 28,
                  color: dark ? Colors.white12 : const Color(0xFFDDD8CC),
                  margin: const EdgeInsets.symmetric(horizontal: 12)),
                _DerivedChip(label: 'ClCr', value: _clcrLocal, unit: 'mL/min', dark: dark),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Resultado da dose ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kDark, Color(0xFF123326), kGreen],
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('DOSE',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                    color: Color(0xBFFFE8A6), letterSpacing: 1.8)),
                const SizedBox(height: 6),
                Text(dose.main,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.3, height: 1.25)),
                if (dose.detail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(height: 1,
                    color: Colors.white.withValues(alpha: 0.12)),
                  const SizedBox(height: 8),
                  Text(
                    dose.detail
                      .replaceAll(': ', ':\n').replaceAll('; ', ';\n'),
                    style: TextStyle(fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600, height: 1.6)),
                ],
              ]),
            ),

            // Alertas clínicos
            ClinicalAlertBox(messages: dose.alerts),
            const SizedBox(height: 14),

            // ── Botão usar no Cockpit ────────────────────────────────────────
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
                letterSpacing: 1.8, color: dark ? const Color(0xFFFFE8A6) : kDark)),
            const SizedBox(height: 14),
            InfoBlock(label: p.t('mechanism'), text: p.tDB(drug.mechanism)),
            const SizedBox(height: 10),
            _Divider(dark: dark),
            const SizedBox(height: 10),
            InfoBlock(label: p.t('warning'), text: p.tDB(drug.warning)),
            const SizedBox(height: 10),
            _Divider(dark: dark),
            const SizedBox(height: 10),
            InfoBlock(label: p.t('renal_alert'), text: p.tDB(drug.renalAlert)),
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
                          color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
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
    final bg     = dark ? const Color(0xFF07110d) : const Color(0xFFF8F5EF);
    final border = dark ? const Color(0xFF1A2E20) : const Color(0xFFDDD8CC);
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
            color: active ? kDark : (dark ? const Color(0xFF07110d) : const Color(0xFFF5F2EC)),
            border: Border.all(
              color: active ? kDark : (dark ? const Color(0xFF1A2E20) : const Color(0xFFDDD8CC)),
            ),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: active ? kGoldLight : (dark ? Colors.white38 : const Color(0xFF999999)),
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
