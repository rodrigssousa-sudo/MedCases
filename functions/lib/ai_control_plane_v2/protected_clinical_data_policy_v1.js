'use strict';

const POLICY_VERSION='openai_protected_clinical_policy_v1';
const PROJECTION_VERSION='protected_clinical_projection_v1';
const PROJECTION_SOURCE='server_deidentified_v1';

function _boolEnv(env,key){
  return !!(
    env &&
    typeof env==='object' &&
    env[key]==='true'
  );
}

function buildOpenAiProtectedClinicalDataPolicyFromEnv(env=process.env){
  const processingAttested=
    _boolEnv(
      env,
      'AI_OPENAI_PROTECTED_CLINICAL_PROCESSING_ATTESTED'
    );

  const realPatientShadowAllowed=
    _boolEnv(
      env,
      'AI_GPT5_NANO_REAL_PATIENT_SHADOW_ALLOWED'
    );

  return Object.freeze({
    version:POLICY_VERSION,
    source:'server_env_v1',
    processingAttested,
    realPatientShadowAllowed,
    deidentifiedProjectionRequired:true,
    ready:
      processingAttested &&
      realPatientShadowAllowed,
  });
}

function classifyClinicalDataSensitivity({patientContext}={}){
  const explicitSynthetic=!!(
    patientContext &&
    typeof patientContext==='object' &&
    !Array.isArray(patientContext) &&
    patientContext.synthetic===true &&
    patientContext.realPatient===false
  );

  return explicitSynthetic
    ? 'synthetic_non_patient'
    : 'potential_real_patient';
}

function _safeToken(v){
  return (
    typeof v==='string' &&
    /^[a-z0-9][a-z0-9_:\-]{0,47}$/i.test(v)
  );
}

function _safeTokenArray(v,maxItems){
  return (
    Array.isArray(v) &&
    v.length<=maxItems &&
    v.every(_safeToken)
  );
}

function _safeNonNegativeInt(v,max){
  return (
    Number.isInteger(v) &&
    v>=0 &&
    v<=max
  );
}

function validateProtectedClinicalProjectionV1(projection){
  if(
    !projection ||
    typeof projection!=='object' ||
    Array.isArray(projection)
  ){
    return Object.freeze({
      valid:false,
      reason:'projection_missing',
    });
  }

  const allowedKeys=[
    'version',
    'source',
    'containsRawText',
    'containsDirectIdentifiers',
    'clinicalIntentTags',
    'complexitySignals',
    'contextMetrics',
  ];

  const unexpected=
    Object.keys(projection)
      .filter(k=>!allowedKeys.includes(k));

  if(unexpected.length>0){
    return Object.freeze({
      valid:false,
      reason:'projection_unexpected_keys',
    });
  }

  if(
    projection.version!==PROJECTION_VERSION ||
    projection.source!==PROJECTION_SOURCE ||
    projection.containsRawText!==false ||
    projection.containsDirectIdentifiers!==false
  ){
    return Object.freeze({
      valid:false,
      reason:'projection_attestation_invalid',
    });
  }

  if(
    !_safeTokenArray(projection.clinicalIntentTags,16) ||
    !_safeTokenArray(projection.complexitySignals,16)
  ){
    return Object.freeze({
      valid:false,
      reason:'projection_token_fields_invalid',
    });
  }

  const metrics=projection.contextMetrics;

  if(
    !metrics ||
    typeof metrics!=='object' ||
    Array.isArray(metrics)
  ){
    return Object.freeze({
      valid:false,
      reason:'projection_metrics_invalid',
    });
  }

  const metricKeys=[
    'userMessageChars',
    'historyTurns',
    'patientContextFieldCount',
  ];

  const unexpectedMetrics=
    Object.keys(metrics)
      .filter(k=>!metricKeys.includes(k));

  if(unexpectedMetrics.length>0){
    return Object.freeze({
      valid:false,
      reason:'projection_metric_keys_invalid',
    });
  }

  if(
    !_safeNonNegativeInt(metrics.userMessageChars,12000) ||
    !_safeNonNegativeInt(metrics.historyTurns,64) ||
    !_safeNonNegativeInt(metrics.patientContextFieldCount,128)
  ){
    return Object.freeze({
      valid:false,
      reason:'projection_metric_values_invalid',
    });
  }

  return Object.freeze({
    valid:true,
    reason:'valid',
  });
}

function evaluateProtectedClinicalProviderGate({
  patientContext,
  providerDataPolicy,
  protectedClinicalProjection,
}={}){
  const sensitivity=
    classifyClinicalDataSensitivity({patientContext});

  if(sensitivity==='synthetic_non_patient'){
    return Object.freeze({
      allowed:true,
      reason:'synthetic_non_patient',
      sensitivity,
      useProtectedProjection:false,
    });
  }

  if(
    !providerDataPolicy ||
    typeof providerDataPolicy!=='object' ||
    providerDataPolicy.version!==POLICY_VERSION ||
    providerDataPolicy.source!=='server_env_v1'
  ){
    return Object.freeze({
      allowed:false,
      reason:'protected_clinical_policy_missing',
      sensitivity,
      useProtectedProjection:true,
    });
  }

  if(
    providerDataPolicy.processingAttested!==true ||
    providerDataPolicy.realPatientShadowAllowed!==true ||
    providerDataPolicy.deidentifiedProjectionRequired!==true ||
    providerDataPolicy.ready!==true
  ){
    return Object.freeze({
      allowed:false,
      reason:'protected_clinical_policy_denied',
      sensitivity,
      useProtectedProjection:true,
    });
  }

  const projectionValidation=
    validateProtectedClinicalProjectionV1(
      protectedClinicalProjection
    );

  if(!projectionValidation.valid){
    return Object.freeze({
      allowed:false,
      reason:projectionValidation.reason,
      sensitivity,
      useProtectedProjection:true,
    });
  }

  return Object.freeze({
    allowed:true,
    reason:'protected_clinical_projection_allowed',
    sensitivity,
    useProtectedProjection:true,
  });
}

function buildProtectedClinicalRouterInputV1(projection){
  const validation=
    validateProtectedClinicalProjectionV1(projection);

  if(!validation.valid){
    throw new Error(
      `invalid_protected_clinical_projection:${validation.reason}`
    );
  }

  return [
    'Protected clinical routing projection v1.',
    `Clinical intent tags: ${projection.clinicalIntentTags.join(',') || 'none'}`,
    `Complexity signals: ${projection.complexitySignals.join(',') || 'none'}`,
    'Context metrics:',
    `user_message_chars=${projection.contextMetrics.userMessageChars}`,
    `history_turns=${projection.contextMetrics.historyTurns}`,
    `patient_context_field_count=${projection.contextMetrics.patientContextFieldCount}`,
    'No raw clinical text or direct identifiers are included.',
  ].join('\n');
}

module.exports={
  POLICY_VERSION,
  PROJECTION_VERSION,
  PROJECTION_SOURCE,
  buildOpenAiProtectedClinicalDataPolicyFromEnv,
  classifyClinicalDataSensitivity,
  validateProtectedClinicalProjectionV1,
  evaluateProtectedClinicalProviderGate,
  buildProtectedClinicalRouterInputV1,
};
