import '../canonical_catalog_cipher.dart' show catalogUidHash;
import 'dart:async';
import '../audio/transcription_diagnostics.dart';
import '../monthly_usage_ledger.dart';
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
    required this.usageReservation,
    this.singleAudio = false,
  }) : _baseUri = baseUri;

  final bool singleAudio;
  String? _remoteState;
  final Uri _baseUri;
  final String jobId;
  final String grant;
  final int expectedSegments;
  final String statusPath;
  final UsageReservation usageReservation;

  final Map<int, String> _cache = <int, String>{};
  bool _cleaned = false;

  Future<String> awaitTranscript(
    int segmentIndex, {
    Future<void> Function(Map<String, dynamic>)? onProgress,
    void Function()? ensureActive,
  }) async {
    final watch = TranscriptionProgressWatch();
    while (true) {
      ensureActive?.call();
      if (!usageReservation.authorizes(UsageKind.transcription))
        throw const TranscriptionFailure('USER_CHANGED', retryable: false);
      try {
        await _refresh();
        ensureActive?.call();
        final ready = _cache[segmentIndex];
        if (ready != null &&
            ready.trim().isNotEmpty &&
            (!singleAudio || _remoteState == 'completed')) return ready;
        final native =
            await StudyBackgroundTranscriptionCoordinator.diagnostics(
                jobId, segmentIndex);
        final server = _segmentStates[segmentIndex] ?? <String, dynamic>{};
        final stage =
            (server['state'] ?? native['state'] ?? 'queued').toString();
        watch.observe('${_cache.length}:$stage:${native['bytesSent'] ?? 0}',
            completed: _cache.length, stage: stage);
        await onProgress?.call({
          'currentStage': stage,
          'statusHttp': lastStatusHttp,
          'segmentsExpected': expectedSegments,
          'segmentsTranscribed': _cache.length,
          'lastProgressAt': watch.lastProgressAt.toUtc().millisecondsSinceEpoch,
          'lastCompletedSegmentCount': _cache.length,
          'retryCount': watch.retryCount,
          'transport': native,
          'serverTimings': server['timings'],
        });
        if (stage == 'failed') {
          final status = native['httpStatus'] as num? ?? 0;
          final code = safeTranscriptionServerCode(server['errorCategory']) ??
              (status == 401 || status == 403
                  ? 'AUTH_FAILURE'
                  : status == 404
                      ? 'JOB_NOT_FOUND'
                      : status >= 500
                          ? 'SERVER_FAILURE'
                          : 'NATIVE_UPLOAD_FAILURE');
          throw TranscriptionFailure(code,
              retryable: server['retryable'] != false);
        }
      } catch (error) {
        final failure = TranscriptionFailure.classify(error);
        if (!failure.retryable ||
            !{'NETWORK_FAILURE', 'TIMEOUT'}.contains(failure.code)) rethrow;
        if (watch.stalled) throw failure;
      }
      if (watch.stalled) {
        if (singleAudio &&
            {'submitted', 'processing', 'persisting'}.contains(_remoteState)) {
          throw const TranscriptionFailure('REMOTE_PROCESSING_PENDING');
        }
        throw const TranscriptionFailure('NO_PROGRESS');
      }
      await Future<void>.delayed(watch.nextDelay());
    }
  }

  final Map<int, Map<String, dynamic>> _segmentStates = {};
  int? lastStatusHttp;
  Future<void> _refresh() async {
    final response = await http.get(
      _baseUri.resolve(statusPath),
      headers: <String, String>{
        'Authorization': 'Study $grant',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 20));

    lastStatusHttp = response.statusCode;
    if (response.statusCode != 200) {
      throw StateError(
        'study_background_transcription_status_${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('study_background_status_invalid');
    }

    _remoteState =
        decoded['state'] is String ? decoded['state'] as String : null;
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

    final states = decoded['segments'];
    if (states is List) {
      for (final item in states) {
        if (item is Map && item['segmentIndex'] is num) {
          _segmentStates[(item['segmentIndex'] as num).toInt()] =
              Map<String, dynamic>.from(item);
        }
      }
    }
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

  static Future<void> cleanupDeletedJob(
      Map<String, dynamic> job, String uid, String sid) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid ||
        job['ownerUid'] != uid ||
        job['sourceId'] != sid) {
      throw StateError('TRANSCRIPTION_JOB_IDENTITY_MISMATCH');
    }
    final id = job['jobId'];
    if (id is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        job['statusPath'] !=
            '/api/ai/study/background-transcription/jobs/$id') {
      throw StateError('TRANSCRIPTION_JOB_PATH_MISMATCH');
    }
    try {
      await _channel.invokeMethod(
          'cancel', {'jobId': id}).timeout(const Duration(seconds: 2));
    } catch (_) {}
    await http.delete(_baseUri.resolve(job['statusPath']), headers: {
      'Authorization': 'Study ${job['grant']}'
    }).timeout(const Duration(seconds: 3));
  }

  static Future<StudyBackgroundTranscriptionSession?> tryStart({
    required String sourceId,
    required bool isEs,
    String? attemptId,
    int? rangeStartFrame,
    int? rangeEndFrame,
    int? rangeTotalFrames,
    int? rangeSampleRate,
    String? originalSha256,
    bool singleAudio = false,
    bool requireDurable = false,
    required List<StudyBackgroundSegmentSpec> segments,
    required UsageReservation usageReservation,
    Map<String, dynamic>? existingJob,
    Future<void> Function(Map<String, dynamic>)? onCreated,
  }) async {
    if (!usageReservation.authorizes(UsageKind.transcription))
      throw StateError('TRANSCRIPTION_QUOTA_REQUIRED');
    if (!(Platform.isIOS || Platform.isAndroid) || segments.isEmpty) {
      if (requireDurable)
        throw const TranscriptionFailure('NATIVE_UPLOAD_FAILURE');
      return null;
    }

    if (segments.length > 64) {
      if (requireDurable)
        throw const TranscriptionFailure('INVALID_AUDIO', retryable: false);
      return null;
    }

    final capabilities =
        existingJob != null || await _capabilities(singleAudio: singleAudio);
    if (!capabilities) {
      if (requireDurable) {
        throw const TranscriptionFailure('SERVER_FAILURE', retryable: true);
      }
      debugPrint(
        '[StudyBackgroundTranscription] unavailable -> foreground fallback',
      );
      return null;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (requireDurable) throw const TranscriptionFailure('AUTH_FAILURE');
      return null;
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      if (existingJob != null || requireDurable)
        throw StateError('TRANSCRIPTION_REAUTH_REQUIRED');
      return null;
    }

    if (existingJob != null) {
      if (existingJob['ownerUid'] != user.uid ||
          existingJob['sourceId'] != sourceId ||
          existingJob['expectedSegments'] != segments.length) {
        throw StateError('TRANSCRIPTION_JOB_IDENTITY_MISMATCH');
      }
      final recovered = StudyBackgroundTranscriptionSession._(
          baseUri: _baseUri,
          singleAudio: singleAudio,
          jobId: existingJob['jobId'],
          grant: existingJob['grant'],
          expectedSegments: segments.length,
          statusPath: existingJob['statusPath'],
          usageReservation: usageReservation);
      if (recovered.statusPath !=
          '/api/ai/study/background-transcription/jobs/${recovered.jobId}') {
        throw StateError('TRANSCRIPTION_JOB_PATH_MISMATCH');
      }
      // Explicit continuation wakes only a suspended worker. The request ID is
      // saved before the network call so an uncertain response is replay-safe.
      final retryRequestId = existingJob['retryRequestId'] as String? ??
          'retry-${DateTime.now().microsecondsSinceEpoch}';
      await onCreated?.call({...existingJob, 'retryRequestId': retryRequestId});
      final retryResponse = await http
          .post(
            _baseUri.resolve('${recovered.statusPath}/retry'),
            headers: {
              'Authorization': 'Study ${recovered.grant}',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({'requestId': retryRequestId}),
          )
          .timeout(const Duration(seconds: 20));
      // Older servers do not expose this endpoint; their existing polling path
      // remains compatible. Other failures must not enqueue a second job.
      if (retryResponse.statusCode != 200 && retryResponse.statusCode != 404) {
        throw const TranscriptionFailure('SERVER_FAILURE');
      }
      await onCreated?.call({...existingJob, 'retryRequestId': null});
      // Reuse the same server job and skip already completed segments.
      await recovered._refresh();
      for (final state in recovered._segmentStates.values) {
        if (state['state'] == 'failed' && state['retryable'] == false)
          throw TranscriptionFailure(
              safeTranscriptionServerCode(state['errorCategory']) ??
                  'EXECUTION_RESULT_UNAVAILABLE',
              retryable: false);
      }
      final missing = segments
          .where((segment) =>
              !recovered._cache.containsKey(segment.index) &&
              recovered._segmentStates[segment.index]?['hasDurableAudio'] !=
                  true)
          .toList();
      if (missing.isNotEmpty) {
        final enqueued = await _channel.invokeMethod<bool>('enqueue', {
          'jobId': recovered.jobId,
          'grant': recovered.grant,
          'uploadBaseUrl': _baseUri
              .resolve(
                  '/api/ai/study/background-transcription/jobs/${recovered.jobId}/segments')
              .toString(),
          'segments': missing.map((segment) => segment.toNativeMap()).toList(),
        });
        if (enqueued != true)
          throw StateError('TRANSCRIPTION_NATIVE_ENQUEUE_FAILED');
      }
      return recovered;
    }

    final createResponse = await http
        .post(
          _baseUri.resolve('/api/ai/study/background-transcription/jobs'),
          headers: <String, String>{
            'Authorization': 'Bearer $idToken',
            ...usageReservation.serverHeaders,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(<String, Object?>{
            'sourceId': sourceId,
            if (singleAudio) 'singleAudio': true,
            if (rangeStartFrame != null) ...{
              'rangeStartFrame': rangeStartFrame,
              'rangeEndFrame': rangeEndFrame,
              'rangeTotalFrames': rangeTotalFrames,
              'rangeSampleRate': rangeSampleRate,
              'originalSha256': originalSha256,
            },
            if (attemptId != null) 'attemptId': attemptId,
            'expectedSegments': segments.length,
            'locale': isEs ? 'es' : 'pt',
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (createResponse.statusCode != 201) {
      // An ambiguous create response must not start a second provider path.
      Map<String, dynamic> failure = {};
      try {
        final body = jsonDecode(createResponse.body);
        if (body is Map<String, dynamic>) failure = body;
      } catch (_) {}
      final code = safeTranscriptionServerCode(failure['code']);
      throw TranscriptionFailure(
          code ?? 'JOB_CREATE_HTTP_${createResponse.statusCode}',
          retryable: code != TranscriptionFailure.providerBlockedCode &&
              failure['retryable'] != false &&
              (createResponse.statusCode >= 500 ||
                  createResponse.statusCode == 429));
    }

    final decoded = jsonDecode(createResponse.body);
    if (decoded is! Map<String, dynamic>) {
      throw const TranscriptionFailure('JOB_CREATE_PROTOCOL_FAILURE');
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
      throw const TranscriptionFailure('JOB_CREATE_PROTOCOL_FAILURE');
    }

    await onCreated?.call({
      'jobCreateHttp': createResponse.statusCode,
      'ownerUid': user.uid,
      'sourceId': sourceId,
      'jobId': jobId,
      'grant': grant,
      'expectedSegments': expectedSegments,
      'statusPath': statusPath,
      'uploadBasePath': uploadBasePath,
    });

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
        throw StateError('TRANSCRIPTION_NATIVE_ENQUEUE_FAILED');
      }
    } on MissingPluginException {
      rethrow;
    } on PlatformException catch (error) {
      debugPrint(
        '[StudyBackgroundTranscription] '
        'native=${error.code} enqueue failed',
      );
      rethrow;
    }

    debugPrint(
      '[StudyBackgroundTranscription] '
      'queued jobHash=${catalogUidHash(jobId).substring(0, 12)} segments=${segments.length}',
    );

    return StudyBackgroundTranscriptionSession._(
      usageReservation: usageReservation,
      singleAudio: singleAudio,
      baseUri: _baseUri,
      jobId: jobId,
      grant: grant,
      expectedSegments: expectedSegments,
      statusPath: statusPath,
    );
  }

  static Future<Map<String, dynamic>> diagnostics(
      String jobId, int index) async {
    try {
      final value = await _channel.invokeMapMethod<String, dynamic>(
          'diagnostics', {'jobId': jobId, 'index': index});
      return value ?? {};
    } on MissingPluginException {
      return {};
    } on PlatformException {
      return {};
    }
  }

  static Future<bool> _capabilities({bool singleAudio = false}) async {
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
      return decoded is Map<String, dynamic> &&
          decoded['enabled'] == true &&
          (!singleAudio || decoded['singleAudioVersion'] == 1);
    } catch (_) {
      return false;
    }
  }
}
