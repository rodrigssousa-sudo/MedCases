'use strict';

/**
 * MedCases AI Control Plane V2
 * Server-derived protected clinical projection owner v1.
 *
 * SECURITY CONTRACT:
 * - Projection is derived exclusively on the server from request structure.
 * - No client-supplied projection or de-identification attestation is accepted.
 * - No raw user message, history text, patient field names or patient values are copied.
 * - No direct identifier detector output is persisted in the projection.
 * - Projection is metadata-only and therefore NOT sufficient, by itself, to grant
 *   live user-response authority. It exists to close the ownership/privacy gap
 *   while existing providers remain shadow/inert.
 * - Any schema/validation failure returns null (fail closed).
 */

const {
  validateProtectedClinicalProjectionV1,
} = require('./protected_clinical_data_policy_v1');

const OWNER_VERSION =
  'server_deidentified_clinical_projection_owner_v1';

const PROJECTION_VERSION =
  'protected_clinical_projection_v1';

const PROJECTION_SOURCE =
  'server_deidentified_v1';

function _isPlainObject(value) {
  return !!(
    value &&
    typeof value === 'object' &&
    !Array.isArray(value)
  );
}

function _clampInt(value, min, max) {
  const n = Number(value);
  if (!Number.isFinite(n)) {
    return min;
  }
  return Math.max(
    min,
    Math.min(
      max,
      Math.trunc(n)
    )
  );
}

function _safeUserMessageChars(userMessage) {
  return _clampInt(
    typeof userMessage === 'string'
      ? userMessage.length
      : 0,
    0,
    20000
  );
}

function _safeHistoryTurns(history) {
  return _clampInt(
    Array.isArray(history)
      ? history.length
      : 0,
    0,
    100
  );
}

function _safePatientContextFieldCount(patientContext) {
  return _clampInt(
    _isPlainObject(patientContext)
      ? Object.keys(patientContext).length
      : 0,
    0,
    200
  );
}

function _clinicalIntentTags({
  mode,
  patientContextFieldCount,
}) {
  const tags = [];

  if (
    typeof mode === 'string' &&
    ['plantao', 'plantão'].includes(
      mode.trim().toLowerCase()
    )
  ) {
    tags.push('acute_care');
  } else {
    tags.push('clinical_query');
  }

  if (patientContextFieldCount > 0) {
    tags.push('patient_context_present');
  }

  return Object.freeze(tags);
}

function _complexitySignals({
  userMessageChars,
  historyTurns,
  patientContextFieldCount,
}) {
  const signals = [];

  if (historyTurns >= 2) {
    signals.push('multi_turn_reasoning');
  }

  if (patientContextFieldCount > 0) {
    signals.push('structured_patient_context');
  }

  if (
    userMessageChars >= 800 ||
    historyTurns >= 6 ||
    patientContextFieldCount >= 8
  ) {
    signals.push('high_context_volume');
  }

  return Object.freeze(signals);
}

function buildServerDeidentifiedClinicalProjectionV1({
  mode = 'plantao',
  userMessage = '',
  history = [],
  patientContext = null,
} = {}) {
  const userMessageChars =
    _safeUserMessageChars(userMessage);

  const historyTurns =
    _safeHistoryTurns(history);

  const patientContextFieldCount =
    _safePatientContextFieldCount(
      patientContext
    );

  const projection = Object.freeze({
    version: PROJECTION_VERSION,
    source: PROJECTION_SOURCE,
    containsRawText: false,
    containsDirectIdentifiers: false,
    clinicalIntentTags:
      _clinicalIntentTags({
        mode,
        patientContextFieldCount,
      }),
    complexitySignals:
      _complexitySignals({
        userMessageChars,
        historyTurns,
        patientContextFieldCount,
      }),
    contextMetrics: Object.freeze({
      userMessageChars,
      historyTurns,
      patientContextFieldCount,
    }),
  });

  const validation =
    validateProtectedClinicalProjectionV1(
      projection
    );

  if (
    !validation ||
    validation.valid !== true
  ) {
    return null;
  }

  return projection;
}

module.exports = Object.freeze({
  OWNER_VERSION,
  PROJECTION_VERSION,
  PROJECTION_SOURCE,
  buildServerDeidentifiedClinicalProjectionV1,
});
