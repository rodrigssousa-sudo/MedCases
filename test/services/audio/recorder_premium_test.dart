import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/durable_recording_screen.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/audio/recording_input_level.dart';
import 'package:medcases/services/audio/recording_derived_audio.dart';
import 'package:medcases/services/canonical_catalog_cipher.dart';
import 'package:medcases/services/audio/recording_completion_notice.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons');
    icons.addFont(File(
            '/Users/brunorodrigues/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytes()
        .then((b) => ByteData.sublistView(b)));
    await icons.load();
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (await font.exists()) {
      final loader = FontLoader('RecorderPreview');
      loader.addFont(font.readAsBytes().then((b) => ByteData.sublistView(b)));
      await loader.load();
    }
  });
  late Directory root;
  late Capture capture;
  late RecordingSessionController service;
  String? uid;
  var delivered = 0;
  var failNotification = false;
  RecordingSessionController create() => RecordingSessionController(
      currentUid: () => uid,
      storageRoot: () async => root,
      captureFactory: () => capture,
      authorize: (_) async {},
      automaticTicks: false,
      notifyCompletion: (s) async {
        final dir = File(s.segments.first['path']).parent;
        expect(
            jsonDecode(await File('${dir.path}/transcript.json')
                .readAsString())['text'],
            'Synthetic test only');
        final manifest =
            jsonDecode(await File('${dir.path}/session.json').readAsString());
        expect(manifest['transcriptionState'], 'completed');
        expect(manifest['job']['completionNotificationSent'], true);
        delivered++;
        if (failNotification)
          throw StateError('notification_permission_denied');
      });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('premium1709-');
    capture = Capture();
    uid = 'fixture-user';
    delivered = 0;
    failNotification = false;
    service = create();
  });
  tearDown(() async {
    service.dispose();
    await root.delete(recursive: true);
  });
  Future<void> complete() async {
    await service.start(language: 'pt', mode: 'study');
    await service.stop();
    await service.transcribe((s, checkpoint) async => 'Synthetic test only');
  }

  test(
      'completion notification follows durable transcript and manifest, at most once',
      () async {
    await complete();
    expect(delivered, 1);
    await service
        .transcribe((s, c) async => throw StateError('must_not_execute'));
    expect(delivered, 1);
    service.dispose();
    service = create();
    await service.open();
    await service
        .transcribe((s, c) async => throw StateError('must_not_execute'));
    expect(delivered, 1);
  });
  test('denied notification does not fail saved transcript', () async {
    failNotification = true;
    await complete();
    expect(service.phase, RecordingPhase.transcribed);
    expect(service.session!.transcript, 'Synthetic test only');
  });
  test('notification deep link loads exactly the owned completed session',
      () async {
    await complete();
    final id = service.session!.sessionId;
    expect((await service.loadCompleted(catalogUidHash(uid!), id))!.transcript,
        'Synthetic test only');
    expect(
        await service.loadCompleted(catalogUidHash('another-user'), id), null);
    uid = 'another-user';
    expect(
        await service.loadCompleted(catalogUidHash('fixture-user'), id), null);
    expect(await service.loadCompleted(catalogUidHash(uid!), '../bad'), null);
  });
  test('failed transcription never sends success and retains master', () async {
    await service.start(language: 'es', mode: 'study');
    await service.stop();
    await expectLater(
        service
            .transcribe((s, c) async => throw const SocketException('offline')),
        throwsA(isA<SocketException>()));
    expect(delivered, 0);
    expect(service.session!.lastErrorCategory, 'NETWORK_FAILURE');
    expect(await File(capture.path!).readAsBytes(), [1, 2, 3]);
  });
  test('interruption finalizes audio and explicit resume appends new path',
      () async {
    await service.start(language: 'pt', mode: 'study');
    final path = capture.path;
    final id = service.session!.sessionId;
    await service.interruptCapture();
    expect(service.phase, RecordingPhase.recoverableError);
    expect(await File(path!).readAsBytes(), [1, 2, 3]);
    await service.resume();
    expect(service.session!.sessionId, id);
    expect(capture.path, isNot(path));
  });
  test(
      'notification language, privacy, deterministic IDs and reserved namespace',
      () {
    for (final es in [false, true]) {
      final n = RecordingCompletionNotice(
          ownerUid: 'fixture-user',
          sessionId: 'safe-session',
          language: es ? 'es' : 'pt');
      final again = RecordingCompletionNotice(
          ownerUid: 'fixture-user',
          sessionId: 'safe-session',
          language: es ? 'es' : 'pt');
      expect(n.title, es ? 'Transcripción concluida' : 'Transcrição concluída');
      expect(
          n.body,
          es
              ? 'Tu grabación ya fue transcrita y está lista para revisar.'
              : 'Sua gravação já foi transcrita e está pronta para revisar.');
      expect(n.payload.contains('fixture-user'), false);
      expect(n.payload,
          'recording:${catalogUidHash('fixture-user')}:safe-session');
      expect(n.id, again.id);
      expect(n.id, greaterThanOrEqualTo(0x40000000));
      expect(n.id, lessThanOrEqualTo(0x7fffffff));
    }
  });
  test('real levels, finite values, silence and clipping', () {
    final monitor = RecordingLevelMonitor();
    expect(monitor.add(-60).quality, RecordingInputQuality.tooLow);
    expect(monitor.add(-22).quality, RecordingInputQuality.good);
    expect(monitor.add(-6).quality, RecordingInputQuality.high);
    expect(monitor.add(-.5).quality, RecordingInputQuality.clipping);
    expect(monitor.add(double.nan).quality, RecordingInputQuality.unavailable);
    for (var i = 0; i < 10; i++) {
      monitor.add(-60);
    }
    expect(monitor.add(-60).silenceMs, greaterThan(720));
    expect(monitor.add(-20).silenceMs, 0);
  });
  test('overlap dedup is gated by actual overlap metadata', () {
    expect(
        removeProvenTranscriptOverlap('one two three', 'one two three four',
            hasAudioOverlap: true),
        'four');
    expect(
        removeProvenTranscriptOverlap('one two three', 'one two three four',
            hasAudioOverlap: false),
        'one two three four');
    expect(
        removeProvenTranscriptOverlap('dose 10 mg', 'dose 20 mg next',
            hasAudioOverlap: true),
        'dose 20 mg next');
  });
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(1024, 1366)
  ]) {
    for (final dark in [false, true]) {
      for (final es in [false, true]) {
        for (final state in [
          'recording',
          'paused',
          'transcribing',
          'offline',
          'recovered',
          'low',
          'clipping'
        ]) {
          testWidgets(
              '$state ${size.width} ${dark ? 'dark' : 'light'} ${es ? 'ES' : 'PT'}',
              (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.runAsync(() async {
              await service.start(language: es ? 'es' : 'pt', mode: 'study');
              if (state == 'paused') await service.pause();
              if (['transcribing', 'offline', 'recovered'].contains(state))
                await service.stop();
            });
            if (state == 'transcribing') {
              service.session!.phase = RecordingPhase.transcribing;
              service.session!.transcriptionState = 'partial';
              service.session!.job['segmentTexts'] = {
                '0': 'Synthetic preview text'
              };
            }
            if (state == 'offline') {
              service.session!.phase = RecordingPhase.recoverableError;
              service.session!.lastErrorCategory = 'offline';
              service.session!.transcriptionState = 'retryableError';
            }
            if (state == 'recovered') {
              service.session!.phase = RecordingPhase.recoverableError;
              service.session!.recoveryAvailable = true;
            }
            if (state == 'low' || state == 'clipping' || state == 'recording')
              service.inputLevel.value =
                  RecordingLevelMonitor().add(state == 'low'
                      ? -60
                      : state == 'clipping'
                          ? -.5
                          : -22);
            final key = GlobalKey();
            await tester.pumpWidget(MaterialApp(
                theme: ThemeData(
                    fontFamily: 'RecorderPreview',
                    colorScheme: ColorScheme.fromSeed(
                        seedColor: const Color(0xFF087B59),
                        brightness: dark ? Brightness.dark : Brightness.light),
                    useMaterial3: true),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: true),
                    child: child!),
                home: RepaintBoundary(
                    key: key,
                    child: DurableRecordingScreen(
                        isEs: es, mode: 'study', controller: service))));
            await tester.pumpAndSettle();
            expect(tester.takeException(), null);
            expect(
                find.text(
                    es ? 'Grabación Inteligente' : 'Gravação Inteligente'),
                findsOneWidget);
            if (state == 'recording')
              expect(
                  find
                      .text(es ? 'Finalizar grabación' : 'Finalizar gravação')
                      .hitTestable(),
                  findsOneWidget);
            if (state == 'low')
              expect(
                  find.textContaining(es ? 'Habla un poco' : 'Fale um pouco'),
                  findsOneWidget);
            if (state == 'clipping')
              expect(
                  find.textContaining(
                      es ? 'Posible saturación' : 'Possível saturação'),
                  findsOneWidget);
            if (size.width == 430 && !es && state == 'recording') {
              final boundary = key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final img = await boundary.toImage(pixelRatio: 2);
                final bytes =
                    await img.toByteData(format: ui.ImageByteFormat.png);
                final output = File('${Directory.systemTemp.path}/medcases1709-recorder-qa/premium-${dark ? 'dark' : 'light'}.png');
                await output.parent.create(recursive:true);
                await output.writeAsBytes(bytes!.buffer.asUint8List());
                img.dispose();
              });
            }
            for (var i = 0; i < 6; i++) {
              await tester.drag(find.byType(ListView), const Offset(0, -220));
              await tester.pumpAndSettle();
              expect(tester.takeException(), null);
            }
            if (state == 'transcribing')
              expect(find.text(es ? 'Ver transcripción' : 'Ver transcrição'),
                  findsOneWidget);
            await tester.pumpWidget(const SizedBox());
            await tester.runAsync(() async {});
          });
        }
      }
    }
  }
}
