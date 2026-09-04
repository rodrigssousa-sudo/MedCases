'use strict';

const fs=require('fs');
const path=require('path');
const assert=require('assert');

const indexPath=path.join(__dirname,'..','index.js');
const source=fs.readFileSync(indexPath,'utf8');

const lunaBegin=
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GPT56_LUNA_INERT_BEGIN'
  );

const lunaEnd=
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GPT56_LUNA_INERT_END',
    lunaBegin
  );

const geminiBegin=
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GEMINI31_PAID_INERT_BEGIN'
  );

const geminiEnd=
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GEMINI31_PAID_INERT_END',
    geminiBegin
  );

assert.ok(lunaBegin>=0);
assert.ok(lunaEnd>lunaBegin);
assert.ok(geminiBegin>lunaBegin);
assert.ok(geminiEnd>geminiBegin);
assert.ok(geminiEnd<lunaEnd);

assert.strictEqual(
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GEMINI31_PAID_INERT_BEGIN',
    geminiBegin+1
  ),
  -1
);

assert.strictEqual(
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GEMINI31_PAID_INERT_END',
    geminiEnd+1
  ),
  -1
);

const lineStart=
  source.lastIndexOf(
    '\n',
    geminiBegin
  );

const local=
  source.slice(
    lineStart>=0 ? lineStart : geminiBegin,
    geminiEnd
  );

assert.ok(
  local.includes(
    'void runGemini31FlashLitePaidCrossProviderShadow({'
  )
);

assert.ok(
  local.includes(
    'shadowResult.technicalFailure === true'
  )
);

assert.ok(
  local.includes(
    'shadowResult.failureClass'
  )
);

assert.ok(
  local.includes(
    'upstreamClinicalEscalation: false'
  )
);

assert.ok(
  local.includes(
    'process.env.GEMINI_PAID_API_KEY'
  )
);

assert.ok(
  local.includes(
    'buildOpenAiProtectedClinicalDataPolicyFromEnv('
  )
);

assert.ok(
  local.includes(
    'protectedClinicalProjection: __protectedClinicalProjectionV2'
  )
);

assert.ok(
  local.includes(
    'buildGemini31PaidShadowTelemetry('
  )
);

assert.strictEqual(
  local.includes(
    'await runGemini31FlashLitePaidCrossProviderShadow'
  ),
  false
);

assert.strictEqual(
  /res\.(?:status|json|send|write|end)\s*\(/.test(local),
  false
);

const reqMutationPattern=
  /req\.[A-Za-z0-9_$.[\]'"]+\s*(?:\+\+|--|\+=|-=|\*=|\/=|%=|\*\*=|&&=|\|\|=|\?\?=|=(?!=|>))/;

assert.strictEqual(
  reqMutationPattern.test(local),
  false
);

assert.strictEqual(
  local.includes('JSON.stringify(geminiShadowResult)'),
  false
);

assert.ok(
  local.includes(
    "model: 'gemini-3.1-flash-lite'"
  )
);

assert.ok(
  local.includes(
    "alias: 'plantao_cross_provider'"
  )
);

assert.ok(
  local.includes(
    'userResponseAuthority: false'
  )
);

assert.ok(
  local.includes(
    'liveModelSelectionAuthority: false'
  )
);

assert.ok(
  local.includes(
    'liveErrorPathAuthority: false'
  )
);

assert.ok(
  local.includes(
    'clinicalEscalationAuthority: false'
  )
);

assert.ok(
  local.includes(
    'terraRoutingAuthority: false'
  )
);

assert.ok(
  local.includes(
    'telemetryOnly: true'
  )
);

console.log('GEMINI31_PAID_INDEX_IMPORT_AND_CALLSITE=PASS');
console.log('GEMINI31_PAID_NESTED_AFTER_LUNA_RESULT=PASS');
console.log('GEMINI31_PAID_UPSTREAM_TECHNICAL_FAILURE_SOURCE=LUNA_ONLY');
console.log('GEMINI31_PAID_CLINICAL_ESCALATION_ACTIVATOR=NO');
console.log('GEMINI31_PAID_FIRE_AND_FORGET_NO_AWAIT=PASS');
console.log('GEMINI31_PAID_NO_RES_WRITE=PASS');
console.log('GEMINI31_PAID_NO_REQ_MUTATION=PASS');
console.log('GEMINI31_PAID_SERVER_KEY_SOURCE=PASS');
console.log('GEMINI31_PAID_SERVER_POLICY_SOURCE=PASS');
console.log('GEMINI31_PAID_CLIENT_PROTECTED_PROJECTION=NONE');
console.log('GEMINI31_PAID_RAW_SHADOW_RESULT_LOGGING=NO');
console.log('GEMINI31_PAID_USER_RESPONSE_AUTHORITY=NONE');
console.log('GEMINI31_PAID_LIVE_MODEL_SELECTION_AUTHORITY=NONE');
console.log('GEMINI31_PAID_LIVE_ERROR_PATH_AUTHORITY=NONE');
console.log('GEMINI31_PAID_CLINICAL_ESCALATION_AUTHORITY=NONE');
console.log('GEMINI31_PAID_TERRA_ROUTING_AUTHORITY=NONE');
console.log('GEMINI31_PAID_INERT_INDEX_WIRING=PASS');
