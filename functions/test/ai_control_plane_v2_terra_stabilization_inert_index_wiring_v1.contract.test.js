'use strict';

const fs=require('fs');
const path=require('path');
const assert=require('assert');

const source=fs.readFileSync(
  path.join(__dirname,'..','index.js'),
  'utf8'
);

const begin=
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GPT56_TERRA_INERT_BEGIN'
  );

const end=
  source.indexOf(
    'AI_CONTROL_PLANE_V2_GPT56_TERRA_INERT_END',
    begin
  );

assert.ok(begin>=0);
assert.ok(end>begin);

const local=source.slice(begin,end);

assert.ok(
  source.includes(
    "require(\n  './lib/ai_control_plane_v2/terra_escalation_stabilization_v1'\n);"
  )
);

assert.ok(
  local.includes(
    'buildTerraStabilizedAuthorizationV1({'
  )
);

assert.ok(
  local.includes(
    'clinicalDecision:'
  )
);

assert.ok(
  local.includes(
    '__terraEscalationDecision'
  )
);

assert.ok(
  local.includes(
    'serverContextMetrics:'
  )
);

assert.ok(
  local.includes(
    '__terraServerContextMetrics'
  )
);

assert.ok(
  local.includes(
    '__v2ExecutionConfigState.config.shadowProviderCalls.gpt56Terra'
  )
);

assert.ok(
  local.includes(
    '__v2ExecutionConfigState.config.clinicalEscalationStabilization.terra'
  )
);

assert.ok(
  local.includes(
    'buildTerraStabilizationTelemetry('
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

assert.strictEqual(
  local.includes(
    'req.body.terraStabilization'
  ),
  false
);

assert.strictEqual(
  local.includes(
    'req.body.stabilization'
  ),
  false
);

assert.strictEqual(
  local.includes(
    'JSON.stringify(__terraStabilizedAuthorization)'
  ),
  false
);

assert.strictEqual(
  /res\.(?:status|json|send|write|end)\s*\(/.test(local),
  false
);

console.log('TERRA_STABILIZATION_INDEX_IMPORT=PASS');
console.log('TERRA_STABILIZATION_SERVER_POLICY_DECISION_INPUT=PASS');
console.log('TERRA_STABILIZATION_SERVER_CONTEXT_METRICS_INPUT=PASS');
console.log('TERRA_STABILIZATION_TERRA_PROVIDER_CONFIG_SERVER_SOURCE=PASS');
console.log('TERRA_STABILIZATION_REMOTE_CONFIG_SERVER_SOURCE=PASS');
console.log('TERRA_STABILIZATION_CLIENT_AUTHORITY=NONE');
console.log('TERRA_STABILIZATION_SAFE_TELEMETRY_BUILDER_ONLY=PASS');
console.log('TERRA_PROVIDER_RECEIVES_STABILIZED_AUTHORIZATION_ONLY=PASS');
console.log('TERRA_STABILIZATION_INERT_INDEX_WIRING=PASS');
