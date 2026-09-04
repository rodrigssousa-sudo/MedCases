'use strict';

const {
  TERRA_LONG_CONTEXT_THRESHOLD_INPUT_TOKENS,
  TERRA_COST_NANO_USD_PER_TOKEN,
}=require('./gpt56_terra_plantao_complex_escalation_shadow_v1');

const {
  POLICY_VERSION,
}=require('./terra_clinical_escalation_policy_v1');

const STABILIZATION_VERSION=
  'medcases_terra_escalation_stabilization_v1';

const COST_GUARD_VERSION=
  'medcases_terra_preflight_cost_guard_v1';

const DEFAULT_STABILIZATION_CONFIG=Object.freeze({
  enabled:false,
  maxEstimatedInputTokens:30000,
  maxOutputTokens:4096,
  maxEstimatedCostNanoUsd:60000000,
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

function sanitizeTerraStabilizationConfig(value){
  const v=_isPlainObject(value)
    ? value
    : {};

  return Object.freeze({
    enabled:v.enabled===true,
    maxEstimatedInputTokens:
      _int(
        v.maxEstimatedInputTokens,
        1000,
        272000,
        DEFAULT_STABILIZATION_CONFIG.maxEstimatedInputTokens
      ),
    maxOutputTokens:
      _int(
        v.maxOutputTokens,
        1024,
        16384,
        DEFAULT_STABILIZATION_CONFIG.maxOutputTokens
      ),
    maxEstimatedCostNanoUsd:
      _int(
        v.maxEstimatedCostNanoUsd,
        1000000,
        1000000000,
        DEFAULT_STABILIZATION_CONFIG.maxEstimatedCostNanoUsd
      ),
  });
}

function estimateTerraInputTokensFromServerMetricsV1(
  serverContextMetrics
){
  const m=_isPlainObject(serverContextMetrics)
    ? serverContextMetrics
    : {};

  const userMessageChars=
    _int(
      m.userMessageChars,
      0,
      12000,
      0
    );

  const historyTurns=
    _int(
      m.historyTurns,
      0,
      64,
      0
    );

  const patientContextFieldCount=
    _int(
      m.patientContextFieldCount,
      0,
      128,
      0
    );

  // Conservative preflight estimate only; never substitutes provider usage.
  // 4 chars/token for current message + fixed structural budgets.
  return Math.min(
    272000,
    Math.ceil(userMessageChars/4) +
    (historyTurns*192) +
    (patientContextFieldCount*32) +
    512
  );
}

function estimateTerraWorstCaseCostNanoUsdV1({
  estimatedInputTokens,
  maxOutputTokens,
}={}){
  const input=
    _int(
      estimatedInputTokens,
      0,
      1000000,
      0
    );

  const output=
    _int(
      maxOutputTokens,
      0,
      16384,
      0
    );

  const longContext=
    input>TERRA_LONG_CONTEXT_THRESHOLD_INPUT_TOKENS;

  const inputMultiplier=
    longContext
      ? 2
      : 1;

  const outputMultiplier=
    longContext
      ? 1.5
      : 1;

  return Math.round(
    (
      input*
      TERRA_COST_NANO_USD_PER_TOKEN.uncachedInput*
      inputMultiplier
    )+
    (
      output*
      TERRA_COST_NANO_USD_PER_TOKEN.output*
      outputMultiplier
    )
  );
}

function buildTerraStabilizedAuthorizationV1({
  clinicalDecision=null,
  serverContextMetrics=null,
  terraProviderConfig=null,
  stabilizationConfig=null,
}={}){
  const config=
    sanitizeTerraStabilizationConfig(
      stabilizationConfig
    );

  const base={
    stabilizationVersion:
      STABILIZATION_VERSION,
    costGuardVersion:
      COST_GUARD_VERSION,
    enabled:
      config.enabled===true,
    clinicalEscalation:false,
    policyTerraAllowed:false,
    terraAllowed:false,
    providerCallAllowed:false,
    gateReason:'stabilization_disabled',
    score:0,
    minScore:0,
    signalCodes:[],
    estimatedInputTokens:0,
    providerMaxOutputTokens:0,
    maxEstimatedInputTokens:
      config.maxEstimatedInputTokens,
    maxAllowedOutputTokens:
      config.maxOutputTokens,
    estimatedWorstCaseCostNanoUsd:0,
    maxEstimatedCostNanoUsd:
      config.maxEstimatedCostNanoUsd,
    userResponseAuthority:false,
    liveModelSelectionAuthority:false,
    liveErrorPathAuthority:false,
    technicalFallbackAuthority:false,
    telemetryOnly:true,
  };

  if(config.enabled!==true){
    return Object.freeze(base);
  }

  if(
    !_isPlainObject(clinicalDecision) ||
    clinicalDecision.policyVersion!==POLICY_VERSION
  ){
    return Object.freeze({
      ...base,
      gateReason:'clinical_decision_invalid',
    });
  }

  if(
    clinicalDecision.clinicalEscalation!==true ||
    clinicalDecision.terraAllowed!==true
  ){
    return Object.freeze({
      ...base,
      clinicalEscalation:
        clinicalDecision.clinicalEscalation===true,
      policyTerraAllowed:
        clinicalDecision.terraAllowed===true,
      score:
        Number.isInteger(clinicalDecision.score)
          ? clinicalDecision.score
          : 0,
      minScore:
        Number.isInteger(clinicalDecision.minScore)
          ? clinicalDecision.minScore
          : 0,
      signalCodes:
        Array.isArray(clinicalDecision.signalCodes)
          ? clinicalDecision.signalCodes
              .filter((v)=>typeof v==='string')
              .slice(0,16)
          : [],
      gateReason:'clinical_policy_not_authorized',
    });
  }

  if(!_isPlainObject(terraProviderConfig)){
    return Object.freeze({
      ...base,
      clinicalEscalation:true,
      policyTerraAllowed:true,
      score:
        Number.isInteger(clinicalDecision.score)
          ? clinicalDecision.score
          : 0,
      minScore:
        Number.isInteger(clinicalDecision.minScore)
          ? clinicalDecision.minScore
          : 0,
      signalCodes:
        Array.isArray(clinicalDecision.signalCodes)
          ? clinicalDecision.signalCodes
              .filter((v)=>typeof v==='string')
              .slice(0,16)
          : [],
      gateReason:'terra_provider_config_missing',
    });
  }

  const providerMaxOutputTokens=
    _int(
      terraProviderConfig.maxOutputTokens,
      1024,
      16384,
      8192
    );

  const estimatedInputTokens=
    estimateTerraInputTokensFromServerMetricsV1(
      serverContextMetrics
    );

  const estimatedWorstCaseCostNanoUsd=
    estimateTerraWorstCaseCostNanoUsdV1({
      estimatedInputTokens,
      maxOutputTokens:
        providerMaxOutputTokens,
    });

  const common={
    ...base,
    clinicalEscalation:true,
    policyTerraAllowed:true,
    score:
      Number.isInteger(clinicalDecision.score)
        ? clinicalDecision.score
        : 0,
    minScore:
      Number.isInteger(clinicalDecision.minScore)
        ? clinicalDecision.minScore
        : 0,
    signalCodes:
      Array.isArray(clinicalDecision.signalCodes)
        ? clinicalDecision.signalCodes
            .filter((v)=>typeof v==='string')
            .slice(0,16)
        : [],
    estimatedInputTokens,
    providerMaxOutputTokens,
    estimatedWorstCaseCostNanoUsd,
  };

  if(
    estimatedInputTokens>
      config.maxEstimatedInputTokens
  ){
    return Object.freeze({
      ...common,
      gateReason:'estimated_input_token_cap_exceeded',
    });
  }

  if(
    providerMaxOutputTokens>
      config.maxOutputTokens
  ){
    return Object.freeze({
      ...common,
      gateReason:'provider_max_output_exceeds_cost_guard',
    });
  }

  if(
    estimatedWorstCaseCostNanoUsd>
      config.maxEstimatedCostNanoUsd
  ){
    return Object.freeze({
      ...common,
      gateReason:'estimated_cost_cap_exceeded',
    });
  }

  return Object.freeze({
    ...common,
    terraAllowed:true,
    providerCallAllowed:true,
    gateReason:'stabilized_clinical_escalation_allowed',
  });
}

function buildTerraStabilizationTelemetry(result){
  const r=_isPlainObject(result)
    ? result
    : {};

  return Object.freeze({
    stabilizationVersion:
      typeof r.stabilizationVersion==='string'
        ? r.stabilizationVersion
        : STABILIZATION_VERSION,
    costGuardVersion:
      typeof r.costGuardVersion==='string'
        ? r.costGuardVersion
        : COST_GUARD_VERSION,
    enabled:r.enabled===true,
    clinicalEscalation:
      r.clinicalEscalation===true,
    policyTerraAllowed:
      r.policyTerraAllowed===true,
    terraAllowed:
      r.terraAllowed===true,
    providerCallAllowed:
      r.providerCallAllowed===true,
    gateReason:
      typeof r.gateReason==='string'
        ? r.gateReason
        : null,
    score:
      Number.isInteger(r.score)
        ? r.score
        : 0,
    minScore:
      Number.isInteger(r.minScore)
        ? r.minScore
        : 0,
    signalCodes:
      Array.isArray(r.signalCodes)
        ? r.signalCodes
            .filter((v)=>typeof v==='string')
            .slice(0,16)
        : [],
    estimatedInputTokens:
      Number.isInteger(r.estimatedInputTokens)
        ? r.estimatedInputTokens
        : 0,
    providerMaxOutputTokens:
      Number.isInteger(r.providerMaxOutputTokens)
        ? r.providerMaxOutputTokens
        : 0,
    maxEstimatedInputTokens:
      Number.isInteger(r.maxEstimatedInputTokens)
        ? r.maxEstimatedInputTokens
        : 0,
    maxAllowedOutputTokens:
      Number.isInteger(r.maxAllowedOutputTokens)
        ? r.maxAllowedOutputTokens
        : 0,
    estimatedWorstCaseCostNanoUsd:
      Number.isInteger(r.estimatedWorstCaseCostNanoUsd)
        ? r.estimatedWorstCaseCostNanoUsd
        : 0,
    maxEstimatedCostNanoUsd:
      Number.isInteger(r.maxEstimatedCostNanoUsd)
        ? r.maxEstimatedCostNanoUsd
        : 0,
    userResponseAuthority:false,
    liveModelSelectionAuthority:false,
    liveErrorPathAuthority:false,
    technicalFallbackAuthority:false,
    telemetryOnly:true,
  });
}

module.exports={
  STABILIZATION_VERSION,
  COST_GUARD_VERSION,
  DEFAULT_STABILIZATION_CONFIG,
  sanitizeTerraStabilizationConfig,
  estimateTerraInputTokensFromServerMetricsV1,
  estimateTerraWorstCaseCostNanoUsdV1,
  buildTerraStabilizedAuthorizationV1,
  buildTerraStabilizationTelemetry,
};
