'use strict';

const {
  evaluateProtectedClinicalProviderGate,
  buildProtectedClinicalRouterInputV1,
} = require('./protected_clinical_data_policy_v2');

const crypto = require('crypto');

const {
  VERIFIED_PROVIDER_BINDINGS,
  ROUTE_ALIASES,
} = require('./model_registry');

const EXECUTOR_VERSION =
  'AI_GPT5_NANO_PLANTAO_ROUTER_REAL_SHADOW_V1_2026_08_29_0001';

const TELEMETRY_MARKER =
  '[AI_CONTROL_PLANE_V2_GPT5_NANO_REAL_SHADOW]';

const ERROR_MARKER =
  '[AI_CONTROL_PLANE_V2_GPT5_NANO_REAL_SHADOW_ERROR]';

const OPENAI_RESPONSES_URL =
  'https://api.openai.com/v1/responses';

const SERVER_HARD_GATE =
  'AI_GPT5_NANO_REAL_SHADOW_ENABLED';

const REMOTE_FEATURE_FLAG =
  'gpt5_nano_real_shadow_v1';

const DEFAULT_TIMEOUT_MS = 5000;
const DEFAULT_MAX_OUTPUT_TOKENS = 128;

const ROUTER_SCHEMA = Object.freeze({
  type: 'object',
  additionalProperties: false,
  properties: {
    complexity: {
      type: 'string',
      enum: [
        'routine',
        'moderate',
        'complex',
        'critical',
        'insufficient_information',
      ],
    },
    escalation_signal: {
      type: 'boolean',
    },
    confidence_band: {
      type: 'string',
      enum: [
        'low',
        'medium',
        'high',
      ],
    },
    reason_code: {
      type: 'string',
      enum: [
        'routine_single_problem',
        'multiple_active_problems',
        'diagnostic_conflict',
        'high_risk_or_unstable',
        'insufficient_information',
        'large_or_longitudinal_context',
        'other_complexity',
      ],
    },
  },
  required: [
    'complexity',
    'escalation_signal',
    'confidence_band',
    'reason_code',
  ],
});

function _isPlainObject(value) {
  return (
    value !== null &&
    typeof value === 'object' &&
    !Array.isArray(value)
  );
}

function _clampInt(value, min, max, fallback) {
  if (!Number.isFinite(Number(value))) {
    return fallback;
  }

  const n = Math.trunc(Number(value));
  return Math.max(min, Math.min(max, n));
}

function deterministicShadowBucket(uid, salt) {
  if (
    typeof uid !== 'string' ||
    uid.length === 0 ||
    typeof salt !== 'string' ||
    salt.length === 0
  ) {
    return null;
  }

  const digest = crypto
    .createHash('sha256')
    .update(`${salt}:${uid}`, 'utf8')
    .digest();

  const first32 = digest.readUInt32BE(0);
  return first32 % 10000;
}

function _getRemoteShadowConfig(config) {
  if (!_isPlainObject(config)) {
    return null;
  }

  const featureFlags = _isPlainObject(config.featureFlags)
    ? config.featureFlags
    : {};

  if (featureFlags[REMOTE_FEATURE_FLAG] !== true) {
    return null;
  }

  const shadowProviderCalls =
    _isPlainObject(config.shadowProviderCalls)
      ? config.shadowProviderCalls
      : {};

  const gpt5Nano =
    _isPlainObject(shadowProviderCalls.gpt5Nano)
      ? shadowProviderCalls.gpt5Nano
      : null;

  if (!gpt5Nano || gpt5Nano.enabled !== true) {
    return null;
  }

  const rolloutPercent = _clampInt(
    gpt5Nano.rolloutPercent,
    0,
    100,
    0
  );

  const cohortSalt =
    typeof gpt5Nano.cohortSalt === 'string'
      ? gpt5Nano.cohortSalt.trim()
      : '';

  if (rolloutPercent <= 0 || cohortSalt.length < 8) {
    return null;
  }

  const timeoutMs = _clampInt(
    gpt5Nano.timeoutMs,
    1000,
    10000,
    DEFAULT_TIMEOUT_MS
  );

  const maxOutputTokens = _clampInt(
    gpt5Nano.maxOutputTokens,
    64,
    1024,
    DEFAULT_MAX_OUTPUT_TOKENS
  );

  return Object.freeze({
    rolloutPercent,
    cohortSalt,
    timeoutMs,
    maxOutputTokens,
  });
}

function evaluateGpt5NanoRealShadowGate({
  config,
  uid,
  mode,
  serverEnabled,
}) {
  if (serverEnabled !== true) {
    return Object.freeze({
      allowed: false,
      reason: 'server_hard_gate_closed',
      bucket: null,
      threshold: null,
      remote: null,
    });
  }

  if (mode !== 'plantao') {
    return Object.freeze({
      allowed: false,
      reason: 'mode_not_plantao',
      bucket: null,
      threshold: null,
      remote: null,
    });
  }

  if (typeof uid !== 'string' || uid.length === 0) {
    return Object.freeze({
      allowed: false,
      reason: 'uid_missing',
      bucket: null,
      threshold: null,
      remote: null,
    });
  }

  const remote = _getRemoteShadowConfig(config);

  if (!remote) {
    return Object.freeze({
      allowed: false,
      reason: 'remote_flag_or_config_closed',
      bucket: null,
      threshold: null,
      remote: null,
    });
  }

  const bucket = deterministicShadowBucket(
    uid,
    remote.cohortSalt
  );

  if (bucket === null) {
    return Object.freeze({
      allowed: false,
      reason: 'cohort_bucket_unavailable',
      bucket: null,
      threshold: null,
      remote,
    });
  }

  const threshold = remote.rolloutPercent * 100;

  if (bucket >= threshold) {
    return Object.freeze({
      allowed: false,
      reason: 'outside_shadow_cohort',
      bucket,
      threshold,
      remote,
    });
  }

  return Object.freeze({
    allowed: true,
    reason: 'open',
    bucket,
    threshold,
    remote,
  });
}

function _validateBindingAndRole() {
  const alias = ROUTE_ALIASES.plantao_router;
  const binding =
    VERIFIED_PROVIDER_BINDINGS.gpt_5_nano;

  if (
    !alias ||
    alias.target !== 'gpt_5_nano' ||
    alias.respondsToUser !== false ||
    alias.routerClassifierOnly !== true
  ) {
    throw new Error(
      'plantao_router_alias_authority_invalid'
    );
  }

  if (
    !binding ||
    binding.provider !== 'openai' ||
    binding.apiModelName !== 'gpt-5-nano' ||
    binding.activationState !== 'shadow_verified' ||
    binding.backendExecutable !== true
  ) {
    throw new Error(
      'gpt5_nano_verified_binding_invalid'
    );
  }

  return Object.freeze({
    alias,
    binding,
  });
}

function _extractOutputText(body) {
  if (!_isPlainObject(body)) {
    return '';
  }

  if (typeof body.output_text === 'string') {
    return body.output_text;
  }

  const output = Array.isArray(body.output)
    ? body.output
    : [];

  const chunks = [];

  for (const item of output) {
    if (
      !_isPlainObject(item) ||
      !Array.isArray(item.content)
    ) {
      continue;
    }

    for (const part of item.content) {
      if (
        _isPlainObject(part) &&
        part.type === 'output_text' &&
        typeof part.text === 'string'
      ) {
        chunks.push(part.text);
      }
    }
  }

  return chunks.join('');
}

function _validateRouterClassification(value) {
  if (!_isPlainObject(value)) {
    return false;
  }

  const allowedComplexity = new Set([
    'routine',
    'moderate',
    'complex',
    'critical',
    'insufficient_information',
  ]);

  const allowedConfidence = new Set([
    'low',
    'medium',
    'high',
  ]);

  const allowedReason = new Set([
    'routine_single_problem',
    'multiple_active_problems',
    'diagnostic_conflict',
    'high_risk_or_unstable',
    'insufficient_information',
    'large_or_longitudinal_context',
    'other_complexity',
  ]);

  return (
    allowedComplexity.has(value.complexity) &&
    typeof value.escalation_signal === 'boolean' &&
    allowedConfidence.has(value.confidence_band) &&
    allowedReason.has(value.reason_code)
  );
}

function _buildInputText({
  userMessage,
  history,
  patientContext,
}) {
  const parts = [];

  if (
    Array.isArray(history) &&
    history.length > 0
  ) {
    const safeHistory = history
      .slice(-6)
      .map((item) => {
        if (!_isPlainObject(item)) {
          return null;
        }

        const role =
          item.role === 'assistant'
            ? 'assistant'
            : 'user';

        const content =
          typeof item.content === 'string'
            ? item.content
            : typeof item.text === 'string'
              ? item.text
              : '';

        if (!content) {
          return null;
        }

        return `${role}: ${content.slice(0, 4000)}`;
      })
      .filter(Boolean);

    if (safeHistory.length > 0) {
      parts.push(
        `Recent conversation:\n${safeHistory.join('\n')}`
      );
    }
  }

  if (_isPlainObject(patientContext)) {
    const serialized = JSON.stringify(patientContext);

    if (serialized.length > 2) {
      parts.push(
        `Patient context:\n${serialized.slice(0, 8000)}`
      );
    }
  }

  if (typeof userMessage === 'string') {
    parts.push(
      `Current clinician message:\n${userMessage.slice(0, 12000)}`
    );
  }

  return parts.join('\n\n');
}

function buildGpt5NanoRouterRequest({
  inputText,
  maxOutputTokens,
}) {
  return Object.freeze({
    model: 'gpt-5-nano',
    instructions:
      'You are a silent clinical routing classifier for MedCases Plantao. ' +
      'Do not provide diagnosis, treatment, recommendations, explanations, ' +
      'or a physician-facing answer. Classify only the reasoning complexity ' +
      'and escalation signal using the required JSON schema.',
    input: inputText,
    store: false,
    max_output_tokens: maxOutputTokens,
    text: {
      format: {
        type: 'json_schema',
        name: 'medcases_plantao_router_shadow_v1',
        strict: true,
        schema: ROUTER_SCHEMA,
      },
    },
  });
}

async function runGpt5NanoPlantaoRouterRealShadow({
  config,
  uid,
  mode,
  userMessage,
  history,
  patientContext,
  providerDataPolicy = null,
  protectedClinicalProjection = null,
  openAiApiKey,
  fetchFn = globalThis.fetch,
  serverEnabled =
    process.env[SERVER_HARD_GATE] === 'true',
  nowMs = () => Date.now(),
}) {
  const gate = evaluateGpt5NanoRealShadowGate({
    config,
    uid,
    mode,
    serverEnabled,
  });

  if (!gate.allowed) {
    return Object.freeze({
      attempted: false,
      completed: false,
      gateReason: gate.reason,
      userResponseAuthority: false,
      liveAuthorityChanged: false,
      telemetryOnly: true,
    });
  }

  _validateBindingAndRole();

  if (
    typeof openAiApiKey !== 'string' ||
    openAiApiKey.length === 0
  ) {
    return Object.freeze({
      attempted: false,
      completed: false,
      gateReason: 'openai_key_missing',
      userResponseAuthority: false,
      liveAuthorityChanged: false,
      telemetryOnly: true,
    });
  }

  if (typeof fetchFn !== 'function') {
    throw new TypeError('fetchFn_required');
  }

  let inputText = _buildInputText({
    userMessage,
    history,
    patientContext,
  });

  if (inputText.length === 0) {
    return Object.freeze({
      attempted: false,
      completed: false,
      gateReason: 'empty_router_input',
      userResponseAuthority: false,
      liveAuthorityChanged: false,
      telemetryOnly: true,
    });
  }

  // Temporary privacy canary guard:
  // when enabled server-side, only explicitly synthetic/non-patient
  // requests may reach the real GPT-5 nano shadow provider.
  const syntheticOnlyGuardEnabled =
    process.env.AI_GPT5_NANO_REAL_SHADOW_SYNTHETIC_ONLY === 'true';

  const syntheticOnlyEligible =
    patientContext != null &&
    typeof patientContext === 'object' &&
    patientContext.synthetic === true &&
    patientContext.realPatient === false;

  if (syntheticOnlyGuardEnabled && !syntheticOnlyEligible) {
    return Object.freeze({
      attempted: false,
      completed: false,
      gateReason: 'synthetic_only_guard',
      provider: 'openai',
      model: 'gpt-5-nano',
      userResponseAuthority: false,
      liveAuthorityChanged: false,
      telemetryOnly: true,
    });
  }

  // Protected clinical data policy:
  // every request not explicitly synthetic/non-patient is treated as
  // potentially real patient data and denied by default. The policy
  // must be created server-side and a strict de-identified projection
  // must replace raw user/history/patientContext before provider send.
  const protectedClinicalGate =
    evaluateProtectedClinicalProviderGate({
      patientContext,
      providerDataPolicy,
      protectedClinicalProjection,
    });

  if (!protectedClinicalGate.allowed) {
    return Object.freeze({
      attempted: false,
      completed: false,
      gateReason: protectedClinicalGate.reason,
      provider: 'openai',
      model: 'gpt-5-nano',
      userResponseAuthority: false,
      liveAuthorityChanged: false,
      telemetryOnly: true,
    });
  }

  if (protectedClinicalGate.useProtectedProjection) {
    inputText =
      buildProtectedClinicalRouterInputV1(
        protectedClinicalProjection
      );
  }

  const payload = buildGpt5NanoRouterRequest({
    inputText,
    maxOutputTokens: gate.remote.maxOutputTokens,
  });

  const startedAt = nowMs();

  let response;

  try {
    response = await fetchFn(
      OPENAI_RESPONSES_URL,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${openAiApiKey}`,
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(
          gate.remote.timeoutMs
        ),
      }
    );
  } catch (error) {
    const latencyMs = Math.max(
      0,
      nowMs() - startedAt
    );

    return Object.freeze({failureStage:'provider_exception',
      attempted: true,
      completed: false,
      gateReason: 'open',
      outcome: 'network_or_timeout_error',
      errorClass:
        error && error.name
          ? String(error.name).slice(0, 80)
          : 'unknown_error',
      latencyMs,
      userResponseAuthority: false,
      liveAuthorityChanged: false,
      telemetryOnly: true,
    });
  }

  const latencyMs = Math.max(
    0,
    nowMs() - startedAt
  );

  let body = null;

  try {
    body = await response.json();
  } catch (_) {
    body = null;
  }

  if (!response.ok) {
    return Object.freeze({failureStage:'provider_http_reject',
      attempted: true,
      completed: false,
      gateReason: 'open',
      outcome: 'provider_http_error',
      httpStatus: response.status,
      latencyMs,
      userResponseAuthority: false,
      liveAuthorityChanged: false,
      telemetryOnly: true,
    });
  }

  const text = _extractOutputText(body);

  let classification = null;

  try {
    classification = JSON.parse(text);
  } catch (_) {
    classification = null;
  }

  if (!_validateRouterClassification(classification)) {
    return Object.freeze({failureStage:'provider_response_invalid',
      attempted: true,
      completed: false,
      gateReason: 'open',
      outcome: 'invalid_structured_output',
      httpStatus: response.status,
      latencyMs,
      model:
        body && typeof body.model === 'string'
          ? body.model
          : 'gpt-5-nano',
      userResponseAuthority: false,
      liveAuthorityChanged: false,
      telemetryOnly: true,
    });
  }

  const usage =
    body && _isPlainObject(body.usage)
      ? body.usage
      : {};

  return Object.freeze({
    attempted: true,
    completed: true,
    gateReason: 'open',
    outcome: 'completed',
    httpStatus: response.status,
    latencyMs,
    model:
      body && typeof body.model === 'string'
        ? body.model
        : 'gpt-5-nano',
    classification: Object.freeze({
      complexity: classification.complexity,
      escalationSignal:
        classification.escalation_signal,
      confidenceBand:
        classification.confidence_band,
      reasonCode:
        classification.reason_code,
    }),
    usage: Object.freeze({
      inputTokens:
        Number.isFinite(Number(usage.input_tokens))
          ? Number(usage.input_tokens)
          : null,
      outputTokens:
        Number.isFinite(Number(usage.output_tokens))
          ? Number(usage.output_tokens)
          : null,
      totalTokens:
        Number.isFinite(Number(usage.total_tokens))
          ? Number(usage.total_tokens)
          : null,
    }),
    userResponseAuthority: false,
    liveAuthorityChanged: false,
    telemetryOnly: true,
  });
}

function buildGpt5NanoRealShadowTelemetry(result) {
  if (!_isPlainObject(result)) {
    throw new TypeError('shadow_result_required');
  }

  const telemetry = {
    executorVersion: EXECUTOR_VERSION,
    attempted: result.attempted === true,
    completed: result.completed === true,
    gateReason:
      typeof result.gateReason === 'string'
        ? result.gateReason
        : 'unknown',
    outcome:
      typeof result.outcome === 'string'
        ? result.outcome
        : null,
    httpStatus:
      Number.isInteger(result.httpStatus)
        ? result.httpStatus
        : null,
    latencyMs:
      Number.isFinite(Number(result.latencyMs))
        ? Number(result.latencyMs)
        : null,
    model:
      typeof result.model === 'string'
        ? result.model
        : null,
    userResponseAuthority: false,
    liveAuthorityChanged: false,
    telemetryOnly: true,
  };

  if (_isPlainObject(result.classification)) {
    telemetry.classification = {
      complexity:
        result.classification.complexity || null,
      escalationSignal:
        result.classification.escalationSignal === true,
      confidenceBand:
        result.classification.confidenceBand || null,
      reasonCode:
        result.classification.reasonCode || null,
    };
  }

  if (_isPlainObject(result.usage)) {
    telemetry.usage = {
      inputTokens:
        result.usage.inputTokens ?? null,
      outputTokens:
        result.usage.outputTokens ?? null,
      totalTokens:
        result.usage.totalTokens ?? null,
    };
  }

  if (typeof result.errorClass === 'string') {
    telemetry.errorClass =
      result.errorClass.slice(0, 80);
  }

  return Object.freeze(telemetry);
}

module.exports = {
  EXECUTOR_VERSION,
  TELEMETRY_MARKER,
  ERROR_MARKER,
  OPENAI_RESPONSES_URL,
  SERVER_HARD_GATE,
  REMOTE_FEATURE_FLAG,
  ROUTER_SCHEMA,
  deterministicShadowBucket,
  evaluateGpt5NanoRealShadowGate,
  buildGpt5NanoRouterRequest,
  runGpt5NanoPlantaoRouterRealShadow,
  buildGpt5NanoRealShadowTelemetry,
};
