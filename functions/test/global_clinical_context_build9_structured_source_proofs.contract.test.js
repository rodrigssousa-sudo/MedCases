"use strict";

const assert = require("assert");
const fs = require("fs");

const phase1 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase1_identity_protocol.local.json",
    "utf8",
  ),
);
const phase2 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase2_proofs.local.json",
    "utf8",
  ),
);
const proofs = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_structured_source_proofs.local.json",
    "utf8",
  ),
);

assert.strictEqual(phase1.identities.length, 270);
assert.strictEqual(phase1.protocols.length, 270);
assert.strictEqual(phase2.identities.length, 270);
assert.strictEqual(phase2.protocols.length, 270);
assert.deepStrictEqual(phase2.identities, phase1.identities);
assert.deepStrictEqual(phase2.protocols, phase1.protocols);

assert.deepStrictEqual(phase2.classifications, []);
assert.deepStrictEqual(phase2.managementRules, []);
assert.deepStrictEqual(phase2.actions, []);
assert.deepStrictEqual(phase2.content, []);
assert.strictEqual(phase2.cutoverReady, false);

assert.strictEqual(proofs.structuredClinicalInferencePerformed, false);
assert.strictEqual(proofs.normalizationPerformed, false);
assert.strictEqual(proofs.summary.protocolModelCount, 270);
assert.strictEqual(proofs.summary.sourceProofMatchedCount, 270);
assert.strictEqual(proofs.records.length, 270);

for (const record of proofs.records) {
  assert(record.canonicalPathologyKey);
  assert(record.protocolKey);
  assert(record.blockSha256);
  assert(Array.isArray(record.clinicalFieldCandidates));

  for (const field of record.clinicalFieldCandidates) {
    assert(field.name);
    assert(field.shape);
    assert(field.exprSha256);
    assert(Array.isArray(field.groups));
    if (field.structuredLiteralProven) {
      assert(
        field.shape === "list_literal" ||
        field.shape === "map_literal",
      );
    }
  }
}

console.log("BUILD9_CONTRACT_TEST=PASS");
console.log("BUILD9_ASSERTION_GROUPS=20");
