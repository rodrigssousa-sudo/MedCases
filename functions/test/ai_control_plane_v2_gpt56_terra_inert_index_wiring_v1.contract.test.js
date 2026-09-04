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

const geminiEnd=
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GEMINI31_PAID_INERT_END',
    lunaBegin
  );

const terraBegin=
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GPT56_TERRA_INERT_BEGIN'
  );

const terraEnd=
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GPT56_TERRA_INERT_END',
    terraBegin
  );

assert.ok(lunaBegin>=0);
assert.ok(lunaEnd>lunaBegin);
assert.ok(geminiEnd>lunaBegin);
assert.ok(terraBegin>geminiEnd);
assert.ok(terraEnd>terraBegin);
assert.ok(terraEnd<lunaEnd);

assert.strictEqual(
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GPT56_TERRA_INERT_BEGIN',
    terraBegin+1
  ),
  -1
);

assert.strictEqual(
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GPT56_TERRA_INERT_END',
    terraEnd+1
  ),
  -1
);

const lineStart=
  source.lastIndexOf('\n',terraBegin);

const local=
  source.slice(
    lineStart>=0 ? lineStart : terraBegin,
    terraEnd
  );

assert.ok(
  local.includes(
    'void runGpt56TerraPlantaoComplexEscalationShadow({'
  )
);

assert.ok(
  local.includes(
    '__terraStabilizedAuthorization.clinicalEscalation'
  )
);

assert.ok(
  local.includes(
    '__terraStabilizedAuthorization.terraAllowed'
  )
);

assert.ok(
  local.includes(
    '__terraStabilizedAuthorization.signalCodes'
  )
);

assert.ok(
  local.includes(
    'buildTerraClinicalEscalationDecisionV1({'
  )
);

assert.ok(
  local.includes(
    'buildServerContextMetricsV1({'
  )
);

assert.ok(
  local.includes(
    '.clinicalEscalationPolicies.terra'
  )
);

assert.ok(
  local.includes(
    'buildTerraClinicalEscalationTelemetry('
  )
);

assert.ok(
  local.includes(
    'buildTerraStabilizedAuthorizationV1({'
  )
);

assert.ok(
  local.includes(
    '.clinicalEscalationStabilization.terra'
  )
);

assert.ok(
  local.includes(
    'buildTerraStabilizationTelemetry('
  )
);


assert.strictEqual(
  local.includes('req.body.clinicalEscalation'),
  false
);

assert.strictEqual(
  local.includes('req.body.terraAllowed'),
  false
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
  local.includes('process.env.OPENAI_API_KEY')
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
    'buildGpt56TerraShadowTelemetry('
  )
);

assert.strictEqual(
  local.includes(
    'await runGpt56TerraPlantaoComplexEscalationShadow'
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
  local.includes('JSON.stringify(terraShadowResult)'),
  false
);

assert.ok(
  local.includes("model: 'gpt-5.6-terra'")
);

assert.ok(
  local.includes("alias: 'plantao_complex'")
);

assert.ok(
  local.includes('userResponseAuthority: false')
);

assert.ok(
  local.includes('liveModelSelectionAuthority: false')
);

assert.ok(
  local.includes('liveErrorPathAuthority: false')
);

assert.ok(
  local.includes('technicalFallbackAuthority: false')
);

assert.ok(
  local.includes('telemetryOnly: true')
);

console.log('GPT56_TERRA_INDEX_IMPORT_AND_CALLSITE=PASS');
console.log('GPT56_TERRA_CALLED_AFTER_LUNA_RESULT=PASS');
console.log('GPT56_TERRA_NOT_NESTED_AS_GEMINI_TECHNICAL_FALLBACK=PASS');
console.log('GPT56_TERRA_CLINICAL_ESCALATION_SIGNAL=SERVER_POLICY_PLUS_STABILIZATION_DECISION');
console.log('GPT56_TERRA_TERRA_ALLOWED_SIGNAL=SERVER_STABILIZATION_AUTHORIZATION');
console.log('GPT56_TERRA_TECHNICAL_FAILURE_NOT_MAPPED_TO_ESCALATION=PASS');
console.log('GPT56_TERRA_FIRE_AND_FORGET_NO_AWAIT=PASS');
console.log('GPT56_TERRA_NO_RES_WRITE=PASS');
console.log('GPT56_TERRA_NO_REQ_MUTATION=PASS');
console.log('GPT56_TERRA_SERVER_KEY_SOURCE=PASS');
console.log('GPT56_TERRA_SERVER_POLICY_SOURCE=PASS');
console.log('GPT56_TERRA_CLIENT_PROTECTED_PROJECTION=NONE');
console.log('GPT56_TERRA_RAW_SHADOW_RESULT_LOGGING=NO');
console.log('GPT56_TERRA_USER_RESPONSE_AUTHORITY=NONE');
console.log('GPT56_TERRA_LIVE_MODEL_SELECTION_AUTHORITY=NONE');
console.log('GPT56_TERRA_LIVE_ERROR_PATH_AUTHORITY=NONE');
console.log('GPT56_TERRA_TECHNICAL_FALLBACK_AUTHORITY=NONE');
console.log('GPT56_TERRA_INERT_INDEX_WIRING=PASS');
