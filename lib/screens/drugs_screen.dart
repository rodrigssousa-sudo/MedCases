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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(children: [
        PremiumCard(child: SectionTitle(eyebrow: 'Knowledge Base', title: p.t('drugs'), subtitle: 'Pesquise, abra o card e veja a ficha completa do fármaco.', light: true)),
        const SizedBox(height: 12),
        StandardCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MedInput(
              controller: _searchCtrl,
              hintText: 'Pesquisar fármaco, classe, mecanismo ou alerta...',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('${unique.length} fármaco(s) encontrado(s)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
          ]),
        ),
        const SizedBox(height: 12),
        ...unique.map((drug) {
          final isFav = p.favDrugs.contains(drug.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selected = drug),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder), color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
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
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(20)), child: const Text('abrir', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight))),
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

class _DrugDetailView extends StatelessWidget {
  final DrugModel drug;
  final VoidCallback onBack;
  final AppProvider p;
  const _DrugDetailView({required this.drug, required this.onBack, required this.p});

  @override
  Widget build(BuildContext context) {
    final dose = p.calculateDose(drug);
    final adverse = drug.getAdverse(p.lang);
    final isFav = p.favDrugs.contains(drug.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: Colors.white),
            child: const Row(children: [
              Icon(Icons.arrow_back_ios, size: 14, color: kDark),
              SizedBox(width: 4),
              Text('Voltar para fármacos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kDark)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // Header premium card
        PremiumCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.tDB(drug.category)} • ${drug.route}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 1.4)),
              const SizedBox(height: 4),
              Text(drug.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text(p.tDB(drug.className), style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
            ])),
            GestureDetector(
              onTap: () => p.toggleFavDrug(drug.id),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withValues(alpha: 0.1), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                child: Text(isFav ? '⭐' : '☆', style: const TextStyle(fontSize: 20)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // Dose card
        StandardCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle(title: 'Dose calculada neste paciente', subtitle: 'Usando dados do Cockpit: sexo, peso, IMC, creatinina e ClCr.'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DataPoint(label: 'Peso', value: p.patient.weight, unit: 'kg')),
              const SizedBox(width: 8),
              Expanded(child: DataPoint(label: 'IMC', value: p.bmi)),
              const SizedBox(width: 8),
              Expanded(child: DataPoint(label: 'ClCr', value: p.clcr, unit: 'mL/min')),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kDark, Color(0xFF123326), kGreen]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dose calculada', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 1.4)),
                const SizedBox(height: 4),
                Text(dose.main, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text(dose.detail, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600, height: 1.45)),
              ]),
            ),
            ClinicalAlertBox(messages: dose.alerts),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => p.setActiveDrug(drug.id),
              child: Container(
                width: double.infinity, height: 46,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kDark, boxShadow: [BoxShadow(color: kDark.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                child: const Center(child: Text('Usar este fármaco no Cockpit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kGoldLight))),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // Drug details
        StandardCard(
          child: Column(children: [
            InfoBlock(label: p.t('mechanism'), text: p.tDB(drug.mechanism)),
            const SizedBox(height: 8),
            InfoBlock(label: p.t('warning'), text: p.tDB(drug.warning)),
            const SizedBox(height: 8),
            InfoBlock(label: 'Alerta renal', text: p.tDB(drug.renalAlert)),
            const SizedBox(height: 8),
            InfoBlock(label: 'Alerta em idosos', text: p.tDB(drug.elderlyAlert)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFFFFF5F5), border: Border.all(color: const Color(0xFFFFCCCC))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Eventos adversos', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFFCC0000))),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: adverse.map((a) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                  child: Text(a, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFCC0000))),
                )).toList()),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
