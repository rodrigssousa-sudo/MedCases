import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/audio/recording_deletion_store.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_durable_store.dart';
import 'package:medcases/services/study/study_library_service.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late RecordingSessionController controller;
  const uid = 'synthetic-delete-owner';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RecordingDeletionStore.ownerOverride = () => uid;
    root = await Directory.systemTemp.createTemp('physical-delete-');
    controller = RecordingSessionController(
        currentUid: () => uid,
        storageRoot: () async => root,
        captureFactory: () => Capture(),
        authorize: (_) async {},
        automaticTicks: false);
  });
  tearDown(() async {
    controller.dispose();
    RecordingDeletionStore.ownerOverride = null;
    await root.delete(recursive: true);
  });
  Future<Directory> fixture(String id,
      {bool legacy = false, bool missing = false}) async {
    final dir = Directory(legacy
        ? '${root.path}/medcases_study_recorded_audio_state/$uid/$id'
        : '${root.path}/medcases_recordings/${base64Url.encode(utf8.encode(uid))}/$id');
    final audio = File('${dir.path}/${legacy ? 'audio/' : ''}segment_0000.m4a');
    await audio.parent.create(recursive: true);
    if (!missing) await audio.writeAsBytes([1, 2, 3]);
    if (legacy) {
      await FileClinicalLongFormDurableStore(rootDirectory: dir.parent)
          .saveManifest(ClinicalLongFormRecordingManifest(
              sessionId: id,
              locale: 'pt',
              state: ClinicalLongFormRecordingState.stopped,
              createdAtUtc: DateTime.utc(2026),
              totalActiveDuration: const Duration(seconds: 3),
              segments: [
            ClinicalLongFormSegmentManifest(
                index: 0,
                path: audio.path,
                startedAtUtc: DateTime.utc(2026),
                activeDuration: const Duration(seconds: 3),
                completed: true)
          ]));
    } else {
      final data = RecordingSessionData(
          sessionId: id,
          ownerUid: uid,
          createdAt: DateTime.utc(2026),
          language: 'pt',
          mode: 'study')
        ..phase = RecordingPhase.recorded;
      data.segments
          .add({'path': audio.path, 'durationMs': 3000, 'completed': true});
      await File('${dir.path}/session.json')
          .writeAsString(jsonEncode(data.toJson()));
    }
    return dir;
  }

  Future<void> cardsStayRemoved(String id) async {
    final source = StudySource(
        id: 'recording_$id',
        type: StudySourceType.recordedAudio,
        title: 'Synthetic',
        state: StudySourceState.transcriptionPending,
        createdAtUtc: DateTime.utc(2026),
        recordingSessionId: id);
    final other = StudySource(
        id: 'other',
        type: StudySourceType.recordedAudio,
        title: 'Other',
        state: StudySourceState.transcriptionPending,
        createdAtUtc: DateTime.utc(2026),
        recordingSessionId: 'other');
    final study = Study(
        id: 'study',
        title: 'Synthetic',
        locale: 'pt',
        createdAtUtc: DateTime.utc(2026),
        sources: [source, other]);
    // A late callback still holding the old study cannot resurrect the card.
    await StudyLibraryService.save(study);
    expect(
        (await StudyLibraryService.loadAll()).single.sources.map((s) => s.id),
        ['other']);
    await StudyLibraryService.saveSource(study, source);
    expect(
        (await StudyLibraryService.loadAll()).single.sources.map((s) => s.id),
        ['other']);
  }

  test(
      'normal delete supports modern and proven UID legacy session; preserves others and restart',
      () async {
    final untouched = await fixture('other');
    for (final legacy in [false, true]) {
      final id = legacy ? 'legacy_case' : 'modern_case';
      final dir = await fixture(id, legacy: legacy);
      await controller.deleteRecording(id,
          confirmed: true, cleanup: (_) async {});
      expect(await dir.exists(), false);
      expect(await untouched.exists(), true);
      await cardsStayRemoved(id);
    }
  });
  test('already absent audio does not prevent source metadata removal',
      () async {
    final dir = await fixture('missing_audio', missing: true);
    await controller.deleteRecording('missing_audio',
        confirmed: true, cleanup: (_) async {});
    expect(await dir.exists(), false);
    await cardsStayRemoved('missing_audio');
    final prefs = await SharedPreferences.getInstance();
    final binding = {
      'sourceId': 'old_source',
      'sessionId': 'gone_session',
      'segments': []
    };
    await prefs.setString('medcases.recorded.pending.$uid.study.gone_session',
        jsonEncode(binding));
    final resolved = await RecordingDeletionStore.sourceBinding('old_source');
    expect(resolved?['sessionId'], 'gone_session');
    await controller.deleteRecording('gone_session',
        confirmed: true, sourceBinding: resolved, cleanup: (_) async {});
    expect(await RecordingDeletionStore.state(uid, 'gone_session'), 'deleted');
    expect(await RecordingDeletionStore.sourceBinding('old_source'), isNull);
    await cardsStayRemoved('gone_session');
  });
  test('remote cleanup failure or timeout cannot delay local deletion',
      () async {
    final pending = Completer<void>();
    for (final timeout in [false, true]) {
      final id = timeout ? 'timeout_case' : 'failed_remote';
      final dir = await fixture(id);
      await controller
          .deleteRecording(id,
              confirmed: true,
              cleanup: (_) => timeout
                  ? pending.future
                  : Future.error(StateError('remote unavailable')))
          .timeout(const Duration(seconds: 1));
      expect(await dir.exists(), false);
      await cardsStayRemoved(id);
    }
    pending.complete();
    await Future<void>.delayed(Duration.zero);
  });
}
