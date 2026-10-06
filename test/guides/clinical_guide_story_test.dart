import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_guide_article.dart';
import 'package:medcases/services/clinical_guide_share.dart';
import 'package:medcases/widgets/clinical_guide_share_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ClinicalGuideSharePayload payload(String title,
          {String language = 'pt', String cover = ''}) =>
      ClinicalGuideSharePayload.fromGuide(
          ClinicalGuideArticle(
              id: 'synthetic-guide', title: title, heroImageUrl: cover),
          language: language);

  setUpAll(() async {
    final font = Platform.environment['GUIDE_SHARE_REVIEW_FONT'];
    if (font != null) {
      await (FontLoader('Roboto')
            ..addFont(Future.value(
                ByteData.sublistView(await File(font).readAsBytes()))))
          .load();
    }
  });

  test('official wordmark has transparent background, not the square app icon',
      () async {
    final data = await rootBundle.load(ClinicalGuideShare.logoAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final pixels = (await image.toByteData())!.buffer.asUint8List();
    expect(pixels[3], 0);
    expect(pixels[pixels.length - 1], 0);
    expect([for (var i = 3; i < pixels.length; i += 4) pixels[i]],
        containsAll([0, 255]));
    expect(ClinicalGuideShare.logoAsset, isNot('assets/icon/app_icon.png'));
    image.dispose();
    codec.dispose();
  });

  test('localized guide supplies title, cover and CTA without mixing languages',
      () {
    const guide = ClinicalGuideArticle(
        id: 'guide',
        title: 'Título PT',
        language: 'pt',
        heroImageUrl: 'https://example.test/pt.png',
        localizations: {
          'es': {
            'title': 'Título ES',
            'heroImageUrl': 'https://example.test/es.png'
          }
        });
    final p = ClinicalGuideSharePayload.fromGuide(guide, language: 'es');
    expect(p.title, 'Título ES');
    expect(p.cover, 'https://example.test/es.png');
    expect(p.cta, 'Ver guía en MedCases');
    expect(p.text, isNot(contains('Título PT')));
  });

  for (final light in [true, false]) {
    test('full bleed ${light ? 'light' : 'dark'} guide cover, title and CTA',
        () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final color = light ? const Color(0xFFE9CBA3) : const Color(0xFF183B58);
      canvas.drawColor(color, BlendMode.src);
      // Distinctive guide art to prove the real cached cover is used and cropped.
      canvas.drawCircle(
          const Offset(420, 380),
          170,
          Paint()
            ..color =
                light ? const Color(0xFFC48064) : const Color(0xFF417A8C));
      final picture = recorder.endRecording();
      final cover = await picture.toImage(840, 840);
      picture.dispose();
      final provider = NetworkImage('https://example.test/cover-$light.png');
      final key = await provider.obtainKey(ImageConfiguration.empty);
      PaintingBinding.instance.imageCache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(
              Future.value(ImageInfo(image: cover))));
      await Future<void>.delayed(Duration.zero);
      final p = payload(
          light
              ? 'Cuidados essenciais em cardiologia'
              : 'Atención inicial en urgencias',
          language: light ? 'pt' : 'es',
          cover: provider.url);
      final png = await ClinicalGuideShare.render(p);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      final rgba = (await image.toByteData())!.buffer.asUint8List();
      expect(image.width, 1080);
      expect(image.height, 1920);
      // Center art is preserved rather than a thumbnail, fallback or sidebars.
      final center = (760 * 1080 + 540) * 4;
      expect(rgba[center + 3], 255);
      expect(
          light
              ? rgba[center] > rgba[center + 2]
              : rgba[center + 2] > rgba[center],
          isTrue);
      for (final rect in [
        ClinicalGuideShare.titleArea,
        ClinicalGuideShare.ctaRect
      ]) {
        var whitePixels = 0;
        for (var y = rect.top.toInt(); y < rect.bottom; y += 2) {
          for (var x = rect.left.toInt(); x < rect.right; x += 2) {
            final i = (y * 1080 + x) * 4;
            if (rgba[i] > 235 && rgba[i + 1] > 235 && rgba[i + 2] > 235)
              whitePixels++;
          }
        }
        expect(whitePixels, greaterThan(50), reason: 'Legible title and CTA');
      }
      final output = Platform.environment['GUIDE_SHARE_IMAGE_OUTPUT'];
      if (output != null)
        await File('$output/cover-${light ? 'light' : 'dark'}.png')
            .writeAsBytes(png);
      image.dispose();
      codec.dispose();
      PaintingBinding.instance.imageCache.evict(key);
    });
  }

  test('extreme title cannot overflow safe title region or obscure CTA',
      () async {
    final short = await ClinicalGuideShare.render(payload(''));
    final long = await ClinicalGuideShare.render(payload(
        List.filled(80, 'Abordagem clínica e monitorização').join(' ')));
    Future<(ui.Image, Uint8List)> decode(Uint8List bytes) async {
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      return (image, (await image.toByteData())!.buffer.asUint8List());
    }

    final a = await decode(short), b = await decode(long);
    const titleAndEyebrow = Rect.fromLTRB(72, 868, 1008, 1500);
    var changes = 0;
    for (var y = 0; y < 1920; y += 2) {
      for (var x = 0; x < 1080; x += 2) {
        final i = (y * 1080 + x) * 4;
        if (a.$2[i] != b.$2[i] ||
            a.$2[i + 1] != b.$2[i + 1] ||
            a.$2[i + 2] != b.$2[i + 2]) {
          changes++;
          expect(titleAndEyebrow.contains(Offset(x.toDouble(), y.toDouble())),
              isTrue,
              reason: 'Title escaped safe area at $x,$y');
        }
      }
    }
    expect(changes, greaterThan(100));
    a.$1.dispose();
    b.$1.dispose();
  });

  for (final confirm in [false, true]) {
    testWidgets(
        'article share ${confirm ? 'confirms exact preview bytes' : 'cancel sends nothing'}',
        (tester) async {
      final temp = Directory.systemTemp.createTempSync('medcases-story-test-');
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
      addTearDown(() async {
        messenger.setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
        messenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'), null);
        await temp.delete(recursive: true);
      });
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: ClinicalGuideShareButton(
                  guide: ClinicalGuideArticle(
                      id: 'synthetic', title: 'Guia de teste'),
                  language: 'pt'))));
      await tester.tap(find.byTooltip('Compartilhar guia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compartilhar guia'));
      for (var i = 0;
          i < 30 && find.byType(ClinicalGuideStoryPreview).evaluate().isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 40));
      }
      // The share button remains busy until the preview is dismissed.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ClinicalGuideStoryPreview), findsOneWidget);
      expect(delivered, isNull);
      final png = tester
          .widget<ClinicalGuideStoryPreview>(
              find.byType(ClinicalGuideStoryPreview))
          .png;
      await tester.tap(
          confirm ? find.text('Compartilhar Story') : find.byTooltip('Fechar'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 40));
      }
      if (confirm) {
        expect(delivered, isNotNull);
        final path = (delivered!['paths'] as List).single as String;
        expect(await tester.runAsync(() => File(path).readAsBytes()), png);
        expect(delivered!['text'], contains('https://medcasespro.com'));
      } else {
        expect(delivered, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final language in ['pt', 'es']) {
      for (final width in [320.0, 430.0]) {
        testWidgets(
            'exact PNG preview $platform $language width=$width scaling=2',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p =
              payload(language == 'pt' ? 'Guia' : 'Guía', language: language);
          final png =
              (await tester.runAsync(() => ClinicalGuideShare.render(p)))!;
          await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                  body: MediaQuery(
                      data: MediaQueryData(
                          size: Size(width, 900),
                          textScaler: const TextScaler.linear(2)),
                      child:
                          ClinicalGuideStoryPreview(payload: p, png: png)))));
          await tester.pumpAndSettle();
          final image = tester.widget<Image>(
              find.byKey(const ValueKey('guide-story-preview-image')));
          expect((image.image as MemoryImage).bytes, same(png));
          expect(
              find.text(
                  language == 'es' ? 'Compartir Story' : 'Compartilhar Story'),
              findsOneWidget);
          expect(find.text(language == 'es' ? 'Copiar enlace' : 'Copiar link'),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        }, variant: TargetPlatformVariant({platform}));
      }
    }
  }
}
