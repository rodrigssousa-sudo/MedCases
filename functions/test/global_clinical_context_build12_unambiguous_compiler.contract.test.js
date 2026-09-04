"use strict";

const assert = require("assert");
const fs = require("fs");

const qualification = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_unambiguous_qualification.local.json",
    "utf8",
  ),
);

const compiled = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_unambiguous_compiled.local.json",
    "utf8",
  ),
);

const phase5 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase5_unambiguous.local.json",
    "utf8",
  ),
);

assert.strictEqual(qualification.candidateCount, 364);
assert.strictEqual(
  qualification.qualifiedCandidateCount +
    qualification.rejectedCandidateCount,
  364,
);

assert.strictEqual(
  qualification.clinicalSemanticInferencePerformed,
  false,
);
assert.strictEqual(
  qualification.descriptivePtEsOnlyPromotionAllowed,
  false,
);

assert.strictEqual(compiled.cutoverReady, false);
assert.strictEqual(compiled.cloudWriteReady, false);
assert.strictEqual(compiled.clinicalSemanticInferencePerformed, false);

assert.strictEqual(phase5.cutoverReady, false);
assert.strictEqual(phase5.identities.length, 270);
assert.strictEqual(phase5.protocols.length, 270);

for (const doc of compiled.classifications) {
  assert(["categorical", "score", "stage"].includes(doc.mode));
  assert(doc.classificationKey);
  assert(doc.canonicalPathologyKey);
  assert(doc.sourceProof?.blockSha256);
}

for (const doc of compiled.actions) {
  assert(["dispatch_prompt", "open_content_ref"].includes(doc.actionType));
  assert(["primary", "classification", "score", "stage"].includes(doc.kind));
  assert(doc.actionKey);
  assert(doc.sourceProof?.blockSha256);
}

for (const doc of compiled.managementRules) {
  assert(doc.managementRuleKey);
  assert(doc.dependsOn);
  assert(doc.sourceProof?.blockSha256);
}

for (const doc of compiled.content) {
  assert(doc.contentKey);
  assert(doc.payload);
  assert(doc.sourceProof?.blockSha256);
}

console.log("BUILD12_CONTRACT_TEST=PASS");
console.log("BUILD12_ASSERTION_GROUPS=18");
