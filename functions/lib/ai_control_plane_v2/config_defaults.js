'use strict';

const { CAPABILITY_ALIASES } = require('./contract');

const CONFIG_SCHEMA_VERSION = 'ai-config-v2';
const BOOTSTRAP_CONFIG_VERSION = 'AI_CONFIG_V2_BOOTSTRAP_0001';

/**
 * Fail-closed compiled V2 bootstrap.
 *
 * V2 is deliberately OFF. The existing live path remains authoritative until:
 * 1) current behavior is migrated 1:1,
 * 2) parity is proven,
 * 3) provider bindings are verified,
 * 4) rollout is explicitly enabled remotely.
 */
function makeSafeBootstrapConfig() {
  return Object.freeze({
    schemaVersion: CONFIG_SCHEMA_VERSION,
    configVersion: BOOTSTRAP_CONFIG_VERSION,

    enabled: false,
    legacyParityMode: true,
    clientOverrideAllowed: false,

    rollout: Object.freeze({
      enabled: false,
      percent: 0,
      cohortSaltVersion: 'v1',
    }),

    aliases: Object.freeze({
      [CAPABILITY_ALIASES.STUDY_PRIMARY]: 'gemini_31_flash_lite_free',
      [CAPABILITY_ALIASES.STUDY_FALLBACK_1]: 'gpt_5_nano',
      [CAPABILITY_ALIASES.STUDY_FALLBACK_2]: 'gemini_31_flash_lite_paid',
      [CAPABILITY_ALIASES.PLANTAO_ROUTER]: 'gpt_5_nano',
      [CAPABILITY_ALIASES.PLANTAO_PRIMARY]: 'gpt_56_luna',
      [CAPABILITY_ALIASES.PLANTAO_CROSS_PROVIDER]:
        'gemini_31_flash_lite_paid',
      [CAPABILITY_ALIASES.PLANTAO_COMPLEX]: 'gpt_56_terra',
    }),

    study: Object.freeze({
      enabled: false,
      route: Object.freeze([
        CAPABILITY_ALIASES.STUDY_PRIMARY,
        CAPABILITY_ALIASES.STUDY_FALLBACK_1,
        CAPABILITY_ALIASES.STUDY_FALLBACK_2,
      ]),
      freeTierEnabled: false,
      privacyGuard: Object.freeze({
        enabled: true,
        requireEducationalClassification: true,
        allowIdentifiableClinicalData: false,
        skipFreeOnPatientContext: true,
        skipFreeOnSensitiveClinicalContext: true,
      }),
      technicalFallback: Object.freeze({
        enabled: true,
        maxRetriesPerModel: 1,
        reasons: Object.freeze([
          'timeout',
          'rate_limit',
          'provider_5xx',
          'network',
          'empty_response',
          'invalid_json',
          'invalid_schema',
          'model_unavailable',
        ]),
      }),
      promptVersions: Object.freeze({
        system: 'study_system_prompt_v1',
      }),
    }),

    plantao: Object.freeze({
      enabled: false,
      routerAlias: CAPABILITY_ALIASES.PLANTAO_ROUTER,
      primaryAlias: CAPABILITY_ALIASES.PLANTAO_PRIMARY,
      technicalFallbackAlias: CAPABILITY_ALIASES.PLANTAO_CROSS_PROVIDER,
      complexAlias: CAPABILITY_ALIASES.PLANTAO_COMPLEX,

      routerMayRespondToUser: false,

      technicalFallback: Object.freeze({
        enabled: true,
        maxRetriesPerModel: 1,
        terraAllowed: false,
        reasons: Object.freeze([
          'timeout',
          'rate_limit',
          'provider_5xx',
          'network',
          'empty_response',
          'invalid_json',
          'invalid_schema',
          'model_unavailable',
        ]),
      }),

      clinicalEscalation: Object.freeze({
        enabled: false,
        terraAllowed: false,
        criteriaVersion: 'plantao_escalation_criteria_v1',
        criteria: Object.freeze([
          'multiple_comorbidities',
          'diagnostic_conflict',
          'longitudinal_complexity',
          'previous_response_insufficient',
          'protocol_context_incompatibility',
          'high_variable_count',
          'very_large_context',
          'difficult_synthesis',
          'low_confidence',
          'source_conflict',
          'explicit_complexity_classification',
        ]),
      }),

      contextContinuity: Object.freeze({
        enabled: true,
        preserveConversationId: true,
        preserveClinicalThreadId: true,
        preserveSameTopic: true,
        preserveContextualFollowup: true,
        preservePreviousClinicalState: true,
      }),

      ragPolicy: Object.freeze({
        enabled: false,
        referenceResolutionEnabled: false,
        contextContradictionGuardEnabled: true,
      }),

      promptVersions: Object.freeze({
        router: 'plantao_router_prompt_v1',
        clinical: 'plantao_clinical_prompt_v1',
        escalation: 'plantao_escalation_prompt_v1',
      }),
    }),

    circuitBreaker: Object.freeze({
      enabled: false,
      scope: 'provider_and_model',
      failureWindowSeconds: 300,
      minimumSamples: 5,
      openAfterConsecutiveFailures: 3,
      halfOpenProbeCount: 1,
      trackedReasons: Object.freeze([
        'rate_limit',
        'timeout',
        'provider_5xx',
        'invalid_schema',
      ]),
    }),

    costControls: Object.freeze({
      enabled: false,
      dailyCostCapUsd: null,
      monthlyCostCapUsd: null,
      perUserSoftLimitUsd: null,
      terraDailyCallLimit: 0,
    }),

    telemetry: Object.freeze({
      enabled: true,
      metadataOnly: true,
      rawPromptLogging: false,
      rawPatientTextLogging: false,
      pseudonymousUserIdOnly: true,
      recordConfigVersion: true,
      recordPromptVersion: true,
      recordAlias: true,
      recordProviderModelName: false,
      recordLatency: true,
      recordTokenApproximation: true,
      recordEstimatedCost: true,
      recordFallbackKind: true,
      recordEscalationLevel: true,
    }),

    featureFlags: Object.freeze({
      study_ai_v2: false,
      plantao_router_v2: false,
      clinical_escalation_v2: false,
      gemini_free_v2: false,
      new_rag_router_v2: false,
    }),
  });
}

module.exports = {
  CONFIG_SCHEMA_VERSION,
  BOOTSTRAP_CONFIG_VERSION,
  makeSafeBootstrapConfig,
};
