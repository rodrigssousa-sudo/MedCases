import 'dart:async';
import 'dart:io';

/// Safe codes only: never retain a provider body, token or patient content.
class TranscriptionFailure implements Exception {
  static const providerBlockedCode = 'ASSEMBLYAI_PHI_PRODUCTION_BLOCKED';
  static String unavailableMessage({required bool isEs}) => isEs
      ? 'La transcripción no está disponible para esta cuenta en este momento. Tu audio está guardado.'
      : 'A transcrição não está disponível para esta conta neste momento. Seu áudio está salvo.';
  const TranscriptionFailure(this.code, {this.retryable = true});
  final String code;
  final bool retryable;
  @override
  String toString() => code;
  static TranscriptionFailure classify(Object error) {
    if (error is TranscriptionFailure) return error;
    if (error is StateError &&
        {
          'TRANSCRIPTION_LIMIT_REACHED',
          'RATE_LIMITED',
          'CONCURRENT_RESERVATION_LIMIT',
          'MONTHLY_USAGE_LIMIT'
        }.contains(error.message))
      return TranscriptionFailure(error.message.toString());
    if (error is SocketException)
      return const TranscriptionFailure('NETWORK_FAILURE');
    if (error is TimeoutException) return const TranscriptionFailure('TIMEOUT');
    final text = error.toString().toLowerCase();
    if (text.contains('owner_changed') || text.contains('user_changed'))
      return const TranscriptionFailure('USER_CHANGED', retryable: false);
    if (text.contains('audio_missing') ||
        text.contains('empty_segment') ||
        text.contains('file_empty'))
      return const TranscriptionFailure('INVALID_AUDIO', retryable: false);
    if (text.contains('401') ||
        text.contains('403') ||
        text.contains('reauth') ||
        text.contains('reservation'))
      return const TranscriptionFailure('AUTH_FAILURE');
    if (text.contains('404'))
      return const TranscriptionFailure('JOB_NOT_FOUND');
    if (text.contains('native') || text.contains('plugin'))
      return const TranscriptionFailure('NATIVE_UPLOAD_FAILURE');
    return const TranscriptionFailure('SERVER_FAILURE');
  }
}

/// An unchanged 200 response is not progress. No unbounded spinner or polling.
class TranscriptionProgressWatch {
  TranscriptionProgressWatch(
      {DateTime Function()? now,
      this.noProgressLimit = const Duration(seconds: 90)})
      : now = now ?? DateTime.now {
    lastProgressAt = this.now();
  }
  final DateTime Function() now;
  final Duration noProgressLimit;
  late DateTime lastProgressAt;
  String? _fingerprint;
  int retryCount = 0;
  int lastCompletedSegmentCount = 0;
  String currentStage = 'queued';
  void observe(String fingerprint,
      {required int completed, required String stage}) {
    if (_fingerprint != fingerprint) {
      _fingerprint = fingerprint;
      lastProgressAt = now();
      retryCount = 0;
    }
    lastCompletedSegmentCount = completed;
    currentStage = stage;
  }

  bool get stalled => now().difference(lastProgressAt) >= noProgressLimit;
  Duration nextDelay() {
    const seconds = [2, 4, 8, 16, 30];
    return Duration(
        seconds: seconds[(retryCount++).clamp(0, seconds.length - 1)]);
  }
}

/// Numeric timing only. Event names are allowlisted and never carry content.
void markTranscriptionTime(Map<String, dynamic> job, String event,
    {int? segment}) {
  if (!RegExp(r'^T(?:[0-9]|1[0-4])$').hasMatch(event))
    throw ArgumentError('timing event');
  final timings = Map<String, dynamic>.from(job['timings'] ?? {});
  final key = segment == null ? event : '$event.$segment';
  timings[key] = DateTime.now().toUtc().millisecondsSinceEpoch;
  job['timings'] = timings;
}

String? safeTranscriptionServerCode(Object? value) {
  if (value is! String) return null;
  const allowed = {
    'TRANSCRIPTION_LIMIT_REACHED',
    'RATE_LIMITED',
    'CONCURRENT_RESERVATION_LIMIT',
    'MONTHLY_USAGE_LIMIT',
    TranscriptionFailure.providerBlockedCode,
    'TRANSCRIPTION_UNAVAILABLE',
    'JOB_CREATE_FAILED',
    'EXECUTION_RESULT_UNAVAILABLE',
    'INVALID_AUDIO',
    'UPSTREAM_RESULT_UNAVAILABLE',
    'UPLOAD_PROCESSING_FAILED',
    'AUTH_FAILURE',
    'JOB_NOT_FOUND',
    'SERVER_FAILURE',
    'NATIVE_UPLOAD_FAILURE',
    'MEDIA_PROOF_FAILED',
    'UPLOAD_STALLED',
    'QUOTA_RESERVATION_FAILED',
    'TRANSCRIPT_PERSIST_FAILED',
    'ACCOUNTING_FINALIZATION_FAILED',
    'WORKER_FAILURE'
  };
  return allowed.contains(value) ||
          RegExp(r'^OPENAI_TRANSCRIPTION_[1-5][0-9]{2}$').hasMatch(value)
      ? value
      : null;
}
