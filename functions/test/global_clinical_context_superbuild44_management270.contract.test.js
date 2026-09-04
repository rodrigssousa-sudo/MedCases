"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  ClinicalManagementDependencyResolver,
} = require("../clinical_context/clinical_management_dependency_resolver");

const phase7 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase7_legacy_compatibility.local.json",
    "utf8",
  ),
);
const m44 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_machine_management.global270.phase18.local.json",
    "utf8",
  ),
);
const evidence = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_management_authoring_evidence.global270.phase18.local.json",
    "utf8",
  ),
);
const supplement = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_machine_native_supplement.phase18_management270.local.json",
    "utf8",
  ),
);
const report = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/global_clinical_context_superbuild44_management270_report.local.json",
    "utf8",
  ),
);
const consolidated94 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_machine_classifications.consolidated94.phase17.local.json",
    "utf8",
  ),
);

const p7keys = phase7.protocols.map((x) => x.protocolKey).sort();
const p7pathologies = phase7.protocols.map((x) => x.canonicalPathologyKey);
assert.strictEqual(p7keys.length, 270);
assert.strictEqual(new Set(p7keys).size, 270);
assert.strictEqual(p7pathologies.length, 270);
assert.strictEqual(new Set(p7pathologies).size, 270);

const chunks = [];
for (let i = 0; i < p7keys.length; i += 45) chunks.push(p7keys.slice(i, i + 45));
assert.strictEqual(chunks.length, 6);
assert.deepStrictEqual(chunks.map((x) => x.length), [45,45,45,45,45,45]);
assert.strictEqual(new Set(chunks.flat()).size, 270);

assert.strictEqual(consolidated94.records.length, 94);
assert.strictEqual(consolidated94.machineEvaluableCount, 40);
assert.strictEqual(consolidated94.noncanonicalFailClosedCount, 54);

assert.strictEqual(m44.batchId, "MANAGEMENT_GLOBAL_270");
assert.strictEqual(m44.records.length, 270);
assert.strictEqual(m44.recordCount, 270);
assert.strictEqual(m44.enabledCount, 0);
assert.strictEqual(m44.failClosedCount, 270);
assert.strictEqual(m44.managementReadyCount, 0);
assert.strictEqual(m44.visibleCutoverEligibleCount, 0);
assert.deepStrictEqual(
  m44.replacesMechanicalBatches,
  [
    "MANAGEMENT_MACRO_01",
    "MANAGEMENT_MACRO_02",
    "MANAGEMENT_MACRO_03",
    "MANAGEMENT_MACRO_04",
    "MANAGEMENT_MACRO_05",
    "MANAGEMENT_MACRO_06",
  ],
);

const protocolKeys = m44.records.map((x) => x.protocolKey);
const pathologyKeys = m44.records.map((x) => x.canonicalPathologyKey);
const managementKeys = m44.records.map((x) => x.managementRuleKey);
assert.strictEqual(new Set(protocolKeys).size, 270);
assert.strictEqual(new Set(pathologyKeys).size, 270);
assert.strictEqual(new Set(managementKeys).size, 270);
assert.deepStrictEqual(protocolKeys, p7keys);

for (const row of m44.records) {
  assert.strictEqual(row.enabled, false);
  assert.strictEqual(row.managementReady, false);
  assert.strictEqual(row.visibleCutoverEligible, false);
  assert.strictEqual(row.authoringStatus, "AUTHORITATIVE_CURRENT_REVIEW_REQUIRED_FAIL_CLOSED");
  assert.strictEqual(row.provenancePolicy, "AUTHORITATIVE_CURRENT_OR_FAIL_CLOSED");
  assert.strictEqual(row.clinicalSemanticInferencePerformed, false);
  assert.strictEqual(row.legacyManagementPromotedAutomatically, false);
  assert.strictEqual(row.managementInferredFromClassificationName, false);
  assert.strictEqual(row.requiresClassification, false);
  assert.deepStrictEqual(row.dependsOn, {});
  assert(row.labels && row.labels.pt && row.labels.es);
  assert(row.clinicalState && row.clinicalState.meaning.pt);
  assert(row.clinicalState && row.clinicalState.meaning.es);
  assert(Array.isArray(row.requiredFacts));
  assert(Array.isArray(row.initialActions));
  assert(Array.isArray(row.definitiveActions));
  assert(Array.isArray(row.conditionalActions));
  assert(Array.isArray(row.contraindicatedActions));
  assert(Array.isArray(row.monitoring));
  assert(Array.isArray(row.reassessment));
  assert(Array.isArray(row.escalationCriteria));
  assert(Array.isArray(row.classificationDependencies));
  assert(Array.isArray(row.scoreDependencies));
  assert.strictEqual(row.initialActions.length, 0);
  assert.strictEqual(row.definitiveActions.length, 0);
  assert.strictEqual(row.conditionalActions.length, 0);
  assert.strictEqual(row.contraindicatedActions.length, 0);
  assert.strictEqual(row.monitoring.length, 0);
  assert.strictEqual(row.reassessment.length, 0);
  assert.strictEqual(row.escalationCriteria.length, 0);
  assert.strictEqual(row.classificationDependencies.length, 0);
  assert.strictEqual(row.scoreDependencies.length, 0);
  assert(row.primaryActionRef);
  assert(row.payload && typeof row.payload === "object");
  assert.strictEqual(row.payload.legacyNavigationReference.clinicalManagementExecutable, false);
  assert.strictEqual(row.payload.legacyNavigationReference.semanticRole, "REFERENCE_ONLY_NOT_MANAGEMENT");
  assert(Array.isArray(row.provenance));
  for (const p of row.provenance) {
    assert(/^https:\/\//.test(String(p.url || "")));
    assert.strictEqual(p.managementAuthorityValidated, false);
    assert.strictEqual(p.automaticPromotion, false);
  }
}

assert.strictEqual(evidence.records.length, 270);
assert.strictEqual(evidence.recordCount, 270);
assert.strictEqual(evidence.automaticLegacyPromotionCount, 0);
for (const row of evidence.records) {
  assert.strictEqual(row.semanticInferencePerformed, false);
  assert.strictEqual(row.automaticLegacyPromotion, false);
  assert.strictEqual(row.authoringDisposition, "AUTHORITATIVE_CURRENT_REVIEW_REQUIRED_FAIL_CLOSED");
}

assert.strictEqual(supplement.classifications.length, 0);
assert.strictEqual(supplement.managementRules.length, 270);
assert.strictEqual(supplement.actions.length, 0);
assert.strictEqual(supplement.content.length, 0);
assert.strictEqual(supplement.cloudWriteAuthorized, false);
assert.strictEqual(supplement.backendDeployAuthorized, false);
assert.strictEqual(supplement.remoteConfigWriteAuthorized, false);
assert.strictEqual(supplement.shadowS1Percent, 1);
assert.strictEqual(supplement.shadowPercentChangeAuthorized, false);
assert.strictEqual(supplement.visibleCutover, false);

assert.strictEqual(report.managementBacklog, 270);
assert.strictEqual(report.authoredMachineNativeEnvelopes, 270);
assert.strictEqual(report.enabledManagementRules, 0);
assert.strictEqual(report.authoritativeFailClosed, 270);
assert.strictEqual(report.managementReady, 0);
assert.strictEqual(report.visibleCutoverEligible, 0);
assert.strictEqual(report.automaticLegacyPromotion, false);
assert.strictEqual(report.managementInferenceFromClassificationName, false);
assert.strictEqual(report.semanticInference, "NONE");
assert.strictEqual(report.cloudMutation, false);
assert.strictEqual(report.shadowS1Percent, 1);
assert.strictEqual(report.visibleCutover, false);

const resolver = new ClinicalManagementDependencyResolver();
for (const idx of [0, 44, 45, 89, 90, 134, 135, 179, 180, 224, 225, 269]) {
  const row = m44.records[idx];
  const result = resolver.resolve({
    pathologyKey: row.canonicalPathologyKey,
    managementRules: [row],
    classificationResult: {
      resolved: true,
      classificationKey: "synthetic",
      categoryKey: "synthetic",
    },
  });
  assert.strictEqual(result.resolved, false);
  assert.strictEqual(result.reason, "management_rule_not_registered");
}

const synthetic = {
  ...m44.records[0],
  enabled: true,
  managementReady: true,
  managementRuleKey: "synthetic_management_dependency_contract",
  requiresClassification: true,
  dependsOn: {
    classificationKey: "synthetic_classification",
    categoryKey: "high",
  },
};

let result = resolver.resolve({
  pathologyKey: synthetic.canonicalPathologyKey,
  managementRules: [synthetic],
  classificationResult: {
    resolved: false,
    missingFacts: ["patient.fact.alpha"],
  },
});
assert.strictEqual(result.resolved, false);
assert.strictEqual(result.reason, "management_waiting_for_classification");
assert.deepStrictEqual(result.missingFacts, ["patient.fact.alpha"]);

result = resolver.resolve({
  pathologyKey: synthetic.canonicalPathologyKey,
  managementRules: [synthetic],
  classificationResult: {
    resolved: true,
    classificationKey: "synthetic_classification",
    categoryKey: "high",
  },
});
assert.strictEqual(result.resolved, true);
assert.strictEqual(result.managementRuleKey, "synthetic_management_dependency_contract");

console.log("SUPERBUILD44_GLOBAL270_CONTRACT=PASS");
console.log("SUPERBUILD44_R1_RESOLVER_ARGUMENT_NAME_CONTRACT=PASS");
console.log("SUPERBUILD44_PROTOCOLS=270/270");
console.log("SUPERBUILD44_MACHINE_NATIVE_RECORDS=270/270");
console.log("SUPERBUILD44_ENABLED=0/270");
console.log("SUPERBUILD44_AUTHORITATIVE_FAIL_CLOSED=270/270");
console.log("SUPERBUILD44_MANAGEMENT_READY=0/270");
console.log("SUPERBUILD44_PT_ES_ENVELOPE_PARITY=270/270_PASS");
console.log("SUPERBUILD44_PRIMARY_ACTION_LINKAGE=270/270_PASS");
console.log("SUPERBUILD44_PROTOCOL_UNIQUENESS=270/270_PASS");
console.log("SUPERBUILD44_PATHOLOGY_UNIQUENESS=270/270_PASS");
console.log("SUPERBUILD44_AUTOMATIC_LEGACY_PROMOTION=NO");
console.log("SUPERBUILD44_MANAGEMENT_INFERENCE_FROM_CLASSIFICATION_NAME=NO");
console.log("SUPERBUILD44_RESOLVER_FAIL_CLOSED_BOUNDARY_SAMPLE=12/12_PASS");
console.log("SUPERBUILD44_RESOLVER_CLASSIFICATION_DEPENDENCY_SYNTHETIC_CONTRACT=PASS");
console.log("S1_SAMPLE_PERCENT=1_UNCHANGED");
console.log("VISIBLE_CUTOVER=HARD_OFF");
