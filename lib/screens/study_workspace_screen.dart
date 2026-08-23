import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/study_long_form_audio_handoff.dart';
import '../models/study_workspace_model.dart';
import '../services/study/study_artifact_generator.dart';
import '../services/study/study_first_use_notice_service.dart';
import '../services/study/study_library_service.dart';
import '../services/study/study_long_form_segment_loader.dart';
import '../services/study/study_multimodal_extraction_service.dart';
import '../services/study/study_pdf_export_service.dart';
import '../services/study/study_visual_result_codec.dart';
import 'notes_audio_local_runtime_screen.dart';

class StudyWorkspaceScreen extends StatefulWidget {
  const StudyWorkspaceScreen({super.key, required this.isEs});

  final bool isEs;

  @override
  State<StudyWorkspaceScreen> createState() => _StudyWorkspaceScreenState();
}

class _StudyWorkspaceScreenState extends State<StudyWorkspaceScreen> {
  late Study _study;
  final _title = TextEditingController();

  final Map<String, List<String>> _recordedRawPaths = <String, List<String>>{};

  List<Study> _library = const <Study>[];
  bool _busy = false;
  bool _noticeAccepted = false;
  StudyArtifactType _artifactType = StudyArtifactType.visualSummary;
  _StudyResultView _resultView = _StudyResultView.visual;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _study = Study(
      id: 'study_${now.microsecondsSinceEpoch}',
      title: widget.isEs ? 'Nuevo estudio' : 'Novo estudo',
      locale: widget.isEs ? 'es-ES' : 'pt-BR',
      createdAtUtc: now,
    );
    _title.text = _study.title;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFirstUseNotice();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadFirstUseNotice() async {
    final accepted = await StudyFirstUseNoticeService.isAccepted();
    if (!mounted) return;
    setState(() => _noticeAccepted = accepted);
    if (!accepted) {
      await _showFirstUseNotice();
    }
  }

  Future<bool> _ensureFirstUseNotice() async {
    if (_noticeAccepted) return true;
    return _showFirstUseNotice();
  }

  Future<bool> _showFirstUseNotice() async {
    if (!mounted) return false;

    final accepted =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final dark = Theme.of(dialogContext).brightness == Brightness.dark;
            final surface = dark ? const Color(0xFF252930) : Colors.white;
            final text = dark
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF111318);
            final sub = dark
                ? const Color(0xFFC6CED9)
                : const Color(0xFF52606D);

            return AlertDialog(
              backgroundColor: surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
              actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              title: Row(
                children: [
                  const Icon(
                    Icons.auto_stories_outlined,
                    size: 19,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isEs ? 'Área de Estudio' : 'Área de Estudos',
                      style: TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                widget.isEs
                    ? 'Usa este espacio solo con material educativo. No '
                          'incluyas datos identificables de pacientes. Este '
                          'aviso aparecerá una sola vez.'
                    : 'Use este espaço apenas com material educacional. Não '
                          'inclua dados identificáveis de pacientes. Este '
                          'aviso aparecerá apenas uma vez.',
                style: TextStyle(color: sub, fontSize: 11.5, height: 1.45),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(widget.isEs ? 'Ahora no' : 'Agora não'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(widget.isEs ? 'Continuar' : 'Continuar'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!accepted) return false;

    await StudyFirstUseNoticeService.accept();
    if (!mounted) return true;
    setState(() => _noticeAccepted = true);
    return true;
  }

  Future<void> _persistStudy() async {
    await StudyLibraryService.save(_study);
    _library = await StudyLibraryService.loadAll();
  }

  String _addSource(StudySourceType type, String title) {
    final id =
        'source_${DateTime.now().toUtc().microsecondsSinceEpoch}_${_study.sources.length}';

    final source = StudySource(
      id: id,
      type: type,
      title: title,
      state: StudySourceState.added,
      createdAtUtc: DateTime.now().toUtc(),
    );

    setState(() {
      _study = _study.copyWith(
        sources: <StudySource>[..._study.sources, source],
      );
    });

    return id;
  }

  StudySource _source(String id) =>
      _study.sources.firstWhere((source) => source.id == id);

  void _replace(StudySource source) {
    final next = List<StudySource>.from(_study.sources);
    final index = next.indexWhere((item) => item.id == source.id);
    if (index < 0) return;
    next[index] = source;
    setState(() => _study = _study.copyWith(sources: next));
  }

  Future<void> _removeSource(String sourceId) async {
    _recordedRawPaths.remove(sourceId);
    final next = _study.sources
        .where((source) => source.id != sourceId)
        .toList(growable: false);
    setState(() => _study = _study.copyWith(sources: next));
    await _persistStudy();
  }

  Future<void> _newStudy() async {
    final now = DateTime.now().toUtc();
    setState(() {
      _study = Study(
        id: 'study_${now.microsecondsSinceEpoch}',
        title: widget.isEs ? 'Nuevo estudio' : 'Novo estudo',
        locale: widget.isEs ? 'es-ES' : 'pt-BR',
        createdAtUtc: now,
      );
      _title.text = _study.title;
      _recordedRawPaths.clear();
    });
  }

  Future<void> _openLibrary() async {
    var studies = await StudyLibraryService.loadAll();
    if (!mounted) return;
    _library = studies;
    var deletedCurrent = false;

    final selected = await showModalBottomSheet<Study>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final dark = Theme.of(sheetContext).brightness == Brightness.dark;
          final page = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
          final surface = dark ? const Color(0xFF252930) : Colors.white;
          final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
          final sub = dark ? const Color(0xFFC6CED9) : const Color(0xFF52606D);
          final border = dark
              ? const Color(0xFF374151)
              : const Color(0xFFE2E7EC);
          const accent = Color(0xFF10B981);
          const destructive = Color(0xFFDC2626);

          Future<void> deleteStudy(Study study) async {
            final ok =
                await showDialog<bool>(
                  context: sheetContext,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    title: Text(
                      widget.isEs ? 'Eliminar estudio' : 'Excluir estudo',
                      style: TextStyle(
                        color: text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    content: Text(
                      widget.isEs
                          ? 'Este estudio se eliminará de la biblioteca y del historial.'
                          : 'Este estudo será excluído da biblioteca e do histórico.',
                      style: TextStyle(color: sub, fontSize: 11, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text('Cancelar', style: TextStyle(color: sub)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(
                          widget.isEs ? 'Eliminar' : 'Excluir',
                          style: const TextStyle(
                            color: destructive,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ) ??
                false;
            if (!ok) return;
            await StudyLibraryService.deleteById(study.id);
            final refreshed = await StudyLibraryService.loadAll();
            if (!sheetContext.mounted) return;
            setSheetState(() => studies = refreshed);
            _library = refreshed;
            if (study.id == _study.id) deletedCurrent = true;
          }

          return SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.68,
              ),
              decoration: BoxDecoration(
                color: page,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 34,
                    height: 3,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.isEs
                                ? 'Biblioteca de estudios'
                                : 'Biblioteca de estudos',
                            style: TextStyle(
                              color: text,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${studies.length}/40',
                          style: TextStyle(
                            color: sub,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 0.7, color: border),
                  Expanded(
                    child: studies.isEmpty
                        ? Center(
                            child: Text(
                              widget.isEs
                                  ? 'Biblioteca vacía'
                                  : 'Biblioteca vazia',
                              style: TextStyle(color: sub, fontSize: 11.5),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                            itemCount: studies.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 0.7,
                              color: border,
                            ),
                            itemBuilder: (_, index) {
                              final study = studies[index];
                              return ListTile(
                                dense: true,
                                minVerticalPadding: 7,
                                contentPadding: const EdgeInsets.only(left: 4),
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(
                                      alpha: dark ? 0.10 : 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.auto_stories_outlined,
                                    size: 16,
                                    color: accent,
                                  ),
                                ),
                                title: Text(
                                  study.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${study.sources.length} ${widget.isEs ? "fuentes" : "fontes"} · ${study.artifacts.length} ${widget.isEs ? "productos" : "produtos"}',
                                  style: TextStyle(color: sub, fontSize: 9.5),
                                ),
                                onTap: () => Navigator.pop(sheetContext, study),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: widget.isEs
                                          ? 'Eliminar'
                                          : 'Excluir',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => deleteStudy(study),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 17,
                                        color: destructive,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: sub,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _study = selected;
        _title.text = selected.title;
        _recordedRawPaths.clear();
      });
    } else if (deletedCurrent) {
      await _newStudy();
    }
  }

  Future<void> _addText() async {
    if (!await _ensureFirstUseNotice()) return;
    if (!mounted) return;

    final editor = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final dark = Theme.of(sheetContext).brightness == Brightness.dark;
        final surface = dark ? const Color(0xFF252930) : Colors.white;
        final page = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
        final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
        final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.isEs ? 'Agregar texto' : 'Adicionar texto',
                          style: TextStyle(
                            color: text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                    ],
                  ),
                  TextField(
                    controller: editor,
                    autofocus: true,
                    minLines: 6,
                    maxLines: 11,
                    style: TextStyle(color: text, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: widget.isEs
                          ? 'Pega aquí el material de estudio…'
                          : 'Cole aqui o material de estudo…',
                      filled: true,
                      fillColor: page,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: border, width: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, editor.text),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(widget.isEs ? 'Agregar' : 'Adicionar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    editor.dispose();

    final value = result?.trim() ?? '';
    if (value.isEmpty) return;

    final id = _addSource(
      StudySourceType.text,
      widget.isEs ? 'Texto agregado' : 'Texto adicionado',
    );

    var source = _source(id).transition(StudySourceState.processing);
    _replace(source);

    try {
      final extraction = StudyMultimodalExtractionService.text(
        sourceId: id,
        value: value,
      );
      source = source.transition(
        StudySourceState.review,
        extractedText: extraction.text,
        sourceRefs: extraction.refs,
      );
      _replace(source);
      await _persistStudy();
    } catch (_) {
      await _removeSource(id);
      _message(
        widget.isEs
            ? 'No fue posible agregar el texto.'
            : 'Não foi possível adicionar o texto.',
      );
    }
  }

  Future<void> _recordLecture() async {
    if (!await _ensureFirstUseNotice()) return;
    if (!mounted) return;

    final sourceId = _addSource(
      StudySourceType.recordedAudio,
      widget.isEs ? 'Clase grabada' : 'Aula gravada',
    );

    final handoff = await Navigator.of(context).push<StudyLongFormAudioHandoff>(
      MaterialPageRoute<StudyLongFormAudioHandoff>(
        builder: (routeContext) => NotesAudioLongFormLocalRuntimeScreen(
          isEs: widget.isEs,
          onCompleted: (value) {
            if (Navigator.of(routeContext).canPop()) {
              Navigator.of(routeContext).pop(value);
            }
          },
        ),
      ),
    );

    if (handoff == null || !handoff.isUsable) {
      await _removeSource(sourceId);
      return;
    }

    var source = _source(sourceId).transition(StudySourceState.processing);
    _replace(source);
    setState(() => _busy = true);

    try {
      final texts = <String>[];
      final refs = <SourceRef>[];
      final paths = handoff.segments.map((segment) => segment.path).toList();
      var offsetMs = 0;

      for (final segment in handoff.segments) {
        final bytes = await StudyLongFormSegmentLoader.read(segment.path);

        final extraction = await StudyMultimodalExtractionService.binary(
          sourceId: sourceId,
          type: StudySourceType.recordedAudio,
          fileName: 'segment_${segment.index}.m4a',
          mimeType: 'audio/mp4',
          bytes: Uint8List.fromList(bytes),
          isEs: widget.isEs,
        );

        texts.add(extraction.text);

        for (final ref in extraction.refs) {
          refs.add(
            SourceRef(
              sourceId: sourceId,
              sourceType: StudySourceType.recordedAudio,
              timestampStartMs: (ref.timestampStartMs ?? 0) + offsetMs,
              timestampEndMs: ref.timestampEndMs == null
                  ? null
                  : ref.timestampEndMs! + offsetMs,
            ),
          );
        }

        offsetMs += segment.activeDurationMs;
      }

      _recordedRawPaths[sourceId] = List<String>.unmodifiable(paths);

      source = source.transition(
        StudySourceState.review,
        extractedText: texts.join('\n\n'),
        sourceRefs: List<SourceRef>.unmodifiable(refs),
      );
      _replace(source);
      await _persistStudy();

      _message(
        widget.isEs
            ? 'Transcripción lista para revisar.'
            : 'Transcrição pronta para revisão.',
      );
    } catch (_) {
      await _removeSource(sourceId);
      _message(
        widget.isEs
            ? 'No fue posible transcribir esta grabación.'
            : 'Não foi possível transcrever esta gravação.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(StudySourceType type, List<String> extensions) async {
    if (!await _ensureFirstUseNotice()) return;
    if (!mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _message(
        widget.isEs
            ? 'No fue posible leer el archivo.'
            : 'Não foi possível ler o arquivo.',
      );
      return;
    }

    final id = _addSource(type, file.name);
    var source = _source(id).transition(StudySourceState.processing);
    _replace(source);
    setState(() => _busy = true);

    try {
      final extraction = await StudyMultimodalExtractionService.binary(
        sourceId: id,
        type: type,
        fileName: file.name,
        mimeType: _mime(file.name, type),
        bytes: Uint8List.fromList(bytes),
        isEs: widget.isEs,
      );

      source = source.transition(
        StudySourceState.review,
        extractedText: extraction.text,
        sourceRefs: extraction.refs,
      );

      _replace(source);
      await _persistStudy();
    } catch (_) {
      await _removeSource(id);
      _message(
        widget.isEs
            ? 'No fue posible procesar este archivo.'
            : 'Não foi possível processar este arquivo.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(StudySource source) async {
    final rawPaths = _recordedRawPaths[source.id] ?? const <String>[];

    if (source.type == StudySourceType.recordedAudio && rawPaths.isNotEmpty) {
      try {
        await StudyLongFormSegmentLoader.deleteAll(rawPaths);
      } catch (_) {
        _message(
          widget.isEs
              ? 'No se pudo eliminar el audio local. Intenta nuevamente.'
              : 'Não foi possível excluir o áudio local. Tente novamente.',
        );
        return;
      }
    }

    _recordedRawPaths.remove(source.id);
    _replace(source.transition(StudySourceState.accepted));
    await _persistStudy();
  }

  Future<void> _generate() async {
    if (!await _ensureFirstUseNotice()) return;
    if (_study.acceptedSources.isEmpty) {
      _message(
        widget.isEs
            ? 'Acepta al menos una fuente revisada.'
            : 'Aceite pelo menos uma fonte revisada.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final artifact = await StudyArtifactGenerator.generate(
        study: _study,
        type: _artifactType,
        isEs: widget.isEs,
      );

      final artifacts =
          _study.artifacts
              .where((item) => item.type != artifact.type)
              .toList(growable: true)
            ..add(artifact);

      setState(() => _study = _study.copyWith(artifacts: artifacts));
      await _persistStudy();
    } catch (_) {
      _message(
        widget.isEs
            ? 'No fue posible generar este material.'
            : 'Não foi possível gerar este material.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  StudyArtifact? _artifactOf(StudyArtifactType type) {
    for (final artifact in _study.artifacts.reversed) {
      if (artifact.type == type) return artifact;
    }
    return null;
  }

  Future<void> _generateType(StudyArtifactType type) async {
    setState(() => _artifactType = type);
    await _generate();
  }

  Future<void> _exportPdf() async {
    final available = _study.artifacts
        .where((item) => item.type != StudyArtifactType.finalPdf)
        .map((item) => item.type)
        .toSet();

    if (available.isEmpty) {
      _message(
        widget.isEs
            ? 'Genera al menos un material antes de exportar.'
            : 'Gere pelo menos um material antes de exportar.',
      );
      return;
    }

    final selected = await showModalBottomSheet<Set<StudyArtifactType>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _StudyPdfSelectionSheet(isEs: widget.isEs, available: available),
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await _persistStudy();
      await StudyPdfExportService.shareSelected(
        _study,
        isEs: widget.isEs,
        artifactTypes: selected,
      );
    } catch (_) {
      _message(
        widget.isEs
            ? 'No fue posible generar el PDF.'
            : 'Não foi possível gerar o PDF.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final page = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final soft = dark ? const Color(0xFF20242B) : const Color(0xFFF6F8FA);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
    final sub = dark ? const Color(0xFFC6CED9) : const Color(0xFF59636E);
    const accent = Color(0xFF10B981);

    return ColoredBox(
      color: page,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          112 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _WorkspaceHeader(
            isEs: widget.isEs,
            text: text,
            sub: sub,
            accent: accent,
            noticeAccepted: _noticeAccepted,
            onLibrary: _busy ? null : _openLibrary,
            onNew: _busy ? null : _newStudy,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            onChanged: (value) {
              final name = value.trim();
              if (name.isNotEmpty) {
                _study = _study.copyWith(title: name);
              }
            },
            onSubmitted: (_) => _persistStudy(),
            style: TextStyle(
              color: text,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: widget.isEs ? 'Nombre del estudio' : 'Nome do estudo',
              isDense: true,
              filled: true,
              fillColor: surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border, width: 0.7),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border, width: 0.7),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: accent, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionLabel(
            title: widget.isEs ? 'Fuentes' : 'Fontes',
            subtitle: widget.isEs
                ? 'Combina uno o más materiales.'
                : 'Combine um ou mais materiais.',
            text: text,
            sub: sub,
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 3;
              return Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _SourceAction(
                    width: width,
                    icon: Icons.mic_none_rounded,
                    label: widget.isEs ? 'Grabar clase' : 'Gravar aula',
                    surface: surface,
                    soft: soft,
                    border: border,
                    text: text,
                    sub: sub,
                    accent: accent,
                    onTap: _busy ? null : _recordLecture,
                  ),
                  _SourceAction(
                    width: width,
                    icon: Icons.audio_file_outlined,
                    label: widget.isEs ? 'Audio' : 'Áudio',
                    surface: surface,
                    soft: soft,
                    border: border,
                    text: text,
                    sub: sub,
                    accent: accent,
                    onTap: _busy
                        ? null
                        : () => _pick(
                            StudySourceType.uploadedAudio,
                            const <String>['m4a', 'mp3', 'wav', 'aac', 'mp4'],
                          ),
                  ),
                  _SourceAction(
                    width: width,
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF',
                    surface: surface,
                    soft: soft,
                    border: border,
                    text: text,
                    sub: sub,
                    accent: accent,
                    onTap: _busy
                        ? null
                        : () =>
                              _pick(StudySourceType.pdf, const <String>['pdf']),
                  ),
                  _SourceAction(
                    width: width,
                    icon: Icons.image_outlined,
                    label: widget.isEs ? 'Imagen' : 'Imagem',
                    surface: surface,
                    soft: soft,
                    border: border,
                    text: text,
                    sub: sub,
                    accent: accent,
                    onTap: _busy
                        ? null
                        : () => _pick(StudySourceType.image, const <String>[
                            'jpg',
                            'jpeg',
                            'png',
                            'webp',
                            'gif',
                          ]),
                  ),
                  _SourceAction(
                    width: width,
                    icon: Icons.notes_rounded,
                    label: 'Texto',
                    surface: surface,
                    soft: soft,
                    border: border,
                    text: text,
                    sub: sub,
                    accent: accent,
                    onTap: _busy ? null : _addText,
                  ),
                ],
              );
            },
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              minHeight: 2,
              color: accent,
              backgroundColor: Colors.transparent,
            ),
          ],
          if (_study.sources.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionLabel(
              title: widget.isEs ? 'Fuentes del estudio' : 'Fontes do estudo',
              subtitle: widget.isEs
                  ? 'Revisa antes de aceptar.'
                  : 'Revise antes de aceitar.',
              text: text,
              sub: sub,
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border, width: 0.7),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _study.sources.length; i++) ...[
                    _SourceRow(
                      source: _study.sources[i],
                      isEs: widget.isEs,
                      text: text,
                      sub: sub,
                      accent: accent,
                      onAccept:
                          _study.sources[i].state == StudySourceState.review
                          ? () => _accept(_study.sources[i])
                          : null,
                    ),
                    if (i < _study.sources.length - 1)
                      Divider(
                        height: 1,
                        thickness: 0.7,
                        color: border,
                        indent: 12,
                        endIndent: 12,
                      ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _SectionLabel(
            title: widget.isEs ? 'Generar con IA' : 'Gerar com IA',
            subtitle: widget.isEs
                ? 'Usa solamente las fuentes aceptadas.'
                : 'Usa apenas as fontes aceitas.',
            text: text,
            sub: sub,
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: 0.7),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<StudyArtifactType>(
                    value: _artifactType,
                    isExpanded: true,
                    items: _artifactOptions
                        .map(
                          (value) => DropdownMenuItem<StudyArtifactType>(
                            value: value,
                            child: Text(_artifactLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _artifactType = value);
                            }
                          },
                    style: TextStyle(color: text, fontSize: 11),
                    dropdownColor: surface,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: soft,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: border, width: 0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                    label: Text(
                      widget.isEs ? 'Generar' : 'Gerar',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_study.artifacts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SectionLabel(
                    title: 'Resultados',
                    subtitle: widget.isEs
                        ? 'Revisa primero en formato visual.'
                        : 'Revise primeiro em formato visual.',
                    text: text,
                    sub: sub,
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _exportPdf,
                  icon: const Icon(Icons.ios_share_rounded, size: 15),
                  label: Text(
                    'PDF',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _StudyResultModeBar(
              value: _resultView,
              isEs: widget.isEs,
              dark: dark,
              surface: surface,
              border: border,
              text: text,
              sub: sub,
              accent: accent,
              onChanged: (value) => setState(() => _resultView = value),
            ),
            const SizedBox(height: 7),
            if (_resultView == _StudyResultView.visual) ...[
              if (_artifactOf(StudyArtifactType.visualSummary)
                  case final visual?)
                _VisualSummaryPanel(
                  artifact: visual,
                  dark: dark,
                  surface: surface,
                  soft: soft,
                  border: border,
                  text: text,
                  sub: sub,
                  accent: accent,
                )
              else
                _ResultGenerateCallout(
                  icon: Icons.dashboard_customize_outlined,
                  title: widget.isEs ? 'Resumen visual' : 'Resumo visual',
                  subtitle: widget.isEs
                      ? 'Convierte el contenido en bloques claros y revisables.'
                      : 'Transforme o conteúdo em blocos claros e revisáveis.',
                  action: widget.isEs ? 'Generar' : 'Gerar',
                  surface: surface,
                  border: border,
                  text: text,
                  sub: sub,
                  accent: accent,
                  onTap: _busy
                      ? null
                      : () => _generateType(StudyArtifactType.visualSummary),
                ),
              const SizedBox(height: 5),
              if (_artifactOf(StudyArtifactType.mindMap) case final mindMap?)
                _MindMapPanel(
                  artifact: mindMap,
                  surface: surface,
                  soft: soft,
                  border: border,
                  text: text,
                  sub: sub,
                  accent: accent,
                )
              else
                _ResultGenerateCallout(
                  icon: Icons.account_tree_outlined,
                  title: 'Mapa mental',
                  subtitle: widget.isEs
                      ? 'Organiza los conceptos como un árbol visual.'
                      : 'Organize os conceitos como uma árvore visual.',
                  action: widget.isEs ? 'Generar' : 'Gerar',
                  surface: surface,
                  border: border,
                  text: text,
                  sub: sub,
                  accent: accent,
                  onTap: _busy
                      ? null
                      : () => _generateType(StudyArtifactType.mindMap),
                ),
            ] else if (_resultView == _StudyResultView.complete) ...[
              if (_artifactOf(StudyArtifactType.fullSummary) case final full?)
                _MarkdownStudyArtifactCard(
                  artifact: full,
                  surface: surface,
                  border: border,
                  text: text,
                  accent: accent,
                )
              else
                _ResultGenerateCallout(
                  icon: Icons.article_outlined,
                  title: widget.isEs ? 'Resumen completo' : 'Resumo completo',
                  subtitle: widget.isEs
                      ? 'Profundiza en prosa continua.'
                      : 'Aprofunde em prosa contínua.',
                  action: widget.isEs ? 'Generar' : 'Gerar',
                  surface: surface,
                  border: border,
                  text: text,
                  sub: sub,
                  accent: accent,
                  onTap: _busy
                      ? null
                      : () => _generateType(StudyArtifactType.fullSummary),
                ),
              if (_artifactOf(StudyArtifactType.examSummary)
                  case final exam?) ...[
                const SizedBox(height: 5),
                _MarkdownStudyArtifactCard(
                  artifact: exam,
                  surface: surface,
                  border: border,
                  text: text,
                  accent: accent,
                ),
              ],
            ] else ...[
              for (final type in const <StudyArtifactType>[
                StudyArtifactType.keyPoints,
                StudyArtifactType.flashcards,
                StudyArtifactType.questionsAndAnswers,
                StudyArtifactType.multipleChoice,
                StudyArtifactType.oralExam,
                StudyArtifactType.comparisonTable,
              ])
                if (_artifactOf(type) case final training?) ...[
                  _MarkdownStudyArtifactCard(
                    artifact: training,
                    surface: surface,
                    border: border,
                    text: text,
                    accent: accent,
                  ),
                  const SizedBox(height: 5),
                ],
            ],
          ],
        ],
      ),
    );
  }

  static const _artifactOptions = <StudyArtifactType>[
    StudyArtifactType.visualSummary,
    StudyArtifactType.fullSummary,
    StudyArtifactType.examSummary,
    StudyArtifactType.mindMap,
    StudyArtifactType.flashcards,
    StudyArtifactType.questionsAndAnswers,
    StudyArtifactType.multipleChoice,
    StudyArtifactType.oralExam,
    StudyArtifactType.keyPoints,
    StudyArtifactType.comparisonTable,
  ];

  String _artifactLabel(StudyArtifactType type) {
    final pt = <StudyArtifactType, String>{
      StudyArtifactType.visualSummary: 'Resumo visual',
      StudyArtifactType.fullSummary: 'Resumo completo',
      StudyArtifactType.examSummary: 'Resumo para prova',
      StudyArtifactType.mindMap: 'Mapa mental',
      StudyArtifactType.flashcards: 'Flashcards',
      StudyArtifactType.questionsAndAnswers: 'Perguntas e respostas',
      StudyArtifactType.multipleChoice: 'Múltipla escolha',
      StudyArtifactType.oralExam: 'Prova oral',
      StudyArtifactType.keyPoints: 'Pontos-chave',
      StudyArtifactType.comparisonTable: 'Tabela comparativa',
      StudyArtifactType.finalPdf: 'PDF final',
    };

    final es = <StudyArtifactType, String>{
      StudyArtifactType.visualSummary: 'Resumen visual',
      StudyArtifactType.fullSummary: 'Resumen completo',
      StudyArtifactType.examSummary: 'Resumen para examen',
      StudyArtifactType.mindMap: 'Mapa mental',
      StudyArtifactType.flashcards: 'Flashcards',
      StudyArtifactType.questionsAndAnswers: 'Preguntas y respuestas',
      StudyArtifactType.multipleChoice: 'Opción múltiple',
      StudyArtifactType.oralExam: 'Examen oral',
      StudyArtifactType.keyPoints: 'Puntos clave',
      StudyArtifactType.comparisonTable: 'Tabla comparativa',
      StudyArtifactType.finalPdf: 'PDF final',
    };

    return (widget.isEs ? es : pt)[type]!;
  }

  String _mime(String name, StudySourceType type) {
    final lower = name.toLowerCase();
    if (type == StudySourceType.pdf) return 'application/pdf';
    if (type == StudySourceType.image) {
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.webp')) return 'image/webp';
      if (lower.endsWith('.gif')) return 'image/gif';
      return 'image/jpeg';
    }
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.aac')) return 'audio/aac';
    return 'audio/mp4';
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(value, style: const TextStyle(fontSize: 11)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.isEs,
    required this.text,
    required this.sub,
    required this.accent,
    required this.noticeAccepted,
    required this.onLibrary,
    required this.onNew,
  });

  final bool isEs;
  final Color text;
  final Color sub;
  final Color accent;
  final bool noticeAccepted;
  final VoidCallback? onLibrary;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isEs ? 'Estudio' : 'Estudos',
                    style: TextStyle(
                      color: text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (noticeAccepted) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.verified_rounded, size: 14, color: accent),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(
                isEs
                    ? 'Organiza fuentes y crea material de repaso.'
                    : 'Organize fontes e crie material de revisão.',
                style: TextStyle(color: sub, fontSize: 10.2),
              ),
            ],
          ),
        ),
        _HeaderAction(
          icon: Icons.library_books_outlined,
          tooltip: isEs ? 'Biblioteca' : 'Biblioteca',
          onTap: onLibrary,
        ),
        const SizedBox(width: 2),
        _HeaderAction(
          icon: Icons.add_rounded,
          tooltip: isEs ? 'Nuevo estudio' : 'Novo estudo',
          onTap: onNew,
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.subtitle,
    required this.text,
    required this.sub,
  });

  final String title;
  final String subtitle;
  final Color text;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: text,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: TextStyle(color: sub, fontSize: 9.8, height: 1.25),
        ),
      ],
    );
  }
}

class _SourceAction extends StatelessWidget {
  const _SourceAction({
    required this.width,
    required this.icon,
    required this.label,
    required this.surface,
    required this.soft,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final Color surface;
  final Color soft;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 58,
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: 0.7),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 17),
                const Spacer(),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onTap == null ? sub : text,
                    fontSize: 10.2,
                    fontWeight: FontWeight.w700,
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

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.isEs,
    required this.text,
    required this.sub,
    required this.accent,
    required this.onAccept,
  });

  final StudySource source;
  final bool isEs;
  final Color text;
  final Color sub;
  final Color accent;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final refs = source.refs
        .take(3)
        .map((ref) => ref.label(isEs: isEs))
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _sourceIcon(source.type),
            size: 17,
            color: source.state == StudySourceState.accepted ? accent : sub,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  refs.isNotEmpty ? refs : _stateLabel(source.state),
                  style: TextStyle(
                    color: source.state == StudySourceState.accepted
                        ? accent
                        : sub,
                    fontSize: 9.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (onAccept != null)
            SizedBox(
              height: 30,
              child: TextButton(
                onPressed: onAccept,
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  isEs ? 'Aceptar' : 'Aceitar',
                  style: const TextStyle(
                    fontSize: 9.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _stateLabel(StudySourceState state) {
    switch (state) {
      case StudySourceState.added:
        return isEs ? 'Agregada' : 'Adicionada';
      case StudySourceState.processing:
        return isEs ? 'Procesando…' : 'Processando…';
      case StudySourceState.review:
        return isEs ? 'Lista para revisar' : 'Pronta para revisão';
      case StudySourceState.accepted:
        return isEs ? 'Aceptada' : 'Aceita';
      case StudySourceState.failed:
        return isEs ? 'No disponible' : 'Indisponível';
    }
  }

  static IconData _sourceIcon(StudySourceType type) {
    switch (type) {
      case StudySourceType.recordedAudio:
        return Icons.mic_none_rounded;
      case StudySourceType.uploadedAudio:
        return Icons.audio_file_outlined;
      case StudySourceType.pdf:
        return Icons.picture_as_pdf_outlined;
      case StudySourceType.image:
        return Icons.image_outlined;
      case StudySourceType.text:
        return Icons.notes_rounded;
    }
  }
}

enum _StudyResultView { visual, complete, training }

class _StudyResultModeBar extends StatelessWidget {
  const _StudyResultModeBar({
    required this.value,
    required this.isEs,
    required this.dark,
    required this.surface,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.onChanged,
  });

  final _StudyResultView value;
  final bool isEs;
  final bool dark;
  final Color surface;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;
  final ValueChanged<_StudyResultView> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <(_StudyResultView, IconData, String)>[
      (_StudyResultView.visual, Icons.auto_awesome_mosaic_outlined, 'Visual'),
      (_StudyResultView.complete, Icons.article_outlined, 'Completo'),
      (
        _StudyResultView.training,
        Icons.school_outlined,
        isEs ? 'Entrenar' : 'Treino',
      ),
    ];

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(item.$1),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == item.$1
                        ? accent.withValues(alpha: dark ? 0.13 : 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.$2,
                        size: 14,
                        color: value == item.$1 ? accent : sub,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.$3,
                        style: TextStyle(
                          color: value == item.$1 ? text : sub,
                          fontSize: 10,
                          fontWeight: value == item.$1
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisualSummaryPanel extends StatelessWidget {
  const _VisualSummaryPanel({
    required this.artifact,
    required this.dark,
    required this.surface,
    required this.soft,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
  });

  final StudyArtifact artifact;
  final bool dark;
  final Color surface;
  final Color soft;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final data = StudyVisualResultCodec.decodeVisualSummary(artifact.content);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: dark ? 0.12 : 0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.dashboard_customize_outlined,
                  size: 16,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.title.isEmpty ? artifact.title : data.title,
                  style: TextStyle(
                    color: text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (data.overview.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              data.overview,
              style: TextStyle(color: text, fontSize: 10.8, height: 1.48),
            ),
          ],
          if (data.sections.isNotEmpty) ...[
            const SizedBox(height: 9),
            for (var i = 0; i < data.sections.length; i++) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.sections[i].title,
                      style: TextStyle(
                        color: text,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (data.sections[i].body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        data.sections[i].body,
                        style: TextStyle(
                          color: sub,
                          fontSize: 9.8,
                          height: 1.42,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (i < data.sections.length - 1) const SizedBox(height: 4),
            ],
          ],
          if (data.keyPoints.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'PONTOS-CHAVE',
              style: TextStyle(
                color: accent,
                fontSize: 8.7,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            for (final point in data.keyPoints)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 5, right: 6),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          color: text,
                          fontSize: 9.8,
                          height: 1.38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (data.takeaway.isNotEmpty) ...[
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: dark ? 0.08 : 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accent.withValues(alpha: 0.35),
                  width: 0.7,
                ),
              ),
              child: Text(
                data.takeaway,
                style: TextStyle(
                  color: text,
                  fontSize: 9.8,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MindMapPanel extends StatelessWidget {
  const _MindMapPanel({
    required this.artifact,
    required this.surface,
    required this.soft,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
  });

  final StudyArtifact artifact;
  final Color surface;
  final Color soft;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final nodes = StudyVisualResultCodec.decodeMindMap(artifact.content);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 17, color: accent),
              const SizedBox(width: 6),
              Text(
                artifact.title,
                style: TextStyle(
                  color: text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final node in nodes)
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(
                (node.depth * 11).toDouble(),
                0,
                0,
                4,
              ),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: node.depth == 0 ? soft : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: accent.withValues(
                      alpha: node.depth == 0 ? 0.95 : 0.45,
                    ),
                    width: node.depth == 0 ? 2 : 1,
                  ),
                ),
              ),
              child: Text(
                node.text,
                style: TextStyle(
                  color: node.depth == 0 ? text : sub,
                  fontSize: node.depth == 0 ? 10.5 : 9.7,
                  height: 1.35,
                  fontWeight: node.depth == 0
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarkdownStudyArtifactCard extends StatelessWidget {
  const _MarkdownStudyArtifactCard({
    required this.artifact,
    required this.surface,
    required this.border,
    required this.text,
    required this.accent,
  });

  final StudyArtifact artifact;
  final Color surface;
  final Color border;
  final Color text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            artifact.title,
            style: TextStyle(
              color: text,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          MarkdownBody(
            data: artifact.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(color: text, fontSize: 10.4, height: 1.48),
              h1: TextStyle(
                color: text,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
              h2: TextStyle(
                color: text,
                fontSize: 11.7,
                fontWeight: FontWeight.w800,
              ),
              h3: TextStyle(
                color: text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              strong: TextStyle(color: text, fontWeight: FontWeight.w800),
              listBullet: TextStyle(color: accent, fontSize: 10.4),
              blockSpacing: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultGenerateCallout extends StatelessWidget {
  const _ResultGenerateCallout({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.surface,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final Color surface;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: text,
                    fontSize: 10.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(color: sub, fontSize: 9.4, height: 1.3),
                ),
              ],
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              child: Text(
                action,
                style: TextStyle(
                  color: accent,
                  fontSize: 9.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudyPdfSelectionSheet extends StatefulWidget {
  const _StudyPdfSelectionSheet({required this.isEs, required this.available});

  final bool isEs;
  final Set<StudyArtifactType> available;

  @override
  State<_StudyPdfSelectionSheet> createState() =>
      _StudyPdfSelectionSheetState();
}

class _StudyPdfSelectionSheetState extends State<_StudyPdfSelectionSheet> {
  late Set<StudyArtifactType> _selected;

  static const _order = <StudyArtifactType>[
    StudyArtifactType.visualSummary,
    StudyArtifactType.mindMap,
    StudyArtifactType.fullSummary,
    StudyArtifactType.examSummary,
    StudyArtifactType.keyPoints,
    StudyArtifactType.flashcards,
    StudyArtifactType.questionsAndAnswers,
    StudyArtifactType.multipleChoice,
    StudyArtifactType.oralExam,
    StudyArtifactType.comparisonTable,
  ];

  @override
  void initState() {
    super.initState();
    final preferred = <StudyArtifactType>{
      StudyArtifactType.visualSummary,
      StudyArtifactType.mindMap,
    }.intersection(widget.available);

    _selected = preferred.isNotEmpty
        ? preferred
        : Set<StudyArtifactType>.from(widget.available);
  }

  String _label(StudyArtifactType type) {
    final pt = <StudyArtifactType, String>{
      StudyArtifactType.visualSummary: 'Resumo visual',
      StudyArtifactType.mindMap: 'Mapa mental',
      StudyArtifactType.fullSummary: 'Resumo completo',
      StudyArtifactType.examSummary: 'Resumo para prova',
      StudyArtifactType.keyPoints: 'Pontos-chave',
      StudyArtifactType.flashcards: 'Flashcards',
      StudyArtifactType.questionsAndAnswers: 'Perguntas e respostas',
      StudyArtifactType.multipleChoice: 'Múltipla escolha',
      StudyArtifactType.oralExam: 'Prova oral',
      StudyArtifactType.comparisonTable: 'Tabela comparativa',
      StudyArtifactType.finalPdf: 'PDF final',
    };
    final es = <StudyArtifactType, String>{
      StudyArtifactType.visualSummary: 'Resumen visual',
      StudyArtifactType.mindMap: 'Mapa mental',
      StudyArtifactType.fullSummary: 'Resumen completo',
      StudyArtifactType.examSummary: 'Resumen para examen',
      StudyArtifactType.keyPoints: 'Puntos clave',
      StudyArtifactType.flashcards: 'Flashcards',
      StudyArtifactType.questionsAndAnswers: 'Preguntas y respuestas',
      StudyArtifactType.multipleChoice: 'Opción múltiple',
      StudyArtifactType.oralExam: 'Examen oral',
      StudyArtifactType.comparisonTable: 'Tabla comparativa',
      StudyArtifactType.finalPdf: 'PDF final',
    };
    return (widget.isEs ? es : pt)[type]!;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final page = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
    final sub = dark ? const Color(0xFFC6CED9) : const Color(0xFF59636E);
    const accent = Color(0xFF10B981);

    final availableOrdered = _order
        .where(widget.available.contains)
        .toList(growable: false);
    final allSelected = _selected.length == widget.available.length;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        decoration: BoxDecoration(
          color: page,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 34,
              height: 3,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEs ? 'Crear PDF' : 'Gerar PDF',
                          style: TextStyle(
                            color: text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isEs
                              ? 'Elige exactamente qué quieres exportar.'
                              : 'Escolha exatamente o que deseja exportar.',
                          style: TextStyle(color: sub, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selected = allSelected
                            ? <StudyArtifactType>{}
                            : Set<StudyArtifactType>.from(widget.available);
                      });
                    },
                    child: Text(
                      allSelected
                          ? (widget.isEs ? 'Limpiar' : 'Limpar')
                          : (widget.isEs ? 'Todo' : 'Tudo'),
                      style: TextStyle(
                        color: accent,
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.7, color: border),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                itemCount: availableOrdered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, thickness: 0.7, color: border),
                itemBuilder: (_, index) {
                  final type = availableOrdered[index];
                  final checked = _selected.contains(type);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        checked ? _selected.remove(type) : _selected.add(type);
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: Checkbox(
                              value: checked,
                              activeColor: accent,
                              onChanged: (_) {
                                setState(() {
                                  checked
                                      ? _selected.remove(type)
                                      : _selected.add(type);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _label(type),
                              style: TextStyle(
                                color: text,
                                fontSize: 10.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          Set<StudyArtifactType>.from(_selected),
                        ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: Text(
                    widget.isEs
                        ? 'Generar PDF (${_selected.length})'
                        : 'Gerar PDF (${_selected.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
