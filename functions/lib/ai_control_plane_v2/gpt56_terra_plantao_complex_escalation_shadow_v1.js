'use strict';
const {
  buildProtectedClinicalRouterInputSafeV2,
} = require(
  './protected_clinical_data_policy_v2'
);


const crypto=require('crypto');

const TERRA_MODEL='gpt-5.6-terra';
const TERRA_ALIAS='plantao_complex';
const TERRA_ENDPOINT='https://api.openai.com/v1/responses';
const TERRA_REMOTE_FLAG='gpt56_terra_real_shadow_v1';
const TERRA_SERVER_GATE='AI_GPT56_TERRA_REAL_SHADOW_ENABLED';
const TERRA_SYNTHETIC_ONLY_GATE='AI_GPT56_TERRA_REAL_SHADOW_SYNTHETIC_ONLY';
const TERRA_PROOF_UID_SHA_ENV='AI_GPT56_TERRA_REAL_SHADOW_PROOF_UID_SHA256';
const TERRA_VALIDATOR_VERSION='medcases_terra_validator_v1';
const TERRA_PRICING_VERSION='openai_gpt56_terra_api_pricing_2026_08_29_v1';
const TERRA_LONG_CONTEXT_THRESHOLD_INPUT_TOKENS=272000;

const TERRA_COST_NANO_USD_PER_TOKEN=Object.freeze({
  uncachedInput:2000,
  cachedInput:200,
  cacheWriteInput:2500,
  output:12000,
});

const TERRA_CLINICAL_SCHEMA=Object.freeze({
  type:'object',
  additionalProperties:false,
  properties:{
    clinical_synthesis:{
      type:'string',
    },
    diagnostic_conflicts:{
      type:'array',
      items:{type:'string'},
    },
    differential:{
      type:'array',
      items:{type:'string'},
    },
    critical_actions:{
      type:'array',
      items:{type:'string'},
    },
    disposition:{
      type:'array',
      items:{type:'string'},
    },
    safety_flags:{
      type:'array',
      items:{type:'string'},
    },
    uncertainties:{
      type:'array',
      items:{type:'string'},
    },
    confidence:{
      type:'string',
      enum:['low','medium','high'],
    },
    needs_more_information:{
      type:'boolean',
    },
  },
  required:[
    'clinical_synthesis',
    'diagnostic_conflicts',
    'differential',
    'critical_actions',
    'disposition',
    'safety_flags',
    'uncertainties',
    'confidence',
    'needs_more_information',
  ],
});

function _isPlainObject(v){
  return !!(
    v &&
    typeof v==='object' &&
    !Array.isArray(v)
  );
}

function _usageInt(value){
  return Number.isInteger(value) && value>=0
    ? value
    : 0;
}

function _sha256Hex(value){
  return crypto
    .createHash('sha256')
    .update(String(value),'utf8')
    .digest('hex');
}

function _safeEqualHex(a,b){
  if(
    typeof a!=='string' ||
    typeof b!=='string' ||
    !/^[a-f0-9]{64}$/i.test(a) ||
    !/^[a-f0-9]{64}$/i.test(b)
  ){
    return false;
  }

  return crypto.timingSafeEqual(
    Buffer.from(a.toLowerCase(),'hex'),
    Buffer.from(b.toLowerCase(),'hex')
  );
}

function _isExplicitSynthetic(patientContext){
  return !!(
    _isPlainObject(patientContext) &&
    patientContext.synthetic===true &&
    patientContext.realPatient===false
  );
}

function _tokenArray(value){
  if(!Array.isArray(value)){
    return [];
  }

  return value
    .filter((v)=>typeof v==='string')
    .map((v)=>v.trim())
    .filter((v)=>/^[a-z0-9][a-z0-9_:\-]{0,47}$/i.test(v))
    .slice(0,16);
}

function _safeMetric(value,min,max){
  if(!Number.isInteger(value)){
    return 0;
  }

  return Math.max(
    min,
    Math.min(max,value)
  );
}

function _validateProtectedProjection(v){
  return !!(
    _isPlainObject(v) &&
    v.version==='protected_clinical_projection_v1' &&
    v.source==='server_deidentified_v1' &&
    v.containsRawText===false &&
    v.containsDirectIdentifiers===false &&
    _isPlainObject(v.contextMetrics)
  );
}

function _buildProtectedInput(v){
  if(!_validateProtectedProjection(v)){
    return null;
  }

  return JSON.stringify({
    clinicalIntentTags:
      _tokenArray(v.clinicalIntentTags),
    complexitySignals:
      _tokenArray(v.complexitySignals),
    contextMetrics:{
      userMessageChars:
        _safeMetric(
          v.contextMetrics.userMessageChars,
          0,
          12000
        ),
      historyTurns:
        _safeMetric(
          v.contextMetrics.historyTurns,
          0,
          64
        ),
      patientContextFieldCount:
        _safeMetric(
          v.contextMetrics.patientContextFieldCount,
          0,
          128
        ),
    },
  });
}

function _syntheticInput({
  userMessage,
  history,
  patientContext,
  escalationReasons,
}){
  return JSON.stringify({
    synthetic:true,
    realPatient:false,
    clinicalEscalation:true,
    escalationReasons:
      _tokenArray(escalationReasons),
    userMessage:
      typeof userMessage==='string'
        ? userMessage.slice(0,12000)
        : '',
    historyTurns:
      Array.isArray(history)
        ? Math.min(history.length,64)
        : 0,
    syntheticContext:
      _isPlainObject(patientContext)
        ? {
            synthetic:true,
            realPatient:false,
          }
        : {
            synthetic:true,
            realPatient:false,
          },
  });
}

function deterministicTerraShadowBucket(
  uid,
  salt
){
  if(
    typeof uid!=='string' ||
    uid.length===0 ||
    typeof salt!=='string' ||
    salt.length===0
  ){
    return null;
  }

  const hex=crypto
    .createHash('sha256')
    .update(`${salt}:${uid}`,'utf8')
    .digest('hex')
    .slice(0,8);

  return parseInt(hex,16)%10000;
}

function _remoteConfig(config){
  return (
    config &&
    _isPlainObject(config.shadowProviderCalls) &&
    _isPlainObject(
      config.shadowProviderCalls.gpt56Terra
    )
  )
    ? config.shadowProviderCalls.gpt56Terra
    : null;
}

function buildGpt56TerraRequest({
  providerInput,
  maxOutputTokens,
  reasoningEffort,
}={}){
  return {
    model:TERRA_MODEL,
    input:
      typeof providerInput==='string'
        ? providerInput
        : '',
    store:false,
    reasoning:{
      effort:
        ['none','low','medium','high','xhigh','max']
          .includes(reasoningEffort)
            ? reasoningEffort
            : 'high',
    },
    max_output_tokens:
      Number.isInteger(maxOutputTokens)
        ? Math.max(
            1024,
            Math.min(maxOutputTokens,16384)
          )
        : 8192,
    text:{
      format:{
        type:'json_schema',
        name:'medcases_terra_complex_clinical_v1',
        strict:true,
        schema:TERRA_CLINICAL_SCHEMA,
      },
    },
  };
}

function _extractOutputText(data){
  if(!data || !Array.isArray(data.output)){
    return '';
  }

  const texts=[];

  for(const item of data.output){
    if(
      !item ||
      item.type!=='message' ||
      !Array.isArray(item.content)
    ){
      continue;
    }

    for(const block of item.content){
      if(
        block &&
        block.type==='output_text' &&
        typeof block.text==='string'
      ){
        texts.push(block.text);
      }
    }
  }

  return texts.join('');
}

function _isValidClinicalResult(v){
  return !!(
    _isPlainObject(v) &&
    typeof v.clinical_synthesis==='string' &&
    Array.isArray(v.diagnostic_conflicts) &&
    Array.isArray(v.differential) &&
    Array.isArray(v.critical_actions) &&
    Array.isArray(v.disposition) &&
    Array.isArray(v.safety_flags) &&
    Array.isArray(v.uncertainties) &&
    ['low','medium','high'].includes(v.confidence) &&
    typeof v.needs_more_information==='boolean'
  );
}

function estimateGpt56TerraCost({
  inputTokens,
  cachedInputTokens,
  cacheWriteInputTokens,
  outputTokens,
}={}){
  const input=_usageInt(inputTokens);
  const cached=Math.min(
    input,
    _usageInt(cachedInputTokens)
  );
  const cacheWrite=Math.min(
    Math.max(0,input-cached),
    _usageInt(cacheWriteInputTokens)
  );
  const uncached=Math.max(
    0,
    input-cached-cacheWrite
  );
  const output=_usageInt(outputTokens);

  const longContext=
    input>TERRA_LONG_CONTEXT_THRESHOLD_INPUT_TOKENS;

  const inputMultiplier=longContext ? 2 : 1;
  const outputMultiplier=longContext ? 1.5 : 1;

  const nanoUsd=
    (
      uncached*
      TERRA_COST_NANO_USD_PER_TOKEN.uncachedInput*
      inputMultiplier
    )+
    (
      cached*
      TERRA_COST_NANO_USD_PER_TOKEN.cachedInput*
      inputMultiplier
    )+
    (
      cacheWrite*
      TERRA_COST_NANO_USD_PER_TOKEN.cacheWriteInput*
      inputMultiplier
    )+
    (
      output*
      TERRA_COST_NANO_USD_PER_TOKEN.output*
      outputMultiplier
    );

  return Object.freeze({
    pricingVersion:TERRA_PRICING_VERSION,
    inputTokens:input,
    cachedInputTokens:cached,
    cacheWriteInputTokens:cacheWrite,
    uncachedInputTokens:uncached,
    outputTokens:output,
    longContextPricingApplied:longContext,
    estimatedCostNanoUsd:Math.round(nanoUsd),
    estimatedCostUsd:
      Math.round(nanoUsd)/1000000000,
  });
}

function classifyGpt56TerraTechnicalOutcome({
  httpStatus,
  providerStatus,
  incompleteReason,
  outputTextPresent,
  jsonParsed,
  schemaValid,
  exceptionName,
  exceptionCode,
}={}){
  if(exceptionName || exceptionCode){
    const value=
      `${exceptionName||''}:${exceptionCode||''}`
        .toLowerCase();

    if(
      value.includes('abort') ||
      value.includes('timeout')
    ){
      return 'technical_timeout';
    }

    return 'technical_network_or_exception';
  }

  if(httpStatus===429){
    return 'technical_rate_limit';
  }

  if(Number.isInteger(httpStatus) && httpStatus>=500){
    return 'technical_provider_5xx';
  }

  if(Number.isInteger(httpStatus) && httpStatus>=400){
    return 'technical_provider_4xx';
  }

  if(providerStatus==='incomplete'){
    if(incompleteReason==='max_output_tokens'){
      return 'technical_incomplete_max_output_tokens';
    }

    return 'technical_incomplete';
  }

  if(providerStatus!=='completed'){
    return 'technical_provider_status_invalid';
  }

  if(outputTextPresent!==true){
    return 'technical_empty_output';
  }

  if(jsonParsed!==true){
    return 'technical_invalid_json';
  }

  if(schemaValid!==true){
    return 'technical_schema_invalid';
  }

  return null;
}

function _usage(data){
  const usage=
    data && _isPlainObject(data.usage)
      ? data.usage
      : {};
  const inputDetails=
    _isPlainObject(usage.input_tokens_details)
      ? usage.input_tokens_details
      : {};
  const outputDetails=
    _isPlainObject(usage.output_tokens_details)
      ? usage.output_tokens_details
      : {};

  return Object.freeze({
    inputTokens:
      Number.isInteger(usage.input_tokens)
        ? usage.input_tokens
        : null,
    cachedInputTokens:
      Number.isInteger(inputDetails.cached_tokens)
        ? inputDetails.cached_tokens
        : null,
    cacheWriteInputTokens:
      Number.isInteger(inputDetails.cache_write_tokens)
        ? inputDetails.cache_write_tokens
        : null,
    outputTokens:
      Number.isInteger(usage.output_tokens)
        ? usage.output_tokens
        : null,
    reasoningTokens:
      Number.isInteger(outputDetails.reasoning_tokens)
        ? outputDetails.reasoning_tokens
        : null,
  });
}

async function runGpt56TerraPlantaoComplexEscalationShadow({
  config=null,
  uid='',
  mode='plantao',
  clinicalEscalation=false,
  terraAllowed=false,
  escalationReasons=[],
  upstreamTechnicalFailure=false,
  upstreamFailureClass=null,
  userMessage='',
  history=[],
  patientContext=null,
  providerDataPolicy=null,
  protectedClinicalProjection=null,
  openAiApiKey='',
  serverEnabled=
    process.env[TERRA_SERVER_GATE]==='true',
  syntheticOnlyEnabled=
    process.env[TERRA_SYNTHETIC_ONLY_GATE]==='true',
  proofUidSha256=
    process.env[TERRA_PROOF_UID_SHA_ENV] || '',
  fetchFn=globalThis.fetch,
}={}){
  const base=Object.freeze({
    provider:'openai',
    model:TERRA_MODEL,
    alias:TERRA_ALIAS,
    clinicalEscalation:
      clinicalEscalation===true,
    terraAllowed:
      terraAllowed===true,
    upstreamTechnicalFailure:
      upstreamTechnicalFailure===true,
    upstreamFailureClass:
      typeof upstreamFailureClass==='string'
        ? upstreamFailureClass
        : null,
    userResponseAuthority:false,
    liveModelSelectionAuthority:false,
    liveErrorPathAuthority:false,
    technicalFallbackAuthority:false,
    liveAuthorityChanged:false,
    telemetryOnly:true,
  });

  if(serverEnabled!==true){
    return Object.freeze({
      ...base,
      attempted:false,
      completed:false,
      gateReason:'server_hard_gate_closed',
    });
  }

  if(!['plantao','plantão'].includes(mode)){
    return Object.freeze({
      ...base,
      attempted:false,
      completed:false,
      gateReason:'plantao_only',
    });
  }

  if(clinicalEscalation!==true){
    return Object.freeze({
      ...base,
      attempted:false,
      completed:false,
      gateReason:
        upstreamTechnicalFailure===true
          ? 'technical_failure_not_terra_route'
          : 'clinical_escalation_not_required',
    });
  }

  if(terraAllowed!==true){
    return Object.freeze({
      ...base,
      attempted:false,
      completed:false,
      gateReason:'terra_not_allowed',
    });
  }

  const remote=_remoteConfig(config);

  if(
    !config ||
    !config.featureFlags ||
    config.featureFlags[TERRA_REMOTE_FLAG]!==true ||
    !remote ||
    remote.enabled!==true
  ){
    return Object.freeze({
      ...base,
      attempted:false,
      completed:false,
      gateReason:'remote_gate_closed',
    });
  }

  const bucket=
    deterministicTerraShadowBucket(
      uid,
      remote.cohortSalt
    );

  const rolloutPercent=
    Number.isFinite(remote.rolloutPercent)
      ? Math.max(
          0,
          Math.min(100,remote.rolloutPercent)
        )
      : 0;

  if(
    bucket===null ||
    bucket>=Math.round(rolloutPercent*100)
  ){
    return Object.freeze({
      ...base,
      attempted:false,
      completed:false,
      gateReason:'cohort_not_eligible',
      cohortBucket:bucket,
    });
  }

  if(syntheticOnlyEnabled===true){
    if(!_isExplicitSynthetic(patientContext)){
      return Object.freeze({
        ...base,
        attempted:false,
        completed:false,
        gateReason:'synthetic_only_non_synthetic',
      });
    }

    if(
      !_safeEqualHex(
        _sha256Hex(uid),
        proofUidSha256
      )
    ){
      return Object.freeze({
        ...base,
        attempted:false,
        completed:false,
        gateReason:'synthetic_only_uid_not_allowed',
      });
    }
  }

  let providerInput=null;

  if(_isExplicitSynthetic(patientContext)){
    providerInput=_syntheticInput({
      userMessage,
      history,
      patientContext,
      escalationReasons,
    });
  }else{
    if(
      !providerDataPolicy ||
      providerDataPolicy.ready!==true
    ){
      return Object.freeze({
        ...base,
        attempted:false,
        completed:false,
        gateReason:'protected_clinical_policy_missing',
      });
    }

    providerInput=
        buildProtectedClinicalRouterInputSafeV2(
          protectedClinicalProjection
        );

    if(!providerInput){
      return Object.freeze({
        ...base,
        attempted:false,
        completed:false,
        gateReason:'protected_clinical_projection_invalid',
      });
    }
  }

  if(
    typeof openAiApiKey!=='string' ||
    openAiApiKey.length===0
  ){
    return Object.freeze({
      ...base,
      attempted:false,
      completed:false,
      gateReason:'provider_key_missing',
    });
  }

  if(typeof fetchFn!=='function'){
    return Object.freeze({
      ...base,
      attempted:false,
      completed:false,
      gateReason:'fetch_unavailable',
    });
  }

  const timeoutMs=
    Number.isInteger(remote.timeoutMs)
      ? Math.max(
          3000,
          Math.min(remote.timeoutMs,60000)
        )
      : 30000;

  const maxOutputTokens=
    Number.isInteger(remote.maxOutputTokens)
      ? Math.max(
          1024,
          Math.min(remote.maxOutputTokens,16384)
        )
      : 8192;

  const reasoningEffort=
    ['none','low','medium','high','xhigh','max']
      .includes(remote.reasoningEffort)
        ? remote.reasoningEffort
        : 'high';

  const controller=new AbortController();
  const timer=setTimeout(
    ()=>controller.abort(),
    timeoutMs
  );
  const started=Date.now();

  try{
    const response=
      await fetchFn(
        TERRA_ENDPOINT,
        {
          method:'POST',
          headers:{
            'content-type':'application/json',
            'authorization':`Bearer ${openAiApiKey}`,
          },
          body:JSON.stringify(
            buildGpt56TerraRequest({
              providerInput,
              maxOutputTokens,
              reasoningEffort,
            })
          ),
          signal:controller.signal,
        }
      );

    const httpStatus=response.status;
    const data=await response.json();
    const providerStatus=
      data && typeof data.status==='string'
        ? data.status
        : null;
    const incompleteReason=
      data &&
      data.incomplete_details &&
      typeof data.incomplete_details.reason==='string'
        ? data.incomplete_details.reason
        : null;
    const text=_extractOutputText(data);

    let parsed=null;
    let jsonParsed=false;

    if(text.length>0){
      try{
        parsed=JSON.parse(text);
        jsonParsed=true;
      }catch(_err){
        parsed=null;
      }
    }

    const schemaValid=
      jsonParsed &&
      _isValidClinicalResult(parsed);

    const failureClass=
      classifyGpt56TerraTechnicalOutcome({
        httpStatus,
        providerStatus,
        incompleteReason,
        outputTextPresent:text.length>0,
        jsonParsed,
        schemaValid,
      });

    const usage=_usage(data);
    const cost=estimateGpt56TerraCost(usage);
    const completed=failureClass===null;

    return Object.freeze({
      ...base,
      attempted:true,
      completed,
      gateReason:'open',
      httpStatus,
      providerStatus,
      incompleteReason,
      failureClass,
      technicalFailure:
        failureClass!==null,
      responseValid:completed,
      validatorVersion:
        TERRA_VALIDATOR_VERSION,
      pricingVersion:
        TERRA_PRICING_VERSION,
      inputTokens:
        usage.inputTokens,
      cachedInputTokens:
        usage.cachedInputTokens,
      cacheWriteInputTokens:
        usage.cacheWriteInputTokens,
      outputTokens:
        usage.outputTokens,
      reasoningTokens:
        usage.reasoningTokens,
      longContextPricingApplied:
        cost.longContextPricingApplied,
      estimatedCostNanoUsd:
        cost.estimatedCostNanoUsd,
      estimatedCostUsd:
        cost.estimatedCostUsd,
      elapsedMs:Date.now()-started,
      parsedClinicalResult:
        completed
          ? parsed
          : null,
      cohortBucket:bucket,
    });
  }catch(err){
    const failureClass=
      classifyGpt56TerraTechnicalOutcome({
        exceptionName:
          err && typeof err.name==='string'
            ? err.name
            : null,
        exceptionCode:
          err && typeof err.code==='string'
            ? err.code
            : null,
      });

    return Object.freeze({
      ...base,
      attempted:true,
      completed:false,
      gateReason:'provider_exception',
      failureClass,
      technicalFailure:true,
      responseValid:false,
      validatorVersion:
        TERRA_VALIDATOR_VERSION,
      pricingVersion:
        TERRA_PRICING_VERSION,
      inputTokens:null,
      cachedInputTokens:null,
      cacheWriteInputTokens:null,
      outputTokens:null,
      reasoningTokens:null,
      longContextPricingApplied:false,
      estimatedCostNanoUsd:null,
      estimatedCostUsd:null,
      elapsedMs:Date.now()-started,
      cohortBucket:bucket,
    });
  }finally{
    clearTimeout(timer);
  }
}

function buildGpt56TerraShadowTelemetry(result){
  const r=_isPlainObject(result)
    ? result
    : {};

  return Object.freeze({
    provider:'openai',
    model:TERRA_MODEL,
    alias:TERRA_ALIAS,
    attempted:r.attempted===true,
    completed:r.completed===true,
    gateReason:
      typeof r.gateReason==='string'
        ? r.gateReason
        : null,
    clinicalEscalation:
      r.clinicalEscalation===true,
    terraAllowed:
      r.terraAllowed===true,
    upstreamTechnicalFailure:
      r.upstreamTechnicalFailure===true,
    upstreamFailureClass:
      typeof r.upstreamFailureClass==='string'
        ? r.upstreamFailureClass
        : null,
    httpStatus:
      Number.isInteger(r.httpStatus)
        ? r.httpStatus
        : null,
    providerStatus:
      typeof r.providerStatus==='string'
        ? r.providerStatus
        : null,
    failureClass:
      typeof r.failureClass==='string'
        ? r.failureClass
        : null,
    technicalFailure:
      r.technicalFailure===true,
    responseValid:
      r.responseValid===true,
    validatorVersion:
      typeof r.validatorVersion==='string'
        ? r.validatorVersion
        : TERRA_VALIDATOR_VERSION,
    pricingVersion:
      typeof r.pricingVersion==='string'
        ? r.pricingVersion
        : TERRA_PRICING_VERSION,
    inputTokens:
      Number.isInteger(r.inputTokens)
        ? r.inputTokens
        : null,
    cachedInputTokens:
      Number.isInteger(r.cachedInputTokens)
        ? r.cachedInputTokens
        : null,
    cacheWriteInputTokens:
      Number.isInteger(r.cacheWriteInputTokens)
        ? r.cacheWriteInputTokens
        : null,
    outputTokens:
      Number.isInteger(r.outputTokens)
        ? r.outputTokens
        : null,
    reasoningTokens:
      Number.isInteger(r.reasoningTokens)
        ? r.reasoningTokens
        : null,
    longContextPricingApplied:
      r.longContextPricingApplied===true,
    estimatedCostNanoUsd:
      Number.isInteger(r.estimatedCostNanoUsd)
        ? r.estimatedCostNanoUsd
        : null,
    estimatedCostUsd:
      Number.isFinite(r.estimatedCostUsd)
        ? r.estimatedCostUsd
        : null,
    elapsedMs:
      Number.isInteger(r.elapsedMs)
        ? r.elapsedMs
        : null,
    cohortBucket:
      Number.isInteger(r.cohortBucket)
        ? r.cohortBucket
        : null,
    userResponseAuthority:false,
    liveModelSelectionAuthority:false,
    liveErrorPathAuthority:false,
    technicalFallbackAuthority:false,
    liveAuthorityChanged:false,
    telemetryOnly:true,
  });
}

module.exports={
  TERRA_MODEL,
  TERRA_ALIAS,
  TERRA_ENDPOINT,
  TERRA_REMOTE_FLAG,
  TERRA_SERVER_GATE,
  TERRA_SYNTHETIC_ONLY_GATE,
  TERRA_PROOF_UID_SHA_ENV,
  TERRA_VALIDATOR_VERSION,
  TERRA_PRICING_VERSION,
  TERRA_LONG_CONTEXT_THRESHOLD_INPUT_TOKENS,
  TERRA_COST_NANO_USD_PER_TOKEN,
  TERRA_CLINICAL_SCHEMA,
  deterministicTerraShadowBucket,
  buildGpt56TerraRequest,
  estimateGpt56TerraCost,
  classifyGpt56TerraTechnicalOutcome,
  runGpt56TerraPlantaoComplexEscalationShadow,
  buildGpt56TerraShadowTelemetry,
};
