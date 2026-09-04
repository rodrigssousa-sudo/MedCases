"use strict";

const assert = require("assert");
const fs = require("fs");

const {
  buildPhase7ExactIdentityIndex,
  collectAliasStrings,
  canonicalIdentityKey,
} = require(
  "../clinical_context/clinical_phase7_exact_identity_index",
);

const {
  extractExplicitLanguage,
  extractExplicitIdentityAlias,
  createClinicalRequestContextBridge,
} = require(
  "../clinical_context/clinical_request_context_bridge",
);

const seed = JSON.parse(
  fs.readFileSync(
    "functions/clinical_context/generated/clinical_registry_seed.phase7_legacy_compatibility.local.json",
    "utf8",
  ),
);

const index = buildPhase7ExactIdentityIndex(seed);

assert.strictEqual(index.identityCount, 270);
assert.strictEqual(index.protocolCount, 270);
assert(index.aliasValueCount >= 270);

let exactExample = null;

for (const identity of seed.identities) {
  const identityKey = canonicalIdentityKey(identity);
  const aliases = collectAliasStrings(identity);

  if (!identityKey || aliases.length === 0) {
    continue;
  }

  for (const alias of aliases) {
    const resolved = index.resolveExactAlias(alias);

    if (resolved.resolved) {
      exactExample = {
        alias,
        resolved,
      };
      break;
    }
  }

  if (exactExample) {
    break;
  }
}

assert(exactExample);
assert(exactExample.resolved.protocolKey);
assert(exactExample.resolved.canonicalPathologyKey);

const bridge = createClinicalRequestContextBridge({
  identityIndex: index,
});

// A. Legacy callable data.isEs is an explicit language signal.
const legacyEs = bridge.resolve({
  data: {
    isEs: true,
    pathologyAlias: exactExample.alias,
  },
});

assert.strictEqual(legacyEs.language, "es");
assert.strictEqual(
  legacyEs.languageSource,
  "explicit_isEs_boolean",
);
assert.strictEqual(legacyEs.identity.resolved, true);
assert.strictEqual(legacyEs.readyForProtocolLookup, true);

// B. PT isEs=false.
const legacyPt = bridge.resolve({
  data: {
    isEs: false,
    pathologyAlias: exactExample.alias,
  },
});

assert.strictEqual(legacyPt.language, "pt");
assert.strictEqual(legacyPt.readyForProtocolLookup, true);

// C. Explicit locale.
const localeEs = bridge.resolve({
  locale: "es-AR",
  pathologyAlias: exactExample.alias,
});

assert.strictEqual(localeEs.language, "es");

// D. Accept-Language is explicit and safe.
const headerPt = bridge.resolve({
  headers: {
    "accept-language": "pt-BR,pt;q=0.9,en;q=0.5",
  },
  pathologyAlias: exactExample.alias,
});

assert.strictEqual(headerPt.language, "pt");
assert.strictEqual(
  headerPt.languageSource,
  "accept_language_header",
);

// E. Explicit machine keys bypass alias lookup.
const explicitMachine = bridge.resolve({
  lang: "es",
  protocolKey: exactExample.resolved.protocolKey,
  canonicalPathologyKey:
    exactExample.resolved.canonicalPathologyKey,
});

assert.strictEqual(
  explicitMachine.identity.reason,
  "explicit_machine_identity",
);
assert.strictEqual(explicitMachine.readyForProtocolLookup, true);

// F. No language inference from prompt.
const noLanguageInference = bridge.resolve({
  userMessage:
    "Paciente con dolor torácico y disnea en guardia.",
  pathologyAlias: exactExample.alias,
});

assert.strictEqual(noLanguageInference.language, null);
assert.strictEqual(
  noLanguageInference.readyForProtocolLookup,
  false,
);

// G. No pathology inference from generic prompt/userMessage.
assert.strictEqual(
  extractExplicitIdentityAlias({
    userMessage: exactExample.alias,
    prompt: exactExample.alias,
    query: exactExample.alias,
  }),
  null,
);

// H. Alias must be exact; extra free text must fail closed.
const nonExactAlias = index.resolveExactAlias(
  `${exactExample.alias} com contexto adicional`,
);

assert.strictEqual(nonExactAlias.resolved, false);

// I. Unknown alias fails closed.
const unknown = bridge.resolve({
  language: "pt-BR",
  pathologyAlias:
    "__MEDCASES_BUILD25_UNKNOWN_IDENTITY_ALIAS__",
});

assert.strictEqual(unknown.identity.resolved, false);
assert.strictEqual(unknown.readyForProtocolLookup, false);

// J. Unsupported language fails closed.
const unsupported = extractExplicitLanguage({
  locale: "en-US",
});

assert.strictEqual(unsupported.language, null);

// K. Hard-off.
for (const result of [
  legacyEs,
  legacyPt,
  localeEs,
  headerPt,
  explicitMachine,
]) {
  assert.strictEqual(result.runtimeActivationEnabled, false);
  assert.strictEqual(result.shadowExecutionEnabled, false);
  assert.strictEqual(result.realProviderExecutionEnabled, false);
  assert.strictEqual(result.visibleCutoverEnabled, false);
  assert.strictEqual(result.cutoverState, "OFF");
  assert(Object.isFrozen(result));
}

console.log("BUILD25_CONTRACT_TEST=PASS");
console.log("BUILD25_ASSERTION_GROUPS=28");
console.log(
  `BUILD25_PHASE7_ALIAS_VALUE_COUNT=${index.aliasValueCount}`,
);
console.log(
  `BUILD25_EXACT_ALIAS_EXAMPLE_PROTOCOL_KEY=${exactExample.resolved.protocolKey}`,
);
console.log(
  `BUILD25_EXACT_ALIAS_EXAMPLE_PATHOLOGY_KEY=${exactExample.resolved.canonicalPathologyKey}`,
);
console.log("BUILD25_LANGUAGE_INFERENCE_FROM_FREE_TEXT=NONE");
console.log("BUILD25_PATHOLOGY_INFERENCE_FROM_GENERAL_PROMPT=NONE");
