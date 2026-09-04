// MEDCASES_PRODUCTIVE_SECOND_BRAND_B1_V2_R1_STUDY_WORKSPACE
import 'dart:ui' as ui;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../home_v2/theme/home_v2_palette.dart';
import '../home_v2/components/common/home_v2_press_surface.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/study_long_form_audio_handoff.dart';
import '../models/study_workspace_model.dart';
import '../services/study/study_artifact_generator.dart';
import '../services/study/study_title_suggestion_service.dart';
import '../services/study/study_first_use_notice_service.dart';
import '../services/study/study_library_service.dart';
import '../services/study/study_large_file_extraction_service.dart';
import '../services/study/study_imported_audio_pipeline.dart';
import '../services/study/study_long_form_segment_loader.dart';
import '../services/study/study_background_transcription_coordinator.dart';
import '../services/study/study_multimodal_extraction_service.dart';
import '../services/study/study_pdf_export_service.dart';
import '../services/study/study_visual_result_codec.dart';
import 'notes_audio_local_runtime_screen.dart';

class StudyWorkspaceScreen extends StatefulWidget {
  const StudyWorkspaceScreen({
    super.key,
    required this.isEs,
    this.initialStudy,
  });

  final bool isEs;
  final Study? initialStudy;

  @override
  State<StudyWorkspaceScreen> createState() => _StudyWorkspaceScreenState();
}

class _StudyWorkspaceScreenState extends State<StudyWorkspaceScreen> {
  late Study _study;
  final _title = TextEditingController();

  final Map<String, List<String>> _recordedRawPaths = <String, List<String>>{};
  final Map<String, String> _importedAudioJobIds = <String, String>{};

  List<Study> _library = const <Study>[];
  bool _busy = false;
  bool _noticeAccepted = false;
  StudyArtifactType _artifactType = StudyArtifactType.visualSummary;
  _StudyResultView _resultView = _StudyResultView.visual;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    final initialStudy = widget.initialStudy;
    if (initialStudy != null) {
      _study = initialStudy;
    } else {
      _study = Study(
        id: 'study_${now.microsecondsSinceEpoch}',
        title: widget.isEs ? 'Nuevo estudio' : 'Novo estudo',
        locale: widget.isEs ? 'es-ES' : 'pt-BR',
        createdAtUtc: now,
      );
    }
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

    final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final dark = Theme.of(dialogContext).brightness == Brightness.dark;
            final surface = dark ? const Color(0xFF252930) : Colors.white;
            final text =
                dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
            final sub =
                dark ? const Color(0xFFC6CED9) : const Color(0xFF52606D);

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
                    color: Color(0xFF0D6B57),
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
                    backgroundColor: const Color(0xFF0D6B57),
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
          final border =
              dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
          const accent = Color(0xFF0D6B57);
          const destructive = Color(0xFFDC2626);

          Future<void> deleteStudy(Study study) async {
            final ok = await showDialog<bool>(
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
                                      tooltip:
                                          widget.isEs ? 'Eliminar' : 'Excluir',
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

  // MEDCASES_STUDY_AUTO_TOPIC_TITLE_AUDIO_RENAME_V2
  bool _isDefaultStudyTitle(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'novo estudo' || normalized == 'nuevo estudio';
  }

  bool _isAudioSource(StudySourceType type) {
    return type == StudySourceType.recordedAudio ||
        type == StudySourceType.uploadedAudio;
  }

  StudySource _sourceWithTitle(StudySource source, String title) {
    return StudySource(
      id: source.id,
      type: source.type,
      title: title,
      state: source.state,
      createdAtUtc: source.createdAtUtc,
      text: source.text,
      refs: source.refs,
      errorCode: source.errorCode,
    );
  }

  Future<void> _maybeAutoNameFromSource(StudySource reviewed) async {
    final material = reviewed.text.trim();
    if (material.isEmpty) return;

    final shouldNameStudy = _isDefaultStudyTitle(_study.title);
    final shouldNameAudio = _isAudioSource(reviewed.type);
    if (!shouldNameStudy && !shouldNameAudio) return;

    final originalStudyTitle = _study.title;
    final originalSourceTitle = reviewed.title;

    final suggestion = await StudyTitleSuggestionService.suggest(
      text: material,
      isEs: widget.isEs,
    );

    if (suggestion == null || suggestion.trim().isEmpty || !mounted) return;

    var nextStudy = _study;
    final nextSources = List<StudySource>.from(nextStudy.sources);
    var changed = false;

    // Human edit wins if title changed while suggestion was in flight.
    if (shouldNameStudy &&
        nextStudy.title == originalStudyTitle &&
        _isDefaultStudyTitle(nextStudy.title)) {
      nextStudy = nextStudy.copyWith(title: suggestion);
      changed = true;
    }

    if (shouldNameAudio) {
      final index = nextSources.indexWhere((item) => item.id == reviewed.id);
      if (index >= 0 && nextSources[index].title == originalSourceTitle) {
        nextSources[index] = _sourceWithTitle(nextSources[index], suggestion);
        changed = true;
      }
    }

    if (!changed) return;

    setState(() {
      _study = nextStudy.copyWith(sources: nextSources);

      if (_title.text != _study.title) {
        _title.value = TextEditingValue(
          text: _study.title,
          selection: TextSelection.collapsed(offset: _study.title.length),
        );
      }
    });
  }

  Future<void> _renameSource(StudySource source) async {
    if (!_isAudioSource(source.type)) return;

    final editor = TextEditingController(text: source.title);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.isEs ? 'Renombrar audio' : 'Renomear áudio'),
        content: TextField(
          controller: editor,
          autofocus: true,
          maxLength: 64,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: widget.isEs ? 'Nombre del audio' : 'Nome do áudio',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editor.text),
            child: Text(widget.isEs ? 'Guardar' : 'Salvar'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      editor.dispose();
    });

    final name = result?.trim() ?? '';
    if (name.isEmpty || !mounted) return;

    final index = _study.sources.indexWhere((item) => item.id == source.id);
    if (index < 0) return;

    final current = _study.sources[index];
    _replace(_sourceWithTitle(current, name));
    await _persistStudy();
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
                        backgroundColor: const Color(0xFF0D6B57),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      editor.dispose();
    });

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
      await _maybeAutoNameFromSource(source);
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

      final backgroundSession =
          await StudyBackgroundTranscriptionCoordinator.tryStart(
        sourceId: sourceId,
        isEs: widget.isEs,
        segments: <StudyBackgroundSegmentSpec>[
          for (final segment in handoff.segments)
            StudyBackgroundSegmentSpec(
              index: segment.index,
              path: segment.path,
              mimeType: 'audio/mp4',
            ),
        ],
      );

      for (final segment in handoff.segments) {
        late final StudyExtraction extraction;
        if (backgroundSession != null) {
          extraction = StudyExtraction(
            text: await backgroundSession.awaitTranscript(segment.index),
            refs: const [],
          );
        } else {
          final bytes = await StudyLongFormSegmentLoader.read(segment.path);

          extraction = await StudyMultimodalExtractionService.binary(
            sourceId: sourceId,
            type: StudySourceType.recordedAudio,
            fileName: 'segment_${segment.index}.m4a',
            mimeType: 'audio/mp4',
            bytes: Uint8List.fromList(bytes),
            isEs: widget.isEs,
          );
        }

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

      if (backgroundSession != null) {
        await backgroundSession.cleanup();
      }

      _recordedRawPaths[sourceId] = List<String>.unmodifiable(paths);

      source = source.transition(
        StudySourceState.review,
        extractedText: texts.join('\n\n'),
        sourceRefs: List<SourceRef>.unmodifiable(refs),
      );
      _replace(source);
      await _maybeAutoNameFromSource(source);
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

    final isLongInput =
        type == StudySourceType.uploadedAudio || type == StudySourceType.pdf;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withData: !isLongInput,
      withReadStream: isLongInput,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final id = _addSource(type, file.name);
    var source = _source(id).transition(StudySourceState.processing);
    _replace(source);
    setState(() => _busy = true);

    try {
      final StudyExtraction extraction;

      if (type == StudySourceType.uploadedAudio &&
          StudyImportedAudioPipeline.nativePhysicalSegmentationAvailable &&
          file.path != null) {
        final result = await StudyImportedAudioPipeline.process(
          sourceId: id,
          fileName: file.name,
          sourcePath: file.path!,
          fileSize: file.size,
          isEs: widget.isEs,
        );
        extraction = result.extraction;
        _importedAudioJobIds[id] = result.jobId;

        debugPrint(
          '[StudyImportedAudio] complete '
          'segments=${result.segmentCount}/${result.segmentCount}',
        );
      } else if (isLongInput) {
        final stream = file.readStream;
        if (stream == null || file.size <= 0) {
          throw StateError('study_file_stream_unavailable');
        }

        extraction = await StudyLargeFileExtractionService.binaryStream(
          sourceId: id,
          type: type,
          fileName: file.name,
          mimeType: _mime(file.name, type),
          byteLength: file.size,
          byteStream: stream,
          isEs: widget.isEs,
        );
      } else {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          throw StateError('study_file_bytes_unavailable');
        }

        extraction = await StudyMultimodalExtractionService.binary(
          sourceId: id,
          type: type,
          fileName: file.name,
          mimeType: _mime(file.name, type),
          bytes: Uint8List.fromList(bytes),
          isEs: widget.isEs,
        );
      }

      source = source.transition(
        StudySourceState.review,
        extractedText: extraction.text,
        sourceRefs: extraction.refs,
      );

      _replace(source);
      await _maybeAutoNameFromSource(source);
      await _persistStudy();
    } catch (error) {
      await _removeSource(id);
      _message(
        isLongInput
            ? StudyLargeFileExtractionService.friendlyError(
                error,
                isEs: widget.isEs,
              )
            : (widget.isEs
                ? 'No fue posible procesar este archivo.'
                : 'Não foi possível processar este arquivo.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(StudySource source) async {
    final rawPaths = _recordedRawPaths[source.id] ?? const <String>[];
    final importedJobId = _importedAudioJobIds[source.id];

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

    if (source.type == StudySourceType.uploadedAudio && importedJobId != null) {
      try {
        await StudyImportedAudioPipeline.cleanup(importedJobId);
      } catch (_) {
        _message(
          widget.isEs
              ? 'No se pudo limpiar el audio temporal. Intenta nuevamente.'
              : 'Não foi possível limpar o áudio temporário. Tente novamente.',
        );
        return;
      }
    }

    _recordedRawPaths.remove(source.id);
    _importedAudioJobIds.remove(source.id);
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

      final artifacts = _study.artifacts
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
    if (type == StudyArtifactType.mindMap) {
      _message(
        widget.isEs
            ? 'El mapa mental no está disponible por el momento.'
            : 'O mapa mental está indisponível por enquanto.',
      );
      return;
    }

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
    } catch (error, stackTrace) {
      // MEDCASES_STUDY_PDF_RUNTIME_DIAGNOSTIC_V1
      // Do not log artifact/source content. Only exception metadata.
      debugPrint(
        '[StudyPDF][EXPORT_ERROR] '
        'type=${error.runtimeType} error=$error',
      );
      debugPrintStack(
        label: '[StudyPDF][EXPORT_STACK]',
        stackTrace: stackTrace,
      );
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

    final page = dark ? const Color(0xFF1A1D23) : Colors.white;
    final surface = dark ? const Color(0xFF252930) : const Color(0xFFF7F9FB);
    final soft = dark ? const Color(0xFF20242B) : const Color(0xFFF6F8FA);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
    final sub = dark ? const Color(0xFFC6CED9) : const Color(0xFF59636E);
    const accent = Color(0xFF0D6B57);

    return ColoredBox(
      color: page,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
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
          const SizedBox(height: 10),
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
              prefixIcon: Icon(Icons.edit_note_rounded, size: 19, color: sub),
              prefixIconConstraints: const BoxConstraints(minWidth: 42),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border, width: 0.7),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border, width: 0.7),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: accent, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(
            title: widget.isEs ? 'Fuentes' : 'Fontes',
            subtitle: widget.isEs ? 'Agrega material.' : 'Adicione material.',
            text: text,
            sub: sub,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 3.0;
              final columns = constraints.maxWidth >= 720 ? 5 : 3;
              final width =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _SourceAction(
                    width: width,
                    svgAsset:
                        'assets/icons/study_workspace/study_record_lecture.svg',
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
                    svgAsset:
                        'assets/icons/study_workspace/study_import_audio.svg',
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
                              const <String>[
                                'm4a',
                                'mp3',
                                'wav',
                                'aac',
                                'mp4',
                                'ogg',
                                'flac',
                                'aiff'
                              ],
                            ),
                  ),
                  _SourceAction(
                    width: width,
                    svgAsset:
                        'assets/icons/study_workspace/study_import_pdf.svg',
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
                    svgAsset:
                        'assets/icons/study_workspace/study_import_image.svg',
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
                    svgAsset: 'assets/icons/study_workspace/study_add_text.svg',
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
            const SizedBox(height: 18),
            _SectionLabel(
              title: widget.isEs ? 'Fuentes del estudio' : 'Fontes do estudo',
              subtitle: widget.isEs ? 'Revisa y acepta.' : 'Revise e aceite.',
              text: text,
              sub: sub,
            ),
            const SizedBox(height: 4),
            Column(
              children: [
                for (var i = 0; i < _study.sources.length; i++) ...[
                  _SourceRow(
                    source: _study.sources[i],
                    isEs: widget.isEs,
                    text: text,
                    sub: sub,
                    accent: accent,
                    onRename: _isAudioSource(_study.sources[i].type)
                        ? () => _renameSource(_study.sources[i])
                        : null,
                    onAccept: _study.sources[i].state == StudySourceState.review
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
          ],
          const SizedBox(height: 18),
          _SectionLabel(
            title: widget.isEs ? 'Generar con IA' : 'Gerar com IA',
            subtitle: widget.isEs ? 'Fuentes aceptadas.' : 'Fontes aceitas.',
            text: text,
            sub: sub,
          ),
          const SizedBox(height: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<StudyArtifactType>(
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
                style: TextStyle(color: text, fontSize: 11.5),
                dropdownColor: surface,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: border, width: 0.7),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: border, width: 0.7),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: accent, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _generate,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                  label: Text(
                    widget.isEs ? 'Generar material' : 'Gerar material',
                    style: const TextStyle(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_study.artifacts.isNotEmpty) ...[
            const SizedBox(height: 18),
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

    if (lower.endsWith('.mp3')) return 'audio/mp3';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.aiff') || lower.endsWith('.aif')) {
      return 'audio/aiff';
    }
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp4')) return 'audio/mp4';
    return 'application/octet-stream';
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
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (noticeAccepted) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.verified_rounded, size: 14, color: accent),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isEs ? 'Crea material de repaso.' : 'Crie material de revisão.',
                style: TextStyle(color: sub, fontSize: 11.5),
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
      width: 38,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 19),
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
            fontSize: 14.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: sub, fontSize: 10.5, height: 1.25),
        ),
      ],
    );
  }
}

// MEDCASES_STUDY_SOURCE_ACTION_HOME_V2_SHARED_SURFACE_V1_B_R1
// Visual owner intentionally reuses HomeV2PressSurface + HomeV2Palette.
// MEDCASES_STUDY_SOURCE_ACTION_CUSTOM_SVG_CUTOVER_V1_B_R1
class _SourceAction extends StatelessWidget {
  const _SourceAction({
    required this.width,
    required this.svgAsset,
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
  final String svgAsset;
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
    final enabled = onTap != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = HomeV2Palette.resolve(dark);

    return SizedBox(
      width: width,
      child: HomeV2PressSurface(
        palette: palette,
        backgroundColor: surface,
        child: SizedBox(
          height: 104,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: Center(
                        child: SvgPicture.asset(
                          svgAsset,
                          width: 54,
                          height: 54,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: enabled
                            ? palette.textPrimary
                            : sub.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.15,
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

class _StudyAudioProcessingSequence extends StatelessWidget {
  const _StudyAudioProcessingSequence({
    required this.state,
    required this.isEs,
    required this.accent,
    required this.text,
    required this.sub,
  });

  final StudySourceState state;
  final bool isEs;
  final Color accent;
  final Color text;
  final Color sub;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final danger = dark ? const Color(0xFFFCA5A5) : const Color(0xFFB42318);

    if (state == StudySourceState.failed) {
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          isEs ? 'Error al procesar.' : 'Erro ao processar.',
          style: TextStyle(
            color: danger,
            fontSize: 8.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final activeStep = switch (state) {
      StudySourceState.added => 0,
      StudySourceState.processing => 1,
      StudySourceState.review => 2,
      StudySourceState.accepted => 3,
      StudySourceState.failed => 0,
    };

    final labels = isEs
        ? const <String>['Recibido', 'Transcripción', 'Revisión', 'Listo']
        : const <String>['Recebido', 'Transcrição', 'Revisão', 'Pronto'];

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: List<Widget>.generate(labels.length, (index) {
          final accepted = state == StudySourceState.accepted;
          final completed = accepted || index < activeStep;
          final current = !accepted && index == activeStep;
          final active = completed || current;

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 15,
                  height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed ? accent : Colors.transparent,
                    border: Border.all(
                      color: active ? accent : border,
                      width: 0.9,
                    ),
                  ),
                  child: completed
                      ? const Icon(
                          Icons.check_rounded,
                          size: 9.5,
                          color: Colors.white,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: current ? accent : sub,
                            fontSize: 7.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(height: 2),
                Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? text : sub,
                    fontSize: 7.3,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
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
    required this.onRename,
    required this.onAccept,
  });

  final StudySource source;
  final bool isEs;
  final Color text;
  final Color sub;
  final Color accent;
  final VoidCallback? onRename;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final refs =
        source.refs.take(3).map((ref) => ref.label(isEs: isEs)).join(' · ');

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
                if (source.type == StudySourceType.recordedAudio ||
                    source.type == StudySourceType.uploadedAudio)
                  _StudyAudioProcessingSequence(
                    state: source.state,
                    isEs: isEs,
                    accent: accent,
                    text: text,
                    sub: sub,
                  ),
              ],
            ),
          ),
          if (onRename != null)
            SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                onPressed: onRename,
                tooltip: isEs ? 'Renombrar audio' : 'Renomear áudio',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: sub,
                ),
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
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: dark
            ? Border.all(
                color: border.withValues(alpha: 0.30),
                width: 0.5,
              )
            : null,
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(item.$1),
                borderRadius: BorderRadius.circular(9),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == item.$1
                        ? accent.withValues(alpha: dark ? 0.13 : 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.$2,
                        size: 15,
                        color: value == item.$1 ? accent : sub,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.$3,
                        style: TextStyle(
                          color: value == item.$1 ? text : sub,
                          fontSize: 10.8,
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: dark
            ? Border.all(
                color: border.withValues(alpha: 0.28),
                width: 0.5,
              )
            : null,
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

class _MindMapPanel extends StatefulWidget {
  const _MindMapPanel({
    required this.artifact,
    required this.isEs,
    required this.surface,
    required this.soft,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
  });

  final StudyArtifact artifact;
  final bool isEs;
  final Color surface;
  final Color soft;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;

  @override
  State<_MindMapPanel> createState() => _MindMapPanelState();
}

class _MindMapPanelState extends State<_MindMapPanel> {
  bool _downloading = false;

  Future<void> _downloadMindMapOnly() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final rawNodes = StudyVisualResultCodec.decodeMindMap(
        widget.artifact.content,
      );
      final tree = _MindMapTreeBuilder.fromFlat(
        rawNodes,
        fallbackTitle: widget.artifact.title,
      );
      final layout = _MindMapLayoutEngine.layout(tree);
      final svg = _MindMapSvgExporter.render(
        layout,
        title: widget.artifact.title,
      );
      await StudyPdfExportService.shareMindMapVisual(
        title: widget.artifact.title,
        svg: svg,
        isEs: widget.isEs,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.isEs
                  ? 'No fue posible descargar este mapa mental.'
                  : 'Não foi possível baixar este mapa mental.',
              style: const TextStyle(fontSize: 11),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openMindMapExpanded() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _MindMapExpandedScreen(
          artifact: widget.artifact,
          isEs: widget.isEs,
          surface: widget.surface,
          soft: widget.soft,
          border: widget.border,
          text: widget.text,
          sub: widget.sub,
          accent: widget.accent,
          onDownload: _downloadMindMapOnly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final viewportHeight = math.max(
      280.0,
      math.min(340.0, MediaQuery.sizeOf(context).width * 0.82),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.border.withValues(alpha: 0.28),
          width: 0.5,
        ),
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
                  color: widget.accent.withValues(alpha: dark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_tree_outlined,
                  size: 16,
                  color: widget.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.artifact.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.isEs
                          ? 'Horizontal · arrastra y amplía'
                          : 'Horizontal · arraste e amplie',
                      style: TextStyle(
                        color: widget.sub,
                        fontSize: 8.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: widget.isEs
                    ? 'Descargar solo este mapa'
                    : 'Baixar somente este mapa',
                child: TextButton.icon(
                  onPressed: _downloading ? null : _downloadMindMapOnly,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    foregroundColor: widget.accent,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: _downloading
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: widget.accent,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 15),
                  label: const Text(
                    'PDF',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: widget.isEs ? 'Ampliar mapa' : 'Expandir mapa',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                onPressed: _openMindMapExpanded,
                icon: Icon(
                  Icons.open_in_full_rounded,
                  size: 16,
                  color: widget.sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: viewportHeight,
            child: _MindMapCanvas(
              artifact: widget.artifact,
              surface: widget.surface,
              soft: widget.soft,
              border: widget.border,
              text: widget.text,
              sub: widget.sub,
              accent: widget.accent,
              dark: dark,
              expanded: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _MindMapExpandedScreen extends StatelessWidget {
  const _MindMapExpandedScreen({
    required this.artifact,
    required this.isEs,
    required this.surface,
    required this.soft,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.onDownload,
  });

  final StudyArtifact artifact;
  final bool isEs;
  final Color surface;
  final Color soft;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.viewPaddingOf(context).top;
    final topbarSurface = dark
        ? const Color(0xFF252930).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.70);
    final topbarDivider =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 14,
                  sigmaY: 14,
                ),
                child: Container(
                  height: topPad + 48,
                  padding: EdgeInsets.only(top: topPad),
                  decoration: BoxDecoration(
                    color: topbarSurface,
                    border: Border(
                      bottom: BorderSide(
                        color: topbarDivider,
                        width: 0.7,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 42,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: isEs ? 'Volver' : 'Voltar',
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 17,
                                color: text,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Mapa mental',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: text,
                              fontSize: 16,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 42,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: isEs ? 'Descargar mapa' : 'Baixar mapa',
                              onPressed: onDownload,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              icon: Icon(
                                Icons.download_rounded,
                                size: 19,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _MindMapCanvas(
                artifact: artifact,
                surface: surface,
                soft: soft,
                border: border,
                text: text,
                sub: sub,
                accent: accent,
                dark: dark,
                expanded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MindMapCanvas extends StatefulWidget {
  const _MindMapCanvas({
    required this.artifact,
    required this.surface,
    required this.soft,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.dark,
    required this.expanded,
  });

  final StudyArtifact artifact;
  final Color surface;
  final Color soft;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;
  final bool dark;
  final bool expanded;

  @override
  State<_MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends State<_MindMapCanvas> {
  final TransformationController _controller = TransformationController();
  String _fitSignature = '';

  @override
  void didUpdateWidget(covariant _MindMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artifact.id != widget.artifact.id ||
        oldWidget.artifact.content != widget.artifact.content ||
        oldWidget.expanded != widget.expanded) {
      _fitSignature = '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleFit({
    required String signature,
    required double viewportWidth,
    required double viewportHeight,
    required _MindMapLayout layout,
  }) {
    if (_fitSignature == signature) return;
    _fitSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _fitSignature != signature) return;
      final fit = math.min(
        viewportWidth / layout.size.width,
        viewportHeight / layout.size.height,
      );
      final maxScale = widget.expanded ? 1.05 : 0.72;
      final scale = widget.expanded
          ? math.max(0.10, math.min(maxScale, fit * 0.94))
          : math.max(0.045, math.min(maxScale, fit * 0.94));
      final tx = viewportWidth / 2 - layout.center.dx * scale;
      final ty = viewportHeight / 2 - layout.center.dy * scale;
      _controller.value = Matrix4.identity()
        ..translateByDouble(tx, ty, 0.0, 1.0)
        ..scaleByDouble(scale, scale, scale, 1.0);
    });
  }

  void _resetFit() {
    setState(() => _fitSignature = '');
  }

  @override
  Widget build(BuildContext context) {
    final rawNodes = StudyVisualResultCodec.decodeMindMap(
      widget.artifact.content,
    );
    final tree = _MindMapTreeBuilder.fromFlat(
      rawNodes,
      fallbackTitle: widget.artifact.title,
    );
    final layout = _MindMapLayoutEngine.layout(tree);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.expanded ? 0 : 8),
      child: Container(
        decoration: BoxDecoration(
          color:
              widget.dark ? const Color(0xFF1F232A) : const Color(0xFFF7F9FA),
          border: widget.expanded
              ? null
              : Border.all(color: widget.border, width: 0.7),
          borderRadius: widget.expanded ? null : BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final signature = '${widget.artifact.id}:${widget.expanded}:'
                '${constraints.maxWidth.round()}:'
                '${constraints.maxHeight.round()}:'
                '${rawNodes.length}:${layout.size.width.round()}:'
                '${layout.size.height.round()}';
            _scheduleFit(
              signature: signature,
              viewportWidth: constraints.maxWidth,
              viewportHeight: constraints.maxHeight,
              layout: layout,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  transformationController: _controller,
                  constrained: false,
                  alignment: Alignment.center,
                  minScale: 0.04,
                  maxScale: 3.6,
                  boundaryMargin: const EdgeInsets.all(320),
                  panEnabled: true,
                  scaleEnabled: true,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: layout.size.width,
                    height: layout.size.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _MindMapConnectorPainter(
                                edges: layout.edges,
                                dark: widget.dark,
                              ),
                            ),
                          ),
                        ),
                        for (final item in layout.nodes)
                          Positioned.fromRect(
                            rect: item.rect,
                            child: _MindMapNodeCard(
                              item: item,
                              dark: widget.dark,
                              surface: widget.surface,
                              soft: widget.soft,
                              border: widget.border,
                              text: widget.text,
                              sub: widget.sub,
                              accent: widget.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: widget.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: _resetFit,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.border,
                            width: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.center_focus_strong_rounded,
                          size: 16,
                          color: widget.sub,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MindMapTreeNode {
  _MindMapTreeNode({
    required this.title,
    this.summary = '',
    String? fullText,
  }) : fullText =
            fullText ?? (summary.trim().isEmpty ? title : '$title — $summary');

  final String title;
  final String summary;
  final String fullText;
  final List<_MindMapTreeNode> children = <_MindMapTreeNode>[];

  String get text => summary.trim().isEmpty ? title : '$title — $summary';
}

class _MindMapEditorialText {
  const _MindMapEditorialText._();

  static String clean(String value) {
    var text = value
        .replaceAll(RegExp(r'[*_`#]+'), ' ')
        .replaceAll(
          RegExp(
            r'\((?:Áudio|Audio|PDF|Imagem|Imagen|Texto)[^)]{0,80}\)',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'\b(?:Áudio|Audio|PDF|Imagem|Imagen|Texto)\s*·'
            r'\s*(?:p(?:á|a)g\.?\s*)?'
            r'\d{1,3}(?::\d{2})?(?::\d{2})?\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'\b(?:min(?:uto)?s?)\s*[:.-]?\s*\d{1,3}\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text
        .replaceAll(RegExp(r'^[·:;,\-–—\s]+'), '')
        .replaceAll(RegExp(r'[·:;,\-–—\s]+$'), '')
        .trim();
  }

  static String topic(String raw, String fallback) {
    var candidate = clean(raw);
    if (candidate.isEmpty ||
        candidate.toLowerCase() == 'mapa mental' ||
        candidate.toLowerCase() == 'mind map') {
      candidate = clean(fallback);
    }

    candidate = candidate
        .replaceAll(
          RegExp(
            r'\b(?:aula|clase|class)\s*\d+\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (candidate.length > 56) {
      final split = candidate.split(RegExp(r'\s+[|/–—-]\s+|[:;]'));
      if (split.isNotEmpty && split.first.trim().length >= 4) {
        candidate = split.first.trim();
      }
    }

    return _short(candidate, 56, fallback: 'Mapa mental');
  }

  static ({String title, String summary}) category(String raw) {
    final cleanValue = clean(raw)
        .replaceFirst(
          RegExp(r'^(?:resumo|resumen)\s*:\s*', caseSensitive: false),
          '',
        )
        .trim();

    for (final separator in <RegExp>[
      RegExp(r'\s+[—–]\s+'),
      RegExp(r'\s+-\s+'),
      RegExp(r':\s+'),
    ]) {
      final match = separator.firstMatch(cleanValue);
      if (match == null) continue;
      final left = cleanValue.substring(0, match.start).trim();
      final right = cleanValue.substring(match.end).trim();
      if (left.length >= 3 && left.length <= 46 && right.isNotEmpty) {
        return (
          title: _short(left, 46, fallback: 'Categoria'),
          summary: _short(right, 150),
        );
      }
    }

    return (
      title: _short(cleanValue, 46, fallback: 'Categoria'),
      summary: '',
    );
  }

  static String summary(String value, {int max = 150}) {
    final cleaned = clean(value)
        .replaceFirst(
          RegExp(r'^(?:resumo|resumen)\s*:\s*', caseSensitive: false),
          '',
        )
        .trim();
    return _short(cleaned, max);
  }

  static String _short(
    String value,
    int max, {
    String fallback = '',
  }) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) return fallback;
    if (cleanValue.length <= max) return cleanValue;

    final cut = cleanValue.substring(0, max - 1);
    final lastSpace = cut.lastIndexOf(' ');
    final safe = lastSpace >= max ~/ 2 ? cut.substring(0, lastSpace) : cut;
    return '${safe.trim()}…';
  }
}

class _MindMapTreeBuilder {
  const _MindMapTreeBuilder._();

  static _MindMapTreeNode fromFlat(
    List<StudyMindMapNode> flat, {
    required String fallbackTitle,
  }) {
    if (flat.isEmpty) {
      return _MindMapTreeNode(
        title: _MindMapEditorialText.topic(fallbackTitle, 'Mapa mental'),
      );
    }

    var start = 0;
    var rootRaw = fallbackTitle;
    final first = flat.first;
    final firstOwnsNestedContent = first.depth == 0 &&
        flat.skip(1).any((node) => node.depth > first.depth);

    if (firstOwnsNestedContent) {
      rootRaw = first.text;
      start = 1;
    }

    final root = _MindMapTreeNode(
      title: _MindMapEditorialText.topic(rootRaw, fallbackTitle),
      fullText: _MindMapEditorialText.clean(rootRaw),
    );

    if (start >= flat.length) return root;

    final remaining = flat.skip(start).toList(growable: false);
    final minDepth =
        remaining.map((node) => node.depth).reduce((a, b) => math.min(a, b));

    final rawStack = <int, _MindMapTreeNode>{0: root};

    for (final raw in remaining) {
      final normalizedDepth = (raw.depth - minDepth + 1).clamp(1, 3).toInt();

      if (normalizedDepth == 1) {
        final parts = _MindMapEditorialText.category(raw.text);
        final category = _MindMapTreeNode(
          title: parts.title,
          summary: parts.summary,
          fullText: _MindMapEditorialText.clean(raw.text),
        );
        root.children.add(category);
        rawStack[1] = category;
        rawStack.removeWhere((key, _) => key > 1);
        continue;
      }

      var parentDepth = normalizedDepth - 1;
      while (parentDepth > 0 && !rawStack.containsKey(parentDepth)) {
        parentDepth--;
      }

      final parent = rawStack[parentDepth] ?? root;
      final clean = _MindMapEditorialText.summary(
        raw.text,
        max: normalizedDepth == 2 ? 130 : 95,
      );

      if (clean.isEmpty) continue;

      if (normalizedDepth == 2 &&
          parent.summary.trim().isEmpty &&
          clean.length <= 150) {
        final promoted = _MindMapTreeNode(
          title: parent.title,
          summary: clean,
          fullText: parent.fullText,
        )..children.addAll(parent.children);

        final index = root.children.indexOf(parent);
        if (index >= 0) {
          root.children[index] = promoted;
          rawStack[1] = promoted;
        }
        continue;
      }

      final detail = _MindMapTreeNode(
        title: normalizedDepth == 2 ? 'Ponto-chave' : 'Detalhe',
        summary: clean,
        fullText: _MindMapEditorialText.clean(raw.text),
      );

      if (parent.children.length < 3) {
        parent.children.add(detail);
        rawStack[normalizedDepth] = detail;
        rawStack.removeWhere((key, _) => key > normalizedDepth);
      }
    }

    return root;
  }
}

class _MindMapLayoutNode {
  const _MindMapLayoutNode({
    required this.node,
    required this.rect,
    required this.depth,
    required this.branchIndex,
    required this.isRoot,
  });

  final _MindMapTreeNode node;
  final Rect rect;
  final int depth;
  final int branchIndex;
  final bool isRoot;
}

class _MindMapLayoutEdge {
  const _MindMapLayoutEdge({
    required this.from,
    required this.to,
    required this.branchIndex,
    required this.depth,
  });

  final Offset from;
  final Offset to;
  final int branchIndex;
  final int depth;
}

class _MindMapLayout {
  const _MindMapLayout({
    required this.size,
    required this.center,
    required this.focusDiameter,
    required this.nodes,
    required this.edges,
  });

  final Size size;
  final Offset center;
  final double focusDiameter;
  final List<_MindMapLayoutNode> nodes;
  final List<_MindMapLayoutEdge> edges;
}

class _MindMapLayoutEngine {
  const _MindMapLayoutEngine._();

  static const double _horizontalPadding = 74;
  static const double _verticalPadding = 64;
  static const double _columnGap = 310;
  static const double _siblingGap = 34;

  static _MindMapLayout layout(_MindMapTreeNode root) {
    final maxDepth = _maxDepth(root).clamp(0, 3).toInt();
    final rootSize = _nodeSize(root, 0, true);

    final left = <MapEntry<int, _MindMapTreeNode>>[];
    final right = <MapEntry<int, _MindMapTreeNode>>[];
    var leftHeight = 0.0;
    var rightHeight = 0.0;

    for (var i = 0; i < root.children.length; i++) {
      final child = root.children[i];
      final h = _subtreeHeight(child, 1);
      if (leftHeight <= rightHeight) {
        left.add(MapEntry<int, _MindMapTreeNode>(i, child));
        leftHeight += h + _siblingGap;
      } else {
        right.add(MapEntry<int, _MindMapTreeNode>(i, child));
        rightHeight += h + _siblingGap;
      }
    }

    final sideHeight = math.max(
      _groupHeight(left, 1),
      _groupHeight(right, 1),
    );
    final height = math.max(
      760.0,
      sideHeight + _verticalPadding * 2,
    );

    final halfSpan = math.max(1, maxDepth) * _columnGap + 170;
    final width = math.max(
      1420.0,
      rootSize.width + halfSpan * 2 + _horizontalPadding * 2,
    );

    final center = Offset(width / 2, height / 2);
    final rootRect = Rect.fromCenter(
      center: center,
      width: rootSize.width,
      height: rootSize.height,
    );

    final nodes = <_MindMapLayoutNode>[
      _MindMapLayoutNode(
        node: root,
        rect: rootRect,
        depth: 0,
        branchIndex: 0,
        isRoot: true,
      ),
    ];
    final edges = <_MindMapLayoutEdge>[];

    _placeGroup(
      entries: left,
      direction: -1,
      centerY: center.dy,
      depth: 1,
      rootCenterX: center.dx,
      parentRect: rootRect,
      nodes: nodes,
      edges: edges,
    );

    _placeGroup(
      entries: right,
      direction: 1,
      centerY: center.dy,
      depth: 1,
      rootCenterX: center.dx,
      parentRect: rootRect,
      nodes: nodes,
      edges: edges,
    );

    return _MindMapLayout(
      size: Size(width, height),
      center: center,
      focusDiameter: math.max(width, height),
      nodes: List<_MindMapLayoutNode>.unmodifiable(nodes),
      edges: List<_MindMapLayoutEdge>.unmodifiable(edges),
    );
  }

  static void _placeGroup({
    required List<MapEntry<int, _MindMapTreeNode>> entries,
    required int direction,
    required double centerY,
    required int depth,
    required double rootCenterX,
    required Rect parentRect,
    required List<_MindMapLayoutNode> nodes,
    required List<_MindMapLayoutEdge> edges,
  }) {
    if (entries.isEmpty) return;

    final heights = <double>[
      for (final entry in entries) _subtreeHeight(entry.value, depth),
    ];

    final total = heights.fold<double>(
          0,
          (sum, value) => sum + value,
        ) +
        _siblingGap * math.max(0, entries.length - 1);

    var cursor = centerY - total / 2;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final h = heights[i];

      _placeBranch(
        node: entry.value,
        direction: direction,
        depth: depth,
        branchIndex: entry.key,
        top: cursor,
        allocatedHeight: h,
        rootCenterX: rootCenterX,
        parentRect: parentRect,
        nodes: nodes,
        edges: edges,
      );

      cursor += h + _siblingGap;
    }
  }

  static void _placeBranch({
    required _MindMapTreeNode node,
    required int direction,
    required int depth,
    required int branchIndex,
    required double top,
    required double allocatedHeight,
    required double rootCenterX,
    required Rect parentRect,
    required List<_MindMapLayoutNode> nodes,
    required List<_MindMapLayoutEdge> edges,
  }) {
    final size = _nodeSize(node, depth, false);
    final rect = Rect.fromCenter(
      center: Offset(
        rootCenterX + direction * depth * _columnGap,
        top + allocatedHeight / 2,
      ),
      width: size.width,
      height: size.height,
    );

    nodes.add(
      _MindMapLayoutNode(
        node: node,
        rect: rect,
        depth: depth,
        branchIndex: branchIndex,
        isRoot: false,
      ),
    );

    final from = Offset(
      direction > 0 ? parentRect.right : parentRect.left,
      parentRect.center.dy,
    );
    final to = Offset(
      direction > 0 ? rect.left : rect.right,
      rect.center.dy,
    );

    edges.add(
      _MindMapLayoutEdge(
        from: from,
        to: to,
        branchIndex: branchIndex,
        depth: depth,
      ),
    );

    if (node.children.isEmpty || depth >= 3) return;

    final heights = <double>[
      for (final child in node.children) _subtreeHeight(child, depth + 1),
    ];
    final total = heights.fold<double>(
          0,
          (sum, value) => sum + value,
        ) +
        _siblingGap * math.max(0, node.children.length - 1);

    var cursor = rect.center.dy - total / 2;
    for (var i = 0; i < node.children.length; i++) {
      final childHeight = heights[i];
      _placeBranch(
        node: node.children[i],
        direction: direction,
        depth: depth + 1,
        branchIndex: branchIndex,
        top: cursor,
        allocatedHeight: childHeight,
        rootCenterX: rootCenterX,
        parentRect: rect,
        nodes: nodes,
        edges: edges,
      );
      cursor += childHeight + _siblingGap;
    }
  }

  static double _groupHeight(
    List<MapEntry<int, _MindMapTreeNode>> entries,
    int depth,
  ) {
    if (entries.isEmpty) return 0;
    return entries.fold<double>(
          0,
          (sum, entry) => sum + _subtreeHeight(entry.value, depth),
        ) +
        _siblingGap * math.max(0, entries.length - 1);
  }

  static double _subtreeHeight(_MindMapTreeNode node, int depth) {
    final own = _nodeSize(node, depth, false).height;
    if (node.children.isEmpty || depth >= 3) return own;

    final children = node.children.fold<double>(
          0,
          (sum, child) => sum + _subtreeHeight(child, depth + 1),
        ) +
        _siblingGap * math.max(0, node.children.length - 1);

    return math.max(own, children);
  }

  static Size _nodeSize(
    _MindMapTreeNode node,
    int depth,
    bool isRoot,
  ) {
    if (isRoot) {
      return const Size(270, 104);
    }

    final width = depth == 1 ? 258.0 : 230.0;
    final base = depth == 1 ? 98.0 : 76.0;
    final summaryLength = node.summary.length;
    final extra = summaryLength > 90
        ? 22.0
        : summaryLength > 45
            ? 12.0
            : 0.0;

    return Size(width, base + extra);
  }

  static int _maxDepth(_MindMapTreeNode node, [int depth = 0]) {
    var result = depth;
    for (final child in node.children) {
      result = math.max(result, _maxDepth(child, depth + 1));
    }
    return result;
  }
}

class _MindMapNodeCard extends StatelessWidget {
  const _MindMapNodeCard({
    required this.item,
    required this.dark,
    required this.surface,
    required this.soft,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
  });

  final _MindMapLayoutNode item;
  final bool dark;
  final Color surface;
  final Color soft;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final branchColor =
        item.isRoot ? accent : _mindMapBranchColor(item.branchIndex);

    final background = item.isRoot
        ? null
        : item.depth == 1
            ? (dark
                ? branchColor.withValues(alpha: 0.13)
                : branchColor.withValues(alpha: 0.075))
            : surface;

    return Semantics(
      label: item.node.fullText,
      child: Tooltip(
        message: item.node.fullText,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: item.isRoot ? 18 : 14,
            vertical: item.isRoot ? 14 : 11,
          ),
          decoration: BoxDecoration(
            color: background,
            gradient: item.isRoot
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: dark ? 0.24 : 0.13),
                      surface,
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(item.isRoot ? 14 : 10),
            border: Border.all(
              color: item.isRoot
                  ? accent.withValues(alpha: 0.78)
                  : branchColor.withValues(
                      alpha: item.depth == 1 ? 0.62 : 0.34,
                    ),
              width: item.isRoot ? 1.25 : 0.85,
            ),
            boxShadow: item.isRoot
                ? [
                    BoxShadow(
                      color: accent.withValues(
                        alpha: dark ? 0.17 : 0.08,
                      ),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: item.isRoot
              ? Center(
                  child: Text(
                    item.node.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: text,
                      fontSize: 15.2,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.15,
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: item.depth == 1 ? 42 : 30,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: branchColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.node.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: text,
                              fontSize: item.depth == 1 ? 11.4 : 10.2,
                              height: 1.17,
                              fontWeight: item.depth == 1
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                          if (item.node.summary.trim().isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              item.node.summary,
                              maxLines: item.depth == 1 ? 4 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: sub,
                                fontSize: item.depth == 1 ? 9.6 : 9.0,
                                height: 1.28,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MindMapConnectorPainter extends CustomPainter {
  const _MindMapConnectorPainter({
    required this.edges,
    required this.dark,
  });

  final List<_MindMapLayoutEdge> edges;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final color = _mindMapBranchColor(edge.branchIndex);
      final paint = Paint()
        ..color = color.withValues(
          alpha: edge.depth == 1 ? (dark ? 0.76 : 0.64) : (dark ? 0.46 : 0.38),
        )
        ..strokeWidth = edge.depth == 1 ? 2.0 : 1.25
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final direction = edge.to.dx >= edge.from.dx ? 1.0 : -1.0;
      final dx = math.max(
        42.0,
        (edge.to.dx - edge.from.dx).abs() * 0.46,
      );

      final path = Path()
        ..moveTo(edge.from.dx, edge.from.dy)
        ..cubicTo(
          edge.from.dx + dx * direction,
          edge.from.dy,
          edge.to.dx - dx * direction,
          edge.to.dy,
          edge.to.dx,
          edge.to.dy,
        );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapConnectorPainter oldDelegate) {
    return oldDelegate.edges != edges || oldDelegate.dark != dark;
  }
}

class _MindMapSvgExporter {
  const _MindMapSvgExporter._();

  static String render(
    _MindMapLayout layout, {
    required String title,
  }) {
    final width = layout.size.width.ceil();
    final height = layout.size.height.ceil();
    final buffer = StringBuffer()
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="$width" height="$height" '
        'viewBox="0 0 $width $height">',
      )
      ..writeln('<rect width="100%" height="100%" fill="#F7F9FA"/>');

    for (final edge in layout.edges) {
      final color = _svgBranchColor(edge.branchIndex);
      final direction = edge.to.dx >= edge.from.dx ? 1.0 : -1.0;
      final dx = math.max(
        42.0,
        (edge.to.dx - edge.from.dx).abs() * 0.46,
      );
      buffer.writeln(
        '<path d="M ${edge.from.dx.toStringAsFixed(1)} '
        '${edge.from.dy.toStringAsFixed(1)} '
        'C ${(edge.from.dx + dx * direction).toStringAsFixed(1)} '
        '${edge.from.dy.toStringAsFixed(1)}, '
        '${(edge.to.dx - dx * direction).toStringAsFixed(1)} '
        '${edge.to.dy.toStringAsFixed(1)}, '
        '${edge.to.dx.toStringAsFixed(1)} '
        '${edge.to.dy.toStringAsFixed(1)}" '
        'fill="none" stroke="$color" '
        'stroke-opacity="${edge.depth == 1 ? '0.72' : '0.46'}" '
        'stroke-width="${edge.depth == 1 ? '2.2' : '1.5'}" '
        'stroke-linecap="round"/>',
      );
    }

    for (final item in layout.nodes) {
      final rect = item.rect;
      final branch =
          item.isRoot ? '#0D6B57' : _svgBranchColor(item.branchIndex);
      final fill = item.isRoot
          ? '#E7F7F1'
          : item.depth == 1
              ? '#F2FBF8'
              : '#FFFFFF';
      final strokeWidth = item.isRoot ? 1.8 : 1.0;

      buffer.writeln(
        '<rect x="${rect.left.toStringAsFixed(1)}" '
        'y="${rect.top.toStringAsFixed(1)}" '
        'width="${rect.width.toStringAsFixed(1)}" '
        'height="${rect.height.toStringAsFixed(1)}" '
        'rx="${item.isRoot ? 12 : 8}" '
        'fill="$fill" stroke="$branch" '
        'stroke-width="$strokeWidth"/>',
      );

      if (!item.isRoot) {
        buffer.writeln(
          '<rect x="${(rect.left + 8).toStringAsFixed(1)}" '
          'y="${(rect.top + 10).toStringAsFixed(1)}" '
          'width="3" '
          'height="${math.max(18.0, rect.height - 20).toStringAsFixed(1)}" '
          'rx="1.5" fill="$branch"/>',
        );
      }

      final lines = _wrap(
        item.node.text,
        item.isRoot
            ? 30
            : item.depth == 1
                ? 28
                : 25,
      );
      final fontSize = item.isRoot
          ? 13.0
          : item.depth == 1
              ? 11.2
              : 10.2;
      final lineHeight = fontSize * 1.25;
      final total = lines.length * lineHeight;
      var y = rect.center.dy - total / 2 + fontSize;
      final x = rect.left + (item.isRoot ? 14 : 19);

      for (final line in lines.take(4)) {
        buffer.writeln(
          '<text x="${x.toStringAsFixed(1)}" '
          'y="${y.toStringAsFixed(1)}" '
          'font-family="Helvetica,Arial,sans-serif" '
          'font-size="$fontSize" '
          'font-weight="${item.isRoot || item.depth == 1 ? '700' : '500'}" '
          'fill="#17212B">${_xml(line)}</text>',
        );
        y += lineHeight;
      }
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  static List<String> _wrap(String value, int maxChars) {
    final words = value
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty);

    final lines = <String>[];
    var current = '';

    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length <= maxChars || current.isEmpty) {
        current = candidate;
      } else {
        lines.add(current);
        current = word;
      }
      if (lines.length == 4) break;
    }

    if (current.isNotEmpty && lines.length < 4) {
      lines.add(current);
    }

    if (lines.isEmpty) return const <String>['Mapa mental'];
    return lines;
  }

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _svgBranchColor(int index) {
    const palette = <String>[
      '#14B8A6',
      '#38BDF8',
      '#8B5CF6',
      '#22C55E',
      '#F59E0B',
      '#EC4899',
      '#06B6D4',
      '#6366F1',
    ];
    return palette[index % palette.length];
  }
}

Color _mindMapBranchColor(int index) {
  const palette = <Color>[
    Color(0xFF14B8A6),
    Color(0xFF38BDF8),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF6366F1),
  ];
  return palette[index % palette.length];
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: dark
            ? Border.all(
                color: border.withValues(alpha: 0.28),
                width: 0.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            artifact.title,
            style: TextStyle(
              color: text,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          MarkdownBody(
            data: artifact.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(color: text, fontSize: 10.8, height: 1.5),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: dark
            ? Border.all(
                color: border.withValues(alpha: 0.28),
                width: 0.5,
              )
            : null,
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
    // MEDCASES_STUDY_PDF_DEFAULT_ALL_AVAILABLE_V1
    // PDF export starts with every material already selected. The user may
    // still deselect individual products before generating the document.
    _selected = Set<StudyArtifactType>.from(widget.available);
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
    const accent = Color(0xFF0D6B57);

    final availableOrdered =
        _order.where(widget.available.contains).toList(growable: false);
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
