"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  authorDeterministicMachineActions,
} = require(
  "../clinical_context/clinical_machine_action_bulk_authoring_compiler",
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

const p10 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_machine_native_supplement.phase10.local.json",
    "utf8",
  ),
);

const p11 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_machine_native_supplement.phase11.local.json",
    "utf8",
  ),
);

const phase11Manifest = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_machine_native_authoring_manifest.phase11.local.json",
    "utf8",
  ),
);

const authored =
  authorDeterministicMachineActions({
    phase7,
    legacyCompatibility,
    phase11Manifest,
  });

assert.strictEqual(
  authored.supplement.semanticInference,
  "NONE",
);
assert.strictEqual(
  authored.supplement.actions.length,
  364,
);

const primary = authored.supplement.actions.filter(
  (doc) => doc.data.kind === "primary",
);
const classification =
  authored.supplement.actions.filter(
    (doc) =>
      doc.data.kind === "classification",
  );

assert.strictEqual(primary.length, 270);
assert.strictEqual(classification.length, 94);

for (const doc of primary) {
  assert.strictEqual(
    doc.data.actionType,
    "open_content_ref",
  );
  assert.strictEqual(
    doc.data.contentRef,
    `legacy_protocol_content::${doc.data.canonicalPathologyKey}`,
  );
}

for (const doc of classification) {
  assert.strictEqual(
    doc.data.actionType,
    "open_content_ref",
  );
  assert.strictEqual(
    doc.data.contentRef,
    `legacy_classification_content::${doc.data.canonicalPathologyKey}`,
  );
}

assert.strictEqual(
  authored.clinicalAuthoringBacklog.summary
    .classificationClinicalAuthoringRequired,
  94,
);
assert.strictEqual(
  authored.clinicalAuthoringBacklog.summary
    .classificationNotExplicitlyRequired,
  176,
);
assert.strictEqual(
  authored.clinicalAuthoringBacklog.summary
    .managementClinicalAuthoringRequired,
  270,
);
assert.strictEqual(
  authored.clinicalAuthoringBacklog.summary
    .legacyActionEvidence,
  270,
);

const merged = {
  semanticInference: "NONE",
  classifications: [
    ...(p10.classifications || []),
    ...(p11.classifications || []),
    ...(authored.supplement.classifications || []),
  ],
  managementRules: [
    ...(p10.managementRules || []),
    ...(p11.managementRules || []),
    ...(authored.supplement.managementRules || []),
  ],
  actions: [
    ...(p10.actions || []),
    ...(p11.actions || []),
    ...(authored.supplement.actions || []),
  ],
  content: [
    ...(p10.content || []),
    ...(p11.content || []),
    ...(authored.supplement.content || []),
  ],
};

const bundle = compileRemoteRegistryBundle({
  phase7,
  legacyCompatibility,
  machineNativeSupplement: merged,
});

assert.strictEqual(
  bundle.counts.machineActions,
  364,
);
assert.strictEqual(
  bundle.counts.machineContent,
  364,
);
assert.strictEqual(
  bundle.counts.machineClassifications,
  0,
);
assert.strictEqual(
  bundle.counts.machineManagement,
  0,
);

const actionIds =
  bundle.collections.machineActions.map(
    (doc) => doc.id,
  );

assert.strictEqual(
  new Set(actionIds).size,
  actionIds.length,
);

assert(
  bundle.collections.machineActions.every(
    (doc) => doc.id === doc.data.actionKey,
  ),
);

const coverage = buildMachineNativeCoverage({
  phase7,
  legacyCompatibility,
  machineNativeSupplement: merged,
});

assert.strictEqual(
  coverage.summary.protocolsWithMachineAction,
  270,
);
assert.strictEqual(
  coverage.summary.protocolsWithMachineContent,
  270,
);

const plan = buildFirestoreDryRunPlan(bundle);

assert.strictEqual(
  plan.counts.totalDryRunOperations,
  1268,
);
assert.strictEqual(
  plan.counts.machineActionOperations,
  364,
);
assert.strictEqual(
  plan.counts.machineContentOperations,
  364,
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
  readiness.shadowObservationReady,
  true,
);
assert.strictEqual(
  readiness.shadowObservationAuthorized,
  false,
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
  readiness.visibleCutoverAuthorized,
  false,
);

console.log("MACRO35_CONTRACT_TEST=PASS");
console.log("MACRO35_ASSERTION_GROUPS=34");
console.log("MACRO35_MACHINE_ACTION_DOCS=364");
console.log("MACRO35_PRIMARY_ACTIONS=270");
console.log("MACRO35_CLASSIFICATION_NAVIGATION_ACTIONS=94");
console.log("MACRO35_MACHINE_ACTION_COVERAGE=270/270");
console.log("MACRO35_MACHINE_CONTENT_COVERAGE=270/270");
console.log("MACRO35_CLASSIFICATION_CLINICAL_BACKLOG=94");
console.log("MACRO35_MANAGEMENT_CLINICAL_BACKLOG=270");
console.log("MACRO35_FIRESTORE_DRYRUN_OPERATIONS=1268");
console.log("MACRO35_SHADOW_OBSERVATION_READY=YES");
console.log("MACRO35_VISIBLE_CUTOVER_READY=NO");
console.log("MACRO35_SEMANTIC_INFERENCE=NONE");
