'use strict';

/**
 * Server-derived deidentified clinical fact projection owner v2.
 *
 * IMPORTANT:
 * - This is a privacy transform, not a legal Safe Harbor certification.
 * - It never accepts a client-supplied projection/attestation.
 * - It redacts common direct identifiers and excludes identifier-bearing
 *   structured fields before retaining clinical content.
 * - If residual direct-identifier risk is detected, it fails closed (null).
 * - Providers remain shadow/inert until a later executed authority build.
 */

const {
  validateProtectedClinicalProjectionV2,
} = require('./protected_clinical_data_policy_v2');

const OWNER_VERSION =
  'server_deidentified_clinical_fact_projection_owner_v2';

const PROJECTION_VERSION =
  'protected_clinical_fact_projection_v2';

const PROJECTION_SOURCE =
  'server_deidentified_v2';

const DEIDENTIFICATION_VERSION =
  'medcases_server_deidentification_v2';

const MAX_TEXT_CHARS = 12000;
const MAX_HISTORY_TURNS = 6;
const MAX_PATIENT_FIELDS = 80;

const SENSITIVE_KEY_RE =
  /(?:^|_)(?:name|nome|nombre|patientname|patient_name|email|mail|phone|telefone|telefono|mobile|whatsapp|cpf|cuit|cuil|dni|rg|passport|passaporte|document|documento|address|endereco|direccion|street|rua|calle|zip|postal|city|cidade|ciudad|state|province|country|birth|nascimento|nacimiento|dob|uid|userid|user_id|identifier|mrn|recordnumber|record_number|prontuario|prontuário|insurance|socialsecurity|social_security)(?:_|$)/i;

const EMAIL_RE =
  /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;

const URL_RE =
  /\b(?:https?:\/\/|www\.)\S+/gi;

const PHONE_RE =
  /(?:\+?\d[\d\s().-]{7,}\d)/g;

const DATE_RE =
  /\b(?:\d{1,2}[\/.-]\d{1,2}[\/.-](?:\d{2}|\d{4})|\d{4}[\/.-]\d{1,2}[\/.-]\d{1,2})\b/g;

const LONG_ID_RE =
  /\b(?=[A-Z0-9.-]{7,}\b)(?=[A-Z0-9.-]*\d{4,})[A-Z0-9.-]+\b/gi;

const LABELED_IDENTIFIER_RE =
  /\b(?:nome|nombre|name|paciente|patient|telefone|tel[eé]fono|phone|email|e-mail|cpf|dni|rg|passport|passaporte|documento|document|endere[cç]o|direcci[oó]n|address|mrn|prontu[aá]rio)\s*[:= -]+\s*[^,;\n]{2,80}/gi;

const TITLED_PERSON_RE =
  /\b(?:sr\.?|sra\.?|señor|señora|senhor|senhora|dr\.?|dra\.?)\s+[A-ZÁÉÍÓÚÃÕÇÑ][A-Za-zÁÉÍÓÚáéíóúÃÕãõÇçÑñ'-]+(?:\s+[A-ZÁÉÍÓÚÃÕÇÑ][A-Za-zÁÉÍÓÚáéíóúÃÕãõÇçÑñ'-]+){0,3}/g;

const LEADING_NAME_AGE_RE =
  /^[A-ZÁÉÍÓÚÃÕÇÑ][A-Za-zÁÉÍÓÚáéíóúÃÕãõÇçÑñ'-]+(?:\s+[A-ZÁÉÍÓÚÃÕÇÑ][A-Za-zÁÉÍÓÚáéíóúÃÕãõÇçÑñ'-]+){1,3},\s*(?=\d{1,3}\s*(?:anos|años|years?))/;

const RESIDUAL_DIRECT_LABEL_RE =
  /\b(?:nome|nombre|name|telefone|tel[eé]fono|phone|email|e-mail|cpf|dni|rg|passport|passaporte|documento|document|endere[cç]o|direcci[oó]n|address|mrn|prontu[aá]rio)\s*[:=]/i;

function _isPlainObject(value) {
  return !!(
    value &&
    typeof value === 'object' &&
    !Array.isArray(value)
  );
}

function _normalizeKey(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .toLowerCase()
    .replace(/^_+|_+$/g, '');
}

function _isSensitiveKey(key) {
  const normalized = _normalizeKey(key);

  if (!normalized) {
    return true;
  }

  if (SENSITIVE_KEY_RE.test(normalized)) {
    return true;
  }

  return [
    'id',
    'patient_id',
    'person_id',
    'account_id',
  ].includes(normalized);
}

function _redactDirectIdentifiers(value) {
  let text = String(value || '');

  text = text
    .replace(EMAIL_RE, '[REDACTED_EMAIL]')
    .replace(URL_RE, '[REDACTED_URL]')
    .replace(PHONE_RE, '[REDACTED_PHONE]')
    .replace(DATE_RE, '[REDACTED_DATE]')
    .replace(
      LABELED_IDENTIFIER_RE,
      '[REDACTED_IDENTIFIER]'
    )
    .replace(
      TITLED_PERSON_RE,
      '[REDACTED_PERSON]'
    )
    .replace(
      LEADING_NAME_AGE_RE,
      '[REDACTED_PERSON], '
    )
    .replace(
      LONG_ID_RE,
      '[REDACTED_ID]'
    );

  return text
    .replace(/\s+/g, ' ')
    .trim();
}

function _hasResidualDirectIdentifierRisk(text) {
  if (typeof text !== 'string') {
    return true;
  }

  EMAIL_RE.lastIndex = 0;
  URL_RE.lastIndex = 0;
  PHONE_RE.lastIndex = 0;
  DATE_RE.lastIndex = 0;
  LONG_ID_RE.lastIndex = 0;
  LABELED_IDENTIFIER_RE.lastIndex = 0;
  TITLED_PERSON_RE.lastIndex = 0;
  LEADING_NAME_AGE_RE.lastIndex = 0;

  return !!(
    EMAIL_RE.test(text) ||
    URL_RE.test(text) ||
    PHONE_RE.test(text) ||
    DATE_RE.test(text) ||
    LONG_ID_RE.test(text) ||
    LABELED_IDENTIFIER_RE.test(text) ||
    TITLED_PERSON_RE.test(text) ||
    LEADING_NAME_AGE_RE.test(text) ||
    RESIDUAL_DIRECT_LABEL_RE.test(text)
  );
}

function _safeAgeValue(value) {
  const n = Number(value);

  if (
    !Number.isFinite(n) ||
    n < 0
  ) {
    return null;
  }

  if (n >= 90) {
    return '90+';
  }

  return Math.round(n * 10) / 10;
}

function _safePrimitiveForClinicalField(
  key,
  value
) {
  const normalizedKey = _normalizeKey(key);

  if (
    normalizedKey === 'age' ||
    normalizedKey === 'idade' ||
    normalizedKey === 'edad'
  ) {
    return _safeAgeValue(value);
  }

  if (
    typeof value === 'number' &&
    Number.isFinite(value)
  ) {
    return value;
  }

  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'string') {
    const redacted =
      _redactDirectIdentifiers(value);

    if (
      !redacted ||
      _hasResidualDirectIdentifierRisk(
        redacted
      )
    ) {
      return null;
    }

    return redacted.slice(0, 500);
  }

  return null;
}

function _buildStructuredClinicalLines(
  patientContext
) {
  if (!_isPlainObject(patientContext)) {
    return [];
  }

  const lines = [];
  const keys = Object.keys(patientContext)
    .slice(0, MAX_PATIENT_FIELDS);

  for (const key of keys) {
    if (_isSensitiveKey(key)) {
      continue;
    }

    const value =
      _safePrimitiveForClinicalField(
        key,
        patientContext[key]
      );

    if (
      value === null ||
      value === ''
    ) {
      continue;
    }

    lines.push(
      _normalizeKey(key) +
      ': ' +
      String(value)
    );
  }

  return lines;
}

function _buildHistoryLines(history) {
  if (!Array.isArray(history)) {
    return [];
  }

  const lines = [];

  for (
    const turn of history.slice(-MAX_HISTORY_TURNS)
  ) {
    if (!_isPlainObject(turn)) {
      continue;
    }

    const role =
      turn.role === 'model' ||
      turn.role === 'assistant'
        ? 'assistant'
        : (
          turn.role === 'user'
            ? 'user'
            : null
        );

    if (!role) {
      continue;
    }

    const raw =
      typeof turn.content === 'string'
        ? turn.content
        : (
          typeof turn.text === 'string'
            ? turn.text
            : ''
        );

    const redacted =
      _redactDirectIdentifiers(raw);

    if (
      !redacted ||
      _hasResidualDirectIdentifierRisk(
        redacted
      )
    ) {
      continue;
    }

    lines.push(
      role + ': ' + redacted.slice(0, 1800)
    );
  }

  return lines;
}

function _buildClinicalText({
  userMessage,
  history,
  patientContext,
}) {
  const sections = [];

  const current =
    _redactDirectIdentifiers(
      typeof userMessage === 'string'
        ? userMessage
        : ''
    );

  if (
    current &&
    !_hasResidualDirectIdentifierRisk(
      current
    )
  ) {
    sections.push(
      'current_query: ' +
      current.slice(0, 5000)
    );
  }

  const historyLines =
    _buildHistoryLines(history);

  if (historyLines.length > 0) {
    sections.push(
      'recent_context:\n' +
      historyLines.join('\n')
    );
  }

  const structuredLines =
    _buildStructuredClinicalLines(
      patientContext
    );

  if (structuredLines.length > 0) {
    sections.push(
      'structured_clinical_context:\n' +
      structuredLines.join('\n')
    );
  }

  const text = sections
    .join('\n\n')
    .slice(0, MAX_TEXT_CHARS)
    .trim();

  if (
    !text ||
    _hasResidualDirectIdentifierRisk(text)
  ) {
    return null;
  }

  return text;
}

function _contextMetrics({
  userMessage,
  history,
  patientContext,
}) {
  return Object.freeze({
    userMessageChars:
      Math.min(
        20000,
        typeof userMessage === 'string'
          ? userMessage.length
          : 0
      ),
    historyTurns:
      Math.min(
        100,
        Array.isArray(history)
          ? history.length
          : 0
      ),
    patientContextFieldCount:
      Math.min(
        200,
        _isPlainObject(patientContext)
          ? Object.keys(patientContext).length
          : 0
      ),
  });
}

function _clinicalIntentTags({
  mode,
  patientContext,
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

  if (
    _isPlainObject(patientContext) &&
    Object.keys(patientContext).length > 0
  ) {
    tags.push('patient_context_present');
  }

  return Object.freeze(tags);
}

function _complexitySignals({
  userMessage,
  history,
  patientContext,
}) {
  const signals = [];

  if (
    Array.isArray(history) &&
    history.length >= 2
  ) {
    signals.push('multi_turn_reasoning');
  }

  if (
    _isPlainObject(patientContext) &&
    Object.keys(patientContext).length > 0
  ) {
    signals.push('structured_patient_context');
  }

  if (
    (
      typeof userMessage === 'string' &&
      userMessage.length >= 800
    ) ||
    (
      Array.isArray(history) &&
      history.length >= 6
    )
  ) {
    signals.push('high_context_volume');
  }

  return Object.freeze(signals);
}

function buildServerDeidentifiedClinicalFactProjectionV2({
  mode = 'plantao',
  userMessage = '',
  history = [],
  patientContext = null,
} = {}) {
  const deidentifiedClinicalText =
    _buildClinicalText({
      userMessage,
      history,
      patientContext,
    });

  if (!deidentifiedClinicalText) {
    return null;
  }

  const projection = Object.freeze({
    version: PROJECTION_VERSION,
    source: PROJECTION_SOURCE,
    deidentificationVersion:
      DEIDENTIFICATION_VERSION,
    containsRawText: false,
    containsDirectIdentifiers: false,
    deidentifiedClinicalText,
    clinicalIntentTags:
      _clinicalIntentTags({
        mode,
        patientContext,
      }),
    complexitySignals:
      _complexitySignals({
        userMessage,
        history,
        patientContext,
      }),
    contextMetrics:
      _contextMetrics({
        userMessage,
        history,
        patientContext,
      }),
  });

  const validation =
    validateProtectedClinicalProjectionV2(
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
  DEIDENTIFICATION_VERSION,
  buildServerDeidentifiedClinicalFactProjectionV2,
});
