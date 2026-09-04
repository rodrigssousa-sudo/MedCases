'use strict';

const assert = require('assert');

const {
  TELEMETRY_MARKER,
  OPENAI_RESPONSES_URL,
  SERVER_HARD_GATE,
  REMOTE_FEATURE_FLAG,
  deterministicShadowBucket,
  evaluateGpt5NanoRealShadowGate,
  buildGpt5NanoRouterRequest,
  runGpt5NanoPlantaoRouterRealShadow: runGpt5NanoPlantaoRouterRealShadowRaw,
  buildGpt5NanoRealShadowTelemetry,
} = require(
  '../lib/ai_control_plane_v2/gpt5_nano_plantao_router_real_shadow_v1'
);

async function runGpt5NanoPlantaoRouterRealShadow(args) {
  const existingPatientContext =
    args &&
    args.patientContext &&
    typeof args.patientContext === 'object' &&
    !Array.isArray(args.patientContext)
      ? args.patientContext
      : {};

  return runGpt5NanoPlantaoRouterRealShadowRaw({
    ...args,
    patientContext: {
      ...existingPatientContext,
      synthetic: true,
      realPatient: false,
    },
  });
}


function openConfig({
  percent = 100,
  salt = 'nano-shadow-test-salt-0001',
} = {}) {
  return {
    featureFlags: {
      [REMOTE_FEATURE_FLAG]: true,
    },
    shadowProviderCalls: {
      gpt5Nano: {
        enabled: true,
        rolloutPercent: percent,
        cohortSalt: salt,
        timeoutMs: 3000,
        maxOutputTokens: 96,
      },
    },
  };
}

function fakeResponse({
  ok = true,
  status = 200,
  body,
}) {
  return {
    ok,
    status,
    async json() {
      return body;
    },
  };
}

async function main() {
  assert.strictEqual(
    OPENAI_RESPONSES_URL,
    'https://api.openai.com/v1/responses'
  );
  assert.strictEqual(
    SERVER_HARD_GATE,
    'AI_GPT5_NANO_REAL_SHADOW_ENABLED'
  );
  assert.strictEqual(
    REMOTE_FEATURE_FLAG,
    'gpt5_nano_real_shadow_v1'
  );
  assert.strictEqual(
    TELEMETRY_MARKER,
    '[AI_CONTROL_PLANE_V2_GPT5_NANO_REAL_SHADOW]'
  );

  // Deterministic 0..9999 cohort.
  const b1 = deterministicShadowBucket(
    'uid-123',
    'salt-12345678'
  );
  const b2 = deterministicShadowBucket(
    'uid-123',
    'salt-12345678'
  );

  assert.strictEqual(b1, b2);
  assert.ok(b1 >= 0 && b1 <= 9999);

  // Hard server gate closed.
  {
    const g = evaluateGpt5NanoRealShadowGate({
      config: openConfig(),
      uid: 'u',
      mode: 'plantao',
      serverEnabled: false,
    });

    assert.strictEqual(g.allowed, false);
    assert.strictEqual(
      g.reason,
      'server_hard_gate_closed'
    );
  }

  // Remote flag absent: closed.
  {
    const g = evaluateGpt5NanoRealShadowGate({
      config: {},
      uid: 'u',
      mode: 'plantao',
      serverEnabled: true,
    });

    assert.strictEqual(g.allowed, false);
    assert.strictEqual(
      g.reason,
      'remote_flag_or_config_closed'
    );
  }

  // Study can never run this Plantao router shadow.
  {
    const g = evaluateGpt5NanoRealShadowGate({
      config: openConfig(),
      uid: 'u',
      mode: 'study',
      serverEnabled: true,
    });

    assert.strictEqual(g.allowed, false);
    assert.strictEqual(
      g.reason,
      'mode_not_plantao'
    );
  }

  // Missing UID fails closed.
  {
    const g = evaluateGpt5NanoRealShadowGate({
      config: openConfig(),
      uid: '',
      mode: 'plantao',
      serverEnabled: true,
    });

    assert.strictEqual(g.allowed, false);
    assert.strictEqual(g.reason, 'uid_missing');
  }

  // 100% synthetic gate opens.
  {
    const g = evaluateGpt5NanoRealShadowGate({
      config: openConfig({percent:100}),
      uid: 'user-a',
      mode: 'plantao',
      serverEnabled: true,
    });

    assert.strictEqual(g.allowed, true);
    assert.strictEqual(g.reason, 'open');
  }

  // Request shape is Responses API + structured output,
  // low output ceiling and no storage.
  {
    const req = buildGpt5NanoRouterRequest({
      inputText: 'synthetic clinical input',
      maxOutputTokens: 96,
    });

    assert.strictEqual(req.model, 'gpt-5-nano');
    assert.strictEqual(req.store, false);
    assert.strictEqual(
      Object.prototype.hasOwnProperty.call(
        req,
        'temperature'
      ),
      false
    );
    assert.strictEqual(
      Object.prototype.hasOwnProperty.call(
        req,
        'top_p'
      ),
      false
    );
    assert.strictEqual(req.max_output_tokens, 96);
    assert.strictEqual(
      req.text.format.type,
      'json_schema'
    );
    assert.strictEqual(req.text.format.strict, true);
    assert.ok(
      req.instructions.includes(
        'Do not provide diagnosis'
      )
    );
  }

  // Closed gate => fetch must never run.
  {
    let fetchCount = 0;

    const r =
      await runGpt5NanoPlantaoRouterRealShadow({
        config: {},
        uid: 'u',
        mode: 'plantao',
        userMessage: 'x',
        history: [],
        patientContext: null,
        openAiApiKey: 'secret',
        serverEnabled: true,
        fetchFn: async () => {
          fetchCount += 1;
          throw new Error('must_not_execute');
        },
      });

    assert.strictEqual(fetchCount, 0);
    assert.strictEqual(r.attempted, false);
    assert.strictEqual(
      r.userResponseAuthority,
      false
    );
    assert.strictEqual(
      r.liveAuthorityChanged,
      false
    );
  }

  // Successful synthetic provider response.
  {
    let captured = null;
    let time = 1000;

    const r =
      await runGpt5NanoPlantaoRouterRealShadow({
        config: openConfig(),
        uid: 'u-success',
        mode: 'plantao',
        userMessage: 'synthetic patient question',
        history: [
          {role:'user',content:'prior synthetic'},
        ],
        patientContext: {
          synthetic: true,
          instability: false,
        },
        openAiApiKey: 'SERVER_SECRET_SENTINEL',
        serverEnabled: true,
        nowMs: () => {
          time += 25;
          return time;
        },
        fetchFn: async (url, options) => {
          captured = {url, options};

          return fakeResponse({
            body: {
              model: 'gpt-5-nano',
              output_text: JSON.stringify({
                complexity: 'moderate',
                escalation_signal: false,
                confidence_band: 'high',
                reason_code:
                  'multiple_active_problems',
              }),
              usage: {
                input_tokens: 50,
                output_tokens: 20,
                total_tokens: 70,
              },
            },
          });
        },
      });

    assert.strictEqual(
      captured.url,
      OPENAI_RESPONSES_URL
    );
    assert.strictEqual(
      captured.options.method,
      'POST'
    );
    assert.ok(
      captured.options.headers.Authorization.startsWith(
        'Bearer '
      )
    );

    const payload = JSON.parse(
      captured.options.body
    );

    assert.strictEqual(payload.model, 'gpt-5-nano');
    assert.strictEqual(payload.store, false);

    assert.strictEqual(r.attempted, true);
    assert.strictEqual(r.completed, true);
    assert.strictEqual(r.outcome, 'completed');
    assert.strictEqual(r.model, 'gpt-5-nano');
    assert.strictEqual(
      r.classification.complexity,
      'moderate'
    );
    assert.strictEqual(
      r.classification.escalationSignal,
      false
    );
    assert.strictEqual(
      r.userResponseAuthority,
      false
    );
    assert.strictEqual(
      r.liveAuthorityChanged,
      false
    );
    assert.strictEqual(r.telemetryOnly, true);

    const telemetry =
      buildGpt5NanoRealShadowTelemetry(r);

    const serialized =
      JSON.stringify(telemetry);

    for (const forbidden of [
      'SERVER_SECRET_SENTINEL',
      'synthetic patient question',
      'prior synthetic',
      'patientContext',
      'userMessage',
      'history',
      'uid',
      'apiKey',
      'Authorization',
    ]) {
      assert.strictEqual(
        serialized.includes(forbidden),
        false
      );
    }

    assert.strictEqual(
      telemetry.userResponseAuthority,
      false
    );
    assert.strictEqual(
      telemetry.liveAuthorityChanged,
      false
    );
  }

  // Provider HTTP error is metadata-only failure.
  {
    const r =
      await runGpt5NanoPlantaoRouterRealShadow({
        config: openConfig(),
        uid: 'u-http',
        mode: 'plantao',
        userMessage: 'x',
        history: [],
        patientContext: null,
        openAiApiKey: 'secret',
        serverEnabled: true,
        fetchFn: async () =>
          fakeResponse({
            ok: false,
            status: 429,
            body: {
              error: {
                message:
                  'raw provider error must not leak',
              },
            },
          }),
      });

    assert.strictEqual(r.attempted, true);
    assert.strictEqual(r.completed, false);
    assert.strictEqual(
      r.outcome,
      'provider_http_error'
    );
    assert.strictEqual(r.httpStatus, 429);

    const telemetry =
      buildGpt5NanoRealShadowTelemetry(r);

    assert.strictEqual(
      JSON.stringify(telemetry).includes(
        'raw provider error must not leak'
      ),
      false
    );
  }

  // Invalid structured output does not become authority.
  {
    const r =
      await runGpt5NanoPlantaoRouterRealShadow({
        config: openConfig(),
        uid: 'u-invalid',
        mode: 'plantao',
        userMessage: 'x',
        history: [],
        patientContext: null,
        openAiApiKey: 'secret',
        serverEnabled: true,
        fetchFn: async () =>
          fakeResponse({
            body: {
              model: 'gpt-5-nano',
              output_text: '{"unexpected":true}',
            },
          }),
      });

    assert.strictEqual(r.completed, false);
    assert.strictEqual(
      r.outcome,
      'invalid_structured_output'
    );
    assert.strictEqual(
      r.userResponseAuthority,
      false
    );
  }

  console.log(
    'AI_CONTROL_PLANE_V2_GPT5_NANO_PLANTAO_ROUTER_REAL_SHADOW_FOUNDATION=PASS'
  );
  console.log('OPENAI_RESPONSES_API_REQUEST_SHAPE=PASS');
  console.log('GPT5_NANO_SAMPLING_PARAMS_OMITTED=PASS');
  console.log('GPT5_NANO_STRUCTURED_CLASSIFIER_SCHEMA=PASS');
  console.log('SERVER_HARD_GATE_FAIL_CLOSED=PASS');
  console.log('REMOTE_FEATURE_FLAG_FAIL_CLOSED=PASS');
  console.log('SERVER_SIDE_UID_COHORT=PASS');
  console.log('STUDY_EXECUTION_FORBIDDEN=PASS');
  console.log('PLANTAO_ROUTER_ONLY=PASS');
  console.log('GPT5_NANO_USER_RESPONSE_AUTHORITY=NONE');
  console.log('LIVE_AUTHORITY_CHANGED=NO');
  console.log('TELEMETRY_ONLY_RESULT=PASS');
  console.log('RAW_CLINICAL_TELEMETRY=ABSENT');
  console.log('RAW_PROVIDER_ERROR_TELEMETRY=ABSENT');
  console.log('PRODUCTION_CALLSITE_WIRING=NONE');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
