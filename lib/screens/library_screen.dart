import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/firestore_service.dart';
import '../models/guide_model.dart';
import '../widgets/common_widgets.dart';

const _kDark  = Color(0xFF07110d);
const _kGreen = Color(0xFF075f45);
const _kGold  = Color(0xFFC5A365);
const _kGoldL = Color(0xFFFFE8A6);

// ─────────────────────────────────────────────────────────────────────────────
// LIBRARY SCREEN — Biblioteca Clínica (PDFs / Guias)
// ─────────────────────────────────────────────────────────────────────────────
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  String _search    = '';
  String _category  = 'Todos';

  StreamSubscription<List<GuideModel>>? _sub;
  List<GuideModel> _guides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = FirestoreService.guidesStream().listen((list) {
      if (mounted) setState(() { _guides = list; _loading = false; });
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _search = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GuideModel> get _filtered {
    return _guides.where((g) {
      final matchCat  = _category == 'Todos' || g.category == _category;
      final matchText = _search.isEmpty ||
          g.title.toLowerCase().contains(_search) ||
          g.description.toLowerCase().contains(_search) ||
          g.authors.toLowerCase().contains(_search) ||
          g.category.toLowerCase().contains(_search);
      return matchCat && matchText;
    }).toList();
  }

  List<String> get _categories {
    final cats = {'Todos', ..._guides.map((g) => g.category)};
    return cats.toList();
  }

  Future<void> _openPdf(GuideModel g) async {
    final uri = Uri.tryParse(g.pdfUrl);
    if (uri == null || g.pdfUrl.isEmpty) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      FirestoreService.incrementGuideDownload(g.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';
    final bg   = dark ? const Color(0xFF0A130E) : const Color(0xFFF7F8FA);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        _LibraryHeader(dark: dark, isEs: isEs),

        // ── Filtro de categoria ──────────────────────────────────────────────
        if (_categories.length > 1)
          _CategoryFilter(
            categories: _categories,
            selected: _category,
            dark: dark,
            onSelect: (c) => setState(() => _category = c),
          ),

        // ── Busca ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: isEs ? 'Buscar guías...' : 'Buscar guias...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // ── Lista ────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2))
              : filtered.isEmpty
                  ? _EmptyState(dark: dark, isEs: isEs, hasSearch: _search.isNotEmpty)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _GuideCard(
                        guide: filtered[i],
                        dark: dark,
                        onOpen: () => _openPdf(filtered[i]),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _LibraryHeader extends StatelessWidget {
  final bool dark;
  final bool isEs;
  const _LibraryHeader({required this.dark, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kDark,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _kGreen.withValues(alpha: 0.3),
                border: Border.all(color: _kGreen.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.menu_book_rounded, color: _kGoldL, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isEs ? 'Biblioteca Clínica' : 'Biblioteca Clínica',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  isEs ? 'Guías • Protocolos • Artículos' : 'Guias • Protocolos • Artigos',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTRO DE CATEGORIA
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryFilter extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final bool dark;
  final ValueChanged<String> onSelect;
  const _CategoryFilter({
    required this.categories, required this.selected,
    required this.dark, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat    = categories[i];
          final active = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active
                    ? _kGreen
                    : (dark ? const Color(0xFF1A2820) : Colors.white),
                border: Border.all(
                  color: active ? _kGreen : (dark ? Colors.white12 : Colors.black12),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : (dark ? Colors.white60 : Colors.black54),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE GUIA
// ─────────────────────────────────────────────────────────────────────────────
class _GuideCard extends StatelessWidget {
  final GuideModel guide;
  final bool dark;
  final VoidCallback onOpen;
  const _GuideCard({required this.guide, required this.dark, required this.onOpen});

  Color get _categoryColor {
    switch (guide.category) {
      case 'Emergência':      return const Color(0xFFEF4444);
      case 'Cardiologia':     return const Color(0xFFEC4899);
      case 'Infectologia':    return const Color(0xFF10B981);
      case 'Pediatria':       return const Color(0xFF3B82F6);
      case 'Neurologia':      return const Color(0xFF8B5CF6);
      case 'Pneumologia':     return const Color(0xFF06B6D4);
      case 'UTI / Intensivismo': return const Color(0xFFF97316);
      case 'Farmacologia':    return const Color(0xFFA855F7);
      default:                return _kGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = dark ? const Color(0xFF111C15) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06);
    final catColor = _categoryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Ícone PDF ──────────────────────────────────────────────────
              Container(
                width: 48, height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: catColor.withValues(alpha: 0.12),
                  border: Border.all(color: catColor.withValues(alpha: 0.3)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.picture_as_pdf_rounded, color: catColor, size: 24),
                  Text('PDF', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: catColor)),
                ]),
              ),
              const SizedBox(width: 14),

              // ── Conteúdo ───────────────────────────────────────────────────
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Badge categoria
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: catColor.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      guide.category,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: catColor),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Título
                  Text(
                    guide.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : const Color(0xFF0F1C14),
                      height: 1.3,
                    ),
                  ),

                  // Autores + Ano
                  if (guide.authors.isNotEmpty || guide.year.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [if (guide.authors.isNotEmpty) guide.authors, if (guide.year.isNotEmpty) guide.year].join(' • '),
                      style: TextStyle(fontSize: 11, color: dark ? Colors.white38 : Colors.black38),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Descrição
                  if (guide.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      guide.description,
                      style: TextStyle(fontSize: 12, color: dark ? Colors.white54 : Colors.black54, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Rodapé — tamanho + downloads + botão
                  Row(children: [
                    if (guide.fileSizeLabel.isNotEmpty)
                      _Chip(label: guide.fileSizeLabel, icon: Icons.storage_rounded, dark: dark),
                    if (guide.downloadCount > 0) ...[
                      const SizedBox(width: 6),
                      _Chip(
                        label: '${guide.downloadCount}',
                        icon: Icons.download_rounded,
                        dark: dark,
                      ),
                    ],
                    const Spacer(),
                    // Botão Abrir / Baixar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _kGreen,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        const Text('Abrir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                      ]),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool dark;
  const _Chip({required this.label, required this.icon, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: dark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dark ? Colors.white38 : Colors.black38)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO VAZIO
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final bool hasSearch;
  const _EmptyState({required this.dark, required this.isEs, this.hasSearch = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.menu_book_rounded,
            size: 56,
            color: dark ? Colors.white12 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? (isEs ? 'Sin resultados' : 'Nenhum resultado')
                : (isEs ? 'Sin guías disponibles aún' : 'Nenhuma guia disponível ainda'),
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: dark ? Colors.white30 : Colors.black26,
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            Text(
              isEs
                  ? 'El administrador aún no subió guías'
                  : 'O administrador ainda não enviou guias',
              style: TextStyle(fontSize: 13, color: dark ? Colors.white24 : Colors.black12),
              textAlign: TextAlign.center,
            ),
          ],
        ]),
      ),
    );
  }
}
