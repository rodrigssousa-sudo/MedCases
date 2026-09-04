'use strict';

const assert=require('assert');

const {
  runGemini31FlashLitePaidCrossProviderShadow,
}=require('../lib/ai_control_plane_v2/gemini31_flash_lite_paid_cross_provider_shadow_v1');

function config(){
  return {
    featureFlags:{
      gemini31_paid_real_shadow_v1:true,
    },
    shadowProviderCalls:{
      gemini31Paid:{
        enabled:true,
        rolloutPercent:100,
        cohortSalt:'gemini-paid-policy-contract',
        timeoutMs:12000,
        maxOutputTokens:2048,
      },
    },
  };
}

function completed(){
  return {
    status:'completed',
    steps:[
      {
        type:'model_output',
        content:[
          {
            type:'text',
            text:JSON.stringify({
              clinical_summary:'Protected projection only.',
              differential:[],
              critical_actions:[],
              safety_flags:[],
              uncertainties:[],
              confidence:'medium',
              needs_more_information:false,
            }),
          },
        ],
      },
    ],
    usage:{
      total_input_tokens:100,
      total_cached_tokens:0,
      total_output_tokens:100,
      total_thought_tokens:0,
    },
  };
}

(async()=>{
  let missingPolicyFetch=0;

  const missingPolicy=
    await runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:'policy-user',
      upstreamTechnicalFailure:true,
      userMessage:'RAW_USER_SENTINEL',
      history:['RAW_HISTORY_SENTINEL'],
      patientContext:{
        realPatient:true,
        patientName:'RAW_PATIENT_SENTINEL',
      },
      providerDataPolicy:null,
      protectedClinicalProjection:null,
      geminiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async()=>{
        missingPolicyFetch++;
      },
    });

  assert.strictEqual(missingPolicyFetch,0);
  assert.strictEqual(
    missingPolicy.gateReason,
    'protected_clinical_policy_missing'
  );

  let invalidProjectionFetch=0;

  const invalidProjection=
    await runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:'policy-user',
      upstreamTechnicalFailure:true,
      patientContext:{
        realPatient:true,
      },
      providerDataPolicy:{
        ready:true,
      },
      protectedClinicalProjection:{
        containsRawText:true,
      },
      geminiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async()=>{
        invalidProjectionFetch++;
      },
    });

  assert.strictEqual(invalidProjectionFetch,0);
  assert.strictEqual(
    invalidProjection.gateReason,
    'protected_clinical_projection_invalid'
  );

  let providerBody='';

  const allowed=
    await runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:'policy-user',
      upstreamTechnicalFailure:true,
      userMessage:'RAW_USER_SENTINEL',
      history:['RAW_HISTORY_SENTINEL'],
      patientContext:{
        realPatient:true,
        patientName:'RAW_PATIENT_SENTINEL',
      },
      providerDataPolicy:{
        ready:true,
      },
      protectedClinicalProjection:{
        version:'protected_clinical_projection_v1',
        source:'server_deidentified_v1',
        containsRawText:false,
        containsDirectIdentifiers:false,
        clinicalIntentTags:[
          'chest_pain',
        ],
        complexitySignals:[
          'hemodynamic_risk',
        ],
        contextMetrics:{
          userMessageChars:500,
          historyTurns:4,
          patientContextFieldCount:3,
        },
      },
      geminiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async(_url,options)=>{
        providerBody=options.body;

        return new Response(
          JSON.stringify(completed()),
          {
            status:200,
            headers:{
              'content-type':'application/json',
            },
          }
        );
      },
    });

  assert.strictEqual(allowed.completed,true);

  assert.strictEqual(
    providerBody.includes('RAW_USER_SENTINEL'),
    false
  );

  assert.strictEqual(
    providerBody.includes('RAW_HISTORY_SENTINEL'),
    false
  );

  assert.strictEqual(
    providerBody.includes('RAW_PATIENT_SENTINEL'),
    false
  );

  assert.strictEqual(
    providerBody.includes('patientName'),
    false
  );

  assert.strictEqual(
    providerBody.includes('chest_pain'),
    true
  );

  console.log('GEMINI31_PAID_NON_SYNTHETIC_POLICY_MISSING_ZERO_FETCH=PASS');
  console.log('GEMINI31_PAID_INVALID_PROTECTED_PROJECTION_ZERO_FETCH=PASS');
  console.log('GEMINI31_PAID_VALID_PROTECTED_PROJECTION_FETCH_ALLOWED=PASS');
  console.log('GEMINI31_PAID_RAW_USER_MESSAGE_PROVIDER_LEAK=NO');
  console.log('GEMINI31_PAID_RAW_HISTORY_PROVIDER_LEAK=NO');
  console.log('GEMINI31_PAID_RAW_PATIENT_CONTEXT_PROVIDER_LEAK=NO');
  console.log('GEMINI31_PAID_PROTECTED_CLINICAL_DEFAULT_DENY=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
