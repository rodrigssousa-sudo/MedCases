'use strict';

const assert=require('assert');

const {
  runGpt5NanoPlantaoRouterRealShadow,
}=require('../lib/ai_control_plane_v2/gpt5_nano_plantao_router_real_shadow_v1');

function buildConfig(maxOutputTokens){
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
        cohortSalt:'max-output-clamp-1024-contract',
        timeoutMs:5000,
        maxOutputTokens,
      },
    },
  };
}

async function captureEffective(requested){
  let requestBody=null;

  const fakeFetch=async(_url,options={})=>{
    requestBody=JSON.parse(options.body);

    // The purpose of this contract is request construction, not response parsing.
    // Return a harmless incomplete response; executor is intentionally shadow-safe.
    return new Response(JSON.stringify({
      id:'resp_fake_clamp_contract',
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
  };

  const result=await runGpt5NanoPlantaoRouterRealShadow({
    config:buildConfig(requested),
    uid:'synthetic-contract-user',
    mode:'plantao',
    userMessage:'synthetic',
    history:[],
    patientContext:{synthetic:true, realPatient:false},
    openAiApiKey:'synthetic-key',
    serverEnabled:true,
    fetchFn:fakeFetch,
  });

  assert.ok(requestBody,'request body must be captured');
  assert.strictEqual(requestBody.model,'gpt-5-nano');
  assert.strictEqual(requestBody.store,false);
  assert.strictEqual(
    Object.prototype.hasOwnProperty.call(requestBody,'temperature'),
    false
  );
  assert.strictEqual(
    Object.prototype.hasOwnProperty.call(requestBody,'top_p'),
    false
  );
  assert.strictEqual(result.attempted,true);
  assert.strictEqual(result.userResponseAuthority,false);
  assert.strictEqual(result.liveAuthorityChanged,false);
  assert.strictEqual(result.telemetryOnly,true);

  return requestBody.max_output_tokens;
}

(async()=>{
  const pairs=[
    [64,64],
    [128,128],
    [256,256],
    [512,512],
    [1024,1024],
    [2048,1024],
  ];

  for(const [requested,expected] of pairs){
    const effective=await captureEffective(requested);
    assert.strictEqual(
      effective,
      expected,
      `requested ${requested} must become ${expected}, got ${effective}`
    );
    console.log(`REQUESTED_${requested}=EFFECTIVE_${effective}`);
  }

  console.log('GPT5_NANO_MAX_OUTPUT_CLAMP_1024_CONTRACT=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
