import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Structured events for the Plantão pipeline QA canary.
///
/// The event surface intentionally accepts no prompt, response, patient,
/// medication, evidence, or arbitrary message fields.
enum PlantaoQaCutoverEvent {
  eligibilityAccepted,
  eligibilityRejected,
  pipelineStarted,
  executionRejectedWhileActive,
  legacyFallbackBeforeEvent,
  validationRejected,
  commitValidated,
  terminalCompleted,
  pipelineErrorBeforeEvent,
  pipelineErrorAfterEvent,
}

/// Closed set of reasons allowed in QA observability.
enum PlantaoQaCutoverReason {
  notPlantaoMode,
  unauthenticatedUid,
  uidNotAllowlisted,
  uidAllowlisted,
  cutoverAlreadyActive,
  fallbackBeforeFirstEvent,
  validationRejected,
  commitValidated,
  terminalCompleted,
  providerErrorBeforeFirstEvent,
  providerErrorAfterFirstEvent,
}

/// Compile-time QA allowlist and privacy-safe observability support.
///
/// No UID is embedded in source. The production default is an empty string:
///
/// `--dart-define=MEDCASES_PLANTAO_PIPELINE_QA_UIDS=uid1,uid2`
///
/// This support object does not activate the pipeline by itself. Wiring to the
/// public selector belongs to the next microphase.
final class PlantaoQaCutoverSupport {
  const PlantaoQaCutoverSupport({
    String rawUidAllowlist = const String.fromEnvironment(
      'MEDCASES_PLANTAO_PIPELINE_QA_UIDS',
      defaultValue: '',
    ),
  }) : _rawUidAllowlist = rawUidAllowlist;

  static const String component = 'plantao_pipeline_qa_cutover';

  final String _rawUidAllowlist;

  Set<String> get _allowlistedUids => UnmodifiableSetView<String>(
        _rawUidAllowlist
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet(),
      );

  bool get hasConfiguredUidAllowlist => _allowlistedUids.isNotEmpty;

  /// Eligibility requires both Plantão mode and an authenticated exact UID.
  ///
  /// Email, display name, locale, device identifiers and substring matching
  /// are intentionally unsupported.
  bool isEligible({
    required bool isPlantao,
    required String? authenticatedUid,
  }) {
    if (!isPlantao) {
      return false;
    }

    final normalizedUid = authenticatedUid?.trim();
    if (normalizedUid == null || normalizedUid.isEmpty) {
      return false;
    }

    return _allowlistedUids.contains(normalizedUid);
  }

  Map<String, Object?> buildEvent({
    required PlantaoQaCutoverEvent event,
    required PlantaoQaCutoverReason reason,
    required String? requestId,
    required String? sessionId,
  }) {
    return Map<String, Object?>.unmodifiable(
      <String, Object?>{
        'component': component,
        'event': event.name,
        'reason': reason.name,
        'mode': 'plantao',
        'requestId': _safeCorrelationId(requestId),
        'sessionId': _safeCorrelationId(sessionId),
      },
    );
  }

  void emit({
    required PlantaoQaCutoverEvent event,
    required PlantaoQaCutoverReason reason,
    required String? requestId,
    required String? sessionId,
  }) {
    final payload = buildEvent(
      event: event,
      reason: reason,
      requestId: requestId,
      sessionId: sessionId,
    );
    debugPrint('[PHASE3K_QA] ${jsonEncode(payload)}');
  }

  String? _safeCorrelationId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    const maxLength = 128;
    if (normalized.length <= maxLength) {
      return normalized;
    }

    return normalized.substring(0, maxLength);
  }
}
