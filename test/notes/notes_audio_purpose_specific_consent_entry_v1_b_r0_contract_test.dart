import '../architecture/architectural_runtime_harness.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Study notice accepts or denies before local recording entry',
      (tester) async {
    await verifyStudyNotice(tester, accept: false);
    await verifyStudyNotice(tester, accept: true);
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('class _NotesAudioWorkspaceAudio')));
  });

  test('production audio guards remain off', () {
    final policy = File(
      'lib/services/audio/clinical_long_form_remote_transcription_policy.dart',
    ).readAsStringSync();
    final store = File(
      'lib/services/audio/clinical_long_form_remote_audio_consent_store.dart',
    ).readAsStringSync();

    expect(
      policy,
      contains('static const bool realPatientAudioAllowed = false'),
    );
    expect(
      store,
      contains('static const bool productionCallsiteWired = false'),
    );
    expect(
      store,
      contains('static const bool productionRemoteAudioEnabled = false'),
    );
  });
}
