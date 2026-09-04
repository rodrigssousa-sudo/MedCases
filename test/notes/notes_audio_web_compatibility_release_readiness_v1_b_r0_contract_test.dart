import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/notes_audio_local_runtime_screen.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('conditional runtime entry keeps the same public widget API', () {
    const consultation = NotesAudioConsultationLocalRuntimeScreen(
      isEs: false,
    );
    const longForm = NotesAudioLongFormLocalRuntimeScreen(
      isEs: false,
    );

    expect(consultation, isA<Widget>());
    expect(longForm, isA<Widget>());
  });

  test('runtime entry is platform conditional and web-safe', () {
    final entry = _read(
      'lib/screens/notes_audio_local_runtime_screen.dart',
    );

    expect(
      entry,
      contains("export 'notes_audio_local_runtime_screen_web.dart'"),
    );
    expect(
      entry,
      contains(
        "if (dart.library.io) 'notes_audio_local_runtime_screen_io.dart'",
      ),
    );

    expect(entry, isNot(contains("import 'dart:io'")));
    expect(entry, isNot(contains('path_provider')));
  });

  test('web owner has no dart io or native local recorder imports', () {
    final web = _read(
      'lib/screens/notes_audio_local_runtime_screen_web.dart',
    );

    for (final forbidden in <String>[
      "import 'dart:io'",
      'path_provider',
      'ClinicalRecorderService',
      'RecordLongFormAudioProvider',
      'ClinicalLongFormRecordingSession',
      'ClinicalLongFormSessionDirectoryLayout',
      'api.openai.com',
      'OPENAI_API_KEY',
      '/api/ai/audio/grant',
      '/api/ai/audio/transcriptions',
      'HttpClient',
      'WebSocket',
    ]) {
      expect(web, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('mobile IO owner keeps the previously homologated runtime source', () {
    final io = _read(
      'lib/screens/notes_audio_local_runtime_screen_io.dart',
    );

    expect(io, contains('ClinicalRecorderService'));
    expect(io, contains('RecordLongFormAudioProvider'));
    expect(io, contains('ClinicalLongFormRecordingSession'));
    expect(io, contains('ClinicalLongFormSessionDirectoryLayout'));
    expect(io, contains('getTemporaryDirectory()'));
    expect(
      io,
      contains("await _recorder.start(lang: widget.isEs ? 'es' : 'pt')"),
    );
  });

  test('web fallback preserves MedCases Home palette', () {
    final web = _read(
      'lib/screens/notes_audio_local_runtime_screen_web.dart',
    );

    expect(web, contains('Color(0xFF1A1D23)'));
    expect(web, contains('Color(0xFFECF1F3)'));
    expect(web, contains('Color(0xFF252930)'));
    expect(web, contains('Color(0xFFF8FAFC)'));
    expect(web, contains('Color(0xFFC6CED9)'));
    expect(web, contains('Color(0xFF52606D)'));
    expect(web, contains('Color(0xFF10B981)'));
  });

  test('remote production guards remain fail-closed', () {
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
