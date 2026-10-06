import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../audio/recording_deletion_store.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/study_workspace_model.dart';
import '../../models/study_long_form_audio_handoff.dart';
import '../audio/recording_session_controller.dart';
import '../audio/recording_transcription_driver.dart';
import '../audio/transcription_diagnostics.dart';
import 'study_multimodal_extraction_service.dart';
import 'study_library_service.dart';

/// One route-independent coordinator per owner, study and recording session.
class RecordedStudyTranscription extends ChangeNotifier {
  RecordedStudyTranscription._(
      this.study, this.sourceId, this.handoff, this.uid);
  static final Map<String, RecordedStudyTranscription> _jobs = {};
  Study study;
  final String sourceId;
  final StudyLongFormAudioHandoff handoff;
  final String uid;
  String get jobId => "$uid:$sourceId:${handoff.sessionId}";
  DateTime get createdAtUtc => source.createdAtUtc;
  String? message;
  List<String> pathsRetained = [];
  bool get isEs => study.locale.startsWith('es');
  StudySource get source => study.sources.firstWhere((s) => s.id == sourceId);
  bool get busy => source.state == StudySourceState.processing;
  bool get canRetry => source.canRetryTranscription;
  bool get _authorized =>
      !RecordingDeletionStore.blockedCached(uid, handoff.sessionId) &&
      (_ownerCheck?.call() ?? FirebaseAuth.instance.currentUser?.uid == uid);
  Future<bool> audioRetained() async {
    if (!_authorized || handoff.segments.isEmpty) return false;
    for (final segment in handoff.segments) {
      final file = File(segment.path);
      if (!await file.exists() || await file.length() == 0) return false;
    }
    return _authorized;
  }

  bool Function()? _ownerCheck;
  Future<StudyExtraction> Function()? _executor;
  Future<void> Function(Study)? _persistOverride;
  Future<void> _persist() async {
    if (!_authorized) return;
    if (_persistOverride != null) {
      await _persistOverride!(study);
      return;
    }
    study = await StudyLibraryService.saveSource(study, source);
  }

  @visibleForTesting
  RecordedStudyTranscription.testing(
      {required this.study,
      required this.sourceId,
      required this.handoff,
      required this.uid,
      required bool Function() ownerCheck,
      required Future<StudyExtraction> Function() execute,
      required Future<void> Function(Study) persist}) {
    _ownerCheck = ownerCheck;
    _executor = execute;
    _persistOverride = persist;
    _bindSource();
  }
  String get _key =>
      'medcases.recorded.pending.$uid.${study.id}.${handoff.sessionId}';
  static String _jobKey(String uid, String studyId, String sessionId) =>
      '$uid:$studyId:$sessionId';

  static RecordedStudyTranscription start(
      Study study, String sourceId, StudyLongFormAudioHandoff handoff) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final key = _jobKey(uid, study.id, handoff.sessionId);
    final previous = _jobs[key];
    if (previous != null) {
      final liveSource = previous.source;
      previous.study = study.copyWith(
          sources: study.sources
              .map((s) => s.id == previous.sourceId ? liveSource : s)
              .toList());
      return previous;
    }
    final job = RecordedStudyTranscription._(study, sourceId, handoff, uid)
      .._bindSource();
    _jobs[key] = job;
    unawaited(handoff.deferTranscription ? job.retainAudio() : job.retry());
    return job;
  }

  static Future<RecordedStudyTranscription?> restore(Study study) async {
    final all = await restoreAll(study);
    return all.isEmpty ? null : all.last;
  }

  static Future<List<RecordedStudyTranscription>> restoreAll(
      Study study) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final prefs = await SharedPreferences.getInstance();
    await deduplicateLegacyAlias(
        prefs, study, uid, () => FirebaseAuth.instance.currentUser?.uid);
    // Read old bindings only when they explicitly map an existing source.
    final prefix = 'medcases.recorded.pending.$uid.${study.id}';
    for (final key in prefs
        .getKeys()
        .where((k) => k == prefix || k.startsWith('$prefix.'))) {
      try {
        final d = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
        final id = d['sourceId'];
        final sid = d['sessionId'];
        if (sid is! String || sid.isEmpty) continue;
        study = study.copyWith(
            sources: study.sources.map((s) {
          if (s.id != id || s.recordingSessionId != null) return s;
          return s.bindRecording(
              sid,
              (d['segments'] as List).map((s) => s['path'] as String).toList(),
              (d['duration'] as num).toInt());
        }).toList());
      } catch (_) {/* Unproven legacy identities remain untouched. */}
    }
    final result = <RecordedStudyTranscription>[];
    for (final source in study.sources) {
      final sid = source.recordingSessionId;
      if (source.type != StudySourceType.recordedAudio ||
          sid == null ||
          source.audioPaths.isEmpty) continue;
      if (await RecordingDeletionStore.state(uid, sid) != null) continue;
      final key = _jobKey(uid, study.id, sid);
      final live = _jobs[key];
      if (live != null) {
        result.add(live);
        continue;
      }
      final h = StudyLongFormAudioHandoff(
          sessionId: sid,
          locale: study.locale,
          totalActiveDurationMs: source.audioDurationMs,
          deferTranscription: true,
          segments: [
            for (var i = 0; i < source.audioPaths.length; i++)
              StudyLongFormAudioSegment(
                  index: i,
                  path: source.audioPaths[i],
                  activeDurationMs: i == 0 ? source.audioDurationMs : 0)
          ]);
      final job = RecordedStudyTranscription._(study, source.id, h, uid);
      if (source.state == StudySourceState.processing ||
          source.state == StudySourceState.added ||
          (source.state == StudySourceState.failed &&
              source.errorCode == 'transcription_pending')) {
        job._replace(source.transition(StudySourceState.transcriptionPending));
      }
      job.pathsRetained = source.audioPaths;
      _jobs[key] = job;
      result.add(job);
    }
    return result;
  }

  /// Remove only a byte-identical old alias with a proven existing source.
  /// Divergent or incomplete checkpoints remain available for recovery.
  static Future<bool> deduplicateLegacyAlias(SharedPreferences prefs,
      Study study, String uid, String? Function() currentUid) async {
    final key = 'medcases.recorded.pending.$uid.${study.id}';
    final raw = prefs.getString(key);
    if (raw == null || currentUid() != uid) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final sid = data['sessionId'];
      if (sid is! String ||
          sid.isEmpty ||
          !study.sources.any((s) =>
              s.id == data['sourceId'] &&
              s.type == StudySourceType.recordedAudio &&
              s.recordingSessionId == sid)) return false;
      if (prefs.getString('$key.$sid') != raw || currentUid() != uid)
        return false;
      return prefs.remove(key);
    } catch (_) {
      return false;
    }
  }

  void _bindSource() {
    final current = source;
    _replace(current.bindRecording(
        handoff.sessionId,
        handoff.segments.map((s) => s.path).toList(),
        handoff.totalActiveDurationMs));
  }

  Future<void> _savePending() async {
    if (!_authorized || _persistOverride != null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key,
        jsonEncode({
          'sourceId': sourceId,
          'userId': uid,
          'jobId': jobId,
          'createdAt': createdAtUtc.toIso8601String(),
          'sessionId': handoff.sessionId,
          'locale': handoff.locale,
          'duration': handoff.totalActiveDurationMs,
          'segments': handoff.segments
              .map((s) => {
                    'index': s.index,
                    'path': s.path,
                    'duration': s.activeDurationMs
                  })
              .toList()
        }));
  }

  void _replace(StudySource next) {
    study = study.copyWith(
        sources:
            study.sources.map((s) => s.id == sourceId ? next : s).toList());
    if (_authorized) notifyListeners();
  }

  Future<void> retainAudio() async {
    if (!_authorized || source.isAccepted || source.canReview || busy) return;
    pathsRetained = handoff.segments.map((s) => s.path).toList();
    _replace(source.transition(StudySourceState.transcriptionPending));
    await _persist();
    await _savePending();
  }

  Future<void> retry() async {
    if (busy ||
        !_authorized ||
        source.isAccepted ||
        source.canReview ||
        source.state == StudySourceState.terminalError) return;
    message = null;
    pathsRetained = handoff.segments.map((s) => s.path).toList();
    _replace(source.transition(StudySourceState.processing));
    try {
      await _persist();
      await _savePending();
      final extraction = await (_executor?.call() ?? _transcribe());
      if (!_authorized) return;
      if (extraction.text.trim().isEmpty)
        throw const TranscriptionFailure('INVALID_AUDIO', retryable: false);
      _replace(source.transition(StudySourceState.review,
          extractedText: extraction.text, sourceRefs: extraction.refs));
      await _persist();
      message = isEs
          ? 'Transcripción lista para revisar.'
          : 'Transcrição pronta para revisão.';
    } catch (error) {
      if (!_authorized) return;
      final failure = TranscriptionFailure.classify(error);
      _replace(source.transition(
          failure.retryable
              ? StudySourceState.retryableError
              : StudySourceState.terminalError,
          error: failure.code));
      try {
        await _persist();
        await _savePending();
      } catch (_) {}
      message = isEs
          ? 'La transcripción no se completó. El audio está guardado.'
          : 'A transcrição não foi concluída. O áudio está salvo.';
    } finally {
      if (_authorized) notifyListeners();
    }
  }

  Future<StudyExtraction> _transcribe() async {
    final controller = RecordingSessionController.instance;
    await controller.openSession(handoff.sessionId);
    if (controller.session?.sessionId != handoff.sessionId ||
        controller.session?.ownerUid != uid)
      throw const TranscriptionFailure('RECORDING_SESSION_UNAVAILABLE');
    final text =
        await controller.transcribe(RecordingTranscriptionDriver.execute);
    final session = controller.session;
    if (session != null) {
      try {
        await RecordingTranscriptionDriver.settle(session);
      } catch (_) {}
    }
    return StudyExtraction(text: text, refs: [
      SourceRef(
          sourceId: sourceId,
          sourceType: StudySourceType.recordedAudio,
          timestampStartMs: 0)
    ]);
  }
}
