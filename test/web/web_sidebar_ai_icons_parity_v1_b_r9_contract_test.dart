import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web uses canonical non-sidebar shell while native wide shell remains', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('if (!kIsWeb && width >= 768)'));
    expect(main, contains('_buildDesktopShell('));
    expect(main, contains('class _DesktopSidebar'));
  });

  test('home v2 svg bundle is registered and present', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/icons/home_v2/'));

    const required = <String>[
      'ic_avaliacao.svg',
      'ic_farmacos.svg',
      'ic_ferramentas.svg',
      'ic_guia_clinica.svg',
      'ic_historia.svg',
      'ic_laboratorio.svg',
      'ic_mi_guardia.svg',
      'ic_notas.svg',
      'ic_paciente.svg',
      'ic_pediatria.svg',
      'ic_simulacao.svg',
      'ic_timer.svg',
      'ic_vacina.svg',
    ];

    for (final name in required) {
      expect(
        File('assets/icons/home_v2/$name').existsSync(),
        isTrue,
        reason: 'missing Home V2 SVG: $name',
      );
    }
  });

  test('current AI three-companion contracts are published', () {
    final chat = File('lib/models/chat_message.dart').readAsStringSync();
    final firestore = File('lib/services/firestore_service.dart').readAsStringSync();
    final structured =
        File('lib/models/clinical_structured_output.dart').readAsStringSync();

    expect(chat, contains('userDisplayText'));
    expect(firestore, contains('deleteLegacyAiSession'));
    expect(firestore, contains('softDeleteCanonicalAiSession'));
    expect(structured, contains('primeiraLinha'));
    expect(structured, contains('segundaLinha'));
    expect(structured, contains('pontosChave'));
    expect(structured, contains('hardStops'));
  });

  test('clinical treatment presentation companion is published', () {
    final owner =
        File('lib/models/clinical_treatment_presentation.dart')
            .readAsStringSync();
    final structured =
        File('lib/models/clinical_structured_output.dart').readAsStringSync();

    expect(owner, contains('class ClinicalTreatmentPresentation'));
    expect(
      structured,
      contains("import 'clinical_treatment_presentation.dart';"),
    );
  });

  test('current AI screen is published and audio production guards remain closed', () {
    final ai = File('lib/screens/ai_screen.dart').readAsStringSync();
    final consent = File(
      'lib/services/audio/clinical_long_form_remote_audio_consent_store.dart',
    ).readAsStringSync();
    final policy = File(
      'lib/services/audio/clinical_long_form_remote_transcription_policy.dart',
    ).readAsStringSync();

    expect(ai, contains('class AiScreen'));
    expect(consent, contains('productionCallsiteWired = false'));
    expect(policy, contains('realPatientAudioAllowed = false'));
  });
}
