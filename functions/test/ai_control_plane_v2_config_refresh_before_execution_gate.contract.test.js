'use strict';

const assert = require('assert');

const {
  DEFAULT_CACHE_TTL_MS,
  getCachedV2ConfigState,
  getV2ConfigStateForExecution,
  resetV2ConfigCacheForTests,
} = require('../lib/ai_control_plane_v2/config_reader');

const {
  makeSafeBootstrapConfig,
} = require('../lib/ai_control_plane_v2/config_defaults');

const {
  resolveLegacyParityExecutionGate,
} = require('../lib/ai_control_plane_v2/legacy_parity_execution_gate');

function clone(v) {
  return JSON.parse(JSON.stringify(v));
}

function activeConfig(version = 'AI_CONFIG_TEST_0100') {
  // makeSafeBootstrapConfig() is intentionally deeply frozen.
  // Clone it before constructing a synthetic mutable remote config.
  const c = clone(makeSafeBootstrapConfig());

  c.configVersion = version;
  c.enabled = true;
  c.legacyParityMode = false;
  c.clientOverrideAllowed = false;
  c.rollout = {
    ...(c.rollout || {}),
    enabled: true,
    percent: 100,
    cohortSaltVersion: 'test-salt-v1',
  };
  c.featureFlags = {
    ...(c.featureFlags || {}),
    legacy_parity_execution_v2: true,
  };

  return c;
}

function fakeFirestore({
  version = 'AI_CONFIG_TEST_0100',
  delayMs = 0,
  failPointer = false,
} = {}) {
  let readCount = 0;
  const config = activeConfig(version);

  const db = {
    collection(collectionName) {
      return {
        doc(documentName) {
          return {
            async get() {
              readCount += 1;

              if (delayMs > 0) {
                await new Promise((resolve) => setTimeout(resolve, delayMs));
              }

              if (
                collectionName === 'ai_config' &&
                documentName === 'current'
              ) {
                if (failPointer) {
                  throw new Error('synthetic_pointer_failure');
                }

                return {
                  exists: true,
                  data() {
                    return {
                      schemaVersion: config.schemaVersion,
                      activeVersion: version,
                    };
                  },
                };
              }

              if (
                collectionName === 'ai_config_versions' &&
                documentName === version
              ) {
                return {
                  exists: true,
                  data() {
                    return clone(config);
                  },
                };
              }

              return {
                exists: false,
                data() {
                  return undefined;
                },
              };
            },
          };
        },
      };
    },
  };

  return {
    db,
    getReadCount() {
      return readCount;
    },
  };
}

function gateFor(state) {
  return resolveLegacyParityExecutionGate(
    {
      userMessage: 'SENSITIVE_TEXT_NOT_TELEMETRY',
      systemPrompt: 'SENSITIVE_PROMPT_NOT_TELEMETRY',
      history: [],
      mode: 'study',
    },
    {
      uid: 'synthetic-authenticated-user',
      geminiPaidModel: 'gemini-2.5-flash',
      env: {
        AI_CONTROL_PLANE_V2_LEGACY_PARITY_EXECUTION_ENABLED: 'true',
      },
      configState: state,
    }
  );
}

(async()=>{
  assert.strictEqual(DEFAULT_CACHE_TTL_MS, 30000);

  // 1. Keep the original safety property: a cold/expired synchronous cache read
  // never grants live execution authority.
  resetV2ConfigCacheForTests();

  {
    const stale = getCachedV2ConfigState(1000);
    assert.strictEqual(stale.executionAllowed, false);
  }

  // 2. Cold cache: execution path MUST await a real refresh before evaluating
  // the gate. A valid remote 100% config then opens V2 on the same request.
  {
    const fs = fakeFirestore();

    const state = await getV2ConfigStateForExecution({
      firestore: fs.db,
      env: {
        AI_CONTROL_PLANE_V2_ENABLED: 'true',
      },
      nowMs: 1000,
      ttlMs: 30000,
    });

    assert.strictEqual(state.executionAllowed, true);
    assert.strictEqual(state.pointerVersion, 'AI_CONFIG_TEST_0100');
    assert.strictEqual(fs.getReadCount(), 2);

    const gate = gateFor(state);
    assert.strictEqual(gate.authority, 'v2_legacy_parity');
    assert.strictEqual(gate.gateOpen, true);
  }

  // 3. Hot cache: no additional Firestore read.
  {
    const fs = fakeFirestore();

    resetV2ConfigCacheForTests();

    const first = await getV2ConfigStateForExecution({
      firestore: fs.db,
      env: {
        AI_CONTROL_PLANE_V2_ENABLED: 'true',
      },
      nowMs: 1000,
      ttlMs: 30000,
    });

    assert.strictEqual(first.executionAllowed, true);
    assert.strictEqual(fs.getReadCount(), 2);

    const second = await getV2ConfigStateForExecution({
      firestore: fs.db,
      env: {
        AI_CONTROL_PLANE_V2_ENABLED: 'true',
      },
      nowMs: 2000,
      ttlMs: 30000,
    });

    assert.strictEqual(second.executionAllowed, true);
    assert.strictEqual(fs.getReadCount(), 2);
  }

  // 4. Expired cache: do NOT hand the transient executionAllowed=false state
  // to the live gate. Await refresh first; valid config remains V2-open.
  {
    const fs = fakeFirestore();

    resetV2ConfigCacheForTests();

    const initial = await getV2ConfigStateForExecution({
      firestore: fs.db,
      env: {
        AI_CONTROL_PLANE_V2_ENABLED: 'true',
      },
      nowMs: 1000,
      ttlMs: 30000,
    });

    assert.strictEqual(initial.executionAllowed, true);
    assert.strictEqual(fs.getReadCount(), 2);

    const rawExpired = getCachedV2ConfigState(31001);
    assert.strictEqual(rawExpired.executionAllowed, false);

    const refreshed = await getV2ConfigStateForExecution({
      firestore: fs.db,
      env: {
        AI_CONTROL_PLANE_V2_ENABLED: 'true',
      },
      nowMs: 31001,
      ttlMs: 30000,
    });

    assert.strictEqual(refreshed.executionAllowed, true);
    assert.strictEqual(fs.getReadCount(), 4);

    const gate = gateFor(refreshed);
    assert.strictEqual(gate.gateOpen, true);
    assert.strictEqual(gate.gateReason, 'open');
  }

  // 5. Single-flight remains effective. Two simultaneous requests after expiry
  // wait for the same refresh instead of doubling Firestore reads.
  {
    const fs = fakeFirestore({ delayMs: 15 });

    resetV2ConfigCacheForTests();

    const [a,b] = await Promise.all([
      getV2ConfigStateForExecution({
        firestore: fs.db,
        env: {
          AI_CONTROL_PLANE_V2_ENABLED: 'true',
        },
        nowMs: 5000,
        ttlMs: 30000,
      }),
      getV2ConfigStateForExecution({
        firestore: fs.db,
        env: {
          AI_CONTROL_PLANE_V2_ENABLED: 'true',
        },
        nowMs: 5000,
        ttlMs: 30000,
      }),
    ]);

    assert.strictEqual(a.executionAllowed, true);
    assert.strictEqual(b.executionAllowed, true);
    assert.strictEqual(fs.getReadCount(), 2);
  }

  // 6. Refresh failure stays fail-closed; there is no last-known-good bypass.
  {
    const fs = fakeFirestore({ failPointer: true });

    resetV2ConfigCacheForTests();

    const state = await getV2ConfigStateForExecution({
      firestore: fs.db,
      env: {
        AI_CONTROL_PLANE_V2_ENABLED: 'true',
      },
      nowMs: 9000,
      ttlMs: 30000,
    });

    assert.strictEqual(state.executionAllowed, false);

    const gate = gateFor(state);
    assert.strictEqual(gate.gateOpen, false);
    assert.strictEqual(gate.authority, 'legacy_v1');
    assert.strictEqual(gate.gateReason, 'config_execution_not_allowed');
  }

  // 7. Server config hard gate OFF also remains fail-closed.
  {
    const fs = fakeFirestore();

    resetV2ConfigCacheForTests();

    const state = await getV2ConfigStateForExecution({
      firestore: fs.db,
      env: {
        AI_CONTROL_PLANE_V2_ENABLED: 'false',
      },
      nowMs: 11000,
      ttlMs: 30000,
    });

    assert.strictEqual(state.executionAllowed, false);
  }

  console.log('AI_CONTROL_PLANE_V2_CONFIG_REFRESH_BEFORE_EXECUTION_GATE=PASS');
  console.log('FROZEN_BOOTSTRAP_TEST_FIX=PASS');
  console.log('COLD_CACHE_AWAITS_REFRESH=PASS');
  console.log('HOT_CACHE_ZERO_EXTRA_FIRESTORE_READ=PASS');
  console.log('EXPIRED_CACHE_AWAITS_REFRESH_BEFORE_LIVE_GATE=PASS');
  console.log('REFRESH_SINGLE_FLIGHT_PRESERVED=PASS');
  console.log('REFRESH_FAILURE_FAIL_CLOSED=PASS');
  console.log('EXPIRED_LAST_KNOWN_GOOD_NOT_USED_AS_AUTHORITY=PASS');
  console.log('CACHE_TTL_30_SECONDS_PRESERVED=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
