"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  compileRemoteRegistryBundle,
  buildMachineNativeCoverage,
  buildFirestoreDryRunPlan,
  buildShadowReadiness,
} = require(
  "../clinical_context/clinical_remote_registry_bundle_compiler",
);

const phase7 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase7_legacy_compatibility.local.json",
    "utf8",
  ),
);

const legacyCompatibility = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_legacy_remote_compatibility.local.json",
    "utf8",
  ),
);

const bundle = compileRemoteRegistryBundle({
  phase7,
  legacyCompatibility,
});

assert.strictEqual(bundle.counts.identities, 270);
assert.strictEqual(bundle.counts.protocols, 270);

assert.strictEqual(
  bundle.counts.machineClassifications,
  0,
);
assert.strictEqual(
  bundle.counts.machineManagement,
  0,
);
assert.strictEqual(
  bundle.counts.machineActions,
  0,
);
assert.strictEqual(
  bundle.counts.machineContent,
  0,
);

assert.strictEqual(bundle.semanticInference, "NONE");

const coverage = buildMachineNativeCoverage({
  phase7,
  legacyCompatibility,
});

assert.strictEqual(coverage.summary.protocols, 270);
assert.strictEqual(
  coverage.summary.machineClassificationReady,
  0,
);
assert.strictEqual(
  coverage.summary.machineManagementReady,
  0,
);
assert.strictEqual(
  coverage.summary.machineActionReady,
  0,
);
assert.strictEqual(
  coverage.summary.machineContentReady,
  0,
);

const plan = buildFirestoreDryRunPlan(bundle);

assert.strictEqual(plan.executionMode, "DRYRUN_ONLY");
assert.strictEqual(
  plan.firebaseWriteAuthorized,
  false,
);
assert.strictEqual(plan.deployAuthorized, false);
assert.strictEqual(
  plan.remoteConfigWriteAuthorized,
  false,
);
assert.strictEqual(
  plan.counts.totalDryRunOperations,
  540,
);

for (const op of plan.operations) {
  assert.strictEqual(op.operation, "UPSERT_DRYRUN");
  assert(
    op.logicalCollection === "identities" ||
    op.logicalCollection === "protocols",
  );
  assert.match(op.dataSha256, /^[a-f0-9]{64}$/);
}

const readiness = buildShadowReadiness({
  bundle,
  appTransportReady: true,
  backendIdentityProtocolReady: true,
});

assert.strictEqual(
  readiness.appStructuredIdentityTransportReady,
  true,
);
assert.strictEqual(
  readiness.backendIdentityProtocolReady,
  true,
);
assert.strictEqual(
  readiness.remoteIdentityRegistryReady,
  true,
);
assert.strictEqual(
  readiness.remoteProtocolRegistryReady,
  true,
);
assert.strictEqual(
  readiness.machineNativeComplete,
  false,
);
assert.strictEqual(
  readiness.shadowActivationReady,
  false,
);
assert.strictEqual(
  readiness.shadowActivationAuthorized,
  false,
);

console.log("MACRO31_CONTRACT_TEST=PASS");
console.log("MACRO31_ASSERTION_GROUPS=28");
console.log("MACRO31_IDENTITIES=270");
console.log("MACRO31_PROTOCOLS=270");
console.log(
  "MACRO31_FIRESTORE_DRYRUN_OPERATIONS=540",
);
console.log(
  "MACRO31_MACHINE_CLASSIFICATIONS=0",
);
console.log(
  "MACRO31_MACHINE_MANAGEMENT=0",
);
console.log(
  "MACRO31_MACHINE_ACTIONS=0",
);
console.log(
  "MACRO31_MACHINE_CONTENT=0",
);
console.log("MACRO31_SEMANTIC_INFERENCE=NONE");
console.log("MACRO31_SHADOW_ACTIVATION_READY=NO");
