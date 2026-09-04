'use strict';

const POLICY_VERSION='medcases_terra_clinical_escalation_policy_v1';
const SERVER_CONTEXT_METRICS_VERSION='server_context_metrics_v1';

const DEFAULT_POLICY_CONFIG=Object.freeze({
  enabled:false,
  terraAllowed:false,
  minScore:4,
  thresholds:Object.freeze({
    uncertainties:2,
    safetyFlags:2,
    differential:4,
    historyTurns:12,
    userMessageChars:6000,
    patientContextFieldCount:12,
  }),
});

const SIGNAL_WEIGHTS=Object.freeze({
  low_confidence:4,
  needs_more_information:1,
  multiple_uncertainties:2,
  multiple_safety_flags:2,
  broad_differential:1,
  longitudinal_complexity:2,
  large_context:1,
  dense_patient_context:1,
});

function _isPlainObject(v){
  return !!(
    v &&
    typeof v==='object' &&
    !Array.isArray(v)
  );
}

function _int(value,min,max,fallback){
  if(!Number.isInteger(value)){
    return fallback;
  }

  return Math.max(
    min,
    Math.min(max,value)
  );
}

function _arrayLength(value){
  return Array.isArray(value)
    ? value.length
    : 0;
}

function sanitizeTerraEscalationPolicyConfig(value){
  const v=_isPlainObject(value)
    ? value
    : {};
  const t=_isPlainObject(v.thresholds)
    ? v.thresholds
    : {};

  return Object.freeze({
    enabled:v.enabled===true,
    terraAllowed:v.terraAllowed===true,
    minScore:
      _int(
        v.minScore,
        1,
        20,
        DEFAULT_POLICY_CONFIG.minScore
      ),
    thresholds:Object.freeze({
      uncertainties:
        _int(
          t.uncertainties,
          1,
          10,
          DEFAULT_POLICY_CONFIG.thresholds.uncertainties
        ),
      safetyFlags:
        _int(
          t.safetyFlags,
          1,
          10,
          DEFAULT_POLICY_CONFIG.thresholds.safetyFlags
        ),
      differential:
        _int(
          t.differential,
          2,
          20,
          DEFAULT_POLICY_CONFIG.thresholds.differential
        ),
      historyTurns:
        _int(
          t.historyTurns,
          1,
          64,
          DEFAULT_POLICY_CONFIG.thresholds.historyTurns
        ),
      userMessageChars:
        _int(
          t.userMessageChars,
          500,
          12000,
          DEFAULT_POLICY_CONFIG.thresholds.userMessageChars
        ),
      patientContextFieldCount:
        _int(
          t.patientContextFieldCount,
          1,
          128,
          DEFAULT_POLICY_CONFIG.thresholds.patientContextFieldCount
        ),
    }),
  });
}

function buildServerContextMetricsV1({
  userMessage,
  history,
  patientContext,
}={}){
  return Object.freeze({
    version:SERVER_CONTEXT_METRICS_VERSION,
    userMessageChars:
      typeof userMessage==='string'
        ? Math.min(userMessage.length,12000)
        : 0,
    historyTurns:
      Array.isArray(history)
        ? Math.min(history.length,64)
        : 0,
    patientContextFieldCount:
      _isPlainObject(patientContext)
        ? Math.min(
            Object.keys(patientContext).length,
            128
          )
        : 0,
  });
}

function _validServerContextMetrics(v){
  return !!(
    _isPlainObject(v) &&
    v.version===SERVER_CONTEXT_METRICS_VERSION &&
    Number.isInteger(v.userMessageChars) &&
    Number.isInteger(v.historyTurns) &&
    Number.isInteger(v.patientContextFieldCount)
  );
}

function _baseDecision({
  policyConfig,
  gateReason,
  clinicalEscalation=false,
  terraAllowed=false,
  score=0,
  signalCodes=[],
  clinicalCounts=null,
  contextMetrics=null,
}){
  return Object.freeze({
    policyVersion:POLICY_VERSION,
    policyEnabled:policyConfig.enabled===true,
    clinicalEscalation:
      clinicalEscalation===true,
    terraAllowed:
      terraAllowed===true,
    gateReason,
    score,
    minScore:policyConfig.minScore,
    signalCodes:Object.freeze(
      [...signalCodes]
    ),
    clinicalCounts:
      clinicalCounts
        ? Object.freeze({...clinicalCounts})
        : null,
    contextMetrics:
      contextMetrics
        ? Object.freeze({...contextMetrics})
        : null,
    userResponseAuthority:false,
    liveModelSelectionAuthority:false,
    liveErrorPathAuthority:false,
    technicalFallbackAuthority:false,
    providerCallAuthority:false,
    telemetryOnly:true,
  });
}

function buildTerraClinicalEscalationDecisionV1({
  mode='plantao',
  lunaResult=null,
  serverContextMetrics=null,
  policyConfig=null,
}={}){
  const policy=
    sanitizeTerraEscalationPolicyConfig(
      policyConfig
    );

  if(policy.enabled!==true){
    return _baseDecision({
      policyConfig:policy,
      gateReason:'policy_disabled',
    });
  }

  if(!['plantao','plantão'].includes(mode)){
    return _baseDecision({
      policyConfig:policy,
      gateReason:'plantao_only',
    });
  }

  if(!_isPlainObject(lunaResult)){
    return _baseDecision({
      policyConfig:policy,
      gateReason:'luna_result_missing',
    });
  }

  if(lunaResult.technicalFailure===true){
    return _baseDecision({
      policyConfig:policy,
      gateReason:'technical_failure_not_clinical_escalation',
    });
  }

  if(
    lunaResult.completed!==true ||
    lunaResult.responseValid!==true ||
    !_isPlainObject(lunaResult.parsedClinicalResult)
  ){
    return _baseDecision({
      policyConfig:policy,
      gateReason:'luna_clinical_result_unavailable',
    });
  }

  const clinical=lunaResult.parsedClinicalResult;
  const context=
    _validServerContextMetrics(serverContextMetrics)
      ? {
          version:SERVER_CONTEXT_METRICS_VERSION,
          userMessageChars:
            _int(
              serverContextMetrics.userMessageChars,
              0,
              12000,
              0
            ),
          historyTurns:
            _int(
              serverContextMetrics.historyTurns,
              0,
              64,
              0
            ),
          patientContextFieldCount:
            _int(
              serverContextMetrics.patientContextFieldCount,
              0,
              128,
              0
            ),
        }
      : {
          version:SERVER_CONTEXT_METRICS_VERSION,
          userMessageChars:0,
          historyTurns:0,
          patientContextFieldCount:0,
        };

  const counts={
    differential:
      _arrayLength(clinical.differential),
    safetyFlags:
      _arrayLength(clinical.safety_flags),
    uncertainties:
      _arrayLength(clinical.uncertainties),
  };

  const signals=[];

  if(clinical.confidence==='low'){
    signals.push('low_confidence');
  }

  if(clinical.needs_more_information===true){
    signals.push('needs_more_information');
  }

  if(
    counts.uncertainties>=
      policy.thresholds.uncertainties
  ){
    signals.push('multiple_uncertainties');
  }

  if(
    counts.safetyFlags>=
      policy.thresholds.safetyFlags
  ){
    signals.push('multiple_safety_flags');
  }

  if(
    counts.differential>=
      policy.thresholds.differential
  ){
    signals.push('broad_differential');
  }

  if(
    context.historyTurns>=
      policy.thresholds.historyTurns
  ){
    signals.push('longitudinal_complexity');
  }

  if(
    context.userMessageChars>=
      policy.thresholds.userMessageChars
  ){
    signals.push('large_context');
  }

  if(
    context.patientContextFieldCount>=
      policy.thresholds.patientContextFieldCount
  ){
    signals.push('dense_patient_context');
  }

  const score=
    signals.reduce(
      (sum,signal)=>
        sum+(SIGNAL_WEIGHTS[signal]||0),
      0
    );

  const clinicalEscalation=
    score>=policy.minScore;

  const terraAllowed=
    clinicalEscalation &&
    policy.terraAllowed===true;

  return _baseDecision({
    policyConfig:policy,
    gateReason:
      clinicalEscalation
        ? (
            terraAllowed
              ? 'clinical_escalation_allowed'
              : 'clinical_escalation_terra_not_allowed'
          )
        : 'clinical_escalation_not_required',
    clinicalEscalation,
    terraAllowed,
    score,
    signalCodes:signals,
    clinicalCounts:counts,
    contextMetrics:context,
  });
}

function buildTerraClinicalEscalationTelemetry(decision){
  const d=_isPlainObject(decision)
    ? decision
    : {};

  const counts=
    _isPlainObject(d.clinicalCounts)
      ? d.clinicalCounts
      : {};
  const metrics=
    _isPlainObject(d.contextMetrics)
      ? d.contextMetrics
      : {};

  return Object.freeze({
    policyVersion:
      typeof d.policyVersion==='string'
        ? d.policyVersion
        : POLICY_VERSION,
    policyEnabled:
      d.policyEnabled===true,
    clinicalEscalation:
      d.clinicalEscalation===true,
    terraAllowed:
      d.terraAllowed===true,
    gateReason:
      typeof d.gateReason==='string'
        ? d.gateReason
        : null,
    score:
      Number.isInteger(d.score)
        ? d.score
        : 0,
    minScore:
      Number.isInteger(d.minScore)
        ? d.minScore
        : DEFAULT_POLICY_CONFIG.minScore,
    signalCodes:
      Array.isArray(d.signalCodes)
        ? d.signalCodes.filter(
            (v)=>typeof v==='string'
          ).slice(0,16)
        : [],
    differentialCount:
      Number.isInteger(counts.differential)
        ? counts.differential
        : 0,
    safetyFlagCount:
      Number.isInteger(counts.safetyFlags)
        ? counts.safetyFlags
        : 0,
    uncertaintyCount:
      Number.isInteger(counts.uncertainties)
        ? counts.uncertainties
        : 0,
    userMessageChars:
      Number.isInteger(metrics.userMessageChars)
        ? metrics.userMessageChars
        : 0,
    historyTurns:
      Number.isInteger(metrics.historyTurns)
        ? metrics.historyTurns
        : 0,
    patientContextFieldCount:
      Number.isInteger(metrics.patientContextFieldCount)
        ? metrics.patientContextFieldCount
        : 0,
    userResponseAuthority:false,
    liveModelSelectionAuthority:false,
    liveErrorPathAuthority:false,
    technicalFallbackAuthority:false,
    providerCallAuthority:false,
    telemetryOnly:true,
  });
}

module.exports={
  POLICY_VERSION,
  SERVER_CONTEXT_METRICS_VERSION,
  DEFAULT_POLICY_CONFIG,
  SIGNAL_WEIGHTS,
  sanitizeTerraEscalationPolicyConfig,
  buildServerContextMetricsV1,
  buildTerraClinicalEscalationDecisionV1,
  buildTerraClinicalEscalationTelemetry,
};
