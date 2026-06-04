// meu_plantao_dashboard.dart — v3
// Feature "Meu Plantão / Mi Guardia"
//
// NOVIDADES v3:
//   • Seção colapsável: quando vazia, aparece fechada (só cabeçalho clicável)
//   • 3 sub-seções com hierarquia clara: PACIENTES · FÁRMACOS · CALCULADORAS
//   • Cards de paciente: quarto, nome, diagnóstico, tratamento, notas
//   • Sheet de edição de paciente com todos os campos
//   • Long-press para remover qualquer item
//   • Botão "+" flutuante dentro do cabeçalho para abrir o manage sheet

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/drug_model.dart';
import '../widgets/common_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE ATALHO DE CALCULADORA
// ─────────────────────────────────────────────────────────────────────────────

class CalcShortcut {
  final String id;
  final String labelPt;
  final String labelEs;
  final IconData icon;
  final Color color;

  const CalcShortcut({
    required this.id,
    required this.labelPt,
    required this.labelEs,
    required this.icon,
    required this.color,
  });

  String label(bool isEs) => isEs ? labelEs : labelPt;
}

const List<CalcShortcut> kAvailableCalcs = [
  CalcShortcut(id: 'calc_biometria',   labelPt: 'Biometria',     labelEs: 'Biometría',      icon: Icons.monitor_weight_outlined,   color: Color(0xFF3B82F6)),
  CalcShortcut(id: 'calc_scores',      labelPt: 'Scores',        labelEs: 'Scores',         icon: Icons.bar_chart_rounded,         color: Color(0xFF8B5CF6)),
  CalcShortcut(id: 'calc_cardio',      labelPt: 'Cardio',        labelEs: 'Cardio',         icon: Icons.favorite_outline_rounded,  color: Color(0xFFEF4444)),
  CalcShortcut(id: 'calc_eletrólitos', labelPt: 'Eletrólitos',   labelEs: 'Electrolitos',   icon: Icons.science_outlined,          color: Color(0xFFF59E0B)),
  CalcShortcut(id: 'calc_infusao',     labelPt: 'Infusão EV',    labelEs: 'Infusión EV',    icon: Icons.water_drop_outlined,       color: Color(0xFF06B6D4)),
  CalcShortcut(id: 'calc_referencia',  labelPt: 'Referência',    labelEs: 'Referencia',     icon: Icons.menu_book_outlined,        color: Color(0xFF10B981)),
  CalcShortcut(id: 'calc_prescricoes', labelPt: 'Prescrições',   labelEs: 'Prescripciones', icon: Icons.receipt_long_outlined,     color: Color(0xFFC5A365)),
  CalcShortcut(id: 'calc_pediatria',   labelPt: 'Pediatria',     labelEs: 'Pediatría',      icon: Icons.child_care_outlined,       color: Color(0xFFEC4899)),
];

CalcShortcut? calcById(String id) {
  try { return kAvailableCalcs.firstWhere((c) => c.id == id); } catch (_) { return null; }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL — colapsável
// ─────────────────────────────────────────────────────────────────────────────

class MeuPlantaoDashboard extends StatefulWidget {
  final void Function(DrugModel drug) onOpenDrug;
  final void Function(String calcId) onOpenCalc;
  final void Function() onManageTap;

  const MeuPlantaoDashboard({
    super.key,
    required this.onOpenDrug,
    required this.onOpenCalc,
    required this.onManageTap,
  });

  @override
  State<MeuPlantaoDashboard> createState() => _MeuPlantaoDashboardState();
}

class _MeuPlantaoDashboardState extends State<MeuPlantaoDashboard>
    with SingleTickerProviderStateMixin {
  bool _expanded = true; // começa expandido se tiver conteúdo, fechado se vazio
  late AnimationController _chevronCtrl;
  late Animation<double> _chevronAngle;

  @override
  void initState() {
    super.initState();
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // 1 = expandido
    );
    _chevronAngle = Tween<double>(begin: 0.0, end: 0.5)
        .animate(CurvedAnimation(parent: _chevronCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _chevronCtrl.dispose();
    super.dispose();
  }

  void _toggle(bool hasContent) {
    AppHaptics.selection(context);
    if (!hasContent) {
      // Se vazio, tap abre o manage sheet
      widget.onManageTap();
      return;
    }
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _chevronCtrl.forward();
    } else {
      _chevronCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final c = AppColors.of(context);
    final isEs = p.lang == 'es';

    final hasPatients = p.plantaoPatients.isNotEmpty;
    final hasDrugs    = p.pinnedDrugs.isNotEmpty;
    final hasCalcs    = p.pinnedCalcIds.isNotEmpty;
    final isEmpty = !hasPatients && !hasDrugs && !hasCalcs;

    // Auto-colapsa quando vazio, expande quando há conteúdo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isEmpty && _expanded) setState(() => _expanded = false);
      if (!isEmpty && !_expanded) {
        // Não forçar expansão — deixar o usuário controlar
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho clicável ──────────────────────────────────────────────
        _PlantaoHeader(
          isEs: isEs,
          colors: c,
          expanded: _expanded,
          isEmpty: isEmpty,
          chevronAngle: _chevronAngle,
          onHeaderTap: () => _toggle(!isEmpty),
          onManageTap: widget.onManageTap,
          onAddPatient: () => _showPatientEditSheet(context, isEs, c, p),
        ),

        // ── Corpo animado ───────────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: isEmpty
                      ? _EmptyState(isEs: isEs, colors: c, onTap: widget.onManageTap)
                      : _PlantaoContent(
                          isEs: isEs,
                          colors: c,
                          p: p,
                          onOpenDrug: widget.onOpenDrug,
                          onOpenCalc: widget.onOpenCalc,
                          onAddPatient: () => _showPatientEditSheet(context, isEs, c, p),
                          onEditPatient: (pt) => _showPatientEditSheet(context, isEs, c, p, existing: pt),
                        ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showPatientEditSheet(
    BuildContext context,
    bool isEs,
    AppColors c,
    AppProvider p, {
    PlantaoPatient? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PatientEditSheet(
        isEs: isEs,
        existing: existing,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CABEÇALHO — com chevron e botões de ação
// ─────────────────────────────────────────────────────────────────────────────

class _PlantaoHeader extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final bool expanded;
  final bool isEmpty;
  final Animation<double> chevronAngle;
  final VoidCallback onHeaderTap;
  final VoidCallback onManageTap;
  final VoidCallback onAddPatient;

  const _PlantaoHeader({
    required this.isEs,
    required this.colors,
    required this.expanded,
    required this.isEmpty,
    required this.chevronAngle,
    required this.onHeaderTap,
    required this.onManageTap,
    required this.onAddPatient,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return GestureDetector(
      onTap: onHeaderTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          // ── Ícone com gradiente ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF075f45), Color(0xFF0F8A62)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF075f45).withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.local_hospital_outlined, size: 16, color: kGoldLight),
          ),
          const SizedBox(width: 10),

          // ── Títulos ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'MI GUARDIA' : 'MEU PLANTÃO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: c.gold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEmpty
                      ? (isEs ? 'Toca para personalizar tu guardia' : 'Toque para personalizar seu plantão')
                      : (isEs ? 'Pacientes · Fármacos · Calculadoras' : 'Pacientes · Fármacos · Calculadoras'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // ── Botão Paciente + ──────────────────────────────────────────────
          if (!isEmpty)
            GestureDetector(
              onTap: () {
                AppHaptics.selection(context);
                onAddPatient();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, size: 13, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 4),
                    Text(
                      isEs ? 'Paciente' : 'Paciente',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),
            ),

          // ── Botão Gestionar ───────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              AppHaptics.selection(context);
              onManageTap();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: c.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.green.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 13, color: c.green),
                  const SizedBox(width: 4),
                  Text(
                    isEs ? 'Gestionar' : 'Gerenciar',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.green),
                  ),
                ],
              ),
            ),
          ),

          // ── Chevron ───────────────────────────────────────────────────────
          RotationTransition(
            turns: chevronAngle,
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: c.textHint),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CORPO COM CONTEÚDO — 3 sub-seções
// ─────────────────────────────────────────────────────────────────────────────

class _PlantaoContent extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final AppProvider p;
  final void Function(DrugModel) onOpenDrug;
  final void Function(String) onOpenCalc;
  final VoidCallback onAddPatient;
  final void Function(PlantaoPatient) onEditPatient;

  const _PlantaoContent({
    required this.isEs,
    required this.colors,
    required this.p,
    required this.onOpenDrug,
    required this.onOpenCalc,
    required this.onAddPatient,
    required this.onEditPatient,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final hasPatients = p.plantaoPatients.isNotEmpty;
    final hasDrugs    = p.pinnedDrugs.isNotEmpty;
    // BUILD 93 — CALCULADORAS ocultas (Apple 1.4.1) — sempre false nesta seção
    // ignore: unused_local_variable
    const hasCalcs    = false; // p.pinnedCalcIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── PACIENTES ───────────────────────────────────────────────────────
        if (hasPatients) ...[
          _SectionLabel(
            icon: Icons.bed_outlined,
            label: isEs ? 'PACIENTES' : 'PACIENTES',
            colors: c,
            accent: const Color(0xFF3B82F6),
            trailing: GestureDetector(
              onTap: onAddPatient,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 11, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 3),
                    Text(
                      isEs ? 'Agregar' : 'Adicionar',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PatientsColumn(
            patients: p.plantaoPatients,
            isEs: isEs,
            colors: c,
            onEdit: onEditPatient,
            onRemove: (pt) {
              AppHaptics.medium(context);
              p.removePlantaoPatient(pt.id);
            },
          ),
          if (hasDrugs) const SizedBox(height: 20),
        ] else ...[
          // Empty patients row — botão de adicionar
          _AddFirstPatientRow(isEs: isEs, colors: c, onTap: onAddPatient),
          if (hasDrugs) const SizedBox(height: 20),
        ],

        // ── FÁRMACOS ────────────────────────────────────────────────────────
        if (hasDrugs) ...[
          _SectionLabel(icon: Icons.medication_outlined, label: isEs ? 'FÁRMACOS' : 'FÁRMACOS', colors: c),
          const SizedBox(height: 8),
          _PinnedDrugsRow(
            drugs: p.pinnedDrugs,
            isEs: isEs,
            colors: c,
            onTap: onOpenDrug,
            onUnpin: (drug) {
              AppHaptics.medium(context);
              p.unpinDrug(drug.id);
            },
          ),
          // BUILD 93: hasCalcs sempre false — espaço removido
        ],

        // BUILD 93 — CALCULADORAS ocultas do Mi Guardia (Apple Guideline 1.4.1)
        // Cálculos de dose e infusão disponíveis apenas na aba Ferramentas.
        // if (hasCalcs) ...[
        //   _SectionLabel(icon: Icons.calculate_outlined, label: 'CALCULADORAS', colors: c),
        //   const SizedBox(height: 8),
        //   _PinnedCalcsRow(calcIds: p.pinnedCalcIds, isEs: isEs, colors: c,
        //     onTap: onOpenCalc, onUnpin: (id) { p.unpinCalc(id); }),
        // ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LINHA "ADICIONAR PRIMEIRO PACIENTE"
// ─────────────────────────────────────────────────────────────────────────────

class _AddFirstPatientRow extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  const _AddFirstPatientRow({required this.isEs, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return GestureDetector(
      onTap: () { AppHaptics.selection(context); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.20), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'Agregar paciente al turno' : 'Adicionar paciente ao plantão',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEs ? 'Habitación, diagnóstico, tratamiento' : 'Quarto, diagnóstico, tratamento',
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLUNA DE PACIENTES
// ─────────────────────────────────────────────────────────────────────────────

class _PatientsColumn extends StatelessWidget {
  final List<PlantaoPatient> patients;
  final bool isEs;
  final AppColors colors;
  final void Function(PlantaoPatient) onEdit;
  final void Function(PlantaoPatient) onRemove;

  const _PatientsColumn({
    required this.patients,
    required this.isEs,
    required this.colors,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < patients.length; i++) ...[
          _PatientCard(
            patient: patients[i],
            isEs: isEs,
            colors: colors,
            onTap: () => onEdit(patients[i]),
            onRemove: () => onRemove(patients[i]),
          ),
          if (i < patients.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE PACIENTE
// ─────────────────────────────────────────────────────────────────────────────

class _PatientCard extends StatefulWidget {
  final PlantaoPatient patient;
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PatientCard({
    required this.patient,
    required this.isEs,
    required this.colors,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  bool _showRemove = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final pt = widget.patient;

    return GestureDetector(
      onTap: () {
        if (_showRemove) { setState(() => _showRemove = false); return; }
        AppHaptics.selection(context);
        widget.onTap();
      },
      onLongPress: () {
        AppHaptics.medium(context);
        setState(() => _showRemove = true);
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _showRemove
                ? AppColors.alertRedBg
                : c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showRemove
                  ? AppColors.alertRedBorder
                  : const Color(0xFF3B82F6).withValues(alpha: 0.22),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: c.dark ? 0.20 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _showRemove
              ? _RemoveConfirmRow(
                  isEs: widget.isEs,
                  colors: c,
                  label: pt.name.isNotEmpty ? pt.name : (widget.isEs ? 'este paciente' : 'este paciente'),
                  onConfirm: widget.onRemove,
                  onCancel: () => setState(() => _showRemove = false),
                )
              : _PatientCardContent(patient: pt, isEs: widget.isEs, colors: c),
        ),
      ),
    );
  }
}

class _PatientCardContent extends StatelessWidget {
  final PlantaoPatient patient;
  final bool isEs;
  final AppColors colors;

  const _PatientCardContent({required this.patient, required this.isEs, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final pt = patient;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ícone quarto ───────────────────────────────────────────────────
        Column(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bed_rounded, size: 20, color: Color(0xFF3B82F6)),
            ),
            if (pt.room.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pt.room,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF3B82F6)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 12),

        // ── Dados do paciente ──────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome
              if (pt.name.isNotEmpty)
                Text(
                  pt.name,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

              // Diagnóstico
              if (pt.diagnosis.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Dx: ' : 'Dx: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textHint),
                    ),
                    Expanded(
                      child: Text(
                        pt.diagnosis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Tratamento
              if (pt.treatment.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Tto: ' : 'Trat: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textHint),
                    ),
                    Expanded(
                      child: Text(
                        pt.treatment,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Notas
              if (pt.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pt.notes,
                    style: TextStyle(fontSize: 10.5, color: c.textHint, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Chevron editar ─────────────────────────────────────────────────
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, size: 16, color: colors.textHint),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM ROW — remove patient / unpin
// ─────────────────────────────────────────────────────────────────────────────

class _RemoveConfirmRow extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final String label;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _RemoveConfirmRow({
    required this.isEs,
    required this.colors,
    required this.label,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.alertRed),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isEs ? 'Eliminar $label?' : 'Remover $label?',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.alertRed),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onCancel,
          child: Text(
            isEs ? 'No' : 'Não',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: onConfirm,
          child: const Text(
            'OK',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.alertRed),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;

  const _EmptyState({required this.isEs, required this.colors, required this.onTap});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;

    return GestureDetector(
      onTap: () { AppHaptics.selection(context); widget.onTap(); },
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => CustomPaint(
          painter: _DashedBorderPainter(
            color: c.green.withValues(alpha: _pulseAnim.value * 0.4),
            radius: 16, dashWidth: 6, dashSpace: 5,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: c.green.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícones de hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HintChip(icon: Icons.bed_outlined, label: widget.isEs ? 'Pacientes' : 'Pacientes', color: const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _HintChip(icon: Icons.medication_outlined, label: widget.isEs ? 'Fármacos' : 'Fármacos', color: const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    _HintChip(icon: Icons.calculate_outlined, label: widget.isEs ? 'Calcs' : 'Calcs', color: const Color(0xFF8B5CF6)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c.green.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.green.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Icon(Icons.add_rounded, size: 22, color: c.green),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isEs ? 'Personaliza tu guardia' : 'Personalize seu plantão',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.3),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.isEs
                      ? 'Fija pacientes, fármacos y calculadoras\npara acceso inmediato en tu turno.'
                      : 'Fixe pacientes, fármacos e calculadoras\npara acesso imediato no plantão.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(color: c.green, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    widget.isEs ? 'Empezar →' : 'Começar →',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HintChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER — borda tracejada animada
// ─────────────────────────────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({required this.color, required this.radius, required this.dashWidth, required this.dashSpace});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.8..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final next = distance + (draw ? dashWidth : dashSpace);
        if (draw) canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// LABEL DE SEÇÃO
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors colors;
  final Color? accent;
  final Widget? trailing;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.colors,
    this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? colors.textHint;
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: color),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROW DE FÁRMACOS FIXADOS (scroll horizontal)
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedDrugsRow extends StatelessWidget {
  final List<DrugModel> drugs;
  final bool isEs;
  final AppColors colors;
  final void Function(DrugModel) onTap;
  final void Function(DrugModel) onUnpin;

  const _PinnedDrugsRow({required this.drugs, required this.isEs, required this.colors, required this.onTap, required this.onUnpin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: drugs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _DrugPinnedCard(
          drug: drugs[i], isEs: isEs, colors: colors,
          onTap: () => onTap(drugs[i]),
          onUnpin: () => onUnpin(drugs[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE FÁRMACO FIXADO
// ─────────────────────────────────────────────────────────────────────────────

class _DrugPinnedCard extends StatefulWidget {
  final DrugModel drug;
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const _DrugPinnedCard({required this.drug, required this.isEs, required this.colors, required this.onTap, required this.onUnpin});

  @override
  State<_DrugPinnedCard> createState() => _DrugPinnedCardState();
}

class _DrugPinnedCardState extends State<_DrugPinnedCard> {
  bool _pressed = false;
  bool _showUnpin = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final drug = widget.drug;
    final route = drug.route.toUpperCase();
    final className = (drug.className[widget.isEs ? 'es' : 'pt'] ?? drug.className['es'] ?? '');
    final classShort = className.length > 14 ? '${className.substring(0, 13)}…' : className;

    return GestureDetector(
      onTap: () {
        if (_showUnpin) { setState(() => _showUnpin = false); return; }
        AppHaptics.selection(context);
        widget.onTap();
      },
      onLongPress: () { AppHaptics.medium(context); setState(() => _showUnpin = !_showUnpin); },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 130,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _showUnpin ? AppColors.alertRedBg : c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _showUnpin ? AppColors.alertRedBorder : c.border, width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.dark ? 0.25 : 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: _showUnpin
              ? _UnpinOverlay(isEs: widget.isEs, colors: c, onConfirm: widget.onUnpin, onCancel: () => setState(() => _showUnpin = false))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: c.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(route.length > 8 ? route.substring(0, 8) : route,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.green, letterSpacing: 0.5)),
                    ),
                    const Spacer(),
                    Text(drug.nameL10n(widget.isEs ? 'es' : 'pt'), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text(classShort, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c.textHint)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY DE DESAFIXAR
// ─────────────────────────────────────────────────────────────────────────────

class _UnpinOverlay extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _UnpinOverlay({required this.isEs, required this.colors, required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.push_pin_outlined, size: 20, color: AppColors.alertRed),
        const SizedBox(height: 6),
        Text(isEs ? 'Desfijar?' : 'Desafixar?',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.alertRed)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(onTap: onCancel, child: Text(isEs ? 'No' : 'Não',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textSecondary))),
            const SizedBox(width: 16),
            GestureDetector(onTap: onConfirm, child: const Text('OK',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.alertRed))),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROW DE CALCULADORAS FIXADAS
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedCalcsRow extends StatelessWidget {
  final List<String> calcIds;
  final bool isEs;
  final AppColors colors;
  final void Function(String) onTap;
  final void Function(String) onUnpin;

  const _PinnedCalcsRow({required this.calcIds, required this.isEs, required this.colors, required this.onTap, required this.onUnpin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: calcIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final shortcut = calcById(calcIds[i]);
          if (shortcut == null) return const SizedBox.shrink();
          return _CalcPinnedCard(
            shortcut: shortcut, isEs: isEs, colors: colors,
            onTap: () => onTap(shortcut.id),
            onUnpin: () => onUnpin(shortcut.id),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE CALCULADORA FIXADA
// ─────────────────────────────────────────────────────────────────────────────

class _CalcPinnedCard extends StatefulWidget {
  final CalcShortcut shortcut;
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const _CalcPinnedCard({required this.shortcut, required this.isEs, required this.colors, required this.onTap, required this.onUnpin});

  @override
  State<_CalcPinnedCard> createState() => _CalcPinnedCardState();
}

class _CalcPinnedCardState extends State<_CalcPinnedCard> {
  bool _pressed = false;
  bool _showUnpin = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final s = widget.shortcut;

    return GestureDetector(
      onTap: () {
        if (_showUnpin) { setState(() => _showUnpin = false); return; }
        AppHaptics.selection(context);
        widget.onTap();
      },
      onLongPress: () { AppHaptics.medium(context); setState(() => _showUnpin = !_showUnpin); },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _showUnpin ? AppColors.alertRedBg : c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _showUnpin ? AppColors.alertRedBorder : c.border, width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.dark ? 0.25 : 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: _showUnpin
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.alertRed),
                    const SizedBox(height: 4),
                    GestureDetector(onTap: widget.onUnpin, child: const Text('OK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.alertRed))),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Icon(s.icon, size: 16, color: s.color),
                    ),
                    Text(s.label(widget.isEs), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.2)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET DE EDIÇÃO DE PACIENTE
// ─────────────────────────────────────────────────────────────────────────────

class _PatientEditSheet extends StatefulWidget {
  final bool isEs;
  final PlantaoPatient? existing;

  const _PatientEditSheet({required this.isEs, this.existing});

  @override
  State<_PatientEditSheet> createState() => _PatientEditSheetState();
}

class _PatientEditSheetState extends State<_PatientEditSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _roomCtrl;
  late TextEditingController _dxCtrl;
  late TextEditingController _ttoCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final pt = widget.existing;
    _nameCtrl  = TextEditingController(text: pt?.name ?? '');
    _roomCtrl  = TextEditingController(text: pt?.room ?? '');
    _dxCtrl    = TextEditingController(text: pt?.diagnosis ?? '');
    _ttoCtrl   = TextEditingController(text: pt?.treatment ?? '');
    _notesCtrl = TextEditingController(text: pt?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _roomCtrl.dispose(); _dxCtrl.dispose();
    _ttoCtrl.dispose();  _notesCtrl.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final p = context.read<AppProvider>();
    final isEdit = widget.existing != null;

    final patient = PlantaoPatient(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      room: _roomCtrl.text.trim(),
      diagnosis: _dxCtrl.text.trim(),
      treatment: _ttoCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      savedAt: widget.existing?.savedAt ?? DateTime.now(),
    );

    if (patient.name.isEmpty && patient.room.isEmpty && patient.diagnosis.isEmpty) {
      Navigator.pop(context);
      return;
    }

    p.savePlantaoPatient(patient);
    AppHaptics.medium(context);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        isEdit
            ? (widget.isEs ? 'Paciente actualizado.' : 'Paciente atualizado.')
            : (widget.isEs ? 'Paciente agregado al turno.' : 'Paciente adicionado ao plantão.'),
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isEs = widget.isEs;
    final screenH = MediaQuery.of(context).size.height;
    final isEdit = widget.existing != null;

    return SizedBox(
      height: screenH * 0.90,
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // ── Título ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bed_rounded, size: 18, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit
                              ? (isEs ? 'Editar Paciente' : 'Editar Paciente')
                              : (isEs ? 'Nuevo Paciente en Turno' : 'Novo Paciente no Plantão'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.3),
                        ),
                        Text(
                          isEs ? 'Presione guardar para fijar en el turno' : 'Pressione salvar para fixar no plantão',
                          style: TextStyle(fontSize: 11, color: c.textHint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Formulário ──────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome + Quarto (lado a lado)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _FieldBlock(
                            label: isEs ? 'Nombre del paciente' : 'Nome do paciente',
                            icon: Icons.person_outline_rounded,
                            controller: _nameCtrl,
                            hint: isEs ? 'Ej: Juan Pérez' : 'Ex: João Silva',
                            colors: c,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _FieldBlock(
                            label: isEs ? 'Habitación / Cama' : 'Quarto / Leito',
                            icon: Icons.bed_outlined,
                            controller: _roomCtrl,
                            hint: '204-A',
                            colors: c,
                            maxLines: 1,
                            accent: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Diagnóstico
                    _FieldBlock(
                      label: isEs ? 'Diagnóstico principal' : 'Diagnóstico principal',
                      icon: Icons.medical_information_outlined,
                      controller: _dxCtrl,
                      hint: isEs ? 'Ej: Neumonía adquirida en la comunidad' : 'Ex: Pneumonia adquirida na comunidade',
                      colors: c,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // Tratamento
                    _FieldBlock(
                      label: isEs ? 'Tratamiento / medicamentos' : 'Tratamento / medicamentos',
                      icon: Icons.medication_outlined,
                      controller: _ttoCtrl,
                      hint: isEs ? 'Ej: Amoxicilina 875mg 12/12h + O2 2L/min' : 'Ex: Amoxicilina 875mg 12/12h + O2 2L/min',
                      colors: c,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // Notas
                    _FieldBlock(
                      label: isEs ? 'Notas del turno' : 'Notas do plantão',
                      icon: Icons.notes_rounded,
                      controller: _notesCtrl,
                      hint: isEs ? 'Evolución, pendientes, alertas…' : 'Evolução, pendências, alertas…',
                      colors: c,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Botões
                    Row(
                      children: [
                        if (isEdit) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                AppHaptics.medium(context);
                                context.read<AppProvider>().removePlantaoPatient(widget.existing!.id);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.alertRedBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.alertRedBorder),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.alertRed),
                                    SizedBox(width: 6),
                                    Text('Remover', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.alertRed)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () => _save(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF075f45), Color(0xFF0F8A62)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF075f45).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save_outlined, size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    isEs ? 'Guardar en turno' : 'Salvar no plantão',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMPO DO FORMULÁRIO
// ─────────────────────────────────────────────────────────────────────────────

class _FieldBlock extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final AppColors colors;
  final int maxLines;
  final Color? accent;

  const _FieldBlock({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    required this.colors,
    required this.maxLines,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final ac = accent ?? c.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: ac),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac, letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: 1,
          style: TextStyle(fontSize: 13.5, color: c.textPrimary, height: 1.4),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12.5, color: c.textHint),
            filled: true,
            fillColor: c.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ac.withValues(alpha: 0.50), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET DE GERENCIAMENTO — abre via showPlantaoManageSheet()
// ─────────────────────────────────────────────────────────────────────────────

void showPlantaoManageSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PlantaoManageSheet(),
  );
}

class _PlantaoManageSheet extends StatefulWidget {
  const _PlantaoManageSheet();

  @override
  State<_PlantaoManageSheet> createState() => _PlantaoManageSheetState();
}

class _PlantaoManageSheetState extends State<_PlantaoManageSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final c = AppColors.of(context);
    final isEs = p.lang == 'es';
    final screenH = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenH * 0.88,
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.push_pin_outlined, size: 20, color: c.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEs ? 'Gestionar Mi Guardia' : 'Gerenciar Meu Plantão',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isEs
                    ? 'Toca para fijar/desfijar. Límites: ${AppProvider.kMaxPinnedDrugsPublic} fármacos, ${AppProvider.kMaxPinnedCalcsPublic} calculadoras.'
                    : 'Toque para fixar/desafixar. Limites: ${AppProvider.kMaxPinnedDrugsPublic} fármacos, ${AppProvider.kMaxPinnedCalcsPublic} calculadoras.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: Colors.white,
                  unselectedLabelColor: c.textSecondary,
                  indicator: BoxDecoration(color: c.green, borderRadius: BorderRadius.circular(8)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(3),
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  tabs: [
                    Tab(text: isEs ? 'Fármacos' : 'Fármacos'),
                    Tab(text: isEs ? 'Calculadoras' : 'Calculadoras'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            AnimatedBuilder(
              animation: _tabCtrl,
              builder: (_, __) {
                if (_tabCtrl.index != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 14, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: isEs ? 'Buscar fármaco…' : 'Buscar medicamento…',
                      hintStyle: TextStyle(fontSize: 13, color: c.textHint),
                      prefixIcon: Icon(Icons.search_rounded, color: c.textHint, size: 18),
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                );
              },
            ),

            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _DrugSelectorList(searchQuery: _searchCtrl.text, p: p, c: c, isEs: isEs),
                  _CalcSelectorList(p: p, c: c, isEs: isEs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA DE SELEÇÃO DE FÁRMACOS
// ─────────────────────────────────────────────────────────────────────────────

class _DrugSelectorList extends StatelessWidget {
  final String searchQuery;
  final AppProvider p;
  final AppColors c;
  final bool isEs;

  const _DrugSelectorList({required this.searchQuery, required this.p, required this.c, required this.isEs});

  @override
  Widget build(BuildContext context) {
    final q = searchQuery.toLowerCase().trim();
    final drugs = q.isEmpty
        ? p.drugsDB
        : p.drugsDB.where((d) =>
            d.name.toLowerCase().contains(q) ||
            (d.className[isEs ? 'es' : 'pt'] ?? '').toLowerCase().contains(q) ||
            d.group.toLowerCase().contains(q)).toList();

    if (drugs.isEmpty) {
      return Center(child: Text(isEs ? 'Sin resultados' : 'Sem resultados', style: TextStyle(color: c.textHint, fontSize: 14)));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: drugs.length,
      itemBuilder: (_, i) {
        final drug = drugs[i];
        final isPinned = p.isDrugPinned(drug.id);
        final limitReached = p.pinnedDrugIds.length >= AppProvider.kMaxPinnedDrugsPublic;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              AppHaptics.selection(context);
              final result = p.togglePinDrug(drug.id);
              if (result == PinResult.limitReached) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEs
                      ? 'Límite de ${AppProvider.kMaxPinnedDrugsPublic} fármacos alcanzado.'
                      : 'Limite de ${AppProvider.kMaxPinnedDrugsPublic} fármacos atingido.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isPinned ? c.green.withValues(alpha: 0.08) : c.cardBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isPinned ? c.green.withValues(alpha: 0.35) : c.border, width: isPinned ? 1.5 : 1.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(drug.nameL10n(isEs ? 'es' : 'pt'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        const SizedBox(height: 2),
                        Text(drug.className[isEs ? 'es' : 'pt'] ?? drug.className['es'] ?? '',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.textHint)),
                      ],
                    ),
                  ),
                  if (!isPinned && limitReached)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(6)),
                      child: Text(isEs ? 'Lleno' : 'Cheio', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c.textHint)),
                    ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: isPinned ? c.green : c.surface, shape: BoxShape.circle),
                    child: Icon(isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        size: 14, color: isPinned ? Colors.white : c.textHint),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA DE SELEÇÃO DE CALCULADORAS
// ─────────────────────────────────────────────────────────────────────────────

class _CalcSelectorList extends StatelessWidget {
  final AppProvider p;
  final AppColors c;
  final bool isEs;

  const _CalcSelectorList({required this.p, required this.c, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: kAvailableCalcs.length,
      itemBuilder: (_, i) {
        final shortcut = kAvailableCalcs[i];
        final isPinned = p.isCalcPinned(shortcut.id);
        final limitReached = p.pinnedCalcIds.length >= AppProvider.kMaxPinnedCalcsPublic;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              AppHaptics.selection(context);
              final result = p.togglePinCalc(shortcut.id);
              if (result == PinResult.limitReached) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEs
                      ? 'Límite de ${AppProvider.kMaxPinnedCalcsPublic} calculadoras alcanzado.'
                      : 'Limite de ${AppProvider.kMaxPinnedCalcsPublic} calculadoras atingido.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isPinned ? shortcut.color.withValues(alpha: 0.07) : c.cardBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isPinned ? shortcut.color.withValues(alpha: 0.35) : c.border, width: isPinned ? 1.5 : 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: shortcut.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(shortcut.icon, size: 20, color: shortcut.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(shortcut.label(isEs), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary))),
                  if (!isPinned && limitReached)
                    Text(isEs ? 'Lleno' : 'Cheio', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.textHint)),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: isPinned ? shortcut.color : c.surface, shape: BoxShape.circle),
                    child: Icon(isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        size: 14, color: isPinned ? Colors.white : c.textHint),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
