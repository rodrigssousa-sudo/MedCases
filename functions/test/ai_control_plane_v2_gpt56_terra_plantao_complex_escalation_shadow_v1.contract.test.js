'use strict';

const assert=require('assert');

const mod=require(
  '../lib/ai_control_plane_v2/gpt56_terra_plantao_complex_escalation_shadow_v1'
);

function config(){
  return {
    featureFlags:{
      gpt56_terra_real_shadow_v1:true,
    },
    shadowProviderCalls:{
      gpt56Terra:{
        enabled:true,
        rolloutPercent:100,
        cohortSalt:'terra-contract',
        timeoutMs:30000,
        maxOutputTokens:8192,
        reasoningEffort:'high',
      },
    },
  };
}

function validClinical(){
  return {
    clinical_synthesis:'Synthetic complex case.',
    diagnostic_conflicts:[],
    differential:[],
    critical_actions:[],
    disposition:[],
    safety_flags:[],
    uncertainties:[],
    confidence:'high',
    needs_more_information:false,
  };
}

function completedResponse(){
  return {
    id:'resp_terra_contract',
    object:'response',
    status:'completed',
    model:'gpt-5.6-terra',
    output:[
      {
        type:'message',
        content:[
          {
            type:'output_text',
            text:JSON.stringify(
              validClinical()
            ),
          },
        ],
      },
    ],
    usage:{
      input_tokens:300,
      input_tokens_details:{
        cached_tokens:40,
        cache_write_tokens:20,
      },
      output_tokens:500,
      output_tokens_details:{
        reasoning_tokens:120,
      },
    },
  };
}

(async()=>{
  assert.strictEqual(
    mod.TERRA_MODEL,
    'gpt-5.6-terra'
  );

  assert.strictEqual(
    mod.TERRA_ALIAS,
    'plantao_complex'
  );

  assert.strictEqual(
    mod.TERRA_ENDPOINT,
    'https://api.openai.com/v1/responses'
  );

  const req=
    mod.buildGpt56TerraRequest({
      providerInput:'synthetic',
      maxOutputTokens:8192,
      reasoningEffort:'high',
    });

  assert.strictEqual(req.model,'gpt-5.6-terra');
  assert.strictEqual(req.store,false);
  assert.strictEqual(req.reasoning.effort,'high');
  assert.strictEqual(req.max_output_tokens,8192);
  assert.strictEqual(req.text.format.type,'json_schema');
  assert.strictEqual(req.text.format.strict,true);
  assert.strictEqual('temperature' in req,false);
  assert.strictEqual('top_p' in req,false);
  assert.strictEqual('tools' in req,false);

  const cost=
    mod.estimateGpt56TerraCost({
      inputTokens:300,
      cachedInputTokens:40,
      cacheWriteInputTokens:20,
      outputTokens:500,
    });

  assert.strictEqual(
    cost.estimatedCostNanoUsd,
    6538000
  );

  assert.strictEqual(
    cost.estimatedCostUsd,
    0.006538
  );

  const longCost=
    mod.estimateGpt56TerraCost({
      inputTokens:1000000,
      cachedInputTokens:500000,
      cacheWriteInputTokens:100000,
      outputTokens:1000000,
    });

  assert.strictEqual(
    longCost.longContextPricingApplied,
    true
  );

  assert.strictEqual(
    longCost.estimatedCostNanoUsd,
    20300000000
  );

  let closedFetch=0;

  const closed=
    await mod.runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid:'terra-contract-user',
      clinicalEscalation:true,
      terraAllowed:true,
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'fake',
      serverEnabled:false,
      fetchFn:async()=>{
        closedFetch++;
      },
    });

  assert.strictEqual(closedFetch,0);
  assert.strictEqual(closed.attempted,false);
  assert.strictEqual(
    closed.gateReason,
    'server_hard_gate_closed'
  );

  let technicalOnlyFetch=0;

  const technicalOnly=
    await mod.runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid:'terra-contract-user',
      clinicalEscalation:false,
      terraAllowed:true,
      upstreamTechnicalFailure:true,
      upstreamFailureClass:'technical_timeout',
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async()=>{
        technicalOnlyFetch++;
      },
    });

  assert.strictEqual(technicalOnlyFetch,0);
  assert.strictEqual(
    technicalOnly.gateReason,
    'technical_failure_not_terra_route'
  );

  let escalationNotAllowedFetch=0;

  const escalationNotAllowed=
    await mod.runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid:'terra-contract-user',
      clinicalEscalation:true,
      terraAllowed:false,
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async()=>{
        escalationNotAllowedFetch++;
      },
    });

  assert.strictEqual(escalationNotAllowedFetch,0);
  assert.strictEqual(
    escalationNotAllowed.gateReason,
    'terra_not_allowed'
  );

  let allowedFetch=0;
  let captured=null;

  const allowed=
    await mod.runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid:'terra-contract-user',
      clinicalEscalation:true,
      terraAllowed:true,
      escalationReasons:[
        'diagnostic_conflict',
        'low_confidence',
      ],
      upstreamTechnicalFailure:false,
      userMessage:'synthetic',
      history:[],
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async(_url,options)=>{
        allowedFetch++;
        captured=JSON.parse(options.body);

        return new Response(
          JSON.stringify(
            completedResponse()
          ),
          {
            status:200,
            headers:{
              'content-type':'application/json',
            },
          }
        );
      },
    });

  assert.strictEqual(allowedFetch,1);
  assert.strictEqual(allowed.completed,true);
  assert.strictEqual(allowed.failureClass,null);
  assert.strictEqual(allowed.responseValid,true);
  assert.strictEqual(
    captured.reasoning.effort,
    'high'
  );
  assert.strictEqual(
    captured.text.format.strict,
    true
  );
  assert.strictEqual(
    allowed.estimatedCostNanoUsd,
    6538000
  );

  assert.strictEqual(
    mod.classifyGpt56TerraTechnicalOutcome({
      httpStatus:429,
    }),
    'technical_rate_limit'
  );

  assert.strictEqual(
    mod.classifyGpt56TerraTechnicalOutcome({
      httpStatus:503,
    }),
    'technical_provider_5xx'
  );

  assert.strictEqual(
    mod.classifyGpt56TerraTechnicalOutcome({
      exceptionName:'TimeoutError',
    }),
    'technical_timeout'
  );

  const telemetry=
    mod.buildGpt56TerraShadowTelemetry(
      allowed
    );

  assert.strictEqual(
    'parsedClinicalResult' in telemetry,
    false
  );

  assert.strictEqual(
    'clinical_synthesis' in telemetry,
    false
  );

  assert.strictEqual(
    'uid' in telemetry,
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

  console.log('GPT56_TERRA_MODEL_ID=PASS');
  console.log('GPT56_TERRA_PLANTAO_COMPLEX_ALIAS=PASS');
  console.log('GPT56_TERRA_RESPONSES_API_REQUEST_SHAPE=PASS');
  console.log('GPT56_TERRA_REASONING_EFFORT_HIGH=PASS');
  console.log('GPT56_TERRA_STRUCTURED_OUTPUT_SCHEMA=PASS');
  console.log('GPT56_TERRA_SAMPLING_PARAMS_OMITTED=PASS');
  console.log('GPT56_TERRA_SERVER_GATE_FAIL_CLOSED=PASS');
  console.log('GPT56_TERRA_PLANTAO_ONLY=PASS');
  console.log('GPT56_TERRA_CLINICAL_ESCALATION_REQUIRED=PASS');
  console.log('GPT56_TERRA_TERRA_ALLOWED_REQUIRED=PASS');
  console.log('GPT56_TERRA_TECHNICAL_FAILURE_ALONE_ZERO_FETCH=PASS');
  console.log('GPT56_TERRA_CURRENT_PRICING_COST=PASS');
  console.log('GPT56_TERRA_CACHE_WRITE_ACCOUNTING=PASS');
  console.log('GPT56_TERRA_LONG_CONTEXT_PRICING=PASS');
  console.log('GPT56_TERRA_TECHNICAL_FAILURE_TAXONOMY=PASS');
  console.log('GPT56_TERRA_RAW_CLINICAL_TELEMETRY=ABSENT');
  console.log('GPT56_TERRA_RAW_UID_TELEMETRY=ABSENT');
  console.log('GPT56_TERRA_USER_RESPONSE_AUTHORITY=NONE');
  console.log('GPT56_TERRA_LIVE_MODEL_SELECTION_AUTHORITY=NONE');
  console.log('GPT56_TERRA_LIVE_ERROR_PATH_AUTHORITY=NONE');
  console.log('GPT56_TERRA_TECHNICAL_FALLBACK_AUTHORITY=NONE');
  console.log('GPT56_TERRA_COMPLEX_CLINICAL_ESCALATION_ONLY_FOUNDATION=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
