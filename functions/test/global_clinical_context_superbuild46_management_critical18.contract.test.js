"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  ClinicalManagementDependencyResolver,
} = require("../clinical_context/clinical_management_dependency_resolver");

const m46 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_machine_management.authoritative18.phase19.local.json",
    "utf8",
  ),
);
const evidence = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_management_authoring_evidence.authoritative18.phase19.local.json",
    "utf8",
  ),
);
const supplement = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_machine_native_supplement.phase19_management270_authoritative18.local.json",
    "utf8",
  ),
);
const report = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/global_clinical_context_superbuild46_management_critical18_report.local.json",
    "utf8",
  ),
);

assert.strictEqual(m46.recordCount, 270);
assert.strictEqual(m46.enabledCount, 18);
assert.strictEqual(m46.managementReadyCount, 18);
assert.strictEqual(m46.failClosedCount, 252);
assert.strictEqual(m46.visibleCutoverEligibleCount, 0);
assert.strictEqual(m46.automaticLegacyPromotion, false);
assert.strictEqual(m46.managementInferenceFromClassificationName, false);
assert.strictEqual(m46.clinicalSemanticInference, "NONE");

assert.strictEqual(new Set(m46.records.map((r) => r.protocolKey)).size, 270);
assert.strictEqual(new Set(m46.records.map((r) => r.canonicalPathologyKey)).size, 270);
assert.strictEqual(new Set(m46.records.map((r) => r.managementRuleKey)).size, 270);

const enabled = m46.records.filter((r) => r.enabled === true);
const disabled = m46.records.filter((r) => r.enabled === false);
assert.strictEqual(enabled.length, 18);
assert.strictEqual(disabled.length, 252);
assert(enabled.every((r) => r.managementReady === true));
assert(enabled.every((r) => r.visibleCutoverEligible === false));
assert(enabled.every((r) => r.legacyManagementPromotedAutomatically === false));
assert(enabled.every((r) => r.managementInferredFromClassificationName === false));
assert(enabled.every((r) => r.clinicalSemanticInferencePerformed === false));
assert(enabled.every((r) => Array.isArray(r.provenance) && r.provenance.length > 0));
for (const row of enabled) {
  for (const p of row.provenance) {
    assert(/^https:\/\//.test(String(p.url || "")));
    assert.strictEqual(p.managementAuthorityValidated, true);
    assert.strictEqual(p.automaticPromotion, false);
  }
}

assert.strictEqual(evidence.recordCount, 270);
assert.strictEqual(evidence.currentAuthoritativeAuthoredCount, 18);
assert.strictEqual(evidence.inheritedFailClosedCount, 252);
assert.strictEqual(evidence.automaticLegacyPromotion, false);

assert.strictEqual(supplement.managementRules.length, 270);
assert.strictEqual(supplement.classifications.length, 0);
assert.strictEqual(supplement.actions.length, 0);
assert.strictEqual(supplement.content.length, 0);
assert.strictEqual(supplement.cloudWriteAuthorized, false);
assert.strictEqual(supplement.backendDeployAuthorized, false);
assert.strictEqual(supplement.remoteConfigWriteAuthorized, false);
assert.strictEqual(supplement.shadowS1Percent, 1);
assert.strictEqual(supplement.shadowPercentChangeAuthorized, false);
assert.strictEqual(supplement.visibleCutover, false);

assert.strictEqual(report.authoritativeCurrentEnabled, 18);
assert.strictEqual(report.retainedFailClosed, 252);
assert.strictEqual(report.visibleCutoverEligible, 0);
assert.strictEqual(report.automaticLegacyPromotion, false);
assert.strictEqual(report.managementInferenceFromClassificationName, false);
assert.strictEqual(report.semanticInference, "NONE");
assert.strictEqual(report.cloudMutation, false);
assert.strictEqual(report.shadowS1Percent, 1);
assert.strictEqual(report.visibleCutover, false);

const byKey = new Map(m46.records.map((r) => [r.canonicalPathologyKey, r]));
const selected = new Set(m46.selectedAuthoritativeKeys);
assert.strictEqual(selected.size, 18);
for (const key of selected) {
  assert(byKey.has(key));
  assert.strictEqual(byKey.get(key).enabled, true);
}

// Regression guards against known stale legacy treatment semantics.
const flat = (key) => JSON.stringify(byKey.get(key)).toLowerCase();
for (const key of ["anafilaxia", "anafilaxia_ped"]) {
  assert(!flat(key).includes("ranitidina"));
  assert(!flat(key).includes("previne reação bifásica"));
  assert(!flat(key).includes("previene reacción bifásica"));
  assert(flat(key).includes("0,01 mg/kg"));
}
for (const key of ["cetoacidose_diabetica", "caso_cetoacidose_diabetica"]) {
  assert(flat(key).includes("<3,5"));
  assert(flat(key).includes("adiar insulina"));
  assert(flat(key).includes("posponer insulina"));
}
for (const key of ["tep_agudo", "tromboembolismo_pulmonar"]) {
  assert(flat(key).includes("não usar wells"));
  assert(flat(key).includes("no usar wells"));
}
assert(flat("sindrome_coronariana_sem_st").includes("não realizar fibrinólise"));
assert(flat("sindrome_coronariana_sem_st").includes("no realizar fibrinólisis"));
assert(flat("sindrome_coronariana_sem_st").includes("pré-tratamento universal"));
assert(flat("sindrome_coronariana_sem_st").includes("pretratamiento universal"));

const resolver = new ClinicalManagementDependencyResolver();
const enabledRule = byKey.get("choque_septico_avancado");
let result = resolver.resolve({
  pathologyKey: enabledRule.canonicalPathologyKey,
  managementRules: [enabledRule],
  classificationResult: { resolved: false, missingFacts: [] },
});
assert.strictEqual(result.resolved, true);
assert.strictEqual(result.managementRuleKey, enabledRule.managementRuleKey);
assert.strictEqual(result.payload.authoringPolicy, "AUTHORITATIVE_CURRENT_OR_FAIL_CLOSED");

const disabledRule = disabled[0];
result = resolver.resolve({
  pathologyKey: disabledRule.canonicalPathologyKey,
  managementRules: [disabledRule],
  classificationResult: { resolved: false, missingFacts: [] },
});
assert.strictEqual(result.resolved, false);
assert.strictEqual(result.reason, "management_rule_not_registered");

console.log("SUPERBUILD46_CONTRACT=PASS");
console.log("SUPERBUILD46_GLOBAL_RECORDS=270/270");
console.log("SUPERBUILD46_AUTHORITATIVE_ENABLED=18/270");
console.log("SUPERBUILD46_MANAGEMENT_READY=18/270");
console.log("SUPERBUILD46_RETAINED_FAIL_CLOSED=252/270");
console.log("SUPERBUILD46_RESOLVER_ENABLED_SAMPLE=PASS");
console.log("SUPERBUILD46_RESOLVER_FAIL_CLOSED_SAMPLE=PASS");
console.log("SUPERBUILD46_STALE_LEGACY_GUARDS=PASS");
console.log("SUPERBUILD46_PT_ES_PROVENANCE_CONTRACT=PASS");
console.log("S1_SAMPLE_PERCENT=1_UNCHANGED");
console.log("VISIBLE_CUTOVER=HARD_OFF");
