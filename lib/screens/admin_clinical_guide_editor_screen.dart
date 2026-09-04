import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/clinical_guide_article.dart';
import '../models/guide_model.dart';
import '../services/clinical_guide_cms_import_service.dart';
import '../services/clinical_guides_editorial_service.dart';
import '../services/storage_service.dart';
import 'clinical_guide_article_screen.dart';

class AdminClinicalGuideEditorScreen extends StatefulWidget {
  const AdminClinicalGuideEditorScreen({
    super.key,
    this.guide,
    required this.adminName,
  });

  final GuideModel? guide;
  final String adminName;

  @override
  State<AdminClinicalGuideEditorScreen> createState() =>
      _AdminClinicalGuideEditorScreenState();
}

class _AdminClinicalGuideEditorScreenState
    extends State<AdminClinicalGuideEditorScreen> {
  static const _accentBrand = Color(0xFF0D6B57);
  static const _maxCoverBytes = 5 * 1024 * 1024;
  static const _maxPdfBytes = 25 * 1024 * 1024;

  final _authorsCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _versionCtrl = TextEditingController(text: '1');

  final _pt = _LocaleDraft('pt');
  final _es = _LocaleDraft('es');

  String _category = 'Geral';
  String _activeLang = 'pt';
  String _coverUrl = '';
  Uint8List? _coverBytes;
  String? _coverFileName;

  bool _loadingExisting = false;
  bool _saving = false;
  double _progress = 0;
  String? _error;
  String? _cmsImportFileName;
  String? _cmsImportNotice;

  bool get _editing => widget.guide != null;
  _LocaleDraft get _draft => _activeLang == 'es' ? _es : _pt;

  @override
  void initState() {
    super.initState();
    final guide = widget.guide;
    if (guide != null) {
      _category = GuideModel.categories.contains(guide.category)
          ? guide.category
          : 'Geral';
      _authorsCtrl.text = guide.authors;
      _yearCtrl.text = guide.year;
      _coverUrl = guide.coverUrl;
      _pt.title.text = guide.localizedTitle(false);
      _pt.summary.text = guide.localizedDescription(false);
      _pt.pdfUrl = guide.localizedPdfUrl(false);

      if (guide.localizations.isNotEmpty) {
        _es.title.text = guide.localizedTitle(true);
        _es.summary.text = guide.localizedDescription(true);
        _es.pdfUrl = guide.localizedPdfUrl(true);
      }

      _loadExistingEditorial();
    }
  }

  @override
  void dispose() {
    _authorsCtrl.dispose();
    _yearCtrl.dispose();
    _versionCtrl.dispose();
    _pt.dispose();
    _es.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEditorial() async {
    final id = widget.guide?.id.trim() ?? '';
    if (id.isEmpty) return;

    setState(() => _loadingExisting = true);
    try {
      final raw = await ClinicalGuidesEditorialService.loadAdminDocument(id);
      if (!mounted || raw == null) return;

      final localizations = _asMap(raw['localizations']);
      if (localizations.isNotEmpty) {
        _pt.load(_asMap(localizations['pt']));
        _es.load(_asMap(localizations['es']));
      } else {
        final legacy = ClinicalGuideArticle.fromJson(raw, documentId: id);
        _pt.load(<String, dynamic>{
          'title': legacy.title,
          'subtitle': legacy.subtitle,
          'summary': legacy.summary,
          'bodyBlocks': legacy.bodyBlocks
              .map((block) => block.toJson())
              .toList(),
          'references': legacy.references,
          'pdfUrl': legacy.pdfUrl,
        });
      }

      final version = raw['version'];
      if (version != null) _versionCtrl.text = version.toString();

      final specialty =
          (raw['specialty'] ?? raw['category'])?.toString().trim() ?? '';
      if (GuideModel.categories.contains(specialty)) _category = specialty;

      final authors = raw['authors']?.toString().trim() ?? '';
      final year = raw['year']?.toString().trim() ?? '';
      final hero =
          (raw['heroImageUrl'] ?? raw['coverUrl'])?.toString().trim() ?? '';

      if (authors.isNotEmpty) _authorsCtrl.text = authors;
      if (year.isNotEmpty) _yearCtrl.text = year;
      if (hero.isNotEmpty) _coverUrl = hero;

      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar o conteúdo: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.of(raw);
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  static String _foldForMatch(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }

  String? _matchImportedCategory(String specialty) {
    final target = _foldForMatch(specialty);
    if (target.isEmpty) return null;

    for (final category in GuideModel.categories) {
      if (_foldForMatch(category) == target) return category;
    }

    if (target.contains('terapia intensiva') ||
        target.contains('cuidados intensivos') ||
        target.contains('intensiv')) {
      for (final category in GuideModel.categories) {
        final folded = _foldForMatch(category);
        if (folded.contains('intensiv') || folded.contains('uti')) {
          return category;
        }
      }
    }

    if (target.contains('emergencia') || target.contains('emergency')) {
      for (final category in GuideModel.categories) {
        final folded = _foldForMatch(category);
        if (folded.contains('emerg')) return category;
      }
    }

    return null;
  }

  void _applyImportedLocale(
    _LocaleDraft draft,
    ClinicalGuideCmsImportLocale imported,
  ) {
    draft.title.text = imported.title;
    draft.subtitle.text = imported.subtitle;
    draft.summary.text = imported.summary;
    draft.references.text = imported.references.join('\n');

    for (final block in draft.blocks) {
      block.dispose();
    }
    draft.blocks
      ..clear()
      ..addAll(
        imported.blocks.map(
          (block) => _BlockDraft(
            type: block.type,
            titleValue: block.title,
            textValue: block.text,
          ),
        ),
      );

    if (draft.blocks.isEmpty) {
      draft.blocks.add(_BlockDraft(type: 'paragraph'));
    }
  }

  Future<void> _pickCmsJson() async {
    FocusScope.of(context).unfocus();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;

    if (bytes == null) {
      setState(() => _error = 'Não foi possível ler o arquivo CMS JSON.');
      return;
    }

    ClinicalGuideCmsImportPackage imported;
    try {
      imported = ClinicalGuideCmsImportService.parseBytes(bytes);
    } on ClinicalGuideCmsImportException catch (e) {
      setState(() => _error = 'Importação bloqueada: ${e.message}');
      return;
    } catch (e) {
      setState(() => _error = 'Importação bloqueada: $e');
      return;
    }

    final suggestedCategory = _matchImportedCategory(imported.specialty);
    final authorToApply = imported.authors.trim().isNotEmpty
        ? imported.authors.trim()
        : (_authorsCtrl.text.trim().isNotEmpty
              ? _authorsCtrl.text.trim()
              : 'MedCases Clinical Editorial');

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final categoryLine = suggestedCategory == null
            ? 'Não reconhecida automaticamente — manter "${_category}".'
            : '$suggestedCategory';

        return AlertDialog(
          title: const Text('Importar CMS JSON'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    imported.pt.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Arquivo: ${file.name}'),
                  Text('Schema: ${imported.schemaVersion}'),
                  Text('Ano: ${imported.year}'),
                  Text('Versão: ${imported.version}'),
                  Text('Categoria: $categoryLine'),
                  Text('Autores: $authorToApply'),
                  const SizedBox(height: 12),
                  Text(
                    'PT: ${imported.pt.blocks.length} blocos · '
                    '${imported.pt.references.length} referências',
                  ),
                  Text(
                    'ES: ${imported.es.blocks.length} blocos · '
                    '${imported.es.references.length} referências',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Conversões determinísticas: '
                    '${imported.tableConversions} tabela(s) e '
                    '${imported.algorithmConversions} algoritmo(s).',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'source_audit, evidence_ledger e gates não entram '
                    'no formulário. Capa e PDFs permanecem separados.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Importar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _applyImportedLocale(_pt, imported.pt);
      _applyImportedLocale(_es, imported.es);

      if (suggestedCategory != null) {
        _category = suggestedCategory;
      }

      _authorsCtrl.text = authorToApply;
      _yearCtrl.text = imported.year;
      _versionCtrl.text = imported.version.toString();

      _cmsImportFileName = file.name;
      _cmsImportNotice =
          suggestedCategory == null && imported.specialty.trim().isNotEmpty
          ? 'CMS importado. Revise a categoria: '
                '"${imported.specialty}" não correspondeu automaticamente.'
          : 'CMS importado e validado. Confira o preview antes de publicar.';
      _error = null;
    });
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Não foi possível ler a imagem selecionada.');
      return;
    }
    if (bytes.lengthInBytes > _maxCoverBytes) {
      setState(() => _error = 'A imagem de capa deve ter no máximo 5 MB.');
      return;
    }

    setState(() {
      _coverBytes = bytes;
      _coverFileName = file.name;
      _error = null;
    });
  }

  Future<void> _pickPdf(_LocaleDraft draft) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Não foi possível ler o PDF selecionado.');
      return;
    }
    if (bytes.lengthInBytes > _maxPdfBytes) {
      setState(() => _error = 'Cada PDF deve ter no máximo 25 MB.');
      return;
    }

    setState(() {
      draft.pdfBytes = bytes;
      draft.pdfFileName = file.name;
      _error = null;
    });
  }

  bool _localeReady(_LocaleDraft draft) {
    return draft.title.text.trim().isNotEmpty &&
        draft.summary.text.trim().isNotEmpty &&
        draft.blocks.any((block) => block.hasContent);
  }

  String? _publicationError() {
    if (!_localeReady(_pt)) {
      return 'Complete título, resumo e ao menos um bloco de conteúdo em PT.';
    }
    if (!_localeReady(_es)) {
      return 'Complete título, resumen e ao menos um bloco de conteúdo em ES.';
    }
    return null;
  }

  Map<String, dynamic> _localePayload(_LocaleDraft draft) {
    final bodyBlocks = draft.blocks
        .where((block) => block.hasContent)
        .map((block) => block.toBlock().toJson())
        .toList(growable: false);

    final references = draft.references.text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return <String, dynamic>{
      'language': draft.code,
      'title': draft.title.text.trim(),
      'subtitle': draft.subtitle.text.trim(),
      'summary': draft.summary.text.trim(),
      'bodyBlocks': bodyBlocks,
      'references': references,
      if (draft.pdfUrl.trim().isNotEmpty) 'pdfUrl': draft.pdfUrl.trim(),
    };
  }

  ClinicalGuideArticle _previewArticle(_LocaleDraft draft) {
    return ClinicalGuideArticle.fromJson(<String, dynamic>{
      'id': widget.guide?.id ?? 'preview',
      'specialty': _category,
      'category': _category,
      'authors': _authorsCtrl.text.trim(),
      'year': _yearCtrl.text.trim(),
      'version': int.tryParse(_versionCtrl.text.trim()) ?? 1,
      'heroImageUrl': _coverBytes == null ? _coverUrl : '',
      ..._localePayload(draft),
    }, documentId: widget.guide?.id ?? 'preview');
  }

  Future<void> _preview() async {
    FocusScope.of(context).unfocus();
    final article = _previewArticle(_draft);
    if (article.title.trim().isEmpty) {
      setState(() => _error = 'Adicione um título antes de pré-visualizar.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ClinicalGuideArticleScreen(guide: article, lang: _activeLang),
      ),
    );
  }

  Future<void> _save({required bool publish}) async {
    FocusScope.of(context).unfocus();

    if (_pt.title.text.trim().isEmpty && _es.title.text.trim().isEmpty) {
      setState(() => _error = 'Informe ao menos um título para salvar.');
      return;
    }

    if (publish) {
      final validation = _publicationError();
      if (validation != null) {
        setState(() => _error = validation);
        return;
      }
    }

    setState(() {
      _saving = true;
      _progress = 0;
      _error = null;
    });

    try {
      var coverUrl = _coverUrl.trim();

      if (_coverBytes != null && _coverFileName != null) {
        final uploaded = await StorageService.uploadGuideImage(
          bytes: _coverBytes!,
          fileName: _coverFileName!,
          onProgress: (value) {
            if (mounted) setState(() => _progress = value * 0.28);
          },
        );
        coverUrl = uploaded.url;
      }

      for (final draft in <_LocaleDraft>[_pt, _es]) {
        if (draft.pdfBytes == null || draft.pdfFileName == null) continue;

        final uploaded = await StorageService.uploadGuidePdf(
          bytes: draft.pdfBytes!,
          fileName: draft.pdfFileName!,
          onProgress: (value) {
            if (!mounted) return;
            final base = draft.code == 'pt' ? 0.30 : 0.61;
            setState(() => _progress = base + value * 0.18);
          },
        );
        draft.pdfUrl = uploaded.url;
      }

      final parsedVersion = int.tryParse(_versionCtrl.text.trim()) ?? 1;
      final savedId = await ClinicalGuidesEditorialService.saveBilingualGuide(
        id: widget.guide?.id ?? '',
        specialty: _category,
        authors: _authorsCtrl.text.trim(),
        year: _yearCtrl.text.trim(),
        version: parsedVersion < 1 ? 1 : parsedVersion,
        heroImageUrl: coverUrl,
        pt: _localePayload(_pt),
        es: _localePayload(_es),
        published: publish,
        adminName: widget.adminName,
      );

      if (!mounted) return;
      setState(() => _progress = 1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            publish
                ? 'Guia PT/ES publicada com sucesso.'
                : 'Rascunho PT/ES salvo com sucesso.',
          ),
        ),
      );
      Navigator.of(context).pop(savedId.isNotEmpty);
    } catch (e) {
      if (mounted) setState(() => _error = 'Falha ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDecoration(String label, bool dark) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: dark ? const Color(0xFF1C2026) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF3B424D) : const Color(0xFFD5DDE4),
          width: 0.8,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accentBrand, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF1A1D23) : const Color(0xFFE0E6E9);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final text = dark ? Colors.white : const Color(0xFF111827);
    final secondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFD5DDE4);

    return Scaffold(
      backgroundColor: background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _EditorGlassTopbar(
          dark: dark,
          title: _editing ? 'EDITAR GUIA' : 'NOVA GUIA',
          busy: _saving,
          onClose: () => Navigator.of(context).maybePop(),
        ),
      ),
      bottomNavigationBar: _EditorActionBar(
        dark: dark,
        saving: _saving,
        onDraft: () => _save(publish: false),
        onPreview: _preview,
        onPublish: () => _save(publish: true),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 128),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          surface: surface,
                          border: border,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                icon: Icons.data_object_rounded,
                                title: 'IMPORTAÇÃO CMS JSON',
                                subtitle:
                                    'Valida o pacote editorial PT/ES antes de preencher. Tabelas e algoritmos são convertidos sem IA; auditoria, capa e PDFs permanecem separados.',
                                text: text,
                                secondary: secondary,
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _pickCmsJson,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Importar CMS JSON'),
                              ),
                              if (_cmsImportFileName != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _cmsImportFileName!,
                                  style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (_cmsImportNotice != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _cmsImportNotice!,
                                  style: TextStyle(
                                    color: secondary,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SectionCard(
                          surface: surface,
                          border: border,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                icon: Icons.image_outlined,
                                title: 'CAPA EDITORIAL',
                                subtitle:
                                    'Recomendado: 1600 × 1200 px (4:3), JPG/PNG/WebP, até 5 MB. Mantenha o assunto principal no centro para os recortes do app.',
                                text: text,
                                secondary: secondary,
                              ),
                              const SizedBox(height: 14),
                              AspectRatio(
                                aspectRatio: 4 / 3,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: _CoverPreview(
                                    bytes: _coverBytes,
                                    url: _coverUrl,
                                    dark: dark,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _pickCover,
                                icon: const Icon(Icons.upload_rounded),
                                label: Text(
                                  _coverBytes != null || _coverUrl.isNotEmpty
                                      ? 'Substituir imagem de capa'
                                      : 'Selecionar imagem de capa',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SectionCard(
                          surface: surface,
                          border: border,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                icon: Icons.tune_rounded,
                                title: 'INFORMAÇÕES GERAIS',
                                subtitle:
                                    'Categoria, capa, autores, ano e versão são compartilhados entre PT e ES.',
                                text: text,
                                secondary: secondary,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _category,
                                decoration: _inputDecoration(
                                  'Especialidade / categoria',
                                  dark,
                                ),
                                items: GuideModel.categories
                                    .map(
                                      (category) => DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: _saving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => _category = value);
                                        }
                                      },
                              ),
                              const SizedBox(height: 10),
                              _ResponsiveFields(
                                first: TextField(
                                  controller: _authorsCtrl,
                                  decoration: _inputDecoration('Autores', dark),
                                ),
                                second: TextField(
                                  controller: _yearCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration('Ano', dark),
                                ),
                                third: TextField(
                                  controller: _versionCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    'Versão editorial',
                                    dark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _LanguageSelector(
                          dark: dark,
                          active: _activeLang,
                          ptReady: _localeReady(_pt),
                          esReady: _localeReady(_es),
                          onChanged: (language) =>
                              setState(() => _activeLang = language),
                        ),
                        const SizedBox(height: 10),
                        _SectionCard(
                          surface: surface,
                          border: border,
                          child: _LocaleEditor(
                            key: ValueKey(_activeLang),
                            draft: _draft,
                            dark: dark,
                            text: text,
                            secondary: secondary,
                            onChanged: () => setState(() {}),
                            onPickPdf: () => _pickPdf(_draft),
                          ),
                        ),
                        if (_saving) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: _progress > 0
                                ? _progress.clamp(0.0, 1.0).toDouble()
                                : null,
                            color: _accentBrand,
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFEF4444,
                                ).withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _LocaleDraft {
  _LocaleDraft(this.code) {
    blocks.add(_BlockDraft(type: 'paragraph'));
  }

  final String code;
  final title = TextEditingController();
  final subtitle = TextEditingController();
  final summary = TextEditingController();
  final references = TextEditingController();
  final List<_BlockDraft> blocks = <_BlockDraft>[];

  String pdfUrl = '';
  Uint8List? pdfBytes;
  String? pdfFileName;

  void load(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    title.text = data['title']?.toString() ?? title.text;
    subtitle.text = data['subtitle']?.toString() ?? subtitle.text;
    summary.text =
        (data['summary'] ?? data['description'])?.toString() ?? summary.text;
    pdfUrl = data['pdfUrl']?.toString() ?? pdfUrl;

    final rawReferences = data['references'];
    if (rawReferences is List) {
      references.text = rawReferences
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .join('\n');
    } else if (rawReferences != null) {
      references.text = rawReferences.toString();
    }

    final rawBlocks = data['bodyBlocks'];
    if (rawBlocks is List && rawBlocks.isNotEmpty) {
      for (final block in blocks) {
        block.dispose();
      }
      blocks.clear();

      for (final raw in rawBlocks) {
        if (raw is Map) {
          final map = raw.map((key, value) => MapEntry(key.toString(), value));
          blocks.add(_BlockDraft.fromMap(map));
        }
      }

      if (blocks.isEmpty) blocks.add(_BlockDraft(type: 'paragraph'));
    }
  }

  void dispose() {
    title.dispose();
    subtitle.dispose();
    summary.dispose();
    references.dispose();
    for (final block in blocks) {
      block.dispose();
    }
  }
}

class _BlockDraft {
  _BlockDraft({
    required this.type,
    String titleValue = '',
    String textValue = '',
  }) : title = TextEditingController(text: titleValue),
       text = TextEditingController(text: textValue);

  factory _BlockDraft.fromMap(Map<String, dynamic> map) {
    final type = map['type']?.toString().trim() ?? 'paragraph';
    final rawItems = map['items'];
    final textValue = type == 'bullets' && rawItems is List
        ? rawItems.map((item) => item.toString()).join('\n')
        : map['text']?.toString() ?? '';

    return _BlockDraft(
      type: type,
      titleValue: map['title']?.toString() ?? '',
      textValue: textValue,
    );
  }

  String type;
  final TextEditingController title;
  final TextEditingController text;

  bool get hasContent =>
      title.text.trim().isNotEmpty || text.text.trim().isNotEmpty;

  ClinicalGuideBlock toBlock() {
    if (type == 'bullets') {
      final items = text.text
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);

      return ClinicalGuideBlock(
        type: 'bullets',
        title: title.text.trim(),
        items: items,
      );
    }

    return ClinicalGuideBlock(
      type: type,
      title: title.text.trim(),
      text: text.text.trim(),
    );
  }

  void dispose() {
    title.dispose();
    text.dispose();
  }
}

class _EditorGlassTopbar extends StatelessWidget {
  const _EditorGlassTopbar({
    required this.dark,
    required this.title,
    required this.busy,
    required this.onClose,
  });

  final bool dark;
  final String title;
  final bool busy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final glassColor = dark
        ? const Color(0xFF161B22).withOpacity(0.58)
        : Colors.white.withOpacity(0.56);
    final borderColor = dark
        ? Colors.white.withOpacity(0.13)
        : Colors.white.withOpacity(0.78);
    final liquidTop = Colors.white.withOpacity(dark ? 0.10 : 0.46);
    final liquidMid = Colors.white.withOpacity(dark ? 0.025 : 0.12);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.16 : 0.07),
            blurRadius: 14,
            spreadRadius: -8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [liquidTop, liquidMid, Colors.transparent],
                stops: const [0.0, 0.42, 1.0],
              ),
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.7),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 52),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark ? Colors.white : const Color(0xFF05070A),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          onPressed: busy ? null : onClose,
                          icon: const Icon(Icons.close_rounded, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorActionBar extends StatelessWidget {
  const _EditorActionBar({
    required this.dark,
    required this.saving,
    required this.onDraft,
    required this.onPreview,
    required this.onPublish,
  });

  final bool dark;
  final bool saving;
  final VoidCallback onDraft;
  final VoidCallback onPreview;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final background = dark ? const Color(0xFF20242B) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFD5DDE4);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: background,
          border: Border(top: BorderSide(color: border, width: 0.7)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final draftButton = OutlinedButton.icon(
              onPressed: saving ? null : onDraft,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Salvar rascunho'),
            );
            final previewButton = OutlinedButton.icon(
              onPressed: saving ? null : onPreview,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Pré-visualizar'),
            );
            final publishButton = FilledButton.icon(
              onPressed: saving ? null : onPublish,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_rounded, size: 18),
              label: const Text('Publicar PT + ES'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B57),
                foregroundColor: Colors.white,
              ),
            );

            if (constraints.maxWidth < 620) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: draftButton),
                      const SizedBox(width: 8),
                      Expanded(child: previewButton),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(height: 44, child: publishButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: draftButton),
                const SizedBox(width: 8),
                Expanded(child: previewButton),
                const SizedBox(width: 8),
                Expanded(child: publishButton),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.surface,
    required this.border,
    required this.child,
  });

  final Color surface;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.text,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color text;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0D6B57)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: text,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(color: secondary, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.bytes,
    required this.url,
    required this.dark,
  });

  final Uint8List? bytes;
  final String url;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (bytes != null) return Image.memory(bytes!, fit: BoxFit.cover);

    if (url.trim().isNotEmpty) {
      return Image.network(
        url.trim(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _empty(),
      );
    }

    return _empty();
  }

  Widget _empty() {
    return ColoredBox(
      color: dark ? const Color(0xFF1C2026) : const Color(0xFFF1F5F9),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 42),
            SizedBox(height: 8),
            Text('1600 × 1200 px · 4:3'),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({
    required this.first,
    required this.second,
    required this.third,
  });

  final Widget first;
  final Widget second;
  final Widget third;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            children: [
              first,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: second),
                  const SizedBox(width: 10),
                  Expanded(child: third),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
            const SizedBox(width: 10),
            Expanded(child: third),
          ],
        );
      },
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.dark,
    required this.active,
    required this.ptReady,
    required this.esReady,
    required this.onChanged,
  });

  final bool dark;
  final String active;
  final bool ptReady;
  final bool esReady;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LanguageButton(
            label: 'PT · Português',
            active: active == 'pt',
            ready: ptReady,
            dark: dark,
            onTap: () => onChanged('pt'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LanguageButton(
            label: 'ES · Español',
            active: active == 'es',
            ready: esReady,
            dark: dark,
            onTap: () => onChanged('es'),
          ),
        ),
      ],
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.active,
    required this.ready,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool ready;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = dark ? const Color(0xFF252930) : Colors.white;

    return Material(
      color: active ? const Color(0xFF0D6B57) : inactive,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : (dark ? Colors.white : const Color(0xFF111827)),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                ready ? Icons.check_circle_rounded : Icons.pending_outlined,
                size: 18,
                color: active
                    ? Colors.white
                    : (ready
                          ? const Color(0xFF059669)
                          : const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocaleEditor extends StatelessWidget {
  const _LocaleEditor({
    super.key,
    required this.draft,
    required this.dark,
    required this.text,
    required this.secondary,
    required this.onChanged,
    required this.onPickPdf,
  });

  final _LocaleDraft draft;
  final bool dark;
  final Color text;
  final Color secondary;
  final VoidCallback onChanged;
  final VoidCallback onPickPdf;

  static const blockTypes = <String>[
    'heading',
    'paragraph',
    'bullets',
    'callout',
    'warning',
    'note',
  ];

  String _typeLabel(String type) {
    switch (type) {
      case 'heading':
        return 'Título de seção';
      case 'bullets':
        return 'Lista';
      case 'callout':
        return 'Destaque';
      case 'warning':
        return 'Alerta';
      case 'note':
        return 'Nota';
      default:
        return 'Parágrafo';
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: dark ? const Color(0xFF1C2026) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF3B424D) : const Color(0xFFD5DDE4),
          width: 0.8,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0D6B57), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = draft.code == 'es';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.translate_rounded,
          title: isEs ? 'CONTEÚDO EM ESPAÑOL' : 'CONTEÚDO EM PORTUGUÊS',
          subtitle: isEs
              ? 'Esta versão será exibida automaticamente quando o app estiver em espanhol.'
              : 'Esta versão será exibida automaticamente quando o app estiver em português.',
          text: text,
          secondary: secondary,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: draft.title,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Título *'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: draft.subtitle,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Subtítulo'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: draft.summary,
          minLines: 3,
          maxLines: 5,
          onChanged: (_) => onChanged(),
          decoration: _decoration(isEs ? 'Resumen *' : 'Resumo *'),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                isEs ? 'BLOCOS DO ARTÍCULO' : 'BLOCOS DO ARTIGO',
                style: TextStyle(
                  color: text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                draft.blocks.add(_BlockDraft(type: 'paragraph'));
                onChanged();
              },
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Adicionar bloco'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B57),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(draft.blocks.length, (index) {
          final block = draft.blocks[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1C2026) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF3B424D)
                      : const Color(0xFFD5DDE4),
                  width: 0.8,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF0D6B57),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: blockTypes.contains(block.type)
                              ? block.type
                              : 'paragraph',
                          decoration: _decoration('Tipo'),
                          items: blockTypes
                              .map(
                                (type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(_typeLabel(type)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              block.type = value;
                              onChanged();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mover para cima',
                        onPressed: index == 0
                            ? null
                            : () {
                                final item = draft.blocks.removeAt(index);
                                draft.blocks.insert(index - 1, item);
                                onChanged();
                              },
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                      IconButton(
                        tooltip: 'Mover para baixo',
                        onPressed: index == draft.blocks.length - 1
                            ? null
                            : () {
                                final item = draft.blocks.removeAt(index);
                                draft.blocks.insert(index + 1, item);
                                onChanged();
                              },
                        icon: const Icon(Icons.arrow_downward_rounded),
                      ),
                      IconButton(
                        tooltip: 'Excluir bloco',
                        onPressed: draft.blocks.length <= 1
                            ? null
                            : () {
                                final removed = draft.blocks.removeAt(index);
                                removed.dispose();
                                onChanged();
                              },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (block.type != 'paragraph')
                    TextField(
                      controller: block.title,
                      onChanged: (_) => onChanged(),
                      decoration: _decoration(
                        block.type == 'heading'
                            ? 'Título da seção'
                            : 'Título do bloco (opcional)',
                      ),
                    ),
                  if (block.type != 'paragraph') const SizedBox(height: 10),
                  if (block.type != 'heading')
                    TextField(
                      controller: block.text,
                      minLines: block.type == 'bullets' ? 4 : 3,
                      maxLines: 12,
                      onChanged: (_) => onChanged(),
                      decoration: _decoration(
                        block.type == 'bullets' ? 'Um item por linha' : 'Texto',
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        TextField(
          controller: draft.references,
          minLines: 4,
          maxLines: 10,
          decoration: _decoration(
            isEs
                ? 'Referencias · uma por línea'
                : 'Referências · uma por linha',
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1C2026) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dark ? const Color(0xFF3B424D) : const Color(0xFFD5DDE4),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  draft.pdfFileName ??
                      (draft.pdfUrl.isNotEmpty
                          ? (isEs ? 'PDF ES anexado' : 'PDF PT anexado')
                          : (isEs
                                ? 'PDF ES opcional · até 25 MB'
                                : 'PDF PT opcional · até 25 MB')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onPickPdf,
                child: Text(
                  draft.pdfFileName != null || draft.pdfUrl.isNotEmpty
                      ? 'Substituir'
                      : 'Selecionar',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
