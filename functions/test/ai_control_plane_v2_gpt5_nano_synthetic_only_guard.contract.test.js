'use strict';

const assert=require('assert');

const {
  runGpt5NanoPlantaoRouterRealShadow,
}=require('../lib/ai_control_plane_v2/gpt5_nano_plantao_router_real_shadow_v1');

const ENV='AI_GPT5_NANO_REAL_SHADOW_SYNTHETIC_ONLY';

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
        cohortSalt:'synthetic-only-contract',
        timeoutMs:5000,
        maxOutputTokens:1024,
      },
    },
  };
}

(async()=>{
  const previous=process.env[ENV];

  try{
    process.env[ENV]='true';

    let blockedFetchCount=0;

    const blocked=
      await runGpt5NanoPlantaoRouterRealShadow({
        config:config(),
        uid:'synthetic-contract-user',
        mode:'plantao',
        userMessage:'synthetic-control',
        history:[],
        patientContext:null,
        openAiApiKey:'synthetic-key',
        serverEnabled:true,
        fetchFn:async()=>{
          blockedFetchCount++;
          throw new Error('FETCH_MUST_NOT_RUN_FOR_NON_SYNTHETIC');
        },
      });

    assert.strictEqual(blockedFetchCount,0);
    assert.strictEqual(blocked.attempted,false);
    assert.strictEqual(blocked.completed,false);
    assert.strictEqual(blocked.gateReason,'synthetic_only_guard');
    assert.strictEqual(blocked.userResponseAuthority,false);
    assert.strictEqual(blocked.liveAuthorityChanged,false);
    assert.strictEqual(blocked.telemetryOnly,true);

    let syntheticFetchCount=0;

    const synthetic=
      await runGpt5NanoPlantaoRouterRealShadow({
        config:config(),
        uid:'synthetic-contract-user',
        mode:'plantao',
        userMessage:'synthetic',
        history:[],
        patientContext:{
          synthetic:true,
          realPatient:false,
        },
        openAiApiKey:'synthetic-key',
        serverEnabled:true,
        fetchFn:async()=>{
          syntheticFetchCount++;

          return new Response(JSON.stringify({
            id:'resp_synthetic_guard_contract',
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
        },
      });

    assert.strictEqual(syntheticFetchCount,1);
    assert.strictEqual(synthetic.attempted,true);
    assert.strictEqual(synthetic.userResponseAuthority,false);
    assert.strictEqual(synthetic.liveAuthorityChanged,false);
    assert.strictEqual(synthetic.telemetryOnly,true);

    console.log('SYNTHETIC_ONLY_NON_SYNTHETIC_ZERO_FETCH=PASS');
    console.log('SYNTHETIC_ONLY_SYNTHETIC_FETCH_ALLOWED=PASS');
    console.log('SYNTHETIC_ONLY_USER_RESPONSE_AUTHORITY=NONE');
    console.log('GPT5_NANO_SYNTHETIC_ONLY_GUARD_CONTRACT=PASS');
  } finally {
    if(previous===undefined){
      delete process.env[ENV];
    }else{
      process.env[ENV]=previous;
    }
  }
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
