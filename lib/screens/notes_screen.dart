// notes_screen.dart — Anotações pessoais do usuário
// Acesso via bottom sheet ou tela completa com push
// Dados salvos em Firestore: users/{uid}/notes
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

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

    final bg      = dark ? const Color(0xFF141414) : const Color(0xFFF5F6F8);
    final headerBg = dark ? const Color(0xFF1A2820) : const Color(0xFF0F1C14);
    final searchBg = dark ? const Color(0xFF222222) : Colors.white;
    final searchBorder = dark ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
    final textCol  = dark ? Colors.white : const Color(0xFF0F1C14);
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
                    ? [const Color(0xFF0F1C14), const Color(0xFF1A2820), const Color(0xFF1F3A28)]
                    : [const Color(0xFF0F1C14), const Color(0xFF1B3D2A), const Color(0xFF1F6B48)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                            color: Colors.white.withValues(alpha: 0.10),
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
                                fontSize: 18, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              _allNotes.isEmpty
                                  ? (isEs ? 'Sin anotaciones' : 'Nenhuma anotação')
                                  : '${_allNotes.length} ${isEs ? 'anotación${_allNotes.length != 1 ? 'es' : ''}' : 'anotaç${_allNotes.length != 1 ? 'ões' : 'ão'}'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Botão nova nota
                      GestureDetector(
                        onTap: () => _openEditor(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFF1F6B48),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1F6B48).withValues(alpha: 0.40),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              isEs ? 'Nueva' : 'Nova',
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ]),
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
                            style: TextStyle(fontSize: 13, color: textCol),
                            decoration: InputDecoration(
                              hintText: isEs
                                  ? 'Buscar anotaciones...'
                                  : 'Buscar anotações...',
                              hintStyle: TextStyle(fontSize: 13, color: subCol),
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
                      color: Color(0xFF1F6B48), strokeWidth: 2))
                : notes.isEmpty
                    ? _EmptyState(
                        dark: dark,
                        isEs: isEs,
                        hasSearch: _search.isNotEmpty,
                        onNew: () => _openEditor(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
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
              backgroundColor: const Color(0xFF1F6B48),
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
          backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFCC3333), size: 20),
            const SizedBox(width: 8),
            Text(
              isEs ? 'Eliminar anotación' : 'Excluir anotação',
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: Color(0xFFCC3333)),
            ),
          ]),
          content: Text(
            isEs
                ? '¿Eliminar esta anotación? Esta acción no se puede deshacer.'
                : 'Excluir esta anotação? Esta ação não pode ser desfeita.',
            style: TextStyle(
              fontSize: 13,
              color: dark ? Colors.white70 : const Color(0xFF444444),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(
                isEs ? 'Cancelar' : 'Cancelar',
                style: const TextStyle(color: Color(0xFF888888))),
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
        ? nc.border.withValues(alpha: 0.25)
        : nc.border.withValues(alpha: 0.7);

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

    final textMain = dark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF1A1A1A);
    final textSub  = dark ? Colors.white.withValues(alpha: 0.45) : Colors.black38;

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
          color: const Color(0xFFCC3333).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFCC3333).withValues(alpha: 0.3)),
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
                color: Colors.black.withValues(alpha: dark ? 0.20 : 0.05),
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
                      fontSize: 14, fontWeight: FontWeight.w800,
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
                    fontSize: 12.5, fontWeight: FontWeight.w400,
                    color: textMain.withValues(alpha: 0.75), height: 1.5,
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
                            color: Colors.black.withValues(alpha:
                              dark ? 0.20 : 0.06),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600,
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
                    fontSize: 10, color: textSub, fontWeight: FontWeight.w500),
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
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFF1F6B48).withValues(alpha: 0.08),
              ),
              child: Center(
                child: Icon(
                  hasSearch
                      ? Icons.search_off_rounded
                      : Icons.edit_note_rounded,
                  size: 34,
                  color: dark
                      ? Colors.white24
                      : const Color(0xFF1F6B48).withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch
                  ? (isEs ? 'Sin resultados' : 'Nenhum resultado')
                  : (isEs ? 'Sin anotaciones aún' : 'Nenhuma anotação ainda'),
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: textCol),
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
                fontSize: 12.5, color: subCol, height: 1.6),
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
                    color: const Color(0xFF1F6B48),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1F6B48).withValues(alpha: 0.35),
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
                        fontSize: 13, fontWeight: FontWeight.w700,
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

  const NoteEditorSheet({
    required this.uid,
    this.note,
    required this.dark,
    required this.lang,
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
    final title   = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final noteId = widget.note?['id'] as String?
          ?? DateTime.now().millisecondsSinceEpoch.toString();
      final displayTitle = title.isEmpty
          ? (content.split('\n').first.substring(0, content.length.clamp(0, 40)))
          : title;

      await FirestoreService.saveNote(
        uid:     widget.uid,
        noteId:  widget.note?['id'] as String?,
        title:   displayTitle,
        content: content,
        color:   _selectedColor,
        tags:    _tags,
      );

      // Agenda notificação se alerta foi configurado
      if (_alertMinutes != null && _alertMinutes! > 0) {
        await NotificationService.scheduleNoteAlert(
          noteId:    noteId,
          noteTitle: displayTitle,
          seconds:   _alertMinutes! * 60,
          lang:      widget.lang,
        );
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
    final dark = widget.dark;
    final nc   = _colorFromHex(_selectedColor);
    final sheetBg = dark ? const Color(0xFF1A1A1A) : Colors.white;
    final textCol = dark ? Colors.white : const Color(0xFF1A1A1A);
    final subCol  = dark ? Colors.white38 : Colors.black38;
    final divCol  = dark ? Colors.white12 : Colors.black.withValues(alpha: 0.07);
    final inputBg = dark ? nc.dark.withValues(alpha: 0.6) : nc.light;
    final borderCol = dark
        ? nc.border.withValues(alpha: 0.20)
        : nc.border.withValues(alpha: 0.60);

    final keyboardH = MediaQuery.viewInsetsOf(context).bottom;
    final screenH   = MediaQuery.sizeOf(context).height;

    return GestureDetector(
      // Fecha ao tocar fora dos campos
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // Altura máxima = 92% da tela, para que o sheet não ultrapasse
        // e o scroll interno funcione quando o teclado estiver aberto
        constraints: BoxConstraints(maxHeight: screenH * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle sempre visível no topo ─────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            // ── Conteúdo rolável ───────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 8, 20, keyboardH + 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

              // Título da sheet
              Row(children: [
                Expanded(
                  child: Text(
                    _isNew
                        ? (_isEs ? 'Nueva anotación' : 'Nova anotação')
                        : (_isEs ? 'Editar anotación' : 'Editar anotação'),
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: textCol),
                  ),
                ),
                if (!_isNew)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      // Notifica o pai para deletar
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.delete_outline_rounded,
                        size: 18, color: const Color(0xFFCC3333)),
                    ),
                  ),
              ]),

              const SizedBox(height: 16),

              // ── Seletor de cor ───────────────────────────────────────────
              Row(children: [
                Text(
                  _isEs ? 'Color:' : 'Cor:',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: subCol, letterSpacing: 0.5),
                ),
                const SizedBox(width: 10),
                ..._noteColors.map((nc2) => GestureDetector(
                  onTap: () => setState(() => _selectedColor = nc2.hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    width: _selectedColor == nc2.hex ? 26 : 22,
                    height: _selectedColor == nc2.hex ? 26 : 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark ? nc2.dark : nc2.light,
                      border: Border.all(
                        color: _selectedColor == nc2.hex
                            ? (dark ? Colors.white60 : const Color(0xFF0F1C14))
                            : nc2.border.withValues(alpha: 0.5),
                        width: _selectedColor == nc2.hex ? 2.5 : 1.0,
                      ),
                    ),
                    child: _selectedColor == nc2.hex
                        ? Icon(Icons.check_rounded,
                            size: 13,
                            color: dark ? Colors.white70 : const Color(0xFF0F1C14))
                        : null,
                  ),
                )),
              ]),

              const SizedBox(height: 14),

              // ── Campo de título ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: TextField(
                  controller: _titleCtrl,
                  focusNode: _titleFocus,
                  enableSuggestions: true,
                  autocorrect: true,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: textCol),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _contentFocus.requestFocus(),
                  decoration: InputDecoration(
                    hintText: _isEs ? 'Título (opcional)' : 'Título (opcional)',
                    hintStyle: TextStyle(
                      fontSize: 14, color: subCol,
                      fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Campo de conteúdo ────────────────────────────────────────
              Container(
                constraints: const BoxConstraints(minHeight: 120),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: TextField(
                  controller: _contentCtrl,
                  focusNode: _contentFocus,
                  maxLines: null,
                  minLines: 5,
                  keyboardType: TextInputType.multiline,
                  enableSuggestions: true,
                  autocorrect: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w400,
                    color: textCol, height: 1.6),
                  decoration: InputDecoration(
                    hintText: _isEs
                        ? 'Escribe tu anotación aquí...'
                        : 'Escreva sua anotação aqui...',
                    hintStyle: TextStyle(
                      fontSize: 13, color: subCol,
                      fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              Divider(color: divCol, height: 1),
              const SizedBox(height: 12),

              // ── Campo de tags ────────────────────────────────────────────
              Text(
                _isEs ? 'Etiquetas (opcional)' : 'Tags (opcional)',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: subCol, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),

              if (_tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tags.map((tag) => GestureDetector(
                    onTap: () => setState(() => _tags.remove(tag)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: const Color(0xFF1F6B48).withValues(alpha: 0.12),
                        border: Border.all(
                          color: const Color(0xFF1F6B48).withValues(alpha: 0.30)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          '#$tag',
                          style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: Color(0xFF1F6B48)),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close_rounded,
                          size: 12,
                          color: const Color(0xFF1F6B48).withValues(alpha: 0.7)),
                      ]),
                    ),
                  )).toList(),
                ),

              if (_tags.length < 5) ...[
                if (_tags.isNotEmpty) const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: dark ? const Color(0xFF242424) : const Color(0xFFF5F5F5),
                        border: Border.all(color: divCol),
                      ),
                      child: TextField(
                        controller: _tagCtrl,
                        style: TextStyle(fontSize: 12, color: textCol),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTag(),
                        decoration: InputDecoration(
                          hintText: _isEs ? 'protocolo, caso, fármaco...' : 'protocolo, caso, fármaco...',
                          hintStyle: TextStyle(fontSize: 12, color: subCol),
                          border: InputBorder.none,
                          prefixText: '#',
                          prefixStyle: TextStyle(
                            fontSize: 12, color: subCol,
                            fontWeight: FontWeight.w700),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _addTag,
                    child: Container(
                      height: 38, width: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: const Color(0xFF1F6B48).withValues(alpha: 0.12),
                        border: Border.all(
                          color: const Color(0xFF1F6B48).withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.add_rounded,
                        size: 18, color: Color(0xFF1F6B48)),
                    ),
                  ),
                ]),
              ],

              const SizedBox(height: 20),

              // ── Alerta agendado (opcional) ───────────────────────────────
              _NoteAlertPicker(
                dark:          widget.dark,
                isEs:          _isEs,
                selectedMinutes: _alertMinutes,
                onChanged:     (v) => setState(() => _alertMinutes = v),
              ),

              const SizedBox(height: 20),

              // ── Botão salvar ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F6B48),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF1F6B48).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                      : Text(
                          _isEs ? 'Guardar anotación' : 'Salvar anotação',
                          style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                ),
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

  // Opções de tempo: null = sem alerta, outros = minutos
  static const _options = <int?>[null, 5, 10, 15, 30, 60, 120, 240];

  String _label(int? m) {
    if (m == null) return isEs ? 'Sin alerta' : 'Sem alerta';
    if (m < 60) return '${m} min';
    return '${m ~/ 60}h';
  }

  @override
  Widget build(BuildContext context) {
    final subCol  = dark ? Colors.white38 : Colors.black38;
    final divCol  = dark ? Colors.white12 : Colors.black.withValues(alpha: 0.07);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: divCol, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Icon(
            selectedMinutes != null
                ? Icons.alarm_on_rounded
                : Icons.alarm_add_rounded,
            size: 15,
            color: selectedMinutes != null
                ? const Color(0xFF1F6B48)
                : subCol,
          ),
          const SizedBox(width: 6),
          Text(
            isEs ? 'Alerta (opcional)' : 'Alerta (opcional)',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: selectedMinutes != null
                  ? const Color(0xFF1F6B48)
                  : subCol,
              letterSpacing: 0.5,
            ),
          ),
          if (selectedMinutes != null) ...[
            const Spacer(),
            Text(
              isEs
                  ? 'en ${_label(selectedMinutes)}'
                  : 'em ${_label(selectedMinutes)}',
              style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: Color(0xFF1F6B48),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        // Chips de opções
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _options.map((opt) {
              final selected = selectedMinutes == opt;
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 7),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: selected
                        ? const Color(0xFF1F6B48)
                        : (dark
                            ? Colors.white.withValues(alpha: 0.07)
                            : const Color(0xFFF0F0F0)),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF1F6B48)
                          : (dark
                              ? Colors.white.withValues(alpha: 0.10)
                              : const Color(0xFFDDDDDD)),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (selected && opt != null) ...[
                      const Icon(Icons.alarm_rounded, size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _label(opt),
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : (dark ? Colors.white54 : const Color(0xFF666666)),
                      ),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
