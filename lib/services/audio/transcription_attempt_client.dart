import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'recording_session_controller.dart';
import 'transcription_diagnostics.dart';

/// Metadata only. The local checkpoint retains the ID if the network is down.
class TranscriptionAttemptClient {
  static const _channel =
      MethodChannel('medcases/study_background_transcription_v1');
  static final _base = Uri.parse(const String.fromEnvironment(
      'MEDCASES_AI_GATEWAY_BASE_URL',
      defaultValue: 'https://medcases-scw37.ondigitalocean.app'));
  static String newId() =>
      'ta_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  static Future<void> _send(
      RecordingSessionData s, String path, Map<String, Object?> value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != s.ownerUid)
      throw const TranscriptionFailure('USER_CHANGED', retryable: false);
    final token = await user.getIdToken();
    if (token == null) throw const TranscriptionFailure('AUTH_FAILURE');
    if (FirebaseAuth.instance.currentUser?.uid != s.ownerUid)
      throw const TranscriptionFailure('USER_CHANGED', retryable: false);
    final response = await http
        .post(_base.resolve(path),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(value))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw const TranscriptionFailure('ATTEMPT_PERSISTENCE_FAILURE');
  }

  static Future<void> requested(RecordingSessionData s) async {
    final metadata =
        await _channel.invokeMapMethod<String, dynamic>('appMetadata');
    await _send(s, '/api/ai/transcription/attempts', {
      'attemptId': s.job['transcriptionAttemptId'],
      'sourceId': s.sessionId,
      'sessionId': s.sessionId,
      'platform': Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : 'unknown',
      'appVersion': metadata?['appVersion'],
      'buildNumber': metadata?['buildNumber'],
      'locale': s.language.startsWith('es') ? 'es' : 'pt',
    });
    s.job['attemptRegistered'] = true;
  }

  static Future<void> failed(RecordingSessionData s, String code) async {
    final reason = switch (code) {
      'TRANSCRIPTION_LIMIT_REACHED' ||
      'MONTHLY_USAGE_LIMIT' =>
        'TRANSCRIPTION_LIMIT_REACHED',
      'AUTH_FAILURE' => 'AUTH_FAILURE',
      'NETWORK_FAILURE' => 'NETWORK_FAILURE',
      'TIMEOUT' || 'NO_PROGRESS' => 'CLIENT_TIMEOUT',
      'INVALID_AUDIO' => 'MEDIA_PROOF_FAILURE',
      'DURATION_LIMIT' => 'DURATION_LIMIT',
      'NATIVE_UPLOAD_FAILURE' => 'UPLOAD_FAILURE',
      _ => 'UNKNOWN',
    };
    s.job['attemptPendingFailure'] = reason;
    if (s.transcriptionJobId == null) s.job['attemptClosed'] = true;
    if (s.job['attemptRegistered'] != true) await requested(s);
    await _send(
        s,
        '/api/ai/transcription/attempts/${s.job['transcriptionAttemptId']}/events',
        {
          'eventId': 'client-failure',
          'state': 'FAILED',
          'stage': 'VALIDATING',
          'reasonCode': reason,
        });
    s.job.remove('attemptPendingFailure');
  }
}
