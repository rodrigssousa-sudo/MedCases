'use strict';

const crypto=require('crypto');

const {
  evaluateProtectedClinicalProviderGate,
  buildProtectedClinicalRouterInputV1,
}=require('./protected_clinical_data_policy_v2');

const LUNA_MODEL='gpt-5.6-luna';
const LUNA_ALIAS='plantao_primary';
const LUNA_REMOTE_FLAG='gpt56_luna_real_shadow_v1';
const LUNA_SERVER_GATE='AI_GPT56_LUNA_REAL_SHADOW_ENABLED';
const LUNA_SYNTHETIC_ONLY_GATE='AI_GPT56_LUNA_REAL_SHADOW_SYNTHETIC_ONLY';
const LUNA_PROOF_UID_SHA_ENV='AI_GPT56_LUNA_REAL_SHADOW_PROOF_UID_SHA256';
const LUNA_ENDPOINT='https://api.openai.com/v1/responses';
const LUNA_VALIDATOR_VERSION='medcases_luna_validator_v1';
const LUNA_PRICING_VERSION='openai_gpt56_luna_api_pricing_2026_07_30_v1';
const LUNA_LONG_CONTEXT_THRESHOLD_INPUT_TOKENS=272000;
const LUNA_COST_NANO_USD_PER_TOKEN=Object.freeze({
  uncachedInput:200,
  cachedInput:20,
  cacheWriteInput:250,
  output:1200,
});

const LUNA_CLINICAL_SCHEMA=Object.freeze({
  type:'object',
  additionalProperties:false,
  properties:{
    clinical_summary:{
      type:'string',
    },
    differential:{
      type:'array',
      maxItems:8,
      items:{
        type:'object',
        additionalProperties:false,
        properties:{
          diagnosis:{type:'string'},
          rationale:{type:'string'},
          urgency:{
            type:'string',
            enum:['critical','high','moderate','low'],
          },
        },
        required:[
          'diagnosis',
          'rationale',
          'urgency',
        ],
      },
    },
    critical_actions:{
      type:'array',
      maxItems:12,
      items:{type:'string'},
    },
    safety_flags:{
      type:'array',
      maxItems:12,
      items:{type:'string'},
    },
    uncertainties:{
      type:'array',
      maxItems:12,
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

function _isExplicitSyntheticPatientContext(patientContext){
  return !!(
    _isPlainObject(patientContext) &&
    patientContext.synthetic===true &&
    patientContext.realPatient===false
  );
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

  const ab=Buffer.from(a.toLowerCase(),'hex');
  const bb=Buffer.from(b.toLowerCase(),'hex');

  return crypto.timingSafeEqual(ab,bb);
}

function _clampInt(value,min,max,fallback){
  const n=Number.parseInt(String(value),10);

  if(!Number.isFinite(n)){
    return fallback;
  }

  return Math.max(min,Math.min(max,n));
}

function deterministicLunaShadowBucket(uid,salt){
  if(
    typeof uid!=='string' ||
    uid.length===0 ||
    typeof salt!=='string' ||
    salt.length===0
  ){
    return null;
  }

  const digest=crypto
    .createHash('sha256')
    .update(`${salt}:${uid}`,'utf8')
    .digest();

  return digest.readUInt32BE(0)%10000;
}

function _remoteState(config){
  const remote=
    config &&
    config.shadowProviderCalls &&
    config.shadowProviderCalls.gpt56Luna;

  if(!_isPlainObject(remote)){
    return null;
  }

  return remote;
}

function evaluateGpt56LunaShadowGate({
  config,
  uid,
  mode,
  serverEnabled,
}={}){
  if(serverEnabled!==true){
    return Object.freeze({
      allowed:false,
      reason:'server_hard_gate_closed',
      bucket:null,
      threshold:null,
    });
  }

  const normalizedMode=
    typeof mode==='string'
      ? mode.trim().toLowerCase()
      : '';

  if(!['plantao','plantão'].includes(normalizedMode)){
    return Object.freeze({
      allowed:false,
      reason:'plantao_only',
      bucket:null,
      threshold:null,
    });
  }

  if(
    !config ||
    config.enabled!==true ||
    !config.featureFlags ||
    config.featureFlags[LUNA_REMOTE_FLAG]!==true
  ){
    return Object.freeze({
      allowed:false,
      reason:'remote_feature_flag_closed',
      bucket:null,
      threshold:null,
    });
  }

  const remote=_remoteState(config);

  if(!remote || remote.enabled!==true){
    return Object.freeze({
      allowed:false,
      reason:'remote_luna_config_closed',
      bucket:null,
      threshold:null,
    });
  }

  if(typeof uid!=='string' || uid.length===0){
    return Object.freeze({
      allowed:false,
      reason:'uid_missing',
      bucket:null,
      threshold:null,
    });
  }

  const rolloutPercent=
    _clampInt(
      remote.rolloutPercent,
      0,
      100,
      0
    );

  const threshold=rolloutPercent*100;

  const bucket=
    deterministicLunaShadowBucket(
      uid,
      remote.cohortSalt
    );

  if(bucket===null){
    return Object.freeze({
      allowed:false,
      reason:'cohort_invalid',
      bucket:null,
      threshold,
    });
  }

  if(bucket>=threshold){
    return Object.freeze({
      allowed:false,
      reason:'outside_cohort',
      bucket,
      threshold,
    });
  }

  return Object.freeze({
    allowed:true,
    reason:'open',
    bucket,
    threshold,
  });
}

function _buildRawInput({
  userMessage,
  history,
  patientContext,
}={}){
  const parts=[];

  if(Array.isArray(history) && history.length>0){
    const safeHistory=history
      .slice(-8)
      .map((item)=>{
        if(!_isPlainObject(item)){
          return null;
        }

        const role=
          typeof item.role==='string'
            ? item.role.trim().toLowerCase()
            : '';

        const text=
          typeof item.content==='string'
            ? item.content
            : (
                typeof item.text==='string'
                  ? item.text
                  : ''
              );

        if(
          !['user','model','assistant'].includes(role) ||
          text.length===0
        ){
          return null;
        }

        return `${role}: ${text.slice(0,6000)}`;
      })
      .filter(Boolean);

    if(safeHistory.length>0){
      parts.push(
        `Recent clinical conversation:\n${safeHistory.join('\n')}`
      );
    }
  }

  if(_isPlainObject(patientContext)){
    const serialized=JSON.stringify(patientContext);

    if(serialized.length>2){
      parts.push(
        `Patient context:\n${serialized.slice(0,12000)}`
      );
    }
  }

  if(typeof userMessage==='string' && userMessage.length>0){
    parts.push(
      `Current clinician request:\n${userMessage.slice(0,16000)}`
    );
  }

  return parts.join('\n\n').trim();
}

function buildGpt56LunaRequest({
  inputText,
  maxOutputTokens,
  reasoningEffort,
}={}){
  const effort=
    ['none','low','medium','high','xhigh','max']
      .includes(reasoningEffort)
      ? reasoningEffort
      : 'low';

  return Object.freeze({
    model:LUNA_MODEL,
    store:false,
    reasoning:{
      effort,
    },
    max_output_tokens:
      _clampInt(
        maxOutputTokens,
        512,
        8192,
        2048
      ),
    input:[
      {
        role:'system',
        content:[
          {
            type:'input_text',
            text:[
              'You are the MedCases Plantão primary clinical reasoning shadow.',
              'Produce a concise structured clinical assessment.',
              'Prioritize life-threatening conditions and immediate safety.',
              'Do not claim certainty when information is insufficient.',
              'This shadow result has no direct user-response authority.',
            ].join(' '),
          },
        ],
      },
      {
        role:'user',
        content:[
          {
            type:'input_text',
            text:inputText,
          },
        ],
      },
    ],
    text:{
      format:{
        type:'json_schema',
        name:'medcases_plantao_primary_shadow_v1',
        strict:true,
        schema:LUNA_CLINICAL_SCHEMA,
      },
    },
  });
}

function _extractOutputText(data){
  if(
    data &&
    typeof data.output_text==='string' &&
    data.output_text.trim().length>0
  ){
    return data.output_text.trim();
  }

  if(!data || !Array.isArray(data.output)){
    return '';
  }

  const chunks=[];

  for(const item of data.output){
    if(!item || !Array.isArray(item.content)){
      continue;
    }

    for(const content of item.content){
      if(
        content &&
        typeof content.text==='string' &&
        content.text.length>0
      ){
        chunks.push(content.text);
      }
    }
  }

  return chunks.join('\n').trim();
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

function _usageInt(value){
  return Number.isInteger(value) && value>=0
    ? value
    : 0;
}

function estimateGpt56LunaCost({
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
    input>LUNA_LONG_CONTEXT_THRESHOLD_INPUT_TOKENS;
  const inputMultiplier=longContext ? 2 : 1;
  const outputMultiplier=longContext ? 1.5 : 1;

  const nanoUsd=
    (
      uncached*
      LUNA_COST_NANO_USD_PER_TOKEN.uncachedInput*
      inputMultiplier
    )+
    (
      cached*
      LUNA_COST_NANO_USD_PER_TOKEN.cachedInput*
      inputMultiplier
    )+
    (
      cacheWrite*
      LUNA_COST_NANO_USD_PER_TOKEN.cacheWriteInput*
      inputMultiplier
    )+
    (
      output*
      LUNA_COST_NANO_USD_PER_TOKEN.output*
      outputMultiplier
    );

  return Object.freeze({
    pricingVersion:LUNA_PRICING_VERSION,
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

function classifyGpt56LunaTechnicalOutcome({
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
    const name=String(exceptionName||'').toLowerCase();
    const code=String(exceptionCode||'').toLowerCase();

    if(
      name.includes('abort') ||
      name.includes('timeout') ||
      code.includes('abort') ||
      code.includes('timeout')
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

function _extractUsage(data){
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
      Number.isFinite(usage.input_tokens)
        ? usage.input_tokens
        : null,
    cachedInputTokens:
      Number.isFinite(inputDetails.cached_tokens)
        ? inputDetails.cached_tokens
        : null,
    cacheWriteInputTokens:
      Number.isFinite(inputDetails.cache_write_tokens)
        ? inputDetails.cache_write_tokens
        : null,
    outputTokens:
      Number.isFinite(usage.output_tokens)
        ? usage.output_tokens
        : null,
    reasoningTokens:
      Number.isFinite(outputDetails.reasoning_tokens)
        ? outputDetails.reasoning_tokens
        : null,
  });
}

async function runGpt56LunaPlantaoPrimaryShadow({
  config,
  uid,
  mode,
  userMessage,
  history,
  patientContext,
  providerDataPolicy=null,
  protectedClinicalProjection=null,
  openAiApiKey,
  fetchFn=globalThis.fetch,
  serverEnabled=
    process.env[LUNA_SERVER_GATE]==='true',
  syntheticOnlyEnabled=
    process.env[LUNA_SYNTHETIC_ONLY_GATE]==='true',
  proofUidSha256=
    process.env[LUNA_PROOF_UID_SHA_ENV] || '',
}={}){
  const gate=
    evaluateGpt56LunaShadowGate({
      config,
      uid,
      mode,
      serverEnabled,
    });

  if(!gate.allowed){
    return Object.freeze({
      attempted:false,
      completed:false,
      gateReason:gate.reason,
      provider:'openai',
      model:LUNA_MODEL,
      alias:LUNA_ALIAS,
      userResponseAuthority:false,
      liveModelSelectionAuthority:false,
      liveErrorPathAuthority:false,
      liveAuthorityChanged:false,
      telemetryOnly:true,
    });
  }

  if(syntheticOnlyEnabled===true){
    if(
      !_isExplicitSyntheticPatientContext(
        patientContext
      )
    ){
      return Object.freeze({
        attempted:false,
        completed:false,
        gateReason:'synthetic_only_non_synthetic',
        provider:'openai',
        model:LUNA_MODEL,
        alias:LUNA_ALIAS,
        userResponseAuthority:false,
        liveModelSelectionAuthority:false,
        liveErrorPathAuthority:false,
        liveAuthorityChanged:false,
        telemetryOnly:true,
      });
    }

    const uidHash=_sha256Hex(uid);

    if(
      !_safeEqualHex(
        uidHash,
        proofUidSha256
      )
    ){
      return Object.freeze({
        attempted:false,
        completed:false,
        gateReason:'synthetic_only_uid_not_allowed',
        provider:'openai',
        model:LUNA_MODEL,
        alias:LUNA_ALIAS,
        userResponseAuthority:false,
        liveModelSelectionAuthority:false,
        liveErrorPathAuthority:false,
        liveAuthorityChanged:false,
        telemetryOnly:true,
      });
    }
  }

  if(
    typeof openAiApiKey!=='string' ||
    openAiApiKey.length===0
  ){
    return Object.freeze({
      attempted:false,
      completed:false,
      gateReason:'openai_key_missing',
      provider:'openai',
      model:LUNA_MODEL,
      alias:LUNA_ALIAS,
      userResponseAuthority:false,
      liveModelSelectionAuthority:false,
      liveErrorPathAuthority:false,
      liveAuthorityChanged:false,
      telemetryOnly:true,
    });
  }

  const protectedGate=
    evaluateProtectedClinicalProviderGate({
      patientContext,
      providerDataPolicy,
      protectedClinicalProjection,
    });

  if(!protectedGate.allowed){
    return Object.freeze({
      attempted:false,
      completed:false,
      gateReason:protectedGate.reason,
      provider:'openai',
      model:LUNA_MODEL,
      alias:LUNA_ALIAS,
      userResponseAuthority:false,
      liveModelSelectionAuthority:false,
      liveErrorPathAuthority:false,
      liveAuthorityChanged:false,
      telemetryOnly:true,
    });
  }

  let inputText=
    _buildRawInput({
      userMessage,
      history,
      patientContext,
    });

  if(protectedGate.useProtectedProjection){
    inputText=
      buildProtectedClinicalRouterInputV1(
        protectedClinicalProjection
      );
  }

  if(inputText.length===0){
    return Object.freeze({
      attempted:false,
      completed:false,
      gateReason:'empty_clinical_input',
      provider:'openai',
      model:LUNA_MODEL,
      alias:LUNA_ALIAS,
      userResponseAuthority:false,
      liveModelSelectionAuthority:false,
      liveErrorPathAuthority:false,
      liveAuthorityChanged:false,
      telemetryOnly:true,
    });
  }

  const remote=_remoteState(config)||{};

  const payload=
    buildGpt56LunaRequest({
      inputText,
      maxOutputTokens:remote.maxOutputTokens,
      reasoningEffort:remote.reasoningEffort,
    });

  const timeoutMs=
    _clampInt(
      remote.timeoutMs,
      1000,
      30000,
      12000
    );

  const started=Date.now();

  try{
    const response=
      await fetchFn(
        LUNA_ENDPOINT,
        {
          method:'POST',
          headers:{
            'Content-Type':'application/json',
            Authorization:`Bearer ${openAiApiKey}`,
          },
          body:JSON.stringify(payload),
          signal:AbortSignal.timeout(timeoutMs),
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
    const usage=_extractUsage(data);
    const cost=estimateGpt56LunaCost(usage);
    const text=_extractOutputText(data);

    let parsed=null;
    let jsonParsed=false;

    if(text.length>0){
      try{
        parsed=JSON.parse(text);
        jsonParsed=true;
      }catch(_err){
        parsed=null;
        jsonParsed=false;
      }
    }

    const schemaValid=
      jsonParsed &&
      _isValidClinicalResult(parsed);

    const failureClass=
      classifyGpt56LunaTechnicalOutcome({
        httpStatus,
        providerStatus,
        incompleteReason,
        outputTextPresent:text.length>0,
        jsonParsed,
        schemaValid,
      });

    const completed=failureClass===null;

    return Object.freeze({
      attempted:true,
      completed,
      gateReason:'open',
      provider:'openai',
      model:LUNA_MODEL,
      alias:LUNA_ALIAS,
      httpStatus,
      providerStatus,
      incompleteReason,
      failureClass,
      technicalFailure:failureClass!==null,
      responseValid:completed,
      validatorVersion:LUNA_VALIDATOR_VERSION,
      pricingVersion:cost.pricingVersion,
      inputTokens:usage.inputTokens,
      cachedInputTokens:usage.cachedInputTokens,
      cacheWriteInputTokens:usage.cacheWriteInputTokens,
      outputTokens:usage.outputTokens,
      reasoningTokens:usage.reasoningTokens,
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
      userResponseAuthority:false,
      liveModelSelectionAuthority:false,
      liveErrorPathAuthority:false,
      liveAuthorityChanged:false,
      telemetryOnly:true,
    });
  }catch(err){
    const failureClass=
      classifyGpt56LunaTechnicalOutcome({
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
      attempted:true,
      completed:false,
      gateReason:'provider_exception',
      provider:'openai',
      model:LUNA_MODEL,
      alias:LUNA_ALIAS,
      failureClass,
      technicalFailure:true,
      responseValid:false,
      validatorVersion:LUNA_VALIDATOR_VERSION,
      pricingVersion:LUNA_PRICING_VERSION,
      inputTokens:null,
      cachedInputTokens:null,
      cacheWriteInputTokens:null,
      outputTokens:null,
      reasoningTokens:null,
      longContextPricingApplied:false,
      estimatedCostNanoUsd:null,
      estimatedCostUsd:null,
      elapsedMs:Date.now()-started,
      userResponseAuthority:false,
      liveModelSelectionAuthority:false,
      liveErrorPathAuthority:false,
      liveAuthorityChanged:false,
      telemetryOnly:true,
    });
  }
}

function buildGpt56LunaShadowTelemetry(result){
  if(!_isPlainObject(result)){
    return Object.freeze({
      provider:'openai',
      model:LUNA_MODEL,
      alias:LUNA_ALIAS,
      attempted:false,
      completed:false,
      gateReason:'result_missing',
      telemetryOnly:true,
    });
  }

  return Object.freeze({
    provider:'openai',
    model:LUNA_MODEL,
    alias:LUNA_ALIAS,
    attempted:result.attempted===true,
    completed:result.completed===true,
    gateReason:
      typeof result.gateReason==='string'
        ? result.gateReason
        : 'unknown',
    httpStatus:
      Number.isInteger(result.httpStatus)
        ? result.httpStatus
        : null,
    providerStatus:
      typeof result.providerStatus==='string'
        ? result.providerStatus
        : null,
    incompleteReason:
      typeof result.incompleteReason==='string'
        ? result.incompleteReason
        : null,
    failureClass:
      typeof result.failureClass==='string'
        ? result.failureClass
        : null,
    technicalFailure:
      result.technicalFailure===true,
    responseValid:
      result.responseValid===true,
    validatorVersion:
      typeof result.validatorVersion==='string'
        ? result.validatorVersion
        : LUNA_VALIDATOR_VERSION,
    pricingVersion:
      typeof result.pricingVersion==='string'
        ? result.pricingVersion
        : LUNA_PRICING_VERSION,
    inputTokens:
      Number.isFinite(result.inputTokens)
        ? result.inputTokens
        : null,
    cachedInputTokens:
      Number.isFinite(result.cachedInputTokens)
        ? result.cachedInputTokens
        : null,
    cacheWriteInputTokens:
      Number.isFinite(result.cacheWriteInputTokens)
        ? result.cacheWriteInputTokens
        : null,
    outputTokens:
      Number.isFinite(result.outputTokens)
        ? result.outputTokens
        : null,
    reasoningTokens:
      Number.isFinite(result.reasoningTokens)
        ? result.reasoningTokens
        : null,
    longContextPricingApplied:
      result.longContextPricingApplied===true,
    estimatedCostNanoUsd:
      Number.isFinite(result.estimatedCostNanoUsd)
        ? result.estimatedCostNanoUsd
        : null,
    estimatedCostUsd:
      Number.isFinite(result.estimatedCostUsd)
        ? result.estimatedCostUsd
        : null,
    elapsedMs:
      Number.isFinite(result.elapsedMs)
        ? result.elapsedMs
        : null,
    userResponseAuthority:false,
    liveModelSelectionAuthority:false,
    liveErrorPathAuthority:false,
    liveAuthorityChanged:false,
    telemetryOnly:true,
  });
}

module.exports={
  LUNA_MODEL,
  LUNA_ALIAS,
  LUNA_REMOTE_FLAG,
  LUNA_SERVER_GATE,
  LUNA_SYNTHETIC_ONLY_GATE,
  LUNA_PROOF_UID_SHA_ENV,
  LUNA_ENDPOINT,
  LUNA_VALIDATOR_VERSION,
  LUNA_PRICING_VERSION,
  LUNA_LONG_CONTEXT_THRESHOLD_INPUT_TOKENS,
  LUNA_COST_NANO_USD_PER_TOKEN,
  LUNA_CLINICAL_SCHEMA,
  deterministicLunaShadowBucket,
  evaluateGpt56LunaShadowGate,
  buildGpt56LunaRequest,
  estimateGpt56LunaCost,
  classifyGpt56LunaTechnicalOutcome,
  runGpt56LunaPlantaoPrimaryShadow,
  buildGpt56LunaShadowTelemetry,
};
