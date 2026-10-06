import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/durable_recording_screen.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';

class Capture implements ClinicalLongFormFileCapture {
  int starts = 0, stops = 0, pauses = 0, resumes = 0, cancels = 0;
  String? path;
  bool running = false;
  @override
  Future<void> startSegment(
      {required String path,
      required ClinicalLongFormRecordingConfig config}) async {
    starts++;
    this.path = path;
    running = true;
    await File(path).writeAsBytes([1, 2, 3]);
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<String?> stopSegment() async {
    stops++;
    running = false;
    return path;
  }

  @override
  Future<void> cancelSegment() async {
    cancels++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Capture capture;
  late RecordingSessionController service;
  late DateTime now;
  String? uid;
  RecordingSessionController create() => RecordingSessionController(
      currentUid: () => uid,
      storageRoot: () async => root,
      captureFactory: () => capture,
      authorize: (_) async {},
      now: () => now,
      automaticTicks: false);
  Future<void> start() => service.start(language: 'pt', mode: 'study');
  Future<void> recorded() async {
    await start();
    now = now.add(const Duration(seconds: 10));
    await service.stop();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('recorder1709-');
    capture = Capture();
    now = DateTime.utc(2026, 9, 25);
    uid = 'owner-a';
    service = create();
  });
  tearDown(() async {
    service.dispose();
    await root.delete(recursive: true);
  });
  test('repeated stop preserves original stop timing', () async {
    await recorded();
    final original = Map<String, dynamic>.from(service.session!.job['timings']);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await service.stop();
    expect(service.session!.job['timings'], original);
  });
  test('source retry selects its own older session and saved transcript',
      () async {
    await recorded();
    final first = service.session!.sessionId;
    final firstPath = capture.path;
    await service.transcribe((_, __) async => 'saved first result');
    await service.complete();
    now = now.add(const Duration(minutes: 1));
    await recorded();
    final second = service.session!.sessionId;
    expect(second, isNot(first));
    await service.openSession(first);
    expect(service.session!.sessionId, first);
    expect(service.session!.transcript, 'saved first result');
    expect(await File(firstPath!).exists(), true);
    expect(capture.starts, 2);
    var dispatched = false;
    expect(
        await service.transcribe((_, __) async {
          dispatched = true;
          return 'wrong';
        }),
        'saved first result');
    expect(dispatched, false);
  });
  test('source retry cannot replace another actively recording session',
      () async {
    await start();
    final active = service.session!.sessionId;
    await expectLater(service.openSession('other'), throwsA(isA<Exception>()));
    expect(service.session!.sessionId, active);
    expect(capture.running, true);
  });
  test('start creates durable metadata before using a unique audio path',
      () async {
    await start();
    expect(service.phase, RecordingPhase.recording);
    expect(await File(capture.path!).exists(), true);
    final d = jsonDecode(
        await File('${File(capture.path!).parent.path}/session.json')
            .readAsString());
    expect(d['ownerUid'], uid);
    expect(d['segmentCount'], 1);
    expect(d['audioPath'], capture.path);
  });
  test('detach UI listeners leaves engine recording', () async {
    void view() {}
    service.addListener(view);
    await start();
    service.removeListener(view);
    expect(capture.running, true);
    expect(capture.stops, 0);
  });
  testWidgets('disposing recorder widget does not stop or delete audio',
      (tester) async {
    await tester.runAsync(start);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: DurableRecordingScreen(
            isEs: false, mode: 'study', controller: service)));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(capture.running, true);
    expect(capture.stops, 0);
    expect(File(capture.path!).existsSync(), true);
  });
  test('reopen returns same session and audio path', () async {
    await start();
    final id = service.session!.sessionId;
    final path = capture.path;
    await service.open();
    expect(service.session!.sessionId, id);
    expect(capture.path, path);
    expect(capture.starts, 1);
  });
  test('reattach does not reset 25-minute wall-clock duration', () async {
    await start();
    now = now.add(const Duration(minutes: 25));
    await service.open();
    expect(service.elapsed, const Duration(minutes: 25));
  });
  test('pause freezes elapsed and resume continues the same file', () async {
    await start();
    final path = capture.path;
    now = now.add(const Duration(seconds: 10));
    await service.pause();
    now = now.add(const Duration(minutes: 3));
    expect(service.elapsed, const Duration(seconds: 10));
    await service.resume();
    now = now.add(const Duration(seconds: 5));
    expect(service.elapsed, const Duration(seconds: 15));
    expect(capture.path, path);
    expect(capture.pauses, 1);
    expect(capture.resumes, 1);
  });
  test('explicit stop finalizes without deleting', () async {
    await recorded();
    expect(service.phase, RecordingPhase.recorded);
    expect(capture.stops, 1);
    expect(service.handoff!.segments.single.path, capture.path);
    expect(File(capture.path!).existsSync(), true);
  });
  test('cancel without confirmation cannot stop', () async {
    await start();
    await service.cancel(confirmed: false);
    expect(service.phase, RecordingPhase.recording);
    expect(capture.stops, 0);
  });
  test('confirmed cancel marks session and retains bytes', () async {
    await start();
    await service.cancel(confirmed: true);
    expect(service.phase, RecordingPhase.cancelled);
    expect(service.session!.explicitlyCancelled, true);
    expect(capture.cancels, 0);
    expect(File(capture.path!).lengthSync(), 3);
  });
  testWidgets('cancel UI requires confirmation and can be declined',
      (tester) async {
    await tester.runAsync(start);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: DurableRecordingScreen(
            isEs: false, mode: 'study', controller: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opções da sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar gravação'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar gravação?'), findsOneWidget);
    expect(capture.stops, 0);
    await tester.tap(find.text('Continuar gravação'));
    await tester.pumpAndSettle();
    expect(capture.stops, 0);
  });
  test('transcription exception preserves the entire audio', () async {
    await recorded();
    await expectLater(
        service.transcribe((s, c) async => throw StateError('provider')),
        throwsStateError);
    expect(service.phase, RecordingPhase.recoverableError);
    expect(File(capture.path!).readAsBytesSync(), [1, 2, 3]);
  });
  test('network loss leaves pending state', () async {
    await recorded();
    await expectLater(
        service
            .transcribe((s, c) async => throw const SocketException('offline')),
        throwsA(isA<SocketException>()));
    expect(service.session!.transcriptionState, 'pending');
    expect(File(capture.path!).existsSync(), true);
  });
  test('retry reuses session, job identity and checkpoints', () async {
    await recorded();
    final id = service.session!.sessionId;
    await expectLater(service.transcribe((s, c) async {
      s.transcriptionJobId = 'job-1';
      s.job['part'] = 'kept';
      await c();
      throw StateError('offline');
    }), throwsStateError);
    final text = await service.transcribe((s, c) async {
      expect(s.sessionId, id);
      expect(s.transcriptionJobId, 'job-1');
      expect(s.job['part'], 'kept');
      return 'result';
    });
    expect(text, 'result');
    expect(capture.starts, 1);
  });
  test('concurrent starts never duplicate engine', () async {
    await Future.wait([start(), start(), service.open()]);
    expect(capture.starts, 1);
  });
  test('all lifecycle notifications checkpoint without stopping', () async {
    await start();
    for (final state in AppLifecycleState.values) {
      service.didChangeAppLifecycleState(state);
    }
    await service.tick();
    expect(capture.stops, 0);
    expect(service.phase, RecordingPhase.recording);
  });
  test('cold reopen restores interrupted session, path and elapsed', () async {
    await start();
    now = now.add(const Duration(seconds: 30));
    await service.tick();
    final id = service.session!.sessionId;
    final path = capture.path;
    service.dispose();
    service = create();
    await service.open();
    expect(service.session!.sessionId, id);
    expect(service.phase, RecordingPhase.recoverableError);
    expect(service.elapsed, const Duration(seconds: 30));
    expect(service.session!.segments.single['path'], path);
    expect(capture.starts, 1);
  });
  test('resume recovered session appends instead of overwriting old segment',
      () async {
    await recorded();
    final first = capture.path;
    service.session!.phase = RecordingPhase.recoverableError;
    await service.resume();
    expect(capture.path, isNot(first));
    expect(File(first!).readAsBytesSync(), [1, 2, 3]);
  });
  test('user switch hides old session immediately and preserves audio',
      () async {
    await start();
    final old = capture.path;
    uid = 'owner-b';
    expect(service.session, isNull);
    await service.open();
    expect(service.session, isNull);
    expect(File(old!).existsSync(), true);
    expect(capture.running, false);
  });
  test('correct user can reopen their own previous recording', () async {
    await recorded();
    final id = service.session!.sessionId;
    uid = 'owner-b';
    await service.open();
    uid = 'owner-a';
    await service.open();
    expect(service.session!.sessionId, id);
  });
  test('no cancellation or new capture during unresolved transcription',
      () async {
    await recorded();
    final pending = Completer<String>();
    final job = service.transcribe((s, c) => pending.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.cancel(confirmed: true);
    await start();
    expect(service.processing, true);
    expect(capture.starts, 1);
    expect(File(capture.path!).existsSync(), true);
    pending.complete('done');
    await job;
  });
  test('duplicate transcription requests share one execution', () async {
    await recorded();
    var calls = 0;
    final c = Completer<String>();
    final a = service.transcribe((s, p) {
      calls++;
      return c.future;
    });
    final b = service.transcribe((s, p) async {
      calls++;
      return 'wrong';
    });
    c.complete('done');
    expect(await a, 'done');
    expect(await b, 'done');
    expect(calls, 1);
  });
  test('wrong-user transcript cannot be attached', () async {
    await recorded();
    final c = Completer<String>();
    final job = service.transcribe((s, p) => c.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    uid = 'owner-b';
    c.complete('private result');
    await expectLater(job, throwsStateError);
    expect(service.session, isNull);
  });
  test('cold transcription recovery preserves same job identity', () async {
    await recorded();
    await expectLater(service.transcribe((s, c) async {
      s.transcriptionJobId = 'same';
      await c();
      throw StateError('offline');
    }), throwsStateError);
    service.dispose();
    service = create();
    await service.open();
    expect(service.session!.transcriptionJobId, 'same');
    expect(service.canTranscribe, true);
  });
  test('durable transcript is linked to exact UID and session', () async {
    await recorded();
    await service.transcribe((s, c) async => 'completed');
    final id = service.session!.sessionId;
    service.dispose();
    service = create();
    await service.open();
    expect(service.session!.sessionId, id);
    expect(service.session!.transcript, 'completed');
    expect(service.phase, RecordingPhase.transcribed);
  });
  test('long duration rotates segment while keeping total elapsed', () async {
    await start();
    final first = capture.path;
    now = now.add(const Duration(minutes: 5));
    await service.tick();
    expect(service.elapsed, const Duration(minutes: 5));
    expect(service.session!.segments.length, 2);
    expect(capture.path, isNot(first));
    expect(File(first!).existsSync(), true);
  });
  test('corrupted primary metadata falls back to previous durable checkpoint',
      () async {
    await recorded();
    final file = File('${File(capture.path!).parent.path}/session.json');
    await file.writeAsString('broken');
    service.dispose();
    service = create();
    await service.open();
    expect(service.session, isNotNull);
    expect(service.session!.recoveryAvailable, true);
    expect(File(capture.path!).existsSync(), true);
  });
  test('legacy UID-scoped audio is copied without deleting original', () async {
    final dir = Directory(
        '${root.path}/medcases_study_recorded_audio_state/owner-a/notes_audio_old/audio');
    await dir.create(recursive: true);
    final audio = File('${dir.path}/segment_00000.m4a');
    await audio.writeAsBytes([7, 8, 9]);
    await File('${dir.parent.path}/manifest.json').writeAsString(jsonEncode({
      'schema': 'medcases.long_form_audio_manifest.v1',
      'sessionId': 'notes_audio_old',
      'locale': 'pt-BR',
      'state': 'recording',
      'createdAtUtc': now.toIso8601String(),
      'totalActiveDurationMs': 12000,
      'segments': [
        {
          'index': 0,
          'path': audio.path,
          'startedAtUtc': now.toIso8601String(),
          'activeDurationMs': 12000,
          'completed': false
        }
      ]
    }));
    await service.open();
    expect(service.session!.sessionId, 'notes_audio_old');
    expect(service.phase, RecordingPhase.recoverableError);
    expect(audio.readAsBytesSync(), [7, 8, 9]);
    expect(File(service.session!.segments.single['path']).readAsBytesSync(),
        [7, 8, 9]);
  });
  test('unknown-owner legacy audio is not attached to the logged-in user',
      () async {
    final dir = Directory(
        '${root.path}/medcases_study_recorded_audio_state/another-user');
    await dir.create(recursive: true);
    await service.open();
    expect(service.session, isNull);
  });
  test('SOAP block transition persists block and keeps session identity',
      () async {
    await service.start(language: 'es', mode: 'soapBlocks');
    final id = service.session!.sessionId;
    now = now.add(const Duration(seconds: 12));
    await service.nextBlock();
    expect(service.session!.sessionId, id);
    expect(service.session!.blockIndex, 1);
    expect(service.session!.segments.first['blockIndex'], 0);
    expect(service.session!.segments.last['blockIndex'], 1);
    expect(service.elapsed, const Duration(seconds: 12));
    await service.stop();
    service.dispose();
    service = create();
    await service.open();
    expect(service.session!.blockIndex, 1);
  });
  test('segment reservation expiry rotates instead of ending the session',
      () async {
    await start();
    final id = service.session!.sessionId;
    final path = capture.path;
    now = now.add(const Duration(minutes: 5));
    await service.rotateForQuota(capture);
    expect(service.phase, RecordingPhase.recording);
    expect(service.session!.sessionId, id);
    expect(capture.starts, 2);
    expect(capture.path, isNot(path));
    expect(File(path!).existsSync(), true);
    await service.rotateForQuota(Capture());
    expect(capture.starts, 2);
  });
  for (final es in [false, true]) {
    testWidgets('${es ? 'ES' : 'PT'} localized continuity and controls',
        (tester) async {
      await tester.runAsync(start);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!),
          home: DurableRecordingScreen(
              isEs: es, mode: 'study', controller: service)));
      await tester.pumpAndSettle();
      expect(find.text(es ? 'GRABANDO' : 'GRAVANDO'), findsOneWidget);
      expect(find.text(es ? 'Finalizar grabación' : 'Finalizar gravação'),
          findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(
          find.textContaining(
              es ? 'La grabación está protegida' : 'A gravação está protegida'),
          findsOneWidget);
    });
  }
}
