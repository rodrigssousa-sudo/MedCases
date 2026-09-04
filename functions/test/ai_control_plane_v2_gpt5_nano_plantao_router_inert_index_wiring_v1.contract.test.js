'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const indexPath =
  path.resolve(__dirname, '..', 'index.js');

const source =
  fs.readFileSync(indexPath, 'utf8');

const executor = require(
  '../lib/ai_control_plane_v2/gpt5_nano_plantao_router_real_shadow_v1'
);

assert.strictEqual(
  (
    source.match(
      /gpt5_nano_plantao_router_real_shadow_v1/g
    ) || []
  ).length,
  1
);

assert.strictEqual(
  (
    source.match(
      /runGpt5NanoPlantaoRouterRealShadow\(\{/g
    ) || []
  ).length,
  1
);

assert.strictEqual(
  (
    source.match(
      /buildGpt5NanoRealShadowTelemetry\(/g
    ) || []
  ).length,
  1
);

assert.strictEqual(
  /await\s+runGpt5NanoPlantaoRouterRealShadow/.test(
    source
  ),
  false
);

assert.strictEqual(
  /return\s+runGpt5NanoPlantaoRouterRealShadow/.test(
    source
  ),
  false
);

// Shadow result must never be returned to the user.
assert.strictEqual(
  /res\.(?:json|send|status)[\s\S]{0,180}shadowResult/.test(
    source
  ),
  false
);

assert.strictEqual(
  /shadowResult[\s\S]{0,180}res\.(?:json|send|status)/.test(
    source
  ),
  false
);

// Shadow result must never select the live provider/model.
assert.strictEqual(
  /shadowResult[\s\S]{0,180}(?:provider|model)\s*=/.test(
    source
  ),
  false
);

// Errors are swallowed into fixed metadata only.
assert.strictEqual(
  source.includes(
    "code: 'nano_shadow_observer_failed'"
  ),
  true
);

assert.strictEqual(
  source.includes(
    'userResponseAuthority: false'
  ),
  true
);

assert.strictEqual(
  source.includes(
    'liveAuthorityChanged: false'
  ),
  true
);

assert.strictEqual(
  source.includes(
    'telemetryOnly: true'
  ),
  true
);

// No source code opens either gate.
assert.strictEqual(
  /AI_GPT5_NANO_REAL_SHADOW_ENABLED\s*=\s*['"]?true/.test(
    source
  ),
  false
);

assert.strictEqual(
  /gpt5_nano_real_shadow_v1\s*:\s*true/.test(
    source
  ),
  false
);

assert.strictEqual(
  /shadowProviderCalls[\s\S]{0,250}gpt5Nano[\s\S]{0,120}enabled\s*:\s*true/.test(
    source
  ),
  false
);

// The executor itself still enforces hard server gate first.
{
  let fetchCount=0;

  const returnPromise =
    executor.runGpt5NanoPlantaoRouterRealShadow({
      config: {
        featureFlags: {
          gpt5_nano_real_shadow_v1: true,
        },
        shadowProviderCalls: {
          gpt5Nano: {
            enabled: true,
            rolloutPercent: 100,
            cohortSalt:
              'contract-test-salt-0001',
          },
        },
      },
      uid: 'synthetic-user',
      mode: 'plantao',
      userMessage: 'synthetic',
      history: [],
      patientContext: null,
      openAiApiKey: 'secret',
      serverEnabled: false,
      fetchFn: async () => {
        fetchCount += 1;
        throw new Error('must_not_execute');
      },
    });

  Promise.resolve(returnPromise)
    .then((result) => {
      assert.strictEqual(fetchCount, 0);
      assert.strictEqual(result.attempted, false);
      assert.strictEqual(
        result.gateReason,
        'server_hard_gate_closed'
      );
      assert.strictEqual(
        result.userResponseAuthority,
        false
      );

      console.log(
        'AI_CONTROL_PLANE_V2_GPT5_NANO_PLANTAO_ROUTER_INERT_INDEX_WIRING=PASS'
      );
      console.log(
        'GPT5_NANO_INDEX_IMPORT_AND_CALLSITE=PASS'
      );
      console.log(
        'GPT5_NANO_SERVER_GATE_CLOSED_ZERO_FETCH=PASS'
      );
      console.log(
        'GPT5_NANO_REMOTE_GATE_SOURCE_OPENING=ABSENT'
      );
      console.log(
        'GPT5_NANO_USER_RESPONSE_AUTHORITY=NONE'
      );
      console.log(
        'GPT5_NANO_LIVE_MODEL_SELECTION_AUTHORITY=NONE'
      );
      console.log(
        'GPT5_NANO_LIVE_ERROR_PATH_AUTHORITY=NONE'
      );
      console.log(
        'GPT5_NANO_SHADOW_RESULT_DESTINATION=METADATA_TELEMETRY_ONLY'
      );
      console.log(
        'PROVIDER_INFERENCE_EXPECTED_WITH_GATES_CLOSED=NO'
      );
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
