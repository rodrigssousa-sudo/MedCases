'use strict';

const assert=require('assert');

const {
  LUNA_VALIDATOR_VERSION,
  LUNA_PRICING_VERSION,
  estimateGpt56LunaCost,
  classifyGpt56LunaTechnicalOutcome,
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
        cohortSalt:'telemetry-contract',
        timeoutMs:20000,
        maxOutputTokens:4096,
        reasoningEffort:'low',
      },
    },
  };
}

function validClinical(){
  return {
    clinical_summary:'Synthetic.',
    differential:[],
    critical_actions:[],
    safety_flags:[],
    uncertainties:[],
    confidence:'high',
    needs_more_information:false,
  };
}

function responseData({
  status='completed',
  incompleteReason=null,
  text=JSON.stringify(validClinical()),
  inputTokens=259,
  cachedTokens=0,
  cacheWriteTokens=0,
  outputTokens=464,
  reasoningTokens=42,
}={}){
  return {
    id:'resp_test',
    status,
    incomplete_details:
      incompleteReason
        ? {reason:incompleteReason}
        : null,
    output:
      text===null
        ? []
        : [
            {
              content:[
                {
                  text,
                },
              ],
            },
          ],
    usage:{
      input_tokens:inputTokens,
      input_tokens_details:{
        cached_tokens:cachedTokens,
        cache_write_tokens:cacheWriteTokens,
      },
      output_tokens:outputTokens,
      output_tokens_details:{
        reasoning_tokens:reasoningTokens,
      },
    },
  };
}

async function runWith({
  httpStatus=200,
  data,
  responseError,
}={}){
  return runGpt56LunaPlantaoPrimaryShadow({
    config:config(),
    uid:'telemetry-contract-user',
    mode:'plantao',
    userMessage:'synthetic',
    history:[],
    patientContext:{
      synthetic:true,
      realPatient:false,
    },
    openAiApiKey:'synthetic-key',
    serverEnabled:true,
    syntheticOnlyEnabled:false,
    fetchFn:async()=>{
      if(responseError){
        throw responseError;
      }

      return new Response(
        JSON.stringify(data),
        {
          status:httpStatus,
          headers:{
            'content-type':'application/json',
          },
        }
      );
    },
  });
}

(async()=>{
  assert.strictEqual(
    LUNA_VALIDATOR_VERSION,
    'medcases_luna_validator_v1'
  );

  assert.strictEqual(
    LUNA_PRICING_VERSION,
    'openai_gpt56_luna_api_pricing_2026_07_30_v1'
  );

  const observed=
    estimateGpt56LunaCost({
      inputTokens:259,
      cachedInputTokens:0,
      cacheWriteInputTokens:0,
      outputTokens:464,
    });

  assert.strictEqual(
    observed.estimatedCostNanoUsd,
    608600
  );

  assert.strictEqual(
    observed.estimatedCostUsd,
    0.0006086
  );

  assert.strictEqual(
    observed.longContextPricingApplied,
    false
  );

  const mixed=
    estimateGpt56LunaCost({
      inputTokens:1000000,
      cachedInputTokens:500000,
      cacheWriteInputTokens:100000,
      outputTokens:1000000,
    });

  assert.strictEqual(
    mixed.estimatedCostNanoUsd,
    2030000000
  );

  assert.strictEqual(
    mixed.estimatedCostUsd,
    2.03
  );

  assert.strictEqual(
    mixed.longContextPricingApplied,
    true
  );

  assert.strictEqual(
    classifyGpt56LunaTechnicalOutcome({
      httpStatus:429,
    }),
    'technical_rate_limit'
  );

  assert.strictEqual(
    classifyGpt56LunaTechnicalOutcome({
      httpStatus:500,
    }),
    'technical_provider_5xx'
  );

  assert.strictEqual(
    classifyGpt56LunaTechnicalOutcome({
      httpStatus:400,
    }),
    'technical_provider_4xx'
  );

  assert.strictEqual(
    classifyGpt56LunaTechnicalOutcome({
      httpStatus:200,
      providerStatus:'incomplete',
      incompleteReason:'max_output_tokens',
    }),
    'technical_incomplete_max_output_tokens'
  );

  assert.strictEqual(
    classifyGpt56LunaTechnicalOutcome({
      exceptionName:'TimeoutError',
    }),
    'technical_timeout'
  );

  assert.strictEqual(
    classifyGpt56LunaTechnicalOutcome({
      exceptionName:'TypeError',
    }),
    'technical_network_or_exception'
  );

  const ok=
    await runWith({
      data:responseData(),
    });

  assert.strictEqual(ok.completed,true);
  assert.strictEqual(ok.failureClass,null);
  assert.strictEqual(ok.technicalFailure,false);
  assert.strictEqual(ok.responseValid,true);
  assert.strictEqual(ok.cachedInputTokens,0);
  assert.strictEqual(ok.cacheWriteInputTokens,0);
  assert.strictEqual(
    ok.estimatedCostNanoUsd,
    608600
  );

  const incomplete=
    await runWith({
      data:responseData({
        status:'incomplete',
        incompleteReason:'max_output_tokens',
        text:null,
      }),
    });

  assert.strictEqual(
    incomplete.completed,
    false
  );

  assert.strictEqual(
    incomplete.failureClass,
    'technical_incomplete_max_output_tokens'
  );

  assert.strictEqual(
    incomplete.technicalFailure,
    true
  );

  const invalidJson=
    await runWith({
      data:responseData({
        text:'not-json',
      }),
    });

  assert.strictEqual(
    invalidJson.failureClass,
    'technical_invalid_json'
  );

  const invalidSchema=
    await runWith({
      data:responseData({
        text:JSON.stringify({
          clinical_summary:'only',
        }),
      }),
    });

  assert.strictEqual(
    invalidSchema.failureClass,
    'technical_schema_invalid'
  );

  const empty=
    await runWith({
      data:responseData({
        text:null,
      }),
    });

  assert.strictEqual(
    empty.failureClass,
    'technical_empty_output'
  );

  const rate=
    await runWith({
      httpStatus:429,
      data:responseData({
        status:'failed',
        text:null,
      }),
    });

  assert.strictEqual(
    rate.failureClass,
    'technical_rate_limit'
  );

  const five=
    await runWith({
      httpStatus:503,
      data:responseData({
        status:'failed',
        text:null,
      }),
    });

  assert.strictEqual(
    five.failureClass,
    'technical_provider_5xx'
  );

  const timeoutError=
    new Error('synthetic timeout');

  timeoutError.name='TimeoutError';

  const timeout=
    await runWith({
      responseError:timeoutError,
    });

  assert.strictEqual(
    timeout.failureClass,
    'technical_timeout'
  );

  assert.strictEqual(
    timeout.estimatedCostUsd,
    null
  );

  const telemetry=
    buildGpt56LunaShadowTelemetry(ok);

  assert.strictEqual(
    telemetry.failureClass,
    null
  );

  assert.strictEqual(
    telemetry.technicalFailure,
    false
  );

  assert.strictEqual(
    telemetry.responseValid,
    true
  );

  assert.strictEqual(
    telemetry.estimatedCostNanoUsd,
    608600
  );

  assert.strictEqual(
    telemetry.estimatedCostUsd,
    0.0006086
  );

  assert.strictEqual(
    'parsedClinicalResult' in telemetry,
    false
  );

  assert.strictEqual(
    'clinical_summary' in telemetry,
    false
  );

  assert.strictEqual(
    'uid' in telemetry,
    false
  );

  console.log('LUNA_COST_PRICING_VERSION=PASS');
  console.log('LUNA_COST_CURRENT_RATE_EXACT_NANOUSD=PASS');
  console.log('LUNA_COST_CACHED_INPUT_ACCOUNTING=PASS');
  console.log('LUNA_COST_CACHE_WRITE_ACCOUNTING=PASS');
  console.log('LUNA_COST_LONG_CONTEXT_MULTIPLIER=PASS');
  console.log('LUNA_VALIDATOR_FAILURE_TAXONOMY=PASS');
  console.log('LUNA_VALIDATOR_TIMEOUT_CLASS=PASS');
  console.log('LUNA_VALIDATOR_RATE_LIMIT_CLASS=PASS');
  console.log('LUNA_VALIDATOR_PROVIDER_5XX_CLASS=PASS');
  console.log('LUNA_VALIDATOR_INCOMPLETE_MAX_OUTPUT_CLASS=PASS');
  console.log('LUNA_VALIDATOR_INVALID_JSON_CLASS=PASS');
  console.log('LUNA_VALIDATOR_SCHEMA_INVALID_CLASS=PASS');
  console.log('LUNA_TELEMETRY_RAW_CLINICAL_RESULT=ABSENT');
  console.log('LUNA_TELEMETRY_RAW_UID=ABSENT');
  console.log('LUNA_TELEMETRY_COST_VALIDATOR_STABILIZATION=PASS');
})().catch((e)=>{
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
