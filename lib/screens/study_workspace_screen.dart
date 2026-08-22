import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/study_workspace_model.dart';
import '../services/study/study_artifact_generator.dart';
import '../services/study/study_multimodal_extraction_service.dart';

class StudyWorkspaceScreen extends StatefulWidget {
  const StudyWorkspaceScreen({
    super.key,
    required this.isEs,
    required this.onOpenLongFormAudio,
  });

  final bool isEs;
  final VoidCallback onOpenLongFormAudio;

  @override
  State<StudyWorkspaceScreen> createState() => _StudyWorkspaceScreenState();
}

class _StudyWorkspaceScreenState extends State<StudyWorkspaceScreen> {
  late Study _study;
  final _title = TextEditingController();
  bool _educationalConfirmed = false;
  bool _busy = false;
  StudyArtifactType _artifactType = StudyArtifactType.fullSummary;

  @override
  void initState() {
    super.initState();
    _study = Study(
      id: 'study_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      title: widget.isEs ? 'Nuevo estudio' : 'Novo estudo',
      locale: widget.isEs ? 'es-ES' : 'pt-BR',
      createdAtUtc: DateTime.now().toUtc(),
    );
    _title.text = _study.title;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
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
    final list = List<StudySource>.from(_study.sources);
    final index = list.indexWhere((item) => item.id == source.id);
    if (index < 0) throw StateError('study_source_missing');
    list[index] = source;
    setState(() => _study = _study.copyWith(sources: list));
  }

  Future<void> _addText() async {
    final editor = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.isEs ? 'Agregar texto' : 'Adicionar texto'),
        content: TextField(
          controller: editor,
          autofocus: true,
          minLines: 6,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: widget.isEs
                ? 'Pega aquí el material de estudio…'
                : 'Cole aqui o material de estudo…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editor.text),
            child: Text(widget.isEs ? 'Agregar' : 'Adicionar'),
          ),
        ],
      ),
    );
    editor.dispose();

    final value = result?.trim() ?? '';
    if (value.isEmpty) return;

    final id = _addSource(
      StudySourceType.text,
      widget.isEs ? 'Texto pegado' : 'Texto colado',
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
    } catch (error) {
      _replace(
        source.transition(StudySourceState.failed, error: error.toString()),
      );
    }
  }

  void _recordLecture() {
    _addSource(
      StudySourceType.recordedAudio,
      widget.isEs ? 'Clase grabada' : 'Aula gravada',
    );
    _message(
      widget.isEs
          ? 'Se abre el grabador largo existente. El handoff automático del '
                'M4A revisado a esta fuente entra en la siguiente macrobuild.'
          : 'O gravador longo existente será aberto. O handoff automático do '
                'M4A revisado para esta fonte entra na próxima macrobuild.',
    );
    widget.onOpenLongFormAudio();
  }

  Future<void> _pick(StudySourceType type, List<String> extensions) async {
    if (!_educationalConfirmed) {
      _message(
        widget.isEs
            ? 'Confirma primero que el archivo es material educativo sin '
                  'datos identificables de pacientes.'
            : 'Confirme primeiro que o arquivo é material educacional sem '
                  'dados identificáveis de pacientes.',
      );
      return;
    }

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
    } catch (error) {
      _replace(
        source.transition(StudySourceState.failed, error: error.toString()),
      );
      _message(
        widget.isEs
            ? 'No se pudo procesar la fuente: $error'
            : 'Não foi possível processar a fonte: $error',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _accept(StudySource source) {
    _replace(source.transition(StudySourceState.accepted));
  }

  Future<void> _generate() async {
    if (!_educationalConfirmed) {
      _message(
        widget.isEs
            ? 'Confirma que las fuentes son material educativo sin datos de pacientes.'
            : 'Confirme que as fontes são material educacional sem dados de pacientes.',
      );
      return;
    }
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
    } catch (error) {
      _message(
        widget.isEs
            ? 'No se pudo generar: $error'
            : 'Não foi possível gerar: $error',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final page = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final card = dark ? const Color(0xFF252930) : Colors.white;
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318);
    final sub = dark ? const Color(0xFFC6CED9) : const Color(0xFF52606D);
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
          _Card(
            color: card,
            border: border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEs ? 'Nuevo estudio' : 'Novo estudo',
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _title,
                    onChanged: (value) {
                      final name = value.trim();
                      if (name.isNotEmpty) {
                        _study = _study.copyWith(title: name);
                      }
                    },
                    style: TextStyle(color: text, fontSize: 12.5),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: page,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: border, width: 0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => setState(
                    () => _educationalConfirmed = !_educationalConfirmed,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _educationalConfirmed,
                          activeColor: accent,
                          onChanged: (value) => setState(
                            () => _educationalConfirmed = value ?? false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.isEs
                              ? 'Material educativo sin datos identificables de pacientes.'
                              : 'Material educacional sem dados identificáveis de pacientes.',
                          style: TextStyle(
                            color: sub,
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isEs ? 'Agregar fuentes' : 'Adicionar fontes',
            style: TextStyle(
              color: text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _Action(
                icon: Icons.mic_none_rounded,
                label: widget.isEs ? 'Grabar clase' : 'Gravar aula',
                onTap: _busy ? null : _recordLecture,
              ),
              _Action(
                icon: Icons.audio_file_outlined,
                label: widget.isEs ? 'Enviar audio' : 'Enviar áudio',
                onTap: _busy
                    ? null
                    : () => _pick(StudySourceType.uploadedAudio, const <String>[
                        'm4a',
                        'mp3',
                        'wav',
                        'aac',
                        'mp4',
                      ]),
              ),
              _Action(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                onTap: _busy
                    ? null
                    : () => _pick(StudySourceType.pdf, const <String>['pdf']),
              ),
              _Action(
                icon: Icons.image_outlined,
                label: widget.isEs ? 'Imagen' : 'Imagem',
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
              _Action(
                icon: Icons.text_snippet_outlined,
                label: 'Texto',
                onTap: _busy ? null : _addText,
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 7),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_study.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.isEs ? 'Fuentes del estudio' : 'Fontes do estudo',
              style: TextStyle(
                color: text,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            for (final source in _study.sources) ...[
              _SourceTile(
                source: source,
                isEs: widget.isEs,
                card: card,
                border: border,
                text: text,
                sub: sub,
                accent: accent,
                onAccept: source.state == StudySourceState.review
                    ? () => _accept(source)
                    : null,
              ),
              const SizedBox(height: 5),
            ],
          ],
          const SizedBox(height: 5),
          _Card(
            color: card,
            border: border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEs ? 'Generar con IA' : 'Gerar com IA',
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
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
                  dropdownColor: card,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: page,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: border, width: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(widget.isEs ? 'Generar' : 'Gerar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
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
            const SizedBox(height: 10),
            Text(
              widget.isEs ? 'Productos de estudio' : 'Produtos de estudo',
              style: TextStyle(
                color: text,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            for (final artifact in _study.artifacts.reversed) ...[
              _Card(
                color: card,
                border: border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artifact.title,
                      style: TextStyle(
                        color: text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      artifact.content,
                      style: TextStyle(
                        color: text,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
            ],
          ],
          const SizedBox(height: 6),
          Text(
            widget.isEs
                ? 'Foundation V1 · biblioteca persistente, PDF final y handoff '
                      'automático de la grabación larga: próxima expansión.'
                : 'Foundation V1 · biblioteca persistente, PDF final e handoff '
                      'automático da gravação longa: próxima expansão.',
            style: TextStyle(color: sub, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }

  static const _artifactOptions = <StudyArtifactType>[
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
          content: Text(value, style: const TextStyle(fontSize: 11.5)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.color, required this.border, required this.child});

  final Color color;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: border, width: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.isEs,
    required this.card,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
    required this.onAccept,
  });

  final StudySource source;
  final bool isEs;
  final Color card;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final preview = source.text.trim();
    final refs = source.refs
        .take(4)
        .map((ref) => ref.label(isEs: isEs))
        .join(' · ');

    return _Card(
      color: card,
      border: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  source.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                source.state.name.toUpperCase(),
                style: TextStyle(
                  color: source.state == StudySourceState.accepted
                      ? accent
                      : sub,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (refs.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(refs, style: TextStyle(color: sub, fontSize: 9.5)),
          ],
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              preview.length > 600 ? '${preview.substring(0, 600)}…' : preview,
              style: TextStyle(color: text, fontSize: 10.5, height: 1.38),
            ),
          ],
          if (source.errorCode != null) ...[
            const SizedBox(height: 4),
            Text(
              source.errorCode!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 9.5),
            ),
          ],
          if (onAccept != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: FilledButton(
                onPressed: onAccept,
                child: Text(
                  isEs ? 'Aceptar fuente' : 'Aceitar fonte',
                  style: const TextStyle(fontSize: 10.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
