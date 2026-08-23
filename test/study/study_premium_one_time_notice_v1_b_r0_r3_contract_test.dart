import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('Study uses one-time notice and no permanent checkbox', () {
    final study = read('lib/screens/study_workspace_screen.dart');
    final notice = read(
      'lib/services/study/study_first_use_notice_service.dart',
    );

    expect(study, contains('StudyFirstUseNoticeService.isAccepted()'));
    expect(study, contains('StudyFirstUseNoticeService.accept()'));
    expect(notice, contains('medcases.study.educational_notice.v1.accepted'));

    expect(
      study,
      isNot(
        contains('Material educativo sin datos identificables de pacientes.'),
      ),
    );
    expect(study, isNot(contains('Checkbox(')));
    expect(study, isNot(contains('Foundation V1')));
    expect(study, isNot(contains('recording_not_completed')));
  });

  test('Study canonical premium palette and density are explicit', () {
    final study = read('lib/screens/study_workspace_screen.dart');

    expect(study, contains('Color(0xFF1A1D23)'));
    expect(study, contains('Color(0xFFECF1F3)'));
    expect(study, contains('Color(0xFF252930)'));
    expect(study, contains('Color(0xFF374151)'));
    expect(study, contains('Color(0xFFE2E7EC)'));
    expect(study, contains('Color(0xFF10B981)'));
    expect(study, contains('BorderRadius.circular(8)'));
    expect(study, contains('width: 0.7'));
  });

  test('cancelled lecture removes placeholder source', () {
    final study = read('lib/screens/study_workspace_screen.dart');

    expect(study, contains('if (handoff == null || !handoff.isUsable)'));
    expect(study, contains('await _removeSource(sourceId);'));
    expect(study, isNot(contains('recording_not_completed')));
  });

  test('Audio hub hides engineering and permanent consent UI', () {
    final main = read('lib/main.dart');

    expect(main, isNot(contains('Backend validado')));
    expect(main, isNot(contains('Privacidad y consentimiento')));
    expect(main, isNot(contains('Configurar consentimiento')));
    expect(main, isNot(contains('Configurar consentimento')));
  });

  test('long-form screen copy matches automatic Study handoff', () {
    final io = read('lib/screens/notes_audio_local_runtime_screen_io.dart');

    // Split Dart literals are validated semantically by the transactional
    // Gate 5 parser. The Flutter contract test protects the functional handoff
    // and rejects only unsplit obsolete full sentences.
    expect(io, isNot(contains('Esta etapa no llama al backend remoto')));
    expect(io, isNot(contains('Esta etapa não chama o backend remoto')));
    expect(io, contains('widget.onCompleted?.call('));
  });

  test('clinical remote patient-audio gates remain closed', () {
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
