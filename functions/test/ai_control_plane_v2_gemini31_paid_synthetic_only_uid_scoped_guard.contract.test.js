'use strict';

const assert=require('assert');
const crypto=require('crypto');

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
        cohortSalt:'gemini-proof-guard',
        timeoutMs:12000,
        maxOutputTokens:2048,
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
      total_input_tokens:50,
      total_cached_tokens:0,
      total_output_tokens:50,
      total_thought_tokens:0,
    },
  };
}

(async()=>{
  const proofUid='gemini-proof-user';
  const proofHash=sha(proofUid);

  let allowedFetch=0;

  const allowed=
    await runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:proofUid,
      mode:'plantao',
      upstreamTechnicalFailure:true,
      upstreamFailureClass:'technical_timeout',
      userMessage:'synthetic',
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      geminiApiKey:'fake',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:proofHash,
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

  let nonSyntheticFetch=0;

  const nonSynthetic=
    await runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:proofUid,
      mode:'plantao',
      upstreamTechnicalFailure:true,
      patientContext:{
        realPatient:true,
      },
      geminiApiKey:'fake',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:proofHash,
      fetchFn:async()=>{
        nonSyntheticFetch++;
      },
    });

  assert.strictEqual(nonSyntheticFetch,0);
  assert.strictEqual(
    nonSynthetic.gateReason,
    'synthetic_only_non_synthetic'
  );

  let wrongUidFetch=0;

  const wrongUid=
    await runGemini31FlashLitePaidCrossProviderShadow({
      config:config(),
      uid:'different-user',
      mode:'plantao',
      upstreamTechnicalFailure:true,
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      geminiApiKey:'fake',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:proofHash,
      fetchFn:async()=>{
        wrongUidFetch++;
      },
    });

  assert.strictEqual(wrongUidFetch,0);
  assert.strictEqual(
    wrongUid.gateReason,
    'synthetic_only_uid_not_allowed'
  );

  console.log('GEMINI31_PAID_SYNTHETIC_ONLY_PROOF_UID_ALLOWED_FETCH=PASS');
  console.log('GEMINI31_PAID_SYNTHETIC_ONLY_NON_SYNTHETIC_ZERO_FETCH=PASS');
  console.log('GEMINI31_PAID_SYNTHETIC_ONLY_WRONG_UID_ZERO_FETCH=PASS');
  console.log('GEMINI31_PAID_SYNTHETIC_ONLY_UID_SCOPED_GUARD=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
