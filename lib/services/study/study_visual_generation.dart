import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/study_workspace_model.dart';

/// Single-flight generation scoped to the exact owner, source content and locale.
/// Completed output survives a persistence retry; failed requests are not cached.
final class StudyVisualGeneration {
  static final _pending = <String, Future<StudyArtifact>>{};
  static final _completed = <String, StudyArtifact>{};

  static String identity(Study study, bool isEs,
      {StudyArtifactType type = StudyArtifactType.visualSummary}) {
    if (study.ownerUid == null || study.ownerUid!.isEmpty) {
      throw StateError('study_owner_changed');
    }
    if (study.acceptedSources.isEmpty ||
        study.acceptedSources.any((s) => s.text.trim().isEmpty)) {
      throw StateError('study_visual_context_empty');
    }
    final binding = {
      'contract': type == StudyArtifactType.visualSummary
          ? 'visual_v2'
          : type == StudyArtifactType.fullSummary
              ? 'full_summary_coverage_v2'
              : 'derived_v1_${type.name}',
      'owner': study.ownerUid,
      'study': study.id,
      'title': study.title,
      'locale': isEs ? 'es' : 'pt',
      'sources': study.acceptedSources
          .map((s) => {
                'source': s.id,
                'session': s.recordingSessionId,
                'title': s.title,
                'content': sha256.convert(utf8.encode(s.text)).toString(),
              })
          .toList(),
    };
    final prefix =
        type == StudyArtifactType.visualSummary ? 'visual' : type.name;
    return 'artifact_${prefix}_${sha256.convert(utf8.encode(jsonEncode(binding)))}';
  }

  static Future<StudyArtifact> run(
      String id, Future<StudyArtifact> Function() generate) {
    final cached = _completed[id];
    if (cached != null) return Future.value(cached);
    final existing = _pending[id];
    if (existing != null) return existing;
    final future = Future<StudyArtifact>.sync(generate).then((result) {
      _completed[id] = result;
      while (_completed.length > 8) {
        _completed.remove(_completed.keys.first);
      }
      return result;
    }).whenComplete(() {
      _pending.remove(id);
    });
    _pending[id] = future;
    return future;
  }
}
