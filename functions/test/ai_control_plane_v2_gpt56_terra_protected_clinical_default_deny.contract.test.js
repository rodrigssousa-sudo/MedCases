'use strict';

const assert=require('assert');

const {
  runGpt56TerraPlantaoComplexEscalationShadow,
}=require('../lib/ai_control_plane_v2/gpt56_terra_plantao_complex_escalation_shadow_v1');

function config(){
  return {
    featureFlags:{
      gpt56_terra_real_shadow_v1:true,
    },
    shadowProviderCalls:{
      gpt56Terra:{
        enabled:true,
        rolloutPercent:100,
        cohortSalt:'terra-policy-contract',
        timeoutMs:30000,
        maxOutputTokens:8192,
        reasoningEffort:'high',
      },
    },
  };
}

function completed(){
  return {
    status:'completed',
    output:[
      {
        type:'message',
        content:[
          {
            type:'output_text',
            text:JSON.stringify({
              clinical_synthesis:'Projection only.',
              diagnostic_conflicts:[],
              differential:[],
              critical_actions:[],
              disposition:[],
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
      input_tokens:100,
      input_tokens_details:{
        cached_tokens:0,
        cache_write_tokens:0,
      },
      output_tokens:100,
      output_tokens_details:{
        reasoning_tokens:20,
      },
    },
  };
}

(async()=>{
  let missingPolicyFetch=0;

  const missingPolicy=
    await runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid:'terra-policy-user',
      clinicalEscalation:true,
      terraAllowed:true,
      escalationReasons:[
        'diagnostic_conflict',
      ],
      userMessage:'RAW_USER_SENTINEL',
      history:['RAW_HISTORY_SENTINEL'],
      patientContext:{
        realPatient:true,
        patientName:'RAW_PATIENT_SENTINEL',
      },
      providerDataPolicy:null,
      protectedClinicalProjection:null,
      openAiApiKey:'fake',
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
    await runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid:'terra-policy-user',
      clinicalEscalation:true,
      terraAllowed:true,
      patientContext:{
        realPatient:true,
      },
      providerDataPolicy:{
        ready:true,
      },
      protectedClinicalProjection:{
        containsRawText:true,
      },
      openAiApiKey:'fake',
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
    await runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid:'terra-policy-user',
      clinicalEscalation:true,
      terraAllowed:true,
      escalationReasons:[
        'diagnostic_conflict',
      ],
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
          'diagnostic_conflict',
        ],
        contextMetrics:{
          userMessageChars:500,
          historyTurns:4,
          patientContextFieldCount:3,
        },
      },
      openAiApiKey:'fake',
      serverEnabled:true,
      fetchFn:async(_url,options)=>{
        providerBody=options.body;

        return new Response(
          JSON.stringify(
            completed()
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

  assert.strictEqual(
    providerBody.includes('diagnostic_conflict'),
    true
  );

  console.log('GPT56_TERRA_NON_SYNTHETIC_POLICY_MISSING_ZERO_FETCH=PASS');
  console.log('GPT56_TERRA_INVALID_PROTECTED_PROJECTION_ZERO_FETCH=PASS');
  console.log('GPT56_TERRA_VALID_PROTECTED_PROJECTION_FETCH_ALLOWED=PASS');
  console.log('GPT56_TERRA_RAW_USER_MESSAGE_PROVIDER_LEAK=NO');
  console.log('GPT56_TERRA_RAW_HISTORY_PROVIDER_LEAK=NO');
  console.log('GPT56_TERRA_RAW_PATIENT_CONTEXT_PROVIDER_LEAK=NO');
  console.log('GPT56_TERRA_PROTECTED_CLINICAL_DEFAULT_DENY=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
