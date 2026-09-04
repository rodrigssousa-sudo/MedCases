'use strict';
const {
  buildProtectedClinicalRouterInputSafeV2,
} = require(
  './protected_clinical_data_policy_v2'
);


const crypto=require('crypto');

const GEMINI_MODEL='gemini-3.1-flash-lite';
const GEMINI_ALIAS='plantao_cross_provider';
const GEMINI_ENDPOINT='https://generativelanguage.googleapis.com/v1beta/interactions';
const GEMINI_REMOTE_FLAG='gemini31_paid_real_shadow_v1';
const GEMINI_SERVER_GATE='AI_GEMINI31_PAID_REAL_SHADOW_ENABLED';
const GEMINI_SYNTHETIC_ONLY_GATE='AI_GEMINI31_PAID_REAL_SHADOW_SYNTHETIC_ONLY';
const GEMINI_PROOF_UID_SHA_ENV='AI_GEMINI31_PAID_REAL_SHADOW_PROOF_UID_SHA256';
const GEMINI_VALIDATOR_VERSION='medcases_gemini31_paid_validator_v1';
const GEMINI_PRICING_VERSION='google_gemini31_flash_lite_paid_2026_08_29_v1';

const GEMINI_COST_NANO_USD_PER_TOKEN=Object.freeze({
  textInput:250,
  cachedTextInput:25,
  outputOrThought:1500,
});

const GEMINI_CLINICAL_SCHEMA=Object.freeze({
  type:'object',
  additionalProperties:false,
  properties:{
    clinical_summary:{
      type:'string',
    },
    differential:{
      type:'array',
      items:{type:'string'},
    },
    critical_actions:{
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
    'clinical_summary',
    'differential',
    'critical_actions',
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

function _int(value){
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
}){
  return JSON.stringify({
    synthetic:true,
    realPatient:false,
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

function deterministicGemini31PaidShadowBucket(
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
      config.shadowProviderCalls.gemini31Paid
    )
  )
    ? config.shadowProviderCalls.gemini31Paid
    : null;
}

function buildGemini31PaidRequest({
  providerInput,
  maxOutputTokens,
}={}){
  return {
    model:GEMINI_MODEL,
    input:
      typeof providerInput==='string'
        ? providerInput
        : '',
    store:false,
    generation_config:{
      max_output_tokens:
        Number.isInteger(maxOutputTokens)
          ? Math.max(
              256,
              Math.min(maxOutputTokens,8192)
            )
          : 2048,
    },
    response_format:{
      type:'text',
      mime_type:'application/json',
      schema:GEMINI_CLINICAL_SCHEMA,
    },
  };
}

function _extractOutputText(data){
  if(!data || !Array.isArray(data.steps)){
    return '';
  }

  const texts=[];

  for(const step of data.steps){
    if(
      !step ||
      step.type!=='model_output' ||
      !Array.isArray(step.content)
    ){
      continue;
    }

    for(const block of step.content){
      if(
        block &&
        block.type==='text' &&
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
    typeof v.clinical_summary==='string' &&
    Array.isArray(v.differential) &&
    Array.isArray(v.critical_actions) &&
    Array.isArray(v.safety_flags) &&
    Array.isArray(v.uncertainties) &&
    ['low','medium','high'].includes(v.confidence) &&
    typeof v.needs_more_information==='boolean'
  );
}

function estimateGemini31PaidCost({
  inputTokens,
  cachedInputTokens,
  outputTokens,
  thoughtTokens,
}={}){
  const input=_int(inputTokens);
  const cached=Math.min(
    input,
    _int(cachedInputTokens)
  );
  const uncached=Math.max(0,input-cached);
  const output=_int(outputTokens);
  const thoughts=_int(thoughtTokens);

  const estimatedCostNanoUsd=
    uncached*
      GEMINI_COST_NANO_USD_PER_TOKEN.textInput+
    cached*
      GEMINI_COST_NANO_USD_PER_TOKEN.cachedTextInput+
    (output+thoughts)*
      GEMINI_COST_NANO_USD_PER_TOKEN.outputOrThought;

  return Object.freeze({
    pricingVersion:GEMINI_PRICING_VERSION,
    inputTokens:input,
    cachedInputTokens:cached,
    uncachedInputTokens:uncached,
    outputTokens:output,
    thoughtTokens:thoughts,
    estimatedCostNanoUsd,
    estimatedCostUsd:
      estimatedCostNanoUsd/1000000000,
  });
}

function classifyGemini31PaidTechnicalOutcome({
  httpStatus,
  providerStatus,
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

  return Object.freeze({
    inputTokens:
      Number.isInteger(usage.total_input_tokens)
        ? usage.total_input_tokens
        : null,
    cachedInputTokens:
      Number.isInteger(usage.total_cached_tokens)
        ? usage.total_cached_tokens
        : null,
    outputTokens:
      Number.isInteger(usage.total_output_tokens)
        ? usage.total_output_tokens
        : null,
    thoughtTokens:
      Number.isInteger(usage.total_thought_tokens)
        ? usage.total_thought_tokens
        : null,
  });
}

async function runGemini31FlashLitePaidCrossProviderShadow({
  config=null,
  uid='',
  mode='plantao',
  upstreamTechnicalFailure=false,
  upstreamFailureClass=null,
  upstreamClinicalEscalation=false,
  userMessage='',
  history=[],
  patientContext=null,
  providerDataPolicy=null,
  protectedClinicalProjection=null,
  geminiApiKey='',
  serverEnabled=
    process.env[GEMINI_SERVER_GATE]==='true',
  syntheticOnlyEnabled=
    process.env[GEMINI_SYNTHETIC_ONLY_GATE]==='true',
  proofUidSha256=
    process.env[GEMINI_PROOF_UID_SHA_ENV] || '',
  fetchFn=globalThis.fetch,
}={}){
  const base=Object.freeze({
    provider:'google',
    model:GEMINI_MODEL,
    alias:GEMINI_ALIAS,
    upstreamTechnicalFailure:
      upstreamTechnicalFailure===true,
    upstreamFailureClass:
      typeof upstreamFailureClass==='string'
        ? upstreamFailureClass
        : null,
    upstreamClinicalEscalation:
      upstreamClinicalEscalation===true,
    userResponseAuthority:false,
    liveModelSelectionAuthority:false,
    liveErrorPathAuthority:false,
    clinicalEscalationAuthority:false,
    terraRoutingAuthority:false,
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

  if(upstreamTechnicalFailure!==true){
    return Object.freeze({
      ...base,
      attempted:false,
      completed:false,
      gateReason:
        upstreamClinicalEscalation===true
          ? 'clinical_escalation_not_technical_fallback'
          : 'technical_fallback_not_required',
    });
  }

  const remote=_remoteConfig(config);

  if(
    !config ||
    !config.featureFlags ||
    config.featureFlags[GEMINI_REMOTE_FLAG]!==true ||
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
    deterministicGemini31PaidShadowBucket(
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
    typeof geminiApiKey!=='string' ||
    geminiApiKey.length===0
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
          1000,
          Math.min(remote.timeoutMs,30000)
        )
      : 12000;

  const maxOutputTokens=
    Number.isInteger(remote.maxOutputTokens)
      ? Math.max(
          256,
          Math.min(remote.maxOutputTokens,8192)
        )
      : 2048;

  const controller=new AbortController();
  const timer=setTimeout(
    ()=>controller.abort(),
    timeoutMs
  );
  const started=Date.now();

  try{
    const response=
      await fetchFn(
        GEMINI_ENDPOINT,
        {
          method:'POST',
          headers:{
            'content-type':'application/json',
            'x-goog-api-key':geminiApiKey,
          },
          body:JSON.stringify(
            buildGemini31PaidRequest({
              providerInput,
              maxOutputTokens,
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
      classifyGemini31PaidTechnicalOutcome({
        httpStatus,
        providerStatus,
        outputTextPresent:text.length>0,
        jsonParsed,
        schemaValid,
      });

    const usage=_usage(data);
    const cost=estimateGemini31PaidCost(usage);
    const completed=failureClass===null;

    return Object.freeze({
      ...base,
      attempted:true,
      completed,
      gateReason:'open',
      httpStatus,
      providerStatus,
      failureClass,
      technicalFailure:
        failureClass!==null,
      responseValid:completed,
      validatorVersion:
        GEMINI_VALIDATOR_VERSION,
      pricingVersion:
        GEMINI_PRICING_VERSION,
      inputTokens:
        usage.inputTokens,
      cachedInputTokens:
        usage.cachedInputTokens,
      outputTokens:
        usage.outputTokens,
      thoughtTokens:
        usage.thoughtTokens,
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
      classifyGemini31PaidTechnicalOutcome({
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
        GEMINI_VALIDATOR_VERSION,
      pricingVersion:
        GEMINI_PRICING_VERSION,
      inputTokens:null,
      cachedInputTokens:null,
      outputTokens:null,
      thoughtTokens:null,
      estimatedCostNanoUsd:null,
      estimatedCostUsd:null,
      elapsedMs:Date.now()-started,
      cohortBucket:bucket,
    });
  }finally{
    clearTimeout(timer);
  }
}

function buildGemini31PaidShadowTelemetry(result){
  const r=_isPlainObject(result)
    ? result
    : {};

  return Object.freeze({
    provider:'google',
    model:GEMINI_MODEL,
    alias:GEMINI_ALIAS,
    attempted:r.attempted===true,
    completed:r.completed===true,
    gateReason:
      typeof r.gateReason==='string'
        ? r.gateReason
        : null,
    upstreamTechnicalFailure:
      r.upstreamTechnicalFailure===true,
    upstreamFailureClass:
      typeof r.upstreamFailureClass==='string'
        ? r.upstreamFailureClass
        : null,
    upstreamClinicalEscalation:
      r.upstreamClinicalEscalation===true,
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
        : GEMINI_VALIDATOR_VERSION,
    pricingVersion:
      typeof r.pricingVersion==='string'
        ? r.pricingVersion
        : GEMINI_PRICING_VERSION,
    inputTokens:
      Number.isInteger(r.inputTokens)
        ? r.inputTokens
        : null,
    cachedInputTokens:
      Number.isInteger(r.cachedInputTokens)
        ? r.cachedInputTokens
        : null,
    outputTokens:
      Number.isInteger(r.outputTokens)
        ? r.outputTokens
        : null,
    thoughtTokens:
      Number.isInteger(r.thoughtTokens)
        ? r.thoughtTokens
        : null,
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
    clinicalEscalationAuthority:false,
    terraRoutingAuthority:false,
    liveAuthorityChanged:false,
    telemetryOnly:true,
  });
}

module.exports={
  GEMINI_MODEL,
  GEMINI_ALIAS,
  GEMINI_ENDPOINT,
  GEMINI_REMOTE_FLAG,
  GEMINI_SERVER_GATE,
  GEMINI_SYNTHETIC_ONLY_GATE,
  GEMINI_PROOF_UID_SHA_ENV,
  GEMINI_VALIDATOR_VERSION,
  GEMINI_PRICING_VERSION,
  GEMINI_COST_NANO_USD_PER_TOKEN,
  GEMINI_CLINICAL_SCHEMA,
  deterministicGemini31PaidShadowBucket,
  buildGemini31PaidRequest,
  estimateGemini31PaidCost,
  classifyGemini31PaidTechnicalOutcome,
  runGemini31FlashLitePaidCrossProviderShadow,
  buildGemini31PaidShadowTelemetry,
};
