'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  CONTRACT_VERSION,
  resolveRemoteAiRouteShadowV1,
  toRemoteAiRouteShadowTelemetryV1,
  shouldEmitRemoteAiRouteShadowV1,
} = require('../lib/ai_remote_router_shadow_v1');

test('Study shadow route matches MedCases control-plane order', () => {
  const d = resolveRemoteAiRouteShadowV1({data: {mode: 'estudo'}});
  assert.equal(d.contractVersion, CONTRACT_VERSION);
  assert.equal(d.mode, 'study');
  assert.equal(d.classifier, null);
  assert.deepEqual(d.responseOrder, [
    'gemini_3_1_flash_lite_free',
    'gpt_5_nano',
    'gemini_3_1_flash_lite_paid',
  ]);
  assert.equal(d.hardCaseModel, null);
  assert.equal(d.shadowOnly, true);
  assert.equal(d.liveProviderOverride, false);
});

test('Plantao shadow route keeps nano as classifier only', () => {
  const d = resolveRemoteAiRouteShadowV1({
    data: {mode: 'plantão'},
  });
  assert.equal(d.mode, 'plantao');
  assert.equal(d.classifier, 'gpt_5_nano');
  assert.deepEqual(d.responseOrder, [
    'gpt_5_6_luna',
    'gemini_3_1_flash_lite_paid',
  ]);
  assert.equal(d.hardCaseModel, 'gpt_5_6_terra');
  assert.equal(d.responseOrder.includes('gpt_5_nano'), false);
  assert.equal(d.liveProviderOverride, false);
});

test('Spanish Guardia maps to Plantao', () => {
  const d = resolveRemoteAiRouteShadowV1({
    body: {assistantMode: 'guardia'},
  });
  assert.equal(d.mode, 'plantao');
});

test('Unknown mode is non-invasive', () => {
  const d = resolveRemoteAiRouteShadowV1({
    data: {prompt: 'clinical text must not enter telemetry'},
  });
  assert.equal(d.mode, 'unknown');
  assert.deepEqual(d.responseOrder, []);
  assert.equal(d.liveProviderOverride, false);
});

test('Telemetry contains route metadata only, never input payload', () => {
  const d = resolveRemoteAiRouteShadowV1({
    data: {
      mode: 'study',
      prompt: 'SECRET_PATIENT_TEXT',
      patientName: 'SECRET_NAME',
    },
  });
  const t = toRemoteAiRouteShadowTelemetryV1(d);
  const serialized = JSON.stringify(t);
  assert.equal(serialized.includes('SECRET_PATIENT_TEXT'), false);
  assert.equal(serialized.includes('SECRET_NAME'), false);
  assert.equal(t.shadowOnly, true);
  assert.equal(t.liveProviderOverride, false);
});

test('functions/index.js binds shadow only to geminiPaidProxy source', () => {
  const indexPath = path.join(__dirname, '..', 'index.js');
  const source = fs.readFileSync(indexPath, 'utf8');

  assert.equal(
    (source.match(/AI_CONTROL_PLANE_SHADOW_V1_BIND/g) || []).length,
    1,
  );
  assert.equal(
    (source.match(/AI_CONTROL_PLANE_SHADOW_V1_EXEC/g) || []).length,
    1,
  );
  assert.ok(source.includes('exports.geminiPaidProxy'));
  assert.ok(source.includes('resolveRemoteAiRouteShadowV1'));
  assert.ok(source.includes('live provider/model or response envelope'));
});

test('valid remote config changes shadow decision only', () => {
  const remote = {
    shadowEnabled: true,
    modes: {
      study: {
        routeId: 'study_remote_test',
        classifier: null,
        responseOrder: ['remote_shadow_model'],
        hardCaseModel: null,
      },
    },
  };
  const d = resolveRemoteAiRouteShadowV1(
    {data: {mode: 'study'}},
    remote,
  );
  assert.equal(d.routeId, 'study_remote_test');
  assert.deepEqual(d.responseOrder, ['remote_shadow_model']);
  assert.equal(d.shadowOnly, true);
  assert.equal(d.liveProviderOverride, false);
});

test('disabled or malformed remote shadow config falls back to compiled route', () => {
  const disabled = resolveRemoteAiRouteShadowV1(
    {data: {mode: 'study'}},
    {shadowEnabled: false, modes: {}},
  );
  assert.equal(disabled.routeId, 'study_v1');

  const malformed = resolveRemoteAiRouteShadowV1(
    {data: {mode: 'plantao'}},
    {
      shadowEnabled: true,
      modes: {plantao: {routeId: '', responseOrder: []}},
    },
  );
  assert.equal(malformed.routeId, 'plantao_v1');
  assert.equal(malformed.liveProviderOverride, false);
});

test('remote shadowEnabled false is a real telemetry kill switch', () => {
  const previous = process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED;
  process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED = 'true';

  try {
    assert.equal(
      shouldEmitRemoteAiRouteShadowV1({
        shadowEnabled: false,
      }),
      false,
    );
    assert.equal(
      shouldEmitRemoteAiRouteShadowV1({
        shadowEnabled: true,
      }),
      true,
    );
  } finally {
    if (previous == null) {
      delete process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED;
    } else {
      process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED = previous;
    }
  }
});

test('server env kill switch overrides remote shadowEnabled true', () => {
  const previous = process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED;
  process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED = 'false';

  try {
    assert.equal(
      shouldEmitRemoteAiRouteShadowV1({
        shadowEnabled: true,
      }),
      false,
    );
  } finally {
    if (previous == null) {
      delete process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED;
    } else {
      process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED = previous;
    }
  }
});

test('cold start with no remote config keeps shadow telemetry off', () => {
  const previous = process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED;
  process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED = 'true';

  try {
    assert.equal(
      shouldEmitRemoteAiRouteShadowV1(null),
      false,
    );
    assert.equal(
      shouldEmitRemoteAiRouteShadowV1(undefined),
      false,
    );
    assert.equal(
      shouldEmitRemoteAiRouteShadowV1({}),
      false,
    );
  } finally {
    if (previous == null) {
      delete process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED;
    } else {
      process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED = previous;
    }
  }
});

test('shadow telemetry starts only after remote shadowEnabled true is loaded', () => {
  const previous = process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED;
  process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED = 'true';

  try {
    assert.equal(
      shouldEmitRemoteAiRouteShadowV1(null),
      false,
    );
    assert.equal(
      shouldEmitRemoteAiRouteShadowV1({shadowEnabled: true}),
      true,
    );
  } finally {
    if (previous == null) {
      delete process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED;
    } else {
      process.env.AI_CONTROL_PLANE_SHADOW_V1_ENABLED = previous;
    }
  }
});
