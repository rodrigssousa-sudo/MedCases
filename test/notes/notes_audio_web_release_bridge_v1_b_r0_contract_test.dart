import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('GitHub main bridge preserves origin tabs and adds Notes as tab 6', () {
    final main = read('lib/main.dart');

    expect(main, contains('void _onOpenNotes() => _onTabChange(6);'));
    expect(main, contains('void _closeNotesWorkspace() => _onTabChange(0);'));
    expect(
      main,
      contains('_NotesAudioWorkspace(onBack: _closeNotesWorkspace)'),
    );
    expect(main, contains('// 6 — NOTAS / ÁUDIO scoped web release workspace'));
    expect(
      main,
      contains('const RepaintBoundary(child: LibraryScreen()), // 5'),
    );

    expect(main, isNot(contains('LaboratoryMainShellWorkspace')));
    expect(main, isNot(contains('PediatricsMainShellWorkspace')));
  });

  test(
    'productive Notes owner is embedded without deleting sheet behavior',
    () {
      final main = read('lib/main.dart');

      expect(main, contains('final bool workspaceMode;'));
      expect(main, contains('this.workspaceMode = false'));
      expect(main, contains('if (!widget.workspaceMode)'));
      expect(main, contains('widget.workspaceMode ? 112 : 24'));
      expect(main, contains('void showNotesSheet(BuildContext context)'));
    },
  );

  test('workspace carries homologated visual and consent/runtime contract', () {
    final main = read('lib/main.dart');

    expect(main, contains('class _NotesAudioWorkspace'));
    expect(main, contains("label: 'Notas'"));
    expect(main, contains("label: isEs ? 'Audio' : 'Áudio'"));
    expect(main, contains("label: isEs ? 'Historial' : 'Histórico'"));

    expect(main, contains('Color(0xFFECF1F3)'));
    expect(main, contains('Color(0xFF1A1D23)'));
    expect(main, contains('Color(0xFF252930)'));
    expect(main, contains('Color(0xFFC6CED9)'));
    expect(main, contains('Color(0xFF52606D)'));

    expect(
      main,
      contains('ClinicalLongFormRemoteAudioConsentUi.showIfNeeded('),
    );
    expect(
      main,
      contains('NotesAudioConsultationLocalRuntimeScreen(isEs: isEs)'),
    );
    expect(main, contains('NotesAudioLongFormLocalRuntimeScreen(isEs: isEs)'));
  });

  test('web runtime is conditional and native runtime remains isolated', () {
    final entry = read('lib/screens/notes_audio_local_runtime_screen.dart');
    final web = read('lib/screens/notes_audio_local_runtime_screen_web.dart');
    final io = read('lib/screens/notes_audio_local_runtime_screen_io.dart');

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

    expect(web, isNot(contains("import 'dart:io'")));
    expect(web, isNot(contains('RecordLongFormAudioProvider')));

    expect(io, contains('ClinicalRecorderService'));
    expect(io, contains('RecordLongFormAudioProvider'));
    expect(io, contains('ClinicalLongFormRecordingSession'));
  });

  test('notification stub API parity is present for dart2js', () {
    final stub = read('lib/services/notification_web_stub.dart');

    expect(stub, contains('class NotificationVisibility'));
    expect(stub, contains('NotificationVisibility? visibility,'));
    expect(
      stub,
      contains('static const inexactAllowWhileIdle = AndroidScheduleMode._();'),
    );
  });

  test('remote real-patient production gates remain off', () {
    final store = read(
      'lib/services/audio/clinical_long_form_remote_audio_consent_store.dart',
    );
    final policy = read(
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
