"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  authorBulkMachineContent,
} = require(
  "../clinical_context/clinical_machine_content_bulk_authoring_compiler",
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

const phase10 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_machine_native_supplement.phase10.local.json",
    "utf8",
  ),
);

const bulk = authorBulkMachineContent({
  phase7,
  legacyCompatibility,
});

assert.strictEqual(
  bulk.authoringManifest.summary.protocols,
  270,
);
assert.strictEqual(
  bulk.authoringManifest.summary.protocolContentDocs,
  270,
);
assert.strictEqual(
  bulk.authoringManifest.summary.classificationContentDocs,
  94,
);
assert.strictEqual(
  bulk.authoringManifest.summary.authoredContentDocs,
  364,
);
assert.strictEqual(
  bulk.authoringManifest.summary.machineContentProtocolCoverage,
  270,
);
assert.strictEqual(
  bulk.authoringManifest.summary.legacyActionEvidence,
  270,
);

for (const doc of bulk.supplement.content) {
  assert.strictEqual(doc.data.enabled, true);
  assert.strictEqual(
    doc.data.sourceMode.includes("verbatim"),
    true,
  );
  assert(doc.data.contentKey);
  assert(doc.data.protocolKey);
  assert(doc.data.canonicalPathologyKey);
  assert(doc.data.version != null);
}

const merged = {
  semanticInference: "NONE",
  classifications: [
    ...(phase10.classifications || []),
    ...(bulk.supplement.classifications || []),
  ],
  managementRules: [
    ...(phase10.managementRules || []),
    ...(bulk.supplement.managementRules || []),
  ],
  actions: [
    ...(phase10.actions || []),
    ...(bulk.supplement.actions || []),
  ],
  content: [
    ...(phase10.content || []),
    ...(bulk.supplement.content || []),
  ],
};

const bundle = compileRemoteRegistryBundle({
  phase7,
  legacyCompatibility,
  machineNativeSupplement: merged,
});

assert.strictEqual(
  bundle.counts.machineContent,
  364,
);

const contentIds = bundle.collections.machineContent.map(
  (doc) => doc.id,
);
assert.strictEqual(
  new Set(contentIds).size,
  contentIds.length,
);

for (const doc of bundle.collections.machineContent) {
  assert.strictEqual(
    doc.id,
    doc.data.contentKey,
  );
}
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

const coverage = buildMachineNativeCoverage({
  phase7,
  legacyCompatibility,
  machineNativeSupplement: merged,
});

assert.strictEqual(
  coverage.summary.protocolsWithMachineContent,
  270,
);
assert.strictEqual(
  coverage.summary.protocolsWithMachineClassification,
  0,
);
assert.strictEqual(
  coverage.summary.protocolsWithMachineManagement,
  0,
);
assert.strictEqual(
  coverage.summary.protocolsWithMachineAction,
  0,
);

const plan = buildFirestoreDryRunPlan(bundle);

assert.strictEqual(
  plan.counts.totalDryRunOperations,
  904,
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
  readiness.machineContentRegistryReady,
  true,
);
assert.strictEqual(
  readiness.fullContentCoverage,
  true,
);
assert.strictEqual(
  readiness.shadowActivationReady,
  false,
);
assert.strictEqual(
  readiness.shadowActivationAuthorized,
  false,
);

console.log("MACRO34_CONTRACT_TEST=PASS");
console.log("MACRO34_ASSERTION_GROUPS=28");
console.log("MACRO34_MACHINE_CONTENT_DOCS=364");
console.log("MACRO34_CONTENT_DOCUMENT_IDS_UNIQUE=PASS");
console.log("MACRO34_CONTENT_ID_EQUALS_CONTENT_KEY=PASS");
console.log("MACRO34_MACHINE_CONTENT_COVERAGE=270/270");
console.log("MACRO34_MACHINE_CLASSIFICATION_COVERAGE=0/270");
console.log("MACRO34_MACHINE_MANAGEMENT_COVERAGE=0/270");
console.log("MACRO34_MACHINE_ACTION_COVERAGE=0/270");
console.log("MACRO34_FIRESTORE_DRYRUN_OPERATIONS=904");
console.log("MACRO34_SHADOW_ACTIVATION_READY=NO");
console.log("MACRO34_SEMANTIC_INFERENCE=NONE");
