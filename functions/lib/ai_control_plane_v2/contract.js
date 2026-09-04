'use strict';

/**
 * MedCases AI Gateway V2 — stable client/server contract.
 *
 * The Flutter client asks for CAPABILITIES, never commercial model names.
 * Commercial/provider model bindings are server-only.
 */

const CONTRACT_VERSION = 'medcases-ai-gateway-v2';

const MODES = Object.freeze({
  STUDY: 'study',
  PLANTAO: 'plantao',
});

const TASKS = Object.freeze({
  CLINICAL_QUESTION: 'clinical_question',
  CLINICAL_REASONING: 'clinical_reasoning',
  EDUCATIONAL_EXPLANATION: 'educational_explanation',
  SUMMARY: 'summary',
  FOLLOWUP: 'followup',
  CLASSIFICATION: 'classification',
});

const CAPABILITY_ALIASES = Object.freeze({
  STUDY_PRIMARY: 'study_primary',
  STUDY_FALLBACK_1: 'study_fallback_1',
  STUDY_FALLBACK_2: 'study_fallback_2',
  PLANTAO_ROUTER: 'plantao_router',
  PLANTAO_PRIMARY: 'plantao_primary',
  PLANTAO_CROSS_PROVIDER: 'plantao_cross_provider',
  PLANTAO_COMPLEX: 'plantao_complex',
});

const RESPONSE_FIELDS = Object.freeze([
  'success',
  'response_text',
  'contract_version',
  'config_version',
  'mode',
  'task',
  'route',
  'model_alias',
  'prompt_version',
  'escalation_level',
  'fallback_used',
  'fallback_kind',
  'clinical_context_id',
  'references',
  'warnings',
  'latency_ms',
]);

function normalizeCapabilityRequest(raw) {
  const req = raw && typeof raw === 'object' ? raw : {};

  return Object.freeze({
    contract_version: CONTRACT_VERSION,
    mode: typeof req.mode === 'string' ? req.mode : '',
    task: typeof req.task === 'string' ? req.task : '',
    locale: typeof req.locale === 'string' ? req.locale : '',
    conversation_id:
      typeof req.conversation_id === 'string' ? req.conversation_id : '',
    clinical_thread_id:
      typeof req.clinical_thread_id === 'string' ? req.clinical_thread_id : '',
    same_topic: req.same_topic === true,
    contextual_followup: req.contextual_followup === true,
    context_flags:
      req.context_flags && typeof req.context_flags === 'object'
        ? Object.freeze({ ...req.context_flags })
        : Object.freeze({}),
    input:
      req.input && typeof req.input === 'object'
        ? Object.freeze({ ...req.input })
        : Object.freeze({}),
  });
}

function makeNormalizedResponse(partial = {}) {
  const response = {
    success: partial.success === true,
    response_text:
      typeof partial.response_text === 'string' ? partial.response_text : '',
    contract_version: CONTRACT_VERSION,
    config_version:
      typeof partial.config_version === 'string' ? partial.config_version : '',
    mode: typeof partial.mode === 'string' ? partial.mode : '',
    task: typeof partial.task === 'string' ? partial.task : '',
    route: typeof partial.route === 'string' ? partial.route : '',
    model_alias:
      typeof partial.model_alias === 'string' ? partial.model_alias : '',
    prompt_version:
      typeof partial.prompt_version === 'string' ? partial.prompt_version : '',
    escalation_level:
      typeof partial.escalation_level === 'string'
        ? partial.escalation_level
        : 'none',
    fallback_used: partial.fallback_used === true,
    fallback_kind:
      typeof partial.fallback_kind === 'string' ? partial.fallback_kind : 'none',
    clinical_context_id:
      typeof partial.clinical_context_id === 'string'
        ? partial.clinical_context_id
        : '',
    references: Array.isArray(partial.references) ? partial.references : [],
    warnings: Array.isArray(partial.warnings) ? partial.warnings : [],
    latency_ms:
      Number.isFinite(partial.latency_ms) && partial.latency_ms >= 0
        ? partial.latency_ms
        : 0,
  };

  return Object.freeze(response);
}

module.exports = {
  CONTRACT_VERSION,
  MODES,
  TASKS,
  CAPABILITY_ALIASES,
  RESPONSE_FIELDS,
  normalizeCapabilityRequest,
  makeNormalizedResponse,
};
