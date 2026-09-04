'use strict';

const {
  VERIFIED_PROVIDER_BINDINGS_VERSION,
  VERIFIED_PROVIDER_BINDINGS,
  EXTERNAL_CLIENT_CAPABILITIES,
  ROUTE_ALIASES,
} = require('./model_registry');

const SHADOW_ROUTER_VERSION =
  'AI_NEXT_MODEL_SHADOW_ROUTING_V2_2026_08_28_0001';

const SHADOW_ROUTER_MARKER = '[AI_CONTROL_PLANE_V2_NEXT_MODEL_SHADOW_ROUTE]';

const ALLOWED_PRIVACY_STATES = Object.freeze([
  'educational_non_identifiable',
  'patient_context',
  'sensitive_clinical_context',
  'identifiable_clinical_data',
  'unknown',
]);

function _alias(name) {
  const value = ROUTE_ALIASES[name];
  if (!value) {
    throw new Error(`unknown_route_alias:${name}`);
  }
  return value;
}

function _backendStep(aliasName, reason) {
  const alias = _alias(aliasName);

  if (alias.targetType !== 'backend_model') {
    throw new Error(`alias_not_backend_model:${aliasName}`);
  }

  const binding = VERIFIED_PROVIDER_BINDINGS[alias.target];
  if (!binding || binding.backendExecutable !== true) {
    throw new Error(`verified_backend_binding_missing:${alias.target}`);
  }

  return Object.freeze({
    alias: aliasName,
    targetType: 'backend_model',
    internalModelId: alias.target,
    provider: binding.provider,
    apiModelName: binding.apiModelName,
    activationState: binding.activationState,
    respondsToUser: alias.respondsToUser === true,
    routerClassifierOnly: alias.routerClassifierOnly === true,
    technicalFallbackOnly: alias.technicalFallbackOnly === true,
    clinicalEscalationOnly: alias.clinicalEscalationOnly === true,
    requiresGuard: alias.requiresGuard || null,
    reason,
  });
}

function _externalStep(aliasName, {
  eligible,
  bypassReason,
}) {
  const alias = _alias(aliasName);

  if (alias.targetType !== 'external_client_capability') {
    throw new Error(`alias_not_external_client:${aliasName}`);
  }

  const capability = EXTERNAL_CLIENT_CAPABILITIES[alias.target];
  if (!capability || capability.backendExecutable !== false) {
    throw new Error(`external_client_capability_missing:${alias.target}`);
  }

  return Object.freeze({
    alias: aliasName,
    targetType: 'external_client_capability',
    capability: alias.target,
    executionPlane: capability.executionPlane,
    provider: capability.provider,
    providerModelFamily: capability.providerModelFamily,
    backendExecutable: false,
    backendApiKeyRequired: false,
    personalUserAuthenticationRequired:
      capability.personalUserAuthenticationRequired === true,
    privacyEligible: eligible === true,
    bypassReason: bypassReason || null,
    respondsToUser: true,
  });
}

function _normalizePrivacyState(value) {
  if (typeof value !== 'string') {
    return 'unknown';
  }

  const normalized = value.trim().toLowerCase();

  return ALLOWED_PRIVACY_STATES.includes(normalized)
    ? normalized
    : 'unknown';
}

function planStudyShadowRoute({
  privacyState = 'unknown',
  personalFreeOutcome = 'not_attempted',
} = {}) {
  const privacy = _normalizePrivacyState(privacyState);

  const personalFreeEligible =
    privacy === 'educational_non_identifiable';

  const bypassReason = personalFreeEligible
    ? null
    : privacy === 'patient_context'
      ? 'patient_context'
      : privacy === 'sensitive_clinical_context'
        ? 'sensitive_clinical_context'
        : privacy === 'identifiable_clinical_data'
          ? 'identifiable_clinical_data'
          : 'privacy_not_proven_safe';

  const externalPrimary = _externalStep('study_primary', {
    eligible: personalFreeEligible,
    bypassReason,
  });

  const backendFallbackChain = Object.freeze([
    _backendStep(
      'study_fallback_1',
      personalFreeEligible
        ? `personal_free_${personalFreeOutcome}`
        : `personal_free_bypassed_${bypassReason}`
    ),
    _backendStep(
      'study_fallback_2',
      'technical_fallback_after_study_fallback_1'
    ),
  ]);

  return Object.freeze({
    shadowRouterVersion: SHADOW_ROUTER_VERSION,
    bindingSetVersion: VERIFIED_PROVIDER_BINDINGS_VERSION,
    mode: 'study',
    privacyState: privacy,
    personalFreeEligible,
    personalFreeOutcome,
    externalPrimary,
    backendFallbackChain,
    liveExecutionAllowed: false,
    providerInferencePerformed: false,
    shadowOnly: true,
  });
}

function planPlantaoShadowRoute({
  technicalFailure = false,
  clinicalEscalation = false,
  terraAllowed = false,
} = {}) {
  const router = _backendStep(
    'plantao_router',
    'router_classifier'
  );

  const primary = _backendStep(
    'plantao_primary',
    'primary_clinical_answer'
  );

  const technicalFallback = technicalFailure === true
    ? _backendStep(
        'plantao_cross_provider',
        'technical_failure_cross_provider'
      )
    : null;

  const complexEscalation =
    clinicalEscalation === true && terraAllowed === true
      ? _backendStep(
          'plantao_complex',
          'clinical_complexity_escalation'
        )
      : null;

  const escalationBlockedReason =
    clinicalEscalation === true && terraAllowed !== true
      ? 'terra_guard_closed'
      : null;

  return Object.freeze({
    shadowRouterVersion: SHADOW_ROUTER_VERSION,
    bindingSetVersion: VERIFIED_PROVIDER_BINDINGS_VERSION,
    mode: 'plantao',
    router,
    primary,
    technicalFallback,
    complexEscalation,
    escalationBlockedReason,
    technicalFallbackAndClinicalEscalationSeparated: true,
    routerMayRespondToUser: false,
    liveExecutionAllowed: false,
    providerInferencePerformed: false,
    shadowOnly: true,
  });
}

function buildNextModelShadowTelemetry(plan) {
  if (!plan || typeof plan !== 'object') {
    throw new TypeError('shadow_plan_required');
  }

  if (plan.shadowOnly !== true || plan.liveExecutionAllowed !== false) {
    throw new Error('shadow_plan_must_be_inert');
  }

  if (plan.mode === 'study') {
    return Object.freeze({
      marker: SHADOW_ROUTER_MARKER,
      shadowRouterVersion: plan.shadowRouterVersion,
      bindingSetVersion: plan.bindingSetVersion,
      mode: 'study',
      personalFreeEligible: plan.personalFreeEligible,
      personalFreeBypassReason:
        plan.externalPrimary.bypassReason,
      fallback1Alias:
        plan.backendFallbackChain[0].alias,
      fallback1Provider:
        plan.backendFallbackChain[0].provider,
      fallback1Model:
        plan.backendFallbackChain[0].apiModelName,
      fallback2Alias:
        plan.backendFallbackChain[1].alias,
      fallback2Provider:
        plan.backendFallbackChain[1].provider,
      fallback2Model:
        plan.backendFallbackChain[1].apiModelName,
      liveExecutionAllowed: false,
      providerInferencePerformed: false,
      shadowOnly: true,
    });
  }

  if (plan.mode === 'plantao') {
    return Object.freeze({
      marker: SHADOW_ROUTER_MARKER,
      shadowRouterVersion: plan.shadowRouterVersion,
      bindingSetVersion: plan.bindingSetVersion,
      mode: 'plantao',
      routerAlias: plan.router.alias,
      routerProvider: plan.router.provider,
      routerModel: plan.router.apiModelName,
      routerMayRespondToUser: false,
      primaryAlias: plan.primary.alias,
      primaryProvider: plan.primary.provider,
      primaryModel: plan.primary.apiModelName,
      technicalFallbackAlias:
        plan.technicalFallback
          ? plan.technicalFallback.alias
          : null,
      complexEscalationAlias:
        plan.complexEscalation
          ? plan.complexEscalation.alias
          : null,
      escalationBlockedReason:
        plan.escalationBlockedReason,
      liveExecutionAllowed: false,
      providerInferencePerformed: false,
      shadowOnly: true,
    });
  }

  throw new Error(`unsupported_shadow_mode:${plan.mode}`);
}

module.exports = {
  SHADOW_ROUTER_VERSION,
  SHADOW_ROUTER_MARKER,
  planStudyShadowRoute,
  planPlantaoShadowRoute,
  buildNextModelShadowTelemetry,
};
