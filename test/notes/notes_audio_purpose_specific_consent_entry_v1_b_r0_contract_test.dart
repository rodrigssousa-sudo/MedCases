import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Consulta and long-form cards enter certified consent gate', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(
      main,
      contains('ClinicalLongFormRemoteAudioConsentUi.showIfNeeded('),
    );
    expect(main, contains("mode: 'Consulta clínica',"));
    expect(
      main,
      contains(
        "mode: isEs ? 'Clase / audio largo' : 'Aula / áudio longo',",
      ),
    );
    expect(main, contains("'Configurar consentimento'"));
    expect(main, contains("'Configurar consentimiento'"));
    expect(main, contains('final VoidCallback onTap;'));
    expect(main, contains('Icon(Icons.chevron_right_rounded'));
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
