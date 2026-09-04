"use strict";

const assert = require("assert");
const fs = require("fs");

const candidates = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_normalized_candidates.local.json",
    "utf8",
  ),
);
const schemas = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_candidate_schema_families.local.json",
    "utf8",
  ),
);
const ownerProofs = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_additional_owner_source_proofs.local.json",
    "utf8",
  ),
);
const phase4 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase4_schema_proofs.local.json",
    "utf8",
  ),
);

assert.strictEqual(candidates.literalParseSuccessCount, 364);
assert.strictEqual(schemas.candidateCount, 364);
assert.strictEqual(schemas.literalParseSuccessCount, 364);
assert(schemas.schemaFamilyCount > 0);

const familyCountTotal = schemas.schemaFamilies
  .reduce((sum, family) => sum + family.count, 0);
assert.strictEqual(familyCountTotal, 364);

for (const family of schemas.schemaFamilies) {
  assert(family.schemaFamilyId);
  assert(family.count > 0);
  assert(family.signature);
  assert.strictEqual(family.clinicalSemanticMappingPerformed, false);
}

assert.strictEqual(ownerProofs.ownerCount, 6);
assert(ownerProofs.totalProofCount >= 2);
assert.strictEqual(ownerProofs.clinicalSemanticMappingPerformed, false);
assert.strictEqual(ownerProofs.finalRegistryDocuments, false);

for (const owner of ownerProofs.owners) {
  assert(owner.file);
  assert(owner.proofCount >= owner.auditStructuredSignalCount);
  for (const proof of owner.proofs) {
    assert(proof.field);
    assert(proof.line > 0);
    assert(proof.expressionSha256);
    assert(proof.sourceFileSha256);
    assert(
      proof.shapeSignal === "list_literal_signal" ||
      proof.shapeSignal === "map_literal_signal",
    );
  }
}

assert.deepStrictEqual(phase4.classifications, []);
assert.deepStrictEqual(phase4.managementRules, []);
assert.deepStrictEqual(phase4.actions, []);
assert.deepStrictEqual(phase4.content, []);
assert.strictEqual(phase4.cutoverReady, false);

console.log("BUILD11_CONTRACT_TEST=PASS");
console.log("BUILD11_ASSERTION_GROUPS=20");
