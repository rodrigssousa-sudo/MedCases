'use strict';

const assert = require('assert');

const {
  validateProtectedClinicalProjectionV1,
  buildProtectedClinicalRouterInputV1,
} = require(
  '../lib/ai_control_plane_v2/protected_clinical_data_policy_v1'
);

const {
  OWNER_VERSION,
  buildServerDeidentifiedClinicalProjectionV1,
} = require(
  '../lib/ai_control_plane_v2/server_deidentified_clinical_projection_owner_v1'
);

assert.strictEqual(
  OWNER_VERSION,
  'server_deidentified_clinical_projection_owner_v1'
);

const RAW_NAME =
  'RAW_PATIENT_NAME_MUST_NEVER_LEAK';

const RAW_PHONE =
  '+54 11 5555 1234';

const RAW_EMAIL =
  'patient@example.invalid';

const RAW_MESSAGE =
  'Dor torácica intensa com dado identificável ' +
  RAW_NAME + ' ' + RAW_PHONE + ' ' + RAW_EMAIL;

const rawHistory = [
  {
    role: 'user',
    content:
      'RAW_HISTORY_SENTINEL ' +
      RAW_NAME,
  },
  {
    role: 'model',
    content:
      'RAW_ASSISTANT_HISTORY_SENTINEL',
  },
];

const rawPatientContext = {
  realPatient: true,
  patientName: RAW_NAME,
  phone: RAW_PHONE,
  email: RAW_EMAIL,
  freeText:
    'RAW_PATIENT_CONTEXT_SENTINEL',
  bloodPressure: '90/60',
  heartRate: 125,
};

const projection =
  buildServerDeidentifiedClinicalProjectionV1({
    mode: 'plantao',
    userMessage: RAW_MESSAGE,
    history: rawHistory,
    patientContext: rawPatientContext,
  });

assert.ok(projection);

assert.strictEqual(
  validateProtectedClinicalProjectionV1(
    projection
  ).valid,
  true
);

assert.strictEqual(
  projection.version,
  'protected_clinical_projection_v1'
);

assert.strictEqual(
  projection.source,
  'server_deidentified_v1'
);

assert.strictEqual(
  projection.containsRawText,
  false
);

assert.strictEqual(
  projection.containsDirectIdentifiers,
  false
);

assert.deepStrictEqual(
  Object.keys(projection).sort(),
  [
    'clinicalIntentTags',
    'complexitySignals',
    'containsDirectIdentifiers',
    'containsRawText',
    'contextMetrics',
    'source',
    'version',
  ].sort()
);

assert.strictEqual(
  projection.contextMetrics.userMessageChars,
  RAW_MESSAGE.length
);

assert.strictEqual(
  projection.contextMetrics.historyTurns,
  2
);

assert.strictEqual(
  projection.contextMetrics.patientContextFieldCount,
  Object.keys(rawPatientContext).length
);

const serialized =
  JSON.stringify(projection);

for (const forbidden of [
  RAW_NAME,
  RAW_PHONE,
  RAW_EMAIL,
  RAW_MESSAGE,
  'RAW_HISTORY_SENTINEL',
  'RAW_ASSISTANT_HISTORY_SENTINEL',
  'RAW_PATIENT_CONTEXT_SENTINEL',
  'patientName',
  'phone',
  'email',
  'bloodPressure',
  'heartRate',
]) {
  assert.strictEqual(
    serialized.includes(forbidden),
    false,
    'projection_must_not_contain_' +
      forbidden
  );
}

const providerInput =
  buildProtectedClinicalRouterInputV1(
    projection
  );

assert.strictEqual(
  typeof providerInput,
  'string'
);

for (const forbidden of [
  RAW_NAME,
  RAW_PHONE,
  RAW_EMAIL,
  RAW_MESSAGE,
  'RAW_HISTORY_SENTINEL',
  'RAW_ASSISTANT_HISTORY_SENTINEL',
  'RAW_PATIENT_CONTEXT_SENTINEL',
]) {
  assert.strictEqual(
    providerInput.includes(forbidden),
    false
  );
}

const emptyProjection =
  buildServerDeidentifiedClinicalProjectionV1();

assert.ok(emptyProjection);
assert.strictEqual(
  validateProtectedClinicalProjectionV1(
    emptyProjection
  ).valid,
  true
);

console.log(
  'SERVER_DERIVED_PROJECTION_OWNER=PASS'
);
console.log(
  'CLIENT_PROJECTION_ACCEPTED=NO'
);
console.log(
  'RAW_CLINICAL_TEXT_IN_PROJECTION=NO'
);
console.log(
  'DIRECT_IDENTIFIERS_IN_PROJECTION=NO'
);
console.log(
  'PROJECTION_SCHEMA_VALID=YES'
);
console.log(
  'PROJECTION_RESPONSE_AUTHORITY=NONE'
);
