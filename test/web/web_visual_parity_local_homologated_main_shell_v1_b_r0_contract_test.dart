import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('web main equals homologated shell topology', () {
    final main = read('lib/main.dart');

    expect(main, contains('void _onOpenNotes() => _onTabChange(10);'));
    expect(
      main,
      contains('// 9 — LABORATORIO / LABORATÓRIO com footer global'),
    );
    expect(
      main,
      contains('_NotesAudioWorkspace(onBack: _closeNotesWorkspace)'),
    );

    expect(
      main,
      isNot(contains('// 6 — NOTAS / ÁUDIO scoped web release workspace')),
    );
    expect(main, isNot(contains('void _onOpenNotes() => _onTabChange(6);')));
  });

  test('notes audio consent/runtime contract remains present', () {
    final main = read('lib/main.dart');

    expect(main, contains('ClinicalLongFormRemoteAudioConsentUi.showIfNeeded'));
    expect(main, contains('NotesAudioConsultationLocalRuntimeScreen'));
    expect(main, contains('NotesAudioLongFormLocalRuntimeScreen'));
  });

  test('production remote audio gates remain disabled', () {
    final consent = read(
      'lib/services/audio/clinical_long_form_remote_audio_consent_store.dart',
    );
    final policy = read(
      'lib/services/audio/clinical_long_form_remote_transcription_policy.dart',
    );

    expect(consent, contains('productionCallsiteWired = false'));
    expect(consent, contains('productionRemoteAudioEnabled = false'));
    expect(policy, contains('realPatientAudioAllowed = false'));
    expect(
      policy,
      contains('remoteAudioTransmissionEnabledInProduction = false'),
    );
  });
}
