'use strict';

const assert=require('assert');

const {
  buildOpenAiProtectedClinicalDataPolicyFromEnv,
  classifyClinicalDataSensitivity,
  validateProtectedClinicalProjectionV1,
  evaluateProtectedClinicalProviderGate,
  buildProtectedClinicalRouterInputV1,
}=require('../lib/ai_control_plane_v2/protected_clinical_data_policy_v1');

const closed=
  buildOpenAiProtectedClinicalDataPolicyFromEnv({});

assert.strictEqual(closed.ready,false);
assert.strictEqual(closed.processingAttested,false);
assert.strictEqual(closed.realPatientShadowAllowed,false);
assert.strictEqual(closed.source,'server_env_v1');

const partial=
  buildOpenAiProtectedClinicalDataPolicyFromEnv({
    AI_OPENAI_PROTECTED_CLINICAL_PROCESSING_ATTESTED:'true',
  });

assert.strictEqual(partial.ready,false);

const open=
  buildOpenAiProtectedClinicalDataPolicyFromEnv({
    AI_OPENAI_PROTECTED_CLINICAL_PROCESSING_ATTESTED:'true',
    AI_GPT5_NANO_REAL_PATIENT_SHADOW_ALLOWED:'true',
  });

assert.strictEqual(open.ready,true);

assert.strictEqual(
  classifyClinicalDataSensitivity({
    patientContext:{
      synthetic:true,
      realPatient:false,
    },
  }),
  'synthetic_non_patient'
);

assert.strictEqual(
  classifyClinicalDataSensitivity({
    patientContext:null,
  }),
  'potential_real_patient'
);

assert.strictEqual(
  classifyClinicalDataSensitivity({
    patientContext:{
      synthetic:true,
      realPatient:true,
    },
  }),
  'potential_real_patient'
);

const projection={
  version:'protected_clinical_projection_v1',
  source:'server_deidentified_v1',
  containsRawText:false,
  containsDirectIdentifiers:false,
  clinicalIntentTags:[
    'acute_care',
    'cardiology',
  ],
  complexitySignals:[
    'multi_step_reasoning',
  ],
  contextMetrics:{
    userMessageChars:320,
    historyTurns:4,
    patientContextFieldCount:8,
  },
};

assert.strictEqual(
  validateProtectedClinicalProjectionV1(projection).valid,
  true
);

assert.strictEqual(
  validateProtectedClinicalProjectionV1({
    ...projection,
    clinicalIntentTags:[
      'patient name must never be accepted here',
    ],
  }).valid,
  false
);

assert.strictEqual(
  validateProtectedClinicalProjectionV1({
    ...projection,
    rawText:'forbidden',
  }).valid,
  false
);

assert.strictEqual(
  evaluateProtectedClinicalProviderGate({
    patientContext:null,
    providerDataPolicy:null,
    protectedClinicalProjection:null,
  }).allowed,
  false
);

assert.strictEqual(
  evaluateProtectedClinicalProviderGate({
    patientContext:null,
    providerDataPolicy:closed,
    protectedClinicalProjection:projection,
  }).allowed,
  false
);

const allowed=
  evaluateProtectedClinicalProviderGate({
    patientContext:null,
    providerDataPolicy:open,
    protectedClinicalProjection:projection,
  });

assert.strictEqual(allowed.allowed,true);
assert.strictEqual(allowed.useProtectedProjection,true);

const providerInput=
  buildProtectedClinicalRouterInputV1(projection);

assert.ok(providerInput.includes('acute_care'));
assert.ok(providerInput.includes('multi_step_reasoning'));
assert.ok(!providerInput.includes('patient name'));

console.log('PROTECTED_POLICY_ENV_DEFAULT_DENY=PASS');
console.log('PROTECTED_POLICY_TWO_SERVER_ATTESTATIONS_REQUIRED=PASS');
console.log('PROTECTED_PROJECTION_STRICT_ALLOWLIST=PASS');
console.log('PROTECTED_PROJECTION_FREE_TEXT_REJECTED=PASS');
console.log('PROTECTED_PROJECTION_DIRECT_IDENTIFIER_ATTESTATION_REQUIRED=PASS');
console.log('PROTECTED_CLINICAL_DATA_POLICY_V1_CONTRACT=PASS');
