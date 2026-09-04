'use strict';

const assert=require('assert');

const {
  runGpt56LunaPlantaoPrimaryShadow,
}=require('../lib/ai_control_plane_v2/gpt56_luna_plantao_primary_shadow_v1');

const {
  buildOpenAiProtectedClinicalDataPolicyFromEnv,
}=require('../lib/ai_control_plane_v2/protected_clinical_data_policy_v1');

function config(){
  return {
    enabled:true,
    featureFlags:{
      gpt56_luna_real_shadow_v1:true,
    },
    shadowProviderCalls:{
      gpt56Luna:{
        enabled:true,
        rolloutPercent:100,
        cohortSalt:'luna-policy-contract',
        timeoutMs:12000,
        maxOutputTokens:2048,
        reasoningEffort:'low',
      },
    },
  };
}

function incompleteResponse(){
  return new Response(JSON.stringify({
    id:'resp_luna_policy',
    object:'response',
    status:'incomplete',
    incomplete_details:{
      reason:'max_output_tokens',
    },
    model:'gpt-5.6-luna',
    output:[],
    usage:{
      input_tokens:1,
      output_tokens:1,
      output_tokens_details:{
        reasoning_tokens:1,
      },
    },
  }),{
    status:200,
    headers:{
      'content-type':'application/json',
    },
  });
}

(async()=>{
  let fetchCount=0;

  const denied=
    await runGpt56LunaPlantaoPrimaryShadow({
      config:config(),
      uid:'luna-policy-user',
      mode:'plantao',
      userMessage:'RAW_LUNA_MESSAGE_MUST_NOT_LEAK',
      history:[
        {
          role:'user',
          content:'RAW_LUNA_HISTORY_MUST_NOT_LEAK',
        },
      ],
      patientContext:{
        realPatient:true,
        patientName:'RAW_LUNA_PATIENT_MUST_NOT_LEAK',
      },
      providerDataPolicy:null,
      protectedClinicalProjection:null,
      openAiApiKey:'synthetic-key',
      serverEnabled:true,
      fetchFn:async()=>{
        fetchCount++;
        return incompleteResponse();
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
      userMessageChars:440,
      historyTurns:5,
      patientContextFieldCount:9,
    },
  };

  let capturedBody='';

  const allowed=
    await runGpt56LunaPlantaoPrimaryShadow({
      config:config(),
      uid:'luna-policy-user',
      mode:'plantao',
      userMessage:'RAW_LUNA_MESSAGE_MUST_NOT_LEAK',
      history:[
        {
          role:'user',
          content:'RAW_LUNA_HISTORY_MUST_NOT_LEAK',
        },
      ],
      patientContext:{
        realPatient:true,
        patientName:'RAW_LUNA_PATIENT_MUST_NOT_LEAK',
      },
      providerDataPolicy:policy,
      protectedClinicalProjection:projection,
      openAiApiKey:'synthetic-key',
      serverEnabled:true,
      fetchFn:async(_url,options)=>{
        fetchCount++;
        capturedBody=String(options.body||'');
        return incompleteResponse();
      },
    });

  assert.strictEqual(fetchCount,1);
  assert.strictEqual(allowed.attempted,true);

  assert.ok(capturedBody.includes('acute_care'));
  assert.ok(capturedBody.includes('multi_step_reasoning'));

  assert.ok(!capturedBody.includes('RAW_LUNA_MESSAGE'));
  assert.ok(!capturedBody.includes('RAW_LUNA_HISTORY'));
  assert.ok(!capturedBody.includes('RAW_LUNA_PATIENT'));

  assert.strictEqual(allowed.userResponseAuthority,false);
  assert.strictEqual(
    allowed.liveModelSelectionAuthority,
    false
  );
  assert.strictEqual(
    allowed.liveErrorPathAuthority,
    false
  );
  assert.strictEqual(allowed.telemetryOnly,true);

  console.log('GPT56_LUNA_NON_SYNTHETIC_POLICY_MISSING_ZERO_FETCH=PASS');
  console.log('GPT56_LUNA_VALID_PROTECTED_PROJECTION_FETCH_ALLOWED=PASS');
  console.log('GPT56_LUNA_RAW_USER_MESSAGE_PROVIDER_LEAK=NO');
  console.log('GPT56_LUNA_RAW_HISTORY_PROVIDER_LEAK=NO');
  console.log('GPT56_LUNA_RAW_PATIENT_CONTEXT_PROVIDER_LEAK=NO');
  console.log('GPT56_LUNA_PROTECTED_CLINICAL_POLICY_REUSE=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
