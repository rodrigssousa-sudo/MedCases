import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/transcription_quota.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final extra in [0, 5, 20]) {
    test('Free base + $extra: start/resume never consume transcription balance',
        () async {
      final root = await Directory.systemTemp.createTemp('effective-quota-');
      final capture = Capture();
      var now = DateTime.utc(2026, 10, 1);
      var reads = 0;
      var executions = 0;
      final cap = Duration(minutes: 15 + extra);
      final service = RecordingSessionController(
        currentUid: () => 'owner',
        storageRoot: () async => root,
        captureFactory: () => capture,
        authorize: (_) async {},
        automaticTicks: false,
        now: () => now,
        resolveQuota: () async {
          reads++;
          return TranscriptionQuota(
              owner: 'owner',
              period: '2026-10',
              premium: false,
              allowanceMs: cap.inMilliseconds,
              usedMs: 0,
              reservedMs: 0,
              remainingMs: cap.inMilliseconds);
        },
        resolveDurationTier: () async =>
            throw StateError('must use server authority'),
        transcribeAtLimit: (session, checkpoint) async {
          executions++;
          expect(capture.running, false);
          expect(session.segments.every((s) => s['completed'] == true), true);
          expect(await File(capture.path!).readAsBytes(), [1, 2, 3]);
          return 'Synthetic transcript';
        },
      );
      try {
        await service.start(language: 'pt', mode: 'study');
        expect(service.durationPolicy.unlimited, true);
        expect(service.durationPolicy.tier, EntitlementTier.free);
        now = now.add(const Duration(minutes: 14));
        await service.pause();
        await service.resume();
        expect(reads, 0);
        expect(service.durationPolicy.unlimited, true);
        now = now.add(const Duration(minutes: 1));
        await service.tick();
        expect(capture.running, true);
        expect(executions, 0);
        now = now.add(Duration(minutes: extra + 1));
        await service.tick();
        expect(capture.running, true);
        await service.stop();
        expect(service.phase, RecordingPhase.recorded);
        expect(executions, 0); // Stop is local, with no provider dispatch.
        await service.transcribe((_, __) async {
          executions++;
          return 'explicit synthetic request';
        });
        expect(executions, 1);
        expect(service.phase, RecordingPhase.transcribed);
        expect(capture.cancels, 0);
        expect(await File(capture.path!).exists(), true);
        await service.tick();
        expect(executions, 1);
      } finally {
        service.dispose();
        await root.delete(recursive: true);
      }
    });
  }
  test('quota refresh updates transcription UI without changing local capture',
      () async {
    final root = await Directory.systemTemp.createTemp('quota-refresh-');
    final capture = Capture();
    var now = DateTime.utc(2026, 10, 1);
    var available = const Duration(minutes: 15);
    final service = RecordingSessionController(
        currentUid: () => 'owner',
        storageRoot: () async => root,
        captureFactory: () => capture,
        authorize: (_) async {},
        automaticTicks: false,
        now: () => now,
        resolveQuota: () async => TranscriptionQuota(
            owner: 'owner',
            period: '2026-10',
            premium: false,
            allowanceMs: available.inMilliseconds,
            usedMs: 0,
            reservedMs: 0,
            remainingMs: available.inMilliseconds));
    try {
      await service.start(language: 'es', mode: 'study');
      now = now.add(const Duration(minutes: 14));
      await service.pause();
      available = const Duration(minutes: 35);
      await service.resume();
      expect(service.durationPolicy.unlimited, true);
      await service.refreshQuota();
      expect(service.quota!.remainingMs, available.inMilliseconds);
      now = now.add(const Duration(minutes: 1));
      await service.tick();
      expect(capture.running, true);
      await service.pause();
      await service.resume();
      expect(service.durationPolicy.unlimited, true);
      await service.stop();
    } finally {
      service.dispose();
      await root.delete(recursive: true);
    }
  });
  test(
      'continuous capture accepts positive balance below legacy segment length',
      () {
    expect(
        () => const ClinicalLongFormRecordingConfig(
                continuous: true,
                fileExtension: 'aac',
                maxDuration: Duration(seconds: 32))
            .validate(),
        returnsNormally);
    expect(
        () => const ClinicalLongFormRecordingConfig(
                continuous: true,
                fileExtension: 'aac',
                maxDuration: Duration.zero)
            .validate(),
        throwsArgumentError);
  });
}
