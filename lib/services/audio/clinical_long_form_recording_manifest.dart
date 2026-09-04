import 'clinical_long_form_audio_contract.dart';

final class ClinicalLongFormSegmentManifest {
  const ClinicalLongFormSegmentManifest({
    required this.index,
    required this.path,
    required this.startedAtUtc,
    required this.activeDuration,
    required this.completed,
  });

  final int index;
  final String path;
  final DateTime startedAtUtc;
  final Duration activeDuration;
  final bool completed;

  Map<String, Object?> toJson() => <String, Object?>{
        'index': index,
        'path': path,
        'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
        'activeDurationMs': activeDuration.inMilliseconds,
        'completed': completed,
      };

  factory ClinicalLongFormSegmentManifest.fromJson(
    Map<String, Object?> json,
  ) {
    return ClinicalLongFormSegmentManifest(
      index: json['index']! as int,
      path: json['path']! as String,
      startedAtUtc: DateTime.parse(
        json['startedAtUtc']! as String,
      ).toUtc(),
      activeDuration: Duration(
        milliseconds: json['activeDurationMs']! as int,
      ),
      completed: json['completed']! as bool,
    );
  }
}

final class ClinicalLongFormRecordingManifest {
  ClinicalLongFormRecordingManifest({
    required this.sessionId,
    required this.locale,
    required this.state,
    required this.createdAtUtc,
    required this.totalActiveDuration,
    required Iterable<ClinicalLongFormSegmentManifest> segments,
  }) : segments = List<ClinicalLongFormSegmentManifest>.unmodifiable(
          segments,
        ) {
    validate();
  }

  final String sessionId;
  final String locale;
  final ClinicalLongFormRecordingState state;
  final DateTime createdAtUtc;
  final Duration totalActiveDuration;
  final List<ClinicalLongFormSegmentManifest> segments;

  void validate() {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    if (locale.trim().isEmpty) {
      throw ArgumentError.value(locale, 'locale');
    }
    if (totalActiveDuration.isNegative) {
      throw ArgumentError.value(
        totalActiveDuration,
        'totalActiveDuration',
      );
    }

    for (var i = 0; i < segments.length; i++) {
      if (segments[i].index != i) {
        throw StateError(
          'Long-form segment indices must be contiguous from zero.',
        );
      }
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'schema': 'medcases.long_form_audio_manifest.v1',
        'sessionId': sessionId,
        'locale': locale,
        'state': state.name,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'totalActiveDurationMs': totalActiveDuration.inMilliseconds,
        'segments':
            segments.map((segment) => segment.toJson()).toList(growable: false),
      };

  factory ClinicalLongFormRecordingManifest.fromJson(
    Map<String, Object?> json,
  ) {
    if (json['schema'] != 'medcases.long_form_audio_manifest.v1') {
      throw const FormatException('Unsupported long-form manifest schema.');
    }

    final rawSegments = json['segments'];
    if (rawSegments is! List) {
      throw const FormatException('Invalid long-form segments.');
    }

    final stateName = json['state']! as String;
    final state = ClinicalLongFormRecordingState.values.firstWhere(
      (value) => value.name == stateName,
    );

    return ClinicalLongFormRecordingManifest(
      sessionId: json['sessionId']! as String,
      locale: json['locale']! as String,
      state: state,
      createdAtUtc: DateTime.parse(
        json['createdAtUtc']! as String,
      ).toUtc(),
      totalActiveDuration: Duration(
        milliseconds: json['totalActiveDurationMs']! as int,
      ),
      segments: rawSegments
          .cast<Map<String, Object?>>()
          .map(ClinicalLongFormSegmentManifest.fromJson),
    );
  }
}

final class ClinicalLongFormRecoveryPlan {
  const ClinicalLongFormRecoveryPlan({
    required this.canRecover,
    required this.nextSegmentIndex,
    required this.totalRecoveredDuration,
    required this.reason,
  });

  factory ClinicalLongFormRecoveryPlan.fromManifest(
    ClinicalLongFormRecordingManifest manifest,
  ) {
    final recoverable =
        manifest.state == ClinicalLongFormRecordingState.recording ||
            manifest.state == ClinicalLongFormRecordingState.paused;

    return ClinicalLongFormRecoveryPlan(
      canRecover: recoverable,
      nextSegmentIndex: manifest.segments.length,
      totalRecoveredDuration: manifest.totalActiveDuration,
      reason: recoverable ? 'resume_as_new_segment' : 'manifest_not_active',
    );
  }

  final bool canRecover;

  /// Nunca tenta anexar bytes ao último M4A após crash.
  /// Recuperação abre sempre um novo segmento.
  final int nextSegmentIndex;
  final Duration totalRecoveredDuration;
  final String reason;
}
