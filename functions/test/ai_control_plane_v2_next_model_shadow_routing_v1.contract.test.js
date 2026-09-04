'use strict';

const assert = require('assert');

const {
  VERIFIED_PROVIDER_BINDINGS,
  EXTERNAL_CLIENT_CAPABILITIES,
  ROUTE_ALIASES,
} = require('../lib/ai_control_plane_v2/model_registry');

const {
  planStudyShadowRoute,
  planPlantaoShadowRoute,
  buildNextModelShadowTelemetry,
} = require('../lib/ai_control_plane_v2/next_model_shadow_routing_v1');

// Provider IDs verified but not activated.
assert.strictEqual(
  VERIFIED_PROVIDER_BINDINGS.gpt_5_nano.apiModelName,
  'gpt-5-nano'
);
assert.strictEqual(
  VERIFIED_PROVIDER_BINDINGS.gpt_56_luna.apiModelName,
  'gpt-5.6-luna'
);
assert.strictEqual(
  VERIFIED_PROVIDER_BINDINGS.gpt_56_terra.apiModelName,
  'gpt-5.6-terra'
);
assert.strictEqual(
  VERIFIED_PROVIDER_BINDINGS.gemini_31_flash_lite_paid.apiModelName,
  'gemini-3.1-flash-lite'
);

for (const binding of Object.values(VERIFIED_PROVIDER_BINDINGS)) {
  assert.strictEqual(binding.activationState, 'shadow_verified');
  assert.strictEqual(binding.backendExecutable, true);
}

// Personal Gemini FREE is external client capability, never a backend key.
const personalFree =
  EXTERNAL_CLIENT_CAPABILITIES.study_personal_gemini_free;

assert.strictEqual(
  personalFree.executionPlane,
  'client_personal_account'
);
assert.strictEqual(personalFree.backendExecutable, false);
assert.strictEqual(personalFree.backendApiKeyRequired, false);
assert.strictEqual(
  personalFree.personalUserAuthenticationRequired,
  true
);
assert.strictEqual(
  personalFree.identifiableClinicalDataAllowed,
  false
);
assert.strictEqual(personalFree.patientContextAllowed, false);
assert.strictEqual(
  personalFree.sensitiveClinicalContextAllowed,
  false
);

// Role semantics: same gpt-5-nano, different answer authority.
assert.strictEqual(
  ROUTE_ALIASES.study_fallback_1.target,
  'gpt_5_nano'
);
assert.strictEqual(
  ROUTE_ALIASES.study_fallback_1.respondsToUser,
  true
);
assert.strictEqual(
  ROUTE_ALIASES.plantao_router.target,
  'gpt_5_nano'
);
assert.strictEqual(
  ROUTE_ALIASES.plantao_router.respondsToUser,
  false
);
assert.strictEqual(
  ROUTE_ALIASES.plantao_router.routerClassifierOnly,
  true
);

// Study educational/non-identifiable may use personal free first.
const studySafe = planStudyShadowRoute({
  privacyState: 'educational_non_identifiable',
  personalFreeOutcome: 'failed',
});

assert.strictEqual(studySafe.personalFreeEligible, true);
assert.strictEqual(
  studySafe.externalPrimary.executionPlane,
  'client_personal_account'
);
assert.strictEqual(
  studySafe.backendFallbackChain[0].apiModelName,
  'gpt-5-nano'
);
assert.strictEqual(
  studySafe.backendFallbackChain[0].respondsToUser,
  true
);
assert.strictEqual(
  studySafe.backendFallbackChain[1].apiModelName,
  'gemini-3.1-flash-lite'
);

// Real/sensitive/identifiable patient content must bypass personal free.
for (const privacyState of [
  'patient_context',
  'sensitive_clinical_context',
  'identifiable_clinical_data',
  'unknown',
]) {
  const plan = planStudyShadowRoute({
    privacyState,
    personalFreeOutcome: 'not_attempted',
  });

  assert.strictEqual(plan.personalFreeEligible, false);
  assert.ok(plan.externalPrimary.bypassReason);
  assert.strictEqual(
    plan.backendFallbackChain[0].apiModelName,
    'gpt-5-nano'
  );
}

// Plantao nano router cannot be final answer.
const plantaoBase = planPlantaoShadowRoute();
assert.strictEqual(
  plantaoBase.router.apiModelName,
  'gpt-5-nano'
);
assert.strictEqual(plantaoBase.router.respondsToUser, false);
assert.strictEqual(plantaoBase.routerMayRespondToUser, false);
assert.strictEqual(
  plantaoBase.primary.apiModelName,
  'gpt-5.6-luna'
);

// Technical fallback is Gemini paid, not Terra.
const plantaoTechnical = planPlantaoShadowRoute({
  technicalFailure: true,
  clinicalEscalation: false,
  terraAllowed: false,
});

assert.strictEqual(
  plantaoTechnical.technicalFallback.apiModelName,
  'gemini-3.1-flash-lite'
);
assert.strictEqual(
  plantaoTechnical.complexEscalation,
  null
);

// Terra is clinical escalation only and guard-protected.
const blockedTerra = planPlantaoShadowRoute({
  technicalFailure: false,
  clinicalEscalation: true,
  terraAllowed: false,
});

assert.strictEqual(blockedTerra.complexEscalation, null);
assert.strictEqual(
  blockedTerra.escalationBlockedReason,
  'terra_guard_closed'
);

const allowedTerra = planPlantaoShadowRoute({
  technicalFailure: false,
  clinicalEscalation: true,
  terraAllowed: true,
});

assert.strictEqual(
  allowedTerra.complexEscalation.apiModelName,
  'gpt-5.6-terra'
);
assert.strictEqual(
  allowedTerra.complexEscalation.clinicalEscalationOnly,
  true
);
assert.strictEqual(
  allowedTerra.complexEscalation.requiresGuard,
  'terra_allowed'
);

// Even if both conditions are true, technical fallback and clinical
// escalation remain distinct fields / mechanisms.
const both = planPlantaoShadowRoute({
  technicalFailure: true,
  clinicalEscalation: true,
  terraAllowed: true,
});

assert.strictEqual(
  both.technicalFallback.apiModelName,
  'gemini-3.1-flash-lite'
);
assert.strictEqual(
  both.complexEscalation.apiModelName,
  'gpt-5.6-terra'
);
assert.strictEqual(
  both.technicalFallbackAndClinicalEscalationSeparated,
  true
);

// Shadow telemetry contains routing metadata only.
const telemetry = buildNextModelShadowTelemetry(studySafe);
const serialized = JSON.stringify(telemetry);

for (const forbidden of [
  'uid',
  'userMessage',
  'systemPrompt',
  'history',
  'patientName',
  'email',
  'accessToken',
  'apiKey',
]) {
  assert.strictEqual(
    serialized.toLowerCase().includes(forbidden.toLowerCase()),
    false
  );
}

assert.strictEqual(telemetry.liveExecutionAllowed, false);
assert.strictEqual(telemetry.providerInferencePerformed, false);
assert.strictEqual(telemetry.shadowOnly, true);

console.log('AI_CONTROL_PLANE_V2_NEXT_MODEL_SHADOW_ROUTING=PASS');
console.log('OFFICIAL_PROVIDER_IDS_STAGED_SHADOW_ONLY=PASS');
console.log('PERSONAL_GEMINI_FREE_EXTERNAL_CLIENT_CAPABILITY=PASS');
console.log('PERSONAL_GEMINI_FREE_BACKEND_API_KEY_REQUIRED=NO');
console.log('STUDY_PERSONAL_FREE_PRIVACY_BYPASS=PASS');
console.log('STUDY_FALLBACK_1_GPT5_NANO_RESPONDS_TO_USER=PASS');
console.log('STUDY_FALLBACK_2_GEMINI_PAID=PASS');
console.log('PLANTAO_GPT5_NANO_ROUTER_ONLY_NO_FINAL_ANSWER=PASS');
console.log('PLANTAO_LUNA_PRIMARY=PASS');
console.log('PLANTAO_GEMINI_PAID_TECHNICAL_FALLBACK=PASS');
console.log('PLANTAO_TERRA_CLINICAL_ESCALATION_GUARDED=PASS');
console.log('TECHNICAL_FALLBACK_CLINICAL_ESCALATION_SEPARATED=PASS');
console.log('SHADOW_TELEMETRY_METADATA_ONLY=PASS');
console.log('LIVE_PROVIDER_EXECUTION_CHANGED=NO');
