'use strict';

const assert = require('assert');

const {
  resolvePlantaoLiveAuthorityGateV1,
  buildPlantaoLiveProviderExecutionConfigV1,
  renderPlantaoClinicalResultV1,
  executePlantaoLiveAuthorityV1,
} = require(
  '../lib/ai_control_plane_v2/plantao_live_authority_v1'
);

function config({
  live = true,
  fallback = true,
  terra = false,
} = {}) {
  return {
    enabled: true,
    legacyParityMode: false,
    rollout: {
      enabled: true,
      percent: 100,
    },
    featureFlags: {
      plantao_router_v2: live,
      clinical_escalation_v2: terra,
      gpt5_nano_real_shadow_v1: true,
      gpt56_luna_real_shadow_v1: true,
      gemini31_paid_real_shadow_v1: true,
      gpt56_terra_real_shadow_v1: true,
    },
    plantao: {
      enabled: live,
      routerMayRespondToUser: false,
      technicalFallback: {
        enabled: fallback,
      },
      clinicalEscalation: {
        enabled: terra,
      },
    },
    shadowProviderCalls: {
      gpt5Nano: {
        enabled: true,
        rolloutPercent: 1,
        cohortSalt: 'nano-shadow',
        timeoutMs: 5000,
        maxOutputTokens: 512,
      },
      gpt56Luna: {
        enabled: true,
        rolloutPercent: 1,
        cohortSalt: 'luna-shadow',
        timeoutMs: 20000,
        maxOutputTokens: 4096,
        reasoningEffort: 'low',
      },
      gemini31Paid: {
        enabled: true,
        rolloutPercent: 1,
        cohortSalt: 'gemini-shadow',
        timeoutMs: 12000,
        maxOutputTokens: 2048,
      },
      gpt56Terra: {
        enabled: true,
        rolloutPercent: 1,
        cohortSalt: 'terra-shadow',
        timeoutMs: 45000,
        maxOutputTokens: 4096,
        reasoningEffort: 'high',
      },
    },
    clinicalEscalationPolicies: {
      terra: {
        enabled: terra,
        terraAllowed: terra,
      },
    },
    clinicalEscalationStabilization: {
      terra: {
        enabled: terra,
        maxEstimatedInputTokens: 30000,
        maxOutputTokens: 4096,
        maxEstimatedCostNanoUsd: 60000000,
      },
    },
  };
}

function nanoOk() {
  return {
    attempted: true,
    completed: true,
    gateReason: 'open',
    classification: {
      complexity: 'moderate',
      escalation_signal: false,
      confidence_band: 'high',
      reason_code:
        'routine_single_problem',
    },
    inputTokens: 10,
    outputTokens: 5,
  };
}

function lunaOk() {
  return {
    attempted: true,
    completed: true,
    responseValid: true,
    technicalFailure: false,
    failureClass: null,
    inputTokens: 100,
    outputTokens: 200,
    parsedClinicalResult: {
      clinical_summary:
        'Síndrome coronariana aguda provável.',
      differential: [
        {
          diagnosis: 'IAM com supra',
          rationale: 'ECG compatível',
          urgency: 'critical',
        },
      ],
      critical_actions: [
        'Monitorização contínua',
      ],
      safety_flags: [],
      uncertainties: [],
      confidence: 'high',
      needs_more_information: false,
    },
  };
}

function lunaTechnicalFailure() {
  return {
    attempted: true,
    completed: false,
    responseValid: false,
    technicalFailure: true,
    failureClass: 'technical_timeout',
    inputTokens: 20,
    outputTokens: 0,
    parsedClinicalResult: null,
  };
}

function geminiOk() {
  return {
    attempted: true,
    completed: true,
    responseValid: true,
    technicalFailure: false,
    failureClass: null,
    inputTokens: 80,
    outputTokens: 120,
    parsedClinicalResult: {
      clinical_summary:
        'Fallback técnico concluído.',
      differential: [
        'Síndrome coronariana aguda',
      ],
      critical_actions: [
        'Monitorização contínua',
      ],
      safety_flags: [],
      uncertainties: [],
      confidence: 'medium',
      needs_more_information: false,
    },
  };
}

function terraOk() {
  return {
    attempted: true,
    completed: true,
    responseValid: true,
    technicalFailure: false,
    failureClass: null,
    inputTokens: 150,
    outputTokens: 250,
    parsedClinicalResult: {
      clinical_synthesis:
        'Caso complexo reavaliado.',
      diagnostic_conflicts: [
        'SCA versus síndrome aórtica',
      ],
      differential: [
        'Síndrome coronariana aguda',
        'Síndrome aórtica aguda',
      ],
      critical_actions: [
        'Priorizar estabilização',
      ],
      disposition: [
        'Área crítica',
      ],
      safety_flags: [],
      uncertainties: [],
      confidence: 'medium',
      needs_more_information: false,
    },
  };
}

const baseArgs = {
  executionGateOpen: true,
  uid: 'synthetic-live-authority-user',
  mode: 'plantao',
  lang: 'pt',
  userMessage:
    'Synthetic non-identifiable clinical case.',
  history: [],
  patientContext: {
    synthetic: true,
    realPatient: false,
  },
  providerDataPolicy: null,
  protectedClinicalProjection: null,
  openAiApiKey: 'fake-openai',
  geminiApiKey: 'fake-gemini',
};

(async () => {
  // Gate closed must call nothing.
  {
    let calls = 0;

    const result =
      await executePlantaoLiveAuthorityV1({
        ...baseArgs,
        config: config({ live: false }),
        runners: {
          nano: async () => {
            calls++;
            return nanoOk();
          },
        },
      });

    assert.strictEqual(calls, 0);
    assert.strictEqual(result.eligible, false);
    assert.strictEqual(result.handled, false);
    assert.strictEqual(
      result.userResponseAuthority,
      false
    );
  }

  // Explicit execution gate is mandatory.
  assert.strictEqual(
    resolvePlantaoLiveAuthorityGateV1({
      config: config(),
      mode: 'plantao',
      executionGateOpen: false,
    }).eligible,
    false
  );

  // Provider config is derived in-memory, forcing live 100% without
  // mutating the active remote config document.
  {
    const original = config();
    const before = JSON.stringify(original);

    const derived =
      buildPlantaoLiveProviderExecutionConfigV1(
        original
      );

    assert.strictEqual(
      derived.shadowProviderCalls
        .gpt5Nano.rolloutPercent,
      100
    );
    assert.strictEqual(
      derived.shadowProviderCalls
        .gpt56Luna.rolloutPercent,
      100
    );
    assert.strictEqual(
      derived.shadowProviderCalls
        .gemini31Paid.rolloutPercent,
      100
    );
    assert.strictEqual(
      derived.shadowProviderCalls
        .gpt56Terra.rolloutPercent,
      100
    );
    assert.strictEqual(
      JSON.stringify(original),
      before
    );
  }

  // Nano failure => no Luna/Gemini/Terra, legacy fallback.
  {
    const count = {
      nano: 0,
      luna: 0,
      gemini: 0,
      terra: 0,
    };

    const result =
      await executePlantaoLiveAuthorityV1({
        ...baseArgs,
        config: config(),
        runners: {
          nano: async () => {
            count.nano++;
            return {
              attempted: false,
              completed: false,
              gateReason:
                'server_hard_gate_closed',
            };
          },
          luna: async () => {
            count.luna++;
            return lunaOk();
          },
          gemini: async () => {
            count.gemini++;
            return geminiOk();
          },
          terra: async () => {
            count.terra++;
            return terraOk();
          },
        },
      });

    assert.deepStrictEqual(
      count,
      {
        nano: 1,
        luna: 0,
        gemini: 0,
        terra: 0,
      }
    );
    assert.strictEqual(result.eligible, true);
    assert.strictEqual(result.handled, false);
    assert.strictEqual(
      result.suppressShadow,
      true
    );
  }

  // Nano routes only; Luna owns routine final response.
  {
    let nanoCount = 0;
    let lunaCount = 0;
    let geminiCount = 0;
    let terraCount = 0;

    const result =
      await executePlantaoLiveAuthorityV1({
        ...baseArgs,
        config: config(),
        runners: {
          nano: async () => {
            nanoCount++;
            return nanoOk();
          },
          luna: async () => {
            lunaCount++;
            return lunaOk();
          },
          gemini: async () => {
            geminiCount++;
            return geminiOk();
          },
          terra: async () => {
            terraCount++;
            return terraOk();
          },
        },
      });

    assert.strictEqual(nanoCount, 1);
    assert.strictEqual(lunaCount, 1);
    assert.strictEqual(geminiCount, 0);
    assert.strictEqual(terraCount, 0);
    assert.strictEqual(result.handled, true);
    assert.strictEqual(
      result.selectedAlias,
      'plantao_primary'
    );
    assert.strictEqual(
      result.response.model,
      'plantao_primary'
    );
    assert.strictEqual(
      result.userResponseAuthority,
      true
    );

    const serialized =
      JSON.stringify(result.response)
        .toLowerCase();

    assert.strictEqual(
      serialized.includes('gpt-5.6'),
      false
    );
    assert.strictEqual(
      serialized.includes(
        'gemini-3.1'
      ),
      false
    );

    assert.deepStrictEqual(
      Object.keys(result.response).sort(),
      [
        'durationMs',
        'inputTokensApprox',
        'model',
        'outputTokensApprox',
        'text',
      ].sort()
    );
  }

  // Luna technical failure => Gemini only. Terra must remain zero.
  {
    let geminiCount = 0;
    let terraCount = 0;

    const result =
      await executePlantaoLiveAuthorityV1({
        ...baseArgs,
        config: config(),
        runners: {
          nano: async () => nanoOk(),
          luna: async () =>
            lunaTechnicalFailure(),
          gemini: async (args) => {
            geminiCount++;
            assert.strictEqual(
              args.upstreamTechnicalFailure,
              true
            );
            assert.strictEqual(
              args.upstreamClinicalEscalation,
              false
            );
            return geminiOk();
          },
          terra: async () => {
            terraCount++;
            return terraOk();
          },
        },
      });

    assert.strictEqual(geminiCount, 1);
    assert.strictEqual(terraCount, 0);
    assert.strictEqual(result.handled, true);
    assert.strictEqual(
      result.selectedAlias,
      'plantao_cross_provider'
    );
  }

  // Gemini failure => legacy fallback; never Terra.
  {
    let terraCount = 0;

    const result =
      await executePlantaoLiveAuthorityV1({
        ...baseArgs,
        config: config(),
        runners: {
          nano: async () => nanoOk(),
          luna: async () =>
            lunaTechnicalFailure(),
          gemini: async () => ({
            attempted: true,
            completed: false,
            responseValid: false,
            technicalFailure: true,
            failureClass:
              'technical_provider_5xx',
          }),
          terra: async () => {
            terraCount++;
            return terraOk();
          },
        },
      });

    assert.strictEqual(terraCount, 0);
    assert.strictEqual(result.handled, false);
    assert.strictEqual(
      result.userResponseAuthority,
      false
    );
  }

  // Clinical escalation => Terra may supersede a valid Luna response.
  {
    let geminiCount = 0;
    let terraCount = 0;

    const result =
      await executePlantaoLiveAuthorityV1({
        ...baseArgs,
        config: config({ terra: true }),
        runners: {
          nano: async () => nanoOk(),
          luna: async () => lunaOk(),
          gemini: async () => {
            geminiCount++;
            return geminiOk();
          },
          terra: async (args) => {
            terraCount++;
            assert.strictEqual(
              args.upstreamTechnicalFailure,
              false
            );
            assert.strictEqual(
              args.clinicalEscalation,
              true
            );
            assert.strictEqual(
              args.terraAllowed,
              true
            );
            return terraOk();
          },
        },
        helpers: {
          buildServerContextMetrics: () => ({
            version:
              'server_context_metrics_v1',
            userMessageChars: 6000,
            historyTurns: 12,
            patientContextFieldCount: 12,
          }),
          buildTerraDecision: () => ({
            clinicalEscalation: true,
            terraAllowed: true,
            signalCodes: [
              'diagnostic_conflict',
            ],
          }),
          stabilizeTerra: () => ({
            providerCallAllowed: true,
            clinicalEscalation: true,
            terraAllowed: true,
            signalCodes: [
              'diagnostic_conflict',
            ],
          }),
        },
      });

    assert.strictEqual(geminiCount, 0);
    assert.strictEqual(terraCount, 1);
    assert.strictEqual(result.handled, true);
    assert.strictEqual(
      result.selectedAlias,
      'plantao_complex'
    );
  }

  // Terra technical/provider failure => keep already-valid Luna final.
  {
    const result =
      await executePlantaoLiveAuthorityV1({
        ...baseArgs,
        config: config({ terra: true }),
        runners: {
          nano: async () => nanoOk(),
          luna: async () => lunaOk(),
          gemini: async () => {
            throw new Error(
              'GEMINI_MUST_NOT_RUN'
            );
          },
          terra: async () => ({
            attempted: true,
            completed: false,
            responseValid: false,
            technicalFailure: true,
            failureClass:
              'technical_timeout',
          }),
        },
        helpers: {
          buildServerContextMetrics: () => ({}),
          buildTerraDecision: () => ({
            clinicalEscalation: true,
            terraAllowed: true,
            signalCodes: ['complexity'],
          }),
          stabilizeTerra: () => ({
            providerCallAllowed: true,
            clinicalEscalation: true,
            terraAllowed: true,
            signalCodes: ['complexity'],
          }),
        },
      });

    assert.strictEqual(result.handled, true);
    assert.strictEqual(
      result.selectedAlias,
      'plantao_primary'
    );
  }

  const esText =
    renderPlantaoClinicalResultV1(
      geminiOk().parsedClinicalResult,
      { lang: 'es' }
    );

  assert.ok(
    esText.includes('Resumen clínico')
  );

  console.log('PLANTAO_LIVE_GATE_FAIL_CLOSED=PASS');
  console.log('PLANTAO_LIVE_PROVIDER_CONFIG_IN_MEMORY_ONLY=PASS');
  console.log('PLANTAO_NANO_ROUTER_ONLY=PASS');
  console.log('PLANTAO_LUNA_PRIMARY_FINAL=PASS');
  console.log('PLANTAO_GEMINI_TECHNICAL_FALLBACK_ONLY=PASS');
  console.log('PLANTAO_GEMINI_FAILURE_LEGACY_FALLBACK=PASS');
  console.log('PLANTAO_TERRA_CLINICAL_ESCALATION_ONLY=PASS');
  console.log('PLANTAO_TERRA_FAILURE_RETURNS_VALID_LUNA=PASS');
  console.log('PLANTAO_FLUTTER_RESPONSE_ENVELOPE=PASS');
  console.log('PLANTAO_COMMERCIAL_MODEL_NAME_TO_FLUTTER=NO');
  console.log('PLANTAO_PT_ES_RENDERER=PASS');
  console.log('PLANTAO_LIVE_AUTHORITY_V1_CONTRACT=PASS');
})().catch((error) => {
  console.error(
    error && error.stack
      ? error.stack
      : error
  );
  process.exit(1);
});
