'use strict';

const assert=require('assert');

const {
  runGpt5NanoPlantaoRouterRealShadow,
}=require('../lib/ai_control_plane_v2/gpt5_nano_plantao_router_real_shadow_v1');

const {
  buildOpenAiProtectedClinicalDataPolicyFromEnv,
}=require('../lib/ai_control_plane_v2/protected_clinical_data_policy_v1');

function config(){
  return {
    enabled:true,
    legacyParityMode:false,
    rollout:{enabled:true,percent:100},
    featureFlags:{
      legacy_parity_execution_v2:true,
      gpt5_nano_real_shadow_v1:true,
    },
    shadowProviderCalls:{
      gpt5Nano:{
        enabled:true,
        rolloutPercent:100,
        cohortSalt:'protected-policy-contract',
        timeoutMs:5000,
        maxOutputTokens:1024,
      },
    },
  };
}

function fakeResponse(){
  return new Response(JSON.stringify({
    id:'resp_policy_contract',
    object:'response',
    status:'incomplete',
    incomplete_details:{reason:'max_output_tokens'},
    model:'gpt-5-nano',
    output:[],
    usage:{
      input_tokens:1,
      output_tokens:1,
      output_tokens_details:{reasoning_tokens:1},
    },
  }),{
    status:200,
    headers:{'content-type':'application/json'},
  });
}

(async()=>{
  const oldSynthetic=
    process.env.AI_GPT5_NANO_REAL_SHADOW_SYNTHETIC_ONLY;

  delete process.env.AI_GPT5_NANO_REAL_SHADOW_SYNTHETIC_ONLY;

  try{
    let fetchCount=0;

    const denied=
      await runGpt5NanoPlantaoRouterRealShadow({
        config:config(),
        uid:'policy-contract-user',
        mode:'plantao',
        userMessage:'RAW_MESSAGE_SENTINEL_MUST_NOT_LEAK',
        history:[
          {
            role:'user',
            content:'RAW_HISTORY_SENTINEL_MUST_NOT_LEAK',
          },
        ],
        patientContext:{
          realPatient:true,
          patientName:'RAW_PATIENT_SENTINEL_MUST_NOT_LEAK',
        },
        providerDataPolicy:null,
        protectedClinicalProjection:null,
        openAiApiKey:'synthetic-key',
        serverEnabled:true,
        fetchFn:async()=>{
          fetchCount++;
          return fakeResponse();
        },
      });

    assert.strictEqual(fetchCount,0);
    assert.strictEqual(denied.attempted,false);
    assert.strictEqual(
      denied.gateReason,
      'protected_clinical_policy_missing'
    );

    const policy=
      buildOpenAiProtectedClinicalDataPolicyFromEnv({
        AI_OPENAI_PROTECTED_CLINICAL_PROCESSING_ATTESTED:'true',
        AI_GPT5_NANO_REAL_PATIENT_SHADOW_ALLOWED:'true',
      });

    const projection={
      version:'protected_clinical_projection_v1',
      source:'server_deidentified_v1',
      containsRawText:false,
      containsDirectIdentifiers:false,
      clinicalIntentTags:[
        'acute_care',
        'cardiology',
      ],
      complexitySignals:[
        'multi_step_reasoning',
      ],
      contextMetrics:{
        userMessageChars:777,
        historyTurns:3,
        patientContextFieldCount:6,
      },
    };

    let capturedBody='';

    const allowed=
      await runGpt5NanoPlantaoRouterRealShadow({
        config:config(),
        uid:'policy-contract-user',
        mode:'plantao',
        userMessage:'RAW_MESSAGE_SENTINEL_MUST_NOT_LEAK',
        history:[
          {
            role:'user',
            content:'RAW_HISTORY_SENTINEL_MUST_NOT_LEAK',
          },
        ],
        patientContext:{
          realPatient:true,
          patientName:'RAW_PATIENT_SENTINEL_MUST_NOT_LEAK',
        },
        providerDataPolicy:policy,
        protectedClinicalProjection:projection,
        openAiApiKey:'synthetic-key',
        serverEnabled:true,
        fetchFn:async(_url,options)=>{
          fetchCount++;
          capturedBody=String(options.body||'');
          return fakeResponse();
        },
      });

    assert.strictEqual(fetchCount,1);
    assert.strictEqual(allowed.attempted,true);
    assert.strictEqual(allowed.userResponseAuthority,false);
    assert.strictEqual(allowed.liveAuthorityChanged,false);
    assert.strictEqual(allowed.telemetryOnly,true);

    assert.ok(capturedBody.includes('acute_care'));
    assert.ok(capturedBody.includes('multi_step_reasoning'));

    assert.ok(!capturedBody.includes('RAW_MESSAGE_SENTINEL'));
    assert.ok(!capturedBody.includes('RAW_HISTORY_SENTINEL'));
    assert.ok(!capturedBody.includes('RAW_PATIENT_SENTINEL'));

    console.log('NON_SYNTHETIC_POLICY_MISSING_ZERO_FETCH=PASS');
    console.log('NON_SYNTHETIC_VALID_POLICY_AND_PROJECTION_FETCH_ALLOWED=PASS');
    console.log('RAW_USER_MESSAGE_PROVIDER_LEAK=NO');
    console.log('RAW_HISTORY_PROVIDER_LEAK=NO');
    console.log('RAW_PATIENT_CONTEXT_PROVIDER_LEAK=NO');
    console.log('GPT5_NANO_PROTECTED_CLINICAL_DEFAULT_DENY=PASS');
  } finally {
    if(oldSynthetic===undefined){
      delete process.env.AI_GPT5_NANO_REAL_SHADOW_SYNTHETIC_ONLY;
    }else{
      process.env.AI_GPT5_NANO_REAL_SHADOW_SYNTHETIC_ONLY=
        oldSynthetic;
    }
  }
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
