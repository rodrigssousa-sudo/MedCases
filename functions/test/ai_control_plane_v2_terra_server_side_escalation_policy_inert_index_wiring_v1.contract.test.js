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
    "require(\n  './lib/ai_control_plane_v2/terra_clinical_escalation_policy_v1'\n);"
  )
);

assert.ok(
  local.includes(
    'buildServerContextMetricsV1({'
  )
);

assert.ok(
  local.includes(
    'buildTerraClinicalEscalationDecisionV1({'
  )
);

assert.ok(
  local.includes(
    'buildTerraClinicalEscalationTelemetry('
  )
);

assert.ok(
  local.includes(
    '__v2ExecutionConfigState.config.clinicalEscalationPolicies.terra'
  )
);

assert.ok(
  local.includes(
    'lunaResult: shadowResult'
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
    'req.body.clinicalEscalation'
  ),
  false
);

assert.strictEqual(
  local.includes(
    'req.body.terraAllowed'
  ),
  false
);

assert.strictEqual(
  local.includes(
    'JSON.stringify(__terraEscalationDecision)'
  ),
  false
);

assert.strictEqual(
  local.includes(
    'clinicalEscalation: shadowResult.technicalFailure'
  ),
  false
);

assert.ok(
  local.includes(
    "protectedClinicalProjection: __protectedClinicalProjectionV2"
  )
);

assert.strictEqual(
  /res\.(?:status|json|send|write|end)\s*\(/.test(local),
  false
);

console.log('TERRA_POLICY_INDEX_IMPORT=PASS');
console.log('TERRA_POLICY_SERVER_CONTEXT_METRICS_OWNER=PASS');
console.log('TERRA_POLICY_LUNA_STRUCTURED_RESULT_OWNER=PASS');
console.log('TERRA_POLICY_REMOTE_CONFIG_SOURCE=PASS');
console.log('TERRA_POLICY_CLIENT_CLINICAL_ESCALATION_AUTHORITY=NONE');
console.log('TERRA_POLICY_CLIENT_TERRA_ALLOWED_AUTHORITY=NONE');
console.log('TERRA_POLICY_TECHNICAL_FAILURE_NOT_MAPPED_TO_ESCALATION=PASS');
console.log('TERRA_POLICY_SAFE_TELEMETRY_BUILDER_ONLY=PASS');
console.log('TERRA_POLICY_PROVIDER_CALL_AUTHORITY=NONE');
console.log('TERRA_SERVER_SIDE_ESCALATION_POLICY_INERT_INDEX_WIRING=PASS');
