import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

class CockpitScreen extends StatefulWidget {
  final Function(String) openProtocol;
  const CockpitScreen({super.key, required this.openProtocol});

  @override
  State<CockpitScreen> createState() => _CockpitScreenState();
}

class _CockpitScreenState extends State<CockpitScreen> {
  bool _copied = false;
  final _drugQueryCtrl = TextEditingController();
  bool _drugPickerOpen = false;

  @override
  void dispose() {
    _drugQueryCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(AppProvider p) async {
    final buf = StringBuffer();
    buf.writeln('=== MEDCASES PRO: COCKPIT CLÍNICO ===');
    buf.writeln('Paciente: ${p.patient.patientId}');
    buf.writeln('Idade: ${p.patient.age} | Sexo: ${p.patient.sex} | Peso: ${p.patient.weight} kg | Creatinina: ${p.patient.creatinine} mg/dL');
    buf.writeln('ClCr: ${p.clcr ?? '—'} mL/min | IMC: ${p.bmi ?? '—'} kg/m²');
    for (final drug in p.selectedDrugs) {
      final dose = p.calculateDose(drug);
      buf.writeln('\n>> Fármaco: ${drug.name}');
      buf.writeln('Dose: ${dose.main}');
      buf.writeln('Detalhe: ${dose.detail}');
      if (dose.alerts.isNotEmpty) {
        buf.writeln('[!] ALERTAS:');
        for (final a in dose.alerts) buf.writeln('- $a');
      }
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final filteredDrugs = p.drugsDB.where((d) {
      if (!p.selectedDrugIds.contains(d.id)) {
        final q = _drugQueryCtrl.text.toLowerCase();
        if (q.isEmpty) return true;
        return d.name.toLowerCase().contains(q) ||
            (d.className[p.lang] ?? '').toLowerCase().contains(q) ||
            (d.category[p.lang] ?? '').toLowerCase().contains(q);
      }
      return false;
    }).take(10).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(children: [
        // ── Premium header ──────────────────────────────────────────────────
        PremiumCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Plantão / Paciente atual', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(
                  p.patient.patientId.isNotEmpty ? p.patient.patientId : 'Leito / Box',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('Centro de comando para triagem, dose e conduta rápida.', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.red.withValues(alpha: 0.2), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                child: Row(children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFFF8888), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('SOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFFCCCC), letterSpacing: 1.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            // Metrics row
            Row(children: [
              Expanded(child: DataPoint(label: 'ClCr', value: p.clcr, unit: 'mL/min', dark: true)),
              const SizedBox(width: 8),
              Expanded(child: DataPoint(label: 'PAM', value: p.map, unit: 'mmHg', dark: true)),
              const SizedBox(width: 8),
              Expanded(child: DataPoint(label: 'IMC', value: p.bmi, unit: 'kg/m²', dark: true)),
            ]),
            const SizedBox(height: 12),
            // Safety status
            _SafetyStatus(clcr: p.clcr, doseAlerts: p.calculateDose(p.activeDrug).alerts),
            const SizedBox(height: 16),
            // Quick protocols
            Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
            const SizedBox(height: 12),
            const Text('Acesso imediato', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0x80FFFFFF), letterSpacing: 1.4)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final item in [('Anafilaxia', 'anafilaxia'), ('Choque', 'choque_cardiogenico'), ('TPSV', 'tpsv'), ('K+ alto', 'hipercalemia')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => widget.openProtocol(item.$2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(item.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Biometrics card ──────────────────────────────────────────────────
        StandardCard(
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const SectionTitle(title: 'Dados biométricos', subtitle: 'Dados mínimos para decisão clínica segura.'),
              GestureDetector(
                onTap: () => p.resetPatient(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder), color: Colors.white),
                  child: Text(p.t('clear'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF555555))),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _FieldRow(label: 'Paciente / Leito', child: MedInput(hintText: 'Ex: Leito 05', initialValue: p.patient.patientId, onChanged: (v) => p.updatePatient('patientId', v))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _FieldRow(label: p.t('age'), child: MedInput(hintText: '68', initialValue: p.patient.age, keyboardType: TextInputType.number, onChanged: (v) => p.updatePatient('age', v)))),
              const SizedBox(width: 10),
              Expanded(child: _FieldRow(label: 'Peso kg', child: MedInput(hintText: '78', initialValue: p.patient.weight, keyboardType: TextInputType.number, onChanged: (v) => p.updatePatient('weight', v)))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _FieldRow(label: 'Altura cm', child: MedInput(hintText: '171', initialValue: p.patient.height, keyboardType: TextInputType.number, onChanged: (v) => p.updatePatient('height', v)))),
              const SizedBox(width: 10),
              Expanded(child: _FieldRow(label: p.t('creatinine'), child: MedInput(hintText: '1.0', initialValue: p.patient.creatinine, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => p.updatePatient('creatinine', v)))),
            ]),
            const SizedBox(height: 10),
            _FieldRow(
              label: p.t('sex'),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: p.patient.sex,
                    isExpanded: true,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kDark),
                    items: const [
                      DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                      DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                    ],
                    onChanged: (v) => p.updatePatient('sex', v ?? 'Masculino'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Drug picker
            _FieldRow(
              label: 'Adicionar fármaco',
              child: Column(children: [
                MedInput(
                  controller: _drugQueryCtrl,
                  hintText: 'Digite para buscar fármaco...',
                  onChanged: (v) => setState(() => _drugPickerOpen = v.isNotEmpty),
                ),
                if (_drugPickerOpen && filteredDrugs.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)]),
                    child: Column(children: filteredDrugs.map((d) => ListTile(
                      dense: true,
                      title: Text(d.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                      subtitle: Text('${p.tDB(d.className)} • ${d.route}', style: const TextStyle(fontSize: 11)),
                      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(8)), child: const Text('usar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight))),
                      onTap: () {
                        p.addDrug(d.id);
                        _drugQueryCtrl.clear();
                        setState(() => _drugPickerOpen = false);
                      },
                    )).toList()),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            // Selected drugs chips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: Colors.white),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fármacos selecionados', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: p.selectedDrugs.map((d) => GestureDetector(
                  onTap: () => p.removeDrug(d.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFBBF7D0))),
                    child: Text('${p.tDB({'pt': d.name, 'es': d.name})} ×', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                  ),
                )).toList()),
                const SizedBox(height: 6),
                const Text('Toque no chip para remover.', style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Dose calculator ───────────────────────────────────────────────────
        StandardCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle(title: 'Calculadora de dose', subtitle: 'Calcula cada fármaco com sexo, peso, IMC, creatinina e ClCr.'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: DataPoint(label: 'Peso', value: p.patient.weight, unit: 'kg')),
              const SizedBox(width: 8),
              Expanded(child: DataPoint(label: 'Altura', value: p.patient.height, unit: 'cm')),
              const SizedBox(width: 8),
              Expanded(child: DataPoint(label: 'ClCr', value: p.clcr, unit: 'mL/min')),
            ]),
            const SizedBox(height: 14),
            // Each drug card
            ...p.selectedDrugs.map((drug) {
              final dose = p.calculateDose(drug);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder), color: Colors.white),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p.tDB(drug.category)} • ${drug.route}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGold, letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        Text(drug.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.4, color: kDark), overflow: TextOverflow.ellipsis),
                      ])),
                      GestureDetector(
                        onTap: () => p.setActiveDrug(drug.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(20)),
                          child: const Text('principal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kDark, Color(0xFF123326), kGreen]),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.t('dose'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 1.4)),
                      const SizedBox(height: 4),
                      Text(dose.main, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text(dose.detail, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7), height: 1.45)),
                    ]),
                  ),
                  if (dose.alerts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: ClinicalAlertBox(messages: dose.alerts),
                    ),
                ]),
              );
            }),
            // Interactions
            if (p.interactionRisks.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFFFFF0F0), border: Border.all(color: const Color(0xFFFFCCCC))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Risco de interação', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFFCC2222))),
                  const SizedBox(height: 6),
                  ...p.interactionRisks.map((r) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $r', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFCC2222), height: 1.4)))),
                ]),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFBBF7D0))),
                child: const Text('Sem interação crítica detectada na base local entre os fármacos selecionados.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
              ),
            // Drug safety info
            _DrugSafetyPanel(p: p),
            const SizedBox(height: 12),
            // Copy button
            GestureDetector(
              onTap: () => _copyToClipboard(p),
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _copied ? const Color(0xFFECFDF5) : kDark,
                  border: _copied ? Border.all(color: const Color(0xFF86EFAC)) : null,
                  boxShadow: _copied ? null : [BoxShadow(color: kDark.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Center(child: Text(
                  _copied ? '✓ ${p.t('copied')}' : '📋 Copiar para prontuário',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _copied ? const Color(0xFF065F46) : kGoldLight),
                )),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Quick protocols ───────────────────────────────────────────────────
        StandardCard(
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const SectionTitle(title: 'Guardia premium', subtitle: 'Atalhos críticos com conduta imediata.'),
              GestureDetector(
                onTap: () {},
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder), color: Colors.white), child: const Text('Ver todos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF555555)))),
              ),
            ]),
            const SizedBox(height: 12),
            ...p.protocolsDB.take(4).map((proto) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => widget.openProtocol(proto.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder), color: Colors.white),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.tDB(proto.severity), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGold, letterSpacing: 1.4)),
                      const SizedBox(height: 2),
                      Text(p.tDB(proto.title), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kDark), overflow: TextOverflow.ellipsis),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(20)), child: const Text('Ver', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight))),
                  ]),
                ),
              ),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _SafetyStatus extends StatelessWidget {
  final String? clcr;
  final List<String> doseAlerts;
  const _SafetyStatus({this.clcr, required this.doseAlerts});

  @override
  Widget build(BuildContext context) {
    final clcrVal = double.tryParse((clcr ?? '').replaceAll(',', '.'));
    final renalRisk = clcrVal != null && clcrVal > 0 && clcrVal < 50;
    final hasAlerts = doseAlerts.isNotEmpty;
    final warning = renalRisk || hasAlerts;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: warning ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.12),
        border: Border.all(color: warning ? Colors.amber.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(warning ? 'Atenção clínica' : 'Parâmetros estáveis', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
        const SizedBox(height: 4),
        Text(
          renalRisk
              ? 'Clearance reduzido: revisar dose, intervalo, nefrotoxicidade e sangramento.'
              : 'Sem alerta renal crítico pelos dados informados. Revisar protocolo, alergias e contexto clínico.',
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600, height: 1.4),
        ),
      ]),
    );
  }
}

class _DrugSafetyPanel extends StatelessWidget {
  final AppProvider p;
  const _DrugSafetyPanel({required this.p});

  @override
  Widget build(BuildContext context) {
    final drug = p.activeDrug;
    final adverse = drug.getAdverse(p.lang);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InfoBlock(label: p.t('mechanism'), text: p.tDB(drug.mechanism)),
      const SizedBox(height: 8),
      InfoBlock(label: p.t('warning'), text: p.tDB(drug.warning)),
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
    ]);
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
      const SizedBox(height: 6),
      child,
    ]);
  }
}
