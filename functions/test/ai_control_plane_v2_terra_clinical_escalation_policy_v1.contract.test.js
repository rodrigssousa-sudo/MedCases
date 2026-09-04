'use strict';

const assert=require('assert');

const {
  POLICY_VERSION,
  SERVER_CONTEXT_METRICS_VERSION,
  sanitizeTerraEscalationPolicyConfig,
  buildServerContextMetricsV1,
  buildTerraClinicalEscalationDecisionV1,
  buildTerraClinicalEscalationTelemetry,
}=require('../lib/ai_control_plane_v2/terra_clinical_escalation_policy_v1');

function policy({
  enabled=true,
  terraAllowed=true,
  minScore=4,
  thresholds={},
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
      ...thresholds,
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
  completed=true,
  responseValid=true,
}={}){
  return {
    completed,
    responseValid,
    technicalFailure,
    failureClass:
      technicalFailure
        ? 'technical_timeout'
        : null,
    parsedClinicalResult:{
      clinical_summary:'RAW_LUNA_SUMMARY_SENTINEL',
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

const emptyContext=
  buildServerContextMetricsV1({
    userMessage:'',
    history:[],
    patientContext:{},
  });

assert.strictEqual(
  POLICY_VERSION,
  'medcases_terra_clinical_escalation_policy_v1'
);

assert.strictEqual(
  SERVER_CONTEXT_METRICS_VERSION,
  'server_context_metrics_v1'
);

const sanitized=
  sanitizeTerraEscalationPolicyConfig({
    enabled:true,
    terraAllowed:true,
    minScore:999,
    thresholds:{
      historyTurns:999,
      userMessageChars:-10,
    },
  });

assert.strictEqual(sanitized.enabled,true);
assert.strictEqual(sanitized.terraAllowed,true);
assert.strictEqual(sanitized.minScore,20);
assert.strictEqual(
  sanitized.thresholds.historyTurns,
  64
);
assert.strictEqual(
  sanitized.thresholds.userMessageChars,
  500
);

const metrics=
  buildServerContextMetricsV1({
    userMessage:'X'.repeat(7000),
    history:new Array(14).fill(
      'RAW_HISTORY_SENTINEL'
    ),
    patientContext:{
      a:'RAW_A',
      b:'RAW_B',
      c:'RAW_C',
    },
  });

assert.strictEqual(
  metrics.version,
  'server_context_metrics_v1'
);
assert.strictEqual(metrics.userMessageChars,7000);
assert.strictEqual(metrics.historyTurns,14);
assert.strictEqual(metrics.patientContextFieldCount,3);
assert.strictEqual(
  JSON.stringify(metrics).includes(
    'RAW_HISTORY_SENTINEL'
  ),
  false
);
assert.strictEqual(
  JSON.stringify(metrics).includes(
    'RAW_A'
  ),
  false
);

const disabled=
  buildTerraClinicalEscalationDecisionV1({
    mode:'plantao',
    lunaResult:luna({
      confidence:'low',
    }),
    serverContextMetrics:emptyContext,
    policyConfig:policy({
      enabled:false,
      terraAllowed:true,
    }),
    // Explicit spoof fields are ignored because they are not part
    // of the server policy owner's accepted contract.
    clinicalEscalation:true,
    terraAllowed:true,
  });

assert.strictEqual(disabled.clinicalEscalation,false);
assert.strictEqual(disabled.terraAllowed,false);
assert.strictEqual(
  disabled.gateReason,
  'policy_disabled'
);

const technicalOnly=
  buildTerraClinicalEscalationDecisionV1({
    mode:'plantao',
    lunaResult:luna({
      confidence:'low',
      technicalFailure:true,
      completed:false,
      responseValid:false,
    }),
    serverContextMetrics:metrics,
    policyConfig:policy(),
  });

assert.strictEqual(
  technicalOnly.clinicalEscalation,
  false
);
assert.strictEqual(
  technicalOnly.terraAllowed,
  false
);
assert.strictEqual(
  technicalOnly.gateReason,
  'technical_failure_not_clinical_escalation'
);

const quiet=
  buildTerraClinicalEscalationDecisionV1({
    mode:'plantao',
    lunaResult:luna({
      confidence:'high',
      needsMoreInformation:false,
      uncertainties:[],
      safetyFlags:[],
      differential:[
        'a',
        'b',
      ],
    }),
    serverContextMetrics:emptyContext,
    policyConfig:policy(),
  });

assert.strictEqual(quiet.score,0);
assert.strictEqual(quiet.clinicalEscalation,false);
assert.strictEqual(quiet.terraAllowed,false);
assert.strictEqual(
  quiet.gateReason,
  'clinical_escalation_not_required'
);

const lowConfidenceDeniedByCostPolicy=
  buildTerraClinicalEscalationDecisionV1({
    mode:'plantao',
    lunaResult:luna({
      confidence:'low',
    }),
    serverContextMetrics:emptyContext,
    policyConfig:policy({
      terraAllowed:false,
    }),
  });

assert.strictEqual(
  lowConfidenceDeniedByCostPolicy.score,
  4
);
assert.strictEqual(
  lowConfidenceDeniedByCostPolicy.clinicalEscalation,
  true
);
assert.strictEqual(
  lowConfidenceDeniedByCostPolicy.terraAllowed,
  false
);
assert.strictEqual(
  lowConfidenceDeniedByCostPolicy.gateReason,
  'clinical_escalation_terra_not_allowed'
);

const lowConfidenceAllowed=
  buildTerraClinicalEscalationDecisionV1({
    mode:'plantao',
    lunaResult:luna({
      confidence:'low',
    }),
    serverContextMetrics:emptyContext,
    policyConfig:policy({
      terraAllowed:true,
    }),
  });

assert.strictEqual(
  lowConfidenceAllowed.clinicalEscalation,
  true
);
assert.strictEqual(
  lowConfidenceAllowed.terraAllowed,
  true
);
assert.strictEqual(
  lowConfidenceAllowed.gateReason,
  'clinical_escalation_allowed'
);
assert.ok(
  lowConfidenceAllowed.signalCodes.includes(
    'low_confidence'
  )
);

const multiSignal=
  buildTerraClinicalEscalationDecisionV1({
    mode:'plantao',
    lunaResult:luna({
      confidence:'medium',
      uncertainties:[
        'u1',
        'u2',
      ],
      safetyFlags:[
        's1',
        's2',
      ],
      differential:[
        'd1',
        'd2',
        'd3',
        'd4',
      ],
    }),
    serverContextMetrics:emptyContext,
    policyConfig:policy({
      terraAllowed:true,
    }),
  });

assert.strictEqual(multiSignal.score,5);
assert.strictEqual(
  multiSignal.clinicalEscalation,
  true
);
assert.strictEqual(
  multiSignal.terraAllowed,
  true
);

const contextEscalation=
  buildTerraClinicalEscalationDecisionV1({
    mode:'plantao',
    lunaResult:luna({
      confidence:'medium',
      uncertainties:[
        'u1',
      ],
      safetyFlags:[
        's1',
      ],
      differential:[
        'd1',
        'd2',
      ],
    }),
    serverContextMetrics:
      buildServerContextMetricsV1({
        userMessage:'X'.repeat(7000),
        history:new Array(15).fill('turn'),
        patientContext:{
          a:1,b:2,c:3,d:4,e:5,f:6,
          g:7,h:8,i:9,j:10,k:11,l:12,
        },
      }),
    policyConfig:policy({
      terraAllowed:true,
    }),
  });

assert.strictEqual(contextEscalation.score,4);
assert.strictEqual(
  contextEscalation.clinicalEscalation,
  true
);
assert.strictEqual(
  contextEscalation.terraAllowed,
  true
);
assert.ok(
  contextEscalation.signalCodes.includes(
    'longitudinal_complexity'
  )
);
assert.ok(
  contextEscalation.signalCodes.includes(
    'large_context'
  )
);
assert.ok(
  contextEscalation.signalCodes.includes(
    'dense_patient_context'
  )
);

const invalidMetrics=
  buildTerraClinicalEscalationDecisionV1({
    mode:'plantao',
    lunaResult:luna({
      confidence:'high',
    }),
    serverContextMetrics:{
      version:'client_spoof_metrics',
      userMessageChars:12000,
      historyTurns:64,
      patientContextFieldCount:128,
    },
    policyConfig:policy({
      terraAllowed:true,
    }),
  });

assert.strictEqual(invalidMetrics.score,0);
assert.strictEqual(
  invalidMetrics.clinicalEscalation,
  false
);

const telemetry=
  buildTerraClinicalEscalationTelemetry(
    lowConfidenceAllowed
  );

const telemetryText=
  JSON.stringify(telemetry);

assert.strictEqual(
  telemetryText.includes(
    'RAW_LUNA_SUMMARY_SENTINEL'
  ),
  false
);
assert.strictEqual(
  telemetryText.includes(
    'clinical_summary'
  ),
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

// Safe aggregate metrics are intentionally retained and must not be
// confused with raw user/patient payload fields.
assert.strictEqual(
  Number.isInteger(
    telemetry.userMessageChars
  ),
  true
);
assert.strictEqual(
  Number.isInteger(
    telemetry.patientContextFieldCount
  ),
  true
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
  telemetry.providerCallAuthority,
  false
);
assert.strictEqual(
  telemetry.telemetryOnly,
  true
);

console.log('TERRA_ESCALATION_POLICY_VERSION=PASS');
console.log('TERRA_ESCALATION_POLICY_SERVER_CONTEXT_METRICS=PASS');
console.log('TERRA_ESCALATION_POLICY_RAW_CONTEXT_VALUES=ABSENT');
console.log('TERRA_ESCALATION_POLICY_REMOTE_THRESHOLDS_SANITIZED=PASS');
console.log('TERRA_ESCALATION_POLICY_CLIENT_SPOOF_FIELDS=IGNORED');
console.log('TERRA_ESCALATION_POLICY_TECHNICAL_FAILURE_ALONE=ZERO_ESCALATION');
console.log('TERRA_ESCALATION_POLICY_LOW_CONFIDENCE_SIGNAL=PASS');
console.log('TERRA_ESCALATION_POLICY_MULTI_SIGNAL_SCORING=PASS');
console.log('TERRA_ESCALATION_POLICY_CONTEXT_COMPLEXITY_SCORING=PASS');
console.log('TERRA_ESCALATION_POLICY_TERRA_ALLOWED_SEPARATE=PASS');
console.log('TERRA_ESCALATION_POLICY_DEFAULT_DENY=PASS');
console.log('TERRA_ESCALATION_POLICY_RAW_CLINICAL_TELEMETRY=ABSENT');
console.log('TERRA_ESCALATION_POLICY_RAW_UID_TELEMETRY=ABSENT');
console.log('TERRA_ESCALATION_POLICY_USER_RESPONSE_AUTHORITY=NONE');
console.log('TERRA_ESCALATION_POLICY_LIVE_MODEL_SELECTION_AUTHORITY=NONE');
console.log('TERRA_ESCALATION_POLICY_LIVE_ERROR_PATH_AUTHORITY=NONE');
console.log('TERRA_ESCALATION_POLICY_TECHNICAL_FALLBACK_AUTHORITY=NONE');
console.log('TERRA_ESCALATION_POLICY_PROVIDER_CALL_AUTHORITY=NONE');
console.log('TERRA_SERVER_SIDE_CLINICAL_ESCALATION_POLICY_OWNER_FOUNDATION=PASS');
