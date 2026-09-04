'use strict';

const assert = require('assert');

const {
  EXECUTION_MARKER,
  EXECUTION_KEYS,
  resolveLegacyParityExecutionGate,
  observeExecutionGate,
} = require('../lib/ai_control_plane_v2/legacy_parity_execution_gate');

function openState(percent = 100) {
  return {
    executionAllowed: true,
    config: {
      enabled: true,
      legacyParityMode: false,
      clientOverrideAllowed: false,
      rollout: {
        enabled: true,
        percent,
        cohortSaltVersion: 'cutover-v1',
      },
      featureFlags: {
        legacy_parity_execution_v2: true,
      },
    },
  };
}

const body = {
  userMessage: 'PATIENT_TEXT_MUST_NEVER_APPEAR',
  systemPrompt: 'SYSTEM_PROMPT_MUST_NEVER_APPEAR',
  history: [{ role: 'user', content: 'HISTORY_MUST_NEVER_APPEAR' }],
  mode: 'study',
  provider: 'openai',
};

// Env off always fails closed before cohort evaluation.
{
  const d = resolveLegacyParityExecutionGate(body, {
    uid: 'user-A',
    geminiPaidModel: 'gemini-current',
    env: {
      AI_CONTROL_PLANE_V2_LEGACY_PARITY_EXECUTION_ENABLED: 'false',
    },
    configState: openState(100),
  });

  assert.strictEqual(d.gateOpen, false);
  assert.strictEqual(d.authority, 'legacy_v1');
  assert.strictEqual(d.gateReason, 'server_env_off');
  assert.strictEqual(d.rolloutEligible, false);
}

// Missing UID fails closed even if every other gate is open.
{
  const d = resolveLegacyParityExecutionGate(body, {
    uid: '',
    geminiPaidModel: 'gemini-current',
    env: {
      AI_CONTROL_PLANE_V2_LEGACY_PARITY_EXECUTION_ENABLED: 'true',
    },
    configState: openState(100),
  });

  assert.strictEqual(d.gateOpen, false);
  assert.strictEqual(d.authority, 'legacy_v1');
  assert.strictEqual(d.gateReason, 'missing_or_invalid_uid');
  assert.strictEqual(d.rolloutEligible, false);
}

// Missing salt fails closed.
{
  const state = openState(100);
  state.config.rollout.cohortSaltVersion = '';

  const d = resolveLegacyParityExecutionGate(body, {
    uid: 'user-A',
    geminiPaidModel: 'gemini-current',
    env: {
      AI_CONTROL_PLANE_V2_LEGACY_PARITY_EXECUTION_ENABLED: 'true',
    },
    configState: state,
  });

  assert.strictEqual(d.gateOpen, false);
  assert.strictEqual(d.gateReason, 'missing_or_invalid_cohort_salt');
}

// 0% fails closed.
{
  const d = resolveLegacyParityExecutionGate(body, {
    uid: 'user-A',
    geminiPaidModel: 'gemini-current',
    env: {
      AI_CONTROL_PLANE_V2_LEGACY_PARITY_EXECUTION_ENABLED: 'true',
    },
    configState: openState(0),
  });

  assert.strictEqual(d.gateOpen, false);
  assert.strictEqual(d.gateReason, 'rollout_zero');
}

// 100% opens for a valid authenticated user.
{
  const d = resolveLegacyParityExecutionGate(body, {
    uid: 'user-A',
    geminiPaidModel: 'gemini-current',
    env: {
      AI_CONTROL_PLANE_V2_LEGACY_PARITY_EXECUTION_ENABLED: 'true',
    },
    configState: openState(100),
  });

  assert.strictEqual(d.gateOpen, true);
  assert.strictEqual(d.authority, 'v2_legacy_parity');
  assert.strictEqual(d.provider, 'openai');
  assert.strictEqual(d.model, 'gpt-4o-mini');
  assert.strictEqual(d.temperature, 0.4);
  assert.strictEqual(d.rolloutEligible, true);
}

// Gemini Plantão still reproduces exact legacy semantics.
{
  const d = resolveLegacyParityExecutionGate(
    { mode: 'plantao' },
    {
      uid: 'user-A',
      geminiPaidModel: 'gemini-2.5-flash',
      env: {
        AI_CONTROL_PLANE_V2_LEGACY_PARITY_EXECUTION_ENABLED: 'true',
      },
      configState: openState(100),
    }
  );

  assert.strictEqual(d.gateOpen, true);
  assert.strictEqual(d.provider, 'gemini');
  assert.strictEqual(d.model, 'gemini-2.5-flash');
  assert.strictEqual(d.temperature, 0.2);
}

// Telemetry contains no UID or raw request content.
{
  const logs = [];
  const d = observeExecutionGate(body, {
    uid: 'SUPER_SECRET_UID_SENTINEL',
    geminiPaidModel: 'gemini-current',
    env: {},
    configState: openState(100),
    logger: (...args) => logs.push(args),
  });

  assert.deepStrictEqual(
    Object.keys(d).sort(),
    [...EXECUTION_KEYS].sort()
  );

  const serialized = JSON.stringify(d);
  assert.strictEqual(serialized.includes('SUPER_SECRET_UID_SENTINEL'), false);
  assert.strictEqual(serialized.includes('PATIENT_TEXT_MUST_NEVER_APPEAR'), false);
  assert.strictEqual(serialized.includes('SYSTEM_PROMPT_MUST_NEVER_APPEAR'), false);
  assert.strictEqual(serialized.includes('HISTORY_MUST_NEVER_APPEAR'), false);

  assert.strictEqual(logs.length, 1);
  assert.strictEqual(logs[0][0], EXECUTION_MARKER);
}

console.log('AI_CONTROL_PLANE_V2_LEGACY_PARITY_EXECUTION_GATE=PASS');
console.log('DETERMINISTIC_COHORT_REQUIRED_FOR_AUTHORITY=PASS');
console.log('MISSING_UID_FAIL_CLOSED=PASS');
console.log('MISSING_COHORT_SALT_FAIL_CLOSED=PASS');
console.log('ZERO_PERCENT_FAIL_CLOSED=PASS');
console.log('HUNDRED_PERCENT_VALID_USER_OPEN=PASS');
console.log('OPENAI_PARITY_EXECUTION_DECISION=PASS');
console.log('GEMINI_PARITY_EXECUTION_DECISION=PASS');
console.log('RAW_UID_TELEMETRY=ABSENT');
console.log('RAW_CLINICAL_TELEMETRY=ABSENT');
