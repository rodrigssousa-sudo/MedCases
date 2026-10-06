import '../../../services/ai/safety/clinical_sections.dart';
import '../../../services/ai_pipeline/ai_request_contract.dart';
import '../../../services/study_response_contract.dart';
import 'dart:async';
import 'dart:math' as math;
import 'clinical_markdown_reveal.dart';
import 'ai_response_loading.dart';
import '../../../services/plantao_presentation_contract.dart';
import 'plantao_editorial_style.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../services/ai_stream/stable_response_blocks.dart';
import '../../../services/ai/safety/ai_stream_trace.dart';

class StableClinicalResponseView extends StatefulWidget {
  const StableClinicalResponseView(
      {super.key,
      required this.text,
      required this.streaming,
      required this.dark,
      required this.lang,
      this.notifier,
      this.queryTitle = '',
      this.mode = AiRequestMode.plantao,
      required this.onCopy,
      this.onTts,
      this.ttsPlaying = false,
      this.onReveal,
      this.onVisualComplete,
      this.trailing});
  final AiRequestMode mode;
  final Widget? trailing;
  final String text, lang;
  final String queryTitle;
  final bool streaming, dark, ttsPlaying;
  final ValueNotifier<String>? notifier;
  final VoidCallback onCopy;
  final VoidCallback? onTts, onReveal, onVisualComplete;
  @override
  State<StableClinicalResponseView> createState() =>
      _StableClinicalResponseViewState();
}

class _StableClinicalResponseViewState
    extends State<StableClinicalResponseView> {
  final blocks = StableResponseBlocks();
  final List<ClinicalRevealBlock> _renderBlocks = [];
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _timer;
  Timer? _snapshotTimer;
  String? _lastReadText;
  bool? _lastReadStreaming;
  String? _lastReadLanguage;

  bool get _isPlantao => widget.mode == AiRequestMode.plantao;

  int _mountedBlockCount(int visible) {
    var count = 0;
    var offset = 0;
    for (final block in _renderBlocks) {
      if (offset >= visible) break;
      offset += block.length;
      count++;
    }
    return count;
  }
  int _visible = 0;
  final ValueNotifier<int> _visibleProgress = ValueNotifier(0);
  int _completionTicks = 0;
  int? _firstAvailableMs;
  bool _animate = false, _reduceMotion = false, _completionNotified = false;
  bool get _visualDone => !widget.streaming && _visible >= _total;
  int get _total => _renderBlocks.fold(0, (n, block) => n + block.length);

  @override
  void initState() {
    super.initState();
    _animate = widget.streaming;
    _read();
    widget.notifier?.addListener(_update);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _schedule();
  }

  void _read() {
    final raw = widget.notifier?.value ?? widget.text;
    if (_isPlantao && raw == _lastReadText &&
        widget.streaming == _lastReadStreaming && widget.lang == _lastReadLanguage) return;
    _lastReadLanguage = widget.lang;
    _lastReadText = raw;
    _lastReadStreaming = widget.streaming;
    final study = widget.mode == AiRequestMode.estudo;
    final snapshot = study
        ? StudyResponseContract.normalizePresentation(raw, complete: !widget.streaming)
        : PlantaoPresentationContract.normalize(raw);
    // Plantão previews can end at a validated sentence inside a paragraph.
    // Re-project that mutable tail instead of freezing it as a separate block.
    // Existing parsed blocks remain reusable through the source equality below.
    final projection = _isPlantao && widget.streaming
        ? StableResponseBlocks()
        : blocks;
    projection.accept(
        widget.streaming
            ? PlantaoEditorialStyle.completeMarkdownPrefix(snapshot,
                includeSafeSentenceTail: _isPlantao)
            : ClinicalSections.withoutEmptyHeadings(snapshot),
        complete: !widget.streaming);
    final ready = projection.blocks.toList();
    // A heading is committed visually only with its first complete body block.
    // Original canonical text stays intact for history and truncation detection.
    while (ready.isNotEmpty && RegExp(r'^#{1,6}\s').hasMatch(ready.last)) {
      ready.removeLast();
    }
    for (var i = 0; i < ready.length; i++) {
      if (i < _renderBlocks.length && _renderBlocks[i].source == ready[i])
        continue;
      if (i < _renderBlocks.length)
        _renderBlocks.removeRange(i, _renderBlocks.length);
      _renderBlocks.add(ClinicalRevealBlock(
          ready[i], study ? ready[i] : PlantaoEditorialStyle.formatBlock(ready[i], widget.lang)));
    }
    if (_renderBlocks.length > ready.length) {
      _renderBlocks.removeRange(ready.length, _renderBlocks.length);
    }
    if (_total > 0) _firstAvailableMs ??= _clock.elapsedMilliseconds;
    _schedule();
  }

  void _schedule() {
    if (!_animate || _reduceMotion) {
      _visible = _total;
      _visibleProgress.value = _visible;
      _timer?.cancel();
      _timer = null;
      _afterReveal();
      return;
    }
    if (_visible < _total && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    } else if (_visualDone) {
      _afterReveal();
    }
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _total - _visible;
    if (remaining <= 0) {
      _timer?.cancel();
      _timer = null;
      _afterReveal();
      return;
    }
    // Bound backlog to about 600 ms. Completion catches up within 24 frames,
    // instead of dumping the full final snapshot in a single frame.
    final step = widget.streaming
        ? math.max(3, (remaining / 36).ceil())
        : math.max(
            3, (remaining / math.max(1, 24 - _completionTicks++)).ceil());
    var target = math.min(_total, _visible + step);
    var offset = 0;
    for (final block in _renderBlocks) {
      final end = offset + block.length;
      if (target > offset && target < end && block.atomic) target = end;
      offset = end;
    }
    final first = _visible == 0;
    // The Markdown children already listen to progress. Rebuild the response
    // tree only when a block enters view or the final controls become visible.
    final structureChanged = _mountedBlockCount(_visible) !=
        _mountedBlockCount(target) || first ||
        (!widget.streaming && target == _total);
    if (!_isPlantao || structureChanged) {
      setState(() => _visible = target);
    } else {
      _visible = target;
    }
    _visibleProgress.value = target;
    if (first) {
      AiStreamTrace.mark(
          'FIRST_VISIBLE_CHARACTER_MS', _clock.elapsedMilliseconds);
      AiStreamTrace.mark('VISUAL_REVEAL_DELAY_MS',
          _clock.elapsedMilliseconds - (_firstAvailableMs ?? 0));
    }
    _afterReveal();
  }

  void _afterReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_visible > 0) {
        AiStreamTrace.mark('UI_PARTIAL_RENDERED', _visible);
        widget.onReveal?.call();
      }
      if (_visualDone && !_completionNotified) {
        _completionNotified = true;
        widget.onVisualComplete?.call();
      }
    });
  }

  void _update() {
    if (!mounted) return;
    if (!_isPlantao || _total == 0) {
      setState(_read);
      return;
    }
    // Trailing coalescence always reads the latest cumulative snapshot. Unlike
    // dropping fast chunks, the last arrival is painted even if the network waits.
    _snapshotTimer ??= Timer(const Duration(milliseconds: 32), () {
      _snapshotTimer = null;
      if (mounted) setState(_read);
    });
  }

  @override
  void didUpdateWidget(covariant StableClinicalResponseView old) {
    super.didUpdateWidget(old);
    if (old.notifier != widget.notifier) {
      old.notifier?.removeListener(_update);
      widget.notifier?.addListener(_update);
    }
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    _read();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _snapshotTimer?.cancel();
    widget.notifier?.removeListener(_update);
    _visibleProgress.dispose();
    super.dispose();
  }

  Widget _block(BuildContext context, int index) {
    final block = _renderBlocks[index];
    final data = block.markdown;
    final offset = _renderBlocks.take(index).fold(0, (n, b) => n + b.length);
    final style = PlantaoEditorialStyle.markdown(context, widget.dark);
    final reveal = ClinicalMarkdownReveal(_visibleProgress, style.p!,
        blockOffset: offset, blockLength: block.length);
    final heading = data.startsWith('#');
    return Padding(
      key: ValueKey('clinical_block_$index'),
      padding: PlantaoEditorialStyle.spacing(data, first: index == 0),
      child: Semantics(
        header: heading,
        child: MarkdownBody(
          data: data,
          builders: block.atomic ? const {} : {'p': reveal, 'li': reveal},
          selectable: true,
          onTapLink: (label, href, title) {
            final uri = Uri.tryParse(href ?? '');
            if (uri != null && uri.scheme == 'https') {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          styleSheet: style,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (_visible == 0 && (widget.streaming || !_visualDone))
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AiResponseLoading(
                dark: widget.dark,
                lang: widget.lang,
                showPhrases: _visible == 0)),

      if (_visible > 0 && widget.queryTitle.isNotEmpty &&
          (_renderBlocks.isEmpty || !RegExp(r'^#\s').hasMatch(_renderBlocks.first.source)))
        Padding(padding: const EdgeInsets.only(bottom: 22),
          child: Semantics(header: true, child: Text(widget.queryTitle,
            key: const ValueKey('ai-response-query-title'),
            style: PlantaoEditorialStyle.markdown(context, widget.dark).h1))),
    ];
    var offset = 0;
    for (var i = 0; i < _renderBlocks.length; i++) {
      if (offset >= _visible) break;
      offset += _renderBlocks[i].length;
      if (PlantaoEditorialStyle.isReferenceHeading(_renderBlocks[i].source)) {
        final headingIndex = i;
        final references = <Widget>[];
        while (i + 1 < _renderBlocks.length &&
            !RegExp(r'^#{1,2} ').hasMatch(_renderBlocks[i + 1].source)) {
          if (offset >= _visible) break;
          offset += _renderBlocks[i + 1].length;
          references.add(_block(context, ++i));
        }
        children.add(ExpansionTile(
          key: ValueKey('clinical_references_$headingIndex'),
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          title: Text(
              widget.lang.startsWith('es') ? 'Referencias' : 'Referências',
              style: TextStyle(
                  fontSize: 14,
                  color: widget.dark
                      ? const Color(0xffadb9c7)
                      : const Color(0xff526172))),
          children: references,
        ));
      } else {
        children.add(_block(context, i));
      }
    }
    if (_visualDone &&
        RegExp(r'(?:^|\n)\s*#{1,6}\s+[^\n]+\s*$')
            .hasMatch(widget.text.trimRight())) {
      children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
              widget.lang.startsWith('es')
                  ? 'La respuesta quedó incompleta. Solicita continuar para completar la sección pendiente.'
                  : 'A resposta ficou incompleta. Peça para continuar e concluir a seção pendente.',
              key: const ValueKey('clinical-incomplete-notice'),
              style: TextStyle(
                  fontSize: 13,
                  color: widget.dark
                      ? const Color(0xffadb9c7)
                      : const Color(0xff526172)))));
    }
    if (_visualDone && widget.trailing != null) {
      children.add(widget.trailing!);
    }
    if (_visualDone) {
      children.add(Wrap(spacing: 8, children: [
        TextButton(
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: widget.dark
                    ? const Color(0xff7cccb8)
                    : const Color(0xff126c59)),
            onPressed: widget.onCopy,
            child: const Text('Copiar')),
        if (widget.onTts != null)
          TextButton(
              style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: widget.dark
                      ? const Color(0xff7cccb8)
                      : const Color(0xff126c59)),
              onPressed: widget.onTts,
              child: Text(widget.ttsPlaying
                  ? (widget.lang.startsWith('es') ? 'Detener' : 'Parar')
                  : (widget.lang.startsWith('es') ? 'Escuchar' : 'Ouvir'))),
      ]));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
