import 'package:flutter/material.dart';
import '../models/study_long_form_audio_handoff.dart';
import '../services/audio/recording_session_controller.dart';
import 'durable_recording_screen.dart';

class NotesAudioConsultationLocalRuntimeScreen extends StatelessWidget {
  const NotesAudioConsultationLocalRuntimeScreen(
      {super.key, required this.isEs});
  final bool isEs;
  @override
  Widget build(BuildContext context) =>
      DurableRecordingScreen(isEs: isEs, mode: 'consultation');
}

class NotesAudioLongFormLocalRuntimeScreen extends StatelessWidget {
  const NotesAudioLongFormLocalRuntimeScreen(
      {super.key, required this.isEs, this.onCompleted});
  final bool isEs;
  final ValueChanged<StudyLongFormAudioHandoff>? onCompleted;
  @override
  Widget build(BuildContext context) => DurableRecordingScreen(
      isEs: isEs,
      mode: 'study',
      onTranscript: (_) {
        final handoff = RecordingSessionController.instance.handoff;
        if (handoff != null) onCompleted?.call(handoff);
      },
      onRecorded: () {
        final handoff = RecordingSessionController.instance.handoff;
        if (handoff != null)
          onCompleted?.call(StudyLongFormAudioHandoff(
              sessionId: handoff.sessionId,
              locale: handoff.locale,
              totalActiveDurationMs: handoff.totalActiveDurationMs,
              segments: handoff.segments,
              deferTranscription:
                  RecordingSessionController.instance.session?.transcript ==
                      null));
      });
}
