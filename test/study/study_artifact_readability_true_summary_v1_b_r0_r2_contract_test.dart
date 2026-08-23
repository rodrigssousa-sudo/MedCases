import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String p) => File(p).readAsStringSync();
void main() {
  test('full summary is continuous prose', () {
    final g = read('lib/services/study/study_artifact_generator.dart');
    expect(g, contains('PROSA CONTÍNUA'));
    expect(g, contains('NÃO use bullets'));
    expect(g, contains('Interlocutor A/B'));
    expect(g, contains('não tiver conteúdo acadêmico substantivo suficiente'));
    expect(g, contains('Não invente matéria médica/acadêmica.'));
    expect(g, contains('Não invente fatos ausentes.'));
    expect(g, contains('Sintetize o SIGNIFICADO'));
    expect(g, contains('return 5200'));
  });
  test('UI renders Markdown', () {
    final s = read('lib/screens/study_workspace_screen.dart');
    expect(s, contains("package:flutter_markdown/flutter_markdown.dart"));
    expect(s, contains('MarkdownBody('));
    expect(s, contains('data: artifact.content'));
    expect(
      s,
      isNot(
        contains('SelectableText(\n                      artifact.content'),
      ),
    );
  });
  test('PDF strips raw Markdown', () {
    final p = read('lib/services/study/study_pdf_export_service.dart');
    expect(p, contains('_artifactPlainText(artifact.content)'));
    expect(p, contains("replaceAll('**', '')"));
    expect(p, isNot(contains('_safe(artifact.content)')));
  });
  test('clinical gates stay closed', () {
    final c = read(
      'lib/services/audio/clinical_long_form_remote_audio_consent_store.dart',
    );
    final p = read(
      'lib/services/audio/clinical_long_form_remote_transcription_policy.dart',
    );
    expect(c, contains('productionCallsiteWired = false'));
    expect(c, contains('productionRemoteAudioEnabled = false'));
    expect(p, contains('realPatientAudioAllowed = false'));
    expect(p, contains('remoteAudioTransmissionEnabledInProduction = false'));
  });
}
