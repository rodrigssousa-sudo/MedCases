import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import '../providers/app_provider.dart';
import '../models/clinical_history_model.dart';
import '../services/firestore_service.dart';
import '../widgets/common_widgets.dart';

// Helper global — formata ISO para 'dd/mm/yyyy às hh:mm'
String _formatUploadedAt(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return 'Publicado $d/$m/${dt.year} \u00e0s $h:$min';
  } catch (_) {
    return '';
  }
}

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
  // Filtro por intervalo de datas (null = sem filtro)
  DateTimeRange? _dateFilter;

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

  // Abre o seletor de intervalo de datas
  Future<void> _showDateFilter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateFilter,
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF07110d),
              onPrimary: Color(0xFFFFE8A6),
              surface: Colors.white,
              onSurface: Color(0xFF07110d),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateFilter = picked);
    }
  }

  void _clearDateFilter() => setState(() => _dateFilter = null);

  // Aplica filtro de texto + data em uma lista de histórias
  List<ClinicalHistoryModel> _applyFilters(List<ClinicalHistoryModel> list) {
    final q = _searchCtrl.text.toLowerCase();
    return list.where((h) {
      // Filtro de texto
      final textOk = q.isEmpty ||
          h.displayTitle.toLowerCase().contains(q) ||
          h.finalDiagnosis.toLowerCase().contains(q) ||
          h.workingDiagnosis.toLowerCase().contains(q) ||
          h.tags.toLowerCase().contains(q);
      if (!textOk) return false;
      // Filtro de data
      if (_dateFilter != null) {
        try {
          final dt = DateTime.parse(h.createdAt).toLocal();
          final start = DateTime(_dateFilter!.start.year, _dateFilter!.start.month, _dateFilter!.start.day);
          final end   = DateTime(_dateFilter!.end.year,   _dateFilter!.end.month,   _dateFilter!.end.day, 23, 59, 59);
          if (dt.isBefore(start) || dt.isAfter(end)) return false;
        } catch (_) {
          // Se não puder parsear a data, não filtra esse item
        }
      }
      return true;
    }).toList();
  }

  // Texto formatado do filtro ativo
  String get _dateFilterLabel {
    if (_dateFilter == null) return '';
    final s = _dateFilter!.start;
    final e = _dateFilter!.end;
    final fmt = (DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    if (s.year == e.year && s.month == e.month && s.day == e.day) return fmt(s);
    return '${fmt(s)} – ${fmt(e)}';
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
    final mine = _applyFilters(p.myHistories);
    final pub  = _applyFilters(p.publicHistories);

    return Column(children: [
      // Header
      PremiumCard(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                final email = p.currentUser?.email ?? '';
                setState(() => _editing = ClinicalHistoryModel.blank(authorUid: uid, authorName: name, authorEmail: email));
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

      // Busca + Filtro por data
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          Expanded(
            child: MedInput(
              controller: _searchCtrl,
              hintText: 'Buscar por diagnóstico, queixa, tags...',
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // Botão filtro por data
          GestureDetector(
            onTap: _showDateFilter,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _dateFilter != null
                    ? const Color(0xFF07110d)
                    : Colors.white,
                border: Border.all(
                  color: _dateFilter != null
                      ? const Color(0xFF07110d)
                      : kBorder,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range_rounded, size: 16,
                    color: _dateFilter != null
                        ? const Color(0xFFFFE8A6)
                        : const Color(0xFF888888)),
              ]),
            ),
          ),
        ]),
      ),

      // Chip do filtro de data ativo
      if (_dateFilter != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF07110d).withValues(alpha: 0.08),
                border: Border.all(color: const Color(0xFF07110d).withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.date_range_rounded, size: 12, color: Color(0xFF07110d)),
                const SizedBox(width: 6),
                Text(_dateFilterLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF07110d))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearDateFilter,
                  child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF555555)),
                ),
              ]),
            ),
          ]),
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
                  final email = p.currentUser?.email ?? '';
                  setState(() => _editing = ClinicalHistoryModel.blank(authorUid: uid, authorName: name, authorEmail: email));
                })
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
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
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                  itemCount: pub.length,
                  itemBuilder: (ctx, i) {
                    final h = pub[i];
                    final canModerate = p.canModerateContent;
                    // Usuários comuns não veem HCs ocultas
                    if (h.isHidden && !canModerate) return const SizedBox.shrink();
                    return _HistoryCard(
                      h: h, p: p,
                      onTap: () => setState(() { _viewing = h; _viewingPublic = true; }),
                      readOnly: true,
                      onModHide: canModerate ? () async {
                        final uid = p.currentUser?.uid ?? '';
                        if (h.isHidden) {
                          await FirestoreService.unhideHistory(h.id);
                          if (context.mounted) _showModSnack(context, 'HC visível novamente');
                        } else {
                          await FirestoreService.hideHistory(h.id, uid);
                          if (context.mounted) _showModSnack(context, 'HC ocultada da comunidade');
                        }
                        p.loadPublicHistories();
                      } : null,
                      onModDelete: canModerate ? () async {
                        final confirm = await _confirmModDelete(context);
                        if (!confirm) return;
                        await FirestoreService.adminDeletePublicHistory(h.id);
                        p.loadPublicHistories();
                        if (context.mounted) _showModSnack(context, 'HC excluída permanentemente', isError: true);
                      } : null,
                    );
                  },
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

  Future<bool> _confirmModDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir HC da Comunidade?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF07110d))),
        content: const Text(
          'Esta ação é permanente e remove a história clínica de todos os usuários.\n\nProceder com a exclusão?',
          style: TextStyle(fontSize: 13, color: Color(0xFF444444))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Excluir permanentemente'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showModSnack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
  // Controles de moderação (admin/supervisor)
  final VoidCallback? onModHide;
  final VoidCallback? onModDelete;
  const _HistoryCard({
    required this.h, required this.p, required this.onTap,
    this.onEdit, this.onDelete, this.onTogglePublic, this.readOnly = false,
    this.onModHide, this.onModDelete,
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
    return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
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
              // Banner de HC oculta (visível apenas para moderadores)
              if (h.isHidden) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.visibility_off_rounded, size: 12, color: Colors.orange),
                    const SizedBox(width: 6),
                    const Text('Oculta por moderador', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orange)),
                  ]),
                ),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.authorName.isNotEmpty ? h.authorName : 'Anônimo',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF333333), fontWeight: FontWeight.w700)),
                  if (h.authorEmail.isNotEmpty)
                    Text(h.authorEmail,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
                  if (h.uploadedAt.isNotEmpty)
                    Text(_formatUploadedAt(h.uploadedAt),
                      style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
                ])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Ver', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight)),
                ),
              ]),
              // Botões de moderação
              if (onModHide != null || onModDelete != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  if (onModHide != null)
                    GestureDetector(
                      onTap: onModHide,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.orange.withValues(alpha: 0.08),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(h.isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 12, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(h.isHidden ? 'Mostrar' : 'Ocultar',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orange)),
                        ]),
                      ),
                    ),
                  if (onModHide != null && onModDelete != null) const SizedBox(width: 8),
                  if (onModDelete != null)
                    GestureDetector(
                      onTap: onModDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.red.withValues(alpha: 0.07),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_forever_rounded, size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Excluir', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red)),
                        ]),
                      ),
                    ),
                ]),
              ],
            ],
          ]),
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISUALIZADOR COMPLETO
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryDetail extends StatefulWidget {
  final ClinicalHistoryModel history;
  final AppProvider p;
  final bool readOnly;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _HistoryDetail({required this.history, required this.p, required this.readOnly, required this.onBack, this.onEdit, this.onDelete});

  @override
  State<_HistoryDetail> createState() => _HistoryDetailState();
}

class _HistoryDetailState extends State<_HistoryDetail> {
  final _printKey = GlobalKey();
  bool _exporting = false;

  ClinicalHistoryModel get history => widget.history;
  AppProvider get p => widget.p;
  bool get readOnly => widget.readOnly;

  void _copy() {
    final buf = StringBuffer();
    buf.writeln('=== MEDCASES PRO — HISTÓRIA CLÍNICA ===');
    buf.writeln('Data: ${history.formattedDate}');
    if (history.authorName.isNotEmpty) buf.writeln('Autor: ${history.authorName}${history.authorEmail.isNotEmpty ? " (${history.authorEmail})" : ""}');
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

  // ── Exportar como PNG (web: download direto) ──────────────────────────────
  Future<void> _exportPng() async {
    setState(() => _exporting = true);
    try {
      final boundary = _printKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      _downloadBytes(bytes, '${_safeFilename()}.png', 'image/png');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PNG gerado — verifique seus downloads'), duration: Duration(seconds: 2)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar PNG: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Exportar como PDF (web: janela de impressão) ──────────────────────────
  void _exportPdf() {
    final buf = StringBuffer();
    buf.write('''<!DOCTYPE html><html><head>
<meta charset="utf-8">
<title>História Clínica — MedCases Pro</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Georgia, serif; font-size: 13px; color: #111; background: #fff; padding: 40px; line-height: 1.6; }
  .header { background: #07110d; color: #FFE8A6; padding: 20px 24px; border-radius: 10px; margin-bottom: 24px; }
  .header h1 { font-size: 22px; font-weight: 900; margin-bottom: 4px; }
  .header .meta { font-size: 11px; opacity: 0.75; }
  .section { margin-bottom: 18px; border: 1px solid #ddd; border-radius: 8px; padding: 14px 16px; }
  .section-title { font-size: 10px; font-weight: 900; letter-spacing: 1.5px; color: #555; text-transform: uppercase; margin-bottom: 8px; border-bottom: 1px solid #eee; padding-bottom: 6px; }
  .field-label { font-size: 9px; font-weight: 700; color: #888; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 2px; margin-top: 10px; }
  .field-value { font-size: 13px; color: #222; line-height: 1.6; }
  .dx-box { background: #ECFDF5; border: 1px solid #BBF7D0; border-radius: 8px; padding: 12px 14px; margin-bottom: 18px; }
  .dx-box h2 { font-size: 10px; font-weight: 900; color: #065F46; letter-spacing: 1.2px; margin-bottom: 4px; }
  .dx-box p { font-size: 16px; font-weight: 900; color: #064E3B; }
  .allergy-box { background: #FFF0F0; border: 1px solid #FFCCCC; border-radius: 8px; padding: 10px 12px; margin-top: 8px; }
  .allergy-box .label { color: #CC2222; font-size: 9px; font-weight: 900; letter-spacing: 1px; }
  .allergy-box p { color: #CC2222; font-weight: 700; }
  .author-row { font-size: 11px; color: #555; margin-top: 6px; }
  .evolution { border-left: 3px solid #C5A365; padding-left: 10px; margin-bottom: 12px; }
  .evolution .evo-meta { font-size: 10px; color: #888; font-weight: 700; }
  .outcome { display: inline-block; padding: 5px 12px; border-radius: 6px; font-size: 12px; font-weight: 900; background: #ECFDF5; color: #065F46; margin-bottom: 10px; }
  .footer { margin-top: 30px; font-size: 10px; color: #aaa; text-align: center; border-top: 1px solid #eee; padding-top: 12px; }
  @media print { body { padding: 20px; } }
</style>
</head><body>
<div class="header">
  <div class="meta">MedCases Pro • História Clínica</div>
  <h1>${_esc(history.displayTitle)}</h1>
  <div class="meta">${history.category} &nbsp;|&nbsp; ${history.formattedDate}</div>
  ${history.authorName.isNotEmpty ? '<div class="meta" style="margin-top:4px">Autor: ${_esc(history.authorName)}${history.authorEmail.isNotEmpty ? " &lt;${_esc(history.authorEmail)}&gt;" : ""}${history.uploadedAt.isNotEmpty ? " — Publicado: ${_formatUploadedAt(history.uploadedAt)}" : ""}</div>' : ''}
</div>
''');

    void section(String title, List<(String, String)> fields, {String? allergyText}) {
      final hasContent = fields.any((f) => f.$2.isNotEmpty) || (allergyText?.isNotEmpty ?? false);
      if (!hasContent) return;
      buf.write('<div class="section"><div class="section-title">$title</div>');
      if (allergyText != null && allergyText.isNotEmpty) {
        buf.write('<div class="allergy-box"><div class="label">⚠ ALERGIAS</div><p>${_esc(allergyText)}</p></div>');
      }
      for (final f in fields) {
        if (f.$2.isEmpty) continue;
        buf.write('<div class="field-label">${f.$1}</div><div class="field-value">${_escNl(f.$2)}</div>');
      }
      buf.write('</div>');
    }

    // ── 1. IDENTIFICAÇÃO DO PACIENTE ──────────────────────────────────────
    if (history.patientInitials.isNotEmpty || history.patientAge.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">1. Identificação do Paciente</div>');
      if (history.patientInitials.isNotEmpty)
        buf.write('<div class="field-label">Iniciais</div><div class="field-value">${_esc(history.patientInitials)}</div>');
      buf.write('<div class="field-label">Dados demográficos</div><div class="field-value">'
          '${history.patientAge.isNotEmpty ? "${history.patientAge} anos" : ""}${history.patientAge.isNotEmpty ? " • " : ""}${history.patientSex}'
          '${history.patientWeight.isNotEmpty ? " • ${history.patientWeight} kg" : ""}'
          '${history.patientHeight.isNotEmpty ? " • ${history.patientHeight} cm" : ""}'
          '${history.patientRecord.isNotEmpty ? " • Pront. ${_esc(history.patientRecord)}" : ""}'
          '</div>');
      buf.write('</div>');
    }

    // ── 2. QUEIXA PRINCIPAL ────────────────────────────────────────────────
    if (history.chiefComplaint.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">2. Queixa Principal</div>');
      buf.write('<div class="field-value" style="font-size:15px;font-weight:700">${_esc(history.chiefComplaint)}</div>');
      buf.write('</div>');
    }

    // ── 3. ANAMNESE ────────────────────────────────────────────────────────
    section('3. Anamnese', [
      ('História da doença atual', history.hpi),
      ('Antecedentes pessoais', history.pastHistory),
      ('Antecedentes familiares', history.familyHistory),
      ('História social (tabagismo, etilismo, ocupação)', history.socialHistory),
      ('Revisão de sistemas', history.reviewOfSystems),
      ('Medicamentos em uso', history.medications),
    ], allergyText: history.allergies);

    // ── 4. EXAME FÍSICO ────────────────────────────────────────────────────
    section('4. Exame Físico', [
      ('Sinais vitais', history.vitalSigns),
      ('Exame físico por sistemas', history.physicalExam),
    ]);

    // ── 5. HIPÓTESES DIAGNÓSTICAS ──────────────────────────────────────────
    if (history.workingDiagnosis.isNotEmpty || history.differentialDx.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">5. Hipóteses Diagnósticas</div>');
      if (history.workingDiagnosis.isNotEmpty) {
        buf.write('<div class="field-label">Hipótese principal</div>');
        buf.write('<div class="field-value" style="font-size:14px;font-weight:700;color:#064E3B">${_esc(history.workingDiagnosis)}</div>');
      }
      if (history.differentialDx.isNotEmpty) {
        buf.write('<div class="field-label" style="margin-top:10px">Diagnósticos diferenciais</div>');
        buf.write('<div class="field-value">${_escNl(history.differentialDx)}</div>');
      }
      buf.write('</div>');
    }

    // ── 6. EXAMES COMPLEMENTARES ──────────────────────────────────────────
    section('6. Exames Complementares', [
      ('Exames laboratoriais', history.labResults),
      ('ECG / Outros (biópsia, EEG...)', history.otherResults),
      ('Exames de imagem', history.imagingResults),
    ]);

    // ── 7. DIAGNÓSTICO FINAL ───────────────────────────────────────────────
    if (history.finalDiagnosis.isNotEmpty) {
      buf.write('<div class="dx-box">');
      buf.write('<h2>7. DIAGNÓSTICO FINAL</h2>');
      buf.write('<p>${_esc(history.finalDiagnosis)}</p>');
      if (history.cid.isNotEmpty)
        buf.write('<div style="font-size:12px;color:#065F46;margin-top:6px;font-weight:700">CID-10: ${_esc(history.cid)}</div>');
      buf.write('</div>');
    }

    // ── 8. CONDUTA / TRATAMENTO ────────────────────────────────────────────
    section('8. Conduta e Plano Terapêutico', [
      ('Plano terapêutico', history.treatmentPlan),
      ('Procedimentos realizados', history.procedures),
    ]);

    // ── 9. EVOLUÇÃO CLÍNICA ────────────────────────────────────────────────
    if (history.evolutions.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">9. Evolução Clínica</div>');
      for (final e in history.evolutions) {
        final dt = DateTime.tryParse(e.date)?.toLocal();
        final ds = dt != null
            ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
            : '';
        final typeMap = {'evolution': 'Evolução Médica', 'nursing': 'Nota de Enfermagem', 'lab': 'Resultado Lab', 'imaging': 'Laudo Imagem', 'procedure': 'Procedimento'};
        buf.write('<div class="evolution">');
        buf.write('<div class="evo-meta">${typeMap[e.type] ?? 'Evolução'} — $ds${e.author.isNotEmpty ? " — ${_esc(e.author)}" : ""}</div>');
        buf.write('<div class="field-value" style="margin-top:4px">${_escNl(e.text)}</div>');
        buf.write('</div>');
      }
      buf.write('</div>');
    }

    // ── 10. DESFECHO E ALTA ────────────────────────────────────────────────
    final outcomeMap = {'internado': 'Internado', 'alta': 'Alta hospitalar', 'obito': 'Óbito', 'transferencia': 'Transferência'};
    if (history.outcome != 'internado' || history.dischargeCondition.isNotEmpty || history.followUp.isNotEmpty) {
      buf.write('<div class="section"><div class="section-title">10. Desfecho e Alta</div>');
      buf.write('<div class="outcome">${outcomeMap[history.outcome] ?? history.outcome}</div>');
      if (history.dischargeCondition.isNotEmpty)
        buf.write('<div class="field-label">Condições de alta</div><div class="field-value">${_escNl(history.dischargeCondition)}</div>');
      if (history.followUp.isNotEmpty)
        buf.write('<div class="field-label">Seguimento / Orientações</div><div class="field-value">${_escNl(history.followUp)}</div>');
      buf.write('</div>');
    }

    buf.write('''<div class="footer">Gerado por MedCases Pro — Uso exclusivamente educacional e de apoio clínico. Não substitui avaliação médica individual presencial.</div>
</body></html>''');

    // Abre janela de impressão (PDF via browser)
    final blob = html.Blob([buf.toString()], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    // O usuário usa Ctrl+P / Imprimir do browser para gerar o PDF
    Future.delayed(const Duration(milliseconds: 1500), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  String _escNl(String s) => _esc(s).replaceAll('\n', '<br>');
  String _safeFilename() => 'HC_${history.displayTitle.replaceAll(RegExp(r'[^a-zA-Z0-9\u00C0-\u024F ]'), '').trim().replaceAll(' ', '_').substring(0, history.displayTitle.length.clamp(0, 30))}_${history.formattedDate.replaceAll('/', '-')}';

  void _downloadBytes(Uint8List bytes, String filename, String mime) {
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Botão voltar
        GestureDetector(
          onTap: widget.onBack,
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

        // Tudo que será capturado como PNG
        RepaintBoundary(
          key: _printKey,
          child: Container(
            color: const Color(0xFFF8F5EF),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Header hero
              PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(history.category.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xBFFFE8A6), letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text(history.displayTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                  ])),
                  if (!readOnly && widget.onEdit != null)
                    GestureDetector(
                      onTap: widget.onEdit,
                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1)), child: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFFFFE8A6))),
                    ),
                ]),
                // Linha do autor
                if (history.authorName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.person_outline_rounded, size: 11, color: Colors.white.withValues(alpha: 0.55)),
                    const SizedBox(width: 5),
                    Expanded(child: Text(
                      '${history.authorName}${history.authorEmail.isNotEmpty ? " • ${history.authorEmail}" : ""}${history.uploadedAt.isNotEmpty ? " • ${_formatUploadedAt(history.uploadedAt)}" : ""}',
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ],
                if (history.patientInitials.isNotEmpty || history.patientAge.isNotEmpty) ...[
                  const SizedBox(height: 10),
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
            ]),
          ),
        ),

        const SizedBox(height: 12),

        // ── Ações ────────────────────────────────────────────────────────────
        Row(children: [
          // Copiar HC
          Expanded(child: GestureDetector(
            onTap: _copy,
            child: Container(height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kDark, boxShadow: [BoxShadow(color: kDark.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0,4))]),
              child: const Center(child: Text('Copiar HC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGoldLight)))),
          )),
          const SizedBox(width: 8),
          // PDF
          GestureDetector(
            onTap: _exportPdf,
            child: Container(
              height: 48, width: 48,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF1E40AF), boxShadow: [BoxShadow(color: const Color(0xFF1E40AF).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0,3))]),
              child: const Center(child: Icon(Icons.picture_as_pdf_rounded, size: 20, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          // PNG
          GestureDetector(
            onTap: _exporting ? null : _exportPng,
            child: Container(
              height: 48, width: 48,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF065F46), boxShadow: [BoxShadow(color: const Color(0xFF065F46).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0,3))]),
              child: Center(child: _exporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.image_rounded, size: 20, color: Colors.white)),
            ),
          ),
          if (!readOnly && widget.onDelete != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onDelete,
              child: Container(height: 48, width: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFCCCC)), color: const Color(0xFFFFF0F0)),
                child: const Center(child: Icon(Icons.delete_rounded, size: 18, color: Color(0xFFCC2222)))),
            ),
          ],
        ]),

        // Legenda dos botões de exportação
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.info_outline_rounded, size: 11, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text('PDF abre janela de impressão  •  PNG salva imagem da HC', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500)),
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
    _sttRecog?.callMethod('stop', []);
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  // ── STT (Speech-to-Text via Web Speech API) ───────────────────────────────
  String? _sttActiveKey;   // chave do campo atualmente ouvindo
  bool _sttListening = false;
  String _sttInterim = '';
  js.JsObject? _sttRecog;

  void _startStt(String key) {
    // Toggle: parar se já está ouvindo este campo
    if (_sttListening && _sttActiveKey == key) {
      try { _sttRecog?.callMethod('stop', []); } catch (_) {}
      if (mounted) setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
      return;
    }
    // Se estava ouvindo outro campo, parar antes
    if (_sttListening) {
      try { _sttRecog?.callMethod('stop', []); } catch (_) {}
    }
    // Verificar suporte do browser via dart:js
    final jsWin = js.context;
    final hasSR = jsWin.hasProperty('SpeechRecognition') || jsWin.hasProperty('webkitSpeechRecognition');
    if (!hasSR) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(widget.p.t('dictation_not_supported')),
          content: Text(widget.p.t('dictation_browser_msg')),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    // Registrar bridge JS antes de criar a instância
    // Usa eval para injetar handler seguro que evita erros de cast no Dart
    try {
      js.context.callMethod('eval', ['''
        window.__sttBridge = function(transcript, isFinal) {};
      ''']);
    } catch (_) {}

    final ctorName = jsWin.hasProperty('SpeechRecognition') ? 'SpeechRecognition' : 'webkitSpeechRecognition';
    js.JsObject recog;
    try {
      recog = js.JsObject(jsWin[ctorName] as js.JsFunction, []);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar ditado: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final appLang = widget.p.lang;
    recog['lang'] = appLang == 'es' ? 'es-ES' : 'pt-BR';
    recog['continuous'] = true;
    recog['interimResults'] = true;
    recog['maxAlternatives'] = 1;

    // Usar callMethod para acessar resultados — mais seguro que cast direto
    recog['onresult'] = js.allowInterop((dynamic event) {
      try {
        final jsEvent = event as js.JsObject;
        final results = jsEvent['results'] as js.JsObject;
        final length = (results['length'] as num).toInt();
        String interim = '';
        // Percorrer apenas os novos resultados (a partir do resultIndex)
        final startIdx = jsEvent.hasProperty('resultIndex')
            ? (jsEvent['resultIndex'] as num).toInt()
            : 0;
        for (int i = startIdx; i < length; i++) {
          final result = js.JsObject.fromBrowserObject(results.callMethod('item', [i]) ?? results[i]);
          final isFinal = result['isFinal'] as bool? ?? false;
          final alt = js.JsObject.fromBrowserObject(result.callMethod('item', [0]) ?? result[0]);
          final transcript = alt['transcript'] as String? ?? '';
          if (isFinal) {
            final ctrl = _ctrls[key];
            if (ctrl != null && transcript.isNotEmpty) {
              final current = ctrl.text;
              final spacer = current.isNotEmpty && !current.endsWith(' ') && !current.endsWith('\n') ? ' ' : '';
              ctrl.text = current + spacer + transcript;
              ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
            }
          } else {
            interim += transcript;
          }
        }
        if (mounted) setState(() => _sttInterim = interim);
      } catch (e) {
        // Ignorar erros de parsing de resultados intermediários
      }
    });

    recog['onerror'] = js.allowInterop((dynamic event) {
      // Ignorar erros de 'no-speech' (usuário não falou nada) — não encerrar
      String? errorCode;
      try { errorCode = (event as js.JsObject)['error'] as String?; } catch (_) {}
      if (errorCode == 'no-speech') return; // continuar ouvindo
      if (mounted) setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
    });

    recog['onend'] = js.allowInterop((dynamic event) {
      // Se ainda está em modo listening (não foi parado manualmente), reiniciar
      // para simular modo contínuo (browsers param após silêncio)
      if (mounted && _sttListening && _sttActiveKey == key) {
        try { recog.callMethod('start', []); } catch (_) {
          setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
        }
      } else {
        if (mounted) setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; });
      }
    });

    try {
      recog.callMethod('start', []);
      _sttRecog = recog;
      if (mounted) setState(() { _sttListening = true; _sttActiveKey = key; _sttInterim = ''; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao iniciar microfone. Verifique as permissões do navegador.'), backgroundColor: Colors.red),
        );
      }
    }
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

      // ── Banner de ditado ativo ──────────────────────────────────────────
      if (_sttListening)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            // Ícone pulsante
            _PulseDot(),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ouvindo...', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFDC2626), letterSpacing: 0.5)),
              if (_sttInterim.isNotEmpty)
                Text(_sttInterim, style: const TextStyle(fontSize: 12, color: Color(0xFF555555), fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () { _sttRecog?.callMethod('stop', []); setState(() { _sttListening = false; _sttActiveKey = null; _sttInterim = ''; }); },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFDC2626).withValues(alpha: 0.12)),
                child: const Icon(Icons.mic_off_rounded, size: 16, color: Color(0xFFDC2626)),
              ),
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
    _EditorField('Queixa principal *', _ctrls['chiefComplaint']!, hint: 'Dor torácica há 2h', multiline: true, onMic: () => _startStt('chiefComplaint')),
    const SizedBox(height: 10),
    _EditorField('História da doença atual (HDA)', _ctrls['hpi']!, hint: 'Descrever cronologia, características, fatores...', multiline: true, lines: 5, onMic: () => _startStt('hpi')),
    const SizedBox(height: 10),
    _EditorField('Antecedentes pessoais', _ctrls['pastHistory']!, hint: 'HAS, DM2, IAM prévio, cirurgias...', multiline: true, onMic: () => _startStt('pastHistory')),
    const SizedBox(height: 10),
    _EditorField('Antecedentes familiares', _ctrls['familyHistory']!, hint: 'Pai: IAM aos 55 anos. Mãe: DM2...', multiline: true, onMic: () => _startStt('familyHistory')),
    const SizedBox(height: 10),
    _EditorField('História social', _ctrls['socialHistory']!, hint: 'Tabagismo, etilismo, drogas, atividade física, profissão...', multiline: true, onMic: () => _startStt('socialHistory')),
    const SizedBox(height: 10),
    _EditorField('Medicamentos em uso', _ctrls['medications']!, hint: 'AAS 100mg/dia, metformina 850mg 2x/dia...', multiline: true, onMic: () => _startStt('medications')),
    const SizedBox(height: 10),
    _EditorField('Alergias', _ctrls['allergies']!, hint: 'Penicilina (urticária), dipirona (angioedema)...', multiline: true, onMic: () => _startStt('allergies')),
    const SizedBox(height: 10),
    _EditorField('Revisão de sistemas', _ctrls['reviewOfSystems']!, hint: 'Cardiovascular, respiratório, GI, neurológico...', multiline: true, onMic: () => _startStt('reviewOfSystems')),
  ]);

  // ── Seção 2: Exame físico ──────────────────────────────────────────────────
  Widget _buildPhysicalExamSection() => Column(children: [
    // ── Sinais Vitais Estruturados ─────────────────────────────────────────
    _VitalSignsWidget(
      controller: _ctrls['vitalSigns']!,
      onMic: () => _startStt('vitalSigns'),
    ),
    const SizedBox(height: 10),
    _EditorField('Exame físico por sistemas', _ctrls['physicalExam']!, hint: 'Geral: BEG, corado, hidratado...\nCV: RCR 2T, sem sopros...\nTórax: MV+ bilateral, sem RA...\nAbdome: RHA+, indolor...', multiline: true, lines: 8, onMic: () => _startStt('physicalExam')),
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
    // ── Lab Estruturado + OCR ──────────────────────────────────────────────
    _LabStructuredWidget(controller: _ctrls['labResults']!),
    const SizedBox(height: 10),
    // ── ECG Estruturado ────────────────────────────────────────────────────
    _EcgStructuredWidget(controller: _ctrls['otherResults']!),
    const SizedBox(height: 10),
    // ── Exames de imagem ───────────────────────────────────────────────────
    _EditorField('Exames de imagem / Outros', _ctrls['imagingResults']!, hint: 'RX tórax: sem congestão, ICT normal...\nEco: FE 48%, hipocinesia anterior...\nTC crânio: sem lesões agudas...', multiline: true, lines: 5),
  ]);

  // ── Seção 4: Conduta / Tratamento ────────────────────────────────────────
  Widget _buildTreatmentSection() => Column(children: [
    _EditorField('Plano terapêutico / Conduta', _ctrls['treatmentPlan']!, hint: '1. AAS 300mg VO imediato\n2. Ticagrelor 180mg VO\n3. Heparina NF EV\n4. Ativar hemodinâmica (meta porta-balão < 90min)...', multiline: true, lines: 7, onMic: () => _startStt('treatmentPlan')),
    const SizedBox(height: 10),
    _EditorField('Procedimentos realizados', _ctrls['procedures']!, hint: 'Cateterismo + angioplastia com stent em DA proximal...', multiline: true, onMic: () => _startStt('procedures')),
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
  final VoidCallback? onMic;  // null = sem botão de mic
  const _EditorField(this.label, this.ctrl, {required this.hint, this.multiline = false, this.numeric = false, this.lines = 3, this.onMic});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
        if (onMic != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onMic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mic_rounded, size: 11, color: Color(0xFFDC2626)),
                SizedBox(width: 4),
                Text('Ditar', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
              ]),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 5),
      MedInput(controller: ctrl, hintText: hint, maxLines: multiline ? lines : 1,
        keyboardType: numeric ? TextInputType.number : multiline ? TextInputType.multiline : null),
    ]);
  }
}

// Widget de ponto pulsante para o banner de ditado
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDC2626))),
  );
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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
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

// ─────────────────────────────────────────────────────────────────────────────
// SINAIS VITAIS ESTRUTURADOS
// Campos pré-definidos; texto livre gerado automaticamente no controller
// ─────────────────────────────────────────────────────────────────────────────
class _VitalSignsWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onMic;
  const _VitalSignsWidget({required this.controller, this.onMic});
  @override
  State<_VitalSignsWidget> createState() => _VitalSignsWidgetState();
}

class _VitalSignsWidgetState extends State<_VitalSignsWidget> {
  final _pas   = TextEditingController();
  final _pad   = TextEditingController();
  final _fc    = TextEditingController();
  final _fr    = TextEditingController();
  final _temp  = TextEditingController();
  final _spo2  = TextEditingController();
  final _dext  = TextEditingController();
  final _peso  = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Parse existing text back into fields on open
    _parseExisting(widget.controller.text);
    for (final c in [_pas,_pad,_fc,_fr,_temp,_spo2,_dext,_peso]) {
      c.addListener(_syncToController);
    }
  }

  void _parseExisting(String text) {
    final regexPA  = RegExp(r'PA[:\s]+(\d+)[/\\](\d+)', caseSensitive: false);
    final regexFC  = RegExp(r'FC[:\s]+(\d+)', caseSensitive: false);
    final regexFR  = RegExp(r'FR[:\s]+(\d+)', caseSensitive: false);
    final regexT   = RegExp(r'[Tt]emp[:\s]+([\d,\.]+)', caseSensitive: false);
    final regexSp  = RegExp(r'SpO2[:\s]+([\d,\.]+)', caseSensitive: false);
    final regexDx  = RegExp(r'[Dd]extro[:\s]+([\d,\.]+)', caseSensitive: false);
    final regexP   = RegExp(r'[Pp]eso[:\s]+([\d,\.]+)', caseSensitive: false);
    final mPA  = regexPA.firstMatch(text);
    if (mPA != null) { _pas.text = mPA.group(1) ?? ''; _pad.text = mPA.group(2) ?? ''; }
    final mFC  = regexFC.firstMatch(text);  if (mFC  != null) _fc.text   = mFC.group(1)  ?? '';
    final mFR  = regexFR.firstMatch(text);  if (mFR  != null) _fr.text   = mFR.group(1)  ?? '';
    final mT   = regexT.firstMatch(text);   if (mT   != null) _temp.text = mT.group(1)   ?? '';
    final mSp  = regexSp.firstMatch(text);  if (mSp  != null) _spo2.text = mSp.group(1)  ?? '';
    final mDx  = regexDx.firstMatch(text);  if (mDx  != null) _dext.text = mDx.group(1)  ?? '';
    final mP   = regexP.firstMatch(text);   if (mP   != null) _peso.text = mP.group(1)   ?? '';
  }

  void _syncToController() {
    final parts = <String>[];
    if (_pas.text.isNotEmpty || _pad.text.isNotEmpty) parts.add('PA ${_pas.text.isNotEmpty ? _pas.text : "?"}/${_pad.text.isNotEmpty ? _pad.text : "?"} mmHg');
    if (_fc.text.isNotEmpty)   parts.add('FC ${_fc.text} bpm');
    if (_fr.text.isNotEmpty)   parts.add('FR ${_fr.text} irpm');
    if (_temp.text.isNotEmpty) parts.add('Temp ${_temp.text}°C');
    if (_spo2.text.isNotEmpty) parts.add('SpO2 ${_spo2.text}%');
    if (_dext.text.isNotEmpty) parts.add('Dextro ${_dext.text} mg/dL');
    if (_peso.text.isNotEmpty) parts.add('Peso ${_peso.text} kg');
    widget.controller.text = parts.join(' | ');
  }

  @override
  void dispose() {
    for (final c in [_pas,_pad,_fc,_fr,_temp,_spo2,_dext,_peso]) c.dispose();
    super.dispose();
  }

  Widget _vsField(String label, TextEditingController ctrl, String unit, {String hint = '', bool wide = false}) {
    return SizedBox(
      width: wide ? double.infinity : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFF888888))),
        const SizedBox(height: 3),
        Row(children: [
          SizedBox(
            width: wide ? 80 : 56,
            height: 36,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Text(unit, style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        color: const Color(0xFFF8FBFA),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.monitor_heart_rounded, size: 14, color: kGreen),
          const SizedBox(width: 6),
          const Text('SINAIS VITAIS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF555555))),
          const Spacer(),
          if (widget.onMic != null)
            GestureDetector(
              onTap: widget.onMic,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFDC2626).withValues(alpha: 0.08), border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.mic_rounded, size: 11, color: Color(0xFFDC2626)),
                  SizedBox(width: 3),
                  Text('Ditar', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        // Linha 1: PA (2 campos) + FC + FR
        Wrap(spacing: 10, runSpacing: 10, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFF888888))),
            const SizedBox(height: 3),
            Row(children: [
              SizedBox(width: 50, height: 36, child: TextField(
                controller: _pas, keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), hintText: '120',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5))),
              )),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Text('/', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300, color: Color(0xFF888888)))),
              SizedBox(width: 50, height: 36, child: TextField(
                controller: _pad, keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), hintText: '80',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5))),
              )),
              const SizedBox(width: 4),
              const Text('mmHg', style: TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w700)),
            ]),
          ]),
          _vsField('FC', _fc, 'bpm', hint: '80'),
          _vsField('FR', _fr, 'irpm', hint: '16'),
          _vsField('Temp', _temp, '°C', hint: '36,5'),
          _vsField('SpO₂', _spo2, '%', hint: '98'),
          _vsField('Dextro', _dext, 'mg/dL', hint: '100'),
          _vsField('Peso', _peso, 'kg', hint: '70', wide: true),
        ]),
        if (widget.controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF065F46).withValues(alpha: 0.06)),
            child: Text(widget.controller.text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ECG ESTRUTURADO
// ─────────────────────────────────────────────────────────────────────────────
class _EcgStructuredWidget extends StatefulWidget {
  final TextEditingController controller;
  const _EcgStructuredWidget({required this.controller});
  @override
  State<_EcgStructuredWidget> createState() => _EcgStructuredWidgetState();
}

class _EcgStructuredWidgetState extends State<_EcgStructuredWidget> {
  bool _expanded = false;
  String _ritmo = 'Sinusal';
  final _fc    = TextEditingController();
  final _pr    = TextEditingController();
  final _qrs   = TextEditingController();
  final _qt    = TextEditingController();
  final _eixo  = TextEditingController();
  final _st    = TextEditingController();
  final _outros = TextEditingController();

  static const _ritmos = ['Sinusal', 'FA', 'Flutter', 'BAV 1º', 'BAV 2º', 'BAV 3º', 'ESSV', 'TV', 'FV', 'Marcapasso', 'Outro'];

  @override
  void dispose() {
    for (final c in [_fc, _pr, _qrs, _qt, _eixo, _st, _outros]) c.dispose();
    super.dispose();
  }

  void _sync() {
    final parts = <String>[];
    parts.add('Ritmo: $_ritmo');
    if (_fc.text.isNotEmpty)    parts.add('FC: ${_fc.text} bpm');
    if (_pr.text.isNotEmpty)    parts.add('PR: ${_pr.text} ms');
    if (_qrs.text.isNotEmpty)   parts.add('QRS: ${_qrs.text} ms');
    if (_qt.text.isNotEmpty)    parts.add('QTc: ${_qt.text} ms');
    if (_eixo.text.isNotEmpty)  parts.add('Eixo: ${_eixo.text}°');
    if (_st.text.isNotEmpty)    parts.add('ST/T: ${_st.text}');
    if (_outros.text.isNotEmpty) parts.add('Outros: ${_outros.text}');
    widget.controller.text = 'ECG — ${parts.join(' | ')}';
    setState(() {});
  }

  Widget _numField(String label, TextEditingController ctrl, {String hint = ''}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
      const SizedBox(height: 3),
      SizedBox(width: 64, height: 34, child: TextField(
        controller: ctrl, keyboardType: TextInputType.number, onChanged: (_) => _sync(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), hintText: hint,
          hintStyle: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 1.5))),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: const Color(0xFFFFFBF2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header clicável
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
            const Icon(Icons.monitor_rounded, size: 14, color: kGold),
            const SizedBox(width: 6),
            const Text('ECG', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF555555))),
            const SizedBox(width: 8),
            if (widget.controller.text.isNotEmpty)
              Expanded(child: Text(widget.controller.text, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            const Spacer(),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: const Color(0xFF888888)),
          ])),
        ),
        if (_expanded) ...[
          const Divider(height: 1, color: kBorder),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Ritmo
            const Text('RITMO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
            const SizedBox(height: 6),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _ritmos.map((r) {
              final sel = r == _ritmo;
              return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                onTap: () { setState(() => _ritmo = r); _sync(); },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: sel ? kDark : Colors.white, border: Border.all(color: sel ? kDark : kBorder)),
                  child: Text(r, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sel ? kGoldLight : const Color(0xFF666666)))),
              ));
            }).toList())),
            const SizedBox(height: 10),
            // Intervalos
            Wrap(spacing: 10, runSpacing: 10, children: [
              _numField('FC (bpm)', _fc, hint: '72'),
              _numField('PR (ms)', _pr, hint: '160'),
              _numField('QRS (ms)', _qrs, hint: '90'),
              _numField('QTc (ms)', _qt, hint: '440'),
              _numField('Eixo (°)', _eixo, hint: '60'),
            ]),
            const SizedBox(height: 10),
            // ST livre
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ALTERAÇÕES ST/T', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
              const SizedBox(height: 3),
              TextField(controller: _st, onChanged: (_) => _sync(),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: 'Supra V1-V4, infra lateral, invertida...',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 1.5)))),
            ]),
            const SizedBox(height: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('OUTROS ACHADOS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
              const SizedBox(height: 3),
              TextField(controller: _outros, onChanged: (_) => _sync(),
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: 'BRD, BRE, HVE, ESSV, ondas Q...',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGold, width: 1.5)))),
            ]),
          ])),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LAB ESTRUTURADO + OCR via FILE INPUT
// ─────────────────────────────────────────────────────────────────────────────
class _LabStructuredWidget extends StatefulWidget {
  final TextEditingController controller;
  const _LabStructuredWidget({required this.controller});
  @override
  State<_LabStructuredWidget> createState() => _LabStructuredWidgetState();
}

class _LabStructuredWidgetState extends State<_LabStructuredWidget> {
  bool _expanded = false;
  bool _ocrLoading = false;
  String _ocrStatus = '';

  final _hb    = TextEditingController();
  final _ht    = TextEditingController();
  final _leuco = TextEditingController();
  final _plaq  = TextEditingController();
  final _na    = TextEditingController();
  final _k     = TextEditingController();
  final _cr    = TextEditingController();
  final _ur    = TextEditingController();
  final _gli   = TextEditingController();
  final _pcr   = TextEditingController();
  final _tni   = TextEditingController();
  final _bnp   = TextEditingController();
  final _lac   = TextEditingController();
  final _tp    = TextEditingController();
  final _tgo   = TextEditingController();
  final _tgp   = TextEditingController();
  final _outros = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final c in [_hb,_ht,_leuco,_plaq,_na,_k,_cr,_ur,_gli,_pcr,_tni,_bnp,_lac,_tp,_tgo,_tgp,_outros]) {
      c.addListener(_sync);
    }
  }

  @override
  void dispose() {
    for (final c in [_hb,_ht,_leuco,_plaq,_na,_k,_cr,_ur,_gli,_pcr,_tni,_bnp,_lac,_tp,_tgo,_tgp,_outros]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    final parts = <String>[];
    void add(String label, TextEditingController ctrl, String unit) {
      if (ctrl.text.isNotEmpty) parts.add('$label: ${ctrl.text} $unit'.trim());
    }
    add('Hb', _hb, 'g/dL'); add('Ht', _ht, '%'); add('Leuco', _leuco, '/mm³'); add('Plaq', _plaq, '×10³');
    add('Na⁺', _na, 'mEq/L'); add('K⁺', _k, 'mEq/L'); add('Cr', _cr, 'mg/dL'); add('Ur', _ur, 'mg/dL');
    add('Gli', _gli, 'mg/dL'); add('PCR', _pcr, 'mg/L'); add('TnI', _tni, 'ng/mL'); add('BNP', _bnp, 'pg/mL');
    add('Lactato', _lac, 'mmol/L'); add('TP', _tp, '%'); add('TGO', _tgo, 'U/L'); add('TGP', _tgp, 'U/L');
    if (_outros.text.isNotEmpty) parts.add(_outros.text.trim());
    widget.controller.text = parts.join('\n');
    if (mounted) setState(() {});
  }

  // ── OCR via File Input (Web) ──────────────────────────────────────────────
  void _openOcrPicker() {
    try {
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..style.display = 'none';
      html.document.body!.append(input);
      input.onChange.listen((e) async {
        final files = input.files;
        if (files == null || files.isEmpty) { input.remove(); return; }
        final file = files[0];
        setState(() { _ocrLoading = true; _ocrStatus = 'Lendo imagem...'; });
        // Ler como DataURL e usar API do browser
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((_) async {
          try {
            final dataUrl = reader.result as String;
            await _runOcr(dataUrl);
          } catch (err) {
            if (mounted) setState(() { _ocrLoading = false; _ocrStatus = 'Erro: $err'; });
          }
          input.remove();
        });
      });
      input.click();
    } catch (e) {
      if (mounted) setState(() { _ocrStatus = 'OCR não disponível: $e'; });
    }
  }

  // Simples OCR via heurística de texto da imagem usando tesseract.js via JS interop
  // Fallback: copia imagem para campo de texto livre para edição manual
  Future<void> _runOcr(String dataUrl) async {
    try {
      // Tenta usar tesseract.js se disponível no browser
      final hasTess = js.context.hasProperty('Tesseract');
      if (hasTess) {
        if (mounted) setState(() { _ocrStatus = 'Extraindo texto (OCR)...'; });
        final result = await js.JsObject.fromBrowserObject(
          js.context.callMethod('eval', [
            '''(function() { return Tesseract.recognize("$dataUrl", "por+spa").then(r => r.data.text); })()'''
          ])
        );
        final text = result?.toString() ?? '';
        _applyOcrText(text);
        if (mounted) setState(() { _ocrLoading = false; _ocrStatus = 'Texto extraído! Revise os campos.'; });
      } else {
        // Sem tesseract.js: copia texto de exemplo / abre para edição manual
        if (mounted) setState(() {
          _ocrLoading = false;
          _ocrStatus = 'Imagem carregada — preencha os campos manualmente ou instale Tesseract.js';
          // Deixa o campo "outros" pronto para edição
          _outros.text = '(Laudo de imagem — edite os valores acima)';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _ocrLoading = false; _ocrStatus = 'Falha OCR: $e'; });
    }
  }

  void _applyOcrText(String text) {
    // Heurística para extrair valores comuns de laudos
    final t = text.toLowerCase();
    void extract(TextEditingController c, List<String> patterns) {
      for (final p in patterns) {
        final m = RegExp('$p[:\\s]+(\\d+[,.]?\\d*)').firstMatch(t);
        if (m != null && c.text.isEmpty) { c.text = m.group(1)?.replaceAll(',', '.') ?? ''; break; }
      }
    }
    extract(_hb,   ['hemoglobina', 'hb']);
    extract(_ht,   ['hematocrito', 'ht']);
    extract(_leuco,['leucocitos', 'leuco', 'glóbulos blancos']);
    extract(_plaq, ['plaquetas', 'plaq', 'trombocitos']);
    extract(_na,   ['sodio', 'na']);
    extract(_k,    ['potasio', 'potássio', 'kalium', '\\bk\\b']);
    extract(_cr,   ['creatinina', 'cr']);
    extract(_ur,   ['ureia', 'urea', 'ur']);
    extract(_gli,  ['glicose', 'glucosa', 'glucose']);
    extract(_pcr,  ['pcr', 'proteina c reativa', 'proteína c reactiva']);
    extract(_tni,  ['troponina', 'tni', 'tnI']);
    extract(_bnp,  ['bnp', 'nt-probnp', 'proBNP']);
    extract(_lac,  ['lactato', 'lactic']);
    extract(_tp,   ['tp', 'tp%', 'atividade protrombinica']);
    extract(_tgo,  ['tgo', 'ast', 'aspartato']);
    extract(_tgp,  ['tgp', 'alt', 'alanino']);
    // Restante vai para "outros" se houver linhas relevantes
    if (_outros.text.isEmpty && text.length > 50) {
      _outros.text = text.substring(0, text.length > 300 ? 300 : text.length).trim();
    }
  }

  Widget _labField(String label, TextEditingController ctrl, String hint, {Color? flagColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF888888))),
      const SizedBox(height: 3),
      SizedBox(width: 68, height: 34, child: TextField(
        controller: ctrl, keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: flagColor ?? const Color(0xFF1A1A1A)),
        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7), hintText: hint,
          hintStyle: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flagColor?.withValues(alpha: 0.4) ?? kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flagColor?.withValues(alpha: 0.4) ?? kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: flagColor ?? const Color(0xFF065F46), width: 1.5))),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: const Color(0xFFF7FFFE)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
            const Icon(Icons.science_rounded, size: 14, color: Color(0xFF065F46)),
            const SizedBox(width: 6),
            const Text('EXAMES LABORATORIAIS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF555555))),
            const SizedBox(width: 8),
            if (widget.controller.text.isNotEmpty && !_expanded)
              const Expanded(child: Text('preenchido', style: TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.w700))),
            const Spacer(),
            // Botão OCR
            GestureDetector(
              onTap: _ocrLoading ? null : _openOcrPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF065F46).withValues(alpha: 0.08), border: Border.all(color: const Color(0xFF065F46).withValues(alpha: 0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_ocrLoading)
                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF065F46)))
                  else
                    const Icon(Icons.document_scanner_rounded, size: 11, color: Color(0xFF065F46)),
                  const SizedBox(width: 3),
                  Text(_ocrLoading ? 'Lendo...' : 'Foto/OCR', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: const Color(0xFF888888)),
          ])),
        ),
        if (_ocrStatus.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(_ocrStatus, style: TextStyle(fontSize: 10, color: _ocrStatus.startsWith('Erro') || _ocrStatus.startsWith('Falha') ? Colors.red : const Color(0xFF065F46), fontWeight: FontWeight.w700))),
        if (_expanded) ...[
          const Divider(height: 1, color: kBorder),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Hemograma
            const Text('HEMOGRAMA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFFAAAAAA))),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _labField('Hb (g/dL)', _hb, '12–16'),
              _labField('Ht (%)', _ht, '36–48'),
              _labField('Leuco (/mm³)', _leuco, '4–11k'),
              _labField('Plaq (×10³)', _plaq, '150–400'),
            ]),
            const SizedBox(height: 10),
            // Eletrólitos / Função Renal
            const Text('ELETRÓLITOS / FUNÇÃO RENAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFFAAAAAA))),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _labField('Na⁺ (mEq/L)', _na, '135–145'),
              _labField('K⁺ (mEq/L)', _k, '3.5–5.0'),
              _labField('Cr (mg/dL)', _cr, '<1.2'),
              _labField('Ur (mg/dL)', _ur, '15–40'),
              _labField('Gli (mg/dL)', _gli, '70–100'),
            ]),
            const SizedBox(height: 10),
            // Marcadores
            const Text('MARCADORES / OUTROS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFFAAAAAA))),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _labField('PCR (mg/L)', _pcr, '<5'),
              _labField('TnI (ng/mL)', _tni, '<0.04'),
              _labField('BNP (pg/mL)', _bnp, '<100'),
              _labField('Lactato', _lac, '<2.0'),
              _labField('TP (%)', _tp, '70–120'),
              _labField('TGO (U/L)', _tgo, '<40'),
              _labField('TGP (U/L)', _tgp, '<40'),
            ]),
            const SizedBox(height: 10),
            // Campo livre
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('OUTROS / OBSERVAÇÕES', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFFAAAAAA))),
              const SizedBox(height: 3),
              TextField(controller: _outros,
                maxLines: 3,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: 'Gasometria, hormônios, sorologia, culturas...',
                  hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)), filled: true, fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF065F46), width: 1.5)))),
            ]),
          ])),
        ],
        // Preview resumo
        if (widget.controller.text.isNotEmpty && !_expanded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF065F46).withValues(alpha: 0.06)),
              child: Text(widget.controller.text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF065F46), height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ]),
    );
  }
}
