'use strict';

const assert = require('assert');

const {
  makeSafeBootstrapConfig,
} = require('../lib/ai_control_plane_v2/config_defaults');

const {
  TELEMETRY_MARKER,
  OBSERVATION_KEYS,
  observeLegacyRequestV2Shadow,
} = require('../lib/ai_control_plane_v2/shadow_bridge');

function safeState() {
  return Object.freeze({
    config: makeSafeBootstrapConfig(),
    source: 'compiled_bootstrap',
    executionAllowed: false,
  });
}

// Study legacy request: routing hints are observed only as a boolean.
{
  const sensitiveSentinel = 'PATIENT_SECRET_SENTINEL_DO_NOT_LOG';

  const body = {
    userMessage: sensitiveSentinel,
    systemPrompt: 'SYSTEM_PROMPT_SECRET_SENTINEL',
    history: [
      { role: 'user', content: 'HISTORY_SECRET_SENTINEL' },
    ],
    mode: 'study',
    lang: 'pt',
    provider: 'openai',
    model: 'client_model_must_not_control_v2',
    model_tier: 'pro',
    temperature: 0.9,
    tier: 'cognitive',
  };

  const before = JSON.stringify(body);
  const logs = [];

  const observation = observeLegacyRequestV2Shadow(body, {
    getStateFn: safeState,
    refreshFn: async () => {
      throw new Error('refresh_not_expected_without_firestore');
    },
    logger: (...args) => logs.push(args),
    errorLogger: (...args) => logs.push(args),
  });

  assert.strictEqual(JSON.stringify(body), before);
  assert.strictEqual(observation.mode, 'study');
  assert.strictEqual(observation.task, 'clinical_question');
  assert.strictEqual(observation.shadowOnly, true);
  assert.strictEqual(observation.livePath, 'legacy_v1');
  assert.strictEqual(observation.liveProviderOverride, false);
  assert.strictEqual(observation.v2ExecutionAllowed, false);
  assert.strictEqual(observation.ignoredClientRoutingHints, true);

  const serialized = JSON.stringify(observation);
  assert.strictEqual(serialized.includes(sensitiveSentinel), false);
  assert.strictEqual(
    serialized.includes('SYSTEM_PROMPT_SECRET_SENTINEL'),
    false
  );
  assert.strictEqual(
    serialized.includes('HISTORY_SECRET_SENTINEL'),
    false
  );
  assert.strictEqual(
    serialized.includes('client_model_must_not_control_v2'),
    false
  );

  assert.strictEqual(logs.length, 1);
  assert.strictEqual(logs[0][0], TELEMETRY_MARKER);

  assert.deepStrictEqual(
    Object.keys(observation).sort(),
    [...OBSERVATION_KEYS].sort()
  );
}

// Plantão legacy request maps capability metadata only.
{
  const observation = observeLegacyRequestV2Shadow(
    {
      userMessage: 'synthetic plantao',
      mode: 'plantao',
      lang: 'es',
      patientContext: { id: 'must_never_be_logged' },
    },
    {
      getStateFn: safeState,
      logger: () => {},
      errorLogger: () => {},
    }
  );

  assert.strictEqual(observation.adapted, true);
  assert.strictEqual(observation.mode, 'plantao');
  assert.strictEqual(observation.task, 'clinical_reasoning');
  assert.strictEqual(
    JSON.stringify(observation).includes('must_never_be_logged'),
    false
  );
}

// Unsupported legacy mode must never affect live path.
{
  const observation = observeLegacyRequestV2Shadow(
    {
      userMessage: 'x',
      mode: 'future_unknown_mode',
    },
    {
      getStateFn: safeState,
      logger: () => {},
      errorLogger: () => {},
    }
  );

  assert.strictEqual(observation.adapted, false);
  assert.strictEqual(observation.mode, 'unknown');
  assert.strictEqual(observation.task, 'unknown');
  assert.strictEqual(observation.shadowOnly, true);
  assert.strictEqual(observation.liveProviderOverride, false);
}

// Config refresh is fire-and-forget and does not control observation/live path.
{
  let refreshCalled = false;
  const firestore = {
    collection() {
      return {};
    },
  };

  const observation = observeLegacyRequestV2Shadow(
    {
      userMessage: 'synthetic',
      mode: 'study',
    },
    {
      firestore,
      getStateFn: safeState,
      refreshFn: async () => {
        refreshCalled = true;
        return safeState();
      },
      logger: () => {},
      errorLogger: () => {},
    }
  );

  assert.strictEqual(observation.shadowOnly, true);
  assert.strictEqual(observation.liveProviderOverride, false);

  setImmediate(() => {
    assert.strictEqual(refreshCalled, true);

    console.log('AI_CONTROL_PLANE_V2_SHADOW_BRIDGE=PASS');
    console.log('LEGACY_REQUEST_TO_CAPABILITY_SHADOW=PASS');
    console.log('RAW_PROMPT_PATIENT_TEXT_TELEMETRY=ABSENT');
    console.log('CLIENT_MODEL_PROVIDER_AUTHORITY=ABSENT');
    console.log('REQUEST_BODY_MUTATION=NO');
    console.log('V2_LIVE_PROVIDER_OVERRIDE=NO');
    console.log('V2_SHADOW_ONLY=YES');
  });
}
