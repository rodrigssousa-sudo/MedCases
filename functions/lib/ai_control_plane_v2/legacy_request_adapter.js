'use strict';

/**
 * Adapter for already-installed MedCases clients that still send the V1
 * geminiPaidProxy payload.
 *
 * The adapter deliberately IGNORES client provider/model/tier/temperature
 * routing hints. They can remain accepted by the legacy endpoint during
 * migration, but they never become V2 routing authority.
 */

const {
  MODES,
  TASKS,
  normalizeCapabilityRequest,
} = require('./contract');

function _string(value) {
  return typeof value === 'string' ? value : '';
}

function _normalizeMode(rawMode) {
  const value = _string(rawMode).trim().toLowerCase();

  if (value === 'study' || value === 'estudo') {
    return MODES.STUDY;
  }

  if (
    value === 'plantao' ||
    value === 'plantão' ||
    value === 'guardia' ||
    value === 'guardião'
  ) {
    return MODES.PLANTAO;
  }

  return '';
}

function _normalizeLocale(rawLang) {
  const value = _string(rawLang).trim().toLowerCase();

  if (value === 'pt' || value.startsWith('pt-')) {
    return 'pt-BR';
  }

  if (value === 'es' || value.startsWith('es-')) {
    return 'es';
  }

  return '';
}

function _sanitizeHistory(rawHistory) {
  if (!Array.isArray(rawHistory)) {
    return [];
  }

  return rawHistory
    .slice(-8)
    .filter((turn) => turn && typeof turn === 'object')
    .map((turn) => ({
      role: _string(turn.role),
      content: _string(turn.content),
    }))
    .filter(
      (turn) =>
        (turn.role === 'user' ||
          turn.role === 'model' ||
          turn.role === 'assistant') &&
        turn.content.length > 0
    );
}

function _defaultTaskForMode(mode) {
  return mode === MODES.STUDY
    ? TASKS.CLINICAL_QUESTION
    : TASKS.CLINICAL_REASONING;
}

function _hasLegacyRoutingHints(body) {
  return [
    'provider',
    'model',
    'model_tier',
    'tier',
    'temperature',
  ].some((key) => Object.hasOwn(body, key));
}

function adaptLegacyGeminiPaidProxyRequest(rawBody) {
  const body =
    rawBody && typeof rawBody === 'object'
      ? rawBody
      : {};

  const mode = _normalizeMode(body.mode);

  if (!mode) {
    return Object.freeze({
      ok: false,
      errorCode: 'unsupported_legacy_mode',
      request: null,
      metadata: Object.freeze({
        sourceContract: 'geminiPaidProxy-v1',
        ignoredClientRoutingHints: _hasLegacyRoutingHints(body),
      }),
    });
  }

  const userMessage = _string(body.userMessage).trim();
  if (!userMessage) {
    return Object.freeze({
      ok: false,
      errorCode: 'legacy_user_message_missing',
      request: null,
      metadata: Object.freeze({
        sourceContract: 'geminiPaidProxy-v1',
        ignoredClientRoutingHints: _hasLegacyRoutingHints(body),
      }),
    });
  }

  const conversationId =
    _string(body.conversation_id) ||
    _string(body.conversationId);

  const clinicalThreadId =
    _string(body.clinical_thread_id) ||
    _string(body.clinicalThreadId);

  const adapted = normalizeCapabilityRequest({
    mode,
    task:
      typeof body.task === 'string' && body.task.trim()
        ? body.task.trim()
        : _defaultTaskForMode(mode),
    locale: _normalizeLocale(body.lang || body.locale),
    conversation_id: conversationId,
    clinical_thread_id: clinicalThreadId,
    same_topic:
      body.same_topic === true ||
      body.sameTopic === true,
    contextual_followup:
      body.contextual_followup === true ||
      body.contextualFollowup === true,
    context_flags: {
      legacy_client: true,
      source_contract: 'geminiPaidProxy-v1',
      patient_context_present:
        body.patientContext != null ||
        body.patient_context != null,
      sensitive_clinical_context_declared:
        body.sensitiveClinicalContext === true ||
        body.sensitive_clinical_context === true,
    },
    input: {
      user_message: userMessage,
      system_prompt: _string(body.systemPrompt),
      history: _sanitizeHistory(body.history),
      max_output_tokens:
        Number.isFinite(body.maxOutputTokens)
          ? Math.trunc(body.maxOutputTokens)
          : null,
      legacy_request_id: _string(body.requestId),
    },
  });

  return Object.freeze({
    ok: true,
    errorCode: '',
    request: adapted,
    metadata: Object.freeze({
      sourceContract: 'geminiPaidProxy-v1',
      ignoredClientRoutingHints: _hasLegacyRoutingHints(body),
      clientRoutingAuthority: false,
    }),
  });
}

module.exports = {
  adaptLegacyGeminiPaidProxyRequest,
};
