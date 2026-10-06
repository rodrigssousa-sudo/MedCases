import 'package:permission_handler/permission_handler.dart';
import 'package:medcases/services/audio/recording_start_failure.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/monthly_usage_ledger.dart';
import 'package:medcases/services/audio/record_long_form_audio_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';

// Transport fake tests the real productive recorder/ledger lifecycle, not
// microphone quality or native PlatformView behavior.
class RecorderTransport implements AudioRecorder {
  final states = StreamController<RecordState>.broadcast(sync: true);
  @override
  Stream<RecordState> onStateChanged() => states.stream;
  bool failStart = false, failStop = false;
  int starts = 0, stops = 0;
  Completer<void>? startGate;
  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    if (failStart) throw StateError('start failure');
    await startGate?.future;
  }

  @override
  Future<String?> stop() async {
    stops++;
    if (failStop) throw StateError('stop failure');
    return '/tmp/test.m4a';
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> pause() async {
    states.add(RecordState.pause);
  }

  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  MonthlyUsageLedger ledger() => MonthlyUsageLedger(
      uid: () => 'A',
      now: () => DateTime.utc(2026, 9),
      limits: () => EntitlementLimits.free,
      preferences: SharedPreferences.getInstance);
  test('paused native capture timer takes refreshed remaining authorization',
      () async {
    final transport = RecorderTransport();
    final scheduled = <Duration>[];
    final provider = RecordLongFormAudioProvider(
        microphonePermission: () async => PermissionStatus.granted,
        recorder: transport,
        scheduleQuota: (duration, callback) {
          scheduled.add(duration);
          return Timer(const Duration(days: 1), () {});
        });
    try {
      await provider.startSegment(
          path: '/tmp/quota-refresh-test.m4a',
          config: const ClinicalLongFormRecordingConfig());
      await provider.pause();
      provider.updateRemainingCaptureBudget(const Duration(minutes: 21));
      await provider.resume();
      expect(scheduled.last.inSeconds, closeTo(21 * 60, 1));
      await provider.stopSegment();
    } finally {
      await provider.dispose();
      await transport.states.close();
    }
  });
  test('quota boundary pause does not masquerade as an external interruption',
      () async {
    final transport = RecorderTransport();
    var rotated = 0;
    late void Function() quotaCallback;
    final provider = RecordLongFormAudioProvider(
        microphonePermission: () async => PermissionStatus.granted,
        recorder: transport,
        onQuotaReached: () {
          rotated++;
        },
        scheduleQuota: (duration, callback) {
          quotaCallback = callback;
          return Timer(const Duration(days: 1), () {});
        });
    final changes = <bool>[];
    final sub = provider.captureActiveChanges.listen(changes.add);
    await provider.startSegment(
        path: '/tmp/test.m4a',
        config: const ClinicalLongFormRecordingConfig(
            segmentDuration: Duration(minutes: 1)));
    quotaCallback();
    await Future<void>.delayed(Duration.zero);
    expect(rotated, 1);
    expect(changes, isEmpty);
    expect(provider.segmentBoundaryPending, true);
    expect(await provider.isCaptureRunning(), true);
    await provider.stopSegment();
    await provider.dispose();
    await sub.cancel();
    await transport.states.close();
  });
  test(
      'productive start failure and cancel release the reserved monthly allowance',
      () async {
    final transport = RecorderTransport()..failStart = true;
    final usage = ledger();
    final provider = RecordLongFormAudioProvider(
      microphonePermission: () async => PermissionStatus.granted,
      recorder: transport,
    );
    const config =
        ClinicalLongFormRecordingConfig(segmentDuration: Duration(minutes: 15));
    await expectLater(
        provider.startSegment(path: '/tmp/test.m4a', config: config),
        throwsStateError);
    transport.failStart = false;
    await provider.startSegment(path: '/tmp/test.m4a', config: config);
    await provider.cancelSegment();
    final available = await usage.begin(
        operationId: 'full-after-cancel',
        kinds: {UsageKind.recording},
        maximumMs: 15 * 60000);
    await available.finish(actualMs: 0, success: false);
    await provider.dispose();
  });
  test(
      'productive single flight rejects a concurrent start; stop failure releases reservation',
      () async {
    final transport = RecorderTransport()..startGate = Completer<void>();
    final usage = ledger();
    final provider = RecordLongFormAudioProvider(
      microphonePermission: () async => PermissionStatus.granted,
      recorder: transport,
    );
    const config =
        ClinicalLongFormRecordingConfig(segmentDuration: Duration(minutes: 15));
    final start = provider.startSegment(path: '/tmp/test.m4a', config: config);
    await expectLater(
        provider.startSegment(path: '/tmp/duplicate.m4a', config: config),
        throwsA(isA<RecordingStartFailure>()));
    transport.startGate!.complete();
    await start;
    expect(transport.starts, 1);
    transport.failStop = true;
    await expectLater(provider.stopSegment(), throwsStateError);
    final available = await usage.begin(
        operationId: 'after-stop-failure',
        kinds: {UsageKind.recording},
        maximumMs: 15 * 60000);
    await available.finish(actualMs: 0, success: false);
    await provider.dispose();
  });
}
