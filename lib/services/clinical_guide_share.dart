import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/clinical_guide_article.dart';

/// Public editorial metadata only. Never serialize the full guide or user state.
class ClinicalGuideSharePayload {
  factory ClinicalGuideSharePayload.fromGuide(
    ClinicalGuideArticle guide, {
    required String language,
    Set<String> publishedSlugs = const <String>{},
  }) =>
      ClinicalGuideSharePayload._(
          guide.forLanguage(language), language, publishedSlugs);

  ClinicalGuideSharePayload._(
      ClinicalGuideArticle guide, String language, Set<String> publishedSlugs)
      : guideId = guide.id,
        slug = guide.slug,
        language = language.toLowerCase().startsWith('es') ? 'es' : 'pt',
        title = guide.title,
        subtitle = guide.subtitle,
        specialty = guide.specialty,
        cover = guide.heroImageUrl,
        publicUrl =
            resolvePublicUrl(guide.publicUrl, guide.slug, publishedSlugs);

  final String guideId, slug, language, title, subtitle, specialty, cover;
  final String publicUrl;

  String get cta =>
      language == 'es' ? 'Ver guía en MedCases' : 'Ver guia no MedCases';

  String get text => <String>[
        title,
        if (subtitle.trim().isNotEmpty) subtitle,
        '$cta:',
        publicUrl,
      ].join('\n\n');

  /// Only public, owned routes: never forward queries, credentials or fragments.
  /// No guide routes have been certified for production yet. An unverified
  /// slug therefore uses the homepage, independently of network availability.
  static String resolvePublicUrl(
      String explicit, String slug, Set<String> publishedSlugs) {
    const home = 'https://medcasespro.com';
    final uri = Uri.tryParse(explicit.trim());
    final path = RegExp(r'^/guias/[a-z0-9]+(?:-[a-z0-9]+)*$');
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'medcasespro.com' &&
        !uri.hasPort &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.path.isEmpty || uri.path == '/' || path.hasMatch(uri.path))) {
      return uri.toString();
    }
    if (publishedSlugs.contains(slug) && path.hasMatch('/guias/$slug')) {
      return '$home/guias/$slug';
    }
    return home;
  }
}

class ClinicalGuideShare {
  // Official transparent wordmark already used by the public MedCases site.
  // The app icon is a different asset with an embedded square background.
  static const logoAsset = 'assets/public_landing/assets/medcases-logo.png';
  static const size = Size(1080, 1920);
  static const safeContent = Rect.fromLTRB(72, 190, 1008, 1660);
  static const logoRect = Rect.fromLTWH(52, 140, 324, 314);
  static const titleArea = Rect.fromLTWH(72, 930, 936, 540);
  static const ctaRect = Rect.fromLTWH(72, 1536, 936, 96);

  /// Reads only an already decoded Flutter image. The loader cannot fetch.
  static Future<ui.Image?> cachedCover(String url) async {
    if (url.isEmpty) return null;
    try {
      if (url.startsWith('assets/') && !url.contains('..')) {
        return await _asset(url);
      }
      final key = await NetworkImage(url).obtainKey(ImageConfiguration.empty);
      final cache = PaintingBinding.instance.imageCache;
      final status = cache.statusForKey(key);
      if (!status.keepAlive && !status.live) return null;
      final stream =
          cache.putIfAbsent(key, () => throw StateError('Cache miss'));
      if (stream == null) return null;
      final done = Completer<ui.Image?>();
      late ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        if (!done.isCompleted) done.complete(info.image.clone());
        info.dispose();
      }, onError: (Object _, StackTrace? stack) {
        if (!done.isCompleted) done.complete(null);
      });
      stream.addListener(listener);
      try {
        return await done.future
            .timeout(const Duration(milliseconds: 200), onTimeout: () => null);
      } finally {
        stream.removeListener(listener);
      }
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _asset(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        targetWidth: 1920,
        allowUpscaling: false);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  /// Reuse the guide's original URL, even if its decoded preview was evicted.
  /// No private state, headers or replacement image are supplied to the loader.
  static Future<ui.Image?> loadCover(String url) async {
    final cached = await cachedCover(url);
    if (cached != null || url.isEmpty || url.startsWith('assets/'))
      return cached;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) return null;
    final done = Completer<ui.Image?>();
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (!done.isCompleted) done.complete(info.image.clone());
      info.dispose();
    }, onError: (Object _, StackTrace? stack) {
      if (!done.isCompleted) done.complete(null);
    });
    stream.addListener(listener);
    try {
      return await done.future.timeout(const Duration(seconds: 8),
          onTimeout: () {
        done.complete(null);
        return null;
      });
    } finally {
      stream.removeListener(listener);
    }
  }

  /// Fixed canvas bounds are independent of device size and accessibility scale.
  static Future<Uint8List> render(ClinicalGuideSharePayload payload) async {
    final logo = await _asset(logoAsset);
    final cover = await loadCover(payload.cover);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    try {
      final bounds = Offset.zero & size;
      canvas.drawRect(bounds, Paint()..color = const Color(0xFF10251E));
      if (cover != null) {
        paintImage(
            canvas: canvas,
            rect: bounds,
            image: cover,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high);
      } else {
        // Branded editorial fallback, never unrelated stock imagery.
        canvas.drawRect(
            bounds,
            Paint()
              ..shader = const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF203D32), Color(0xFF0B1714)])
                  .createShader(bounds));
        canvas.drawCircle(const Offset(940, 640), 580,
            Paint()..color = const Color(0xFF285743).withValues(alpha: .3));
        canvas.drawCircle(
            const Offset(940, 640),
            480,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFC5A567).withValues(alpha: .25));
      }
      // Leave the center of the cover prominent; protect only the text zones.
      canvas.drawRect(
          bounds,
          Paint()
            ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB30A1512),
                  Color(0x050A1512),
                  Color(0xD90A1512),
                  Color(0xFF0A1512)
                ],
                stops: [
                  0,
                  .35,
                  .64,
                  1
                ]).createShader(bounds));
      paintImage(
          canvas: canvas,
          rect: logoRect,
          image: logo,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high);
      final title = _titlePainter(payload.title);
      final titleTop = titleArea.bottom - title.height;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(
          safeContent.left, titleTop - 62, safeContent.right, titleArea.bottom));
      _text(
          canvas,
          payload.language == 'es' ? 'GUÍA CLÍNICA' : 'GUIA CLÍNICO',
          Offset(safeContent.left, titleTop - 62),
          safeContent.width,
          28,
          1,
          const Color(0xFFB8D1C4));
      title.paint(canvas, Offset(titleArea.left, titleTop));
      title.dispose();
      canvas.restore();
      canvas.drawLine(
          const Offset(72, 1500),
          const Offset(156, 1500),
          Paint()
            ..strokeWidth = 4
            ..color = const Color(0xFFC5A567));
      _text(canvas, payload.cta, ctaRect.topLeft, ctaRect.width, 36, 1,
          Colors.white);
      _text(canvas, 'medcasespro.com', const Offset(72, 1600), 936, 28, 1,
          const Color(0xFFB8D1C4));
      final picture = recorder.endRecording();
      try {
        final image =
            await picture.toImage(size.width.toInt(), size.height.toInt());
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) throw StateError('PNG unavailable');
          return bytes.buffer
              .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      logo.dispose();
      cover?.dispose();
    }
  }

  static TextPainter _titlePainter(String value) {
    final title = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    for (var fontSize = 88.0; fontSize >= 56; fontSize -= 4) {
      final painter = TextPainter(
          text: TextSpan(
              text: title,
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: fontSize,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: Colors.white)),
          textDirection: TextDirection.ltr,
          maxLines: 6,
          ellipsis: '…')
        ..layout(maxWidth: titleArea.width);
      if ((!painter.didExceedMaxLines && painter.height <= titleArea.height) ||
          fontSize == 56) return painter;
      painter.dispose();
    }
    throw StateError('Title layout unavailable');
  }

  static void _text(Canvas canvas, String value, Offset offset, double width,
      double fontSize, int lines, Color color) {
    final painter = TextPainter(
      text: TextSpan(
          text: value,
          style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: fontSize,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: color)),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
    painter.dispose();
  }

  /// share_plus materializes fromData files in its temporary directory on
  /// native platforms. Do not delete while a receiving app may still read it.
  static ShareParams parameters(
          ClinicalGuideSharePayload payload, Uint8List png, Rect origin) =>
      ShareParams(
        title: payload.title,
        subject: payload.title,
        text: payload.text,
        files: <XFile>[XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: const <String>['medcases-guia.png'],
        sharePositionOrigin: origin,
      );

  static Future<void> copyLink(ClinicalGuideSharePayload payload) =>
      Clipboard.setData(ClipboardData(text: payload.publicUrl));
}
