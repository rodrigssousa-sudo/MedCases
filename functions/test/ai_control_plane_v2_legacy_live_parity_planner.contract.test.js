'use strict';

const assert = require('assert');

const {
  PARITY_MARKER,
  PARITY_KEYS,
  buildLegacyLiveParityPlan,
  observeLegacyLiveParity,
} = require('../lib/ai_control_plane_v2/legacy_live_parity_planner');

// Default legacy app request -> Gemini, model comes from server runtime constant.
{
  const body = {
    userMessage: 'secret_not_for_telemetry',
    systemPrompt: 'secret_system_prompt',
    history: [{ role: 'user', content: 'secret_history' }],
    mode: 'study',
    maxOutputTokens: 64,
    model: 'client_hint_not_authority',
    temperature: 0.99,
    tier: 'cognitive',
  };

  const before = JSON.stringify(body);
  const logs = [];

  const plan = observeLegacyLiveParity(body, {
    geminiPaidModel: 'gemini-runtime-current',
    logger: (...args) => logs.push(args),
  });

  assert.strictEqual(JSON.stringify(body), before);
  assert.strictEqual(plan.mode, 'study');
  assert.strictEqual(plan.plannedProvider, 'gemini');
  assert.strictEqual(plan.plannedModel, 'gemini-runtime-current');
  assert.strictEqual(plan.plannedTemperature, 0.4);
  assert.strictEqual(plan.plannedMaxOutputTokens, 200);
  assert.strictEqual(plan.legacyProviderDefaultApplied, true);
  assert.strictEqual(plan.clientProviderHintPresent, false);
  assert.strictEqual(plan.shadowOnly, true);
  assert.strictEqual(plan.liveProviderOverride, false);

  assert.deepStrictEqual(
    Object.keys(plan).sort(),
    [...PARITY_KEYS].sort()
  );

  const serialized = JSON.stringify(plan);
  assert.strictEqual(serialized.includes('secret_not_for_telemetry'), false);
  assert.strictEqual(serialized.includes('secret_system_prompt'), false);
  assert.strictEqual(serialized.includes('secret_history'), false);
  assert.strictEqual(serialized.includes('client_hint_not_authority'), false);

  assert.strictEqual(logs.length, 1);
  assert.strictEqual(logs[0][0], PARITY_MARKER);
}

// Explicit legacy OpenAI request reproduces current GPT-4o Mini branch.
{
  const plan = buildLegacyLiveParityPlan(
    {
      mode: 'plantao',
      provider: 'openai',
      maxOutputTokens: 4096,
      model: 'ignored-client-model',
      temperature: 1.0,
    },
    {
      geminiPaidModel: 'gemini-runtime-current',
    }
  );

  assert.strictEqual(plan.mode, 'plantao');
  assert.strictEqual(plan.plannedProvider, 'openai');
  assert.strictEqual(plan.plannedModel, 'gpt-4o-mini');
  assert.strictEqual(plan.plannedTemperature, 0.2);
  assert.strictEqual(plan.plannedMaxOutputTokens, 2048);
  assert.strictEqual(plan.legacyProviderDefaultApplied, false);
  assert.strictEqual(plan.clientProviderHintPresent, true);
}

// Non-openai provider still follows existing else/Gemini live branch.
{
  const plan = buildLegacyLiveParityPlan(
    {
      mode: 'study',
      provider: 'future-provider-name',
      maxOutputTokens: 800,
    },
    {
      geminiPaidModel: 'gemini-runtime-current',
    }
  );

  assert.strictEqual(plan.plannedProvider, 'gemini');
  assert.strictEqual(plan.plannedModel, 'gemini-runtime-current');
  assert.strictEqual(plan.plannedTemperature, 0.4);
  assert.strictEqual(plan.plannedMaxOutputTokens, 800);
}

// Unknown/missing mode preserves current practical default as Plantão semantics.
{
  const plan = buildLegacyLiveParityPlan(
    {
      maxOutputTokens: 800,
    },
    {
      geminiPaidModel: 'gemini-runtime-current',
    }
  );

  assert.strictEqual(plan.mode, 'plantao');
  assert.strictEqual(plan.plannedTemperature, 0.2);
}

console.log('AI_CONTROL_PLANE_V2_LEGACY_PARITY_PLANNER=PASS');
console.log('DEFAULT_GEMINI_PROVIDER_PARITY=PASS');
console.log('OPENAI_GPT4O_MINI_BRANCH_PARITY=PASS');
console.log('MODE_TEMPERATURE_PARITY=PASS');
console.log('MAX_OUTPUT_CLAMP_PARITY=PASS');
console.log('CLIENT_MODEL_HINT_AUTHORITY=NO');
console.log('RAW_CLINICAL_TEXT_TELEMETRY=NO');
console.log('REQUEST_MUTATION=NO');
console.log('LIVE_PROVIDER_OVERRIDE=NO');
