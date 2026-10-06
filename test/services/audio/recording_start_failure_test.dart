import 'package:medcases/services/entitlement_service.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/audio/recording_start_failure.dart';
import 'package:medcases/services/audio/record_long_form_audio_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/transcription_quota.dart';
import '../record_usage_integration_test.dart' show RecorderTransport;
import 'reconstruction_recording_owner_test.dart' show Capture;

class FailingCapture extends Capture {
  @override
  Future<void> startSegment(
      {required String path,
      required ClinicalLongFormRecordingConfig config}) async {
    throw const RecordingStartFailure(
        'AUDIO_SESSION_ACTIVATION_FAILED', 'audio_session');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('productive capture capability permits Free without granting long-form',
      () {
    expect(RecordingSessionController.captureCapability,
        MedCasesCapability.audioBasic);
    expect(
        EntitlementService.instance
            .canUse(RecordingSessionController.captureCapability),
        true);
    expect(EntitlementService.instance.canUse(MedCasesCapability.audioLongForm),
        false);
  });
  late Directory root;
  late RecordingSessionController service;
  var fail = false;
  var available = 900000;
  var now = DateTime.utc(2026, 9, 29);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('record-start-');
    fail = false;
    available = 900000;
    service = RecordingSessionController(
        currentUid: () => 'synthetic',
        storageRoot: () async => root,
        captureFactory: () => fail ? FailingCapture() : Capture(),
        authorize: (_) async {},
        automaticTicks: false,
        now: () => now,
        resolveQuota: () async => TranscriptionQuota(
            owner: 'synthetic',
            period: '2026-09',
            premium: false,
            allowanceMs: 900000,
            usedMs: 900000 - available,
            reservedMs: 0,
            remainingMs: available));
  });
  tearDown(() async {
    service.dispose();
    await root.delete(recursive: true);
  });
  test('completed A + Free 15 minutes starts B and retains A history',
      () async {
    await service.start(language: 'es', mode: 'study');
    now = now.add(const Duration(seconds: 15));
    await service.stop();
    await service.complete();
    final a = service.session!;
    await service.start(language: 'es', mode: 'study');
    expect(service.session!.sessionId, isNot(a.sessionId));
    expect(service.phase, RecordingPhase.recording);
    now = now.add(const Duration(seconds: 2));
    expect(service.elapsed.inSeconds, 2);
    expect(await File(a.segments.first['path'] as String).readAsBytes(),
        [1, 2, 3]);
    await service.stop();
  });
  test(
      'failed new start restores prior source, no elapsed time, retry possible',
      () async {
    await service.start(language: 'pt', mode: 'study');
    await service.stop();
    await service.complete();
    final a = service.session!;
    fail = true;
    await expectLater(service.start(language: 'pt', mode: 'study'),
        throwsA(isA<RecordingStartFailure>()));
    expect(service.session, same(a));
    expect(service.canStart, true);
    expect(await File(a.segments.first['path'] as String).readAsBytes(),
        [1, 2, 3]);
    fail = false;
    await service.start(language: 'pt', mode: 'study');
    expect(service.phase, RecordingPhase.recording);
    await service.stop();
  });
  test('zero effective authorization cannot start a quota-limited recording',
      () async {
    available = 0;
    await expectLater(service.start(language: 'es', mode: 'study'),
        throwsA(isA<RecordingStartFailure>()));
    expect(service.capturing, false);
    expect(service.session, isNull);
  });
  for (final permission in [
    PermissionStatus.denied,
    PermissionStatus.restricted,
    PermissionStatus.permanentlyDenied
  ]) {
    test('permission $permission blocks before native start or ledger',
        () async {
      final transport = RecorderTransport();
      final provider = RecordLongFormAudioProvider(
          recorder: transport, microphonePermission: () async => permission);
      await expectLater(
          provider.startSegment(
              path: '/tmp/synthetic.m4a',
              config: const ClinicalLongFormRecordingConfig()),
          throwsA(isA<RecordingStartFailure>()
              .having((e) => e.microphone, 'microphone', true)));
      expect(transport.starts, 0);
      await provider.dispose();
      await transport.states.close();
    });
  }
  test('error copy PT ES is specific and contains no native details', () {
    const error = RecordingStartFailure('MIC_PERMISSION_DENIED', 'permission');
    expect(error.message(isEs: false), contains('microfone'));
    expect(error.message(isEs: true), contains('micrófono'));
    final fs = RecordingStartFailure.from(
        const FileSystemException('private path'), 'allocation');
    expect(fs.code, 'FILESYSTEM_CREATE_FAILED');
    expect(fs.toString(), isNot(contains('private path')));
  });
}
