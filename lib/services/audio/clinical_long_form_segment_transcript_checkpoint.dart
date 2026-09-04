import 'clinical_long_form_batch_transcription_provider.dart';

final class ClinicalLongFormSegmentTranscriptCheckpoint {
  ClinicalLongFormSegmentTranscriptCheckpoint({
    required this.sessionId,
    required this.segmentIndex,
    required this.deduplicationKey,
    required this.transcript,
    required this.resultRef,
    required this.completedAtUtc,
  }) {
    validate();
  }

  final String sessionId;
  final int segmentIndex;
  final String deduplicationKey;
  final String transcript;
  final String resultRef;
  final DateTime completedAtUtc;

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    if (segmentIndex < 0 || segmentIndex > 99999) {
      throw ArgumentError.value(segmentIndex, 'segmentIndex');
    }
    if (deduplicationKey.trim().isEmpty || deduplicationKey.length > 240) {
      throw ArgumentError.value(
        deduplicationKey,
        'deduplicationKey',
      );
    }
    if (transcript.trim().isEmpty) {
      throw ArgumentError.value(transcript, 'transcript');
    }
    if (resultRef.trim().isEmpty || resultRef.length > 240) {
      throw ArgumentError.value(resultRef, 'resultRef');
    }
  }

  ClinicalLongFormBatchTranscriptionResult toBatchResult() {
    return ClinicalLongFormBatchTranscriptionResult(
      segmentIndex: segmentIndex,
      deduplicationKey: deduplicationKey,
      transcript: transcript,
      resultRef: resultRef,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'medcases.long_form_segment_transcript.v1',
        'sessionId': sessionId,
        'segmentIndex': segmentIndex,
        'deduplicationKey': deduplicationKey,
        'transcript': transcript,
        'resultRef': resultRef,
        'completedAtUtc': completedAtUtc.toUtc().toIso8601String(),
      };

  factory ClinicalLongFormSegmentTranscriptCheckpoint.fromJson(
    Map<String, Object?> json,
  ) {
    if (json['schema'] != 'medcases.long_form_segment_transcript.v1') {
      throw const FormatException(
        'Unsupported segment transcript checkpoint schema.',
      );
    }

    return ClinicalLongFormSegmentTranscriptCheckpoint(
      sessionId: json['sessionId']! as String,
      segmentIndex: json['segmentIndex']! as int,
      deduplicationKey: json['deduplicationKey']! as String,
      transcript: json['transcript']! as String,
      resultRef: json['resultRef']! as String,
      completedAtUtc: DateTime.parse(
        json['completedAtUtc']! as String,
      ).toUtc(),
    );
  }
}
