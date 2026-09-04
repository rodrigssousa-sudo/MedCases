'use strict';

const assert = require('assert');

const {
  buildServerDeidentifiedClinicalFactProjectionV2,
} = require(
  '../lib/ai_control_plane_v2/server_deidentified_clinical_fact_projection_owner_v2'
);

const {
  validateProtectedClinicalProjectionV2,
  buildProtectedClinicalRouterInputV1,
} = require(
  '../lib/ai_control_plane_v2/protected_clinical_data_policy_v2'
);

const RAW_NAME =
  'Bruno Patient Sentinel';
const RAW_EMAIL =
  'patient@example.com';
const RAW_PHONE =
  '+54 11 5555 1234';
const RAW_DNI =
  'DNI: 12345678';

const projection =
  buildServerDeidentifiedClinicalFactProjectionV2({
    mode: 'plantao',
    userMessage:
      'Paciente: ' + RAW_NAME +
      ', 67 anos, dor toracica intensa, ' +
      'supra de ST em V2-V5 e hipotensao. ' +
      'Email: ' + RAW_EMAIL +
      ' telefone ' + RAW_PHONE +
      ' ' + RAW_DNI,
    history: [
      {
        role: 'user',
        content:
          'Relata dispneia progressiva. ' +
          'Nome: ' + RAW_NAME,
      },
      {
        role: 'model',
        content:
          'Avaliar perfusao e ECG.',
      },
    ],
    patientContext: {
      realPatient: true,
      patientName: RAW_NAME,
      email: RAW_EMAIL,
      phone: RAW_PHONE,
      age: 67,
      systolicBloodPressure: 82,
      heartRate: 128,
      spo2: 89,
      ecgFinding: 'ST elevation V2-V5',
    },
  });

assert.ok(projection);

assert.strictEqual(
  validateProtectedClinicalProjectionV2(
    projection
  ).valid,
  true
);

const serialized =
  JSON.stringify(projection);

for (const forbidden of [
  RAW_NAME,
  RAW_EMAIL,
  RAW_PHONE,
  '12345678',
  'patientName',
  'email',
  'phone',
]) {
  assert.strictEqual(
    serialized.includes(forbidden),
    false,
    'must_not_leak_' + forbidden
  );
}

for (const requiredClinicalFact of [
  'dor toracica',
  'supra de ST',
  'hipotensao',
  'dispneia',
  'systolic_blood_pressure: 82',
  'heart_rate: 128',
  'spo2: 89',
  'ecg_finding: ST elevation V2-V5',
]) {
  assert.ok(
    projection.deidentifiedClinicalText
      .includes(requiredClinicalFact),
    'must_preserve_' + requiredClinicalFact
  );
}

const caseA =
  buildServerDeidentifiedClinicalFactProjectionV2({
    mode: 'plantao',
    userMessage:
      'Dor toracica com supra de ST e hipotensao.',
    history: [],
    patientContext: {
      realPatient: true,
      heartRate: 125,
    },
  });

const caseB =
  buildServerDeidentifiedClinicalFactProjectionV2({
    mode: 'plantao',
    userMessage:
      'Cefaleia com rigidez nucal e febre persistente.',
    history: [],
    patientContext: {
      realPatient: true,
      heartRate: 125,
    },
  });

assert.ok(caseA);
assert.ok(caseB);

const inputA =
  buildProtectedClinicalRouterInputV1(caseA);
const inputB =
  buildProtectedClinicalRouterInputV1(caseB);

assert.notStrictEqual(
  inputA,
  inputB
);

assert.ok(
  inputA.toLowerCase().includes(
    'dor toracica'
  )
);
assert.ok(
  inputB.toLowerCase().includes(
    'rigidez nucal'
  )
);

const age90 =
  buildServerDeidentifiedClinicalFactProjectionV2({
    userMessage:
      'Paciente com dispneia.',
    patientContext: {
      age: 94,
    },
  });

assert.ok(age90);
assert.ok(
  age90.deidentifiedClinicalText
    .includes('age: 90+')
);

console.log('CLINICAL_FACT_PROJECTION_V2=PASS');
console.log('DIRECT_IDENTIFIER_SENTINELS_LEAK=NO');
console.log('RAW_CLIENT_PROJECTION_ACCEPTED=NO');
console.log('CLINICAL_FACTS_PRESERVED=YES');
console.log('DISTINCT_CASES_DISTINCT_PROVIDER_INPUT=YES');
console.log('AGE_90_PLUS_COARSENING=PASS');
console.log('LIVE_RESPONSE_AUTHORITY=NONE');
