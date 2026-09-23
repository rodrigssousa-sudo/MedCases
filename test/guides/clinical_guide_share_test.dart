import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'clinical_guide_share_test_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_guide_article.dart';
import 'package:medcases/services/clinical_guide_share.dart';
import 'package:medcases/screens/clinical_guide_article_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Supply an actual branded asset to the otherwise unimplemented test
    // channel. Native tests and visual evidence use the original rootBundle.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = const StringCodec().decodeMessage(message);
      return key == ClinicalGuideShare.logoAsset
          ? ByteData.sublistView(guideShareTestLogo())
          : null;
    });
  }
  ClinicalGuideSharePayload payload(
          {String language = 'pt',
          String title = 'Guia clínica: ação',
          String subtitle = 'Avaliação e atenção',
          String cover = ''}) =>
      ClinicalGuideSharePayload.fromGuide(
          ClinicalGuideArticle(
              id: 'editorial-id',
              title: title,
              subtitle: subtitle,
              heroImageUrl: cover),
          language: language);
  for (final language in ['pt', 'es']) {
    test('$language title/subtitle, accents and public URL', () {
      final p = payload(language: language);
      expect(p.text, startsWith('Guia clínica: ação\n\nAvaliação e atenção'));
      expect(
          p.text,
          contains(language == 'pt'
              ? 'Veja no MedCases Pro:'
              : 'Ver en MedCases Pro:'));
      expect(p.text, endsWith('https://medcasespro.com'));
    });
  }
  test('empty optional subtitle',
      () => expect(payload(subtitle: '').text, isNot(contains('\n\n\n'))));
  test('validated slug only; absent or unverified slug falls back', () {
    expect(
        ClinicalGuideSharePayload.resolvePublicUrl(
            '', 'public-guide', {'public-guide'}),
        'https://medcasespro.com/guias/public-guide');
    expect(ClinicalGuideSharePayload.resolvePublicUrl('', 'public-guide', {}),
        'https://medcasespro.com');
    expect(ClinicalGuideSharePayload.resolvePublicUrl('', '', {}),
        'https://medcasespro.com');
    expect(ClinicalGuideSharePayload.resolvePublicUrl('', '../uid', {'../uid'}),
        'https://medcasespro.com');
  });
  test(
      'explicit public HTTPS URL wins',
      () => expect(
          ClinicalGuideSharePayload.resolvePublicUrl(
              'https://medcasespro.com/guias/guia-publica', 'other', {'other'}),
          'https://medcasespro.com/guias/guia-publica'));
  for (final invalid in [
    'http://medcasespro.com',
    'https://localhost/guias/a',
    'https://medcasespro.com@evil.test/guias/a',
    'https://medcasespro.com/guias/a?token=secret',
    'https://medcasespro.com/guias/a#session',
    'https://medcasespro.com:8443',
    'https://firebasestorage.googleapis.com/private',
    'https://medcasespro.com/users/uid',
    'javascript:alert(1)',
    'https://medcasespro.com/guias/a%2Fb'
  ]) {
    test(
        'reject private/invalid URL $invalid',
        () => expect(
            ClinicalGuideSharePayload.resolvePublicUrl(invalid, '', {}),
            'https://medcasespro.com'));
  }
  test('remote object: unknown private fields excluded', () async {
    final g = ClinicalGuideArticle.fromJson({
      'id': 'public-id',
      'title': 'Título remoto',
      'localizations': {
        'es': {'title': 'Título español', 'subtitle': 'Subtítulo'}
      },
      'patientName': 'PRIVATE_NAME',
      'uid': 'PRIVATE_UID',
      'token': 'PRIVATE_TOKEN',
      'clinicalHistory': 'PRIVATE_HISTORY',
      'labs': 'PRIVATE_LABS',
      'prompt': 'PRIVATE_PROMPT',
      'transcript': 'PRIVATE_TRANSCRIPT',
      'email': 'PRIVATE_EMAIL',
      'session': 'PRIVATE_SESSION',
      'bed': 'PRIVATE_BED',
      'entitlement': 'PRIVATE_ENTITLEMENT'
    }).forLanguage('es');
    final p = ClinicalGuideSharePayload.fromGuide(g, language: 'es');
    final params = ClinicalGuideShare.parameters(
        p, Uint8List.fromList([1, 2, 3]), const Rect.fromLTWH(2, 2, 36, 36));
    expect(params.text, contains('Título español'));
    expect(params.text, isNot(contains('PRIVATE_')));
    expect(params.text, isNot(contains('public-id')));
    expect(params.files!.single.mimeType, 'image/png');
    expect(await params.files!.single.readAsBytes(), [1, 2, 3]);
    expect(params.fileNameOverrides, ['medcases-guia.png']);
    expect(params.sharePositionOrigin!.isEmpty, false);
    expect(g.publicUrl, '');
  });
  test('publicUrl survives localization', () {
    final g = ClinicalGuideArticle.fromJson({
      'title': 'PT',
      'publicUrl': 'https://medcasespro.com/guias/a',
      'localizations': {
        'es': {'title': 'ES'}
      }
    });
    expect(g.forLanguage('es').publicUrl, g.publicUrl);
    expect(g.toJson()['publicUrl'], g.publicUrl);
  });
  test('clipboard receives only public URL', () async {
    Object? sent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') sent = call.arguments;
      return null;
    });
    await ClinicalGuideShare.copyLink(payload());
    expect(sent, {'text': 'https://medcasespro.com'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  test('offline uncached remote and absent cover do not fetch', () async {
    expect(
        await ClinicalGuideShare.cachedCover(
            'https://invalid.example/uncached.png'),
        isNull);
    expect(await ClinicalGuideShare.cachedCover(''), isNull);
    expect(
        await ClinicalGuideShare.cachedCover('assets/not-found.png'), isNull);
  });
  test('decoded official cover reused from cache', () async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawColor(Colors.red, BlendMode.src);
    final picture = rec.endRecording();
    final image = await picture.toImage(16, 16);
    picture.dispose();
    const provider =
        NetworkImage('https://invalid.example/already-decoded.png');
    final key = await provider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: image))));
    await Future<void>.delayed(Duration.zero);
    final cover = await ClinicalGuideShare.cachedCover(provider.url);
    expect(cover, isNotNull);
    expect(cover!.width, 16);
    cover.dispose();
    PaintingBinding.instance.imageCache.evict(key);
  });
  for (final item in [
    ('pt-normal', 'pt', 'Guia clínica', 'Avaliação e atenção'),
    ('es-normal', 'es', 'Guía clínica', 'Evaluación y atención'),
    (
      'long',
      'pt',
      List.filled(100, 'Título muito longo').join(' '),
      List.filled(100, 'Subtítulo').join(' ')
    ),
    ('fallback', 'pt', 'Guia sem capa', '')
  ]) {
    test('PNG 1080x1350 offline ${item.$1}', () async {
      final bytes = await ClinicalGuideShare.render(
          payload(language: item.$2, title: item.$3, subtitle: item.$4));
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1080);
      expect(image.height, 1350);
      image.dispose();
      codec.dispose();
    });
  }
  testWidgets('detail share/copy and feedback PT', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    await tester.pumpWidget(const MaterialApp(
        home: ClinicalGuideArticleScreen(
            guide: ClinicalGuideArticle(id: 'x', title: 'Guia'), lang: 'pt')));
    await tester.tap(find.byTooltip('Compartilhar guia'));
    await tester.pumpAndSettle();
    expect(find.text('Copiar link'), findsOneWidget);
    await tester.tap(find.text('Copiar link'));
    await tester.pumpAndSettle();
    expect(find.text('Link copiado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  testWidgets('Spanish menu, high text scale', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640), textScaler: TextScaler.linear(2)),
            child: const ClinicalGuideArticleScreen(
                guide: ClinicalGuideArticle(id: 'x', title: 'Guía'),
                lang: 'es'))));
    await tester.tap(find.byTooltip('Compartir guía'));
    await tester.pumpAndSettle();
    expect(find.text('Copiar enlace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
