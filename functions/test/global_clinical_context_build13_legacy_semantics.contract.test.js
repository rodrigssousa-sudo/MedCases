"use strict";

const assert = require("assert");
const fs = require("fs");

const semantics = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_legacy_pt_es_semantics.local.json",
    "utf8",
  ),
);

const consumers = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_legacy_consumer_proofs.local.json",
    "utf8",
  ),
);

const compat = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_legacy_compatibility_candidates.local.json",
    "utf8",
  ),
);

const phase6 = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase6_legacy_semantics.local.json",
    "utf8",
  ),
);

assert.strictEqual(semantics.fieldCounts.classification, 94);
assert.strictEqual(semantics.fieldCounts.actions, 270);
assert.strictEqual(semantics.records.length, 364);
assert(semantics.innerFamilyCount > 0);

for (const record of semantics.records) {
  assert(record.canonicalPathologyKey);
  assert(record.protocolKey);
  assert(record.blockSha256);
  assert(record.sourceExpressionSha256);
  assert(["classification", "actions"].includes(record.fieldName));
  assert.strictEqual(typeof record.ptEsStructuralParity, "boolean");
}

assert(consumers.dartFileCount > 0);
assert(consumers.proofCount >= 0);
assert.strictEqual(
  compat.candidateCount,
  364,
);
assert.strictEqual(compat.finalRegistryDocuments, false);
assert.strictEqual(compat.remoteRegistryMappingPerformed, false);
assert.strictEqual(compat.cloudWriteReady, false);
assert.strictEqual(compat.cutoverReady, false);

for (const record of compat.records) {
  assert(record.canonicalPathologyKey);
  assert(record.protocolKey);
  assert(["classification", "actions"].includes(record.legacyField));
  assert.strictEqual(record.finalRegistryDocument, false);
  assert.strictEqual(record.remoteRegistryMappingPerformed, false);
  if (record.consumerContractProven) {
    assert.strictEqual(record.compatibilityKind, "localized_payload");
  }
}

assert.deepStrictEqual(phase6.classifications, []);
assert.deepStrictEqual(phase6.managementRules, []);
assert.deepStrictEqual(phase6.actions, []);
assert.deepStrictEqual(phase6.content, []);
assert.strictEqual(phase6.cutoverReady, false);

console.log("BUILD13_CONTRACT_TEST=PASS");
console.log("BUILD13_ASSERTION_GROUPS=20");
