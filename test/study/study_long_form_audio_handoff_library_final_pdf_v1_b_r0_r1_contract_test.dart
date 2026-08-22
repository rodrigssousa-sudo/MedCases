import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_long_form_audio_handoff.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_pdf_export_service.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('long-form handoff has segmented M4A metadata', () {
    const handoff = StudyLongFormAudioHandoff(
      sessionId: 'lecture_001',
      locale: 'pt-BR',
      totalActiveDurationMs: 600000,
      segments: <StudyLongFormAudioSegment>[
        StudyLongFormAudioSegment(
          index: 0,
          path: '/tmp/segment_000.m4a',
          activeDurationMs: 600000,
        ),
      ],
    );

    expect(handoff.isUsable, isTrue);
    expect(handoff.segments.single.path, endsWith('.m4a'));
  });

  test('runtime emits completion callback after stopped manifest', () {
    final io = read('lib/screens/notes_audio_local_runtime_screen_io.dart');
    final web = read('lib/screens/notes_audio_local_runtime_screen_web.dart');

    expect(io, contains('widget.onCompleted?.call('));
    expect(io, contains('StudyLongFormAudioHandoff('));
    expect(io, contains('manifest.totalActiveDuration.inMilliseconds'));
    expect(io, contains('segment.activeDuration.inMilliseconds'));
    expect(
        web, contains('ValueChanged<StudyLongFormAudioHandoff>? onCompleted'));
  });

  test('Study screen transcribes segments and deletes raw only on accept', () {
    final screen = read('lib/screens/study_workspace_screen.dart');

    expect(screen, contains('NotesAudioLongFormLocalRuntimeScreen('));
    expect(screen, contains('StudyLongFormSegmentLoader.read('));
    expect(screen, contains('type: StudySourceType.recordedAudio'));
    expect(screen, contains('_recordedRawPaths[sourceId]'));
    expect(screen, contains('StudyLongFormSegmentLoader.deleteAll(rawPaths)'));

    final deletePos =
        screen.indexOf('StudyLongFormSegmentLoader.deleteAll(rawPaths)');
    final acceptPos = screen.indexOf(
      '_replace(source.transition(StudySourceState.accepted))',
      deletePos,
    );

    expect(deletePos, greaterThanOrEqualTo(0));
    expect(acceptPos, greaterThan(deletePos));
  });

  test('library and final PDF owners use existing packages', () {
    final library = read('lib/services/study/study_library_service.dart');
    final pdf = read('lib/services/study/study_pdf_export_service.dart');

    expect(library, contains('SharedPreferences.getInstance()'));
    expect(library, contains("medcases.study.library.v1"));
    expect(pdf, contains('pw.Document('));
    expect(pdf, contains('pw.MultiPage('));
    expect(pdf, contains('Printing.sharePdf('));
  });

  test('PDF can be built from generated Study artifact', () async {
    final now = DateTime.utc(2026, 8, 22);
    final study = Study(
      id: 'study_pdf',
      title: 'Digestivo',
      locale: 'es-ES',
      createdAtUtc: now,
      artifacts: <StudyArtifact>[
        StudyArtifact(
          id: 'a1',
          type: StudyArtifactType.fullSummary,
          title: 'Resumen completo',
          content: 'Contenido educativo.',
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
      ],
    );

    final bytes = await StudyPdfExportService.build(study, isEs: true);
    expect(bytes.length, greaterThan(500));
  });

  test('clinical real-patient production gates stay off', () {
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
