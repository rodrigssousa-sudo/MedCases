// notes_screen.dart — Anotações pessoais do usuário
// Acesso via bottom sheet ou tela completa com push
// Dados salvos em Firestore: users/{uid}/notes
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../design_system/foundation/med_typography.dart';
import '../design_system/tokens/med_spacing.dart';
import 'home_screen.dart' show ClinicalTimerExternalBridge;

// ── Paleta de cores das notas (6 cores) ──────────────────────────────────────
class _NoteColor {
  final String hex;
  final Color light;
  final Color dark;
  final Color border;
  const _NoteColor({
    required this.hex,
    required this.light,
    required this.dark,
    required this.border,
  });
}

const _noteColors = [
  _NoteColor(
    hex: '#FFFEF0',
    light: Color(0xFFFFFEF0),
    dark: Color(0xFF2A2800),
    border: Color(0xFFE8E0A0),
  ),
  _NoteColor(
    hex: '#F0FFF4',
    light: Color(0xFFF0FFF4),
    dark: Color(0xFF002A0F),
    border: Color(0xFFA0DEB8),
  ),
  _NoteColor(
    hex: '#F0F4FF',
    light: Color(0xFFF0F4FF),
    dark: Color(0xFF00102A),
    border: Color(0xFFA0B8E8),
  ),
  _NoteColor(
    hex: '#FFF0F4',
    light: Color(0xFFFFF0F4),
    dark: Color(0xFF2A0010),
    border: Color(0xFFE8A0B8),
  ),
  _NoteColor(
    hex: '#FFF6F0',
    light: Color(0xFFFFF6F0),
    dark: Color(0xFF2A1200),
    border: Color(0xFFE8C0A0),
  ),
  _NoteColor(
    hex: '#F6F0FF',
    light: Color(0xFFF6F0FF),
    dark: Color(0xFF1A0028),
    border: Color(0xFFC0A0E8),
  ),
];

_NoteColor _colorFromHex(String hex) {
  return _noteColors.firstWhere(
    (c) => c.hex == hex,
    orElse: () => _noteColors[0],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point — abre como tela push
// ─────────────────────────────────────────────────────────────────────────────
void openNotesScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const NotesScreen()),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tela principal de anotações
// ─────────────────────────────────────────────────────────────────────────────
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _allNotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _search = _searchCtrl.text.toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  void _subscribe() {
    final uid = context.read<AppProvider>().currentUser?.uid ?? '';
    if (uid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _sub = FirestoreService.notesStream(uid).listen(
      (notes) {
        if (mounted) setState(() { _allNotes = notes; _loading = false; });
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _allNotes;
    return _allNotes.where((n) {
      final title   = (n['title'] as String? ?? '').toLowerCase();
      final content = (n['content'] as String? ?? '').toLowerCase();
      return title.contains(_search) || content.contains(_search);
    }).toList();
  }

  Future<void> _deleteNote(String noteId) async {
    final uid = context.read<AppProvider>().currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    await FirestoreService.deleteNote(uid: uid, noteId: noteId);
  }

  void _openEditor({Map<String, dynamic>? note}) {
    final uid = context.read<AppProvider>().currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final dark = context.read<AppProvider>().darkMode;
    final lang = context.read<AppProvider>().lang;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteEditorSheet(
        uid: uid,
        note: note,
        dark: dark,
        lang: lang,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final lang = p.lang;
    final isEs = lang == 'es';

    final bg      = dark ? const Color(0xFF1A1D23) : const Color(0xFFF5F6F8);
    final headerBg = dark ? const Color(0xFF2D3340) : const Color(0xFF0F1116);
    final searchBg = dark ? const Color(0xFF222222) : Colors.white;
    final searchBorder = dark ? const Color(0xFF374151) : const Color(0xFFE0E0E0);
    final textCol  = dark ? Colors.white : const Color(0xFF0F1116);
    final subCol   = dark ? Colors.white54 : Colors.black45;

    final notes = _filtered;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [const Color(0xFF0F1116), const Color(0xFF2D3340), const Color(0xFF1F3A28)]
                    : [const Color(0xFF0F1116), const Color(0xFF1B3D2A), const Color(0xFF10B981)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
          MedSpacing.screenHorizontalPadding,
          10,
          MedSpacing.screenHorizontalPadding,
          16,
        ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withOpacity(0.10),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEs ? 'Mis Anotaciones' : 'Minhas Anotações',
                              style: const TextStyle(
                                fontSize: MedTypography.screenTitleSize, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              _allNotes.isEmpty
                                  ? (isEs ? 'Sin anotaciones' : 'Nenhuma anotação')
                                  : '${_allNotes.length} ${isEs ? 'anotación${_allNotes.length != 1 ? 'es' : ''}' : 'anotaç${_allNotes.length != 1 ? 'ões' : 'ão'}'}',
                              style: TextStyle(
                                fontSize: MedTypography.microTextSize,
                                color: Colors.white.withOpacity(0.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // SUPER ORDEM MASTER 14 M10: ícone único minimalista Cyan
                      // Destruído: cápsula verde com texto "Nova/Nueva"
                      GestureDetector(
                        onTap: () => _openEditor(),
                        child: const Icon(
                          Icons.add,
                          size: 22,
                          color: Color(0xFF00E5FF), // Cyan Elétrico Neon
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    // Barra de busca
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: searchBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: searchBorder, width: 0.8),
                      ),
                      child: Row(children: [
                        const SizedBox(width: 12),
                        Icon(Icons.search_rounded, size: 16, color: subCol),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: TextStyle(fontSize: MedTypography.auxiliarySize, color: textCol),
                            decoration: InputDecoration(
                              hintText: isEs
                                  ? 'Buscar anotaciones...'
                                  : 'Buscar anotações...',
                              hintStyle: TextStyle(fontSize: MedTypography.auxiliarySize, color: subCol),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_search.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchCtrl.clear(),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Icon(Icons.close_rounded, size: 16, color: subCol),
                            ),
                          ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Corpo ────────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF10B981), strokeWidth: 2))
                : notes.isEmpty
                    ? _EmptyState(
                        dark: dark,
                        isEs: isEs,
                        hasSearch: _search.isNotEmpty,
                        onNew: () => _openEditor(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
          MedSpacing.screenHorizontalPadding,
          14,
          MedSpacing.screenHorizontalPadding,
          80,
        ),
                        itemCount: notes.length,
                        itemBuilder: (_, i) {
                          final note = notes[i];
                          return _NoteCard(
                            note: note,
                            dark: dark,
                            isEs: isEs,
                            onTap: () => _openEditor(note: note),
                            onDelete: () => _confirmDelete(context, note, isEs),
                          );
                        },
                      ),
          ),
        ],
      ),

      // FAB flutuante para nova nota
      floatingActionButton: _allNotes.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _openEditor(),
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add_rounded, size: 24),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, Map<String, dynamic> note, bool isEs) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        final dark = context.read<AppProvider>().darkMode;
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF252930) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFCC3333), size: 20),
            const SizedBox(width: 8),
            Text(
              isEs ? 'Eliminar anotación' : 'Excluir anotação',
              style: const TextStyle(
                fontSize: MedTypography.internalTitleSize, fontWeight: FontWeight.w800,
                color: Color(0xFFCC3333)),
            ),
          ]),
          content: Text(
            isEs
                ? '¿Eliminar esta anotación? Esta acción no se puede deshacer.'
                : 'Excluir esta anotação? Esta ação não pode ser desfeita.',
            style: TextStyle(
              fontSize: MedTypography.clinicalBodySize,
              color: dark ? Colors.white70 : const Color(0xFF444444),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(
                isEs ? 'Cancelar' : 'Cancelar',
                style: const TextStyle(color: Color(0xFF6B7280))),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFCC3333),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEs ? 'Eliminar' : 'Excluir'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _deleteNote(note['id'] as String);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de nota
// ─────────────────────────────────────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final bool dark;
  final bool isEs;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.dark,
    required this.isEs,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorHex = note['color'] as String? ?? '#FFFEF0';
    final nc = _colorFromHex(colorHex);
    final cardBg = dark ? nc.dark : nc.light;
    final cardBorder = dark
        ? nc.border.withOpacity(0.25)
        : nc.border.withOpacity(0.7);

    final title   = note['title']   as String? ?? '';
    final content = note['content'] as String? ?? '';
    final tags    = (note['tags'] as List<dynamic>?)?.cast<String>() ?? [];

    // Timestamp seguro
    String timeStr = '';
    final updatedAt = note['updatedAt'];
    if (updatedAt != null) {
      try {
        final dt = (updatedAt as dynamic).toDate() as DateTime;
        timeStr = _formatDate(dt);
      } catch (_) {}
    }

    final textMain = dark ? Colors.white.withOpacity(0.90) : const Color(0xFF1A1D23);
    final textSub  = dark ? Colors.white.withOpacity(0.45) : Colors.black38;

    return Dismissible(
      key: Key(note['id'] as String),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // deixa o dialog controlar a remoção real
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFCC3333).withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFCC3333).withOpacity(0.3)),
        ),
        child: const Icon(Icons.delete_outline_rounded,
          color: Color(0xFFCC3333), size: 22),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.20 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: MedTypography.internalTitleSize, fontWeight: FontWeight.w800,
                      color: textMain, height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Preview do conteúdo
              if (content.isNotEmpty)
                Text(
                  content,
                  style: TextStyle(
                    fontSize: MedTypography.clinicalBodySize, fontWeight: FontWeight.w400,
                    color: textMain.withOpacity(0.75), height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 10),
              // Rodapé: tags + timestamp
              Row(children: [
                if (tags.isNotEmpty) ...[
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: tags.take(3).map((tag) => Container(
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.black.withOpacity(dark ? 0.20 : 0.06),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: MedTypography.microTextSize, fontWeight: FontWeight.w600,
                              color: textSub),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: MedTypography.microTextSize, color: textSub, fontWeight: FontWeight.w500),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inHours < 1) return '${diff.inMinutes}min atrás';
    if (diff.inDays < 1) return '${diff.inHours}h atrás';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vazio
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final bool hasSearch;
  final VoidCallback onNew;

  const _EmptyState({
    required this.dark,
    required this.isEs,
    required this.hasSearch,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final textCol = dark ? Colors.white60 : const Color(0xFF666666);
    final subCol  = dark ? Colors.white30 : Colors.black38;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0xFF10B981).withOpacity(0.08),
              ),
              child: Center(
                child: Icon(
                  hasSearch
                      ? Icons.search_off_rounded
                      : Icons.edit_note_rounded,
                  size: 34,
                  color: dark
                      ? Colors.white24
                      : const Color(0xFF10B981).withOpacity(0.4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch
                  ? (isEs ? 'Sin resultados' : 'Nenhum resultado')
                  : (isEs ? 'Sin anotaciones aún' : 'Nenhuma anotação ainda'),
              style: TextStyle(
                fontSize: MedTypography.internalTitleSize, fontWeight: FontWeight.w800, color: textCol),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? (isEs
                      ? 'Intenta con otro término de búsqueda'
                      : 'Tente outro termo de busca')
                  : (isEs
                      ? 'Guarda notas de protocolos, casos, medicamentos o cualquier referencia clínica importante'
                      : 'Salve anotações de protocolos, casos, medicamentos ou qualquer referência clínica importante'),
              style: TextStyle(
                fontSize: MedTypography.auxiliarySize, color: subCol, height: 1.6),
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onNew,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF10B981),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded,
                      color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isEs ? 'Crear primera anotación'
                           : 'Criar primeira anotação',
                      style: const TextStyle(
                        fontSize: MedTypography.auxiliarySize, fontWeight: FontWeight.w700,
                        color: Colors.white),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor de nota (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
class NoteEditorSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic>? note; // null = nova nota
  final bool dark;
  final String lang;
  final Future<void> Function()? onDelete;

  const NoteEditorSheet({
    required this.uid,
    this.note,
    required this.dark,
    required this.lang,
    this.onDelete,
  });

  @override
  State<NoteEditorSheet> createState() => NoteEditorSheetState();
}

class NoteEditorSheetState extends State<NoteEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _tagCtrl;
  late String _selectedColor;
  late List<String> _tags;
  bool _saving = false;
  final _titleFocus   = FocusNode();
  final _contentFocus = FocusNode();

  // ── Alerta agendado (opcional) ────────────────────────────────────────────
  // null = sem alerta; valor = minutos a partir de "salvar"
  int? _alertMinutes;

  bool get _isNew => widget.note == null;
  bool get _isEs  => widget.lang == 'es';

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleCtrl   = TextEditingController(text: n?['title']   as String? ?? '');
    _contentCtrl = TextEditingController(text: n?['content'] as String? ?? '');
    _tagCtrl     = TextEditingController();
    _selectedColor = n?['color'] as String? ?? _noteColors[0].hex;
    _tags = List<String>.from(
        (n?['tags'] as List<dynamic>?)?.cast<String>() ?? []);

    // Abre teclado no título ao criar
    if (_isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final firstLine = content.split('\n').first.trim();
      final displayTitle = title.isEmpty
          ? firstLine.substring(0, firstLine.length.clamp(0, 40))
          : title;
      final savedNoteId = await FirestoreService.saveNote(
        uid: widget.uid,
        noteId: widget.note?['id'] as String?,
        title: displayTitle,
        content: content,
        color: _selectedColor,
        tags: _tags,
      );
      if (_alertMinutes != null && _alertMinutes! > 0) {
        final alertSeconds = _alertMinutes! * 60;
        final notifId = await NotificationService.scheduleNoteAlert(
          noteId: savedNoteId,
          noteTitle: displayTitle,
          seconds: alertSeconds,
          lang: widget.lang,
        );

        if (!mounted) {
          if (notifId != 0) {
            await NotificationService.cancel(notifId);
          }
          return;
        }

        final registration =
            await ClinicalTimerExternalBridge.adoptExistingNotification(
          notificationId: notifId,
          seconds: alertSeconds,
          label: displayTitle,
          payload: 'note:$savedNoteId',
          lang: widget.lang,
        );

        if (!registration.accepted) {
          if (notifId != 0) {
            await NotificationService.cancel(notifId);
          }
          if (!mounted) return;

          final messenger = ScaffoldMessenger.of(context);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  _isEs
                      ? 'Anotación guardada, pero el recordatorio no '
                          'pudo añadirse al Timer.'
                      : 'Anotação salva, mas o lembrete não pôde ser '
                          'adicionado ao Timer.',
                ),
              ),
            );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim()
        .replaceAll('#', '')
        .replaceAll(' ', '_')
        .toLowerCase();
    if (tag.isEmpty || _tags.contains(tag) || _tags.length >= 5) return;
    setState(() { _tags.add(tag); _tagCtrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    // NOTES V2.6B — EDITOR CLÍNICO HOME/TIMER
    final dark = widget.dark;
    final nc = _colorFromHex(_selectedColor);
    final panelBg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final surface = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final surfaceStrong = dark ? const Color(0xFF2D3340) : const Color(0xFFEFF2F5);
    final borderCol = dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);
    final accent = dark ? const Color(0xFF00C781) : const Color(0xFF008F66);
    final textCol = dark ? const Color(0xFFF3F4F6) : const Color(0xFF111318);
    final subCol = dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final deleteCol = dark ? const Color(0xFFF28B82) : const Color(0xFFB42318);
    final noteAccent = nc.border;
    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;

    InputDecoration fieldDecoration(String hint, {String? prefix}) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: subCol, fontSize: MedTypography.auxiliarySize, fontWeight: FontWeight.w500),
      prefixText: prefix,
      prefixStyle: TextStyle(color: subCol, fontSize: MedTypography.auxiliarySize, fontWeight: FontWeight.w700),
      border: InputBorder.none,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.92),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: borderCol, width: 0.8),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.fromLTRB(0, 10, 0, 5),
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: surfaceStrong, borderRadius: BorderRadius.circular(99)),
          ),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
            MedSpacing.screenHorizontalPadding,
            8,
            MedSpacing.screenHorizontalPadding,
            keyboardH + 24,
          ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 4, height: 38, decoration: BoxDecoration(color: noteAccent, borderRadius: BorderRadius.circular(99))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _isNew ? (_isEs ? 'Nueva anotación' : 'Nova anotação') : (_isEs ? 'Editar anotación' : 'Editar anotação'),
                      style: TextStyle(color: textCol, fontSize: MedTypography.internalTitleSize, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isEs ? 'Información clínica personal' : 'Informação clínica pessoal',
                      style: TextStyle(color: subCol, fontSize: MedTypography.auxiliarySize, fontWeight: FontWeight.w600),
                    ),
                  ])),
                  if (!_isNew && widget.onDelete != null)
                    IconButton(
                      tooltip: _isEs ? 'Eliminar' : 'Excluir',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: borderCol, width: 0.8),
                            ),
                            title: Text(
                              _isEs ? 'Eliminar nota' : 'Excluir anotação',
                              style: TextStyle(color: textCol, fontSize: MedTypography.internalTitleSize, fontWeight: FontWeight.w800),
                            ),
                            content: Text(
                              _isEs ? '¿Eliminar esta nota?' : 'Deseja excluir esta anotação?',
                              style: TextStyle(color: subCol, fontSize: MedTypography.clinicalBodySize),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: Text('Cancelar', style: TextStyle(color: subCol, fontWeight: FontWeight.w700)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                child: Text(_isEs ? 'Eliminar' : 'Excluir', style: TextStyle(color: deleteCol, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        final delete = widget.onDelete;
                        if (delete == null) return;
                        await delete();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.delete_outline_rounded, color: deleteCol, size: 19),
                    ),
                ]),
                const SizedBox(height: 15),
                Text(
                  _isEs ? 'Identificación visual' : 'Identificação visual',
                  style: TextStyle(color: subCol, fontSize: MedTypography.sectionLabelSize, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol, width: 0.8)),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _noteColors.map((option) {
                      final selected = _selectedColor == option.hex;
                      final chipColor = option.border;
                      return InkWell(
                        onTap: () => setState(() => _selectedColor = option.hex),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: selected ? 36 : 32,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: surfaceStrong,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: selected ? chipColor : borderCol, width: selected ? 1.8 : 0.8),
                          ),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle),
                            child: selected ? const Icon(Icons.check_rounded, size: 9, color: Colors.white) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol, width: 0.8)),
                  child: TextField(
                    controller: _titleCtrl,
                    focusNode: _titleFocus,
                    enableSuggestions: true,
                    autocorrect: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _contentFocus.requestFocus(),
                    style: TextStyle(color: textCol, fontSize: MedTypography.clinicalBodySize, fontWeight: FontWeight.w700),
                    decoration: fieldDecoration('Título (opcional)'),
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  constraints: const BoxConstraints(minHeight: 128),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderCol, width: 0.8)),
                  child: TextField(
                    controller: _contentCtrl,
                    focusNode: _contentFocus,
                    maxLines: null,
                    minLines: 5,
                    keyboardType: TextInputType.multiline,
                    enableSuggestions: true,
                    autocorrect: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: textCol, fontSize: MedTypography.clinicalBodySize, fontWeight: FontWeight.w500, height: 1.45),
                    decoration: fieldDecoration(_isEs ? 'Escribe tu anotación aquí...' : 'Escreva sua anotação aqui...'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isEs ? 'Etiquetas (opcional)' : 'Tags (opcional)',
                  style: TextStyle(color: subCol, fontSize: MedTypography.sectionLabelSize, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
                const SizedBox(height: 8),
                if (_tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tags.map((tag) => InkWell(
                      onTap: () => setState(() => _tags.remove(tag)),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(color: surfaceStrong, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol, width: 0.8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('#$tag', style: TextStyle(color: textCol, fontSize: MedTypography.microTextSize, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Icon(Icons.close_rounded, size: 12, color: subCol),
                        ]),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_tags.length < 5)
                  Row(children: [
                    Expanded(child: Container(
                      height: 40,
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderCol, width: 0.7)),
                      child: TextField(
                        controller: _tagCtrl,
                        style: TextStyle(color: textCol, fontSize: MedTypography.auxiliarySize),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTag(),
                        decoration: fieldDecoration('protocolo, caso, fármaco...', prefix: '#'),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Material(
                      color: surfaceStrong,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: _addTag,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: borderCol, width: 0.7)),
                          child: Icon(Icons.add_rounded, color: accent, size: 19),
                        ),
                      ),
                    ),
                  ]),
                const SizedBox(height: 16),
                _NoteAlertPicker(
                  dark: dark,
                  isEs: _isEs,
                  selectedMinutes: _alertMinutes,
                  onChanged: (value) => setState(() => _alertMinutes = value),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: accent.withValues(alpha: 0.4),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEs ? 'Guardar anotación' : 'Salvar anotação', style: const TextStyle(fontSize: MedTypography.auxiliarySize, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seletor de alerta para anotação
// ─────────────────────────────────────────────────────────────────────────────
class _NoteAlertPicker extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final int? selectedMinutes;
  final void Function(int?) onChanged;

  const _NoteAlertPicker({
    required this.dark,
    required this.isEs,
    required this.selectedMinutes,
    required this.onChanged,
  });

  static const _options = <int?>[null, 5, 10, 15, 30, 60, 120, 240];

  String _label(int? minutes) {
    if (minutes == null) return isEs ? 'Sin recordatorio' : 'Sem lembrete';
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h';
  }

  @override
  Widget build(BuildContext context) {
    // NOTES V2.6B — LEMBRETE DE ANOTAÇÃO, NÃO TIMER CLÍNICO
    final surface = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final surfaceStrong = dark ? const Color(0xFF2D3340) : const Color(0xFFEFF2F5);
    final borderCol = dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);
    final accent = dark ? const Color(0xFF00C781) : const Color(0xFF008F66);
    final textCol = dark ? const Color(0xFFF3F4F6) : const Color(0xFF111318);
    final subCol = dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderCol, width: 0.7),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: surfaceStrong, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol, width: 0.7)),
            child: Icon(
              selectedMinutes == null ? Icons.notifications_none_rounded : Icons.notifications_active_outlined,
              color: selectedMinutes == null ? subCol : accent,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isEs ? 'Recordatorio de la anotación' : 'Lembrete da anotação',
              style: TextStyle(color: textCol, fontSize: MedTypography.sectionLabelSize, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              isEs ? 'Notificación vinculada a esta nota' : 'Notificação vinculada a esta nota',
              style: TextStyle(color: subCol, fontSize: MedTypography.auxiliarySize, fontWeight: FontWeight.w500),
            ),
          ])),
          if (selectedMinutes != null)
            Text(_label(selectedMinutes), style: TextStyle(color: accent, fontSize: MedTypography.auxiliarySize, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _options.map((option) {
            final selected = selectedMinutes == option;
            return Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Material(
                color: selected ? accent : surfaceStrong,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onChanged(option),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? accent : borderCol, width: 0.8),
                    ),
                    child: Text(
                      _label(option),
                      style: TextStyle(color: selected ? Colors.white : textCol, fontSize: MedTypography.auxiliarySize, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            );
          }).toList()),
        ),
      ]),
    );
  }
}
