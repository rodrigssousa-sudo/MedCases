'use strict';

const assert=require('assert');

const mod=require(
  '../lib/ai_control_plane_v2/gemini31_flash_lite_paid_cross_provider_shadow_v1'
);

function config({
  rolloutPercent=100,
}={}){
  return {
    featureFlags:{
      gemini31_paid_real_shadow_v1:true,
    },
    shadowProviderCalls:{
      gemini31Paid:{
        enabled:true,
        rolloutPercent,
        cohortSalt:'gemini-paid-contract',
        timeoutMs:12000,
        maxOutputTokens:2048,
      },
    },
  };
}

function completedInteraction(){
  return {
    id:'int_contract',
    model:'gemini-3.1-flash-lite',
    object:'interaction',
    status:'completed',
    steps:[
      {
        type:'model_output',
        content:[
          {
            type:'text',
            text:JSON.stringify({
              clinical_summary:'Synthetic.',
              differential:[],
              critical_actions:[],
              safety_flags:[],
              uncertainties:[],
              confidence:'high',
              needs_more_information:false,
            }),
          },
        ],
      },
    ],
    usage:{
      total_input_tokens:200,
      total_cached_tokens:40,
      total_output_tokens:300,
      total_thought_tokens:50,
      total_tokens:550,
    },
  };
}

(async()=>{
  assert.strictEqual(
    mod.GEMINI_MODEL,
    'gemini-3.1-flash-lite'
  );

  assert.strictEqual(
    mod.GEMINI_ALIAS,
    'plantao_cross_provider'
  );

  assert.strictEqual(
    mod.GEMINI_ENDPOINT,
    'https://generativelanguage.googleapis.com/v1beta/interactions'
  );

  const request=
    mod.buildGemini31PaidRequest({
      providerInput:'synthetic',
      maxOutputTokens:2048,
    });

  assert.strictEqual(request.model,'gemini-3.1-flash-lite');
  assert.strictEqual(request.store,false);
  assert.strictEqual(request.generation_config.max_output_tokens,2048);
  assert.strictEqual(request.response_format.type,'text');
  assert.strictEqual(request.response_format.mime_type,'application/json');
  assert.strictEqual(request.response_format.schema.type,'object');
  assert.strictEqual('tools' in request,false);

  const cost=
    mod.estimateGemini31PaidCost({
      inputTokens:200,
      cachedInputTokens:40,
      outputTokens:300,
      thoughtTokens:50,
    });

  assert.strictEqual(
    cost.estimatedCostNanoUsd,
    566000
  );

  assert.strictEqual(
    cost.estimatedCostUsd,
    0.000566
  );

  let closedFetch=0;

  const closed=
    await mod.runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:'contract-user',
      upstreamTechnicalFailure:true,
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      geminiApiKey:'fake',
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

  let noFailureFetch=0;

  const noFailure=
    await mod.runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:'contract-user',
      upstreamTechnicalFailure:false,
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      geminiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async()=>{
        noFailureFetch++;
      },
    });

  assert.strictEqual(noFailureFetch,0);
  assert.strictEqual(
    noFailure.gateReason,
    'technical_fallback_not_required'
  );

  let escalationFetch=0;

  const escalationOnly=
    await mod.runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:'contract-user',
      upstreamTechnicalFailure:false,
      upstreamClinicalEscalation:true,
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      geminiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async()=>{
        escalationFetch++;
      },
    });

  assert.strictEqual(escalationFetch,0);
  assert.strictEqual(
    escalationOnly.gateReason,
    'clinical_escalation_not_technical_fallback'
  );

  let allowedFetch=0;
  let capturedRequest=null;

  const allowed=
    await mod.runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:'contract-user',
      upstreamTechnicalFailure:true,
      upstreamFailureClass:'technical_timeout',
      upstreamClinicalEscalation:false,
      userMessage:'synthetic',
      history:[],
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      geminiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async(_url,options)=>{
        allowedFetch++;
        capturedRequest=JSON.parse(options.body);

        return new Response(
          JSON.stringify(completedInteraction()),
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
    capturedRequest.response_format.mime_type,
    'application/json'
  );
  assert.strictEqual(
    allowed.estimatedCostNanoUsd,
    566000
  );

  assert.strictEqual(
    mod.classifyGemini31PaidTechnicalOutcome({
      httpStatus:429,
    }),
    'technical_rate_limit'
  );

  assert.strictEqual(
    mod.classifyGemini31PaidTechnicalOutcome({
      httpStatus:503,
    }),
    'technical_provider_5xx'
  );

  assert.strictEqual(
    mod.classifyGemini31PaidTechnicalOutcome({
      exceptionName:'TimeoutError',
    }),
    'technical_timeout'
  );

  const telemetry=
    mod.buildGemini31PaidShadowTelemetry(
      allowed
    );

  assert.strictEqual(
    'parsedClinicalResult' in telemetry,
    false
  );

  assert.strictEqual(
    'clinical_summary' in telemetry,
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
    telemetry.clinicalEscalationAuthority,
    false
  );

  assert.strictEqual(
    telemetry.terraRoutingAuthority,
    false
  );

  assert.strictEqual(
    telemetry.telemetryOnly,
    true
  );

  console.log('GEMINI31_PAID_MODEL_ID=PASS');
  console.log('GEMINI31_PAID_PLANTAO_CROSS_PROVIDER_ALIAS=PASS');
  console.log('GEMINI31_PAID_INTERACTIONS_API_REQUEST_SHAPE=PASS');
  console.log('GEMINI31_PAID_STRUCTURED_OUTPUT_SCHEMA=PASS');
  console.log('GEMINI31_PAID_STORE_FALSE=PASS');
  console.log('GEMINI31_PAID_TOOLS_GROUNDING=ABSENT');
  console.log('GEMINI31_PAID_TECHNICAL_FAILURE_REQUIRED=PASS');
  console.log('GEMINI31_PAID_CLINICAL_ESCALATION_ALONE_ZERO_FETCH=PASS');
  console.log('GEMINI31_PAID_CURRENT_PRICING_COST=PASS');
  console.log('GEMINI31_PAID_THOUGHT_TOKEN_COST_ACCOUNTING=PASS');
  console.log('GEMINI31_PAID_TECHNICAL_FAILURE_TAXONOMY=PASS');
  console.log('GEMINI31_PAID_RAW_CLINICAL_TELEMETRY=ABSENT');
  console.log('GEMINI31_PAID_RAW_UID_TELEMETRY=ABSENT');
  console.log('GEMINI31_PAID_USER_RESPONSE_AUTHORITY=NONE');
  console.log('GEMINI31_PAID_LIVE_MODEL_SELECTION_AUTHORITY=NONE');
  console.log('GEMINI31_PAID_LIVE_ERROR_PATH_AUTHORITY=NONE');
  console.log('GEMINI31_PAID_CLINICAL_ESCALATION_AUTHORITY=NONE');
  console.log('GEMINI31_PAID_TERRA_ROUTING_AUTHORITY=NONE');
  console.log('GEMINI31_PAID_CROSS_PROVIDER_TECHNICAL_FALLBACK_FOUNDATION=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
