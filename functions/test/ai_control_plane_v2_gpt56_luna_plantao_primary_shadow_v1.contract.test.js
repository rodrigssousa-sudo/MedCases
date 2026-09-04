'use strict';

const assert=require('assert');

const {
  LUNA_MODEL,
  LUNA_ALIAS,
  LUNA_ENDPOINT,
  deterministicLunaShadowBucket,
  evaluateGpt56LunaShadowGate,
  buildGpt56LunaRequest,
  runGpt56LunaPlantaoPrimaryShadow,
  buildGpt56LunaShadowTelemetry,
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
        cohortSalt:'luna-foundation-contract',
        timeoutMs:12000,
        maxOutputTokens:2048,
        reasoningEffort:'low',
      },
    },
  };
}

(async()=>{
  assert.strictEqual(LUNA_MODEL,'gpt-5.6-luna');
  assert.strictEqual(LUNA_ALIAS,'plantao_primary');
  assert.strictEqual(
    LUNA_ENDPOINT,
    'https://api.openai.com/v1/responses'
  );

  const bucket=
    deterministicLunaShadowBucket(
      'uid-foundation',
      'luna-foundation-contract'
    );

  assert.ok(Number.isInteger(bucket));
  assert.ok(bucket>=0 && bucket<10000);

  assert.strictEqual(
    evaluateGpt56LunaShadowGate({
      config:config(),
      uid:'uid-foundation',
      mode:'plantao',
      serverEnabled:false,
    }).reason,
    'server_hard_gate_closed'
  );

  assert.strictEqual(
    evaluateGpt56LunaShadowGate({
      config:config(),
      uid:'uid-foundation',
      mode:'study',
      serverEnabled:true,
    }).reason,
    'plantao_only'
  );

  const request=
    buildGpt56LunaRequest({
      inputText:'synthetic foundation',
      maxOutputTokens:2048,
      reasoningEffort:'low',
    });

  assert.strictEqual(request.model,'gpt-5.6-luna');
  assert.strictEqual(request.store,false);
  assert.strictEqual(request.max_output_tokens,2048);
  assert.strictEqual(request.reasoning.effort,'low');

  assert.ok(request.text);
  assert.ok(request.text.format);
  assert.strictEqual(
    request.text.format.type,
    'json_schema'
  );
  assert.strictEqual(
    request.text.format.strict,
    true
  );

  assert.strictEqual('temperature' in request,false);
  assert.strictEqual('top_p' in request,false);

  let closedFetchCount=0;

  const closed=
    await runGpt56LunaPlantaoPrimaryShadow({
      config:config(),
      uid:'uid-foundation',
      mode:'plantao',
      userMessage:'synthetic',
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'synthetic-key',
      serverEnabled:false,
      fetchFn:async()=>{
        closedFetchCount++;
        throw new Error('FETCH_MUST_NOT_RUN');
      },
    });

  assert.strictEqual(closedFetchCount,0);
  assert.strictEqual(closed.attempted,false);
  assert.strictEqual(closed.userResponseAuthority,false);
  assert.strictEqual(
    closed.liveModelSelectionAuthority,
    false
  );
  assert.strictEqual(
    closed.liveErrorPathAuthority,
    false
  );
  assert.strictEqual(closed.telemetryOnly,true);

  let fetchCount=0;
  let captured=null;

  const completed=
    await runGpt56LunaPlantaoPrimaryShadow({
      config:config(),
      uid:'uid-foundation',
      mode:'plantao',
      userMessage:'synthetic',
      history:[],
      patientContext:{
        synthetic:true,
        realPatient:false,
      },
      openAiApiKey:'synthetic-key',
      serverEnabled:true,
      fetchFn:async(url,options)=>{
        fetchCount++;
        captured={
          url,
          body:JSON.parse(options.body),
        };

        return new Response(JSON.stringify({
          id:'resp_luna_foundation',
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
                    clinical_summary:'Synthetic assessment.',
                    differential:[
                      {
                        diagnosis:'synthetic_diagnosis',
                        rationale:'synthetic rationale',
                        urgency:'low',
                      },
                    ],
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
            input_tokens:30,
            output_tokens:50,
            output_tokens_details:{
              reasoning_tokens:10,
            },
          },
        }),{
          status:200,
          headers:{
            'content-type':'application/json',
          },
        });
      },
    });

  assert.strictEqual(fetchCount,1);
  assert.strictEqual(
    captured.url,
    'https://api.openai.com/v1/responses'
  );
  assert.strictEqual(
    captured.body.model,
    'gpt-5.6-luna'
  );
  assert.strictEqual(captured.body.store,false);
  assert.strictEqual(completed.attempted,true);
  assert.strictEqual(completed.completed,true);
  assert.strictEqual(completed.userResponseAuthority,false);
  assert.strictEqual(
    completed.liveModelSelectionAuthority,
    false
  );
  assert.strictEqual(
    completed.liveErrorPathAuthority,
    false
  );
  assert.strictEqual(completed.telemetryOnly,true);
  assert.ok(completed.parsedClinicalResult);

  const telemetry=
    buildGpt56LunaShadowTelemetry(completed);

  assert.strictEqual(telemetry.completed,true);
  assert.strictEqual(
    'parsedClinicalResult' in telemetry,
    false
  );
  assert.strictEqual(
    'clinical_summary' in telemetry,
    false
  );

  console.log('GPT56_LUNA_MODEL_ID=PASS');
  console.log('GPT56_LUNA_PLANTAO_PRIMARY_ALIAS=PASS');
  console.log('GPT56_LUNA_RESPONSES_API_REQUEST_SHAPE=PASS');
  console.log('GPT56_LUNA_REASONING_EFFORT_LOW=PASS');
  console.log('GPT56_LUNA_STRUCTURED_OUTPUT_SCHEMA=PASS');
  console.log('GPT56_LUNA_SAMPLING_PARAMS_OMITTED=PASS');
  console.log('GPT56_LUNA_SERVER_GATE_FAIL_CLOSED=PASS');
  console.log('GPT56_LUNA_PLANTAO_ONLY=PASS');
  console.log('GPT56_LUNA_SHADOW_USER_RESPONSE_AUTHORITY=NONE');
  console.log('GPT56_LUNA_SHADOW_LIVE_MODEL_SELECTION_AUTHORITY=NONE');
  console.log('GPT56_LUNA_SHADOW_LIVE_ERROR_PATH_AUTHORITY=NONE');
  console.log('GPT56_LUNA_RAW_CLINICAL_TELEMETRY=ABSENT');
  console.log('GPT56_LUNA_PLANTAO_PRIMARY_SHADOW_FOUNDATION=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
