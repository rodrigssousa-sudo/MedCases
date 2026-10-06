import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/transcription_quota.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/audio/recording_duration_policy.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final tier in EntitlementTier.values) {
    final premium = tier == EntitlementTier.premium;
    final cap = Duration(minutes: premium ? 90 : 15);
    test(
        '${premium ? 'PREMIUM' : 'FREE'} local capture ignores legacy plan boundary',
        () async {
      final root = await Directory.systemTemp.createTemp('duration-policy-');
      var now = DateTime.utc(2026, 9, 26);
      final capture = Capture();
      var entitlementReads = 0;
      var calls = 0;
      final service = RecordingSessionController(
          currentUid: () => 'owner',
          storageRoot: () async => root,
          captureFactory: () => capture,
          authorize: (_) async {},
          resolveDurationTier: () async {
            entitlementReads++;
            return tier;
          },
          now: () => now,
          automaticTicks: false,
          transcribeAtLimit: (session, checkpoint) async {
            calls++;
            for (final segment in session.segments) {
              expect(segment['completed'], true);
              expect(await File(segment['path']).readAsBytes(), [1, 2, 3]);
            }
            return 'Synthetic result';
          });
      try {
        await service.start(language: 'pt', mode: 'study');
        expect(entitlementReads, 0);
        now = now.add(cap - const Duration(seconds: 1));
        await service.tick();
        expect(service.phase, RecordingPhase.recording);
        expect(calls, 0);
        now = now.add(const Duration(seconds: 1));
        await service.tick();
        expect(capture.running, true);
        await service.stop();
        expect(calls, 0);
        await service.transcribe((_, __) async {
          calls++;
          return 'explicit request';
        });
        expect(capture.running, false);
        expect(service.session!.job['durationLimitReached'], isNot(true));
        expect(service.session!.elapsedDurationMs, cap.inMilliseconds);
        expect(calls, 1);
        expect(service.phase, RecordingPhase.transcribed);
        await service.tick();
        await service.resume();
        expect(calls, 1);
        expect(capture.running, false);
        for (final segment in service.session!.segments) {
          expect(await File(segment['path']).readAsBytes(), [1, 2, 3]);
        }
      } finally {
        service.dispose();
        await root.delete(recursive: true);
      }
    });
    test('${tier.name} warnings and PT/ES copy', () {
      final p = RecordingDurationPolicy(tier, limit: cap);
      for (final isEs in [false, true]) {
        expect(p.warning(cap - const Duration(minutes: 5), isEs: isEs),
            '5 minutos restantes');
        expect(p.warning(cap - const Duration(minutes: 1), isEs: isEs),
            '1 minuto restante');
        expect(p.warning(cap - const Duration(seconds: 10), isEs: isEs),
            '10 segundos restantes');
        expect(p.remainingLabel(cap - const Duration(seconds: 1), isEs: isEs),
            '00:01 restantes');
        expect(p.completion(isEs: isEs),
            contains(isEs ? 'El audio fue guardado.' : 'O áudio foi salvo.'));
      }
    });
  }
  test('failed explicitly requested transcription retains audio and can retry',
      () async {
    final root = await Directory.systemTemp.createTemp('duration-retry-');
    var now = DateTime.utc(2026, 9, 26);
    final capture = Capture();
    final service = RecordingSessionController(
        currentUid: () => 'owner',
        storageRoot: () async => root,
        captureFactory: () => capture,
        authorize: (_) async {},
        now: () => now,
        automaticTicks: false,
        transcribeAtLimit: (_, __) async => throw StateError('offline'));
    try {
      await service.start(language: 'es', mode: 'study');
      now = now.add(const Duration(minutes: 15));
      await service.tick();
      expect(capture.running, true);
      await service.stop();
      await expectLater(
          service.transcribe((_, __) async => throw StateError('offline')),
          throwsStateError);
      expect(service.phase, RecordingPhase.recoverableError);
      expect(await File(capture.path!).readAsBytes(), [1, 2, 3]);
      expect(await service.transcribe((_, __) async => 'retry result'),
          'retry result');
      expect(capture.starts, 1);
    } finally {
      service.dispose();
      await root.delete(recursive: true);
    }
  });
  test('premium quota affects transcription readback, never local capture',
      () async {
    final root = await Directory.systemTemp.createTemp('cumulative-capture-');
    var now = DateTime.utc(2026, 9, 26);
    final capture = Capture();
    final service = RecordingSessionController(
        currentUid: () => 'owner',
        storageRoot: () async => root,
        captureFactory: () => capture,
        authorize: (_) async {},
        now: () => now,
        automaticTicks: false,
        resolveDurationTier: () async => EntitlementTier.premium,
        resolveQuota: () async => const TranscriptionQuota(
            owner: 'owner',
            period: '2026-09',
            premium: true,
            allowanceMs: 5400000,
            usedMs: 1200000,
            reservedMs: 0,
            remainingMs: 4200000));
    try {
      await service.start(language: 'es', mode: 'study');
      await service.refreshQuota();
      expect(service.quota!.remainingMs, 4200000);
      expect(service.durationPolicy.unlimited, true);
      now = now.add(const Duration(minutes: 70));
      await service.tick();
      expect(capture.running, true);
      await service.stop();
      expect(await File(capture.path!).readAsBytes(), [1, 2, 3]);
    } finally {
      service.dispose();
      await root.delete(recursive: true);
    }
  });
  test('downgrade affects transcription only and cannot stop local resume',
      () async {
    final root = await Directory.systemTemp.createTemp('duration-authority-');
    var now = DateTime.utc(2026, 9, 26);
    var tier = EntitlementTier.premium;
    final capture = Capture();
    final service = RecordingSessionController(
        currentUid: () => 'owner',
        storageRoot: () async => root,
        captureFactory: () => capture,
        authorize: (_) async {},
        resolveDurationTier: () async => tier,
        now: () => now,
        automaticTicks: false);
    try {
      await service.start(language: 'pt', mode: 'study');
      now = now.add(const Duration(minutes: 15));
      await service.pause();
      tier = EntitlementTier.free;
      now = now.add(const Duration(minutes: 30));
      await service.resume();
      expect(capture.running, true);
      expect(service.durationPolicy.unlimited, true);
      expect(service.elapsed, const Duration(minutes: 15));
      await service.stop();
      expect(await File(capture.path!).exists(), true);
    } finally {
      service.dispose();
      await root.delete(recursive: true);
    }
  });
}
