import 'dart:async';
import '../notifications/durable_result_notification.dart';
import '../notifications/notification_contract.dart';
import 'dart:convert';
import '../audio/recording_deletion_store.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/study_workspace_model.dart';

final class StudyLibraryService {
  const StudyLibraryService._();

  static const _key = 'medcases.study.library.v1';
  static const int maxStudies = 40;
  static String? get currentOwner => RecordingDeletionStore.owner;
  static String _ownerKey(String uid) =>
      '$_key.${base64Url.encode(utf8.encode(uid))}';
  static void _checkOwner(String? uid) {
    if (uid == null || currentOwner != uid)
      throw StateError('study_owner_changed');
  }

  static Future<List<Study>> loadAll() async {
    final uid = currentOwner;
    if (uid == null) return const <Study>[];
    final prefs = await SharedPreferences.getInstance();
    _checkOwner(uid);
    final raw = prefs.getString(_ownerKey(uid)) ?? prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return const <Study>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Study>[];

      final studies = <Study>[];
      for (final item in decoded) {
        if (item is Map) {
          final map = item.map((k, v) => MapEntry('$k', v));
          final study = _decodeStudy(map);
          final proven = study.ownerUid == uid ||
              (study.ownerUid == null &&
                  study.sources.isNotEmpty &&
                  study.sources.every((source) => prefs
                          .getKeys()
                          .where((k) => k.startsWith(
                              'medcases.recorded.pending.$uid.${study.id}.'))
                          .any((k) {
                        try {
                          final binding =
                              jsonDecode(prefs.getString(k)!) as Map;
                          return binding['sourceId'] == source.id &&
                              binding['sessionId'] == source.recordingSessionId;
                        } catch (_) {
                          return false;
                        }
                      })));
          if (proven)
            studies.add(await _withoutDeleted(study.copyWith(ownerUid: uid)));
        }
      }
      studies.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
      _checkOwner(uid);
      return List<Study>.unmodifiable(studies.take(maxStudies));
    } catch (_) {
      return const <Study>[];
    }
  }

  static Future<String?> activeStudyId() async {
    final uid = currentOwner;
    if (uid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    _checkOwner(uid);
    return prefs.getString('${_ownerKey(uid)}.activeStudy');
  }

  static Future<void> _writes = Future.value();
  static Future<Study> saveSource(Study study, StudySource source) {
    final uid = currentOwner;
    _checkOwner(uid);
    if (study.ownerUid != null && study.ownerUid != uid)
      throw StateError("study_owner_changed");
    study = study.copyWith(ownerUid: uid);
    late Study merged;
    final next = _writes.then((_) async {
      _checkOwner(uid);
      final owner = uid;
      final sid = source.recordingSessionId;
      if (owner != null &&
          sid != null &&
          await RecordingDeletionStore.state(owner, sid) != null) {
        merged = await _withoutDeleted(study);
        return;
      }
      final all = await loadAll();
      final current = all.where((s) => s.id == study.id).firstOrNull ?? study;
      final exists = current.sources.any((s) => s.id == source.id);
      merged = current.copyWith(
          sources: exists
              ? current.sources
                  .map((s) => s.id == source.id ? source : s)
                  .toList()
              : [...current.sources, source]);
      await _save(merged);
    });
    _writes = next.catchError((Object _) {});
    return next.then((_) => merged);
  }

  static Future<Study> saveArtifact(Study snapshot, StudyArtifact artifact) {
    final uid = currentOwner;
    _checkOwner(uid);
    if (snapshot.ownerUid != null && snapshot.ownerUid != uid)
      throw StateError('study_owner_changed');
    snapshot = snapshot.copyWith(ownerUid: uid);
    late Study merged;
    final next = _writes.then((_) async {
      _checkOwner(uid);
      final current =
          (await loadAll()).where((s) => s.id == snapshot.id).firstOrNull ??
              snapshot;
      merged = current.copyWith(artifacts: [
        ...current.artifacts.where((a) => a.id != artifact.id),
        artifact,
      ]);
      await _save(merged);
      if (artifact.type == StudyArtifactType.visualSummary ||
          artifact.type == StudyArtifactType.fullSummary ||
          artifact.type == StudyArtifactType.oralExam) {
        final persisted = (await loadAll())
            .where((s) => s.id == snapshot.id && s.ownerUid == uid)
            .expand((s) => s.artifacts)
            .any((a) => a.id == artifact.id && a.content == artifact.content);
        if (!persisted) throw StateError('study_visual_persistence_failed');
      }
    });
    _writes = next.catchError((Object _) {});
    return next.then((_) => merged);
  }

  static Future<void> save(Study study) {
    final uid = currentOwner;
    _checkOwner(uid);
    if (study.ownerUid != null && study.ownerUid != uid)
      throw StateError('study_owner_changed');
    final bound = study.copyWith(ownerUid: uid);
    final next = _writes.then((_) async {
      _checkOwner(uid);
      await _save(bound);
      _checkOwner(uid);
      await (await SharedPreferences.getInstance())
          .setString('${_ownerKey(uid!)}.activeStudy', bound.id);
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  static Future<Study> _withoutDeleted(Study study) async {
    final owner = RecordingDeletionStore.owner;
    if (owner == null) return study;
    final sources = <StudySource>[];
    for (final source in study.sources) {
      final sid = source.recordingSessionId;
      if (sid != null &&
          await RecordingDeletionStore.state(owner, sid) == 'deleted') continue;
      sources.add(source);
    }
    return study.copyWith(sources: sources);
  }

  static Future<void> _save(Study study) async {
    final owner = study.ownerUid;
    _checkOwner(owner);
    final previousIds =
        (await loadAll()).expand((s) => s.artifacts).map((a) => a.id).toSet();
    study = await _withoutDeleted(study);
    final studies = List<Study>.from(await loadAll())
      ..removeWhere((item) => item.id == study.id)
      ..insert(0, study);

    if (studies.length > maxStudies) {
      studies.removeRange(maxStudies, studies.length);
    }

    final prefs = await SharedPreferences.getInstance();
    _checkOwner(owner);
    await prefs.setString(
      _ownerKey(study.ownerUid!),
      jsonEncode(studies.map(_encodeStudy).toList(growable: false)),
    );
    if (owner != null) {
      for (final artifact
          in study.artifacts.where((a) => !previousIds.contains(a.id))) {
        unawaited(DurableResultNotification.publish(
            event: artifact.type == StudyArtifactType.fullSummary ||
                    artifact.type == StudyArtifactType.visualSummary
                ? NotificationEvent.consultationSummaryReady
                : NotificationEvent.contentProcessed,
            resourceId: artifact.id,
            ownerUid: owner));
      }
    }
  }

  static Future<void> deleteById(String studyId) async {
    final uid = currentOwner;
    _checkOwner(uid);
    final normalized = studyId.trim();
    if (normalized.isEmpty) return;
    final studies = List<Study>.from(await loadAll())
      ..removeWhere((item) => item.id == normalized);
    final prefs = await SharedPreferences.getInstance();
    if (studies.isEmpty) {
      _checkOwner(uid);
      await prefs.remove(_ownerKey(uid!));
      return;
    }
    _checkOwner(uid);
    await prefs.setString(
      _ownerKey(uid!),
      jsonEncode(studies.map(_encodeStudy).toList(growable: false)),
    );
  }

  static Map<String, Object?> _encodeStudy(Study study) {
    return <String, Object?>{
      'id': study.id,
      'ownerUid': study.ownerUid,
      'activeSourceId': study.activeSourceId,
      'title': study.title,
      'locale': study.locale,
      'createdAtUtc': study.createdAtUtc.toUtc().toIso8601String(),
      'sources': study.sources.map(_encodeSource).toList(growable: false),
      'artifacts': study.artifacts.map(_encodeArtifact).toList(growable: false),
    };
  }

  static Map<String, Object?> _encodeSource(StudySource source) {
    return <String, Object?>{
      'id': source.id,
      'type': source.type.name,
      'title': source.title,
      'state': source.state.name,
      'createdAtUtc': source.createdAtUtc.toUtc().toIso8601String(),
      'text': source.text,
      'errorCode': source.errorCode,
      'recordingSessionId': source.recordingSessionId,
      'audioPaths': source.audioPaths,
      'audioDurationMs': source.audioDurationMs,
      'refs': source.refs
          .map(
            (ref) => <String, Object?>{
              'sourceId': ref.sourceId,
              'sourceType': ref.sourceType.name,
              'pageNumber': ref.pageNumber,
              'timestampStartMs': ref.timestampStartMs,
              'timestampEndMs': ref.timestampEndMs,
              'imageIndex': ref.imageIndex,
              'textBlockIndex': ref.textBlockIndex,
            },
          )
          .toList(growable: false),
    };
  }

  static Map<String, Object?> _encodeArtifact(StudyArtifact artifact) {
    return <String, Object?>{
      'id': artifact.id,
      'type': artifact.type.name,
      'title': artifact.title,
      'content': artifact.content,
      'createdAtUtc': artifact.createdAtUtc.toUtc().toIso8601String(),
      'sourceIds': artifact.sourceIds,
    };
  }

  static Study _decodeStudy(Map<String, dynamic> json) {
    final sources = <StudySource>[];
    final rawSources = json['sources'];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is Map) {
          sources.add(_decodeSource(item.map((k, v) => MapEntry('$k', v))));
        }
      }
    }

    final artifacts = <StudyArtifact>[];
    final rawArtifacts = json['artifacts'];
    if (rawArtifacts is List) {
      for (final item in rawArtifacts) {
        if (item is Map) {
          artifacts.add(_decodeArtifact(item.map((k, v) => MapEntry('$k', v))));
        }
      }
    }

    return Study(
      id: '${json['id'] ?? ''}',
      ownerUid: json['ownerUid'] as String?,
      activeSourceId: json.containsKey('activeSourceId')
          ? json['activeSourceId'] as String?
          : _legacyActive(sources),
      title: '${json['title'] ?? ''}',
      locale: '${json['locale'] ?? 'pt-BR'}',
      createdAtUtc: _date(json['createdAtUtc']),
      sources: List<StudySource>.unmodifiable(sources),
      artifacts: List<StudyArtifact>.unmodifiable(artifacts),
    );
  }

  // Deterministic one-time selection for existing records without a pointer.
  static String? _legacyActive(List<StudySource> sources) {
    final audio = sources.where((s) => s.isAudio).toList()
      ..sort((a, b) {
        final time = a.createdAtUtc.compareTo(b.createdAtUtc);
        return time != 0 ? time : a.id.compareTo(b.id);
      });
    return audio.isEmpty ? null : audio.last.id;
  }

  static StudySource _decodeSource(Map<String, dynamic> json) {
    final refs = <SourceRef>[];
    final rawRefs = json['refs'];
    if (rawRefs is List) {
      for (final item in rawRefs) {
        if (item is Map) {
          final map = item.map((k, v) => MapEntry('$k', v));
          refs.add(
            SourceRef(
              sourceId: '${map['sourceId'] ?? ''}',
              sourceType: _sourceType('${map['sourceType'] ?? 'text'}'),
              pageNumber: _int(map['pageNumber']),
              timestampStartMs: _int(map['timestampStartMs']),
              timestampEndMs: _int(map['timestampEndMs']),
              imageIndex: _int(map['imageIndex']),
              textBlockIndex: _int(map['textBlockIndex']),
            ),
          );
        }
      }
    }

    return StudySource(
      id: '${json['id'] ?? ''}',
      type: _sourceType('${json['type'] ?? 'text'}'),
      title: '${json['title'] ?? ''}',
      state: _sourceState('${json['state'] ?? 'added'}'),
      createdAtUtc: _date(json['createdAtUtc']),
      text: '${json['text'] ?? ''}',
      refs: List<SourceRef>.unmodifiable(refs),
      errorCode: json['errorCode']?.toString(),
      recordingSessionId: json['recordingSessionId']?.toString(),
      audioPaths: List<String>.from(json['audioPaths'] ?? const []),
      audioDurationMs: _int(json['audioDurationMs']) ?? 0,
    );
  }

  static StudyArtifact _decodeArtifact(Map<String, dynamic> json) {
    final ids = <String>[];
    final raw = json['sourceIds'];
    if (raw is List) ids.addAll(raw.map((item) => '$item'));

    return StudyArtifact(
      id: '${json['id'] ?? ''}',
      type: _artifactType('${json['type'] ?? 'fullSummary'}'),
      title: '${json['title'] ?? ''}',
      content: '${json['content'] ?? ''}',
      createdAtUtc: _date(json['createdAtUtc']),
      sourceIds: List<String>.unmodifiable(ids),
    );
  }

  static StudySourceType _sourceType(String value) =>
      StudySourceType.values.firstWhere(
        (item) => item.name == value,
        orElse: () => StudySourceType.text,
      );

  static StudySourceState _sourceState(String value) =>
      StudySourceState.values.firstWhere(
        (item) => item.name == value,
        orElse: () => StudySourceState.added,
      );

  static StudyArtifactType _artifactType(String value) =>
      StudyArtifactType.values.firstWhere(
        (item) => item.name == value,
        orElse: () => StudyArtifactType.fullSummary,
      );

  static DateTime _date(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
