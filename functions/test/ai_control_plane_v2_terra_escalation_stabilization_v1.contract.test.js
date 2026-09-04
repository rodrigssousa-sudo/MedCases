'use strict';

const assert=require('assert');

const {
  buildServerContextMetricsV1,
  buildTerraClinicalEscalationDecisionV1,
}=require('../lib/ai_control_plane_v2/terra_clinical_escalation_policy_v1');

const {
  STABILIZATION_VERSION,
  COST_GUARD_VERSION,
  sanitizeTerraStabilizationConfig,
  estimateTerraInputTokensFromServerMetricsV1,
  estimateTerraWorstCaseCostNanoUsdV1,
  buildTerraStabilizedAuthorizationV1,
  buildTerraStabilizationTelemetry,
}=require('../lib/ai_control_plane_v2/terra_escalation_stabilization_v1');

function policy({
  enabled=true,
  terraAllowed=true,
  minScore=4,
}={}){
  return {
    enabled,
    terraAllowed,
    minScore,
    thresholds:{
      uncertainties:2,
      safetyFlags:2,
      differential:4,
      historyTurns:12,
      userMessageChars:6000,
      patientContextFieldCount:12,
    },
  };
}

function luna({
  confidence='high',
  needsMoreInformation=false,
  uncertainties=[],
  safetyFlags=[],
  differential=[],
  technicalFailure=false,
}={}){
  return {
    completed:technicalFailure ? false : true,
    responseValid:technicalFailure ? false : true,
    technicalFailure,
    failureClass:
      technicalFailure
        ? 'technical_timeout'
        : null,
    parsedClinicalResult:
      technicalFailure
        ? null
        : {
            clinical_summary:'RAW_SYNTHETIC_SUMMARY',
            differential,
            critical_actions:[],
            safety_flags:safetyFlags,
            uncertainties,
            confidence,
            needs_more_information:
              needsMoreInformation,
          },
  };
}

function metrics({
  chars=0,
  turns=0,
  fields=0,
}={}){
  return {
    version:'server_context_metrics_v1',
    userMessageChars:chars,
    historyTurns:turns,
    patientContextFieldCount:fields,
  };
}

function decision({
  lunaResult,
  serverMetrics,
  policyConfig=policy(),
}){
  return buildTerraClinicalEscalationDecisionV1({
    mode:'plantao',
    lunaResult,
    serverContextMetrics:serverMetrics,
    policyConfig,
  });
}

assert.strictEqual(
  STABILIZATION_VERSION,
  'medcases_terra_escalation_stabilization_v1'
);

assert.strictEqual(
  COST_GUARD_VERSION,
  'medcases_terra_preflight_cost_guard_v1'
);

const sanitized=
  sanitizeTerraStabilizationConfig({
    enabled:true,
    maxEstimatedInputTokens:999999,
    maxOutputTokens:999999,
    maxEstimatedCostNanoUsd:9999999999,
  });

assert.strictEqual(sanitized.enabled,true);
assert.strictEqual(
  sanitized.maxEstimatedInputTokens,
  272000
);
assert.strictEqual(
  sanitized.maxOutputTokens,
  16384
);
assert.strictEqual(
  sanitized.maxEstimatedCostNanoUsd,
  1000000000
);

const lowConfidence=
  decision({
    lunaResult:luna({
      confidence:'low',
    }),
    serverMetrics:metrics(),
  });

assert.strictEqual(lowConfidence.score,4);
assert.strictEqual(
  lowConfidence.clinicalEscalation,
  true
);
assert.strictEqual(
  lowConfidence.terraAllowed,
  true
);

const uncertaintySafety=
  decision({
    lunaResult:luna({
      confidence:'medium',
      uncertainties:['u1','u2'],
      safetyFlags:['s1','s2'],
    }),
    serverMetrics:metrics(),
  });

assert.strictEqual(uncertaintySafety.score,4);
assert.strictEqual(
  uncertaintySafety.clinicalEscalation,
  true
);

const contextBoundary=
  decision({
    lunaResult:luna({
      confidence:'medium',
    }),
    serverMetrics:metrics({
      chars:6000,
      turns:12,
      fields:12,
    }),
  });

assert.strictEqual(contextBoundary.score,4);
assert.deepStrictEqual(
  [...contextBoundary.signalCodes].sort(),
  [
    'dense_patient_context',
    'large_context',
    'longitudinal_complexity',
  ].sort()
);

const justBelowContextBoundary=
  decision({
    lunaResult:luna({
      confidence:'medium',
    }),
    serverMetrics:metrics({
      chars:5999,
      turns:11,
      fields:11,
    }),
  });

assert.strictEqual(
  justBelowContextBoundary.score,
  0
);
assert.strictEqual(
  justBelowContextBoundary.clinicalEscalation,
  false
);

const technicalFailure=
  decision({
    lunaResult:luna({
      confidence:'low',
      technicalFailure:true,
    }),
    serverMetrics:metrics({
      chars:12000,
      turns:64,
      fields:128,
    }),
  });

assert.strictEqual(
  technicalFailure.clinicalEscalation,
  false
);
assert.strictEqual(
  technicalFailure.terraAllowed,
  false
);

const estimate=
  estimateTerraInputTokensFromServerMetricsV1(
    metrics({
      chars:6000,
      turns:12,
      fields:12,
    })
  );

assert.strictEqual(estimate,4700);

const worst4096=
  estimateTerraWorstCaseCostNanoUsdV1({
    estimatedInputTokens:estimate,
    maxOutputTokens:4096,
  });

assert.strictEqual(worst4096,58552000);

const disabled=
  buildTerraStabilizedAuthorizationV1({
    clinicalDecision:contextBoundary,
    serverContextMetrics:
      metrics({
        chars:6000,
        turns:12,
        fields:12,
      }),
    terraProviderConfig:{
      maxOutputTokens:4096,
    },
    stabilizationConfig:{
      enabled:false,
    },
  });

assert.strictEqual(disabled.terraAllowed,false);
assert.strictEqual(
  disabled.providerCallAllowed,
  false
);
assert.strictEqual(
  disabled.gateReason,
  'stabilization_disabled'
);

const current8192Blocked=
  buildTerraStabilizedAuthorizationV1({
    clinicalDecision:contextBoundary,
    serverContextMetrics:
      metrics({
        chars:6000,
        turns:12,
        fields:12,
      }),
    terraProviderConfig:{
      maxOutputTokens:8192,
    },
    stabilizationConfig:{
      enabled:true,
      maxEstimatedInputTokens:30000,
      maxOutputTokens:4096,
      maxEstimatedCostNanoUsd:60000000,
    },
  });

assert.strictEqual(
  current8192Blocked.providerCallAllowed,
  false
);
assert.strictEqual(
  current8192Blocked.terraAllowed,
  false
);
assert.strictEqual(
  current8192Blocked.gateReason,
  'provider_max_output_exceeds_cost_guard'
);

const stabilized4096Allowed=
  buildTerraStabilizedAuthorizationV1({
    clinicalDecision:contextBoundary,
    serverContextMetrics:
      metrics({
        chars:6000,
        turns:12,
        fields:12,
      }),
    terraProviderConfig:{
      maxOutputTokens:4096,
    },
    stabilizationConfig:{
      enabled:true,
      maxEstimatedInputTokens:30000,
      maxOutputTokens:4096,
      maxEstimatedCostNanoUsd:60000000,
    },
  });

assert.strictEqual(
  stabilized4096Allowed.providerCallAllowed,
  true
);
assert.strictEqual(
  stabilized4096Allowed.terraAllowed,
  true
);
assert.strictEqual(
  stabilized4096Allowed.gateReason,
  'stabilized_clinical_escalation_allowed'
);
assert.strictEqual(
  stabilized4096Allowed.estimatedWorstCaseCostNanoUsd,
  58552000
);

const costBlocked=
  buildTerraStabilizedAuthorizationV1({
    clinicalDecision:lowConfidence,
    serverContextMetrics:
      metrics({
        chars:12000,
        turns:20,
        fields:20,
      }),
    terraProviderConfig:{
      maxOutputTokens:4096,
    },
    stabilizationConfig:{
      enabled:true,
      maxEstimatedInputTokens:30000,
      maxOutputTokens:4096,
      maxEstimatedCostNanoUsd:50000000,
    },
  });

assert.strictEqual(
  costBlocked.providerCallAllowed,
  false
);
assert.strictEqual(
  costBlocked.gateReason,
  'estimated_cost_cap_exceeded'
);

const noClinicalAuthorization=
  buildTerraStabilizedAuthorizationV1({
    clinicalDecision:justBelowContextBoundary,
    serverContextMetrics:
      metrics({
        chars:5999,
        turns:11,
        fields:11,
      }),
    terraProviderConfig:{
      maxOutputTokens:4096,
    },
    stabilizationConfig:{
      enabled:true,
    },
  });

assert.strictEqual(
  noClinicalAuthorization.providerCallAllowed,
  false
);
assert.strictEqual(
  noClinicalAuthorization.gateReason,
  'clinical_policy_not_authorized'
);

const telemetry=
  buildTerraStabilizationTelemetry(
    stabilized4096Allowed
  );

const telemetryText=
  JSON.stringify(telemetry);

assert.strictEqual(
  telemetryText.includes('RAW_SYNTHETIC_SUMMARY'),
  false
);

assert.strictEqual(
  Object.prototype.hasOwnProperty.call(
    telemetry,
    'userMessage'
  ),
  false
);

assert.strictEqual(
  Object.prototype.hasOwnProperty.call(
    telemetry,
    'patientContext'
  ),
  false
);

assert.strictEqual(
  Object.prototype.hasOwnProperty.call(
    telemetry,
    'uid'
  ),
  false
);

assert.strictEqual(
  telemetry.userResponseAuthority,
  false
);
assert.strictEqual(
  telemetry.liveModelSelectionAuthority,
  false
);
assert.strictEqual(
  telemetry.liveErrorPathAuthority,
  false
);
assert.strictEqual(
  telemetry.technicalFallbackAuthority,
  false
);
assert.strictEqual(
  telemetry.telemetryOnly,
  true
);

console.log('TERRA_STABILIZATION_VERSION=PASS');
console.log('TERRA_COST_GUARD_VERSION=PASS');
console.log('TERRA_THRESHOLD_LOW_CONFIDENCE_SCORE4=PASS');
console.log('TERRA_THRESHOLD_UNCERTAINTY_PLUS_SAFETY_SCORE4=PASS');
console.log('TERRA_THRESHOLD_CONTEXT_COMPLEXITY_SCORE4=PASS');
console.log('TERRA_THRESHOLD_JUST_BELOW_CONTEXT_BOUNDARY=NO_ESCALATION');
console.log('TERRA_TECHNICAL_FAILURE_ZERO_ESCALATION=PASS');
console.log('TERRA_INPUT_TOKEN_PREFLIGHT_ESTIMATE=PASS');
console.log('TERRA_WORST_CASE_COST_4096_EXACT_NANOUSD=PASS');
console.log('TERRA_COST_GUARD_DEFAULT_DISABLED_FAIL_CLOSED=PASS');
console.log('TERRA_CURRENT_8192_MAX_OUTPUT_BLOCKED_BY_4096_GUARD=PASS');
console.log('TERRA_STABILIZED_4096_MAX_OUTPUT_UNDER_006USD_ALLOWED=PASS');
console.log('TERRA_ESTIMATED_COST_CAP_BLOCK=PASS');
console.log('TERRA_CLINICAL_POLICY_AUTHORIZATION_REQUIRED=PASS');
console.log('TERRA_STABILIZATION_RAW_CLINICAL_TELEMETRY=ABSENT');
console.log('TERRA_STABILIZATION_RAW_UID_TELEMETRY=ABSENT');
console.log('TERRA_STABILIZATION_USER_RESPONSE_AUTHORITY=NONE');
console.log('TERRA_STABILIZATION_LIVE_MODEL_SELECTION_AUTHORITY=NONE');
console.log('TERRA_STABILIZATION_LIVE_ERROR_PATH_AUTHORITY=NONE');
console.log('TERRA_STABILIZATION_TECHNICAL_FALLBACK_AUTHORITY=NONE');
console.log('TERRA_ESCALATION_THRESHOLDS_COST_GUARD_TELEMETRY_STABILIZATION=PASS');
