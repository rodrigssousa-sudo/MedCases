"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  createShadowObservationCanaryRuntime,
} = require(
  "../clinical_context/clinical_shadow_observation_canary_runtime",
);

const payload = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_firestore_write_payload.phase13.local.json",
    "utf8",
  ),
);

const batches = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_firestore_write_batches.phase13.local.json",
    "utf8",
  ),
);

const plan = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_shadow_observation_canary_plan.phase13.local.json",
    "utf8",
  ),
);

const callsites = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_shadow_observation_callsite_plan.phase13.local.json",
    "utf8",
  ),
);

assert.strictEqual(
  payload.executionMode,
  "PREPARED_NOT_AUTHORIZED",
);
assert.strictEqual(
  payload.firebaseWriteAuthorized,
  false,
);
assert.strictEqual(
  payload.counts.totalOperations,
  1268,
);
assert.strictEqual(payload.counts.identities, 270);
assert.strictEqual(payload.counts.protocols, 270);
assert.strictEqual(payload.counts.actions, 364);
assert.strictEqual(payload.counts.content, 364);
assert.strictEqual(payload.counts.classifications, 0);
assert.strictEqual(payload.counts.managementRules, 0);

assert.strictEqual(batches.batchCount, 4);
assert.strictEqual(batches.totalOperations, 1268);
assert.deepStrictEqual(
  batches.batches.map((x) => x.operationCount),
  [400, 400, 400, 68],
);

for (const batch of batches.batches) {
  assert(batch.operationCount < 500);
  assert.match(
    batch.operationsSha256,
    /^[a-f0-9]{64}$/,
  );
}

assert.strictEqual(callsites.handlers.length, 3);
assert.strictEqual(callsites.patchAuthorized, false);
assert.strictEqual(
  callsites.shadowObservationAuthorized,
  false,
);

assert.strictEqual(
  plan.mode,
  "NONVISIBLE_OBSERVATION_ONLY",
);
assert.strictEqual(
  plan.activationAuthorized,
  false,
);
assert.strictEqual(
  plan.patientTextAllowedInObservation,
  false,
);
assert.strictEqual(
  plan.stages.length,
  5,
);

const cloudStages = plan.stages.filter(
  (x) => x.requiresCloudWrite,
);
assert.strictEqual(cloudStages.length, 4);
assert(
  cloudStages.every(
    (x) => x.authorized === false,
  ),
);

assert.strictEqual(
  plan.zeroToleranceStopGates.identityMismatch,
  0,
);
assert.strictEqual(
  plan.zeroToleranceStopGates.protocolMismatch,
  0,
);
assert.strictEqual(
  plan.zeroToleranceStopGates.missingMachineAction,
  0,
);
assert.strictEqual(
  plan.zeroToleranceStopGates.missingMachineContent,
  0,
);
assert.strictEqual(
  plan.zeroToleranceStopGates.visibleMutation,
  0,
);
assert.strictEqual(
  plan.zeroToleranceStopGates.providerCallsFromObserver,
  0,
);
assert.strictEqual(
  plan.zeroToleranceStopGates.patientTextCaptured,
  0,
);

const runtime =
  createShadowObservationCanaryRuntime();

const disabled = runtime.observe({
  requestId: "synthetic",
  protocolKey:
    "legacy_protocol::agitacao_psicomotora",
  canonicalPathologyKey:
    "agitacao_psicomotora",
  userMessage:
    "THIS_MUST_NEVER_BE_CAPTURED",
});

assert.strictEqual(disabled.observed, false);
assert.strictEqual(
  disabled.reason,
  "shadow_observation_disabled",
);
assert.strictEqual(disabled.providerCalls, 0);
assert.strictEqual(disabled.firebaseReads, 0);
assert.strictEqual(
  disabled.visibleMutation,
  false,
);

assert.throws(
  () =>
    createShadowObservationCanaryRuntime({
      shadowObservationEnabled: true,
    }),
  /activation_not_authorized/,
);

assert.throws(
  () =>
    createShadowObservationCanaryRuntime({
      providerExecutionEnabled: true,
    }),
  /provider_execution_not_authorized/,
);

const sanitized =
  runtime.sanitizeObservation({
    requestIdHash: "hash",
    protocolKey:
      "legacy_protocol::agitacao_psicomotora",
    canonicalPathologyKey:
      "agitacao_psicomotora",
    identityResolved: true,
    protocolResolved: true,
    machineActionReady: true,
    machineContentReady: true,
    userMessage: "DO_NOT_INCLUDE",
    prompt: "DO_NOT_INCLUDE",
    history: ["DO_NOT_INCLUDE"],
  });

assert.strictEqual(
  Object.prototype.hasOwnProperty.call(
    sanitized,
    "userMessage",
  ),
  false,
);
assert.strictEqual(
  Object.prototype.hasOwnProperty.call(
    sanitized,
    "prompt",
  ),
  false,
);
assert.strictEqual(
  Object.prototype.hasOwnProperty.call(
    sanitized,
    "history",
  ),
  false,
);

console.log("MACRO36_CONTRACT_TEST=PASS");
console.log("MACRO36_ASSERTION_GROUPS=42");
console.log("MACRO36_FIRESTORE_PAYLOAD_OPERATIONS=1268");
console.log("MACRO36_FIRESTORE_BATCHES=4");
console.log("MACRO36_FIRESTORE_BATCH_SIZES=400,400,400,68");
console.log("MACRO36_CALLSITE_PLAN_HANDLERS=3");
console.log("MACRO36_CANARY_STAGES=5");
console.log("MACRO36_CLOUD_CANARY_STAGES_AUTHORIZED=0");
console.log("MACRO36_PATIENT_TEXT_CAPTURE=NONE");
console.log("MACRO36_PROVIDER_CALLS=0");
console.log("MACRO36_VISIBLE_MUTATION=NO");
console.log("MACRO36_SHADOW_OBSERVATION_ACTIVATION=NO");
console.log("MACRO36_VISIBLE_CUTOVER=NO");
