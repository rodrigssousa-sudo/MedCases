import '../architecture/architectural_runtime_harness.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/notes_audio_local_runtime_screen.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('new local runtime widgets compile and remain explicit', () {
    const consultation = NotesAudioConsultationLocalRuntimeScreen(
      isEs: false,
    );
    const longForm = NotesAudioLongFormLocalRuntimeScreen(
      isEs: false,
    );

    expect(consultation, isA<StatefulWidget>());
    expect(longForm, isA<StatefulWidget>());
  });

  test('current workspace uses Study owner and legacy menu stays retired', () {
    final main = _read('lib/main.dart');
    final start = main.indexOf('class _NotesAudioWorkspaceState');
    expect(start, isNonNegative);
    final end = main.indexOf('\nclass ', start + 1);
    final owner = main.substring(start, end < 0 ? main.length : end);
    expect(owner, contains('StudyWorkspaceScreen('));
    expect(main, isNot(contains('class _NotesAudioWorkspaceAudio')));
  });

  test('consent surface has explicit MedCases colors and no button glow', () {
    final consent = _read(
      'lib/screens/remote_audio_consent_sheet.dart',
    );

    expect(consent, contains('foregroundColor: accent'));
    expect(consent, contains('Color(0xFFC6CED9)'));
    expect(consent, contains('Color(0xFF52606D)'));
    expect(consent, contains('shadowColor: Colors.transparent'));
    expect(consent, contains('surfaceTintColor: Colors.transparent'));
    expect(consent, contains('overlayColor: Colors.transparent'));
    expect(consent, isNot(contains('BoxShadow(')));
  });

  testWidgets('Study notice accepts or denies before local recording entry',
      (tester) async {
    await verifyStudyNotice(tester, accept: false);
    await verifyStudyNotice(tester, accept: true);
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('class _NotesAudioWorkspaceAudio')));
  });

  test('consultation runtime reuses certified ClinicalRecorderService API', () {
    final runtime = _read(
      'lib/screens/notes_audio_local_runtime_screen_io.dart',
    );

    expect(runtime, contains('ClinicalRecorderService'));
    expect(runtime, contains('_recorder.transcriptStream.listen'));
    expect(runtime, contains('_recorder.stateStream.listen'));
    expect(
      runtime,
      contains("await _recorder.start(lang: widget.isEs ? 'es' : 'pt')"),
    );
    expect(runtime, contains('_recorder.pause()'));
    expect(runtime, contains('_recorder.resume()'));
    expect(runtime, contains('await _recorder.stop()'));
  });

  test('long-form runtime reuses physical M4A owners and canonical layout', () {
    final runtime = _read(
      'lib/screens/notes_audio_local_runtime_screen_io.dart',
    );

    expect(runtime, contains('RecordLongFormAudioProvider'));
    expect(runtime, contains('ClinicalLongFormSessionDirectoryLayout'));
    expect(runtime, contains('ClinicalLongFormRecordingSession'));
    expect(runtime, contains('getApplicationSupportDirectory()'));
    expect(runtime, contains('medcases_study_recorded_audio_state'));
    expect(runtime, contains('sessionId: sessionId'));
    expect(runtime, contains('await layout.ensureDirectories()'));
    expect(runtime, contains('layout.segmentFile(0).path'));
    expect(runtime, contains('session.shouldRotate(now)'));
    expect(runtime, contains('session.reachedMaxDuration(now)'));
    expect(runtime, contains('await session.pause('));
    expect(runtime, contains('await session.resume('));
    expect(runtime, contains('await session.stop(now)'));
    expect(runtime, contains('session.snapshot(now)'));
  });

  test('runtime contains no MedCases remote transport or secret path', () {
    final runtime = _read(
      'lib/screens/notes_audio_local_runtime_screen_io.dart',
    );

    for (final forbidden in <String>[
      'api.openai.com',
      'OPENAI_API_KEY',
      'ClinicalLongFormHttpsBackend',
      'RemoteBatchSandbox',
      'SyntheticCallsite',
      '/api/ai/audio/grant',
      '/api/ai/audio/transcriptions',
      'Bearer ',
      'package:http',
      'HttpClient',
      'WebSocket',
    ]) {
      expect(runtime, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('remote production and real-patient guards stay fail-closed', () {
    final store = _read(
      'lib/services/audio/clinical_long_form_remote_audio_consent_store.dart',
    );
    final policy = _read(
      'lib/services/audio/clinical_long_form_remote_transcription_policy.dart',
    );

    expect(store, contains('productionCallsiteWired = false'));
    expect(store, contains('productionRemoteAudioEnabled = false'));
    expect(policy, contains('realPatientAudioAllowed = false'));
    expect(
      policy,
      contains('remoteAudioTransmissionEnabledInProduction = false'),
    );
  });
}
