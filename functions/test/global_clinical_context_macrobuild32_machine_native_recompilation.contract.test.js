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
assert.strictEqual(bundle.semanticInference, "NONE");

assert.strictEqual(
  bundle.counts.machineClassifications,
  Array.isArray(phase7.classifications)
    ? phase7.classifications.length
    : 0,
);

assert.strictEqual(
  bundle.counts.machineManagement,
  Array.isArray(phase7.managementRules)
    ? phase7.managementRules.length
    : 0,
);

assert.strictEqual(
  bundle.counts.machineActions,
  Array.isArray(phase7.actions)
    ? phase7.actions.length
    : 0,
);

assert.strictEqual(
  bundle.counts.machineContent,
  Array.isArray(phase7.content)
    ? phase7.content.length
    : 0,
);

const expectedLegacyRecords =
  legacyCompatibility.recordsByPathology &&
  typeof legacyCompatibility.recordsByPathology ===
    "object"
    ? Object.keys(
        legacyCompatibility.recordsByPathology,
      ).length
    : 0;

assert.strictEqual(
  bundle.counts.legacyCompatibilityRecords,
  expectedLegacyRecords,
);

const coverage = buildMachineNativeCoverage({
  phase7,
  legacyCompatibility,
});

assert.strictEqual(
  coverage.summary.protocols,
  270,
);

assert.strictEqual(
  coverage.summary.machineClassificationDocs,
  bundle.counts.machineClassifications,
);

assert.strictEqual(
  coverage.summary.machineManagementDocs,
  bundle.counts.machineManagement,
);

assert.strictEqual(
  coverage.summary.machineActionDocs,
  bundle.counts.machineActions,
);

assert.strictEqual(
  coverage.summary.machineContentDocs,
  bundle.counts.machineContent,
);

const plan = buildFirestoreDryRunPlan(bundle);

const expectedOps =
  bundle.counts.identities +
  bundle.counts.protocols +
  bundle.counts.machineClassifications +
  bundle.counts.machineManagement +
  bundle.counts.machineActions +
  bundle.counts.machineContent;

assert.strictEqual(
  plan.counts.totalDryRunOperations,
  expectedOps,
);
assert.strictEqual(
  plan.executionMode,
  "DRYRUN_ONLY",
);
assert.strictEqual(
  plan.firebaseWriteAuthorized,
  false,
);

const readiness = buildShadowReadiness({
  bundle,
  coverage,
  appTransportReady: true,
  backendIdentityProtocolReady: true,
});

assert.strictEqual(
  readiness.shadowActivationAuthorized,
  false,
);
assert.strictEqual(
  readiness.runtimeActivationAuthorized,
  false,
);
assert.strictEqual(
  readiness.visibleCutoverAuthorized,
  false,
);

console.log("MACRO32_CONTRACT_TEST=PASS");
console.log("MACRO32_ASSERTION_GROUPS=24");
console.log(
  "MACRO32_MACHINE_CLASSIFICATIONS="+
  bundle.counts.machineClassifications,
);
console.log(
  "MACRO32_MACHINE_MANAGEMENT="+
  bundle.counts.machineManagement,
);
console.log(
  "MACRO32_MACHINE_ACTIONS="+
  bundle.counts.machineActions,
);
console.log(
  "MACRO32_MACHINE_CONTENT="+
  bundle.counts.machineContent,
);
console.log(
  "MACRO32_LEGACY_COMPAT_RECORDS="+
  bundle.counts.legacyCompatibilityRecords,
);
console.log(
  "MACRO32_FIRESTORE_DRYRUN_OPERATIONS="+
  plan.counts.totalDryRunOperations,
);
console.log(
  "MACRO32_PROTOCOLS_WITH_MACHINE_CLASSIFICATION="+
  coverage.summary.protocolsWithMachineClassification,
);
console.log(
  "MACRO32_PROTOCOLS_WITH_MACHINE_MANAGEMENT="+
  coverage.summary.protocolsWithMachineManagement,
);
console.log(
  "MACRO32_PROTOCOLS_WITH_MACHINE_ACTION="+
  coverage.summary.protocolsWithMachineAction,
);
console.log(
  "MACRO32_PROTOCOLS_WITH_MACHINE_CONTENT="+
  coverage.summary.protocolsWithMachineContent,
);
console.log(
  "MACRO32_SHADOW_ACTIVATION_READY="+
  (readiness.shadowActivationReady ? "YES" : "NO"),
);
console.log(
  "MACRO32_SHADOW_BLOCKER="+
  readiness.blocker,
);
