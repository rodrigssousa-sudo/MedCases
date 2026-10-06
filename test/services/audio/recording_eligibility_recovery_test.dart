import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/audio/transcription_diagnostics.dart';

import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late RecordingSessionController service;
  late Capture capture;
  late DateTime now;
  String? uid;
  late Future<void> Function() eligibility;

  RecordingSessionController create() => RecordingSessionController(
      currentUid: () => uid,
      storageRoot: () async => root,
      captureFactory: () => capture,
      authorize: (_) async {},
      resolveEligibility: () => eligibility(),
      automaticTicks: false,
      now: () => now);

  Future<void> deny() async => throw const TranscriptionFailure(
      TranscriptionFailure.providerBlockedCode,
      retryable: false);

  Future<void> record() async {
    await service.start(language: 'pt', mode: 'study');
    now = now.add(const Duration(seconds: 25));
    await service.stop();
  }

  Future<void> fail(String code) async {
    await expectLater(
        service.transcribe((_, __) async =>
            throw TranscriptionFailure(code, retryable: false)),
        throwsA(isA<TranscriptionFailure>()));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('eligibility-recovery-');
    uid = 'synthetic-owner';
    now = DateTime.utc(2026, 9, 28);
    capture = Capture();
    eligibility = () async {};
    service = create();
  });
  tearDown(() async {
    service.dispose();
    await root.delete(recursive: true);
  });

  test('fresh eligibility recovers only policy failure, preserving saved audio',
      () async {
    await record();
    await fail(TranscriptionFailure.providerBlockedCode);
    final id = service.session!.sessionId;
    final path = capture.path!;
    final bytes = await File(path).readAsBytes();
    eligibility = deny;
    await service.refreshAvailability();
    expect(service.providerBlocked, true);
    expect(service.canTranscribe, false);

    eligibility = () async {};
    await service.refreshAvailability();
    expect(service.providerBlocked, false);
    expect(service.canTranscribe, true);
    expect(service.session!.sessionId, id);
    expect(service.session!.elapsedDurationMs, 25000);
    expect(service.session!.lastErrorCategory, isNull);
    expect(service.session!.transcriptionState, 'pending');
    expect(await File(path).readAsBytes(), bytes);
    expect(capture.starts, 1);
    expect(service.processing, false);

    service.dispose();
    service = create();
    await service.openSession(id);
    expect(service.canTranscribe, true);
    var dispatches = 0;
    await service.transcribe((_, __) async {
      dispatches++;
      return 'Synthetic educational transcript';
    });
    expect(dispatches, 1);
    expect(service.session!.sessionId, id);
  });

  test('policy still denied stays terminal across refresh and restart', () async {
    await record();
    await fail(TranscriptionFailure.providerBlockedCode);
    final id = service.session!.sessionId;
    service.dispose();
    service = create();
    await service.openSession(id);
    eligibility = deny;
    await service.refreshAvailability();
    expect(service.providerBlocked, true);
    expect(service.canTranscribe, false);
    expect(service.session!.transcriptionState, 'terminalError');
  });

  test('network failure is not a positive eligibility decision', () async {
    await record();
    await fail(TranscriptionFailure.providerBlockedCode);
    eligibility = () async => throw const SocketException('offline');
    await expectLater(service.refreshAvailability(),
        throwsA(isA<SocketException>()));
    expect(service.canTranscribe, false);
    expect(service.session!.lastErrorCategory,
        TranscriptionFailure.providerBlockedCode);
  });

  test('positive eligibility never clears an unrelated terminal failure',
      () async {
    await record();
    await fail('INVALID_AUDIO');
    await service.refreshAvailability();
    expect(service.session!.lastErrorCategory, 'INVALID_AUDIO');
    expect(service.session!.transcriptionState, 'terminalError');
    expect(service.canTranscribe, false);
  });

  test('owner switch during eligibility does not recover another owner',
      () async {
    await record();
    await fail(TranscriptionFailure.providerBlockedCode);
    final response = Completer<void>();
    eligibility = () => response.future;
    final refresh = service.refreshAvailability();
    await Future<void>.delayed(Duration.zero);
    uid = 'different-owner';
    response.complete();
    await expectLater(refresh, throwsA(isA<StateError>()));
    expect(service.session, isNull);
  });

  test('older positive response cannot override a newer server denial', () async {
    await record();
    await fail(TranscriptionFailure.providerBlockedCode);
    final older = Completer<void>();
    eligibility = () => older.future;
    final refresh = service.refreshAvailability();
    await Future<void>.delayed(Duration.zero);
    eligibility = deny;
    await service.refreshAvailability();
    older.complete();
    await refresh;
    expect(service.providerBlocked, true);
    expect(service.canTranscribe, false);
    expect(service.session!.transcriptionState, 'terminalError');
  });
}
