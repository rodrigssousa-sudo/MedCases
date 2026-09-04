"use strict";

const assert = require("assert");
const fs = require("fs");

const schema = require(
  "../clinical_context/clinical_registry_schema",
);
const {
  compileMassGapfill,
} = require(
  "../clinical_context/clinical_machine_native_mass_gapfill_compiler",
);
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

const gapfill = compileMassGapfill({
  phase7,
  legacyCompatibility,
  schema,
});

assert.strictEqual(
  gapfill.supplement.semanticInference,
  "NONE",
);
assert.strictEqual(
  gapfill.gapManifest.summary.protocols,
  270,
);

const bundle = compileRemoteRegistryBundle({
  phase7,
  legacyCompatibility,
  machineNativeSupplement:
    gapfill.supplement,
});

assert.strictEqual(bundle.counts.identities, 270);
assert.strictEqual(bundle.counts.protocols, 270);

assert.strictEqual(
  bundle.counts.machineClassifications,
  gapfill.supplement.classifications.length,
);
assert.strictEqual(
  bundle.counts.machineManagement,
  gapfill.supplement.managementRules.length,
);
assert.strictEqual(
  bundle.counts.machineActions,
  gapfill.supplement.actions.length,
);
assert.strictEqual(
  bundle.counts.machineContent,
  gapfill.supplement.content.length,
);

const coverage = buildMachineNativeCoverage({
  phase7,
  legacyCompatibility,
  machineNativeSupplement:
    gapfill.supplement,
});

assert.strictEqual(
  coverage.summary.protocols,
  270,
);

const plan = buildFirestoreDryRunPlan(bundle);

const expectedOps =
  540 +
  bundle.counts.machineClassifications +
  bundle.counts.machineManagement +
  bundle.counts.machineActions +
  bundle.counts.machineContent;

assert.strictEqual(
  plan.counts.totalDryRunOperations,
  expectedOps,
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

for (const doc of [
  ...gapfill.supplement.classifications,
  ...gapfill.supplement.managementRules,
  ...gapfill.supplement.actions,
  ...gapfill.supplement.content,
]) {
  assert(
    doc.evidence ||
    gapfill.evidence.accepted.some(
      (item) => item.id === doc.id,
    ),
  );
}

console.log("MACRO33_CONTRACT_TEST=PASS");
console.log("MACRO33_ASSERTION_GROUPS=24");
console.log(
  "MACRO33_COMPILED_CLASSIFICATIONS="+
  gapfill.supplement.classifications.length,
);
console.log(
  "MACRO33_COMPILED_MANAGEMENT="+
  gapfill.supplement.managementRules.length,
);
console.log(
  "MACRO33_COMPILED_ACTIONS="+
  gapfill.supplement.actions.length,
);
console.log(
  "MACRO33_COMPILED_CONTENT="+
  gapfill.supplement.content.length,
);
console.log(
  "MACRO33_PROTOCOLS_WITH_CLASSIFICATION="+
  coverage.summary.protocolsWithMachineClassification,
);
console.log(
  "MACRO33_PROTOCOLS_WITH_MANAGEMENT="+
  coverage.summary.protocolsWithMachineManagement,
);
console.log(
  "MACRO33_PROTOCOLS_WITH_ACTION="+
  coverage.summary.protocolsWithMachineAction,
);
console.log(
  "MACRO33_PROTOCOLS_WITH_CONTENT="+
  coverage.summary.protocolsWithMachineContent,
);
console.log(
  "MACRO33_FIRESTORE_DRYRUN_OPERATIONS="+
  plan.counts.totalDryRunOperations,
);
console.log(
  "MACRO33_SHADOW_ACTIVATION_READY="+
  (readiness.shadowActivationReady ? "YES" : "NO"),
);
console.log(
  "MACRO33_SHADOW_BLOCKER="+
  readiness.blocker,
);
console.log("MACRO33_SEMANTIC_INFERENCE=NONE");
