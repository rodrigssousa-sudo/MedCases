import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_provider.dart';
import '../models/clinical_case_model.dart';
import '../widgets/common_widgets.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});
  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  ClinicalCaseModel? _editing;
  bool _viewingDb = false;
  ClinicalCaseModel? _viewingCase;
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

    if (_editing != null) {
      return _CaseEditor(
        initial: _editing!,
        onSave: (c) { p.saveCase(c); setState(() => _editing = null); },
        onCancel: () => setState(() => _editing = null),
        p: p,
      );
    }

    if (_viewingCase != null) {
      return _CaseDetail(
        caseModel: _viewingCase!,
        onBack: () => setState(() { _viewingCase = null; _viewingDb = false; }),
        onEdit: () { _editing = _viewingCase!.copyWith(); setState(() => _viewingCase = null); },
        onDelete: _viewingDb ? null : () {
          p.deleteCase(_viewingCase!.id);
          setState(() => _viewingCase = null);
        },
        p: p,
      );
    }

    final q = _searchCtrl.text.toLowerCase();

    final customFiltered = p.customCases.where((c) {
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) || c.diagnosis.toLowerCase().contains(q) || c.history.toLowerCase().contains(q);
    }).toList();

    final dbFiltered = p.casesDB.where((c) {
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) || c.diagnosis.toLowerCase().contains(q);
    }).toList();

    return Column(children: [
      // Header
      PremiumCard(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Expanded(child: SectionTitle(
              eyebrow: 'Case Manager',
              title: p.t('cases'),
              subtitle: p.t('cases_subtitle'),
              light: true,
            )),
            GestureDetector(
              onTap: () => setState(() => _editing = ClinicalCaseModel.blank()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withValues(alpha: 0.15), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                child: Row(children: [
                  const Icon(Icons.add_rounded, size: 16, color: Color(0xFFFFE8A6)),
                  const SizedBox(width: 4),
                  Text(p.t('new_case'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6))),
                ]),
              ),
            ),
          ]),
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
              Tab(text: '${p.t("my_cases")} (${customFiltered.length})'),
              Tab(text: '${p.t("library")} (${dbFiltered.length})'),
            ],
          ),
        ),
      ),

      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: MedInput(
          controller: _searchCtrl,
          hintText: p.t('search_cases'),
          onChanged: (_) => setState(() {}),
        ),
      ),

      const SizedBox(height: 4),

      // Tab views
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            // My cases
            customFiltered.isEmpty
              ? _EmptyState(
                  text: p.t('no_cases'),
                  actionText: p.t('new_case'),
                  onAction: () => setState(() => _editing = ClinicalCaseModel.blank()),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                  itemCount: customFiltered.length,
                  itemBuilder: (context, i) => _CaseCard(
                    c: customFiltered[i],
                    onTap: () => setState(() { _viewingCase = customFiltered[i]; _viewingDb = false; }),
                    onEdit: () => setState(() => _editing = customFiltered[i].copyWith()),
                    onDelete: () { p.deleteCase(customFiltered[i].id); },
                    p: p,
                  ),
                ),
            // Library
            dbFiltered.isEmpty
              ? _EmptyState(text: p.t('no_library_cases'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                  itemCount: dbFiltered.length,
                  itemBuilder: (context, i) => _CaseCard(
                    c: dbFiltered[i],
                    onTap: () => setState(() { _viewingCase = dbFiltered[i]; _viewingDb = true; }),
                    p: p,
                    readOnly: true,
                  ),
                ),
          ],
        ),
      ),
    ]);
  }
}

class _CaseCard extends StatelessWidget {
  final ClinicalCaseModel c;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final AppProvider p;
  final bool readOnly;
  const _CaseCard({required this.c, required this.onTap, required this.p, this.onEdit, this.onDelete, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: kDark),
                    child: Text(c.category.isNotEmpty ? c.category : p.t('case_label'),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGoldLight)),
                  ),
                  if (c.patientAge.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('${c.patientAge}a | ${c.patientSex}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
                  ],
                ]),
                const SizedBox(height: 6),
                Text(c.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kDark), overflow: TextOverflow.ellipsis),
              ])),
              if (!readOnly && onEdit != null) ...[
                GestureDetector(onTap: onEdit, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_rounded, size: 16, color: kGold))),
                GestureDetector(
                  onTap: () {
                    if (onDelete != null) {
                      showDialog(context: context, builder: (_) => AlertDialog(
                        title: Text(p.t('delete_case_q')),
                        content: Text('${p.t("delete_case_confirm")} "${c.title}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text(p.t('cancel'))),
                          TextButton(onPressed: () { Navigator.pop(context); onDelete!(); }, child: Text(p.t('delete'), style: const TextStyle(color: Colors.red))),
                        ],
                      ));
                    }
                  },
                  child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFCC2222))),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(20)),
                child: Text(p.t('open'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
              ),
            ]),
            if (c.diagnosis.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFBBF7D0))),
                child: Text('Dx: ${c.diagnosis}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)), overflow: TextOverflow.ellipsis),
              ),
            ],
            if (c.history.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(c.history, style: const TextStyle(fontSize: 12, color: Color(0xFF777777), fontWeight: FontWeight.w600, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
      ),
    );
  }
}

class _CaseDetail extends StatelessWidget {
  final ClinicalCaseModel caseModel;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final AppProvider p;
  const _CaseDetail({required this.caseModel, required this.onBack, this.onEdit, this.onDelete, required this.p});

  String _buildCaseText() {
    final buf = StringBuffer();
    buf.writeln('=== MEDCASES PRO: ${p.t('clinical_case_header').toUpperCase()} ===');
    buf.writeln('${p.t('title_label')}: ${caseModel.title}');
    if (caseModel.patientAge.isNotEmpty) buf.writeln('${p.t('patient_label')}: ${caseModel.patientAge} ${p.t('years')} | ${caseModel.patientSex}');
    if (caseModel.history.isNotEmpty) buf.writeln('\n${p.t('clinical_history')}:\n${caseModel.history}');
    if (caseModel.diagnosis.isNotEmpty) buf.writeln('\n${p.t('diagnosis')}: ${caseModel.diagnosis}');
    if (caseModel.plan.isNotEmpty) buf.writeln('\n${p.t('plan_conduct')}:\n${caseModel.plan}');
    if (caseModel.notes.isNotEmpty) buf.writeln('\n${p.t('notes')}:\n${caseModel.notes}');
    buf.writeln('\n— MedCases Pro');
    return buf.toString();
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _buildCaseText()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.t('copied')), duration: const Duration(seconds: 1)));
  }

  void _share() {
    SharePlus.instance.share(ShareParams(text: _buildCaseText()));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(children: [
        GestureDetector(
          onTap: onBack,
          child: Row(children: [
            const Icon(Icons.arrow_back_ios, size: 14, color: kDark),
            const SizedBox(width: 4),
            Text(p.t('back_cases'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kDark)),
          ]),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (caseModel.category.isNotEmpty)
                  Text(caseModel.category.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 1.8)),
                const SizedBox(height: 4),
                Text(caseModel.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
              ])),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1), border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
                    child: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFFFFE8A6)),
                  ),
                ),
            ]),
            if (caseModel.patientAge.isNotEmpty || caseModel.patientSex.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (caseModel.patientAge.isNotEmpty)
                  _MetaChip(label: "${caseModel.patientAge} ${p.t('years')}"),
                if (caseModel.patientSex.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _MetaChip(label: caseModel.patientSex),
                ],
                if (caseModel.patientWeight.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _MetaChip(label: '${caseModel.patientWeight} kg'),
                ],
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        StandardCard(
          child: Column(children: [
            if (caseModel.history.isNotEmpty) _DetailBlock(label: p.t('clinical_history'), text: caseModel.history),
            if (caseModel.diagnosis.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFBBF7D0))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.t('diagnosis').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF065F46))),
                  const SizedBox(height: 4),
                  Text(caseModel.diagnosis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF064E3B))),
                ]),
              ),
            ],
            if (caseModel.plan.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailBlock(label: p.t('plan_conduct'), text: caseModel.plan),
            ],
            if (caseModel.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailBlock(label: p.t('notes'), text: caseModel.notes),
            ],
            if (caseModel.drugIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.t('drugs').toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: caseModel.drugIds.map((id) {
                  final drug = p.drugsDB.where((d) => d.id == id).firstOrNull;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: kDark, border: Border.all(color: kDark)),
                    child: Text(drug?.name ?? id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kGoldLight)),
                  );
                }).toList()),
              ]),
            ],
            const SizedBox(height: 12),
            Row(children: [
              // Copiar
              Expanded(
                child: GestureDetector(
                  onTap: () => _copy(context),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kDark),
                    child: Center(child: Text(p.t('copy_case'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGoldLight))),
                  ),
                ),
              ),
              // Compartilhar
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _share,
                child: Container(
                  height: 44, width: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                    color: Colors.white,
                  ),
                  child: const Center(child: Icon(Icons.share_rounded, size: 18, color: kDark)),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(context: context, builder: (_) => AlertDialog(
                      title: Text(p.t('delete_case_q')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text(p.t('cancel'))),
                        TextButton(onPressed: () { Navigator.pop(context); onDelete!(); }, child: Text(p.t('delete'), style: const TextStyle(color: Colors.red))),
                      ],
                    ));
                  },
                  child: Container(
                    height: 44, width: 44,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFCCCC)), color: const Color(0xFFFFF0F0)),
                    child: const Center(child: Icon(Icons.delete_rounded, size: 18, color: Color(0xFFCC2222))),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.12), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final String text;
  const _DetailBlock({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333), height: 1.55)),
      ]),
    );
  }
}

class _CaseEditor extends StatefulWidget {
  final ClinicalCaseModel initial;
  final ValueChanged<ClinicalCaseModel> onSave;
  final VoidCallback onCancel;
  final AppProvider p;
  const _CaseEditor({required this.initial, required this.onSave, required this.onCancel, required this.p});

  @override
  State<_CaseEditor> createState() => _CaseEditorState();
}

class _CaseEditorState extends State<_CaseEditor> {
  late final TextEditingController _titleCtrl, _ageCtrl, _histCtrl, _dxCtrl, _planCtrl, _notesCtrl;
  String _sex = 'Masculino';
  String _category = 'Cardiology';
  late String _weight;

  static const _categories = ['Cardiology', 'Emergência', 'Pneumologia', 'Neurologia', 'Gastro', 'Endocrinologia', 'Nefrologia', 'Infectologia', 'Outro'];
  static const _sexes = ['Masculino', 'Feminino'];

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _titleCtrl = TextEditingController(text: c.title);
    _ageCtrl = TextEditingController(text: c.patientAge);
    _histCtrl = TextEditingController(text: c.history);
    _dxCtrl = TextEditingController(text: c.diagnosis);
    _planCtrl = TextEditingController(text: c.plan);
    _notesCtrl = TextEditingController(text: c.notes);
    _sex = c.patientSex.isNotEmpty ? c.patientSex : 'Masculino';
    _category = c.category.isNotEmpty ? c.category : 'Emergência';
    _weight = c.patientWeight;
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _ageCtrl, _histCtrl, _dxCtrl, _planCtrl, _notesCtrl]) c.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.p.t('case_title_required'))));
      return;
    }
    widget.onSave(widget.initial.copyWith(
      title: _titleCtrl.text.trim(),
      patientAge: _ageCtrl.text.trim(),
      patientSex: _sex,
      patientWeight: _weight,
      history: _histCtrl.text.trim(),
      diagnosis: _dxCtrl.text.trim(),
      plan: _planCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      category: _category,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(children: [
        // Header
        PremiumCard(
          child: Row(children: [
            GestureDetector(
              onTap: widget.onCancel,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1)),
                child: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
              widget.initial.title.isEmpty ? p.t('new_case') : p.t('edit_case'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            )),
            GestureDetector(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFFC5A365)),
                child: Text(p.t('save'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF07110d))),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        StandardCard(
          child: Column(children: [
            _EditorField(label: p.t('case_title_field'), ctrl: _titleCtrl, hint: 'Ex: IAM anterior extenso'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _EditorField(label: p.t('age'), ctrl: _ageCtrl, hint: '68', numeric: true)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('SEXO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sex,
                      isExpanded: true,
                      items: _sexes.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)))).toList(),
                      onChanged: (v) => setState(() => _sex = v ?? 'Masculino'),
                    ),
                  ),
                ),
              ])),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CATEGORIA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _category,
                      isExpanded: true,
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))).toList(),
                      onChanged: (v) => setState(() => _category = v ?? 'Emergência'),
                    ),
                  ),
                ),
              ])),
            ]),
            const SizedBox(height: 10),
            _EditorField(label: p.t('clinical_history'), ctrl: _histCtrl,
              hint: p.t('history_hint'), multiline: true),
            const SizedBox(height: 10),
            _EditorField(label: p.t('diagnosis'), ctrl: _dxCtrl, hint: 'IAM com supradesnivelamento de ST'),
            const SizedBox(height: 10),
            _EditorField(label: p.t('plan_conduct'), ctrl: _planCtrl,
              hint: 'AAS, clopidogrel, heparina, cateterismo...', multiline: true),
            const SizedBox(height: 10),
            _EditorField(label: p.t('additional_notes'), ctrl: _notesCtrl,
              hint: p.t('notes_hint'), multiline: true),
            const SizedBox(height: 14),
            MedButton(label: p.t('save'), onTap: _save, fullWidth: true),
          ]),
        ),
      ]),
    );
  }
}

class _EditorField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final bool multiline;
  final bool numeric;
  const _EditorField({required this.label, required this.ctrl, required this.hint, this.multiline = false, this.numeric = false});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
      const SizedBox(height: 5),
      MedInput(
        controller: ctrl,
        hintText: hint,
        maxLines: multiline ? 4 : 1,
        keyboardType: numeric ? TextInputType.number : null,
      ),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  final String? actionText;
  final VoidCallback? onAction;
  const _EmptyState({required this.text, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFAAAAAA))),
        if (actionText != null && onAction != null) ...[
          const SizedBox(height: 16),
          MedButton(label: '+ $actionText', onTap: onAction),
        ],
      ]),
    );
  }
}
