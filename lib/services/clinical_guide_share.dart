import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/clinical_guide_article.dart';

/// Public editorial metadata only. Never serialize the full guide or user state.
class ClinicalGuideSharePayload {
  ClinicalGuideSharePayload.fromGuide(
    ClinicalGuideArticle guide, {
    required String language,
    Set<String> publishedSlugs = const <String>{},
  })  : guideId = guide.id,
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

  String get text => <String>[
        title,
        if (subtitle.trim().isNotEmpty) subtitle,
        language == 'es' ? 'Ver en MedCases Pro:' : 'Veja no MedCases Pro:',
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
  static const logoAsset = 'assets/icon/app_icon.png';
  static const size = Size(1080, 1350);

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
        targetWidth: 1080);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  /// Fixed canvas bounds are independent of device size and accessibility scale.
  static Future<Uint8List> render(ClinicalGuideSharePayload payload) async {
    final logo = await _asset(logoAsset);
    final cover = await cachedCover(payload.cover);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    try {
      canvas.drawRect(
          Offset.zero & size, Paint()..color = const Color(0xFFF4F7FA));
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1080, 180),
          Paint()..color = const Color(0xFF18202A));
      paintImage(
          canvas: canvas,
          rect: const Rect.fromLTWH(60, 42, 96, 96),
          image: logo,
          fit: BoxFit.contain);
      _text(canvas, 'MedCases Pro', const Offset(182, 64), 820, 40, 1,
          Colors.white);
      final coverRect = const Rect.fromLTWH(60, 220, 960, 450);
      canvas.save();
      canvas.clipRRect(
          RRect.fromRectAndRadius(coverRect, const Radius.circular(24)));
      if (cover != null) {
        paintImage(
            canvas: canvas, rect: coverRect, image: cover, fit: BoxFit.cover);
      } else {
        canvas.drawRect(coverRect, Paint()..color = const Color(0xFFE5EBF1));
        paintImage(
            canvas: canvas,
            rect: const Rect.fromLTWH(430, 270, 220, 220),
            image: logo,
            fit: BoxFit.contain);
        _text(canvas, payload.specialty, const Offset(100, 555), 880, 34, 2,
            const Color(0xFF334155));
      }
      canvas.restore();
      _text(canvas, payload.title, const Offset(60, 718), 960, 56, 4,
          const Color(0xFF18202A));
      _text(canvas, payload.subtitle, const Offset(60, 1008), 960, 32, 4,
          const Color(0xFF64748B));
      canvas.drawLine(const Offset(60, 1220), const Offset(1020, 1220),
          Paint()..color = const Color(0xFFCCD5DF));
      _text(canvas, 'medcasespro.com', const Offset(60, 1260), 960, 30, 1,
          const Color(0xFF334155));
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(1080, 1350);
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
