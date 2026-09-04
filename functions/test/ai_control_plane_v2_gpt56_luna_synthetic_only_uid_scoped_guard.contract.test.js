'use strict';

const assert=require('assert');
const crypto=require('crypto');

const {
  runGpt56LunaPlantaoPrimaryShadow,
}=require('../lib/ai_control_plane_v2/gpt56_luna_plantao_primary_shadow_v1');

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
        cohortSalt:'luna-synthetic-uid-guard-contract',
        timeoutMs:20000,
        maxOutputTokens:4096,
        reasoningEffort:'low',
      },
    },
  };
}

function sha256(v){
  return crypto
    .createHash('sha256')
    .update(v,'utf8')
    .digest('hex');
}

function completedResponse(){
  return new Response(JSON.stringify({
    id:'resp_luna_guard_contract',
    object:'response',
    status:'completed',
    model:'gpt-5.6-luna',
    output:[
      {
        type:'message',
        content:[
          {
            type:'output_text',
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
      input_tokens:10,
      output_tokens:20,
      output_tokens_details:{
        reasoning_tokens:5,
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
  const proofUid='proof-user';
  const proofHash=sha256(proofUid);

  let allowedFetch=0;

  const allowed=
    await runGpt56LunaPlantaoPrimaryShadow({
      config:config(),
      uid:proofUid,
      mode:'plantao',
      userMessage:'synthetic-only',
      history:[],
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'synthetic-key',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:proofHash,
      fetchFn:async()=>{
        allowedFetch++;
        return completedResponse();
      },
    });

  assert.strictEqual(allowedFetch,1);
  assert.strictEqual(allowed.attempted,true);
  assert.strictEqual(allowed.completed,true);

  let nonSyntheticFetch=0;

  const nonSynthetic=
    await runGpt56LunaPlantaoPrimaryShadow({
      config:config(),
      uid:proofUid,
      mode:'plantao',
      userMessage:'fake potential patient',
      patientContext:{
        realPatient:true,
      },
      openAiApiKey:'synthetic-key',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:proofHash,
      fetchFn:async()=>{
        nonSyntheticFetch++;
        return completedResponse();
      },
    });

  assert.strictEqual(nonSyntheticFetch,0);
  assert.strictEqual(nonSynthetic.attempted,false);
  assert.strictEqual(
    nonSynthetic.gateReason,
    'synthetic_only_non_synthetic'
  );

  let wrongUidFetch=0;

  const wrongUid=
    await runGpt56LunaPlantaoPrimaryShadow({
      config:config(),
      uid:'different-user',
      mode:'plantao',
      userMessage:'synthetic explicit',
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'synthetic-key',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:proofHash,
      fetchFn:async()=>{
        wrongUidFetch++;
        return completedResponse();
      },
    });

  assert.strictEqual(wrongUidFetch,0);
  assert.strictEqual(wrongUid.attempted,false);
  assert.strictEqual(
    wrongUid.gateReason,
    'synthetic_only_uid_not_allowed'
  );

  let missingHashFetch=0;

  const missingHash=
    await runGpt56LunaPlantaoPrimaryShadow({
      config:config(),
      uid:proofUid,
      mode:'plantao',
      userMessage:'synthetic explicit',
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'synthetic-key',
      serverEnabled:true,
      syntheticOnlyEnabled:true,
      proofUidSha256:'',
      fetchFn:async()=>{
        missingHashFetch++;
        return completedResponse();
      },
    });

  assert.strictEqual(missingHashFetch,0);
  assert.strictEqual(
    missingHash.gateReason,
    'synthetic_only_uid_not_allowed'
  );

  for(const result of [
    allowed,
    nonSynthetic,
    wrongUid,
    missingHash,
  ]){
    assert.strictEqual(
      result.userResponseAuthority,
      false
    );
    assert.strictEqual(
      result.liveModelSelectionAuthority,
      false
    );
    assert.strictEqual(
      result.liveErrorPathAuthority,
      false
    );
    assert.strictEqual(
      result.liveAuthorityChanged,
      false
    );
    assert.strictEqual(
      result.telemetryOnly,
      true
    );
  }

  console.log('LUNA_SYNTHETIC_ONLY_PROOF_UID_ALLOWED_FETCH=PASS');
  console.log('LUNA_SYNTHETIC_ONLY_NON_SYNTHETIC_ZERO_FETCH=PASS');
  console.log('LUNA_SYNTHETIC_ONLY_WRONG_UID_ZERO_FETCH=PASS');
  console.log('LUNA_SYNTHETIC_ONLY_MISSING_UID_HASH_ZERO_FETCH=PASS');
  console.log('LUNA_SYNTHETIC_ONLY_RAW_UID_TELEMETRY=ABSENT');
  console.log('LUNA_SYNTHETIC_ONLY_UID_SCOPED_GUARD_CONTRACT=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
