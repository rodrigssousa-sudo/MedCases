import 'clinical_long_form_review_lifecycle.dart';

enum ClinicalLongFormAudioRetentionState {
  reviewedPersisted,
  keepAudio,
  deletePending,
  audioDeleted,
  deletionFailed,
}

final class ClinicalLongFormReviewedTranscriptArtifact {
  ClinicalLongFormReviewedTranscriptArtifact({
    required this.sessionId,
    required this.locale,
    required this.reviewedTranscript,
    required this.reviewedAtUtc,
    required this.sourceSegmentCount,
    required this.sourceActiveDuration,
    required this.retentionState,
    required this.audioDisposition,
    this.lastCleanupErrorCode,
  }) {
    validate();
  }

  final String sessionId;
  final String locale;
  final String reviewedTranscript;
  final DateTime reviewedAtUtc;
  final int sourceSegmentCount;
  final Duration sourceActiveDuration;
  final ClinicalLongFormAudioRetentionState retentionState;
  final ClinicalLongFormAudioDisposition? audioDisposition;
  final String? lastCleanupErrorCode;

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    if (locale.trim().isEmpty || locale.length > 32) {
      throw ArgumentError.value(locale, 'locale');
    }
    if (reviewedTranscript.trim().isEmpty) {
      throw ArgumentError.value(
        reviewedTranscript,
        'reviewedTranscript',
      );
    }
    if (sourceSegmentCount < 1) {
      throw ArgumentError.value(
        sourceSegmentCount,
        'sourceSegmentCount',
      );
    }
    if (sourceActiveDuration.isNegative) {
      throw ArgumentError.value(
        sourceActiveDuration,
        'sourceActiveDuration',
      );
    }
    if (lastCleanupErrorCode != null &&
        (lastCleanupErrorCode!.trim().isEmpty ||
            lastCleanupErrorCode!.length > 120)) {
      throw ArgumentError.value(
        lastCleanupErrorCode,
        'lastCleanupErrorCode',
      );
    }
  }

  ClinicalLongFormReviewedTranscriptArtifact copyWith({
    ClinicalLongFormAudioRetentionState? retentionState,
    ClinicalLongFormAudioDisposition? audioDisposition,
    bool clearAudioDisposition = false,
    String? lastCleanupErrorCode,
    bool clearCleanupError = false,
  }) {
    return ClinicalLongFormReviewedTranscriptArtifact(
      sessionId: sessionId,
      locale: locale,
      reviewedTranscript: reviewedTranscript,
      reviewedAtUtc: reviewedAtUtc,
      sourceSegmentCount: sourceSegmentCount,
      sourceActiveDuration: sourceActiveDuration,
      retentionState: retentionState ?? this.retentionState,
      audioDisposition: clearAudioDisposition
          ? null
          : audioDisposition ?? this.audioDisposition,
      lastCleanupErrorCode: clearCleanupError
          ? null
          : lastCleanupErrorCode ?? this.lastCleanupErrorCode,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'medcases.long_form_reviewed_transcript.v1',
        'sessionId': sessionId,
        'locale': locale,
        'reviewedTranscript': reviewedTranscript,
        'reviewedAtUtc': reviewedAtUtc.toUtc().toIso8601String(),
        'sourceSegmentCount': sourceSegmentCount,
        'sourceActiveDurationMs': sourceActiveDuration.inMilliseconds,
        'retentionState': retentionState.name,
        'audioDisposition': audioDisposition?.name,
        'lastCleanupErrorCode': lastCleanupErrorCode,
      };

  factory ClinicalLongFormReviewedTranscriptArtifact.fromJson(
    Map<String, Object?> json,
  ) {
    if (json['schema'] != 'medcases.long_form_reviewed_transcript.v1') {
      throw const FormatException(
        'Unsupported reviewed transcript artifact schema.',
      );
    }

    final retentionName = json['retentionState']! as String;
    final retentionState =
        ClinicalLongFormAudioRetentionState.values.firstWhere(
      (value) => value.name == retentionName,
    );

    final dispositionName = json['audioDisposition'] as String?;
    final disposition = dispositionName == null
        ? null
        : ClinicalLongFormAudioDisposition.values.firstWhere(
            (value) => value.name == dispositionName,
          );

    return ClinicalLongFormReviewedTranscriptArtifact(
      sessionId: json['sessionId']! as String,
      locale: json['locale']! as String,
      reviewedTranscript: json['reviewedTranscript']! as String,
      reviewedAtUtc: DateTime.parse(
        json['reviewedAtUtc']! as String,
      ).toUtc(),
      sourceSegmentCount: json['sourceSegmentCount']! as int,
      sourceActiveDuration: Duration(
        milliseconds: json['sourceActiveDurationMs']! as int,
      ),
      retentionState: retentionState,
      audioDisposition: disposition,
      lastCleanupErrorCode: json['lastCleanupErrorCode'] as String?,
    );
  }
}
