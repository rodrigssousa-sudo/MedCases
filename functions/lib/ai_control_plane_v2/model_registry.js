'use strict';

/**
 * Backend-only MODEL REGISTRY.
 *
 * IMPORTANT:
 * - Registry keys below are MedCases internal identifiers.
 * - apiModelName intentionally remains null during V2 foundation/parity phase.
 * - Exact external provider model IDs must be bound server-side only after
 *   provider/API verification and explicit activation.
 * - No API key/secret belongs here.
 */

const MODEL_REGISTRY_VERSION = 'AI_MODEL_REGISTRY_V2_BOOTSTRAP_0001';

/**
 * Provider IDs physically verified against the MedCases provider accounts.
 *
 * IMPORTANT:
 * - These bindings are metadata only at this stage.
 * - `activationState: 'shadow_verified'` explicitly prevents this map from
 *   becoming live execution authority by itself.
 * - No secret value is stored here.
 * - Gemini personal FREE is intentionally NOT a backend provider binding.
 */
const VERIFIED_PROVIDER_BINDINGS_VERSION =
  'AI_VERIFIED_PROVIDER_BINDINGS_V2_2026_08_28_0001';

const VERIFIED_PROVIDER_BINDINGS = Object.freeze({
  gpt_5_nano: Object.freeze({
    provider: 'openai',
    apiModelName: 'gpt-5-nano',
    credentialEnv: 'OPENAI_API_KEY',
    accountAccessVerified: true,
    activationState: 'shadow_verified',
    backendExecutable: true,
  }),

  gemini_31_flash_lite_paid: Object.freeze({
    provider: 'google',
    apiModelName: 'gemini-3.1-flash-lite',
    credentialEnv: 'GEMINI_PAID_API_KEY',
    accountAccessVerified: true,
    billingVerified: true,
    activationState: 'shadow_verified',
    backendExecutable: true,
  }),

  gpt_56_luna: Object.freeze({
    provider: 'openai',
    apiModelName: 'gpt-5.6-luna',
    credentialEnv: 'OPENAI_API_KEY',
    accountAccessVerified: true,
    activationState: 'shadow_verified',
    backendExecutable: true,
  }),

  gpt_56_terra: Object.freeze({
    provider: 'openai',
    apiModelName: 'gpt-5.6-terra',
    credentialEnv: 'OPENAI_API_KEY',
    accountAccessVerified: true,
    activationState: 'shadow_verified',
    backendExecutable: true,
  }),
});

/**
 * External client capability: Study personal Gemini FREE.
 *
 * This is deliberately NOT in VERIFIED_PROVIDER_BINDINGS because the server
 * never owns a FREE Gemini API key for this path. The user authenticates their
 * personal Gemini account on the client. Backend fallback starts only after
 * personal-free failure/unavailability or a privacy bypass.
 */
const EXTERNAL_CLIENT_CAPABILITIES = Object.freeze({
  study_personal_gemini_free: Object.freeze({
    provider: 'google',
    providerModelFamily: 'gemini-3.1-flash-lite',
    executionPlane: 'client_personal_account',
    backendExecutable: false,
    backendApiKeyRequired: false,
    personalUserAuthenticationRequired: true,
    privacyClass: 'educational_non_identifiable_only',
    identifiableClinicalDataAllowed: false,
    patientContextAllowed: false,
    sensitiveClinicalContextAllowed: false,
  }),
});

/**
 * Stable MedCases role aliases.
 *
 * Role policy lives here rather than on the model because one model may have
 * different permissions in different modes. gpt-5-nano is the key example:
 * - Study fallback: may answer the user.
 * - Plantao router/classifier: must never be the physician-facing answer.
 */
const ROUTE_ALIASES = Object.freeze({
  study_primary: Object.freeze({
    targetType: 'external_client_capability',
    target: 'study_personal_gemini_free',
    respondsToUser: true,
    technicalFallbackOnly: false,
    clinicalEscalationOnly: false,
  }),

  study_fallback_1: Object.freeze({
    targetType: 'backend_model',
    target: 'gpt_5_nano',
    respondsToUser: true,
    technicalFallbackOnly: true,
    clinicalEscalationOnly: false,
  }),

  study_fallback_2: Object.freeze({
    targetType: 'backend_model',
    target: 'gemini_31_flash_lite_paid',
    respondsToUser: true,
    technicalFallbackOnly: true,
    clinicalEscalationOnly: false,
  }),

  plantao_router: Object.freeze({
    targetType: 'backend_model',
    target: 'gpt_5_nano',
    respondsToUser: false,
    routerClassifierOnly: true,
    technicalFallbackOnly: false,
    clinicalEscalationOnly: false,
  }),

  plantao_primary: Object.freeze({
    targetType: 'backend_model',
    target: 'gpt_56_luna',
    respondsToUser: true,
    routerClassifierOnly: false,
    technicalFallbackOnly: false,
    clinicalEscalationOnly: false,
  }),

  plantao_cross_provider: Object.freeze({
    targetType: 'backend_model',
    target: 'gemini_31_flash_lite_paid',
    respondsToUser: true,
    routerClassifierOnly: false,
    technicalFallbackOnly: true,
    clinicalEscalationOnly: false,
  }),

  plantao_complex: Object.freeze({
    targetType: 'backend_model',
    target: 'gpt_56_terra',
    respondsToUser: true,
    routerClassifierOnly: false,
    technicalFallbackOnly: false,
    clinicalEscalationOnly: true,
    requiresGuard: 'terra_allowed',
  }),
});

const REGISTRY = Object.freeze({
  gemini_31_flash_lite_free: Object.freeze({
    provider: 'google',
    apiModelName: null,
    bindingState: 'unbound',
    enabled: false,
    capability: ['educational_text'],
    tier: 'free',
    supportsText: true,
    supportsImage: false,
    supportsAudio: false,
    supportsStructuredOutput: true,
    maxContext: null,
    timeoutMs: 45000,
    maxRetries: 1,
    costClass: 'free',
    privacyClass: 'educational_non_identifiable_only',
    identifiableClinicalDataAllowed: false,
    clinicalEscalationOnly: false,
    technicalFallbackAllowed: true,
    respondsToUser: true,
  }),

  gpt_5_nano: Object.freeze({
    provider: 'openai',
    apiModelName: null,
    bindingState: 'unbound',
    enabled: false,
    capability: ['router', 'classification', 'educational_text'],
    tier: 'economy',
    supportsText: true,
    supportsImage: false,
    supportsAudio: false,
    supportsStructuredOutput: true,
    maxContext: null,
    timeoutMs: 20000,
    maxRetries: 1,
    costClass: 'low',
    privacyClass: 'server_approved_clinical',
    identifiableClinicalDataAllowed: true,
    clinicalEscalationOnly: false,
    technicalFallbackAllowed: true,
    respondsToUser: false,
  }),

  gemini_31_flash_lite_paid: Object.freeze({
    provider: 'google',
    apiModelName: null,
    bindingState: 'unbound',
    enabled: false,
    capability: ['clinical_text', 'educational_text'],
    tier: 'paid',
    supportsText: true,
    supportsImage: false,
    supportsAudio: false,
    supportsStructuredOutput: true,
    maxContext: null,
    timeoutMs: 45000,
    maxRetries: 1,
    costClass: 'low',
    privacyClass: 'server_approved_clinical',
    identifiableClinicalDataAllowed: true,
    clinicalEscalationOnly: false,
    technicalFallbackAllowed: true,
    respondsToUser: true,
  }),

  gpt_56_luna: Object.freeze({
    provider: 'openai',
    apiModelName: null,
    bindingState: 'unbound',
    enabled: false,
    capability: ['clinical_reasoning'],
    tier: 'primary_clinical',
    supportsText: true,
    supportsImage: false,
    supportsAudio: false,
    supportsStructuredOutput: true,
    maxContext: null,
    timeoutMs: 45000,
    maxRetries: 1,
    costClass: 'medium',
    privacyClass: 'server_approved_clinical',
    identifiableClinicalDataAllowed: true,
    clinicalEscalationOnly: false,
    technicalFallbackAllowed: true,
    respondsToUser: true,
  }),

  gpt_56_terra: Object.freeze({
    provider: 'openai',
    apiModelName: null,
    bindingState: 'unbound',
    enabled: false,
    capability: ['complex_clinical_reasoning'],
    tier: 'complex_clinical',
    supportsText: true,
    supportsImage: false,
    supportsAudio: false,
    supportsStructuredOutput: true,
    maxContext: null,
    timeoutMs: 55000,
    maxRetries: 0,
    costClass: 'high',
    privacyClass: 'server_approved_clinical',
    identifiableClinicalDataAllowed: true,
    clinicalEscalationOnly: true,
    technicalFallbackAllowed: false,
    respondsToUser: true,
  }),
});

function getModelRegistry() {
  return REGISTRY;
}

module.exports = {
  MODEL_REGISTRY_VERSION,
  VERIFIED_PROVIDER_BINDINGS_VERSION,
  VERIFIED_PROVIDER_BINDINGS,
  EXTERNAL_CLIENT_CAPABILITIES,
  ROUTE_ALIASES,
  getModelRegistry,
};
