'use strict';

const assert=require('assert');
const crypto=require('crypto');

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
        cohortSalt:'terra-synthetic-guard-contract',
        timeoutMs:45000,
        maxOutputTokens:8192,
        reasoningEffort:'high',
      },
    },
  };
}

function sha(v){
  return crypto
    .createHash('sha256')
    .update(v,'utf8')
    .digest('hex');
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
              clinical_synthesis:'Synthetic.',
              diagnostic_conflicts:[],
              differential:[],
              critical_actions:[],
              disposition:[],
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
      input_tokens:100,
      input_tokens_details:{
        cached_tokens:0,
        cache_write_tokens:0,
      },
      output_tokens:100,
      output_tokens_details:{
        reasoning_tokens:10,
      },
    },
  };
}

(async()=>{
  const uid='terra-synthetic-guard-user';
  const uidHash=sha(uid);

  let allowedFetch=0;

  const allowed=
    await runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid,
      mode:'plantao',
      clinicalEscalation:true,
      terraAllowed:true,
      escalationReasons:[
        'longitudinal_complexity',
      ],
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'fake',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:uidHash,
      fetchFn:async()=>{
        allowedFetch++;

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

  assert.strictEqual(allowedFetch,1);
  assert.strictEqual(allowed.completed,true);

  let realFetch=0;

  const real=
    await runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid,
      mode:'plantao',
      clinicalEscalation:true,
      terraAllowed:true,
      patientContext:{
        realPatient:true,
      },
      openAiApiKey:'fake',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:uidHash,
      fetchFn:async()=>{
        realFetch++;
      },
    });

  assert.strictEqual(realFetch,0);
  assert.strictEqual(
    real.gateReason,
    'synthetic_only_non_synthetic'
  );

  let wrongUidFetch=0;

  const wrongUid=
    await runGpt56TerraPlantaoComplexEscalationShadow({
      config:config(),
      uid:'different-user',
      mode:'plantao',
      clinicalEscalation:true,
      terraAllowed:true,
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'fake',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:uidHash,
      fetchFn:async()=>{
        wrongUidFetch++;
      },
    });

  assert.strictEqual(wrongUidFetch,0);
  assert.strictEqual(
    wrongUid.gateReason,
    'synthetic_only_uid_not_allowed'
  );

  console.log('TERRA_SYNTHETIC_ONLY_PROOF_UID_ALLOWED_FETCH=PASS');
  console.log('TERRA_SYNTHETIC_ONLY_NON_SYNTHETIC_ZERO_FETCH=PASS');
  console.log('TERRA_SYNTHETIC_ONLY_WRONG_UID_ZERO_FETCH=PASS');
  console.log('TERRA_SYNTHETIC_ONLY_UID_SCOPED_GUARD=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
