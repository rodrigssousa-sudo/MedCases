"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  buildPhase7ExactIdentityIndex,
  collectAliasStrings,
} = require(
  "../clinical_context/clinical_phase7_exact_identity_index",
);

const {
  createClinicalRequestContextBridge,
} = require(
  "../clinical_context/clinical_request_context_bridge",
);

const {
  createPhase7ProtocolLoader,
} = require(
  "../clinical_context/clinical_phase7_protocol_loader",
);

const {
  createClinicalRuntimeIdentityProtocolComposition,
} = require(
  "../clinical_context/clinical_runtime_identity_protocol_composition",
);

const seed = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase7_legacy_compatibility.local.json",
    "utf8",
  ),
);

const identityIndex =
  buildPhase7ExactIdentityIndex(seed);

const requestBridge =
  createClinicalRequestContextBridge({
    identityIndex,
  });

const protocolLoader =
  createPhase7ProtocolLoader(seed);

const composition =
  createClinicalRuntimeIdentityProtocolComposition({
    requestContextBridge: requestBridge,
    protocolLoader,
  });

assert.strictEqual(protocolLoader.protocolCount, 270);
assert.strictEqual(protocolLoader.protocolKeyCount, 270);
assert.strictEqual(
  protocolLoader.canonicalPathologyKeyCount,
  270,
);

// Find one exact Phase7 alias that resolves safely.
let exact = null;
for (const identity of seed.identities) {
  const aliases = collectAliasStrings(identity);
  for (const alias of aliases) {
    const resolved =
      identityIndex.resolveExactAlias(alias);
    if (resolved.resolved) {
      exact = { alias, resolved };
      break;
    }
  }
  if (exact) break;
}
assert(exact);

// Alias + explicit language -> identity -> protocol.
const aliasResult = composition.resolve({
  lang: "es-AR",
  pathologyAlias: exact.alias,
});

assert.strictEqual(aliasResult.resolved, true);
assert.strictEqual(
  aliasResult.protocolLookup.protocolKey,
  exact.resolved.protocolKey,
);
assert.strictEqual(
  aliasResult.protocolLookup.canonicalPathologyKey,
  exact.resolved.canonicalPathologyKey,
);

// Explicit machine keys -> protocol.
const machineResult = composition.resolve({
  language: "pt-BR",
  protocolKey: exact.resolved.protocolKey,
  canonicalPathologyKey:
    exact.resolved.canonicalPathologyKey,
});

assert.strictEqual(machineResult.resolved, true);

// Generic free text must never acquire identity.
const freeText = composition.resolve({
  language: "pt-BR",
  userMessage: exact.alias,
  prompt: exact.alias,
  query: exact.alias,
});

assert.strictEqual(freeText.resolved, false);
assert.strictEqual(
  freeText.reason,
  "request_context_not_ready",
);

// Mismatched keys fail closed.
const other = seed.protocols.find(
  (p) =>
    p.protocolKey !== exact.resolved.protocolKey &&
    p.canonicalPathologyKey !==
      exact.resolved.canonicalPathologyKey,
);
assert(other);

const mismatch = protocolLoader.load({
  protocolKey: exact.resolved.protocolKey,
  canonicalPathologyKey:
    other.canonicalPathologyKey,
});

assert.strictEqual(mismatch.resolved, false);
assert.strictEqual(
  mismatch.reason,
  "protocol_pathology_key_mismatch",
);

for (const result of [
  aliasResult,
  machineResult,
  freeText,
]) {
  assert.strictEqual(
    result.runtimeActivationEnabled,
    false,
  );
  assert.strictEqual(
    result.shadowExecutionEnabled,
    false,
  );
  assert.strictEqual(
    result.realProviderExecutionEnabled,
    false,
  );
  assert.strictEqual(
    result.visibleCutoverEnabled,
    false,
  );
  assert.strictEqual(result.cutoverState, "OFF");
}

console.log("MACRO30A_SYNTHETIC_E2E=PASS");
console.log("MACRO30A_ASSERTION_GROUPS=24");
console.log("MACRO30A_PROTOCOLS=270");
console.log("MACRO30A_ALIAS_TO_PROTOCOL=PASS");
console.log("MACRO30A_MACHINE_KEY_TO_PROTOCOL=PASS");
console.log("MACRO30A_FREE_TEXT_IDENTITY_INFERENCE=NONE");
console.log("MACRO30A_KEY_MISMATCH_FAIL_CLOSED=PASS");
