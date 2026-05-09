import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/clinical_history_model.dart';
import '../widgets/common_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  ClinicalHistoryModel? _viewing;
  ClinicalHistoryModel? _editing;
  bool _viewingPublic = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadHistories();
    });
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

    // ── Modo edição ────────────────────────────────────────────────────────
    if (_editing != null) {
      return _HistoryEditor(
        initial: _editing!,
        p: p,
        onSave: (h) async {
          await p.saveHistory(h);
          setState(() => _editing = null);
        },
        onCancel: () => setState(() => _editing = null),
      );
    }

    // ── Modo visualização ──────────────────────────────────────────────────
    if (_viewing != null) {
      return _HistoryDetail(
        history: _viewing!,
        p: p,
        readOnly: _viewingPublic,
        onBack: () => setState(() { _viewing = null; _viewingPublic = false; }),
        onEdit: _viewingPublic ? null : () {
          final h = _viewing!;
          setState(() { _viewing = null; _editing = h; });
        },
        onDelete: _viewingPublic ? null : () async {
          await p.deleteHistory(_viewing!.id, wasPublic: _viewing!.isPublic);
          setState(() => _viewing = null);
        },
      );
    }

    // ── Lista ───────────────────────────────────────────────────────────────
    final q = _searchCtrl.text.toLowerCase();
    final mine = p.myHistories.where((h) =>
      q.isEmpty ||
      h.displayTitle.toLowerCase().contains(q) ||
      h.finalDiagnosis.toLowerCase().contains(q) ||
      h.workingDiagnosis.toLowerCase().contains(q) ||
      h.tags.toLowerCase().contains(q)
    ).toList();

    final pub = p.publicHistories.where((h) =>
      q.isEmpty ||
      h.displayTitle.toLowerCase().contains(q) ||
      h.finalDiagnosis.toLowerCase().contains(q) ||
      h.tags.toLowerCase().contains(q)
    ).toList();

    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: PremiumCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('HISTÓRIA CLÍNICA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 2)),
              const SizedBox(height: 3),
              const Text('Registro clínico completo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 2),
              Text('${mine.length} minhas • ${pub.length} públicas',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
            ])),
            GestureDetector(
              onTap: () {
                final uid = p.currentUser?.uid ?? 'local';
                final name = p.currentUser?.displayName ?? p.currentUser?.email ?? 'Anônimo';
                setState(() => _editing = ClinicalHistoryModel.blank(authorUid: uid, authorName: name));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.add_rounded, size: 16, color: Color(0xFFFFE8A6)),
                  SizedBox(width: 5),
                  Text('Nova HC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6))),
                ]),
              ),
            ),
          ]),
        ),
      ),

      // Tabs
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Container(
          height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white, border: Border.all(color: kBorder)),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(borderRadius: BorderRadius.circular(12), color: kDark),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            labelColor: kGoldLight,
            unselectedLabelColor: const Color(0xFF888888),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Minhas HCs (${mine.length})'),
              Tab(text: 'Comunidade (${pub.length})'),
            ],
          ),
        ),
      ),

      // Busca
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: MedInput(
          controller: _searchCtrl,
          hintText: 'Buscar por diagnóstico, queixa, tags...',
          onChanged: (_) => setState(() {}),
        ),
      ),

      const SizedBox(height: 4),

      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Minhas HCs ──────────────────────────────────────────────
            mine.isEmpty
              ? _EmptyHistoryState(onNew: () {
                  final uid = p.currentUser?.uid ?? 'local';
                  final name = p.currentUser?.displayName ?? p.currentUser?.email ?? 'Anônimo';
                  setState(() => _editing = ClinicalHistoryModel.blank(authorUid: uid, authorName: name));
                })
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: mine.length,
                  itemBuilder: (_, i) => _HistoryCard(
                    h: mine[i], p: p,
                    onTap: () => setState(() { _viewing = mine[i]; _viewingPublic = false; }),
                    onEdit: () => setState(() => _editing = mine[i]),
                    onDelete: () async {
                      final confirm = await _confirmDelete(context);
                      if (confirm) await p.deleteHistory(mine[i].id, wasPublic: mine[i].isPublic);
                    },
                    onTogglePublic: () => p.toggleHistoryPublic(mine[i]),
                  ),
                ),

            // ── Comunidade ───────────────────────────────────────────────
            p.publicHistories.isEmpty
              ? _EmptyCommunityState(onRefresh: () => p.loadPublicHistories())
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: pub.length,
                  itemBuilder: (_, i) => _HistoryCard(
                    h: pub[i], p: p,
                    onTap: () => setState(() { _viewing = pub[i]; _viewingPublic = true; }),
                    readOnly: true,
                  ),
                ),
          ],
        ),
      ),
    ]);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir história clínica?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DA LISTA
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final ClinicalHistoryModel h;
  final AppProvider p;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePublic;
  final bool readOnly;
  const _HistoryCard({
    required this.h, required this.p, required this.onTap,
    this.onEdit, this.onDelete, this.onTogglePublic, this.readOnly = false,
  });

  Color get _outcomeColor {
    switch (h.outcome) {
      case 'alta': return const Color(0xFF065F46);
      case 'obito': return const Color(0xFFCC2222);
      case 'transferencia': return const Color(0xFF1E40AF);
      default: return const Color(0xFFC5A365);
    }
  }

  String get _outcomeLabel {
    switch (h.outcome) {
      case 'alta': return 'Alta';
      case 'obito': return 'Óbito';
      case 'transferencia': return 'Transferência';
      default: return 'Internado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final completion = h.completionRatio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorder),
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Categoria badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: kDark),
                child: Text(h.category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoldLight)),
              ),
              const SizedBox(width: 6),
              // Outcome badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _outcomeColor.withValues(alpha: 0.12), border: Border.all(color: _outcomeColor.withValues(alpha: 0.3))),
                child: Text(_outcomeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _outcomeColor)),
              ),
              if (h.isPublic) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF1E40AF).withValues(alpha: 0.1), border: Border.all(color: const Color(0xFF1E40AF).withValues(alpha: 0.3))),
                  child: const Text('Público', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF))),
                ),
              ],
              const Spacer(),
              Text(h.formattedDate, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Text(h.displayTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kDark), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (h.patientInitials.isNotEmpty || h.patientAge.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${h.patientInitials.isNotEmpty ? h.patientInitials : ''}${h.patientAge.isNotEmpty ? " • ${h.patientAge} anos" : ""} • ${h.patientSex}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
            ],
            if (h.finalDiagnosis.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFBBF7D0))),
                child: Text('Dx: ${h.finalDiagnosis}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)), overflow: TextOverflow.ellipsis),
              ),
            ] else if (h.workingDiagnosis.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFFFFF8E6), border: Border.all(color: const Color(0xFFFFE0A0))),
                child: Text('Hipótese: ${h.workingDiagnosis}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)), overflow: TextOverflow.ellipsis),
              ),
            ],
            const SizedBox(height: 10),
            // Barra de progresso
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completion,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFE8E1D2),
                  valueColor: AlwaysStoppedAnimation(completion > 0.7 ? const Color(0xFF065F46) : completion > 0.4 ? kGold : const Color(0xFFCCCCCC)),
                ),
              )),
              const SizedBox(width: 8),
              Text('${(completion * 100).round()}%', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF888888))),
            ]),
            if (!readOnly) ...[
              const SizedBox(height: 10),
              Row(children: [
                // Compartilhar
                GestureDetector(
                  onTap: onTogglePublic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: h.isPublic ? const Color(0xFF1E40AF).withValues(alpha: 0.1) : const Color(0xFFF0F0F0),
                      border: Border.all(color: h.isPublic ? const Color(0xFF1E40AF).withValues(alpha: 0.3) : kBorder),
                    ),
                    child: Row(children: [
                      Icon(h.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded, size: 12,
                        color: h.isPublic ? const Color(0xFF1E40AF) : const Color(0xFF888888)),
                      const SizedBox(width: 4),
                      Text(h.isPublic ? 'Público' : 'Privado',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                          color: h.isPublic ? const Color(0xFF1E40AF) : const Color(0xFF888888))),
                    ]),
                  ),
                ),
                const Spacer(),
                GestureDetector(onTap: onEdit, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_rounded, size: 16, color: kGold))),
                GestureDetector(onTap: onDelete, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFCC2222)))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Abrir', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
                ),
              ]),
            ] else ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(h.authorName.isNotEmpty ? h.authorName : 'Anônimo',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Ver', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISUALIZADOR COMPLETO
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryDetail extends StatelessWidget {
  final ClinicalHistoryModel history;
  final AppProvider p;
  final bool readOnly;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _HistoryDetail({required this.history, required this.p, required this.readOnly, required this.onBack, this.onEdit, this.onDelete});

  void _copy(BuildContext context) {
    final buf = StringBuffer();
    buf.writeln('=== MEDCASES PRO — HISTÓRIA CLÍNICA ===');
    buf.writeln('Data: ${history.formattedDate}');
    if (history.patientInitials.isNotEmpty) buf.writeln('Paciente: ${history.patientInitials} • ${history.patientAge} anos • ${history.patientSex}');
    if (history.chiefComplaint.isNotEmpty) buf.writeln('\nQUEIXA PRINCIPAL:\n${history.chiefComplaint}');
    if (history.hpi.isNotEmpty) buf.writeln('\nHISTÓRIA DA DOENÇA ATUAL:\n${history.hpi}');
    if (history.pastHistory.isNotEmpty) buf.writeln('\nANTECEDENTES PESSOAIS:\n${history.pastHistory}');
    if (history.medications.isNotEmpty) buf.writeln('\nMEDICAMENTOS EM USO:\n${history.medications}');
    if (history.allergies.isNotEmpty) buf.writeln('\nALERGIAS: ${history.allergies}');
    if (history.vitalSigns.isNotEmpty) buf.writeln('\nSINAIS VITAIS:\n${history.vitalSigns}');
    if (history.physicalExam.isNotEmpty) buf.writeln('\nEXAME FÍSICO:\n${history.physicalExam}');
    if (history.workingDiagnosis.isNotEmpty) buf.writeln('\nHIPÓTESE DIAGNÓSTICA: ${history.workingDiagnosis}');
    if (history.finalDiagnosis.isNotEmpty) buf.writeln('DIAGNÓSTICO FINAL: ${history.finalDiagnosis}${history.cid.isNotEmpty ? " (${history.cid})" : ""}');
    if (history.labResults.isNotEmpty) buf.writeln('\nEXAMES LABORATORIAIS:\n${history.labResults}');
    if (history.imagingResults.isNotEmpty) buf.writeln('\nEXAMES DE IMAGEM:\n${history.imagingResults}');
    if (history.treatmentPlan.isNotEmpty) buf.writeln('\nCONDUTA / TRATAMENTO:\n${history.treatmentPlan}');
    for (final e in history.evolutions) {
      final dt = DateTime.tryParse(e.date);
      final dateStr = dt != null ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}' : '';
      buf.writeln('\nEVOLUÇÃO ($dateStr — ${e.author}):\n${e.text}');
    }
    if (history.outcome != 'internado') buf.writeln('\nDESFECHO: ${history.outcome.toUpperCase()}');
    if (history.followUp.isNotEmpty) buf.writeln('SEGUIMENTO: ${history.followUp}');
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('História copiada'), duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Botão voltar
        GestureDetector(
          onTap: onBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: Colors.white),
            child: const Row(children: [
              Icon(Icons.arrow_back_ios_rounded, size: 14, color: kDark),
              SizedBox(width: 4),
              Text('Voltar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kDark)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Header hero
        PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(history.category.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(history.displayTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
            ])),
            if (!readOnly && onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1)), child: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFFFFE8A6))),
              ),
          ]),
          if (history.patientInitials.isNotEmpty || history.patientAge.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (history.patientInitials.isNotEmpty) _MetaChip(history.patientInitials),
              if (history.patientAge.isNotEmpty) _MetaChip('${history.patientAge} anos'),
              _MetaChip(history.patientSex),
              if (history.patientWeight.isNotEmpty) _MetaChip('${history.patientWeight} kg'),
              if (history.patientRecord.isNotEmpty) _MetaChip('Pront. ${history.patientRecord}'),
            ]),
          ],
          if (history.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(history.tags, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
          ],
        ])),
        const SizedBox(height: 12),

        // Diagnóstico em destaque
        if (history.finalDiagnosis.isNotEmpty || history.workingDiagnosis.isNotEmpty)
          _DxBanner(final_: history.finalDiagnosis, working: history.workingDiagnosis, cid: history.cid, differential: history.differentialDx),
        if (history.finalDiagnosis.isNotEmpty || history.workingDiagnosis.isNotEmpty) const SizedBox(height: 12),

        // Seções em cards
        _DetailCard(icon: Icons.record_voice_over_rounded, title: 'ANAMNESE', children: [
          if (history.chiefComplaint.isNotEmpty) _SectionBlock('Queixa principal', history.chiefComplaint),
          if (history.hpi.isNotEmpty) _SectionBlock('História da doença atual', history.hpi),
          if (history.pastHistory.isNotEmpty) _SectionBlock('Antecedentes pessoais', history.pastHistory),
          if (history.familyHistory.isNotEmpty) _SectionBlock('Antecedentes familiares', history.familyHistory),
          if (history.socialHistory.isNotEmpty) _SectionBlock('História social', history.socialHistory),
          if (history.medications.isNotEmpty) _SectionBlock('Medicamentos em uso', history.medications),
          if (history.allergies.isNotEmpty) _AllergyBanner(history.allergies),
          if (history.reviewOfSystems.isNotEmpty) _SectionBlock('Revisão de sistemas', history.reviewOfSystems),
        ]),
        const SizedBox(height: 10),

        _DetailCard(icon: Icons.monitor_heart_rounded, title: 'EXAME FÍSICO', children: [
          if (history.vitalSigns.isNotEmpty) _SectionBlock('Sinais vitais', history.vitalSigns),
          if (history.physicalExam.isNotEmpty) _SectionBlock('Exame físico', history.physicalExam),
        ]),
        const SizedBox(height: 10),

        _DetailCard(icon: Icons.science_rounded, title: 'EXAMES', children: [
          if (history.labResults.isNotEmpty) _SectionBlock('Laboratório', history.labResults),
          if (history.imagingResults.isNotEmpty) _SectionBlock('Imagem', history.imagingResults),
          if (history.otherResults.isNotEmpty) _SectionBlock('Outros (ECG, biopsia...)', history.otherResults),
        ]),
        const SizedBox(height: 10),

        _DetailCard(icon: Icons.medical_services_rounded, title: 'CONDUTA E TRATAMENTO', children: [
          if (history.treatmentPlan.isNotEmpty) _SectionBlock('Plano terapêutico', history.treatmentPlan),
          if (history.procedures.isNotEmpty) _SectionBlock('Procedimentos', history.procedures),
          if (history.drugIds.isNotEmpty) _DrugChips(history.drugIds, p),
        ]),
        const SizedBox(height: 10),

        // Evoluções
        if (history.evolutions.isNotEmpty) ...[
          _EvolutionSection(evolutions: history.evolutions),
          const SizedBox(height: 10),
        ],

        // Desfecho
        if (history.outcome != 'internado' || history.dischargeCondition.isNotEmpty || history.followUp.isNotEmpty)
          _DetailCard(icon: Icons.flag_rounded, title: 'DESFECHO E ALTA', children: [
            _OutcomeBadge(history.outcome),
            if (history.dischargeCondition.isNotEmpty) _SectionBlock('Condições de alta', history.dischargeCondition),
            if (history.followUp.isNotEmpty) _SectionBlock('Seguimento', history.followUp),
          ]),
        const SizedBox(height: 10),

        // Ações
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => _copy(context),
            child: Container(height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kDark, boxShadow: [BoxShadow(color: kDark.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0,4))]),
              child: const Center(child: Text('Copiar HC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGoldLight)))),
          )),
          if (!readOnly && onDelete != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onDelete,
              child: Container(height: 48, width: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFCCCC)), color: const Color(0xFFFFF0F0)),
                child: const Center(child: Icon(Icons.delete_rounded, size: 18, color: Color(0xFFCC2222)))),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR COMPLETO (com todas as seções)
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryEditor extends StatefulWidget {
  final ClinicalHistoryModel initial;
  final AppProvider p;
  final ValueChanged<ClinicalHistoryModel> onSave;
  final VoidCallback onCancel;
  const _HistoryEditor({required this.initial, required this.p, required this.onSave, required this.onCancel});

  @override
  State<_HistoryEditor> createState() => _HistoryEditorState();
}

class _HistoryEditorState extends State<_HistoryEditor> {
  late ClinicalHistoryModel _draft;
  int _section = 0; // seção ativa do editor

  // Controllers
  late final Map<String, TextEditingController> _ctrls;

  static const _sections = [
    ('', 'Paciente'),
    ('', 'Anamnese'),
    ('', 'Exame Físico'),
    ('', 'Exames'),
    ('', 'Conduta'),
    ('', 'Evolução'),
    ('', 'Desfecho'),
  ];

  static const _categories = ['Clínica Geral', 'Cardiology', 'Emergência', 'Pneumologia', 'Neurologia', 'Gastro', 'Endocrinologia', 'Nefrologia', 'Infectologia', 'Cirurgia', 'Pediatria', 'Ginecologia', 'Ortopedia', 'Outro'];
  static const _outcomes = ['internado', 'alta', 'obito', 'transferencia'];
  static const _outcomesLabel = ['Internado', 'Alta', 'Óbito', 'Transferência'];

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _ctrls = {
      'patientInitials': TextEditingController(text: _draft.patientInitials),
      'patientAge': TextEditingController(text: _draft.patientAge),
      'patientWeight': TextEditingController(text: _draft.patientWeight),
      'patientHeight': TextEditingController(text: _draft.patientHeight),
      'patientRecord': TextEditingController(text: _draft.patientRecord),
      'chiefComplaint': TextEditingController(text: _draft.chiefComplaint),
      'hpi': TextEditingController(text: _draft.hpi),
      'pastHistory': TextEditingController(text: _draft.pastHistory),
      'familyHistory': TextEditingController(text: _draft.familyHistory),
      'socialHistory': TextEditingController(text: _draft.socialHistory),
      'medications': TextEditingController(text: _draft.medications),
      'allergies': TextEditingController(text: _draft.allergies),
      'reviewOfSystems': TextEditingController(text: _draft.reviewOfSystems),
      'vitalSigns': TextEditingController(text: _draft.vitalSigns),
      'physicalExam': TextEditingController(text: _draft.physicalExam),
      'workingDiagnosis': TextEditingController(text: _draft.workingDiagnosis),
      'differentialDx': TextEditingController(text: _draft.differentialDx),
      'finalDiagnosis': TextEditingController(text: _draft.finalDiagnosis),
      'cid': TextEditingController(text: _draft.cid),
      'labResults': TextEditingController(text: _draft.labResults),
      'imagingResults': TextEditingController(text: _draft.imagingResults),
      'otherResults': TextEditingController(text: _draft.otherResults),
      'treatmentPlan': TextEditingController(text: _draft.treatmentPlan),
      'procedures': TextEditingController(text: _draft.procedures),
      'dischargeCondition': TextEditingController(text: _draft.dischargeCondition),
      'followUp': TextEditingController(text: _draft.followUp),
      'tags': TextEditingController(text: _draft.tags),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  void _save() {
    final updated = _draft.copyWith(
      patientInitials: _ctrls['patientInitials']!.text.trim(),
      patientAge: _ctrls['patientAge']!.text.trim(),
      patientWeight: _ctrls['patientWeight']!.text.trim(),
      patientHeight: _ctrls['patientHeight']!.text.trim(),
      patientRecord: _ctrls['patientRecord']!.text.trim(),
      chiefComplaint: _ctrls['chiefComplaint']!.text.trim(),
      hpi: _ctrls['hpi']!.text.trim(),
      pastHistory: _ctrls['pastHistory']!.text.trim(),
      familyHistory: _ctrls['familyHistory']!.text.trim(),
      socialHistory: _ctrls['socialHistory']!.text.trim(),
      medications: _ctrls['medications']!.text.trim(),
      allergies: _ctrls['allergies']!.text.trim(),
      reviewOfSystems: _ctrls['reviewOfSystems']!.text.trim(),
      vitalSigns: _ctrls['vitalSigns']!.text.trim(),
      physicalExam: _ctrls['physicalExam']!.text.trim(),
      workingDiagnosis: _ctrls['workingDiagnosis']!.text.trim(),
      differentialDx: _ctrls['differentialDx']!.text.trim(),
      finalDiagnosis: _ctrls['finalDiagnosis']!.text.trim(),
      cid: _ctrls['cid']!.text.trim(),
      labResults: _ctrls['labResults']!.text.trim(),
      imagingResults: _ctrls['imagingResults']!.text.trim(),
      otherResults: _ctrls['otherResults']!.text.trim(),
      treatmentPlan: _ctrls['treatmentPlan']!.text.trim(),
      procedures: _ctrls['procedures']!.text.trim(),
      dischargeCondition: _ctrls['dischargeCondition']!.text.trim(),
      followUp: _ctrls['followUp']!.text.trim(),
      tags: _ctrls['tags']!.text.trim(),
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final completion = _draft.completionRatio;
    return Column(children: [
      // Header
      PremiumCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(children: [
          Row(children: [
            GestureDetector(onTap: widget.onCancel,
              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1)),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white))),
            const SizedBox(width: 10),
            Expanded(child: Text(_draft.chiefComplaint.isNotEmpty ? _draft.chiefComplaint : 'Nova história clínica',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white), overflow: TextOverflow.ellipsis)),
            GestureDetector(onTap: _save,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: kGold),
                child: const Text('Salvar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF07110d))))),
          ]),
          const SizedBox(height: 10),
          // Barra de progresso
          Row(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: completion, minHeight: 4, backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(kGold)))),
            const SizedBox(width: 8),
            Text('${(completion * 100).round()}% preenchido', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          // Navegação de seções
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: List.generate(_sections.length, (i) {
              final active = _section == i;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _section = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: active ? kGold : Colors.white.withValues(alpha: 0.1),
                      border: Border.all(color: active ? kGold : Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(_sections[i].$2,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: active ? const Color(0xFF07110d) : Colors.white.withValues(alpha: 0.85))),
                  ),
                ),
              );
            })),
          ),
        ]),
      ),

      // Conteúdo da seção
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        child: _buildSection(),
      )),
    ]);
  }

  Widget _buildSection() {
    switch (_section) {
      case 0: return _buildPatientSection();
      case 1: return _buildAnamnesisSection();
      case 2: return _buildPhysicalExamSection();
      case 3: return _buildExamsSection();
      case 4: return _buildTreatmentSection();
      case 5: return _buildEvolutionSection();
      case 6: return _buildOutcomeSection();
      default: return const SizedBox();
    }
  }

  // ── Seção 0: Paciente ──────────────────────────────────────────────────────
  Widget _buildPatientSection() => Column(children: [
    _EditorField('Iniciais do paciente *', _ctrls['patientInitials']!, hint: 'J.S. (preservar privacidade)'),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _EditorField('Idade', _ctrls['patientAge']!, hint: '68', numeric: true)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SEXO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12), height: 44,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _draft.patientSex, isExpanded: true,
            items: ['Masculino', 'Feminino'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)))).toList(),
            onChanged: (v) => setState(() => _draft = _draft.copyWith(patientSex: v ?? 'Masculino')),
          )),
        ),
      ])),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _EditorField('Peso (kg)', _ctrls['patientWeight']!, hint: '72', numeric: true)),
      const SizedBox(width: 10),
      Expanded(child: _EditorField('Altura (cm)', _ctrls['patientHeight']!, hint: '170', numeric: true)),
    ]),
    const SizedBox(height: 10),
    _EditorField('Nº Prontuário (opcional)', _ctrls['patientRecord']!, hint: '00123456'),
    const SizedBox(height: 10),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('CATEGORIA / ESPECIALIDADE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12), height: 44,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _draft.category, isExpanded: true,
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))).toList(),
          onChanged: (v) => setState(() => _draft = _draft.copyWith(category: v ?? 'Clínica Geral')),
        )),
      ),
    ]),
    const SizedBox(height: 10),
    _EditorField('Tags (ex: sepse, UTI, DM2)', _ctrls['tags']!, hint: 'sepse, pneumonia, idoso'),
    const SizedBox(height: 14),
    // Compartilhar toggle
    GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(isPublic: !_draft.isPublic)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _draft.isPublic ? const Color(0xFF1E40AF).withValues(alpha: 0.4) : kBorder),
          color: _draft.isPublic ? const Color(0xFF1E40AF).withValues(alpha: 0.06) : Colors.white),
        child: Row(children: [
          Icon(_draft.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded, size: 20, color: _draft.isPublic ? const Color(0xFF1E40AF) : const Color(0xFF888888)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_draft.isPublic ? 'História pública — visível na Comunidade' : 'História privada — somente você vê',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _draft.isPublic ? const Color(0xFF1E40AF) : kDark)),
            const SizedBox(height: 2),
            const Text('Toque para alternar. Dados do paciente são anonimizados (iniciais).', style: TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
          ])),
          Switch(value: _draft.isPublic, onChanged: (v) => setState(() => _draft = _draft.copyWith(isPublic: v)),
            activeColor: const Color(0xFF1E40AF)),
        ]),
      ),
    ),
  ]);

  // ── Seção 1: Anamnese ─────────────────────────────────────────────────────
  Widget _buildAnamnesisSection() => Column(children: [
    _EditorField('Queixa principal *', _ctrls['chiefComplaint']!, hint: 'Dor torácica há 2h', multiline: true),
    const SizedBox(height: 10),
    _EditorField('História da doença atual (HDA)', _ctrls['hpi']!, hint: 'Descrever cronologia, características, fatores...', multiline: true, lines: 5),
    const SizedBox(height: 10),
    _EditorField('Antecedentes pessoais', _ctrls['pastHistory']!, hint: 'HAS, DM2, IAM prévio, cirurgias...', multiline: true),
    const SizedBox(height: 10),
    _EditorField('Antecedentes familiares', _ctrls['familyHistory']!, hint: 'Pai: IAM aos 55 anos. Mãe: DM2...', multiline: true),
    const SizedBox(height: 10),
    _EditorField('História social', _ctrls['socialHistory']!, hint: 'Tabagismo, etilismo, drogas, atividade física, profissão...', multiline: true),
    const SizedBox(height: 10),
    _EditorField('Medicamentos em uso', _ctrls['medications']!, hint: 'AAS 100mg/dia, metformina 850mg 2x/dia...', multiline: true),
    const SizedBox(height: 10),
    _EditorField('Alergias', _ctrls['allergies']!, hint: 'Penicilina (urticária), dipirona (angioedema)...', multiline: true),
    const SizedBox(height: 10),
    _EditorField('Revisão de sistemas', _ctrls['reviewOfSystems']!, hint: 'Cardiovascular, respiratório, GI, neurológico...', multiline: true),
  ]);

  // ── Seção 2: Exame físico ──────────────────────────────────────────────────
  Widget _buildPhysicalExamSection() => Column(children: [
    _EditorField('Sinais vitais', _ctrls['vitalSigns']!, hint: 'PA 130/80 | FC 88 | FR 18 | Temp 36,8°C | SpO2 97% | Peso 78kg', multiline: true),
    const SizedBox(height: 10),
    _EditorField('Exame físico por sistemas', _ctrls['physicalExam']!, hint: 'Geral: BEG, corado, hidratado...\nCV: RCR 2T, sem sopros...\nTórax: MV+ bilateral, sem RA...\nAbdome: RHA+, indolor...', multiline: true, lines: 8),
    const SizedBox(height: 10),
    // Diagnóstico logo após o exame físico
    _EditorField('Hipótese diagnóstica principal', _ctrls['workingDiagnosis']!, hint: 'Síndrome Coronariana Aguda STEMI anterior'),
    const SizedBox(height: 10),
    _EditorField('Diagnóstico diferencial', _ctrls['differentialDx']!, hint: 'Pericardite aguda, dissecção aórtica, TEP...', multiline: true),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(flex: 2, child: _EditorField('Diagnóstico final', _ctrls['finalDiagnosis']!, hint: 'IAM STEMI anterior')),
      const SizedBox(width: 10),
      Expanded(child: _EditorField('CID', _ctrls['cid']!, hint: 'I21.0')),
    ]),
  ]);

  // ── Seção 3: Exames ───────────────────────────────────────────────────────
  Widget _buildExamsSection() => Column(children: [
    _EditorField('Exames laboratoriais', _ctrls['labResults']!, hint: 'Troponina: 2,4 ng/mL (↑)\nHb: 12,8 g/dL | Leuco: 14.200\nCreatinina: 1,1 mg/dL | K+: 4,2...', multiline: true, lines: 6),
    const SizedBox(height: 10),
    _EditorField('Exames de imagem', _ctrls['imagingResults']!, hint: 'ECG: supra ST V1-V4, QRS 95ms...\nRX tórax: sem congestão, ICT normal...\nEco: FE 48%, hipocinesia anterior...', multiline: true, lines: 5),
    const SizedBox(height: 10),
    _EditorField('Outros exames (ECG, biópsia, EEG...)', _ctrls['otherResults']!, hint: 'Biópsia renal: glomerulonefrite focal...', multiline: true),
  ]);

  // ── Seção 4: Conduta / Tratamento ────────────────────────────────────────
  Widget _buildTreatmentSection() => Column(children: [
    _EditorField('Plano terapêutico / Conduta', _ctrls['treatmentPlan']!, hint: '1. AAS 300mg VO imediato\n2. Ticagrelor 180mg VO\n3. Heparina NF EV\n4. Ativar hemodinâmica (meta porta-balão < 90min)...', multiline: true, lines: 7),
    const SizedBox(height: 10),
    _EditorField('Procedimentos realizados', _ctrls['procedures']!, hint: 'Cateterismo + angioplastia com stent em DA proximal...', multiline: true),
  ]);

  // ── Seção 5: Evolução ─────────────────────────────────────────────────────
  Widget _buildEvolutionSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('NOTAS DE EVOLUÇÃO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
      const SizedBox(height: 4),
      const Text('Registre a evolução cronológica do paciente (diária, por turno, por evento).', style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      ..._draft.evolutions.asMap().entries.map((entry) {
        final i = entry.key;
        final evo = entry.value;
        return _EvolutionEditorCard(
          evo: evo,
          onDelete: () => setState(() {
            final list = List<EvolutionEntry>.from(_draft.evolutions);
            list.removeAt(i);
            _draft = _draft.copyWith(evolutions: list);
          }),
          onUpdate: (updated) => setState(() {
            final list = List<EvolutionEntry>.from(_draft.evolutions);
            list[i] = updated;
            _draft = _draft.copyWith(evolutions: list);
          }),
        );
      }),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => setState(() {
          final list = List<EvolutionEntry>.from(_draft.evolutions);
          list.add(EvolutionEntry.blank());
          _draft = _draft.copyWith(evolutions: list);
        }),
        child: Container(
          width: double.infinity, height: 48,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder, style: BorderStyle.solid), color: kSurface),
          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_circle_outline_rounded, size: 16, color: kGold),
            SizedBox(width: 6),
            Text('Adicionar nota de evolução', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGold)),
          ])),
        ),
      ),
    ]);
  }

  // ── Seção 6: Desfecho ──────────────────────────────────────────────────────
  Widget _buildOutcomeSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('DESFECHO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
    const SizedBox(height: 8),
    Row(children: List.generate(_outcomes.length, (i) {
      final selected = _draft.outcome == _outcomes[i];
      final colors = [const Color(0xFFC5A365), const Color(0xFF065F46), const Color(0xFFCC2222), const Color(0xFF1E40AF)];
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: i < _outcomes.length - 1 ? 6 : 0),
        child: GestureDetector(
          onTap: () => setState(() => _draft = _draft.copyWith(outcome: _outcomes[i])),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              color: selected ? colors[i] : Colors.white,
              border: Border.all(color: selected ? colors[i] : kBorder)),
            child: Column(children: [
              Icon(i == 0 ? Icons.hotel_rounded : i == 1 ? Icons.home_rounded : i == 2 ? Icons.close_rounded : Icons.arrow_forward_rounded,
                size: 16, color: selected ? Colors.white : const Color(0xFF888888)),
              const SizedBox(height: 3),
              Text(_outcomesLabel[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: selected ? Colors.white : const Color(0xFF888888))),
            ]),
          ),
        ),
      ));
    })),
    const SizedBox(height: 14),
    _EditorField('Condições de alta', _ctrls['dischargeCondition']!, hint: 'BEG, estável, orientado, tolerando VO...', multiline: true),
    const SizedBox(height: 10),
    _EditorField('Seguimento / Orientações', _ctrls['followUp']!, hint: 'Retorno em 7 dias com cardiologista. Manter AAS + ticagrelor por 12 meses...', multiline: true),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _EditorField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final bool multiline, numeric;
  final int lines;
  const _EditorField(this.label, this.ctrl, {required this.hint, this.multiline = false, this.numeric = false, this.lines = 3});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
      const SizedBox(height: 5),
      MedInput(controller: ctrl, hintText: hint, maxLines: multiline ? lines : 1,
        keyboardType: numeric ? TextInputType.number : multiline ? TextInputType.multiline : null),
    ]);
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.12), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _DetailCard({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final filled = children.where((c) => c is! SizedBox).isNotEmpty;
    if (!filled) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder), color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: kDark),
            child: Icon(icon, size: 14, color: kGoldLight)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: kDark)),
        ]),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String label, text;
  const _SectionBlock(this.label, this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF888888))),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333), height: 1.55)),
      ]),
    );
  }
}

class _AllergyBanner extends StatelessWidget {
  final String text;
  const _AllergyBanner(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFFFFF0F0), border: Border.all(color: const Color(0xFFFFCCCC))),
        child: Row(children: [
          const Icon(Icons.warning_rounded, size: 16, color: Color(0xFFCC2222)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ALERGIAS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFCC2222), letterSpacing: 1.2)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFCC2222))),
          ])),
        ]),
      ),
    );
  }
}

class _DxBanner extends StatelessWidget {
  final String final_, working, cid, differential;
  const _DxBanner({required this.final_, required this.working, required this.cid, required this.differential});
  @override
  Widget build(BuildContext context) {
    final hasFinal = final_.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: hasFinal ? const Color(0xFFECFDF5) : const Color(0xFFFFF8E6),
        border: Border.all(color: hasFinal ? const Color(0xFFBBF7D0) : const Color(0xFFFFE0A0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hasFinal ? 'DIAGNÓSTICO FINAL' : 'HIPÓTESE DIAGNÓSTICA',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: hasFinal ? const Color(0xFF065F46) : const Color(0xFF92400E))),
        const SizedBox(height: 4),
        Text(hasFinal ? final_ : working,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: hasFinal ? const Color(0xFF064E3B) : const Color(0xFF78350F))),
        if (cid.isNotEmpty) ...[const SizedBox(height: 4), Text('CID: $cid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hasFinal ? const Color(0xFF065F46) : const Color(0xFF92400E)))],
        if (differential.isNotEmpty) ...[const SizedBox(height: 6), Text('DD: $differential', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF555555), height: 1.4))],
      ]),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  final String outcome;
  const _OutcomeBadge(this.outcome);
  @override
  Widget build(BuildContext context) {
    final map = {'internado': ('Internado', const Color(0xFFC5A365)), 'alta': ('Alta hospitalar', const Color(0xFF065F46)), 'obito': ('Óbito', const Color(0xFFCC2222)), 'transferencia': ('Transferência', const Color(0xFF1E40AF))};
    final info = map[outcome] ?? ('Internado', kGold);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: info.$2.withValues(alpha: 0.1), border: Border.all(color: info.$2.withValues(alpha: 0.3))),
        child: Text('Desfecho: ${info.$1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: info.$2)),
      ),
    );
  }
}

class _DrugChips extends StatelessWidget {
  final List<String> ids;
  final AppProvider p;
  const _DrugChips(this.ids, this.p);
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('FÁRMACOS UTILIZADOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF888888))),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: ids.map((id) {
        final drug = p.drugsDB.where((d) => d.id == id).firstOrNull;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: kDark),
          child: Text(drug?.name ?? id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kGoldLight)),
        );
      }).toList()),
    ]);
  }
}

class _EvolutionSection extends StatelessWidget {
  final List<EvolutionEntry> evolutions;
  const _EvolutionSection({required this.evolutions});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder), color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.timeline_rounded, size: 16, color: kGold),
          SizedBox(width: 8),
          Text('EVOLUÇÃO CLÍNICA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: kDark)),
        ]),
        const SizedBox(height: 12),
        ...evolutions.map((e) {
          final dt = DateTime.tryParse(e.date);
          final dateStr = dt != null
            ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} às ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
            : '';
          final typeLabels = {'evolution': 'Evolução', 'nursing': 'Enfermagem', 'lab': 'Lab', 'imaging': 'Imagem', 'procedure': 'Procedimento'};
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle)),
                Container(width: 2, height: 40, color: kBorder),
              ]),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(typeLabels[e.type] ?? 'Evolução', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGold)),
                  const Spacer(),
                  Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                ]),
                if (e.author.isNotEmpty) Text(e.author, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(e.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF333333), height: 1.5)),
              ])),
            ]),
          );
        }),
      ]),
    );
  }
}

class _EvolutionEditorCard extends StatefulWidget {
  final EvolutionEntry evo;
  final VoidCallback onDelete;
  final ValueChanged<EvolutionEntry> onUpdate;
  const _EvolutionEditorCard({required this.evo, required this.onDelete, required this.onUpdate});
  @override
  State<_EvolutionEditorCard> createState() => _EvolutionEditorCardState();
}

class _EvolutionEditorCardState extends State<_EvolutionEditorCard> {
  late final TextEditingController _textCtrl;
  late final TextEditingController _authorCtrl;
  late String _type;

  static const _types = ['evolution', 'nursing', 'lab', 'imaging', 'procedure'];
  static const _typeLabels = ['Evolução', 'Enfermagem', 'Lab', 'Imagem', 'Procedimento'];

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.evo.text);
    _authorCtrl = TextEditingController(text: widget.evo.author);
    _type = widget.evo.type;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  void _update() {
    widget.onUpdate(widget.evo.copyWith(text: _textCtrl.text, author: _authorCtrl.text, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(widget.evo.date);
    final dateStr = dt != null ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: kSurface),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(dateStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
          const Spacer(),
          GestureDetector(onTap: widget.onDelete, child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFCC2222))),
        ]),
        const SizedBox(height: 8),
        // Tipo de nota
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(_types.length, (i) {
          final sel = _type == _types[i];
          return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
            onTap: () { setState(() => _type = _types[i]); _update(); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: sel ? kDark : Colors.white, border: Border.all(color: sel ? kDark : kBorder)),
              child: Text(_typeLabels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sel ? kGoldLight : const Color(0xFF888888)))),
          ));
        }))),
        const SizedBox(height: 8),
        MedInput(controller: _authorCtrl, hintText: 'Dr./Enf. nome do profissional', onChanged: (_) => _update()),
        const SizedBox(height: 6),
        MedInput(controller: _textCtrl, hintText: 'Nota de evolução...', maxLines: 4, onChanged: (_) => _update()),
      ]),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyHistoryState({required this.onNew});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.description_outlined, size: 56, color: Colors.grey[300]),
      const SizedBox(height: 14),
      const Text('Nenhuma história clínica', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFAAAAAA))),
      const SizedBox(height: 6),
      const Text('Crie e documente seus casos clínicos\nde forma estruturada e completa', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      MedButton(label: '+ Nova história clínica', onTap: onNew),
    ]));
  }
}

class _EmptyCommunityState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyCommunityState({required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey[300]),
      const SizedBox(height: 14),
      const Text('Nenhuma história pública', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFAAAAAA))),
      const SizedBox(height: 6),
      const Text('Seja o primeiro a compartilhar!\nAnonimize e compartilhe seus casos.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      GestureDetector(onTap: onRefresh, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: kDark),
        child: const Text('Atualizar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGoldLight)),
      )),
    ]));
  }
}
