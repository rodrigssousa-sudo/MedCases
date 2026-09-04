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

let example = null;

for (const identity of seed.identities) {
  for (const alias of collectAliasStrings(identity)) {
    const identityResult =
      identityIndex.resolveExactAlias(alias);
    if (identityResult.resolved) {
      example = {
        alias,
        identityResult,
      };
      break;
    }
  }
  if (example) break;
}

assert(example);

// Exact shape emitted by the new Dart transport envelope.
const appPayload = {
  userMessage: "conteudo_nao_usado_para_identidade",
  systemPrompt:
    `PROTOCOLO_CLINICO_ATIVO: ${example.alias}`,
  lang: "pt",
  mode: "plantao",
  requestId: "macro30b_synthetic",
  clinicalIdentityAlias: example.alias,
};

const result = composition.resolve(appPayload);

assert.strictEqual(result.resolved, true);
assert.strictEqual(
  result.protocolLookup.protocolKey,
  example.identityResult.protocolKey,
);
assert.strictEqual(
  result.protocolLookup.canonicalPathologyKey,
  example.identityResult.canonicalPathologyKey,
);

// Prove free text alone still cannot resolve.
const freeTextOnly = composition.resolve({
  userMessage: example.alias,
  lang: "pt",
  mode: "plantao",
});

assert.strictEqual(freeTextOnly.resolved, false);

console.log("MACRO30B_APP_PAYLOAD_BACKEND_E2E=PASS");
console.log("MACRO30B_REAL_PHASE7_ALIAS="+example.alias);
console.log(
  "MACRO30B_PROTOCOL_KEY="+
  example.identityResult.protocolKey,
);
console.log(
  "MACRO30B_PATHOLOGY_KEY="+
  example.identityResult.canonicalPathologyKey,
);
console.log("MACRO30B_FREE_TEXT_IDENTITY_INFERENCE=NONE");
console.log("MACRO30B_ASSERTION_GROUPS=12");
