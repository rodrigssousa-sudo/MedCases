import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_multimodal_extraction_service.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('multimodal source and artifact contracts exist', () {
    expect(
      StudySourceType.values.map((e) => e.name),
      containsAll(<String>[
        'recordedAudio',
        'uploadedAudio',
        'pdf',
        'image',
        'text',
      ]),
    );
    expect(
      StudyArtifactType.values.map((e) => e.name),
      containsAll(<String>[
        'fullSummary',
        'examSummary',
        'mindMap',
        'flashcards',
        'questionsAndAnswers',
        'multipleChoice',
        'oralExam',
        'keyPoints',
        'comparisonTable',
        'finalPdf',
      ]),
    );
  });

  test('source state machine is deterministic', () {
    var source = StudySource(
      id: 'source_1',
      type: StudySourceType.text,
      title: 'Aula',
      state: StudySourceState.added,
      createdAtUtc: DateTime.utc(2026, 8, 22),
    );

    source = source.transition(StudySourceState.processing);
    source = source.transition(
      StudySourceState.review,
      extractedText: 'Conteúdo revisável',
      sourceRefs: const <SourceRef>[
        SourceRef(
          sourceId: 'source_1',
          sourceType: StudySourceType.text,
          textBlockIndex: 1,
        ),
      ],
    );
    source = source.transition(StudySourceState.accepted);

    expect(source.isAccepted, isTrue);
  });

  test('source provenance renders page and timestamp', () {
    const pdf = SourceRef(
      sourceId: 'p',
      sourceType: StudySourceType.pdf,
      pageNumber: 18,
    );
    const audio = SourceRef(
      sourceId: 'a',
      sourceType: StudySourceType.uploadedAudio,
      timestampStartMs: 2600000,
    );

    expect(pdf.label(isEs: false), 'PDF · pág. 18');
    expect(audio.label(isEs: false), 'Áudio · 43:20');
  });

  test('educational binary bridge explicitly rejects patient material', () {
    expect(
      StudyEducationalMaterialPolicy.binaryRemoteExtractionEnabled,
      isTrue,
    );
    expect(StudyEducationalMaterialPolicy.realPatientMaterialAllowed, isFalse);
    expect(
      StudyEducationalMaterialPolicy.explicitEducationalConfirmationRequired,
      isTrue,
    );
  });

  test('main integrates Estudos into canonical Notes Audio workspace', () {
    final main = read('lib/main.dart');
    expect(main, contains("import 'screens/study_workspace_screen.dart';"));
    expect(main, contains("label: isEs ? 'Estudio' : 'Estudos'"));
    expect(main, contains('StudyWorkspaceScreen('));
    expect(
      main,
      contains('onOpenLongFormAudio: () => setState(() => _section = 1)'),
    );
    expect(
      RegExp(r'class _NotesAudioWorkspaceState\b').allMatches(main).length,
      1,
    );
  });

  test('artifact generator reuses AiService and no direct OpenAI secret', () {
    final generator = read('lib/services/study/study_artifact_generator.dart');
    final extractor = read(
      'lib/services/study/study_multimodal_extraction_service.dart',
    );

    expect(generator, contains('AiService.chat('));
    expect(generator, isNot(contains('ProviderRouterService.callPaidProxy(')));
    expect(extractor, contains('GeminiService.apiKeyForLab'));
    expect(extractor, isNot(contains('OPENAI_API_KEY')));
    expect(extractor, isNot(contains('api.openai.com')));
  });

  test('clinical audio production guards remain off', () {
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
