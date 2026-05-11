import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/drug_interaction_service.dart';
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

  // ── Lembrete de reavaliação ───────────────────────────────────────────────
  int? _reminderMinutes;      // null = sem lembrete ativo
  DateTime? _reminderAt;      // quando o lembrete foi definido
  bool _reminderExpired = false;

  void _setReminder(int minutes) {
    setState(() {
      _reminderMinutes = minutes;
      _reminderAt = DateTime.now();
      _reminderExpired = false;
    });
    // Dispara callback após o tempo escolhido
    Future.delayed(Duration(minutes: minutes), () {
      if (mounted && _reminderMinutes == minutes &&
          _reminderAt != null &&
          DateTime.now().difference(_reminderAt!).inMinutes >= minutes) {
        setState(() => _reminderExpired = true);
      }
    });
  }

  void _cancelReminder() {
    setState(() {
      _reminderMinutes = null;
      _reminderAt = null;
      _reminderExpired = false;
    });
  }

  @override
  void dispose() {
    _drugQueryCtrl.dispose();
    _calcDrugQueryCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(AppProvider p) async {
    final buf = StringBuffer();
    buf.writeln('=== MEDCASES PRO: RESUMO CLÍNICO ===');
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
      if (p.patient.age.isNotEmpty) '${p.patient.age} ${p.t("years")}',
      if (p.patient.weight.isNotEmpty) '${p.patient.weight} kg',
      p.patient.sex == 'M' ? p.t('male') : p.t('female'),
    ].join(' · ');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
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
          title: p.t('patient_data'),
          subtitle: bioSubtitle.isEmpty ? p.t('tap_to_fill') : bioSubtitle,
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
          title: p.t('dose_calc'),
          subtitle: p.selectedDrugs.isEmpty
              ? p.t('no_drug_selected')
              : '${p.selectedDrugs.length} ${p.t('drug_active')}${p.selectedDrugs.length > 1 ? 's' : ''}',

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
          title: p.t('emergency_protocols'),
          subtitle: p.t('quick_access_protocols'),
          isOpen: _protOpen,
          onToggle: () => setState(() => _protOpen = !_protOpen),
          child: _ProtocolsBody(p: p, openProtocol: widget.openProtocol),
        ),
        const SizedBox(height: 10),

        // ── LEMBRETE DE REAVALIAÇÃO ──────────────────────────────────────────
        _ReminderCard(
          p: p,
          reminderMinutes: _reminderMinutes,
          reminderAt: _reminderAt,
          reminderExpired: _reminderExpired,
          onSet: _setReminder,
          onCancel: _cancelReminder,
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
            Text(p.lang == 'es' ? 'RESUMEN CLÍNICO' : 'RESUMO CLÍNICO', style: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w900,
              color: Color(0xBFFFE8A6), letterSpacing: 2.5,
            )),
            const SizedBox(height: 4),
            Text(
              p.patient.patientId.isNotEmpty ? p.patient.patientId : p.t('patient_bed'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
              overflow: TextOverflow.ellipsis,
            ),
          ])),
          // SOS badge
          _SosBadge(),
        ]),
        const SizedBox(height: 14),
        // Safety status inline
        _SafetyStatus(clcr: p.clcr, doseAlerts: p.activeDrug != null ? p.calculateDose(p.activeDrug!).alerts : [], lang: p.lang),
        const SizedBox(height: 14),
        // Quick access chips
        Text(p.lang == 'es' ? 'ACCESO INMEDIATO' : 'ACESSO IMEDIATO', style: const TextStyle(
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
              (p.lang == 'es' ? 'ACV' : 'AVC', 'avc_isquemico'),
              (p.lang == 'es' ? 'Sepsis' : 'Sepse', 'sepse'),
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
        color: alert ? const Color(0xFFFFF8E6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert ? const Color(0xFFFFD580) : const Color(0xFFE5E7EB),
          width: alert ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [
          // Header clicável
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
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
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF888888), size: 22),
                ),
              ]),
            ),
          ),
          // Conteúdo animado
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(children: [
              Divider(height: 1, color: kBorder),
              Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: child),
            ]),
            crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BIOMETRIA BODY
// ─────────────────────────────────────────────────────────────────────────────
class _BiometricsBody extends StatefulWidget {
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
  State<_BiometricsBody> createState() => _BiometricsBodyState();
}

class _BiometricsBodyState extends State<_BiometricsBody> {
  // Controllers próprios — únicas fontes de verdade para os TextFields.
  // Necessário porque initialValue num TextField só é aplicado na primeira
  // montagem; ao chamar resetPatient() + notifyListeners() o widget reconstrói
  // mas o TextField já montado ignora o novo initialValue, mantendo o texto
  // antigo na tela. Com controllers explícitos conseguimos fazer .clear()
  // quando o provider zerar o PatientData.
  late final TextEditingController _idCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _creatCtrl;
  late final TextEditingController _medsCtrl;

  // Rastrea a "versão" do patient para detectar reset externo
  String _lastPatientSnapshot = '';

  @override
  void initState() {
    super.initState();
    final pt = widget.p.patient;
    _idCtrl     = TextEditingController(text: pt.patientId);
    _ageCtrl    = TextEditingController(text: pt.age);
    _weightCtrl = TextEditingController(text: pt.weight);
    _heightCtrl = TextEditingController(text: pt.height);
    _creatCtrl  = TextEditingController(text: pt.creatinine);
    _medsCtrl   = TextEditingController(text: pt.medications);
    _lastPatientSnapshot = _snapshot(pt);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _creatCtrl.dispose();
    _medsCtrl.dispose();
    super.dispose();
  }

  // Snapshot simples para detectar reset: concatena todos os campos
  String _snapshot(dynamic pt) =>
      '${pt.patientId}|${pt.age}|${pt.weight}|${pt.height}|${pt.creatinine}|${pt.medications}';

  // Chamado a cada rebuild (provider mudou). Se o snapshot virou tudo vazio
  // (resetPatient()), limpa os controllers para refletir na tela.
  void _syncControllersIfReset() {
    final pt = widget.p.patient;
    final snap = _snapshot(pt);
    if (snap == _lastPatientSnapshot) return; // nada mudou
    _lastPatientSnapshot = snap;

    // Só aplica se o provider está vazio (reset) e o campo ainda tem texto
    // para não sobrescrever edições normais do usuário.
    if (pt.patientId.isEmpty   && _idCtrl.text.isNotEmpty)     _idCtrl.clear();
    if (pt.age.isEmpty         && _ageCtrl.text.isNotEmpty)     _ageCtrl.clear();
    if (pt.weight.isEmpty      && _weightCtrl.text.isNotEmpty)  _weightCtrl.clear();
    if (pt.height.isEmpty      && _heightCtrl.text.isNotEmpty)  _heightCtrl.clear();
    if (pt.creatinine.isEmpty  && _creatCtrl.text.isNotEmpty)   _creatCtrl.clear();
    if (pt.medications.isEmpty && _medsCtrl.text.isNotEmpty)    _medsCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    _syncControllersIfReset();
    final p = widget.p;
    final isMale = p.patient.sex == 'M';
    return Column(children: [
      // Paciente + Limpar
      Row(children: [
        Expanded(child: _FieldRow(label: p.t('patient_bed'),
          child: MedInput(controller: _idCtrl, hintText: p.t('hint_bed'),
            onChanged: (v) => p.updatePatient('patientId', v)))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => p.resetPatient(),
          child: Container(
            margin: const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: Colors.white),
            child: Text(p.t('clear'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF555555))),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      // Idade + Sexo toggle
      Row(children: [
        Expanded(child: _FieldRow(label: p.t('age'),
          child: MedInput(controller: _ageCtrl, hintText: '68',
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
                  isMale ? p.t('male') : p.t('female'),
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
        Expanded(child: _FieldRow(label: p.t('weight_kg'),
          child: MedInput(controller: _weightCtrl, hintText: '78',
            keyboardType: TextInputType.number, onChanged: (v) => p.updatePatient('weight', v)))),
        const SizedBox(width: 10),
        Expanded(child: _FieldRow(label: p.t('height_cm'),
          child: MedInput(controller: _heightCtrl, hintText: '171',
            keyboardType: TextInputType.number, onChanged: (v) => p.updatePatient('height', v)))),
      ]),
      const SizedBox(height: 10),
      // Creatinina
      _FieldRow(label: p.t('creatinine'),
        child: MedInput(controller: _creatCtrl, hintText: '1.0 mg/dL',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => p.updatePatient('creatinine', v))),
      const SizedBox(height: 10),
      // Medicamentos em uso
      _FieldRow(
        label: p.t('medications_optional'),
        child: MedInput(
          controller: _medsCtrl,
          hintText: p.t('hint_meds'),
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
        label: p.t('select_drug'),
        child: Column(children: [
          MedInput(
            controller: drugQueryCtrl,
            hintText: p.t('search_drug_hint'),
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
                  child: Text(p.t('use'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
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
          Text(p.t('no_drug_selected'), style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(p.t('search_add_above'), style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
        ])),
        const SizedBox(height: 16),
      ] else ...[
        const SizedBox(height: 14),
        // Métricas mini
        Row(children: [
          Expanded(child: _MiniStat(label: p.t('weight'), value: p.patient.weight.isNotEmpty ? '${p.patient.weight} kg' : '—')),
          const SizedBox(width: 6),
          Expanded(child: _MiniStat(label: p.t('height'), value: p.patient.height.isNotEmpty ? '${p.patient.height} cm' : '—')),
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
        _InteractionPanel(interactions: p.drugInteractions, hasMedications: p.patient.medications.isNotEmpty, lang: p.lang),
        const SizedBox(height: 10),

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
              copied ? p.t('copied_record') : p.t('copy_record'),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
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
                child: Text(p.t('set_main'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
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
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kDark, Color(0xFF123326), kGreen]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.t('calculated_dose'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 1.4)),
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
  final String lang;
  const _SafetyStatus({this.clcr, required this.doseAlerts, required this.lang});

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
            ? (lang == 'es' ? 'ClCr reducido — revisar dosis y nefrotóxicos' : 'ClCr reduzido — revisar doses e nefrotóxicos')
            : (lang == 'es' ? 'Parámetros estables — sin alerta renal crítica' : 'Parâmetros estáveis — sem alerta renal crítico'),
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
          Text(p.lang == 'es' ? 'EVENTOS ADVERSOS' : 'EVENTOS ADVERSOS', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFFCC0000))),
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

// ─────────────────────────────────────────────────────────────────────────────
// PAINEL DE INTERAÇÕES MEDICAMENTOSAS
// ─────────────────────────────────────────────────────────────────────────────
class _InteractionPanel extends StatefulWidget {
  final List<DrugInteraction> interactions;
  final bool hasMedications;
  final String lang;
  const _InteractionPanel({required this.interactions, required this.hasMedications, required this.lang});

  @override
  State<_InteractionPanel> createState() => _InteractionPanelState();
}

class _InteractionPanelState extends State<_InteractionPanel> {
  final _expanded = <int>{};

  Color _severityColor(InteractionSeverity s) {
    switch (s) {
      case InteractionSeverity.contraindicated: return const Color(0xFF7F1D1D);
      case InteractionSeverity.major:           return const Color(0xFFCC2222);
      case InteractionSeverity.moderate:        return const Color(0xFFD97706);
      case InteractionSeverity.minor:           return const Color(0xFF065F46);
    }
  }

  Color _severityBg(InteractionSeverity s) {
    switch (s) {
      case InteractionSeverity.contraindicated: return const Color(0xFFFEF2F2);
      case InteractionSeverity.major:           return const Color(0xFFFFF0F0);
      case InteractionSeverity.moderate:        return const Color(0xFFFFFBEB);
      case InteractionSeverity.minor:           return const Color(0xFFECFDF5);
    }
  }

  Color _severityBorder(InteractionSeverity s) {
    switch (s) {
      case InteractionSeverity.contraindicated: return const Color(0xFFFCA5A5);
      case InteractionSeverity.major:           return const Color(0xFFFFCCCC);
      case InteractionSeverity.moderate:        return const Color(0xFFFCD34D);
      case InteractionSeverity.minor:           return const Color(0xFFBBF7D0);
    }
  }

  IconData _severityIcon(InteractionSeverity s) {
    switch (s) {
      case InteractionSeverity.contraindicated: return Icons.block_rounded;
      case InteractionSeverity.major:           return Icons.warning_rounded;
      case InteractionSeverity.moderate:        return Icons.info_rounded;
      case InteractionSeverity.minor:           return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final interactions = widget.interactions;

    if (interactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFECFDF5),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF065F46)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.lang == 'es' ? 'Sin interacciones detectadas' : 'Sem interações detectadas',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
            if (widget.hasMedications)
              Text(
                widget.lang == 'es' ? 'Verificado con los medicamentos del paciente' : 'Verificado contra medicamentos do paciente',
                style: const TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.w500))
            else
              Text(
                widget.lang == 'es'
                  ? 'Complete "Medicamentos en uso" para verificar con la medicación actual del paciente'
                  : 'Preencha "Medicamentos em uso" para verificar com a medicação atual do paciente',
                style: const TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.w500)),
          ])),
        ]),
      );
    }

    // Contagem por severidade
    final nContra   = interactions.where((i) => i.severity == InteractionSeverity.contraindicated).length;
    final nMajor    = interactions.where((i) => i.severity == InteractionSeverity.major).length;
    final nModerate = interactions.where((i) => i.severity == InteractionSeverity.moderate).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Cabeçalho do painel
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: nContra > 0 ? const Color(0xFFFEF2F2) : nMajor > 0 ? const Color(0xFFFFF0F0) : const Color(0xFFFFFBEB),
          border: Border.all(color: nContra > 0 ? const Color(0xFFFCA5A5) : nMajor > 0 ? const Color(0xFFFFCCCC) : const Color(0xFFFCD34D)),
        ),
        child: Row(children: [
          Icon(nContra > 0 ? Icons.block_rounded : Icons.warning_rounded,
            size: 16,
            color: nContra > 0 ? const Color(0xFF7F1D1D) : nMajor > 0 ? const Color(0xFFCC2222) : const Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.lang == 'es'
                ? '${interactions.length} interacci${interactions.length > 1 ? "ones" : "ón"} detectada${interactions.length > 1 ? "s" : ""}'
                : '${interactions.length} interaç${interactions.length > 1 ? "ões" : "ão"} detectada${interactions.length > 1 ? "s" : ""}',
              
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                color: nContra > 0 ? const Color(0xFF7F1D1D) : nMajor > 0 ? const Color(0xFFCC2222) : const Color(0xFFD97706)),
            ),
            Row(children: [
              if (nContra > 0) _SeverityBadge(widget.lang == 'es' ? '$nContra contraindicada${nContra > 1 ? "s" : ""}' : '$nContra contraindicada${nContra > 1 ? "s" : ""}', const Color(0xFF7F1D1D)),
              if (nContra > 0 && nMajor > 0) const SizedBox(width: 4),
              if (nMajor > 0) _SeverityBadge(widget.lang == 'es' ? '$nMajor mayor${nMajor > 1 ? "es" : ""}' : '$nMajor maior${nMajor > 1 ? "es" : ""}', const Color(0xFFCC2222)),
              if ((nContra > 0 || nMajor > 0) && nModerate > 0) const SizedBox(width: 4),
              if (nModerate > 0) _SeverityBadge(widget.lang == 'es' ? '$nModerate moderada${nModerate > 1 ? "s" : ""}' : '$nModerate moderada${nModerate > 1 ? "s" : ""}', const Color(0xFFD97706)),
            ]),
            if (widget.hasMedications)
              Text(
                widget.lang == 'es' ? 'Incluye medicamentos del paciente' : 'Incluindo medicamentos do paciente',
                style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
          ])),
        ]),
      ),
      const SizedBox(height: 6),

      // Cards de cada interação
      ...interactions.asMap().entries.map((entry) {
        final i = entry.key;
        final ix = entry.value;
        final isOpen = _expanded.contains(i);
        final col = _severityColor(ix.severity);
        final bg = _severityBg(ix.severity);
        final border = _severityBorder(ix.severity);

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GestureDetector(
            onTap: () => setState(() => isOpen ? _expanded.remove(i) : _expanded.add(i)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: bg,
                border: Border.all(color: border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Linha do cabeçalho (sempre visível)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Row(children: [
                    Icon(_severityIcon(ix.severity), size: 13, color: col),
                    const SizedBox(width: 6),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${ix.drug1}  +  ${ix.drug2}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: col, height: 1.3)),
                      Text(ix.severityLabel,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: col.withValues(alpha: 0.75), letterSpacing: 0.8)),
                    ])),
                    Icon(isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: col.withValues(alpha: 0.6)),
                  ]),
                ),

                // Detalhes expandíveis
                if (isOpen) ...[
                  Divider(height: 1, color: border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Efeito clínico
                      _IxRow(Icons.bolt_rounded, widget.lang == 'es' ? 'EFECTO CLÍNICO' : 'EFEITO CLÍNICO', ix.effect, col),
                      const SizedBox(height: 8),
                      // Mecanismo
                      _IxRow(Icons.biotech_rounded, 'MECANISMO', ix.mechanism, col),
                      const SizedBox(height: 8),
                      // Conduta
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(alpha: 0.7),
                          border: Border.all(color: border),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.medical_services_rounded, size: 11, color: col),
                            const SizedBox(width: 5),
                            Text(widget.lang == 'es' ? 'CONDUCTA' : 'CONDUTA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: col, letterSpacing: 0.8)),
                          ]),
                          const SizedBox(height: 4),
                          Text(ix.management, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col, height: 1.5)),
                        ]),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        );
      }),
    ]);
  }
}

class _SeverityBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SeverityBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color)),
    );
  }
}

class _IxRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color color;
  const _IxRow(this.icon, this.label, this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
      ),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color.withValues(alpha: 0.7), letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF333333), height: 1.45)),
      ])),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REMINDER CARD — Lembrete de reavaliação do paciente
// ─────────────────────────────────────────────────────────────────────────────
class _ReminderCard extends StatefulWidget {
  final AppProvider p;
  final int? reminderMinutes;
  final DateTime? reminderAt;
  final bool reminderExpired;
  final void Function(int) onSet;
  final VoidCallback onCancel;
  const _ReminderCard({
    required this.p,
    required this.reminderMinutes,
    required this.reminderAt,
    required this.reminderExpired,
    required this.onSet,
    required this.onCancel,
  });
  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard>
    with SingleTickerProviderStateMixin {
  // Ticker para atualizar o contador a cada 30 segundos
  late final Stream<int> _ticker;

  // Flash visual ao expirar — anima a borda e o fundo do card
  late final AnimationController _flashCtrl;
  late final Animation<double> _flashAnim;
  bool _wasExpired = false;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(seconds: 30), (i) => i);

    // 4 pulsos de 500ms cada
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flashAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_ReminderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detecta transição para "expirado" e dispara o flash
    if (widget.reminderExpired && !_wasExpired) {
      _wasExpired = true;
      _triggerFlash();
    } else if (!widget.reminderExpired) {
      _wasExpired = false;
      _flashCtrl.reset();
    }
  }

  Future<void> _triggerFlash() async {
    for (int i = 0; i < 4; i++) {
      if (!mounted) return;
      await _flashCtrl.forward();
      if (!mounted) return;
      await _flashCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  String _remaining() {
    if (widget.reminderAt == null || widget.reminderMinutes == null) return '';
    final elapsed = DateTime.now().difference(widget.reminderAt!).inSeconds;
    final totalSec = widget.reminderMinutes! * 60;
    final left = totalSec - elapsed;
    if (left <= 0) return '0 ${widget.p.t("reminder_minutes")}';
    final m = (left ~/ 60);
    final s = left % 60;
    return m > 0 ? '$m ${widget.p.t("reminder_minutes")}' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final hasReminder = widget.reminderMinutes != null;
    final expired = widget.reminderExpired;

    // Conteúdo interno do card (estático — não reconstruído pelo AnimatedBuilder)
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + ícone
        Row(children: [
          Icon(
            expired
                ? Icons.alarm_off_rounded
                : hasReminder
                    ? Icons.alarm_on_rounded
                    : Icons.alarm_add_rounded,
            size: 16,
            color: expired
                ? const Color(0xFFCC2222)
                : hasReminder
                    ? const Color(0xFF065F46)
                    : const Color(0xFF888888),
          ),
          const SizedBox(width: 6),
          Text(
            expired
                ? p.t('reminder_expired')
                : hasReminder
                    ? p.t('reminder_active')
                    : p.t('reminder_label'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: expired
                  ? const Color(0xFFCC2222)
                  : hasReminder
                      ? const Color(0xFF065F46)
                      : const Color(0xFF888888),
              letterSpacing: 0.2,
            ),
          ),
          if (hasReminder && !expired) ...[
            const Spacer(),
            StreamBuilder<int>(
              stream: _ticker,
              builder: (context, _) => Text(
                _remaining(),
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900,
                  color: Color(0xFF065F46),
                ),
              ),
            ),
          ],
        ]),

        // Botões de tempo (quando sem lembrete ativo)
        if (!hasReminder) ...[
          const SizedBox(height: 10),
          Row(children: [
            for (final min in [5, 10, 15, 30, 60]) ...[
              if (min != 5) const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onSet(min),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: kDark,
                    ),
                    child: Center(
                      child: Text(
                        min >= 60 ? '1h' : '${min}m',
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w900,
                          color: kGoldLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ],

        // Botão cancelar (quando há lembrete ativo)
        if (hasReminder) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: widget.onCancel,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
                color: Colors.white,
              ),
              child: Center(
                child: Text(
                  p.t('reminder_cancel'),
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    // AnimatedBuilder anima apenas a decoração do container (flash de borda)
    return AnimatedBuilder(
      animation: _flashCtrl,
      builder: (context, child) {
        final flashVal = _flashAnim.value;
        final bgColor = expired
            ? Color.lerp(
                const Color(0xFFFFF0F0),
                const Color(0xFFFFDDDD),
                flashVal,
              )!
            : hasReminder
                ? const Color(0xFFECFDF5)
                : Colors.transparent;

        final borderColor = expired
            ? Color.lerp(
                const Color(0xFFFF8888),
                const Color(0xFFCC0000),
                flashVal,
              )!
            : hasReminder
                ? const Color(0xFF075f45)
                : Colors.transparent;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              left: BorderSide(
                color: borderColor,
                width: expired ? 4.0 + flashVal * 2 : 3,
              ),
            ),
            boxShadow: expired && flashVal > 0.4
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF4444)
                          .withValues(alpha: flashVal * 0.25),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: cardContent,
    );
  }
}
