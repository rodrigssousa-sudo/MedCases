import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:medcases/models/clinical_guide_article.dart';
import 'package:medcases/services/clinical_guide_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native plugin contract: actual temporary PNG and text/URL, iPad anchor',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('medcases-guide-share-test-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Map<Object?, Object?>? delivered;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => temp.path);
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
      delivered = Map<Object?, Object?>.from(call.arguments as Map);
      return 'test-receiver';
    });
    try {
      final p = ClinicalGuideSharePayload.fromGuide(
          const ClinicalGuideArticle(
              id: 'public-guide', title: 'Guia pública', subtitle: 'Subtítulo'),
          language: 'pt');
      final png = await ClinicalGuideShare.render(p);
      await SharePlus.instance.share(ClinicalGuideShare.parameters(
          p, png, const Rect.fromLTWH(10, 10, 36, 36)));
      expect(delivered!['text'], p.text);
      final path = (delivered!['paths'] as List).single as String;
      expect(path, startsWith(temp.path));
      expect(await File(path).readAsBytes(), png);
      expect(delivered!['mimeTypes'], ['image/png']);
      expect([
        delivered!['originX'],
        delivered!['originY'],
        delivered!['originWidth'],
        delivered!['originHeight']
      ], [
        10.0,
        10.0,
        36.0,
        36.0
      ]);
    } finally {
      messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'), null);
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'), null);
      await temp.delete(recursive: true);
    }
  });
  test('rendered bounds and visual evidence: PT ES long fallback', () async {
    final fontPath = Platform.environment['GUIDE_SHARE_REVIEW_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(
            ByteData.sublistView(await File(fontPath).readAsBytes())));
      await loader.load();
    }
    final output = Platform.environment['GUIDE_SHARE_IMAGE_OUTPUT'];
    for (final item in [
      (
        'pt',
        'pt',
        'Guia clínica de cardiologia',
        'Uma referência para consulta e estudo'
      ),
      (
        'es',
        'es',
        'Guía clínica de cardiología',
        'Una referencia para consulta y estudio'
      ),
      (
        'long',
        'pt',
        List.filled(50, 'Título clínico muito longo').join(' '),
        List.filled(50, 'Subtítulo longo').join(' ')
      ),
      ('fallback', 'pt', 'Guia sem capa', '')
    ]) {
      final p = ClinicalGuideSharePayload.fromGuide(
          ClinicalGuideArticle(
              id: 'public',
              title: item.$3,
              subtitle: item.$4,
              specialty: 'Cardiologia'),
          language: item.$2);
      final bytes = await ClinicalGuideShare.render(p);
      final codec = await ui.instantiateImageCodec(bytes);
      final im = (await codec.getNextFrame()).image;
      final rgba = (await im.toByteData())!.buffer.asUint8List();
      // Background gaps between cover/title/subtitle/footer must stay clear.
      for (final y in [690, 990, 1190, 1240]) {
        for (var x = 60; x < 1020; x++) {
          final i = (y * 1080 + x) * 4;
          expect(rgba.sublist(i, i + 3), [244, 247, 250],
              reason: '${item.$1} no overflow at $x,$y');
        }
      }
      // Official logo and domain/text regions must contain rendered content.
      for (final rect in [
        const Rect.fromLTWH(60, 42, 96, 96),
        const Rect.fromLTWH(60, 718, 960, 258),
        const Rect.fromLTWH(60, 1260, 960, 50)
      ]) {
        final colors = <int>{};
        for (var y = rect.top.toInt(); y < rect.bottom; y += 2) {
          for (var x = rect.left.toInt(); x < rect.right; x += 2) {
            final i = (y * 1080 + x) * 4;
            colors.add((rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2]);
          }
        }
        expect(colors.length, greaterThan(1));
      }
      if (output != null) {
        await File('$output/${item.$1}.png').writeAsBytes(bytes);
      }
      im.dispose();
      codec.dispose();
    }
  });
}
