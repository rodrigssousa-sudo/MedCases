import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

final class StudyBackgroundSegmentSpec {
  const StudyBackgroundSegmentSpec({
    required this.index,
    required this.path,
    required this.mimeType,
  });

  final int index;
  final String path;
  final String mimeType;

  Map<String, Object?> toNativeMap() => <String, Object?>{
        'index': index,
        'path': path,
        'mimeType': mimeType,
      };
}

final class StudyBackgroundTranscriptionSession {
  StudyBackgroundTranscriptionSession._({
    required Uri baseUri,
    required this.jobId,
    required this.grant,
    required this.expectedSegments,
    required this.statusPath,
  }) : _baseUri = baseUri;

  final Uri _baseUri;
  final String jobId;
  final String grant;
  final int expectedSegments;
  final String statusPath;

  final Map<int, String> _cache = <int, String>{};
  bool _cleaned = false;

  Future<String> awaitTranscript(int segmentIndex) async {
    final cached = _cache[segmentIndex];
    if (cached != null && cached.trim().isNotEmpty) {
      return cached;
    }

    final deadline = DateTime.now().add(const Duration(hours: 2));
    while (DateTime.now().isBefore(deadline)) {
      await _refresh();
      final ready = _cache[segmentIndex];
      if (ready != null && ready.trim().isNotEmpty) {
        return ready;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    throw TimeoutException(
      'study_background_transcription_segment_timeout_$segmentIndex',
    );
  }

  Future<void> _refresh() async {
    final response = await http.get(
      _baseUri.resolve(statusPath),
      headers: <String, String>{
        'Authorization': 'Study $grant',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError(
        'study_background_transcription_status_${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('study_background_status_invalid');
    }

    final raw = decoded['transcripts'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final index = item['segmentIndex'];
        final transcript = item['transcript'];
        if (index is num &&
            transcript is String &&
            transcript.trim().isNotEmpty) {
          _cache[index.toInt()] = transcript.trim();
        }
      }
    }

    debugPrint(
      '[StudyBackgroundTranscription] '
      'job=$jobId completed=${_cache.length}/$expectedSegments',
    );
  }

  Future<void> cleanup() async {
    if (_cleaned) return;
    _cleaned = true;

    try {
      await http.delete(
        _baseUri.resolve(statusPath),
        headers: <String, String>{
          'Authorization': 'Study $grant',
        },
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Server TTL cleanup remains the final privacy backstop.
    }
  }
}

final class StudyBackgroundTranscriptionCoordinator {
  StudyBackgroundTranscriptionCoordinator._();

  static const MethodChannel _channel =
      MethodChannel('medcases/study_background_transcription_v1');

  static final Uri _baseUri = Uri.parse(
    const String.fromEnvironment(
      'MEDCASES_AI_GATEWAY_BASE_URL',
      defaultValue: 'https://medcases-scw37.ondigitalocean.app',
    ),
  );

  static Future<StudyBackgroundTranscriptionSession?> tryStart({
    required String sourceId,
    required bool isEs,
    required List<StudyBackgroundSegmentSpec> segments,
  }) async {
    if (!(Platform.isIOS || Platform.isAndroid) || segments.isEmpty) {
      return null;
    }

    if (segments.length > 64) {
      return null;
    }

    final capabilities = await _capabilities();
    if (!capabilities) {
      debugPrint(
        '[StudyBackgroundTranscription] unavailable -> foreground fallback',
      );
      return null;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      return null;
    }

    final createResponse = await http
        .post(
          _baseUri.resolve('/api/ai/study/background-transcription/jobs'),
          headers: <String, String>{
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, Object?>{
            'sourceId': sourceId,
            'expectedSegments': segments.length,
            'locale': isEs ? 'es' : 'pt',
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (createResponse.statusCode != 201) {
      debugPrint(
        '[StudyBackgroundTranscription] '
        'create=${createResponse.statusCode} -> foreground fallback',
      );
      return null;
    }

    final decoded = jsonDecode(createResponse.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final jobId = decoded['jobId']?.toString() ?? '';
    final grant = decoded['grant']?.toString() ?? '';
    final uploadBasePath = decoded['uploadBasePath']?.toString() ?? '';
    final statusPath = decoded['statusPath']?.toString() ?? '';
    final expectedSegments =
        (decoded['expectedSegments'] as num?)?.toInt() ?? 0;

    if (jobId.isEmpty ||
        grant.isEmpty ||
        uploadBasePath.isEmpty ||
        statusPath.isEmpty ||
        expectedSegments != segments.length) {
      return null;
    }

    final uploadBaseUrl = _baseUri.resolve(uploadBasePath).toString();

    try {
      final enqueued = await _channel.invokeMethod<bool>(
        'enqueue',
        <String, Object?>{
          'jobId': jobId,
          'grant': grant,
          'uploadBaseUrl': uploadBaseUrl,
          'segments': <Map<String, Object?>>[
            for (final segment in segments) segment.toNativeMap(),
          ],
        },
      );

      if (enqueued != true) {
        return null;
      }
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint(
        '[StudyBackgroundTranscription] '
        'native=${error.code} -> foreground fallback',
      );
      return null;
    }

    debugPrint(
      '[StudyBackgroundTranscription] '
      'queued job=$jobId segments=${segments.length}/${segments.length}',
    );

    return StudyBackgroundTranscriptionSession._(
      baseUri: _baseUri,
      jobId: jobId,
      grant: grant,
      expectedSegments: expectedSegments,
      statusPath: statusPath,
    );
  }

  static Future<bool> _capabilities() async {
    try {
      final response = await http.get(
        _baseUri.resolve(
          '/api/ai/study/background-transcription/capabilities',
        ),
        headers: const <String, String>{
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> && decoded['enabled'] == true;
    } catch (_) {
      return false;
    }
  }
}
