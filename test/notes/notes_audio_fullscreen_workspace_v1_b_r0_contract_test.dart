import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('Home NOTAS opens MainShell full-screen workspace tab 10', () {
    final main = _read('lib/main.dart');

    expect(main, contains('void _onOpenNotes() => _onTabChange(10);'));
    expect(main, contains('void _closeNotesWorkspace() => _onTabChange(0);'));
    expect(
      main,
      contains('_NotesAudioWorkspace(onBack: _closeNotesWorkspace)'),
    );
    expect(
      main,
      isNot(contains('void _onOpenNotes() => showNotesSheet(context);')),
    );
  });

  test('workspace follows canonical premium three-section contract', () {
    final main = _read('lib/main.dart');

    expect(main, contains('class _NotesAudioWorkspace'));
    expect(main, contains("label: 'Notas'"));
    expect(main, contains("label: isEs ? 'Audio' : 'Áudio'"));
    expect(main, contains("label: isEs ? 'Historial' : 'Histórico'"));
    expect(main, contains('height: 48'));
    expect(main, contains('height: 44'));
    expect(main, contains('height: 2'));
  });

  test('real productive Notes owner is reused', () {
    final main = _read('lib/main.dart');

    expect(
      main,
      contains(
        '_NotesPanelContent(\n'
        '                    onClose: widget.onBack,\n'
        '                    workspaceMode: true,',
      ),
    );
    expect(main, contains('final bool workspaceMode;'));
    expect(main, contains('if (!widget.workspaceMode)'));
  });

  test('audio workspace remains fail-closed', () {
    final main = _read('lib/main.dart');
    final policy = _read(
      'lib/services/audio/clinical_long_form_remote_transcription_policy.dart',
    );
    final consent = _read(
      'lib/services/audio/clinical_long_form_remote_audio_consent_store.dart',
    );

    expect(main, isNot(contains('OPENAI_API_KEY')));
    expect(main, isNot(contains('api.openai.com')));
    expect(main, contains('Áudio real de pacientes continua desativado'));
    expect(
      policy,
      contains('static const bool realPatientAudioAllowed = false'),
    );
    expect(
      consent,
      contains('static const bool productionCallsiteWired = false'),
    );
    expect(
      consent,
      contains('static const bool productionRemoteAudioEnabled = false'),
    );
  });

  test('audio tab exposes consultation and long-form modes', () {
    final main = _read('lib/main.dart');

    expect(main, contains("'Consulta clínica'"));
    expect(main, contains("'Aula / áudio longo'"));
    expect(main, contains("'Clase / audio largo'"));
    expect(main, contains("'Modo estudo'"));
    expect(main, contains("'Modo estudio'"));
    expect(main, contains("'Backend validado'"));
  });
}
