"use strict";

const assert = require("assert");
const fs = require("fs");

const proofs = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_structured_source_proofs.local.json",
    "utf8",
  ),
);

const candidates = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_normalized_candidates.local.json",
    "utf8",
  ),
);

const audit = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_additional_owner_inventory.local.json",
    "utf8",
  ),
);

const phase3 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase3_normalized_candidates.local.json",
    "utf8",
  ),
);

const expectedStructuredProofCount = proofs.records
  .flatMap((record) => record.clinicalFieldCandidates)
  .filter((field) => field.structuredLiteralProven)
  .length;

assert.strictEqual(candidates.candidateCount, expectedStructuredProofCount);
assert.strictEqual(
  candidates.literalParseSuccessCount + candidates.literalParseRejectedCount,
  candidates.candidateCount,
);

assert.strictEqual(candidates.clinicalSemanticMappingPerformed, false);
assert.strictEqual(candidates.finalRegistryDocuments, false);
assert.strictEqual(candidates.cutoverReady, false);

for (const item of candidates.candidates) {
  assert(item.canonicalPathologyKey);
  assert(item.protocolKey);
  assert(item.blockSha256);
  assert(item.fieldName);
  assert(Array.isArray(item.groups));
  assert.strictEqual(item.clinicalSemanticMappingPerformed, false);
  assert.strictEqual(item.finalRegistryDocument, false);

  if (item.literalParseOk) {
    assert.strictEqual(item.literalParseError, null);
  } else {
    assert(item.literalParseError);
    assert.strictEqual(item.normalizedLiteral, null);
  }
}

assert.strictEqual(audit.owners.length, 6);
assert.strictEqual(audit.sourceWritePerformed, false);
assert.strictEqual(audit.cutoverReady, false);

assert.deepStrictEqual(phase3.classifications, []);
assert.deepStrictEqual(phase3.managementRules, []);
assert.deepStrictEqual(phase3.actions, []);
assert.deepStrictEqual(phase3.content, []);
assert.strictEqual(phase3.cutoverReady, false);

console.log("BUILD10_CONTRACT_TEST=PASS");
console.log("BUILD10_ASSERTION_GROUPS=18");
