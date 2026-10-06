import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/audio/recording_duration_policy.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    'free_zero',
    'premium_zero',
    'offline',
    'provider_unavailable'
  ]) {
    test('$scenario captures, pauses, resumes and saves without remote calls',
        () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('local-recording-r1-');
      var now = DateTime.utc(2026, 10, 3), reads = 0, providerCalls = 0;
      final capture = Capture();
      final c = RecordingSessionController(
          currentUid: () => 'qa',
          storageRoot: () async => root,
          captureFactory: () => capture,
          authorize: (_) async {},
          now: () => now,
          automaticTicks: false,
          resolveQuota: () async {
            reads++;
            throw StateError('OFFLINE');
          },
          resolveEligibility: () async {
            providerCalls++;
            throw StateError('UNAVAILABLE');
          },
          transcribeAtLimit: (_, __) async {
            providerCalls++;
            return 'should never execute';
          });
      try {
        await c.start(language: 'pt', mode: 'study');
        now = now.add(const Duration(minutes: 20));
        await c.tick();
        expect(capture.running, true);
        await c.pause();
        await c.resume();
        now = now.add(const Duration(hours: 8));
        await c.tick();
        expect(capture.running, true);
        await c.stop();
        expect(c.phase, RecordingPhase.recorded);
        expect(reads, 0);
        expect(providerCalls, 0);
        expect(await File(capture.path!).readAsBytes(), [1, 2, 3]);
        expect(capture.cancels, 0);
        c.dispose();
        final reopened = RecordingSessionController(
            currentUid: () => 'qa',
            storageRoot: () async => root,
            captureFactory: () => Capture(),
            authorize: (_) async {},
            automaticTicks: false);
        await reopened.open();
        expect(reopened.session?.sessionId, isNotNull);
        expect(await File(capture.path!).exists(), true);
        reopened.dispose();
      } finally {
        await root.delete(recursive: true);
      }
    });
  }
  test('local policy has no commercial boundary or countdown', () {
    const p = RecordingDurationPolicy.local();
    expect(p.unlimited, true);
    expect(p.reached(const Duration(days: 3)), false);
    expect(p.warning(const Duration(minutes: 15), isEs: false), null);
  });
}
