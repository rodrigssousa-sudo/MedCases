'use strict';

/**
 * MedCases protected clinical data policy compatibility layer v2.
 *
 * Keeps v1 projections valid while adding a strict server-generated
 * deidentified clinical-fact projection v2.
 */

const base =
  require('./protected_clinical_data_policy_v1');

const PROJECTION_V2 =
  'protected_clinical_fact_projection_v2';

const PROJECTION_V2_SOURCE =
  'server_deidentified_v2';

const DEIDENTIFICATION_VERSION =
  'medcases_server_deidentification_v2';

const V2_ALLOWED_KEYS = Object.freeze([
  'version',
  'source',
  'deidentificationVersion',
  'containsRawText',
  'containsDirectIdentifiers',
  'deidentifiedClinicalText',
  'clinicalIntentTags',
  'complexitySignals',
  'contextMetrics',
]);

const SAFE_TAG_RE =
  /^[a-z0-9][a-z0-9_.:-]{0,63}$/;

const EMAIL_RE =
  /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i;

const URL_RE =
  /\b(?:https?:\/\/|www\.)\S+/i;

const PHONE_RE =
  /(?:\+?\d[\d\s().-]{7,}\d)/;

const DIRECT_LABEL_RE =
  /\b(?:nome|nombre|name|telefone|tel[eé]fono|phone|email|e-mail|cpf|dni|rg|passport|passaporte|documento|document|endere[cç]o|direcci[oó]n|address|mrn|prontu[aá]rio)\s*[:=]/i;

function _isPlainObject(value) {
  return !!(
    value &&
    typeof value === 'object' &&
    !Array.isArray(value)
  );
}

function _safeTagArray(value) {
  return (
    Array.isArray(value) &&
    value.length <= 64 &&
    value.every(
      (item) =>
        typeof item === 'string' &&
        SAFE_TAG_RE.test(item)
    )
  );
}

function _safeContextMetrics(value) {
  if (!_isPlainObject(value)) {
    return false;
  }

  const keys = Object.keys(value).sort();
  const expected = [
    'historyTurns',
    'patientContextFieldCount',
    'userMessageChars',
  ];

  if (
    JSON.stringify(keys) !==
    JSON.stringify(expected)
  ) {
    return false;
  }

  return expected.every((key) => {
    const n = Number(value[key]);
    return (
      Number.isInteger(n) &&
      n >= 0 &&
      n <= 20000
    );
  });
}

function _containsResidualDirectIdentifier(text) {
  if (typeof text !== 'string') {
    return true;
  }

  return !!(
    EMAIL_RE.test(text) ||
    URL_RE.test(text) ||
    PHONE_RE.test(text) ||
    DIRECT_LABEL_RE.test(text)
  );
}

function validateProtectedClinicalProjectionV2(
  projection
) {
  if (!_isPlainObject(projection)) {
    return Object.freeze({
      valid: false,
      reason: 'projection_not_object',
    });
  }

  const keys = Object.keys(projection).sort();
  const expected = [...V2_ALLOWED_KEYS].sort();

  if (
    JSON.stringify(keys) !==
    JSON.stringify(expected)
  ) {
    return Object.freeze({
      valid: false,
      reason: 'projection_unexpected_keys',
    });
  }

  if (
    projection.version !== PROJECTION_V2 ||
    projection.source !== PROJECTION_V2_SOURCE ||
    projection.deidentificationVersion !==
      DEIDENTIFICATION_VERSION ||
    projection.containsRawText !== false ||
    projection.containsDirectIdentifiers !== false
  ) {
    return Object.freeze({
      valid: false,
      reason: 'projection_attestation_invalid',
    });
  }

  if (
    typeof projection.deidentifiedClinicalText !==
      'string' ||
    projection.deidentifiedClinicalText.length < 1 ||
    projection.deidentifiedClinicalText.length > 16000
  ) {
    return Object.freeze({
      valid: false,
      reason: 'projection_clinical_text_invalid',
    });
  }

  if (
    _containsResidualDirectIdentifier(
      projection.deidentifiedClinicalText
    )
  ) {
    return Object.freeze({
      valid: false,
      reason:
        'projection_residual_direct_identifier_risk',
    });
  }

  if (
    !_safeTagArray(projection.clinicalIntentTags) ||
    !_safeTagArray(projection.complexitySignals) ||
    !_safeContextMetrics(projection.contextMetrics)
  ) {
    return Object.freeze({
      valid: false,
      reason: 'projection_metadata_invalid',
    });
  }

  return Object.freeze({
    valid: true,
    reason: 'valid_v2',
  });
}

function validateProtectedClinicalProjectionV1(
  projection
) {
  if (
    projection &&
    projection.version === PROJECTION_V2
  ) {
    return validateProtectedClinicalProjectionV2(
      projection
    );
  }

  return base.validateProtectedClinicalProjectionV1(
    projection
  );
}

function _v2ToV1MetadataProjection(projection) {
  return Object.freeze({
    version: 'protected_clinical_projection_v1',
    source: 'server_deidentified_v1',
    containsRawText: false,
    containsDirectIdentifiers: false,
    clinicalIntentTags:
      projection.clinicalIntentTags,
    complexitySignals:
      projection.complexitySignals,
    contextMetrics:
      projection.contextMetrics,
  });
}

function evaluateProtectedClinicalProviderGate({
  patientContext = null,
  providerDataPolicy = null,
  protectedClinicalProjection = null,
} = {}) {
  if (
    protectedClinicalProjection &&
    protectedClinicalProjection.version ===
      PROJECTION_V2
  ) {
    const validation =
      validateProtectedClinicalProjectionV2(
        protectedClinicalProjection
      );

    if (!validation.valid) {
      return Object.freeze({
        allowed: false,
        useProtectedProjection: false,
        reason: validation.reason,
      });
    }

    const baseGate =
      base.evaluateProtectedClinicalProviderGate({
        patientContext,
        providerDataPolicy,
        protectedClinicalProjection:
          _v2ToV1MetadataProjection(
            protectedClinicalProjection
          ),
      });

    if (
      !baseGate ||
      baseGate.allowed !== true
    ) {
      return baseGate;
    }

    return Object.freeze({
      ...baseGate,
      allowed: true,
      useProtectedProjection: true,
      projectionVersion: PROJECTION_V2,
    });
  }

  return base.evaluateProtectedClinicalProviderGate({
    patientContext,
    providerDataPolicy,
    protectedClinicalProjection,
  });
}

function buildProtectedClinicalRouterInputV1(
  projection
) {
  if (
    projection &&
    projection.version === PROJECTION_V2
  ) {
    const validation =
      validateProtectedClinicalProjectionV2(
        projection
      );

    if (!validation.valid) {
      return '';
    }

    return [
      'MEDCASES_PROTECTED_CLINICAL_INPUT_V2',
      'The following content was deidentified server-side.',
      'Do not infer or reconstruct identifying information.',
      '',
      'Clinical content:',
      projection.deidentifiedClinicalText,
      '',
      'Clinical intent tags:',
      JSON.stringify(
        projection.clinicalIntentTags
      ),
      'Complexity signals:',
      JSON.stringify(
        projection.complexitySignals
      ),
      'Context metrics:',
      JSON.stringify(
        projection.contextMetrics
      ),
    ].join('\n');
  }

  return base.buildProtectedClinicalRouterInputV1(
    projection
  );
}

function buildProtectedClinicalRouterInputSafeV2(
  projection
) {
  try {
    const value =
      buildProtectedClinicalRouterInputV1(
        projection
      );

    return (
      typeof value === 'string' &&
      value.length > 0
    )
      ? value
      : null;
  } catch (_) {
    return null;
  }
}

module.exports = Object.freeze({
  ...base,
  PROJECTION_V2,
  PROJECTION_V2_SOURCE,
  DEIDENTIFICATION_VERSION,
  validateProtectedClinicalProjectionV2,
  validateProtectedClinicalProjectionV1,
  evaluateProtectedClinicalProviderGate,
  buildProtectedClinicalRouterInputV1,
  buildProtectedClinicalRouterInputSafeV2,
});
