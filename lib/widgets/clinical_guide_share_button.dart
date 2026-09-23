import 'package:flutter/material.dart';
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
