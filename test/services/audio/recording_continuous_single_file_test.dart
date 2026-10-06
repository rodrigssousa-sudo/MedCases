import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final seconds in [20, 300, 1080, 1800, 3600]) {
    test('continuous $seconds seconds retains one file and source', () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('continuous-test-');
      var now = DateTime.utc(2026, 9, 30);
      final capture = Capture();
      final controller = RecordingSessionController(
        currentUid: () => 'synthetic-owner',
        storageRoot: () async => root,
        captureFactory: () => capture,
        authorize: (_) async {},
        resolveDurationTier: () async => EntitlementTier.premium,
        now: () => now,
        automaticTicks: false,
      );
      try {
        await controller.start(language: 'pt', mode: 'study');
        final id = controller.session!.sessionId;
        for (var elapsed = 0; elapsed < seconds; elapsed += 10) {
          now = now.add(const Duration(seconds: 10));
          await controller.tick();
        }
        await controller.stop();
        expect(controller.session!.sessionId, id);
        expect(controller.session!.segments, hasLength(1));
        expect(capture.starts, 1);
        expect(capture.stops, 1);
        expect(capture.path, endsWith('/recording.aac'));
        expect(await File(capture.path!).readAsBytes(), [1, 2, 3]);
        final reopened = RecordingSessionController(
          currentUid: () => 'synthetic-owner',
          storageRoot: () async => root,
          captureFactory: () => Capture(),
          authorize: (_) async {},
          now: () => now,
          automaticTicks: false,
        );
        try {
          await reopened.open(requestedSessionId: id);
          expect(reopened.session!.sessionId, id);
          expect(reopened.session!.segments.single['path'], capture.path);
        } finally {
          reopened.dispose();
        }
      } finally {
        controller.dispose();
        await root.delete(recursive: true);
      }
    });
  }
}
