'use strict';

const assert = require('assert');

const base = require(
  '../lib/ai_control_plane_v2/protected_clinical_data_policy_v1'
);

const v2 = require(
  '../lib/ai_control_plane_v2/protected_clinical_data_policy_v2'
);

const v1Projection = {
  version: 'protected_clinical_projection_v1',
  source: 'server_deidentified_v1',
  containsRawText: false,
  containsDirectIdentifiers: false,
  clinicalIntentTags: ['acute_care'],
  complexitySignals: ['multi_step_reasoning'],
  contextMetrics: {
    userMessageChars: 100,
    historyTurns: 2,
    patientContextFieldCount: 4,
  },
};

assert.deepStrictEqual(
  v2.validateProtectedClinicalProjectionV1(
    v1Projection
  ),
  base.validateProtectedClinicalProjectionV1(
    v1Projection
  )
);

const projectionV2 = {
  version:
    'protected_clinical_fact_projection_v2',
  source: 'server_deidentified_v2',
  deidentificationVersion:
    'medcases_server_deidentification_v2',
  containsRawText: false,
  containsDirectIdentifiers: false,
  deidentifiedClinicalText:
    'current_query: dor toracica com supra de ST e hipotensao',
  clinicalIntentTags: ['acute_care'],
  complexitySignals: ['multi_step_reasoning'],
  contextMetrics: {
    userMessageChars: 52,
    historyTurns: 2,
    patientContextFieldCount: 3,
  },
};

assert.strictEqual(
  v2.validateProtectedClinicalProjectionV2(
    projectionV2
  ).valid,
  true
);

for (const invalidText of [
  'email: patient@example.com',
  'phone: +54 11 5555 1234',
  'https://example.com/patient',
]) {
  assert.strictEqual(
    v2.validateProtectedClinicalProjectionV2({
      ...projectionV2,
      deidentifiedClinicalText:
        invalidText,
    }).valid,
    false
  );
}

const input =
  v2.buildProtectedClinicalRouterInputV1(
    projectionV2
  );

assert.ok(
  input.includes(
    'dor toracica com supra de ST e hipotensao'
  )
);

assert.ok(
  input.includes(
    'MEDCASES_PROTECTED_CLINICAL_INPUT_V2'
  )
);

const invalidLegacyProjection = {
  ...v1Projection,
  containsRawText: true,
};

assert.strictEqual(
  v2.buildProtectedClinicalRouterInputSafeV2(
    invalidLegacyProjection
  ),
  null
);

assert.strictEqual(
  v2.buildProtectedClinicalRouterInputSafeV2(
    {
      ...projectionV2,
      deidentifiedClinicalText:
        'email: patient@example.com',
    }
  ),
  null
);

console.log('POLICY_V2_SAFE_BUILDER_INVALID_V1_FAILCLOSED=PASS');
console.log('POLICY_V2_SAFE_BUILDER_INVALID_V2_FAILCLOSED=PASS');
console.log('POLICY_V2_V1_BACKWARD_COMPATIBILITY=PASS');
console.log('POLICY_V2_STRICT_SCHEMA=PASS');
console.log('POLICY_V2_RESIDUAL_IDENTIFIER_GUARD=PASS');
console.log('POLICY_V2_CLINICAL_FACT_INPUT=PASS');
