import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/study_workspace_model.dart';

final class StudyLibraryService {
  const StudyLibraryService._();

  static const _key = 'medcases.study.library.v1';
  static const int maxStudies = 40;

  static Future<List<Study>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return const <Study>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Study>[];

      final studies = <Study>[];
      for (final item in decoded) {
        if (item is Map) {
          final map = item.map((k, v) => MapEntry('$k', v));
          studies.add(_decodeStudy(map));
        }
      }
      studies.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
      return List<Study>.unmodifiable(studies.take(maxStudies));
    } catch (_) {
      return const <Study>[];
    }
  }

  static Future<void> save(Study study) async {
    final studies = List<Study>.from(await loadAll())
      ..removeWhere((item) => item.id == study.id)
      ..insert(0, study);

    if (studies.length > maxStudies) {
      studies.removeRange(maxStudies, studies.length);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(studies.map(_encodeStudy).toList(growable: false)),
    );
  }

  static Future<void> deleteById(String studyId) async {
    final normalized = studyId.trim();
    if (normalized.isEmpty) return;
    final studies = List<Study>.from(await loadAll())
      ..removeWhere((item) => item.id == normalized);
    final prefs = await SharedPreferences.getInstance();
    if (studies.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(
      _key,
      jsonEncode(studies.map(_encodeStudy).toList(growable: false)),
    );
  }

  static Map<String, Object?> _encodeStudy(Study study) {
    return <String, Object?>{
      'id': study.id,
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
      title: '${json['title'] ?? ''}',
      locale: '${json['locale'] ?? 'pt-BR'}',
      createdAtUtc: _date(json['createdAtUtc']),
      sources: List<StudySource>.unmodifiable(sources),
      artifacts: List<StudyArtifact>.unmodifiable(artifacts),
    );
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
