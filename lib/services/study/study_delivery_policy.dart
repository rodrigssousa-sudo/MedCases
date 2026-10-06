import '../ai/safety/ai_stream_trace.dart';

/// Delivery decisions only; no clinical content, model or safety selection.
class StudyDeliveryPolicy {
  static bool bypassPrimaryForVolume({required bool isStudy, required int promptChars}) =>
      !isStudy && promptChars > 20000;

  /// Recover transient HTTP failures through the existing bounded recovery.
  /// Authentication, quota and clinical refusals never enter via this rule.
  static bool isAdditionalTechnicalFailure(String? code) =>
      const {'http_500', 'http_502', 'http_504'}.contains(code);

  /// Fixed metadata codes; never place a server error or user text in a log.
  static int fallbackReasonCode(String reason) => const {
    'global_timeout_free': 1,
    'study_invalid_terminal': 2,
    'study_incomplete_stream': 3,
    'timeout': 4,
    'network': 5,
    'http_503': 6,
    'http_429': 7,
    'http_400': 8,
    'http_404': 9,
    'stream_error': 10,
    'stream_exception': 11,
    'http_500': 12,
    'http_502': 13,
    'http_504': 14,
  }[reason] ?? 0;
  static void traceFallbackMetadata(Map<String, dynamic> body) {
    const errors = ['study_luna_timeout', 'study_luna_upstream_error',
      'study_luna_incomplete', 'study_luna_binding_invalid',
      'study_luna_schema_invalid', 'study_luna_records_invalid'];
    AiStreamTrace.mark('STUDY_LUNA_ERROR_CODE', errors.indexOf(body['error']) + 1);
    final timing = body['timing'];
    if (timing is! Map) return;
    const fields = {'firstCallMs': 'STUDY_LUNA_FIRST_CALL_MS',
      'correctionRetryMs': 'STUDY_LUNA_CORRECTION_MS',
      'totalFallbackMs': 'STUDY_LUNA_TOTAL_MS'};
    for (final entry in fields.entries) {
      final value = timing[entry.key];
      if (value is num && value.isFinite && value >= 0 && value <= 120000) {
        AiStreamTrace.mark(entry.value, value.toInt());
      }
    }
    AiStreamTrace.mark('STUDY_LUNA_COVERAGE_RETRY', timing['coverageRetryUsed'] == true ? 1 : 0);
  }
}
