'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const {
  makeSafeBootstrapConfig,
} = require('../lib/ai_control_plane_v2/config_defaults');

const {
  TELEMETRY_MARKER,
  NEXT_MODEL_SHADOW_TELEMETRY_ERROR_MARKER,
  observeLegacyRequestV2Shadow,
} = require('../lib/ai_control_plane_v2/shadow_bridge');

const {
  SHADOW_ROUTER_MARKER,
} = require('../lib/ai_control_plane_v2/next_model_shadow_routing_v1');

function safeState() {
  return Object.freeze({
    config: makeSafeBootstrapConfig(),
    source: 'compiled_bootstrap',
    executionAllowed: false,
  });
}

function observe(body) {
  const legacyLogs = [];
  const nextLogs = [];
  const nextErrors = [];

  const before = JSON.stringify(body);

  const observation = observeLegacyRequestV2Shadow(body, {
    getStateFn: safeState,
    logger: (...args) => legacyLogs.push(args),
    errorLogger: () => {},
    nextModelLogger: (...args) => nextLogs.push(args),
    nextModelErrorLogger: (...args) => nextErrors.push(args),
  });

  assert.strictEqual(JSON.stringify(body), before);

  return {
    observation,
    legacyLogs,
    nextLogs,
    nextErrors,
  };
}

// Existing shadow telemetry remains intact and new telemetry is additive.
{
  const r = observe({
    userMessage: 'synthetic educational study',
    systemPrompt: 'SECRET_SYSTEM_PROMPT_SENTINEL',
    history: [
      { role: 'user', content: 'SECRET_HISTORY_SENTINEL' },
    ],
    mode: 'study',
    lang: 'pt',
  });

  assert.strictEqual(r.legacyLogs.length, 1);
  assert.strictEqual(r.legacyLogs[0][0], TELEMETRY_MARKER);

  assert.strictEqual(r.nextLogs.length, 1);
  assert.strictEqual(r.nextLogs[0][0], SHADOW_ROUTER_MARKER);
  assert.strictEqual(r.nextErrors.length, 0);

  const next = JSON.parse(r.nextLogs[0][1]);

  // Backend does not inspect content to decide that personal FREE is safe.
  assert.strictEqual(next.mode, 'study');
  assert.strictEqual(next.personalFreeEligible, false);
  assert.strictEqual(
    next.personalFreeBypassReason,
    'privacy_not_proven_safe'
  );
  assert.strictEqual(next.fallback1Alias, 'study_fallback_1');
  assert.strictEqual(next.fallback1Provider, 'openai');
  assert.strictEqual(next.fallback1Model, 'gpt-5-nano');
  assert.strictEqual(next.fallback2Alias, 'study_fallback_2');
  assert.strictEqual(next.fallback2Provider, 'google');
  assert.strictEqual(
    next.fallback2Model,
    'gemini-3.1-flash-lite'
  );
  assert.strictEqual(next.liveExecutionAllowed, false);
  assert.strictEqual(next.providerInferencePerformed, false);
  assert.strictEqual(next.shadowOnly, true);

  const serialized = JSON.stringify(next);
  for (const forbidden of [
    'synthetic educational study',
    'SECRET_SYSTEM_PROMPT_SENTINEL',
    'SECRET_HISTORY_SENTINEL',
    'uid',
    'email',
    'accessToken',
    'apiKey',
  ]) {
    assert.strictEqual(serialized.includes(forbidden), false);
  }
}

// Explicit patient context must remain personal-free bypassed.
{
  const r = observe({
    userMessage: 'patient sentinel must not be logged',
    mode: 'study',
    patientContext: {
      id: 'PATIENT_IDENTIFIER_SENTINEL',
    },
  });

  const next = JSON.parse(r.nextLogs[0][1]);

  assert.strictEqual(next.personalFreeEligible, false);
  assert.strictEqual(
    next.personalFreeBypassReason,
    'patient_context'
  );

  assert.strictEqual(
    JSON.stringify(next).includes('PATIENT_IDENTIFIER_SENTINEL'),
    false
  );
}

// Explicit sensitive clinical context has priority and bypasses personal free.
{
  const r = observe({
    userMessage: 'sensitive sentinel',
    mode: 'study',
    patientContext: { id: 'x' },
    sensitiveClinicalContext: true,
  });

  const next = JSON.parse(r.nextLogs[0][1]);

  assert.strictEqual(next.personalFreeEligible, false);
  assert.strictEqual(
    next.personalFreeBypassReason,
    'sensitive_clinical_context'
  );
}

// Plantao route metadata: Nano router only, Luna primary, no inferred failure
// or Terra escalation at request-start observation.
{
  const r = observe({
    userMessage: 'synthetic plantao',
    mode: 'plantao',
    patientContext: { id: 'NEVER_LOG_ME' },
  });

  const next = JSON.parse(r.nextLogs[0][1]);

  assert.strictEqual(next.mode, 'plantao');
  assert.strictEqual(next.routerAlias, 'plantao_router');
  assert.strictEqual(next.routerProvider, 'openai');
  assert.strictEqual(next.routerModel, 'gpt-5-nano');
  assert.strictEqual(next.routerMayRespondToUser, false);

  assert.strictEqual(next.primaryAlias, 'plantao_primary');
  assert.strictEqual(next.primaryProvider, 'openai');
  assert.strictEqual(next.primaryModel, 'gpt-5.6-luna');

  assert.strictEqual(next.technicalFallbackAlias, null);
  assert.strictEqual(next.complexEscalationAlias, null);
  assert.strictEqual(next.liveExecutionAllowed, false);
  assert.strictEqual(next.providerInferencePerformed, false);

  assert.strictEqual(
    JSON.stringify(next).includes('NEVER_LOG_ME'),
    false
  );
}

// Unsupported mode preserves legacy observation but emits no next route.
{
  const r = observe({
    userMessage: 'x',
    mode: 'unsupported_future_mode',
  });

  assert.strictEqual(r.observation.adapted, false);
  assert.strictEqual(r.legacyLogs.length, 1);
  assert.strictEqual(r.nextLogs.length, 0);
  assert.strictEqual(r.nextErrors.length, 0);
}

// Backward-compatible bridge call: without nextModelLogger, still one legacy
// telemetry event exactly as the frozen old contract expects.
{
  const logs = [];

  observeLegacyRequestV2Shadow(
    {
      userMessage: 'legacy compatible',
      mode: 'study',
    },
    {
      getStateFn: safeState,
      logger: (...args) => logs.push(args),
      errorLogger: (...args) => logs.push(args),
    }
  );

  assert.strictEqual(logs.length, 1);
  assert.strictEqual(logs[0][0], TELEMETRY_MARKER);
}

// Static callsite contract: index opts in explicitly; no await/return authority.
{
  const indexPath = path.resolve(__dirname, '..', 'index.js');
  const source = fs.readFileSync(indexPath, 'utf8');

  assert.strictEqual(
    (source.match(/observeLegacyRequestV2Shadow\(req\.body/g) || []).length,
    1
  );
  assert.strictEqual(
    (source.match(/nextModelLogger:\s*console\.log/g) || []).length,
    1
  );
  assert.strictEqual(
    (source.match(/nextModelErrorLogger:\s*console\.warn/g) || []).length,
    1
  );

  assert.strictEqual(
    /await\s+observeLegacyRequestV2Shadow/.test(source),
    false
  );
  assert.strictEqual(
    /return\s+observeLegacyRequestV2Shadow/.test(source),
    false
  );
}

// Error marker exists but no raw payload is part of the fixed error schema.
assert.strictEqual(
  NEXT_MODEL_SHADOW_TELEMETRY_ERROR_MARKER,
  '[AI_CONTROL_PLANE_V2_NEXT_MODEL_SHADOW_ROUTE_ERROR]'
);

console.log(
  'AI_CONTROL_PLANE_V2_NEXT_MODEL_SHADOW_OBSERVER_WIRING=PASS'
);
console.log('EXISTING_SHADOW_API_BACKWARD_COMPATIBILITY=PASS');
console.log('NEXT_MODEL_SHADOW_TELEMETRY_OPT_IN=PASS');
console.log('NEXT_MODEL_SHADOW_TELEMETRY_METADATA_ONLY=PASS');
console.log('NEXT_MODEL_PROVIDER_INFERENCE_PERFORMED=NO');
console.log('NEXT_MODEL_LIVE_AUTHORITY_CHANGED=NO');
console.log('STUDY_BACKEND_UNKNOWN_PRIVACY_FAIL_SAFE=PASS');
console.log('STUDY_PATIENT_CONTEXT_PERSONAL_FREE_BYPASS=PASS');
console.log('STUDY_SENSITIVE_CONTEXT_PERSONAL_FREE_BYPASS=PASS');
console.log('PLANTAO_NANO_ROUTER_ONLY_SHADOW=PASS');
console.log('PLANTAO_LUNA_PRIMARY_SHADOW=PASS');
console.log('TERRA_NOT_INFERRED_AT_REQUEST_START=PASS');
console.log('RAW_CLINICAL_NEXT_MODEL_TELEMETRY=ABSENT');
console.log('INDEX_SHADOW_CALLSITE_ONLY_ARGUMENT_PROPAGATION=PASS');
