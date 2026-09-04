'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const source =
  fs.readFileSync(
    path.resolve(__dirname, '..', 'index.js'),
    'utf8'
  );

assert.strictEqual(
  (
    source.match(
      /plantao_live_authority_v1/g
    ) || []
  ).length,
  1
);

assert.strictEqual(
  (
    source.match(
      /await\s+executePlantaoLiveAuthorityV1\(\{/g
    ) || []
  ).length,
  1
);

assert.strictEqual(
  source.includes(
    '__v2ParityExecution.gateOpen === true'
  ),
  true
);

assert.strictEqual(
  source.includes(
    'protectedClinicalProjection:\n' +
    '          __protectedClinicalProjectionV2'
  ),
  true
);

assert.strictEqual(
  /protectedClinicalProjection\s*:\s*req\.body/.test(
    source
  ),
  false
);

assert.strictEqual(
  source.includes(
    '__plantaoLiveAuthorityV1.handled === true'
  ),
  true
);

assert.strictEqual(
  source.includes(
    '__plantaoLiveAuthorityV1.eligible === true'
  ),
  true
);

assert.strictEqual(
  source.includes(
    'res.status(200).json(\n' +
    '        __plantaoLiveAuthorityV1.response\n' +
    '      );'
  ),
  true
);

// Existing shadow executors remain fire-and-forget and are not mutated
// into response owners.
for (const call of [
  'void runGpt5NanoPlantaoRouterRealShadow({',
  'void runGpt56LunaPlantaoPrimaryShadow({',
  'void runGemini31FlashLitePaidCrossProviderShadow({',
  'void runGpt56TerraPlantaoComplexEscalationShadow({',
]) {
  assert.strictEqual(
    (
      source.match(
        new RegExp(
          call
            .replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),
          'g'
        )
      ) || []
    ).length,
    1
  );
}

assert.strictEqual(
  source.includes(
    'AI_CONTROL_PLANE_V2_PLANTAO_LIVE_AUTHORITY_V1_BEGIN'
  ),
  true
);

assert.strictEqual(
  source.includes(
    'AI_CONTROL_PLANE_V2_PLANTAO_LIVE_SHADOW_SUPPRESSION_END'
  ),
  true
);

assert.strictEqual(
  source.includes('req.body.liveAuthority'),
  false
);

assert.strictEqual(
  source.includes('req.body.providerAuthority'),
  false
);

// The pre-existing Flutter envelope remains present in the legacy path.
for (const field of [
  'text',
  'model',
  'inputTokensApprox',
  'outputTokensApprox',
  'durationMs',
]) {
  assert.strictEqual(
    source.includes(field),
    true
  );
}

console.log('PLANTAO_LIVE_INDEX_IMPORT=PASS');
console.log('PLANTAO_LIVE_INDEX_AWAIT_HANDOFF=PASS');
console.log('PLANTAO_LIVE_INDEX_SERVER_EXECUTION_GATE=PASS');
console.log('PLANTAO_LIVE_INDEX_V2_PROJECTION=PASS');
console.log('PLANTAO_LIVE_INDEX_CLIENT_AUTHORITY=NONE');
console.log('PLANTAO_LIVE_INDEX_HANDLED_RESPONSE_OWNER=PASS');
console.log('PLANTAO_LIVE_INDEX_SHADOW_SUPPRESSION=PASS');
console.log('PLANTAO_EXISTING_SHADOW_EXECUTORS_PRESERVED=PASS');
console.log('PLANTAO_FLUTTER_ENVELOPE_PRESERVED=PASS');
console.log('PLANTAO_LIVE_AUTHORITY_INDEX_WIRING=PASS');
