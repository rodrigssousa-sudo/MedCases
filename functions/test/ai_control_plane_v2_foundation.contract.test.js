'use strict';

const assert = require('assert');

const {
  CONTRACT_VERSION,
  CAPABILITY_ALIASES,
  normalizeCapabilityRequest,
  makeNormalizedResponse,
} = require('../lib/ai_control_plane_v2/contract');

const {
  getModelRegistry,
} = require('../lib/ai_control_plane_v2/model_registry');

const {
  makeSafeBootstrapConfig,
} = require('../lib/ai_control_plane_v2/config_defaults');

const {
  validateV2Config,
  validateRegistryNoSecrets,
  validateRegistryBindingsInactive,
} = require('../lib/ai_control_plane_v2/validator');

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

const registry = getModelRegistry();
const config = makeSafeBootstrapConfig();

assert.strictEqual(CONTRACT_VERSION, 'medcases-ai-gateway-v2');
assert.strictEqual(config.enabled, false);
assert.strictEqual(config.legacyParityMode, true);
assert.strictEqual(config.clientOverrideAllowed, false);
assert.strictEqual(config.rollout.percent, 0);

assert.strictEqual(
  config.aliases[CAPABILITY_ALIASES.STUDY_PRIMARY],
  'gemini_31_flash_lite_free'
);
assert.strictEqual(
  config.aliases[CAPABILITY_ALIASES.PLANTAO_ROUTER],
  'gpt_5_nano'
);
assert.strictEqual(
  config.aliases[CAPABILITY_ALIASES.PLANTAO_PRIMARY],
  'gpt_56_luna'
);
assert.strictEqual(
  config.aliases[CAPABILITY_ALIASES.PLANTAO_CROSS_PROVIDER],
  'gemini_31_flash_lite_paid'
);
assert.strictEqual(
  config.aliases[CAPABILITY_ALIASES.PLANTAO_COMPLEX],
  'gpt_56_terra'
);

assert.strictEqual(
  config.study.privacyGuard.allowIdentifiableClinicalData,
  false
);
assert.strictEqual(config.plantao.routerMayRespondToUser, false);
assert.strictEqual(config.plantao.technicalFallback.terraAllowed, false);

const baseValidation = validateV2Config(config, registry);
assert.deepStrictEqual(baseValidation, { ok: true, errors: [] });

const secretValidation = validateRegistryNoSecrets(registry);
assert.deepStrictEqual(secretValidation, { ok: true, errors: [] });

const bindingValidation = validateRegistryBindingsInactive(registry);
assert.deepStrictEqual(bindingValidation, { ok: true, errors: [] });

// Unsafe Study FREE privacy must fail.
{
  const unsafe = clone(config);
  unsafe.study.privacyGuard.allowIdentifiableClinicalData = true;
  const result = validateV2Config(unsafe, registry);
  assert.strictEqual(result.ok, false);
  assert.ok(
    result.errors.includes('study_free_identifiable_data_must_be_false')
  );
}

// Client model/provider overrides can never be enabled.
{
  const unsafe = clone(config);
  unsafe.clientOverrideAllowed = true;
  const result = validateV2Config(unsafe, registry);
  assert.strictEqual(result.ok, false);
  assert.ok(result.errors.includes('client_override_must_be_false'));
}

// Terra can never become technical fallback.
{
  const unsafe = clone(config);
  unsafe.plantao.technicalFallback.terraAllowed = true;
  const result = validateV2Config(unsafe, registry);
  assert.strictEqual(result.ok, false);
  assert.ok(result.errors.includes('terra_must_not_be_technical_fallback'));
}

// Router must never answer the physician.
{
  const unsafeRegistry = clone(registry);
  unsafeRegistry.gpt_5_nano.respondsToUser = true;
  const result = validateV2Config(config, unsafeRegistry);
  assert.strictEqual(result.ok, false);
  assert.ok(
    result.errors.includes('plantao_router_must_not_respond_to_user')
  );
}

// Raw prompt/patient telemetry must remain disabled.
{
  const unsafe = clone(config);
  unsafe.telemetry.rawPatientTextLogging = true;
  const result = validateV2Config(unsafe, registry);
  assert.strictEqual(result.ok, false);
  assert.ok(
    result.errors.includes('raw_clinical_telemetry_must_be_disabled')
  );
}

// Stable capability request ignores commercial-model style fields.
{
  const req = normalizeCapabilityRequest({
    mode: 'study',
    task: 'clinical_question',
    locale: 'pt-BR',
    provider: 'client_must_not_choose',
    model: 'client_must_not_choose',
    input: { text: 'synthetic' },
  });
  assert.strictEqual(req.mode, 'study');
  assert.strictEqual(req.task, 'clinical_question');
  assert.strictEqual(Object.hasOwn(req, 'provider'), false);
  assert.strictEqual(Object.hasOwn(req, 'model'), false);
}

// Normalized response exposes alias/config version, not provider payload shape.
{
  const res = makeNormalizedResponse({
    success: true,
    response_text: 'ok',
    config_version: config.configVersion,
    mode: 'study',
    task: 'clinical_question',
    route: 'study_v2',
    model_alias: 'study_primary',
    prompt_version: 'study_system_prompt_v1',
    latency_ms: 100,
  });
  assert.strictEqual(res.contract_version, CONTRACT_VERSION);
  assert.strictEqual(res.model_alias, 'study_primary');
  assert.strictEqual(Object.hasOwn(res, 'provider_raw_response'), false);
}

console.log('AI_CONTROL_PLANE_V2_FOUNDATION_CONTRACT=PASS');
console.log('V2_ENABLED=FALSE');
console.log('LEGACY_PARITY_MODE=TRUE');
console.log('CLIENT_OVERRIDE_ALLOWED=FALSE');
console.log('MODEL_BINDINGS=UNBOUND');
console.log('MODEL_REGISTRY_ENABLED_MODELS=0');
console.log('STUDY_FREE_PRIVACY_GUARD=PASS');
console.log('PLANTAO_ROUTER_NO_USER_RESPONSE_GUARD=PASS');
console.log('TECHNICAL_FALLBACK_CLINICAL_ESCALATION_SEPARATION=PASS');
console.log('TERRA_TECHNICAL_FALLBACK_FORBIDDEN=PASS');
console.log('RAW_CLINICAL_TELEMETRY_DISABLED=PASS');
console.log('CAPABILITY_ONLY_CLIENT_CONTRACT=PASS');
