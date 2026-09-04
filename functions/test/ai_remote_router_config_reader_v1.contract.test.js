'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  CONFIG_COLLECTION,
  CONFIG_DOCUMENT,
  CONFIG_CONTRACT_VERSION,
  normalizeRemoteAiRouterConfigV1,
  getCachedRemoteAiRouterConfigV1,
  refreshRemoteAiRouterConfigV1,
  resetRemoteAiRouterConfigCacheV1ForTest,
} = require('../lib/ai_remote_router_config_reader_v1');

const validConfig = () => ({
  contractVersion: CONFIG_CONTRACT_VERSION,
  enabled: false,
  shadowEnabled: true,
  modes: {
    study: {
      routeId: 'study_remote_v1',
      classifier: null,
      responseOrder: [
        'gemini_3_1_flash_lite_free',
        'gpt_5_nano',
        'gemini_3_1_flash_lite_paid',
      ],
      hardCaseModel: null,
    },
    plantao: {
      routeId: 'plantao_remote_v1',
      classifier: 'gpt_5_nano',
      responseOrder: [
        'gpt_5_6_luna',
        'gemini_3_1_flash_lite_paid',
      ],
      hardCaseModel: 'gpt_5_6_terra',
    },
  },
  policy: {
    fallbackOnTimeout: true,
    fallbackOnRateLimit: true,
    fallbackOnProvider5xx: true,
    clientOverrideAllowed: true,
    unknownModeAction: 'anything',
  },
});

test('remote config owner is fixed and server-side', () => {
  assert.equal(CONFIG_COLLECTION, 'ai_control_plane');
  assert.equal(CONFIG_DOCUMENT, 'router_v1');
});

test('valid config is normalized and client override forced off', () => {
  const cfg = normalizeRemoteAiRouterConfigV1(validConfig());
  assert.ok(cfg);
  assert.equal(cfg.enabled, false);
  assert.equal(cfg.shadowEnabled, true);
  assert.equal(cfg.policy.clientOverrideAllowed, false);
  assert.equal(
    cfg.policy.unknownModeAction,
    'preserve_live_behavior',
  );
});

test('wrong contract version fails closed to null', () => {
  const raw = validConfig();
  raw.contractVersion = 'future-incompatible-version';
  assert.equal(normalizeRemoteAiRouterConfigV1(raw), null);
});

test('malformed mode fails closed to null', () => {
  const raw = validConfig();
  raw.modes.plantao.responseOrder = [];
  assert.equal(normalizeRemoteAiRouterConfigV1(raw), null);
});

test('missing Firestore document clears override and preserves defaults', async () => {
  resetRemoteAiRouterConfigCacheV1ForTest();
  const cfg = await refreshRemoteAiRouterConfigV1({
    force: true,
    nowMs: 1000,
    fetchDocument: async () => ({
      exists: false,
      data: () => null,
    }),
  });
  assert.equal(cfg, null);
  assert.equal(getCachedRemoteAiRouterConfigV1(), null);
});

test('valid Firestore document populates server-side cache', async () => {
  resetRemoteAiRouterConfigCacheV1ForTest();
  const cfg = await refreshRemoteAiRouterConfigV1({
    force: true,
    nowMs: 2000,
    fetchDocument: async () => ({
      exists: true,
      data: () => validConfig(),
    }),
  });
  assert.ok(cfg);
  assert.equal(cfg.modes.plantao.classifier, 'gpt_5_nano');
  assert.equal(
    getCachedRemoteAiRouterConfigV1().modes.study.routeId,
    'study_remote_v1',
  );
});

test('Firestore failure never throws into live request', async () => {
  resetRemoteAiRouterConfigCacheV1ForTest();
  const cfg = await refreshRemoteAiRouterConfigV1({
    force: true,
    nowMs: 3000,
    fetchDocument: async () => {
      throw new Error('simulated-firestore-failure');
    },
  });
  assert.equal(cfg, null);
});
