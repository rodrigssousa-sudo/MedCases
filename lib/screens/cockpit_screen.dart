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

  // Seções colapsáveis — todas fechadas por padrão
  bool _bioOpen = false;
  bool _doseOpen = false;
  bool _protOpen = false;

  // Drug picker na calculadora
  final _calcDrugQueryCtrl = TextEditingController();
  bool _calcDrugPickerOpen = false;

  @override
  void dispose() {
    _drugQueryCtrl.dispose();
    _calcDrugQueryCtrl.dispose();
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
    }).take(8).toList();

    // Drug picker filtrado para a calculadora
    final calcFilteredDrugs = p.drugsDB.where((d) {
      if (!p.selectedDrugIds.contains(d.id)) {
        final q = _calcDrugQueryCtrl.text.toLowerCase();
        if (q.isEmpty) return true;
        return d.name.toLowerCase().contains(q) ||
            (d.className[p.lang] ?? '').toLowerCase().contains(q) ||
            (d.category[p.lang] ?? '').toLowerCase().contains(q);
      }
      return false;
    }).take(8).toList();

    // Subtítulo dinâmico do card de paciente
    final bioSubtitle = [
      if (p.patient.age.isNotEmpty) '${p.patient.age} anos',
      if (p.patient.weight.isNotEmpty) '${p.patient.weight} kg',
      p.patient.sex,
    ].join(' · ');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(children: [

        // ── HERO HEADER ──────────────────────────────────────────────────────
        _HeroHeader(p: p, openProtocol: widget.openProtocol),
        const SizedBox(height: 14),

        // ── MÉTRICAS RÁPIDAS ─────────────────────────────────────────────────
        _MetricsRow(p: p),
        const SizedBox(height: 14),

        // ── BIOMETRIA (colapsável) ───────────────────────────────────────────
        _CollapsibleSection(
          icon: Icons.person_outline_rounded,
          title: 'Dados do paciente',
          subtitle: bioSubtitle.isEmpty ? 'Toque para preencher' : bioSubtitle,
          isOpen: _bioOpen,
          onToggle: () => setState(() => _bioOpen = !_bioOpen),
          child: _BiometricsBody(
            p: p,
            drugQueryCtrl: _drugQueryCtrl,
            drugPickerOpen: _drugPickerOpen,
            filteredDrugs: filteredDrugs,
            onDrugPickerChanged: (v) => setState(() => _drugPickerOpen = v),
          ),
        ),
        const SizedBox(height: 10),

        // ── CALCULADORA DE DOSE (colapsável) ────────────────────────────────
        _CollapsibleSection(
          icon: Icons.calculate_outlined,
          title: 'Calculadora de dose',
          subtitle: p.selectedDrugs.isEmpty
              ? 'Nenhum fármaco selecionado'
              : '${p.selectedDrugs.length} fármaco${p.selectedDrugs.length > 1 ? 's' : ''} ativo${p.selectedDrugs.length > 1 ? 's' : ''}',
          isOpen: _doseOpen,
          onToggle: () => setState(() => _doseOpen = !_doseOpen),
          badgeCount: p.selectedDrugs.length,
          child: _DoseBody(
            p: p,
            copied: _copied,
            onCopy: () => _copyToClipboard(p),
            drugQueryCtrl: _calcDrugQueryCtrl,
            drugPickerOpen: _calcDrugPickerOpen,
            filteredDrugs: calcFilteredDrugs,
            onDrugPickerChanged: (v) => setState(() => _calcDrugPickerOpen = v),
          ),
        ),
        const SizedBox(height: 10),

        // ── PROTOCOLOS RÁPIDOS (colapsável) ─────────────────────────────────
        _CollapsibleSection(
          icon: Icons.bolt_rounded,
          title: 'Protocolos de emergência',
          subtitle: 'Acesso rápido a condutas críticas',
          isOpen: _protOpen,
          onToggle: () => setState(() => _protOpen = !_protOpen),
          child: _ProtocolsBody(p: p, openProtocol: widget.openProtocol),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final AppProvider p;
  final Function(String) openProtocol;
  const _HeroHeader({required this.p, required this.openProtocol});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('COCKPIT CLÍNICO', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w900,
              color: Color(0xBFFFE8A6), letterSpacing: 2.5,
            )),
            const SizedBox(height: 4),
            Text(
              p.patient.patientId.isNotEmpty ? p.patient.patientId : 'Leito / Box',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
              overflow: TextOverflow.ellipsis,
            ),
          ])),
          // SOS badge
          _SosBadge(),
        ]),
        const SizedBox(height: 14),
        // Safety status inline
        _SafetyStatus(clcr: p.clcr, doseAlerts: p.activeDrug != null ? p.calculateDose(p.activeDrug!).alerts : []),
        const SizedBox(height: 14),
        // Quick access chips
        const Text('ACESSO IMEDIATO', style: TextStyle(
          fontSize: 8, fontWeight: FontWeight.w900,
          color: Color(0x80FFFFFF), letterSpacing: 2,
        )),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final item in [
              ('Anafilaxia', 'anafilaxia'),
              ('Choque', 'choque_cardiogenico'),
              ('TPSV', 'tpsv'),
              ('K+ alto', 'hipercalemia'),
              ('AVC', 'avc_isquemico'),
              ('Sepse', 'sepse'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => openProtocol(item.$2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Text(item.$1, style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
                    )),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _SosBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.red.withValues(alpha: 0.18),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFFF8888), shape: BoxShape.circle)),
        const SizedBox(width: 5),
        const Text('SOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFFCCCC), letterSpacing: 1.5)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MÉTRICAS RÁPIDAS
// ─────────────────────────────────────────────────────────────────────────────
class _MetricsRow extends StatelessWidget {
  final AppProvider p;
  const _MetricsRow({required this.p});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _MetricTile(label: 'ClCr', value: p.clcr ?? '—', unit: 'mL/min', icon: Icons.water_drop_outlined, alert: _isRenalAlert(p.clcr))),
      const SizedBox(width: 8),
      Expanded(child: _MetricTile(label: 'IMC', value: p.bmi ?? '—', unit: 'kg/m²', icon: Icons.monitor_weight_outlined)),
      const SizedBox(width: 8),
      Expanded(child: _MetricTile(label: 'PAM', value: p.map ?? '—', unit: 'mmHg', icon: Icons.favorite_outline_rounded)),
    ]);
  }

  bool _isRenalAlert(String? clcr) {
    final v = double.tryParse((clcr ?? '').replaceAll(',', '.'));
    return v != null && v > 0 && v < 50;
  }
}

class _MetricTile extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final bool alert;
  const _MetricTile({required this.label, required this.value, required this.unit, required this.icon, this.alert = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: alert ? const Color(0xFFFFF8E6) : Colors.white,
        border: Border.all(color: alert ? const Color(0xFFFFD580) : kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: alert ? const Color(0xFFC5A365) : const Color(0xFF888888)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: alert ? kGold : const Color(0xFF888888))),
        ]),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: alert ? kGold : kDark, letterSpacing: -0.5)),
        Text(unit, style: const TextStyle(fontSize: 9, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEÇÃO COLAPSÁVEL GENÉRICA
// ─────────────────────────────────────────────────────────────────────────────
class _CollapsibleSection extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isOpen;
  final VoidCallback onToggle;
  final Widget child;
  final int badgeCount;
  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isOpen,
    required this.onToggle,
    required this.child,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header clicável
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: kDark),
                child: Icon(icon, size: 16, color: kGoldLight),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kDark)),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: kGreen),
                      child: Text('$badgeCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
              ])),
              Icon(isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF888888), size: 22),
            ]),
          ),
        ),
        // Conteúdo animado
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(children: [
            Divider(height: 1, color: kBorder),
            Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 14), child: child),
          ]),
          crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BIOMETRIA BODY
// ─────────────────────────────────────────────────────────────────────────────
class _BiometricsBody extends StatelessWidget {
  final AppProvider p;
  final TextEditingController drugQueryCtrl;
  final bool drugPickerOpen;
  final List filteredDrugs;
  final ValueChanged<bool> onDrugPickerChanged;
  const _BiometricsBody({
    required this.p,
    required this.drugQueryCtrl,
    required this.drugPickerOpen,
    required this.filteredDrugs,
    required this.onDrugPickerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMale = p.patient.sex == 'M';
    return Column(children: [
      // Paciente + Limpar
      Row(children: [
        Expanded(child: _FieldRow(label: 'Paciente / Leito',
          child: MedInput(hintText: 'Ex: Leito 05', initialValue: p.patient.patientId,
            onChanged: (v) => p.updatePatient('patientId', v)))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => p.resetPatient(),
          child: Container(
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: Colors.white),
            child: const Text('Limpar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF555555))),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      // Idade + Sexo toggle
      Row(children: [
        Expanded(child: _FieldRow(label: p.t('age'),
          child: MedInput(hintText: '68', initialValue: p.patient.age,
            keyboardType: TextInputType.number, onChanged: (v) => p.updatePatient('age', v)))),
        const SizedBox(width: 10),
        Expanded(child: _FieldRow(
          label: p.t('sex'),
          child: GestureDetector(
            onTap: () => p.updatePatient('sex', isMale ? 'F' : 'M'),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
                color: Colors.white,
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMale ? const Color(0xFFDCEEFF) : const Color(0xFFFFE4F0),
                  ),
                  child: Center(child: Text(
                    isMale ? 'M' : 'F',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900,
                      color: isMale ? const Color(0xFF1565C0) : const Color(0xFFC2185B),
                    ),
                  )),
                ),
                const SizedBox(width: 8),
                Text(
                  isMale ? 'Masculino' : 'Feminino',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kDark),
                ),
                const Spacer(),
                Icon(Icons.swap_horiz_rounded, size: 15, color: Colors.grey[400]),
              ]),
            ),
          ),
        )),
      ]),
      const SizedBox(height: 10),
      // Peso + Altura
      Row(children: [
        Expanded(child: _FieldRow(label: 'Peso (kg)',
          child: MedInput(hintText: '78', initialValue: p.patient.weight,
            keyboardType: TextInputType.number, onChanged: (v) => p.updatePatient('weight', v)))),
        const SizedBox(width: 10),
        Expanded(child: _FieldRow(label: 'Altura (cm)',
          child: MedInput(hintText: '171', initialValue: p.patient.height,
            keyboardType: TextInputType.number, onChanged: (v) => p.updatePatient('height', v)))),
      ]),
      const SizedBox(height: 10),
      // Creatinina
      _FieldRow(label: p.t('creatinine'),
        child: MedInput(hintText: '1.0 mg/dL', initialValue: p.patient.creatinine,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => p.updatePatient('creatinine', v))),
      const SizedBox(height: 10),
      // Medicamentos em uso
      _FieldRow(
        label: 'Medicamentos em uso (opcional)',
        child: MedInput(
          hintText: 'Ex: AAS 100mg, Enalapril 10mg...',
          initialValue: p.patient.medications,
          maxLines: 3,
          onChanged: (v) => p.updatePatient('medications', v),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOSE BODY
// ─────────────────────────────────────────────────────────────────────────────
class _DoseBody extends StatelessWidget {
  final AppProvider p;
  final bool copied;
  final VoidCallback onCopy;
  final TextEditingController drugQueryCtrl;
  final bool drugPickerOpen;
  final List filteredDrugs;
  final ValueChanged<bool> onDrugPickerChanged;
  const _DoseBody({
    required this.p,
    required this.copied,
    required this.onCopy,
    required this.drugQueryCtrl,
    required this.drugPickerOpen,
    required this.filteredDrugs,
    required this.onDrugPickerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Drug picker sempre visível
      _FieldRow(
        label: 'Selecionar fármaco',
        child: Column(children: [
          MedInput(
            controller: drugQueryCtrl,
            hintText: 'Buscar fármaco...',
            onChanged: (v) => onDrugPickerChanged(v.isNotEmpty),
          ),
          if (drugPickerOpen && filteredDrugs.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
              ),
              child: Column(children: filteredDrugs.map((d) => ListTile(
                dense: true,
                title: Text(d.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                subtitle: Text('${p.tDB(d.className)} · ${d.route}', style: const TextStyle(fontSize: 11)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Usar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
                ),
                onTap: () {
                  p.addDrug(d.id);
                  drugQueryCtrl.clear();
                  onDrugPickerChanged(false);
                },
              )).toList()),
            ),
        ]),
      ),

      if (p.selectedDrugs.isEmpty) ...[
        const SizedBox(height: 20),
        Center(child: Column(children: [
          Icon(Icons.medication_outlined, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text('Nenhum fármaco selecionado', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Busque e selecione um fármaco acima', style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
        ])),
        const SizedBox(height: 16),
      ] else ...[
        const SizedBox(height: 14),
        // Métricas mini
        Row(children: [
          Expanded(child: _MiniStat(label: 'Peso', value: p.patient.weight.isNotEmpty ? '${p.patient.weight} kg' : '—')),
          const SizedBox(width: 6),
          Expanded(child: _MiniStat(label: 'Altura', value: p.patient.height.isNotEmpty ? '${p.patient.height} cm' : '—')),
          const SizedBox(width: 6),
          Expanded(child: _MiniStat(label: 'ClCr', value: '${p.clcr ?? '—'} mL/min')),
        ]),
        const SizedBox(height: 14),

        // Cards de fármaco
        ...p.selectedDrugs.map((drug) {
          final dose = p.calculateDose(drug);
          return _DrugDoseCard(drug: drug, dose: dose, p: p);
        }),


        // Interações
        if (p.interactionRisks.isNotEmpty) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFFFFF0F0), border: Border.all(color: const Color(0xFFFFCCCC))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.warning_rounded, size: 14, color: Color(0xFFCC2222)),
              SizedBox(width: 6),
              Text('Interações detectadas', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFFCC2222))),
            ]),
            const SizedBox(height: 6),
            ...p.interactionRisks.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $r', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFCC2222), height: 1.4)),
            )),
          ]),
        ),
          const SizedBox(height: 10),
        ] else ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFBBF7D0))),
          child: const Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF065F46)),
            SizedBox(width: 6),
            Expanded(child: Text('Sem interação crítica detectada na base local.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)))),
          ]),
        ),
          const SizedBox(height: 10),
        ],

        // Info do fármaco ativo
        _DrugSafetyPanel(p: p),
        const SizedBox(height: 14),

        // Botão copiar
        GestureDetector(
          onTap: onCopy,
          child: Container(
            width: double.infinity, height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: copied ? const Color(0xFFECFDF5) : kDark,
              border: copied ? Border.all(color: const Color(0xFF86EFAC)) : null,
              boxShadow: copied ? null : [BoxShadow(color: kDark.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Center(child: Text(
              copied ? 'Copiado para prontuário!' : 'Copiar para prontuário',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: copied ? const Color(0xFF065F46) : kGoldLight),
            )),
          ),
        ),
      ],
    ]);
  }
}

class _DrugDoseCard extends StatelessWidget {
  final drug;
  final dose;
  final AppProvider p;
  const _DrugDoseCard({required this.drug, required this.dose, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
        color: Colors.white,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.tDB(drug.category)} • ${drug.route}',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGold, letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text(drug.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3, color: kDark), overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: () => p.setActiveDrug(drug.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(20)),
                child: const Text('principal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => p.removeDrug(drug.id),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFF0F0), border: Border.all(color: const Color(0xFFFFCCCC))),
                child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFFCC2222)),
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
            const Text('DOSE CALCULADA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 1.4)),
            const SizedBox(height: 4),
            Text(dose.main, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
            const SizedBox(height: 5),
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
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: kSurface, border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFF888888))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kDark)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROTOCOLOS BODY
// ─────────────────────────────────────────────────────────────────────────────
class _ProtocolsBody extends StatelessWidget {
  final AppProvider p;
  final Function(String) openProtocol;
  const _ProtocolsBody({required this.p, required this.openProtocol});

  @override
  Widget build(BuildContext context) {
    final protos = p.protocolsDB.take(8).toList();
    return Column(children: protos.map((proto) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => openProtocol(proto.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
            color: kSurface,
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.tDB(proto.severity), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGold, letterSpacing: 1.4)),
              const SizedBox(height: 2),
              Text(p.tDB(proto.title), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kDark), overflow: TextOverflow.ellipsis),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF888888)),
          ]),
        ),
      ),
    )).toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAFETY STATUS
// ─────────────────────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: warning ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.12),
        border: Border.all(color: warning ? Colors.amber.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(warning ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
          size: 15, color: warning ? Colors.amber[300] : Colors.green[300]),
        const SizedBox(width: 8),
        Expanded(child: Text(
          renalRisk
            ? 'ClCr reduzido — revisar doses e nefrotóxicos'
            : 'Parâmetros estáveis — sem alerta renal crítico',
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRUG SAFETY PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _DrugSafetyPanel extends StatelessWidget {
  final AppProvider p;
  const _DrugSafetyPanel({required this.p});

  @override
  Widget build(BuildContext context) {
    final drug = p.activeDrug;
    if (drug == null) return const SizedBox.shrink();
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
          const Text('EVENTOS ADVERSOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFFCC0000))),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: adverse.map((a) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Text(a, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFCC0000))),
          )).toList()),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD ROW
// ─────────────────────────────────────────────────────────────────────────────
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
