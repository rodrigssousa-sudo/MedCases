import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/study_workspace_model.dart';

/// Metadata-only receipt. Never stores source text, titles, tokens or audio.
final class StudyArtifactAttemptClient {
  StudyArtifactAttemptClient._(this.owner, this.id);
  final String owner;
  final String id;
  static const _channel =
      MethodChannel('medcases/study_background_transcription_v1');
  static final _base = Uri.parse(const String.fromEnvironment(
      'MEDCASES_AI_GATEWAY_BASE_URL',
      defaultValue: 'https://medcases-scw37.ondigitalocean.app'));
  static const _prefix = 'medcases.derived.events.v1.';
  static Future<void> _post(
      String owner, String path, Map<String, Object?> body,
      {Duration timeout = const Duration(seconds: 3)}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != owner) {
      throw StateError('study_owner_changed');
    }
    final token = await user.getIdToken().timeout(timeout);
    if (token == null || FirebaseAuth.instance.currentUser?.uid != owner) {
      throw StateError('study_owner_changed');
    }
    final response = await http
        .post(_base.resolve(path),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(body))
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw StateError('study_attempt_unavailable');
    }
  }

  static Future<StudyArtifactAttemptClient> begin(
      Study study, StudyArtifactType type, String artifactId, bool isEs) async {
    final owner = study.ownerUid;
    if (owner == null || owner.isEmpty) throw StateError('study_owner_changed');
    final id =
        'da_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    final metadata =
        await _channel.invokeMapMethod<String, dynamic>('appMetadata');
    final attempt = StudyArtifactAttemptClient._(owner, id);
    unawaited(flush(owner).catchError((Object _) {}));
    await _post(owner, '/api/ai/study/artifact-attempts', {
      'attemptId': id,
      'artifactId': artifactId,
      'studyId': study.id,
      'sourceIds': study.acceptedSources.map((s) => s.id).toList(),
      'sessionIds': study.acceptedSources
          .map((s) => s.recordingSessionId)
          .whereType<String>()
          .toList(),
      'type': type == StudyArtifactType.fullSummary
          ? 'summary'
          : type == StudyArtifactType.oralExam
              ? 'oral'
              : 'visual',
      'platform': defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'unknown',
      'locale': isEs ? 'es' : 'pt',
      'appVersion': metadata?['appVersion'],
      'buildNumber': metadata?['buildNumber'],
    });
    return attempt;
  }

  /// Failure to deliver telemetry never discards already generated material.
  /// Events are retried only for their original authenticated owner.
  Future<void> event(String state, {String? reason}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix${base64Url.encode(utf8.encode(owner))}.$id.$state';
      final record = <String, Object?>{
        'path': '/api/ai/study/artifact-attempts/$id/events',
        'body': {'state': state, if (reason != null) 'reasonCode': reason}
      };
      await prefs.setString(key, jsonEncode(record));
      await _post(owner, record['path']! as String,
          Map<String, Object?>.from(record['body']! as Map));
      await prefs.remove(key);
    } catch (_) {
      debugPrint('[StudyArtifact] stage=TELEMETRY_PENDING');
    }
  }

  static Future<void> flush(String owner) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_prefix${base64Url.encode(utf8.encode(owner))}.';
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList()
      ..sort();
    for (final key in keys.take(30)) {
      try {
        final value = jsonDecode(prefs.getString(key)!) as Map;
        await _post(owner, value['path'] as String,
            Map<String, Object?>.from(value['body'] as Map));
        await prefs.remove(key);
      } catch (_) {
        break;
      }
    }
  }

  static String reason(Object error) {
    if (error is TimeoutException) return 'PROVIDER_TIMEOUT';
    if (error is FormatException) return 'PARSE_FAILURE';
    final code =
        error is StateError ? error.message.toString().toLowerCase() : '';
    if (code.contains('owner') ||
        code.contains('auth') ||
        code.contains('no_key')) {
      return 'AUTH';
    }
    if (code.contains('context_empty') || code.contains('no_material')) {
      return 'CONTEXT_EMPTY';
    }
    if (code.contains('timeout')) return 'PROVIDER_TIMEOUT';
    if (code.contains('truncat')) return 'TRUNCATED_OUTPUT';
    if (code.contains('parse') ||
        code.contains('visual_invalid') ||
        code.contains('invalid_visual')) {
      return 'PARSE_FAILURE';
    }
    if (code.contains('persist')) return 'PERSISTENCE_FAILURE';
    if (code.contains('network')) return 'NETWORK';
    if (code.contains('upstream') || code.contains('5xx')) {
      return 'PROVIDER_5XX';
    }
    return 'OTHER';
  }
}
