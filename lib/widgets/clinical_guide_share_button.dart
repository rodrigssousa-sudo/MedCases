import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/clinical_guide_article.dart';
import '../services/clinical_guide_share.dart';

class ClinicalGuideShareButton extends StatefulWidget {
  const ClinicalGuideShareButton(
      {super.key, required this.guide, required this.language});
  final ClinicalGuideArticle guide;
  final String language;

  @override
  State<ClinicalGuideShareButton> createState() =>
      _ClinicalGuideShareButtonState();
}

class _ClinicalGuideShareButtonState extends State<ClinicalGuideShareButton> {
  bool _busy = false;
  bool get _es => widget.language.toLowerCase().startsWith('es');

  Future<void> _act(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final payload = ClinicalGuideSharePayload.fromGuide(widget.guide,
        language: widget.language);
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    try {
      if (action == 'copy') {
        await ClinicalGuideShare.copyLink(payload);
        if (mounted) _message(_es ? 'Enlace copiado' : 'Link copiado');
      } else {
        final png = await ClinicalGuideShare.render(payload);
        if (!mounted) return;
        final confirmed = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ClinicalGuideStoryPreview(payload: payload, png: png),
        );
        if (confirmed != true || !mounted) return;
        await SharePlus.instance
            .share(ClinicalGuideShare.parameters(payload, png, origin));
      }
    } catch (_) {
      if (mounted) {
        _message(_es
            ? 'No se pudo compartir. Intenta copiar el enlace.'
            : 'Não foi possível compartilhar. Tente copiar o link.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        enabled: !_busy,
        tooltip: _es ? 'Compartir guía' : 'Compartilhar guia',
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.ios_share_rounded, size: 20),
        onSelected: _act,
        itemBuilder: (_) => <PopupMenuEntry<String>>[
          PopupMenuItem(
              value: 'share',
              child: Text(_es ? 'Compartir guía' : 'Compartilhar guia')),
          PopupMenuItem(
              value: 'copy',
              child: Text(_es ? 'Copiar enlace' : 'Copiar link')),
        ],
      );
}

/// Displays the exact PNG sent to the native share sheet, never a second render.
class ClinicalGuideStoryPreview extends StatelessWidget {
  const ClinicalGuideStoryPreview(
      {super.key, required this.payload, required this.png});
  final ClinicalGuideSharePayload payload;
  final Uint8List png;

  @override
  Widget build(BuildContext context) {
    final es = payload.language == 'es';
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: Text(es ? 'Vista previa del Story' : 'Prévia do Story',
                      style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                  tooltip: es ? 'Cerrar' : 'Fechar',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 8),
            Expanded(
                child: Center(
                    child: Image.memory(png,
                        key: const ValueKey('guide-story-preview-image'),
                        fit: BoxFit.contain,
                        semanticLabel: payload.title))),
            const SizedBox(height: 12),
            Text(
                es
                    ? 'Si la app no incluye el enlace, cópialo y añádelo al Story.'
                    : 'Se o app não incluir o link, copie e adicione ao Story.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                      onPressed: () async {
                        await ClinicalGuideShare.copyLink(payload);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  es ? 'Enlace copiado' : 'Link copiado')));
                        }
                      },
                      child: Text(es ? 'Copiar enlace' : 'Copiar link')),
                  FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.ios_share_rounded),
                      label:
                          Text(es ? 'Compartir Story' : 'Compartilhar Story')),
                ]),
          ]),
        ),
      ),
    );
  }
}
