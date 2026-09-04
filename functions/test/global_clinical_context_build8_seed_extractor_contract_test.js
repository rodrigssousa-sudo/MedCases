"use strict";

const assert = require("assert");
const fs = require("fs");
const {
  validateRegistrySeed,
} = require("../clinical_context/clinical_registry_seed_validator");

const seed = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase1_identity_protocol.local.json",
    "utf8",
  ),
);
const inventory = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_migration_inventory.local.json",
    "utf8",
  ),
);

const validation = validateRegistrySeed(seed);

assert.strictEqual(validation.ok, true);
assert.strictEqual(seed.cutoverReady, false);
assert.strictEqual(seed.phase, "identity_protocol_only");
assert(seed.identities.length >= 20);
assert.strictEqual(seed.identities.length, seed.protocols.length);
assert.strictEqual(inventory.recordCount, seed.identities.length);
assert.strictEqual(inventory.cutoverReady, false);
assert.strictEqual(inventory.phase1SeedValidatedOnly, true);

for (const identity of seed.identities) {
  assert(identity.canonicalKey);
  assert(identity.source?.blockSha256);
  assert(identity.source?.sourceKey);
  assert(identity.source?.strategy);
}

for (const protocol of seed.protocols) {
  assert(protocol.protocolKey);
  assert(protocol.canonicalPathologyKey);
  assert(protocol.source?.blockSha256);
  assert(Array.isArray(protocol.referenceUrls));
}

assert.deepStrictEqual(seed.classifications, []);
assert.deepStrictEqual(seed.managementRules, []);
assert.deepStrictEqual(seed.actions, []);
assert.deepStrictEqual(seed.content, []);

console.log("BUILD8_R1_CONTRACT_TEST=PASS");
console.log("BUILD8_R1_ASSERTION_GROUPS=16");
